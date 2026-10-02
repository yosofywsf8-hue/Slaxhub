-- Blade Ball Mobile — Auto Parry + Auto Spam (Gist Only)
-- Runtime: Roblox mobile
-- Executor: cloneref, getupvalues, getrawmetatable, setreadonly, writefile/readfile

local cloneref = cloneref or function(o) return o end
local CoreGui  = cloneref(game:GetService("CoreGui"))

-- ============================================================
-- 1. PARRY PATCH
-- ============================================================
local _PARRY_PATCH = {
    keyTable    = nil,
    transformFn = nil,
    parryHash   = nil,
    parryRemote = nil,
    ready       = false,
}

task.spawn(function()
    local ok, err = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local Controllers = RS:WaitForChild("Controllers", 15)
        if not Controllers then return end
        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 16) == "SwordsController" then SC = child; break end
        end
        if not SC then warn("[PARRY] SwordsController not found"); return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then warn("[PARRY] PRY module not found"); return end
        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then warn("[PARRY] executor missing getupvalues"); return end
        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then warn("[PARRY] unexpected upvalue count"); return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
    end)
    if not ok then warn("[PARRY] init error:", tostring(err)) end
end)

local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local workspace          = cloneref(game:GetService("Workspace"))

local _reverted, _original = {}, {}

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string"
        and type(args[3]) == "string"
        and type(args[4]) == "number"
        and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table"
        and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    if _reverted[remote] then return end
    local meta = getrawmetatable(remote)
    if not meta or _original[meta] then return end
    _original[meta] = true
    setreadonly(meta, false)
    local _old = meta.__index
    meta.__index = function(self, key)
        if (key == "FireServer" and self:IsA("RemoteEvent"))
        or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return function(_, ...)
                local _args = {...}
                if _is_valid(_args) and not _reverted[self] then
                    _reverted[self]          = _args
                    _PARRY_PATCH.ready       = true
                    _PARRY_PATCH.parryRemote = self
                end
                return _old(self, key)(_, unpack(_args))
            end
        end
        return _old(self, key)
    end
    setreadonly(meta, true)
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA("RemoteEvent") or _remote:IsA("RemoteFunction") then
        pcall(_hook, _remote)
    end
end

function _PARRY_PATCH.fire(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local keyIndex   = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
    if not currentKey then return false end
    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false end
    end
    local serverTime = workspace:GetServerTimeNow() * 100
    local timeStr = tostring(math.floor(serverTime))
    local tc = {}
    for i = 1, #timeStr do
        local ki = (i - 1) % #transformed + 1
        local kb = string.byte(transformed, ki)
        local tb = (string.byte(timeStr, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)
    return pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token, 0.5,
            curveCFrame, screenPositions, mouseLocation, false
        )
    end)
end

-- ============================================================
-- 2. IMPORTS
-- ============================================================
local Players          = cloneref(game:GetService("Players"))
local RunService       = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Stats            = cloneref(game:GetService("Stats"))
local TweenService     = cloneref(game:GetService("TweenService"))
local HttpService      = cloneref(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

local Alive   = workspace:FindFirstChild("Alive")   or workspace:WaitForChild("Alive")
local Runtime = workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime")

-- ============================================================
-- 3. STATE
-- ============================================================
local maxParryCount = 36
local parryDelay    = 0.05

local System = {
    __properties = {
        __autoparry_enabled   = false,
        __triggerbot_enabled  = false,
        __auto_spam_enabled   = false,
        __curve_mode          = 1,
        __accuracy            = 1,
        __divisor_multiplier  = 1.1,
        __parried             = false,
        __training_parried    = false,
        __spam_threshold      = 1.5,
        __parries             = 0,
        __grab_animation      = nil,
        __tornado_time        = tick(),
        __first_parry_done    = false,
        __connections         = {},
        __infinity_active     = false,
        __deathslash_active   = false,
        __timehole_active     = false,
        __slashesoffury_active = false,
        __slashesoffury_count = 0,
        __humanizer_enabled   = false,
        __humanizer_min_accuracy = 1,
        __humanizer_max_accuracy = 50,
        __humanizer_last_update  = 0,
        __humanizer_next_change  = 0.8,
        __is_mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled,
    },
    __config = {
        __curve_names = {"Camera", "Random", "Accelerated", "Backwards", "Slow", "High", "Left", "Right"},
        __detections = {
            __infinity     = true,
            __deathslash   = true,
            __timehole     = true,
            __slashesoffury = true,
            __phantom      = false,
            __dribble      = false,
        },
    },
    __triggerbot = {
        __enabled     = false,
        __is_parrying = false,
        __parries     = 0,
        __max_parries = 10000,
        __parry_delay = 0.5,
    },
}

-- ============================================================
-- 4. HELPERS
-- ============================================================
local function update_divisor()
    System.__properties.__divisor_multiplier =
        0.7 + (System.__properties.__accuracy - 1) * 0.0035353535353535
end

local function update_randomized_accuracy()
    if not System.__properties.__humanizer_enabled then return end
    local props = System.__properties
    local now = os.clock()
    if now < props.__humanizer_last_update + props.__humanizer_next_change then return end
    props.__humanizer_last_update = now

    local ping_str = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping = tonumber(ping_str:match("%d+")) or 0
    local min_h = math.clamp(props.__humanizer_min_accuracy, 1, 50)
    local max_h = math.clamp(props.__humanizer_max_accuracy, 1, 50)
    if min_h > max_h then min_h, max_h = max_h, min_h end

    local current = math.clamp(props.__accuracy, min_h, max_h)
    local span    = math.max(1, max_h - min_h)
    local ping_factor = ping >= 90 and 0.75 or (ping <= 50 and 1.25 or 1)
    local roll = math.random(1, 100)
    local new_acc
    if ping >= 90 then
        new_acc = math.clamp(current + math.random(-1, 1), min_h, max_h)
    elseif roll <= 45 then
        new_acc = math.clamp(current + math.random(-2, 2), min_h, max_h)
    elseif roll <= 80 then
        local drift = math.random(2, math.max(3, math.floor(span * 0.2)))
        local dir = math.random() < 0.5 and -drift or drift
        new_acc = math.clamp(current + dir, min_h, max_h)
    else
        new_acc = math.random(min_h, max_h)
    end
    if new_acc then
        props.__accuracy = new_acc
        props.__humanizer_next_change = math.random(0.7, 1.4) / ping_factor
        update_divisor()
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if System.__properties.__humanizer_enabled then
            pcall(update_randomized_accuracy)
        end
    end
end)

-- ============================================================
-- 5. BALL / PLAYER / CURVE / PARRY / DETECTION
-- ============================================================
System.animation = {}
function System.animation.play_grab_parry() end

System.ball = {}
function System.ball.get()
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return nil end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then
            ball.CanCollide = false
            return ball
        end
    end
    return nil
end

function System.ball.get_all()
    local out = {}
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return out end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then
            ball.CanCollide = false
            table.insert(out, ball)
        end
    end
    return out
end

System.player = {}
local Closest_Entity = nil

function System.player.get_closest()
    local max_d = math.huge
    local closest = nil
    if not Alive then return nil end
    for _, entity in pairs(Alive:GetChildren()) do
        if entity ~= LocalPlayer.Character and entity.PrimaryPart then
            local d = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
            if d < max_d then max_d = d; closest = entity end
        end
    end
    Closest_Entity = closest
    return closest
end

function System.player.get_closest_to_cursor()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local camera = workspace.CurrentCamera
    if not Alive then return nil end
    local ok, ml = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok then ml = {X = camera.ViewportSize.X/2, Y = camera.ViewportSize.Y/2} end
    local ray = camera:ScreenPointToRay(ml.X, ml.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    local closest, min_dot = nil, -math.huge
    for _, player in pairs(Alive:GetChildren()) do
        if player ~= LocalPlayer.Character and player:FindFirstChild("HumanoidRootPart") then
            local dir = (player.HumanoidRootPart.Position - camera.CFrame.Position).Unit
            local dot = pointer.LookVector:Dot(dir)
            if dot > min_dot then min_dot = dot; closest = player end
        end
    end
    return closest
end

System.curve = {}
function System.curve.get_cframe()
    local camera = workspace.CurrentCamera
    local root   = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return camera.CFrame end
    local targetPart
    local closest = System.player.get_closest_to_cursor()
    if closest and closest:FindFirstChild("HumanoidRootPart") then targetPart = closest.HumanoidRootPart end
    local target_pos = targetPart and targetPart.Position or (root.Position + camera.CFrame.LookVector * 100)
    local fns = {
        function() return camera.CFrame end,
        function()
            local direction = (target_pos - root.Position).Unit
            local random_offset
            local attempts = 0
            repeat
                random_offset = Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
                local cd = (target_pos + random_offset - root.Position).Unit
                attempts += 1
            until direction:Dot(cd) < 0.95 or attempts > 10
            return CFrame.new(root.Position, target_pos + random_offset)
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, 5, 0)) end,
        function()
            local direction = (root.Position - target_pos).Unit
            return CFrame.new(camera.CFrame.Position, root.Position + direction * 10000 + Vector3.new(0, 1000, 0))
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, -9e18, 0)) end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, 9e18, 0)) end,
        function() local left = -camera.CFrame.RightVector * 10000; return CFrame.new(root.Position, root.Position + left) end,
        function() local right = camera.CFrame.RightVector * 10000; return CFrame.new(root.Position, root.Position + right) end,
    }
    return fns[math.clamp(System.__properties.__curve_mode, 1, #fns)]()
end

System.parry = {}
function System.parry.execute()
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    if not _PARRY_PATCH or not _PARRY_PATCH.ready then return end
    local camera = workspace.CurrentCamera
    local ok, mouse = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok then
        local vp = camera.ViewportSize
        mouse = {X = vp.X/2, Y = vp.Y/2}
    end
    local screenPositions = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok2, sp = pcall(function() return camera:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                if ok2 then screenPositions[entity.Name] = sp end
            end
        end
    end
    local curveCF = System.curve.get_cframe() or camera.CFrame
    local mouseLocation = {mouse.X, mouse.Y}
    _PARRY_PATCH.fire(curveCF, screenPositions, mouseLocation)
    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end
    end)
end

function System.parry.keypress()
    System.parry.execute()
end

function System.parry.execute_action()
    System.animation.play_grab_parry()
    System.parry.execute()
end

local function linear_predict(a, b, t) return a + (b - a) * t end

System.detection = {
    __ball_properties = {
        __aerodynamic_time = tick(),
        __last_warping     = tick(),
        __lerp_radians     = 0,
        __curving          = tick(),
    },
}

function System.detection.is_curved()
    local bp   = System.detection.__ball_properties
    local ball = System.ball.get()
    if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end
    local velocity = zoomies.VectorVelocity or Vector3.new()
    local speed    = velocity.Magnitude
    if speed == 0 then return false end
    local ball_direction = velocity.Unit
    local dv = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if dv.Magnitude == 0 then return false end
    local direction = dv.Unit
    local dot = direction:Dot(ball_direction)
    local speed_threshold = math.min(speed / 100, 40)
    local dir_diff = ball_direction - velocity
    local dir_sim = 0
    if dir_diff.Magnitude > 0 then dir_sim = direction:Dot(dir_diff.Unit) end
    local dot_difference = dot - dir_sim
    local distance = dv.Magnitude
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local dot_thr = 0.5 - (ping / 1000)
    local reach = distance / speed - (ping / 1000)
    local bdt = 15 - math.min(distance / 1000, 15) + speed_threshold
    local clamped = math.clamp(dot, -1, 1)
    local radians = math.rad(math.asin(clamped))
    bp.__lerp_radians = linear_predict(bp.__lerp_radians, radians, 0.8)
    if speed > 0 and reach > ping / 10 then bdt = math.max(bdt - 15, 15) end
    if distance < bdt then return false end
    if dot_difference < dot_thr then return true end
    if bp.__lerp_radians < 0.018 then bp.__last_warping = tick() end
    if (tick() - bp.__last_warping) < (reach / 1.5) then return true end
    if (tick() - bp.__curving) < (reach / 1.5) then return true end
    return dot < dot_thr
end

-- ============================================================
-- 6. DETECTION HOOKS
-- ============================================================
local RS = replicated_storage
RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, d)
    System.__properties.__deathslash_active = d or false
end)
RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b)
    System.__properties.__infinity_active = b or false
end)

local netFolder = RS.Packages._Index["sleitnick_net@0.1.0"].net
netFolder["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
    local p = ({...})[1]
    if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
        System.__properties.__timehole_active = true
    end
end)
netFolder["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
    System.__properties.__timehole_active = false
end)
netFolder["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    local p = ({...})[1]
    if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
        System.__properties.__slashesoffury_active = true
        System.__properties.__slashesoffury_count  = 0
    end
end)
netFolder["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_active = false
    System.__properties.__slashesoffury_count  = 0
end)
netFolder["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_count += 1
end)
netFolder["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    task.spawn(function()
        while System.__properties.__slashesoffury_active
              and System.__properties.__slashesoffury_count < maxParryCount do
            if System.__config.__detections.__slashesoffury then
                System.parry.execute()
                task.wait(parryDelay)
            else break end
        end
    end)
end)

Runtime.ChildAdded:Connect(function(Object)
    if not System.__config.__detections.__phantom then return end
    if Object.Name == "maxTransmission" or Object.Name == "transmissionpart" then
        local Weld = Object:FindFirstChildWhichIsA("WeldConstraint")
        if not Weld then return end
        local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        if not Character or Weld.Part1 ~= Character.HumanoidRootPart then return end
        local CurrentBall = System.ball.get()
        Weld:Destroy()
        if not CurrentBall then return end
        local FocusConnection
        FocusConnection = RunService.RenderStepped:Connect(function()
            local highlighted = CurrentBall:GetAttribute("highlighted")
            if highlighted == true then
                RS.Remotes.AbilityButtonPress:Fire()
                System.__properties.__parried = true
                task.delay(1, function() System.__properties.__parried = false end)
            elseif highlighted == false then
                FocusConnection:Disconnect()
            end
        end)
        task.delay(3, function()
            if FocusConnection and FocusConnection.Connected then FocusConnection:Disconnect() end
        end)
    end
end)

RS.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, root)
    if root.Parent and root.Parent ~= LocalPlayer.Character then
        if not Alive or root.Parent.Parent ~= Alive then return end
    end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
    local closest = System.player.get_closest()
    local ball = System.ball.get()
    if not ball or not closest or not closest.PrimaryPart then return end
    local td = (LocalPlayer.Character.PrimaryPart.Position - closest.PrimaryPart.Position).Magnitude
    local dv = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if dv.Magnitude == 0 then return end
    local distance = dv.Magnitude
    local direction = dv.Unit
    local bv = ball.AssemblyLinearVelocity or Vector3.new()
    if bv.Magnitude == 0 then return end
    local dot = direction:Dot(bv.Unit)
    local curved = System.detection.is_curved()
    if td < 15 and distance < 15 and dot > -0.25 then
        if curved then System.parry.execute_action() end
    end
    if System.__properties.__grab_animation then
        System.__properties.__grab_animation:Stop()
    end
end)

-- ============================================================
-- 7. AUTOPARRY
-- ============================================================
System.autoparry = {}
function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        local training_ball = nil
        if workspace:FindFirstChild("TrainingBalls") then
            for _, inst in pairs(workspace.TrainingBalls:GetChildren()) do
                if inst:GetAttribute("realBall") then training_ball = inst; break end
            end
        end
        for _, ball in pairs(balls) do
            if not ball then continue end
            local zoomies = ball:FindFirstChild("zoomies")
            if not zoomies then continue end
            ball:GetAttributeChangedSignal("target"):Once(function()
                System.__properties.__parried = false
            end)
            if System.__properties.__parried then continue end
            local ball_target = ball:GetAttribute("target")
            local velocity = zoomies.VectorVelocity
            local distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
            local ping_thr = math.clamp(ping / 10, 5, 17)
            local speed = velocity.Magnitude
            local capped = math.min(math.max(speed - 9.5, 0), 650)
            local speed_div = (2.4 + capped * 0.002) * System.__properties.__divisor_multiplier
            local parry_acc = ping_thr + math.max(speed / speed_div, 9.5)
            local curved = System.detection.is_curved()
            if ball:FindFirstChild("AeroDynamicSlashVFX") then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            if Runtime:FindFirstChild("Tornado") then
                local tt = Runtime.Tornado:GetAttribute("TornadoTime") or 1
                if (tick() - System.__properties.__tornado_time) < tt + 0.314159 then continue end
            end
            if one_ball and one_ball:GetAttribute("target") == LocalPlayer.Name and curved then continue end
            if ball:FindFirstChild("ComboCounter") then continue end
            if LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape") then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            if ball_target == LocalPlayer.Name and distance <= parry_acc then
                System.parry.execute()
                System.__properties.__parried = true
            end
            local last_parrys = tick()
            repeat RunService.Stepped:Wait() until (tick() - last_parrys) >= 1 or not System.__properties.__parried
            System.__properties.__parried = false
        end
        if training_ball then
            local zoomies = training_ball:FindFirstChild("zoomies")
            if zoomies then
                training_ball:GetAttributeChangedSignal("target"):Once(function()
                    System.__properties.__training_parried = false
                end)
                if not System.__properties.__training_parried then
                    local bt = training_ball:GetAttribute("target")
                    local v = zoomies.VectorVelocity
                    local d = LocalPlayer:DistanceFromCharacter(training_ball.Position)
                    local s = v.Magnitude
                    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                    local pt = math.clamp(ping / 10, 5, 17)
                    local capped = math.min(math.max(s - 9.5, 0), 650)
                    local sd = (2.4 + capped * 0.002) * System.__properties.__divisor_multiplier
                    local acc = pt + math.max(s / sd, 9.5)
                    if bt == LocalPlayer.Name and d <= acc then
                        System.parry.execute()
                        System.__properties.__training_parried = true
                        local last_parrys = tick()
                        repeat RunService.Stepped:Wait() until (tick() - last_parrys) >= 1 or not System.__properties.__training_parried
                        System.__properties.__training_parried = false
                    end
                end
            end
        end
    end)
end

function System.autoparry.stop()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
        System.__properties.__connections.__autoparry = nil
    end
end

-- ============================================================
-- 8. AUTO SPAM — VERSI GIST ASLI (utuh)
-- ============================================================
System.auto_spam = {}

function System.auto_spam:get_entity_properties()
    System.player.get_closest()
    if not Closest_Entity or not Closest_Entity.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local entity_velocity = Closest_Entity.PrimaryPart.Velocity
    local entity_direction = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local entity_distance = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude
    return { Velocity = entity_velocity, Direction = entity_direction, Distance = entity_distance }
end

function System.auto_spam:get_ball_properties()
    local ball = System.ball.get()
    if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local ball_velocity = ball.AssemblyLinearVelocity or Vector3.new()
    local ball_origin = ball
    local ball_direction_vector = LocalPlayer.Character.PrimaryPart.Position - ball_origin.Position
    local ball_distance = ball_direction_vector.Magnitude
    local ball_direction = Vector3.new()
    local ball_dot = 0
    if ball_distance > 0 then
        ball_direction = ball_direction_vector.Unit
        if ball_velocity.Magnitude > 0 then
            ball_dot = ball_direction:Dot(ball_velocity.Unit)
        end
    end
    return { Velocity = ball_velocity, Direction = ball_direction, Distance = ball_distance, Dot = ball_dot }
end

function System.auto_spam.spam_service(self)
    local ball = System.ball.get()
    local entity = System.player.get_closest()
    if not ball or not entity or not entity.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end

    local D = 5
    local velocity = ball.AssemblyLinearVelocity or Vector3.new()
    local n = velocity.Magnitude
    if n == 0 then return D end

    local to_ball = (LocalPlayer.Character.PrimaryPart.Position - ball.Position)
    if to_ball.Magnitude == 0 then return D end

    local r = to_ball.Unit
    local t = 0
    if n > 0 and velocity.Magnitude > 0 then
        t = r:Dot(velocity.Unit)
    end

    local target_pos = entity.PrimaryPart.Position
    local X = LocalPlayer:DistanceFromCharacter(target_pos)

    local E = 1
    local Fmove = Vector3.new()
    local success, humanoid = pcall(function()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end)
    if success and humanoid and humanoid.MoveDirection then
        Fmove = humanoid.MoveDirection
    end

    local N = (target_pos - LocalPlayer.Character.PrimaryPart.Position)
    if N.Magnitude > 0 then N = N.Unit else N = Vector3.new() end
    local lmove = Vector3.new()
    if entity then
        local ehum = entity:FindFirstChildOfClass("Humanoid")
        if ehum and ehum.MoveDirection then lmove = ehum.MoveDirection end
    end

    _G.Last_Close_Contact = _G.Last_Close_Contact or 0
    _G.In_Close_Contact = _G.In_Close_Contact or false
    local now = tick()
    if X <= 3 then _G.In_Close_Contact = true end
    if _G.In_Close_Contact and X > 3.3 then
        _G.In_Close_Contact = false
        _G.Last_Close_Contact = now
    end
    local u = (not _G.In_Close_Contact) and (now - (_G.Last_Close_Contact or 0) >= 1.5)
    if u and (Fmove.Magnitude > 0.2 and Fmove:Dot(N) < -0.4) then E = 10 end
    if u and (lmove.Magnitude > 0.2 and lmove:Dot(-N) < -0.4) then E = 10 end

    local B = (self.Ping or 50) * 0.7 + math.min(n / (E * 1.2), 80)
    if (self.Entity_Properties and self.Entity_Properties.Distance or math.huge) > B then return D end
    if (self.Ball_Properties and self.Ball_Properties.Distance or math.huge) > B then return D end
    if X > B then return D end

    local U = math.clamp(-t, 0, 1)
    local q = math.clamp(U * (n / 40), 0, 4)
    D = B - q
    return D
end

function System.auto_spam.start()
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
    end
    System.__properties.__auto_spam_enabled = true
    System.__properties.__connections.__auto_spam = RunService.PreSimulation:Connect(function()
        local ball = System.ball.get()
        if not ball then return end
        if System.__properties.__slashesoffury_active then return end
        local zoomies = ball:FindFirstChild("zoomies")
        if not zoomies then return end
        System.player.get_closest()
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        local ping_threshold = math.clamp(ping / 10, 1, 16)
        local ball_target = ball:GetAttribute("target")
        local ball_properties = System.auto_spam:get_ball_properties()
        local entity_properties = System.auto_spam:get_entity_properties()
        if not ball_properties or not entity_properties then return end
        local spam_accuracy = System.auto_spam.spam_service({
            Ball_Properties = ball_properties,
            Entity_Properties = entity_properties,
            Ping = ping_threshold,
        })
        local target_position = Closest_Entity.PrimaryPart.Position
        local target_distance = LocalPlayer:DistanceFromCharacter(target_position)
        if zoomies.VectorVelocity.Magnitude == 0 then return end
        local direction = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit
        local ball_direction = zoomies.VectorVelocity.Unit
        local dot = direction:Dot(ball_direction)
        local distance = LocalPlayer:DistanceFromCharacter(ball.Position)
        if not ball_target then return end
        if target_distance > spam_accuracy or distance > spam_accuracy then return end
        local pulsed = LocalPlayer.Character:GetAttribute("Pulsed")
        if pulsed then return end
        if ball_target == LocalPlayer.Name and target_distance > 30 and distance > 30 then return end
        if distance <= spam_accuracy and System.__properties.__parries > System.__properties.__spam_threshold then
            System.parry.execute()
        end
    end)
end

function System.auto_spam.stop()
    System.__properties.__auto_spam_enabled = false
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
        System.__properties.__connections.__auto_spam = nil
    end
end

-- ============================================================
-- 9. UI LIBRARY — Azure
-- ============================================================
local Connections = setmetatable({
    disconnect = function(self, c)
        if not self[c] then return end
        self[c]:Disconnect()
        self[c] = nil
    end,
    disconnect_all = function(self)
        for _, v in self do
            if typeof(v) == "function" then continue end
            v:Disconnect()
        end
    end,
}, { __index = {} })

local Config = setmetatable({
    save = function(self, file_name, config)
        pcall(function()
            if not writefile then return end
            local flags = HttpService:JSONEncode(config)
            writefile("Azure/" .. file_name .. ".json", flags)
        end)
    end,
    load = function(self, file_name, config)
        local result
        pcall(function()
            if not isfile or not isfile("Azure/" .. file_name .. ".json") then return end
            local flags = readfile("Azure/" .. file_name .. ".json")
            if not flags then return end
            result = HttpService:JSONDecode(flags)
        end)
        if not result then
            result = { _flags = {}, _keybinds = {}, _library = {} }
        end
        return result
    end,
}, { __index = {} })

local Library = {
    _config = Config:load(game.GameId),
    _device = nil,
    _ui_open = true,
    _ui_scale = 1,
    _ui_loaded = false,
    _ui = nil,
    _tab = 0,
    _dragging = false,
    _drag_start = nil,
    _container_position = nil,
}
Library.__index = Library

function Library:get_screen_scale()
    local vp_x = workspace.CurrentCamera.ViewportSize.X
    self._ui_scale = vp_x / 1400
end

function Library:get_device()
    local device = "Unknown"
    if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        device = "PC"
    elseif UserInputService.TouchEnabled then
        device = "Mobile"
    elseif UserInputService.GamepadEnabled then
        device = "Console"
    end
    self._device = device
end

function Library:flag_type(flag, flag_type)
    if not Library._config._flags[flag] then return end
    return typeof(Library._config._flags[flag]) == flag_type
end

function Library:create_ui()
    local old = CoreGui:FindFirstChild("Azure")
    if old then old:Destroy() end

    local AzureUI = Instance.new("ScreenGui")
    AzureUI.ResetOnSpawn = false
    AzureUI.Name = "Azure"
    AzureUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AzureUI.IgnoreGuiInset = true
    AzureUI.Parent = CoreGui

    local Container = Instance.new("Frame")
    Container.ClipsDescendants = true
    Container.AnchorPoint = Vector2.new(0.5, 0.5)
    Container.Name = "Container"
    Container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Container.Position = UDim2.new(0.5, 0, 0.5, 0)
    Container.Size = UDim2.new(0, 0, 0, 0)
    Container.Active = true
    Container.BorderSizePixel = 0
    Container.ZIndex = 2
    Container.Parent = AzureUI

    local ContainerGradient = Instance.new("UIGradient")
    ContainerGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.10, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.12, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0))
    }
    ContainerGradient.Rotation = 90
    ContainerGradient.Parent = Container

    local SideBar = Instance.new("Frame")
    SideBar.Name = "GradientSide"
    SideBar.Parent = Container
    SideBar.Size = UDim2.new(0, 10, 1, 0)
    SideBar.Position = UDim2.new(0, 0, 0, 0)
    SideBar.BackgroundTransparency = 1

    local SideGradient = Instance.new("UIGradient")
    SideGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(30, 30, 34)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(55, 110, 190)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(110, 80, 200))
    }
    SideGradient.Rotation = 90
    SideGradient.Parent = SideBar

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = Container

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(78, 92, 122)
    UIStroke.Thickness = 1
    UIStroke.Transparency = 0.28
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = Container

    local Handler = Instance.new("Frame")
    Handler.BackgroundTransparency = 1
    Handler.Name = "Handler"
    Handler.Size = UDim2.new(0, 750, 0, 530)
    Handler.BorderSizePixel = 0
    Handler.Parent = Container

    local Tabs = Instance.new("ScrollingFrame")
    Tabs.ScrollBarImageTransparency = 1
    Tabs.ScrollBarThickness = 0
    Tabs.Name = "Tabs"
    Tabs.Size = UDim2.new(0, 140, 0, 445)
    Tabs.Selectable = false
    Tabs.AutomaticCanvasSize = Enum.AutomaticSize.XY
    Tabs.BackgroundTransparency = 1
    Tabs.Position = UDim2.new(0.026, 0, 0.111, 10)
    Tabs.BorderSizePixel = 0
    Tabs.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    Tabs.Parent = Handler

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 4)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = Tabs

    local ClientName = Instance.new("TextLabel")
    ClientName.Font = Enum.Font.GothamBold
    ClientName.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClientName.Text = "Azure hub"
    ClientName.Size = UDim2.new(0, 100, 0, 13)
    ClientName.AnchorPoint = Vector2.new(0, 0.5)
    ClientName.Position = UDim2.new(0.06, 0, 0.049, 1.5)
    ClientName.BackgroundTransparency = 1
    ClientName.TextXAlignment = Enum.TextXAlignment.Left
    ClientName.TextSize = 16
    ClientName.Parent = Handler

    local Divider = Instance.new("Frame")
    Divider.BackgroundTransparency = 0.5
    Divider.Position = UDim2.new(0.225, 0, 0, 68)
    Divider.Size = UDim2.new(0, 1, 0, 440)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Divider.Parent = Handler

    local Sections = Instance.new("Folder")
    Sections.Name = "Sections"
    Sections.Parent = Handler

    local Minimize = Instance.new("TextButton")
    Minimize.Text = ""
    Minimize.AutoButtonColor = false
    Minimize.BackgroundTransparency = 1
    Minimize.Position = UDim2.new(0.02, 0, 0.029, 0)
    Minimize.Size = UDim2.new(0, 24, 0, 24)
    Minimize.Parent = Handler

    local MinimizeLabel = Instance.new("TextLabel")
    MinimizeLabel.Size = UDim2.new(1, 0, 1, 0)
    MinimizeLabel.BackgroundTransparency = 1
    MinimizeLabel.Text = "—"
    MinimizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeLabel.TextSize = 20
    MinimizeLabel.Font = Enum.Font.GothamBold
    MinimizeLabel.Parent = Minimize

    local UIScale = Instance.new("UIScale")
    UIScale.Parent = Container

    self._ui = AzureUI

    Container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._drag_start = input.Position
            self._container_position = Container.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    self._dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not self._dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - self._drag_start
            Container.Position = UDim2.new(
                self._container_position.X.Scale,
                self._container_position.X.Offset + delta.X,
                self._container_position.Y.Scale,
                self._container_position.Y.Offset + delta.Y
            )
        end
    end)

    function self:load()
        self:get_device()
        if self._device == "Mobile" or self._device == "Unknown" then
            self:get_screen_scale()
            UIScale.Scale = self._ui_scale
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                self:get_screen_scale()
                UIScale.Scale = self._ui_scale
            end)
        end
        TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
            Size = UDim2.fromOffset(750, 530)
        }):Play()
        self._ui_loaded = true
    end

    Minimize.MouseButton1Click:Connect(function()
        TweenService:Create(Container, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
            Size = UDim2.fromOffset(104.5, 52)
        }):Play()
    end)

    function self:update_tabs(tab)
        for _, object in Tabs:GetChildren() do
            if object.Name ~= "Tab" then continue end
            if object == tab then
                TweenService:Create(object, TweenInfo.new(0.4), {
                    BackgroundTransparency = 0.85,
                    BackgroundColor3 = Color3.fromRGB(220, 220, 220)
                }):Play()
                TweenService:Create(object.TextLabel, TweenInfo.new(0.4), {
                    TextTransparency = 0.3, TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
            else
                TweenService:Create(object, TweenInfo.new(0.4), {
                    BackgroundTransparency = 1
                }):Play()
                TweenService:Create(object.TextLabel, TweenInfo.new(0.4), {
                    TextTransparency = 0.6, TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
            end
        end
    end

    function self:update_sections(left, right)
        for _, object in Sections:GetChildren() do
            if object == left or object == right then
                object.Visible = true
            else
                object.Visible = false
            end
        end
    end

    function self:create_tab(title)
        local TabManager = {}
        local LayoutOrder = 0
        local first_tab = not Tabs:FindFirstChild("Tab")

        local Tab = Instance.new("TextButton")
        Tab.Font = Enum.Font.GothamBold
        Tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        Tab.Text = ""
        Tab.AutoButtonColor = false
        Tab.BackgroundTransparency = 1
        Tab.Name = "Tab"
        Tab.Size = UDim2.new(0, 129, 0, 38)
        Tab.BorderSizePixel = 0
        Tab.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        Tab.Parent = Tabs
        Tab.LayoutOrder = self._tab

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 8)
        UICorner.Parent = Tab

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Font = Enum.Font.GothamBold
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextTransparency = 0.7
        TextLabel.Text = title
        TextLabel.Size = UDim2.new(0, 100, 0, 16)
        TextLabel.AnchorPoint = Vector2.new(0, 0.5)
        TextLabel.Position = UDim2.new(0.24, 0, 0.5, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.TextSize = 13
        TextLabel.Parent = Tab

        local LeftSection = Instance.new("ScrollingFrame")
        LeftSection.Name = "LeftSection"
        LeftSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        LeftSection.ScrollBarThickness = 0
        LeftSection.Size = UDim2.new(0, 243, 0, 445)
        LeftSection.Selectable = false
        LeftSection.AnchorPoint = Vector2.new(0, 0.5)
        LeftSection.BackgroundTransparency = 1
        LeftSection.Position = UDim2.new(0.259, 0, 0.5, 25)
        LeftSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        LeftSection.Visible = false
        LeftSection.Parent = Sections

        local UIListLayoutL = Instance.new("UIListLayout")
        UIListLayoutL.Padding = UDim.new(0, 18)
        UIListLayoutL.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayoutL.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayoutL.Parent = LeftSection

        local UIPaddingL = Instance.new("UIPadding")
        UIPaddingL.PaddingTop = UDim.new(0, 1)
        UIPaddingL.Parent = LeftSection

        local RightSection = Instance.new("ScrollingFrame")
        RightSection.Name = "RightSection"
        RightSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        RightSection.ScrollBarThickness = 0
        RightSection.Size = UDim2.new(0, 243, 0, 445)
        RightSection.Selectable = false
        RightSection.AnchorPoint = Vector2.new(0, 0.5)
        RightSection.BackgroundTransparency = 1
        RightSection.Position = UDim2.new(0.629, 0, 0.5, 25)
        RightSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        RightSection.Visible = false
        RightSection.Parent = Sections

        local UIListLayoutR = Instance.new("UIListLayout")
        UIListLayoutR.Padding = UDim.new(0, 18)
        UIListLayoutR.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayoutR.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayoutR.Parent = RightSection

        local UIPaddingR = Instance.new("UIPadding")
        UIPaddingR.PaddingTop = UDim.new(0, 1)
        UIPaddingR.Parent = RightSection

        self._tab += 1
        if first_tab then
            self:update_tabs(Tab)
            self:update_sections(LeftSection, RightSection)
        end

        Tab.MouseButton1Click:Connect(function()
            self:update_tabs(Tab)
            self:update_sections(LeftSection, RightSection)
        end)

        function TabManager:create_module(settings)
            LayoutOrder = LayoutOrder + 1
            local ModuleManager = { _state = false, _size = 0, _multiplier = 0 }
            if settings.section == "right" then settings.section = RightSection else settings.section = LeftSection end

            local Module = Instance.new("Frame")
            Module.ClipsDescendants = true
            Module.BackgroundTransparency = 0.02
            Module.Position = UDim2.new(0.004, 0, 0, -5)
            Module.Name = "Module"
            Module.Size = UDim2.new(0, 241, 0, 93)
            Module.BorderSizePixel = 0
            Module.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
            Module.Parent = settings.section

            local UIListLayout = Instance.new("UIListLayout")
            UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout.Parent = Module

            local UICorner = Instance.new("UICorner")
            UICorner.CornerRadius = UDim.new(0, 8)
            UICorner.Parent = Module

            local UIStroke = Instance.new("UIStroke")
            UIStroke.Color = Color3.fromRGB(255, 255, 255)
            UIStroke.Transparency = 0.72
            UIStroke.Thickness = 1
            UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            UIStroke.Parent = Module

            local Header = Instance.new("TextButton")
            Header.Text = ""
            Header.AutoButtonColor = false
            Header.BackgroundTransparency = 1
            Header.Name = "Header"
            Header.Size = UDim2.new(0, 241, 0, 93)
            Header.BorderSizePixel = 0
            Header.Parent = Module

            local ModuleName = Instance.new("TextLabel")
            ModuleName.Font = Enum.Font.GothamSemiBold
            ModuleName.TextColor3 = Color3.fromRGB(255, 255, 255)
            ModuleName.TextTransparency = 0.2
            ModuleName.Text = settings.title or "Module"
            ModuleName.Size = UDim2.new(0, 205, 0, 13)
            ModuleName.AnchorPoint = Vector2.new(0, 0.5)
            ModuleName.Position = UDim2.new(0.073, 0, 0.24, 0)
            ModuleName.BackgroundTransparency = 1
            ModuleName.TextXAlignment = Enum.TextXAlignment.Left
            ModuleName.TextSize = 13
            ModuleName.Parent = Header

            local Description = Instance.new("TextLabel")
            Description.Font = Enum.Font.Gotham
            Description.TextColor3 = Color3.fromRGB(255, 255, 255)
            Description.TextTransparency = 0.7
            Description.Text = settings.description or ""
            Description.Size = UDim2.new(0, 205, 0, 13)
            Description.AnchorPoint = Vector2.new(0, 0.5)
            Description.Position = UDim2.new(0.073, 0, 0.42, 0)
            Description.BackgroundTransparency = 1
            Description.TextXAlignment = Enum.TextXAlignment.Left
            Description.TextSize = 10
            Description.Parent = Header

            local Toggle = Instance.new("Frame")
            Toggle.BackgroundTransparency = 0.7
            Toggle.Position = UDim2.new(0.82, 0, 0.757, 0)
            Toggle.Size = UDim2.new(0, 25, 0, 12)
            Toggle.BorderSizePixel = 0
            Toggle.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
            Toggle.Parent = Header

            local UICornerT = Instance.new("UICorner")
            UICornerT.CornerRadius = UDim.new(1, 0)
            UICornerT.Parent = Toggle

            local Circle = Instance.new("Frame")
            Circle.AnchorPoint = Vector2.new(0, 0.5)
            Circle.BackgroundTransparency = 0.2
            Circle.Position = UDim2.new(0, 0, 0.5, 0)
            Circle.Size = UDim2.new(0, 12, 0, 12)
            Circle.BorderSizePixel = 0
            Circle.BackgroundColor3 = Color3.fromRGB(120, 120, 132)
            Circle.Parent = Toggle

            local UICornerC = Instance.new("UICorner")
            UICornerC.CornerRadius = UDim.new(1, 0)
            UICornerC.Parent = Circle

            local Divider = Instance.new("Frame")
            Divider.AnchorPoint = Vector2.new(0.5, 0)
            Divider.BackgroundTransparency = 0.7
            Divider.Position = UDim2.new(0.5, 0, 0.62, 0)
            Divider.Size = UDim2.new(0, 241, 0, 1)
            Divider.BorderSizePixel = 0
            Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Divider.Parent = Header

            local Options = Instance.new("Frame")
            Options.Name = "Options"
            Options.BackgroundTransparency = 1
            Options.Position = UDim2.new(0, 0, 1, 0)
            Options.Size = UDim2.new(0, 241, 0, 8)
            Options.BorderSizePixel = 0
            Options.Parent = Module

            local UIPadding = Instance.new("UIPadding")
            UIPadding.PaddingTop = UDim.new(0, 8)
            UIPadding.Parent = Options

            local UIListLayout2 = Instance.new("UIListLayout")
            UIListLayout2.Padding = UDim.new(0, 5)
            UIListLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout2.Parent = Options

            function ModuleManager:change_state(state)
                self._state = state
                if self._state then
                    TweenService:Create(Module, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                        Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                    }):Play()
                    TweenService:Create(Toggle, TweenInfo.new(0.4), {
                        BackgroundColor3 = Color3.fromRGB(205, 205, 220)
                    }):Play()
                    TweenService:Create(Circle, TweenInfo.new(0.4), {
                        BackgroundColor3 = Color3.fromRGB(245, 245, 250),
                        Position = UDim2.fromScale(0.53, 0.5)
                    }):Play()
                else
                    TweenService:Create(Module, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                        Size = UDim2.fromOffset(241, 93)
                    }):Play()
                    TweenService:Create(Toggle, TweenInfo.new(0.4), {
                        BackgroundColor3 = Color3.fromRGB(44, 44, 52)
                    }):Play()
                    TweenService:Create(Circle, TweenInfo.new(0.4), {
                        BackgroundColor3 = Color3.fromRGB(120, 120, 132),
                        Position = UDim2.fromScale(0, 0.5)
                    }):Play()
                end
                Library._config._flags[settings.flag] = self._state
                Config:save(game.GameId, Library._config)
                settings.callback(self._state)
            end

            if Library:flag_type(settings.flag, "boolean") then
                ModuleManager._state = true
                pcall(function() settings.callback(true) end)
                Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle.Position = UDim2.fromScale(0.53, 0.5)
            end

            Header.MouseButton1Click:Connect(function()
                ModuleManager:change_state(not ModuleManager._state)
            end)

            function ModuleManager:create_slider(s)
                if self._size == 0 then self._size = 11 end
                self._size += 27
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local Slider = Instance.new("TextButton")
                Slider.Text = ""
                Slider.AutoButtonColor = false
                Slider.BackgroundTransparency = 1
                Slider.Size = UDim2.new(0, 207, 0, 22)
                Slider.BorderSizePixel = 0
                Slider.Parent = Options

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Font = Enum.Font.GothamSemiBold
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextTransparency = 0.2
                TextLabel.Text = s.title
                TextLabel.Size = UDim2.new(0, 153, 0, 13)
                TextLabel.Position = UDim2.new(0, 0, 0.05, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.TextSize = 11
                TextLabel.Parent = Slider

                local Drag = Instance.new("Frame")
                Drag.AnchorPoint = Vector2.new(0.5, 1)
                Drag.BackgroundTransparency = 0.7
                Drag.Position = UDim2.new(0.5, 0, 0.95, 0)
                Drag.Size = UDim2.new(0, 207, 0, 4)
                Drag.BorderSizePixel = 0
                Drag.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
                Drag.Parent = Slider

                local UICornerD = Instance.new("UICorner")
                UICornerD.CornerRadius = UDim.new(1, 0)
                UICornerD.Parent = Drag

                local Fill = Instance.new("Frame")
                Fill.AnchorPoint = Vector2.new(0, 0.5)
                Fill.BackgroundTransparency = 0.15
                Fill.Position = UDim2.new(0, 0, 0.5, 0)
                Fill.Size = UDim2.new(0, 103, 0, 4)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Fill.Parent = Drag

                local UICornerF = Instance.new("UICorner")
                UICornerF.CornerRadius = UDim.new(0, 3)
                UICornerF.Parent = Fill

                local Circle2 = Instance.new("Frame")
                Circle2.AnchorPoint = Vector2.new(1, 0.5)
                Circle2.Position = UDim2.new(1, 0, 0.5, 0)
                Circle2.Size = UDim2.new(0, 6, 0, 6)
                Circle2.BorderSizePixel = 0
                Circle2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle2.Parent = Fill

                local UICornerC2 = Instance.new("UICorner")
                UICornerC2.CornerRadius = UDim.new(1, 0)
                UICornerC2.Parent = Circle2

                local Value = Instance.new("TextLabel")
                Value.Font = Enum.Font.GothamSemiBold
                Value.TextColor3 = Color3.fromRGB(255, 255, 255)
                Value.TextTransparency = 0.2
                Value.Text = "0"
                Value.Size = UDim2.new(0, 42, 0, 13)
                Value.AnchorPoint = Vector2.new(1, 0)
                Value.Position = UDim2.new(1, 0, 0, 0)
                Value.BackgroundTransparency = 1
                Value.TextXAlignment = Enum.TextXAlignment.Right
                Value.TextSize = 10
                Value.Parent = Slider

                local SliderManager = {}

                function SliderManager:set_percentage(pct)
                    local rounded_number
                    if s.round_number then
                        rounded_number = math.floor(pct)
                    else
                        rounded_number = math.floor(pct * 10) / 10
                    end
                    pct = (pct - s.minimum_value) / (s.maximum_value - s.minimum_value)
                    local slider_size = math.clamp(pct, 0.02, 1) * Drag.AbsoluteSize.X
                    local number_threshold = math.clamp(rounded_number, s.minimum_value, s.maximum_value)
                    Library._config._flags[s.flag] = number_threshold
                    Value.Text = number_threshold
                    TweenService:Create(Fill, TweenInfo.new(0.2), {
                        Size = UDim2.fromOffset(slider_size, Drag.AbsoluteSize.Y)
                    }):Play()
                    s.callback(number_threshold)
                end

                function SliderManager:update()
                    local mouse = UserInputService:GetMouseLocation()
                    local mouse_position = (mouse.X - Drag.AbsolutePosition.X) / Drag.AbsoluteSize.X
                    local pct = s.minimum_value + (s.maximum_value - s.minimum_value) * mouse_position
                    self:set_percentage(pct)
                end

                function SliderManager:input()
                    SliderManager:update()
                    Connections["slider_drag_" .. s.flag] = UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch then
                            SliderManager:update()
                        end
                    end)
                    Connections["slider_input_" .. s.flag] = UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        Connections:disconnect("slider_drag_" .. s.flag)
                        Connections:disconnect("slider_input_" .. s.flag)
                        Config:save(game.GameId, Library._config)
                    end)
                end

                if Library:flag_type(s.flag, "number") then
                    SliderManager:set_percentage(Library._config._flags[s.flag])
                else
                    SliderManager:set_percentage(s.value)
                end

                Slider.MouseButton1Down:Connect(function()
                    SliderManager:input()
                end)

                return SliderManager
            end

            function ModuleManager:create_checkbox(s)
                if self._size == 0 then self._size = 11 end
                self._size += 20
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local CheckboxManager = { _state = false }

                local Checkbox = Instance.new("TextButton")
                Checkbox.Text = ""
                Checkbox.AutoButtonColor = false
                Checkbox.BackgroundTransparency = 1
                Checkbox.Size = UDim2.new(0, 207, 0, 15)
                Checkbox.BorderSizePixel = 0
                Checkbox.Parent = Options

                local TitleLabel = Instance.new("TextLabel")
                TitleLabel.Font = Enum.Font.GothamSemiBold
                TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TitleLabel.TextTransparency = 0.2
                TitleLabel.Text = s.title
                TitleLabel.Size = UDim2.new(0, 142, 0, 13)
                TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
                TitleLabel.Position = UDim2.new(0, 0, 0.5, 0)
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                TitleLabel.TextSize = 11
                TitleLabel.Parent = Checkbox

                local Box = Instance.new("Frame")
                Box.AnchorPoint = Vector2.new(1, 0.5)
                Box.BackgroundTransparency = 0.9
                Box.Position = UDim2.new(1, 0, 0.5, 0)
                Box.Size = UDim2.new(0, 15, 0, 15)
                Box.BorderSizePixel = 0
                Box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
                Box.Parent = Checkbox

                local BoxCorner = Instance.new("UICorner")
                BoxCorner.CornerRadius = UDim.new(0, 7)
                BoxCorner.Parent = Box

                local Fill = Instance.new("Frame")
                Fill.AnchorPoint = Vector2.new(0.5, 0.5)
                Fill.BackgroundTransparency = 0.2
                Fill.Position = UDim2.new(0.5, 0, 0.5, 0)
                Fill.Size = UDim2.fromOffset(0, 0)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
                Fill.Parent = Box

                local FillCorner = Instance.new("UICorner")
                FillCorner.CornerRadius = UDim.new(0, 6)
                FillCorner.Parent = Fill

                function CheckboxManager:change_state(state)
                    self._state = state
                    if state then
                        TweenService:Create(Box, TweenInfo.new(0.3), { BackgroundTransparency = 0.7 }):Play()
                        TweenService:Create(Fill, TweenInfo.new(0.3), { Size = UDim2.fromOffset(9, 9) }):Play()
                    else
                        TweenService:Create(Box, TweenInfo.new(0.3), { BackgroundTransparency = 0.9 }):Play()
                        TweenService:Create(Fill, TweenInfo.new(0.3), { Size = UDim2.fromOffset(0, 0) }):Play()
                    end
                    Library._config._flags[s.flag] = self._state
                    Config:save(game.GameId, Library._config)
                    s.callback(self._state)
                end

                if Library:flag_type(s.flag, "boolean") then
                    CheckboxManager:change_state(Library._config._flags[s.flag])
                end

                Checkbox.MouseButton1Click:Connect(function()
                    CheckboxManager:change_state(not CheckboxManager._state)
                end)

                return CheckboxManager
            end

            function ModuleManager:create_dropdown(s)
                LayoutOrder = LayoutOrder + 1
                local DropdownManager = { _state = false, _size = 0 }

                if self._size == 0 then self._size = 11 end
                self._size += 44
                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local Dropdown = Instance.new("TextButton")
                Dropdown.Text = ""
                Dropdown.AutoButtonColor = false
                Dropdown.BackgroundTransparency = 1
                Dropdown.Size = UDim2.new(0, 207, 0, 39)
                Dropdown.BorderSizePixel = 0
                Dropdown.Parent = Options

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Font = Enum.Font.GothamSemiBold
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextTransparency = 0.2
                TextLabel.Text = s.title
                TextLabel.Size = UDim2.new(0, 207, 0, 13)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.TextSize = 11
                TextLabel.Parent = Dropdown

                local Box = Instance.new("Frame")
                Box.ClipsDescendants = true
                Box.AnchorPoint = Vector2.new(0.5, 0)
                Box.BackgroundTransparency = 0.9
                Box.Position = UDim2.new(0.5, 0, 1.2, 0)
                Box.Size = UDim2.new(0, 207, 0, 22)
                Box.BorderSizePixel = 0
                Box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
                Box.Parent = TextLabel

                local UICornerBox = Instance.new("UICorner")
                UICornerBox.CornerRadius = UDim.new(0, 4)
                UICornerBox.Parent = Box

                local CurrentOption = Instance.new("TextLabel")
                CurrentOption.Font = Enum.Font.GothamSemiBold
                CurrentOption.TextColor3 = Color3.fromRGB(255, 255, 255)
                CurrentOption.TextTransparency = 0.2
                CurrentOption.Size = UDim2.new(0, 161, 0, 13)
                CurrentOption.AnchorPoint = Vector2.new(0, 0.5)
                CurrentOption.Position = UDim2.new(0.05, 0, 0.5, 0)
                CurrentOption.BackgroundTransparency = 1
                CurrentOption.TextXAlignment = Enum.TextXAlignment.Left
                CurrentOption.TextSize = 10
                CurrentOption.Parent = Box

                local OptionsFrame = Instance.new("ScrollingFrame")
                OptionsFrame.ScrollBarThickness = 0
                OptionsFrame.Size = UDim2.new(0, 207, 0, 0)
                OptionsFrame.BackgroundTransparency = 1
                OptionsFrame.Position = UDim2.new(0, 0, 1, 0)
                OptionsFrame.CanvasSize = UDim2.new(0, 0, 0.5, 0)
                OptionsFrame.Parent = Box

                local UIListLayoutO = Instance.new("UIListLayout")
                UIListLayoutO.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayoutO.Parent = OptionsFrame

                function DropdownManager:update(option)
                    CurrentOption.Text = (typeof(option) == "string" and option) or option.Name
                    Library._config._flags[s.flag] = option
                    Config:save(game.GameId, Library._config)
                    s.callback(option)
                end

                function DropdownManager:unfold_settings()
                    self._state = not self._state
                    if self._state then
                        ModuleManager._multiplier += self._size
                        TweenService:Create(Module, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Module.Options, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(207, 39 + self._size)
                        }):Play()
                        TweenService:Create(Box, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(207, 22 + self._size)
                        }):Play()
                    else
                        ModuleManager._multiplier -= self._size
                        TweenService:Create(Module, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Module.Options, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(207, 39)
                        }):Play()
                        TweenService:Create(Box, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
                            Size = UDim2.fromOffset(207, 22)
                        }):Play()
                    end
                end

                if #s.options > 0 then
                    DropdownManager._size = 3
                    for index, value in ipairs(s.options) do
                        local Option = Instance.new("TextButton")
                        Option.Font = Enum.Font.GothamSemiBold
                        Option.TextTransparency = 0.6
                        Option.TextSize = 10
                        Option.Size = UDim2.new(0, 186, 0, 16)
                        Option.TextColor3 = Color3.fromRGB(255, 255, 255)
                        Option.Text = (typeof(value) == "string" and value) or value.Name
                        Option.AutoButtonColor = false
                        Option.BackgroundTransparency = 1
                        Option.TextXAlignment = Enum.TextXAlignment.Left
                        Option.Parent = OptionsFrame

                        Option.MouseButton1Click:Connect(function()
                            DropdownManager:update(value)
                            for _, child in OptionsFrame:GetChildren() do
                                if child.Name == "Option" then
                                    if child.Text == CurrentOption.Text then
                                        child.TextTransparency = 0.2
                                    else
                                        child.TextTransparency = 0.6
                                    end
                                end
                            end
                        end)

                        if index > (s.maximum_options or 10) then continue end
                        DropdownManager._size += 16
                        OptionsFrame.Size = UDim2.fromOffset(207, DropdownManager._size)
                    end
                end

                if Library:flag_type(s.flag, "string") then
                    DropdownManager:update(Library._config._flags[s.flag])
                else
                    DropdownManager:update(s.options[1])
                end

                Dropdown.MouseButton1Click:Connect(function()
                    DropdownManager:unfold_settings()
                end)

                return DropdownManager
            end

            return ModuleManager
        end

        return TabManager
    end

    return self
end

local library = Library.new()
library:load()

-- ============================================================
-- 10. TABS + MODULES
-- ============================================================
local MainTab = library:create_tab("Main")

-- Auto Parry
local autoparry_module = MainTab:create_module({
    title = "Auto Parry",
    description = "Auto Parry Settings",
    flag = "AutoParryModule",
    section = "left",
    callback = function(state)
        System.__properties.__autoparry_enabled = state
        if state then
            System.autoparry.start()
        else
            System.autoparry.stop()
        end
    end,
})

autoparry_module:create_dropdown({
    title = "Curve Mode",
    flag = "ModeCurve",
    options = System.__config.__curve_names,
    maximum_options = 10,
    callback = function(value)
        for i, name in ipairs(System.__config.__curve_names) do
            if name == value then
                System.__properties.__curve_mode = i
                break
            end
        end
    end,
})

autoparry_module:create_slider({
    title = "Parry Accuracy",
    flag = "ParryAccuracy",
    maximum_value = 50,
    minimum_value = 1,
    value = 1,
    round_number = true,
    callback = function(value)
        if not System.__properties.__humanizer_enabled then
            System.__properties.__accuracy = value
            update_divisor()
        end
    end,
})

-- Humanizer
local humanizer_module = MainTab:create_module({
    title = "Humanizer",
    description = "Random parry accuracy range",
    flag = "HumanizerModule",
    section = "left",
    callback = function(state)
        System.__properties.__humanizer_enabled = state
        if state then update_randomized_accuracy() end
    end,
})

humanizer_module:create_slider({
    title = "Min Accuracy",
    flag = "HumanizerMin",
    maximum_value = 50,
    minimum_value = 1,
    value = 1,
    round_number = true,
    callback = function(value)
        System.__properties.__humanizer_min_accuracy = value
    end,
})

humanizer_module:create_slider({
    title = "Max Accuracy",
    flag = "HumanizerMax",
    maximum_value = 50,
    minimum_value = 1,
    value = 50,
    round_number = true,
    callback = function(value)
        System.__properties.__humanizer_max_accuracy = value
    end,
})

-- Auto Spam
local auto_spam_module = MainTab:create_module({
    title = "Auto Spam",
    description = "Automatically spam parry",
    flag = "AutoSpamModule",
    section = "right",
    callback = function(state)
        if state then
            System.auto_spam.start()
        else
            System.auto_spam.stop()
        end
    end,
})

auto_spam_module:create_slider({
    title = "Parry Threshold",
    flag = "ParryThreshold",
    maximum_value = 3,
    minimum_value = 1,
    value = 1,
    round_number = true,
    callback = function(value)
        System.__properties.__spam_threshold = value
    end,
})

-- ============================================================
-- 11. AUTO START
-- ============================================================
update_divisor()
