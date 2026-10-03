-- BLABLA Hub — Blade Ball Script
-- Runtime: Roblox mobile / PC
-- Executor: cloneref, getupvalues, getrawmetatable, setreadonly

local cloneref = cloneref or function(o) return o end

-- ============================================================
-- PREMIUM FONT (Ubuntu)
-- ============================================================
local FONT_FAMILY = "rbxasset://fonts/families/Ubuntu.json"
local FONT = {
    reg   = Font.new(FONT_FAMILY, Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
    med   = Font.new(FONT_FAMILY, Enum.FontWeight.Medium,   Enum.FontStyle.Normal),
    semi  = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
    bold  = Font.new(FONT_FAMILY, Enum.FontWeight.Bold,     Enum.FontStyle.Normal),
    black = Font.new(FONT_FAMILY, Enum.FontWeight.Heavy,    Enum.FontStyle.Normal),
}

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

local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string" and type(args[3]) == "string"
        and type(args[4]) == "number" and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table" and type(args[7]) == "table"
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
    local timeStr    = tostring(math.floor(serverTime))
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
local CoreGui          = cloneref(game:GetService("CoreGui"))
local TweenService     = cloneref(game:GetService("TweenService"))
local Lighting         = cloneref(game:GetService("Lighting"))
local SoundService     = cloneref(game:GetService("SoundService"))
local Debris           = cloneref(game:GetService("Debris"))
local HttpService      = cloneref(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

local Alive   = workspace:FindFirstChild("Alive")   or workspace:WaitForChild("Alive")
local Runtime = workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime")

local Connections_Manager = getgenv().Connections_Manager or {}
getgenv().Connections_Manager = Connections_Manager

-- ============================================================
-- 3. STATE
-- ============================================================
local System = {
    __properties = {
        __autoparry_enabled   = false,
        __auto_spam_enabled   = false,
        __manual_spam_enabled = false,
        __curve_mode          = 1,
        __accuracy            = 100,
        __divisor_multiplier  = 1.1,
        __parried             = false,
        __training_parried    = false,
        __parries             = 0,
        __spam_threshold      = 1.5,
        __spam_accumulator    = 0,
        __spam_rate           = 1000,
        __distance_multiplier = 1,
        __humanizer_enabled      = false,
        __humanizer_min_accuracy = 1,
        __humanizer_max_accuracy = 50,
        __humanizer_last_update  = 0,
        __humanizer_next_change  = 0.8,
        __tornado_time        = tick(),
        __connections         = {},
        __infinity_active     = false,
        __deathslash_active   = false,
        __timehole_active     = false,
        __slashesoffury_active = false,
        __slashesoffury_count  = 0,
        __no_render_enabled   = false,
        __fps_boost_enabled   = false,
    },
    __config = {
        __curve_names = {"Camera", "Random", "Accelerated", "Backwards", "Slow", "High", "Left", "Right"},
        __detections = {
            __infinity      = true,
            __deathslash    = true,
            __timehole      = true,
            __slashesoffury = true,
        },
    },
}

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
    local span = math.max(1, max_h - min_h)
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
    props.__accuracy = new_acc
    props.__humanizer_next_change = math.random(0.7, 1.4) / ping_factor
    update_divisor()
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if System.__properties.__humanizer_enabled then
            pcall(update_randomized_accuracy)
        end
    end
end)

local maxParryCount = 36
local parryDelay    = 0.05

-- ============================================================
-- 4. BALL / PLAYER / CURVE / PARRY / DETECTION
-- ============================================================
System.ball = {}
function System.ball.get()
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return nil end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; return ball end
    end
    return nil
end

function System.ball.get_all()
    local out = {}
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return out end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; table.insert(out, ball) end
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
    local vp = camera.ViewportSize
    local ray     = camera:ScreenPointToRay(vp.X / 2, vp.Y / 2)
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
            local random_offset, attempts = nil, 0
            repeat
                random_offset = Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
                local cd = (target_pos + random_offset - root.Position).Unit
                attempts += 1
            until direction:Dot(cd) < 0.95 or attempts > 10
            return CFrame.new(root.Position, target_pos + random_offset)
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, 5, 0)) end,
        function()
            local dir = (root.Position - target_pos).Unit
            return CFrame.new(camera.CFrame.Position, root.Position + dir * 10000 + Vector3.new(0, 1000, 0))
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, -9e18, 0)) end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, 9e18, 0)) end,
        function() local l = -camera.CFrame.RightVector * 10000; return CFrame.new(root.Position, root.Position + l) end,
        function() local r = camera.CFrame.RightVector * 10000; return CFrame.new(root.Position, root.Position + r) end,
    }
    return fns[math.clamp(System.__properties.__curve_mode, 1, #fns)]()
end

System.parry = {}
function System.parry.execute()
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    if not _PARRY_PATCH or not _PARRY_PATCH.ready then return end
    local camera = workspace.CurrentCamera
    local vp     = camera.ViewportSize
    local screenPositions = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function() return camera:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                if ok then screenPositions[entity.Name] = sp end
            end
        end
    end
    local curveCF = System.curve.get_cframe() or camera.CFrame
    local mouseLocation = {vp.X / 2, vp.Y / 2}
    _PARRY_PATCH.fire(curveCF, screenPositions, mouseLocation)
    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end
    end)
end

local function linear_predict(a, b, t) return a + (b - a) * t end

System.detection = {
    __ball_properties = {
        __aerodynamic_time = tick(), __last_warping = tick(), __lerp_radians = 0, __curving = tick(),
    },
}

function System.detection.is_curved()
    local bp = System.detection.__ball_properties
    local ball = System.ball.get()
    if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end
    local velocity = zoomies.VectorVelocity or Vector3.new()
    local speed = velocity.Magnitude
    if speed == 0 then return false end
    local ball_dir = velocity.Unit
    local dv = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if dv.Magnitude == 0 then return false end
    local direction = dv.Unit
    local dot = direction:Dot(ball_dir)
    local speed_thr = math.min(speed / 100, 40)
    local dir_diff = ball_dir - velocity
    local dir_sim = 0
    if dir_diff.Magnitude > 0 then dir_sim = direction:Dot(dir_diff.Unit) end
    local dot_diff = dot - dir_sim
    local distance = dv.Magnitude
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local dot_thr = 0.5 - (ping / 1000)
    local reach = distance / speed - (ping / 1000)
    local bdt = 15 - math.min(distance / 1000, 15) + speed_thr
    local clamped = math.clamp(dot, -1, 1)
    local radians = math.rad(math.asin(clamped))
    bp.__lerp_radians = linear_predict(bp.__lerp_radians, radians, 0.8)
    if speed > 0 and reach > ping / 10 then bdt = math.max(bdt - 15, 15) end
    if distance < bdt then return false end
    if dot_diff < dot_thr then return true end
    if bp.__lerp_radians < 0.018 then bp.__last_warping = tick() end
    if (tick() - bp.__last_warping) < (reach / 1.5) then return true end
    if (tick() - bp.__curving) < (reach / 1.5) then return true end
    return dot < dot_thr
end

-- ============================================================
-- 5. DETECTION HOOKS
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
    local player = ({...})[1]
    if player == LocalPlayer or player == LocalPlayer.Name or (player and player.Name == LocalPlayer.Name) then
        System.__properties.__timehole_active = true
    end
end)
netFolder["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
    System.__properties.__timehole_active = false
end)
netFolder["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    local player = ({...})[1]
    if player == LocalPlayer or player == LocalPlayer.Name or (player and player.Name == LocalPlayer.Name) then
        System.__properties.__slashesoffury_active = true
        System.__properties.__slashesoffury_count = 0
    end
end)
netFolder["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_active = false
    System.__properties.__slashesoffury_count = 0
end)
netFolder["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_count = System.__properties.__slashesoffury_count + 1
end)
netFolder["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    spawn(function()
        while System.__properties.__slashesoffury_active and
              System.__properties.__slashesoffury_count < maxParryCount do
            if System.__config.__detections.__slashesoffury then
                System.parry.execute()
                task.wait(parryDelay)
            else break end
        end
    end)
end)

-- ============================================================
-- 6. AUTOPARRY
-- ============================================================
System.autoparry = {}

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or
           not LocalPlayer.Character.PrimaryPart then return end
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        local training_ball = nil
        if workspace:FindFirstChild("TrainingBalls") then
            for _, Instance in pairs(workspace.TrainingBalls:GetChildren()) do
                if Instance:GetAttribute("realBall") then training_ball = Instance; break end
            end
        end
        for _, ball in pairs(balls) do
            if not ball then continue end
            local zoomies = ball:FindFirstChild('zoomies')
            if not zoomies then continue end
            ball:GetAttributeChangedSignal('target'):Once(function()
                System.__properties.__parried = false
            end)
            if System.__properties.__parried then continue end
            local ball_target = ball:GetAttribute('target')
            local velocity = zoomies.VectorVelocity
            local distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
            local ping_threshold = math.clamp(ping / 10, 5, 17)
            local speed = velocity.Magnitude
            local capped_speed_diff = math.min(math.max(speed - 9.5, 0), 650)
            local speed_divisor = (2.4 + capped_speed_diff * 0.002) * System.__properties.__divisor_multiplier
            local parry_accuracy = ping_threshold + math.max(speed / speed_divisor, 9.5)
            local curved = System.detection.is_curved()
            if ball:FindFirstChild('AeroDynamicSlashVFX') then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            if Runtime:FindFirstChild('Tornado') then
                if (tick() - System.__properties.__tornado_time) <
                   (Runtime.Tornado:GetAttribute('TornadoTime') or 1) + 0.314159 then continue end
            end
            if one_ball and one_ball:GetAttribute('target') == LocalPlayer.Name and curved then continue end
            if ball:FindFirstChild('ComboCounter') then continue end
            if LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            if ball_target == LocalPlayer.Name and distance <= parry_accuracy then
                System.parry.execute()
                System.__properties.__parried = true
            end
            local last_parrys = tick()
            repeat RunService.Stepped:Wait() until (tick() - last_parrys) >= 1 or not System.__properties.__parried
            System.__properties.__parried = false
        end
        if training_ball then
            local zoomies = training_ball:FindFirstChild('zoomies')
            if zoomies then
                training_ball:GetAttributeChangedSignal('target'):Once(function()
                    System.__properties.__training_parried = false
                end)
                if not System.__properties.__training_parried then
                    local ball_target = training_ball:GetAttribute('target')
                    local velocity = zoomies.VectorVelocity
                    local distance = LocalPlayer:DistanceFromCharacter(training_ball.Position)
                    local speed = velocity.Magnitude
                    local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
                    local ping_threshold = math.clamp(ping / 10, 5, 17)
                    local capped_speed_diff = math.min(math.max(speed - 9.5, 0), 650)
                    local speed_divisor = (2.4 + capped_speed_diff * 0.002) * System.__properties.__divisor_multiplier
                    local parry_accuracy = ping_threshold + math.max(speed / speed_divisor, 9.5)
                    if ball_target == LocalPlayer.Name and distance <= parry_accuracy then
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
-- 7. AUTO SPAM
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
    if X <= 3 then
        _G.In_Close_Contact = true
    end
    if _G.In_Close_Contact and X > 3.3 then
        _G.In_Close_Contact = false
        _G.Last_Close_Contact = now
    end
    local u = (not _G.In_Close_Contact) and (now - (_G.Last_Close_Contact or 0) >= 1.5)
    if u and (Fmove.Magnitude > 0.2 and Fmove:Dot(N) < -0.4) then
        E = 10
    end
    if u and (lmove.Magnitude > 0.2 and lmove:Dot(-N) < -0.4) then
        E = 10
    end

    local B = (self.Ping or 50) * 0.7 + math.min(n / (E * 1.2), 80)

    if (self.Entity_Properties and self.Entity_Properties.Distance or math.huge) > B then
        return D
    end
    if (self.Ball_Properties and self.Ball_Properties.Distance or math.huge) > B then
        return D
    end
    if X > B then
        return D
    end

    local U = math.clamp(-t, 0, 1)
    local q = math.clamp(U * (n / 40), 0, 4)
    D = B - q
    return D
end

function System.auto_spam.start()
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
    end
    System.__properties.__connections.__auto_spam = RunService.PreSimulation:Connect(function()
        if not System.__properties.__auto_spam_enabled then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end

        local ball = System.ball.get()
        if not ball then return end
        if System.__properties.__slashesoffury_active then return end

        local zoomies = ball:FindFirstChild("zoomies")
        if not zoomies then return end
        if zoomies.VectorVelocity.Magnitude == 0 then return end

        System.player.get_closest()
        if not Closest_Entity or not Closest_Entity.PrimaryPart then return end

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

        local dist_mult = System.__properties.__distance_multiplier or 1
        spam_accuracy = spam_accuracy * dist_mult

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
-- 7.5 MANUAL SPAM
-- ============================================================
System.manual_spam = {}

function System.manual_spam.loop(delta)
    if not System.__properties.__manual_spam_enabled then return end
    if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= Alive then return end
    if getgenv().spamui then return end
    System.__properties.__spam_accumulator = (System.__properties.__spam_accumulator or 0) + delta
    local interval = 1 / math.max(1, System.__properties.__spam_rate or 100)
    if (System.__properties.__spam_accumulator or 0) < interval then return end
    System.__properties.__spam_accumulator = 0
    System.parry.execute()
end

function System.manual_spam.start()
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
    end
    System.__properties.__manual_spam_enabled = true
    System.__properties.__connections.__manual_spam = RunService.Heartbeat:Connect(System.manual_spam.loop)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
        System.__properties.__connections.__manual_spam = nil
    end
end

-- ============================================================
-- 7.6 NO RENDER
-- ============================================================
function System.no_render_set(state)
    System.__properties.__no_render_enabled = state
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local effectScripts = playerScripts and playerScripts:FindFirstChild("EffectScripts")
    local clientFX      = effectScripts and effectScripts:FindFirstChild("ClientFX")
    if clientFX then clientFX.Disabled = state end
    if state then
        if not Connections_Manager["No Render"] then
            local runtime = workspace:FindFirstChild("Runtime")
            if runtime then
                Connections_Manager["No Render"] = runtime.ChildAdded:Connect(function(value)
                    Debris:AddItem(value, 0)
                end)
            end
        end
    else
        if Connections_Manager["No Render"] then
            Connections_Manager["No Render"]:Disconnect()
            Connections_Manager["No Render"] = nil
        end
    end
end

-- ============================================================
-- 7.7 FPS BOOST
-- ============================================================
local original_fog_end = Lighting.FogEnd
local original_fog_start = Lighting.FogStart
local postprocessing_backup = {}
local decals_backup = {}
local scene_backup = {}
local sound_backup = nil
local lighting_backup = nil
local fog_backup = nil
local fps_boost_loop = nil
local fps_boost_enabled = false

local function apply_disable_fog(state)
    if state then Lighting.FogEnd = math.huge; Lighting.FogStart = math.huge
    else Lighting.FogEnd = original_fog_end; Lighting.FogStart = original_fog_start end
end

local function apply_disable_postprocessing(state)
    if state then
        for _, v in pairs(Lighting:GetDescendants()) do
            pcall(function()
                if v.Enabled ~= nil then postprocessing_backup[v] = v.Enabled; v.Enabled = false end
            end)
        end
        fog_backup = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
        pcall(function()
            Lighting.FogEnd = math.huge; Lighting.FogStart = math.huge
            Lighting.FogColor = Color3.new(0, 0, 0)
        end)
    else
        for v, enabled in pairs(postprocessing_backup) do
            pcall(function() if v and v.Parent and v.Enabled ~= nil then v.Enabled = enabled end end)
        end
        postprocessing_backup = {}
        if fog_backup then
            pcall(function()
                Lighting.FogEnd = fog_backup.FogEnd
                Lighting.FogStart = fog_backup.FogStart
                Lighting.FogColor = fog_backup.FogColor
            end)
            fog_backup = nil
        end
    end
end

local function apply_remove_decals(state)
    if state then
        for _, v in pairs(workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Decal") or v:IsA("Texture") then
                    decals_backup[v] = { Texture = v.Texture, Transparency = v.Transparency }
                    pcall(function() v.Texture = "" end)
                    pcall(function() v.Transparency = 1 end)
                end
            end)
        end
    else
        for v, data in pairs(decals_backup) do
            pcall(function()
                if v and v.Parent then
                    if data.Texture ~= nil then pcall(function() v.Texture = data.Texture end) end
                    if data.Transparency ~= nil then pcall(function() v.Transparency = data.Transparency end) end
                end
            end)
        end
        decals_backup = {}
    end
end

local function is_character_object(obj)
    if not obj then return false end
    local lc = LocalPlayer and LocalPlayer.Character
    if lc and obj:IsDescendantOf(lc) then return true end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and obj:IsDescendantOf(player.Character) then return true end
    end
    return false
end

function System.fps_boost_set(state)
    fps_boost_enabled = state
    System.__properties.__fps_boost_enabled = state
    if fps_boost_loop then fps_boost_loop:Disconnect(); fps_boost_loop = nil end
    if not state then
        apply_disable_fog(false)
        apply_disable_postprocessing(false)
        apply_remove_decals(false)
        if lighting_backup then
            Lighting.Brightness = lighting_backup.Brightness
            Lighting.ExposureCompensation = lighting_backup.ExposureCompensation
            Lighting.GlobalShadows = lighting_backup.GlobalShadows
            Lighting.OutdoorAmbient = lighting_backup.OutdoorAmbient
            Lighting.Ambient = lighting_backup.Ambient
            Lighting.ColorShift_Bottom = lighting_backup.ColorShift_Bottom
            Lighting.ColorShift_Top = lighting_backup.ColorShift_Top
            Lighting.ClockTime = lighting_backup.ClockTime
            Lighting.ShadowSoftness = lighting_backup.ShadowSoftness
            lighting_backup = nil
        end
        for obj, values in pairs(scene_backup) do
            pcall(function()
                if obj and obj.Parent then
                    if values.Enabled ~= nil then obj.Enabled = values.Enabled end
                    if values.CastShadow ~= nil then obj.CastShadow = values.CastShadow end
                    if values.Material ~= nil then obj.Material = values.Material end
                end
            end)
        end
        scene_backup = {}
        if SoundService and sound_backup ~= nil then SoundService.Volume = sound_backup; sound_backup = nil end
        return
    end
    apply_disable_fog(true)
    apply_disable_postprocessing(true)
    apply_remove_decals(true)
    lighting_backup = {
        Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation,
        GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient, ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top, ClockTime = Lighting.ClockTime,
        ShadowSoftness = Lighting.ShadowSoftness,
    }
    Lighting.Brightness = 0.18
    Lighting.ExposureCompensation = -1.2
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(35, 35, 35)
    Lighting.Ambient = Color3.fromRGB(35, 35, 35)
    Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
    Lighting.ColorShift_Top = Color3.new(0, 0, 0)
    Lighting.ClockTime = 14
    Lighting.ShadowSoftness = 0
    if SoundService and sound_backup == nil then
        sound_backup = SoundService.Volume
        SoundService.Volume = 0.03
    end
    fps_boost_loop = RunService.Heartbeat:Connect(function()
        if not fps_boost_enabled then return end
        for _, obj in pairs(workspace:GetDescendants()) do
            pcall(function()
                if is_character_object(obj) then return end
                if obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Highlight")
                or obj:IsA("SurfaceGui") or obj:IsA("BillboardGui")
                or obj:IsA("ParticleEmitter") or obj:IsA("Fire")
                or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion")
                or obj:IsA("Weld") or obj:IsA("UIStroke")
                or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageLabel") then
                    local stored = scene_backup[obj]
                    if not stored then scene_backup[obj] = { Enabled = obj.Enabled } end
                    obj.Enabled = false
                elseif obj:IsA("Part") then
                    local stored = scene_backup[obj]
                    if not stored then scene_backup[obj] = { CastShadow = obj.CastShadow, Material = obj.Material } end
                    obj.CastShadow = false
                    obj.Material = Enum.Material.SmoothPlastic
                elseif obj:IsA("Atmosphere") then
                    obj.Density = 0
                end
            end)
        end
    end)
end

-- ============================================================
-- 7.8 HOTKEYS
-- ============================================================
System.hotkeys = { __enabled = true, __conn = nil }

local HOTKEY_MAP = {
    [Enum.KeyCode.T] = function()
        System.__properties.__autoparry_enabled = not System.__properties.__autoparry_enabled
        if System.__properties.__autoparry_enabled then System.autoparry.start() else System.autoparry.stop() end
    end,
    [Enum.KeyCode.C] = function()
        System.__properties.__auto_spam_enabled = not System.__properties.__auto_spam_enabled
        if System.__properties.__auto_spam_enabled then System.auto_spam.start() else System.auto_spam.stop() end
    end,
    [Enum.KeyCode.E] = function()
        System.__properties.__manual_spam_enabled = not System.__properties.__manual_spam_enabled
        if System.__properties.__manual_spam_enabled then System.manual_spam.start() else System.manual_spam.stop() end
    end,
}

function System.hotkeys.start()
    if System.hotkeys.__conn then System.hotkeys.__conn:Disconnect(); System.hotkeys.__conn = nil end
    System.hotkeys.__conn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not System.hotkeys.__enabled then return end
        local fn = HOTKEY_MAP[input.KeyCode]
        if fn then pcall(fn) end
    end)
end
System.hotkeys.start()

-- ============================================================
-- 8. AZURE UI (BLABLA HUB)
-- ============================================================
local Config = setmetatable({
    save = function(self, file_name, config)
        pcall(function()
            if not writefile then return end
            if isfolder and makefolder and not isfolder("BLABLA") then makefolder("BLABLA") end
            writefile("BLABLA/"..file_name..".json", HttpService:JSONEncode(config))
        end)
    end,
    load = function(self, file_name)
        local result
        pcall(function()
            if not isfile or not isfile("BLABLA/"..file_name..".json") then return end
            result = HttpService:JSONDecode(readfile("BLABLA/"..file_name..".json"))
        end)
        return result or { _flags = {}, _keybinds = {}, _library = {} }
    end,
}, {})

local Azure = {}
Azure.__index = Azure
Azure._config = Config:load(game.GameId)
Azure._tabCounter = 0
Azure._tabs = {}

function Azure.new()
    local self = setmetatable({}, Azure)
    self._tabs = {}

    local old = CoreGui:FindFirstChild("Azure")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Azure"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 1000
    ScreenGui.Parent = CoreGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.AnchorPoint = Vector2.new(0.5, 0.5)
    Container.Position = UDim2.new(0.5, 0, 0.5, 0)
    Container.Size = UDim2.new(0, 0, 0, 0)
    Container.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
    Container.BackgroundTransparency = 0
    Container.BorderSizePixel = 0
    Container.ClipsDescendants = true
    Container.Active = true
    Container.ZIndex = 2
    Container.Parent = ScreenGui
    Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 12)

    local bgGradient = Instance.new("UIGradient", Container)
    bgGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(42, 25, 82)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(75, 45, 150)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 70, 200)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(75, 45, 150)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(42, 25, 82)),
    }
    bgGradient.Rotation = 135

    local containerStroke = Instance.new("UIStroke", Container)
    containerStroke.Color = Color3.fromRGB(180, 130, 255)
    containerStroke.Thickness = 1.5
    containerStroke.Transparency = 0.2
    containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local Shimmer = Instance.new("Frame", Container)
    Shimmer.Name = "Shimmer"
    Shimmer.AnchorPoint = Vector2.new(0.5, 0.5)
    Shimmer.Position = UDim2.new(0.5, 0, 0.5, 0)
    Shimmer.Size = UDim2.new(1, 0, 1, 0)
    Shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Shimmer.BackgroundTransparency = 0
    Shimmer.BorderSizePixel = 0
    Shimmer.ZIndex = 100
    Shimmer.Active = false
    Instance.new("UICorner", Shimmer).CornerRadius = UDim.new(0, 12)

    local shimmerGradient = Instance.new("UIGradient", Shimmer)
    shimmerGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    shimmerGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),
        NumberSequenceKeypoint.new(0.42, 1),
        NumberSequenceKeypoint.new(0.48, 0.15),
        NumberSequenceKeypoint.new(0.50, 0.05),
        NumberSequenceKeypoint.new(0.52, 0.15),
        NumberSequenceKeypoint.new(0.58, 1),
        NumberSequenceKeypoint.new(1.00, 1),
    })
    shimmerGradient.Rotation = 45
    shimmerGradient.Offset = Vector2.new(-1, 0)
    shimmerGradient.Parent = Shimmer

    task.spawn(function()
        while Shimmer.Parent do
            shimmerGradient.Offset = Vector2.new(-1, 0)
            task.wait(2.2)
            TweenService:Create(
                shimmerGradient,
                TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                { Offset = Vector2.new(1, 0) }
            ):Play()
            task.wait(1.4)
        end
    end)

    local Handler = Instance.new("Frame", Container)
    Handler.Name = "Handler"
    Handler.BackgroundTransparency = 1
    Handler.Size = UDim2.new(0, 750, 0, 530)
    Handler.ZIndex = 3

    local Title = Instance.new("TextLabel", Handler)
    Title.FontFace = FONT.black
    Title.Text = "BLABLA"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(0, 200, 0, 22)
    Title.AnchorPoint = Vector2.new(0, 0.5)
    Title.Position = UDim2.new(0.05, 0, 0.05, 0)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextSize = 20
    Title.ZIndex = 4

    local SubTitle = Instance.new("TextLabel", Handler)
    SubTitle.FontFace = FONT.reg
    SubTitle.Text = "blade ball hub"
    SubTitle.TextColor3 = Color3.fromRGB(200, 180, 255)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Size = UDim2.new(0, 200, 0, 14)
    SubTitle.AnchorPoint = Vector2.new(0, 0.5)
    SubTitle.Position = UDim2.new(0.05, 0, 0.09, 0)
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.TextSize = 11
    SubTitle.ZIndex = 4

    local Divider = Instance.new("Frame", Handler)
    Divider.BackgroundTransparency = 0.5
    Divider.Position = UDim2.new(0.225, 0, 0, 68)
    Divider.Size = UDim2.new(0, 1, 0, 440)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = Color3.fromRGB(200, 160, 255)
    Divider.ZIndex = 4

    local TabsFrame = Instance.new("ScrollingFrame", Handler)
    TabsFrame.Name = "Tabs"
    TabsFrame.Size = UDim2.new(0, 140, 0, 445)
    TabsFrame.Position = UDim2.new(0.026, 0, 0.111, 10)
    TabsFrame.BackgroundTransparency = 1
    TabsFrame.BorderSizePixel = 0
    TabsFrame.ScrollBarThickness = 0
    TabsFrame.Selectable = true
    TabsFrame.Active = true
    TabsFrame.ZIndex = 10
    TabsFrame.AutomaticCanvasSize = Enum.AutomaticSize.XY
    TabsFrame.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    local tabsLayout = Instance.new("UIListLayout", TabsFrame)
    tabsLayout.Padding = UDim.new(0, 4)
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local SectionsFrame = Instance.new("Frame", Handler)
    SectionsFrame.Name = "Sections"
    SectionsFrame.BackgroundTransparency = 1
    SectionsFrame.Position = UDim2.new(0.22, 0, 0, 0)
    SectionsFrame.Size = UDim2.new(0.78, 0, 1, 0)
    SectionsFrame.ZIndex = 5
    SectionsFrame.Active = false

    local UIScale = Instance.new("UIScale", Container)

    local dragging, dragStart, startPos
    Container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Container.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            Container.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    self._container = Container
    self._handler = Handler
    self._tabsFrame = TabsFrame
    self._sections = SectionsFrame
    self._ui = ScreenGui

    local vp_x = workspace.CurrentCamera.ViewportSize.X
    if UserInputService.TouchEnabled then UIScale.Scale = vp_x / 1400 end
    TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
        Size = UDim2.fromOffset(750, 530)
    }):Play()

    return self
end

function Azure:create_tab(title)
    local tabIndex = self._tabCounter
    self._tabCounter = self._tabCounter + 1

    local Tab = Instance.new("TextButton")
    Tab.Name = "Tab"
    Tab.FontFace = FONT.semi
    Tab.Text = title
    Tab.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tab.TextTransparency = 0.6
    Tab.TextSize = 13
    Tab.AutoButtonColor = false
    Tab.BackgroundTransparency = 1
    Tab.BackgroundColor3 = Color3.fromRGB(60, 40, 120)
    Tab.Size = UDim2.new(0, 129, 0, 38)
    Tab.BorderSizePixel = 0
    Tab.LayoutOrder = tabIndex
    Tab.TextXAlignment = Enum.TextXAlignment.Left
    Tab.ZIndex = 11
    Tab.Active = true
    Tab.Parent = self._tabsFrame
    Instance.new("UICorner", Tab).CornerRadius = UDim.new(0, 8)
    local tabPad = Instance.new("UIPadding", Tab)
    tabPad.PaddingLeft = UDim.new(0, 32)

    local LeftSection = Instance.new("ScrollingFrame")
    LeftSection.Name = "LeftSection"
    LeftSection.Size = UDim2.new(0, 243, 0, 445)
    LeftSection.Position = UDim2.new(0.05, 0, 0.5, 25)
    LeftSection.AnchorPoint = Vector2.new(0, 0.5)
    LeftSection.BackgroundTransparency = 1
    LeftSection.BorderSizePixel = 0
    LeftSection.ScrollBarThickness = 0
    LeftSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
    LeftSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    LeftSection.Visible = false
    LeftSection.ZIndex = 6
    LeftSection.Parent = self._sections
    local leftList = Instance.new("UIListLayout", LeftSection)
    leftList.Padding = UDim.new(0, 18)
    leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    leftList.SortOrder = Enum.SortOrder.LayoutOrder

    local RightSection = Instance.new("ScrollingFrame")
    RightSection.Name = "RightSection"
    RightSection.Size = UDim2.new(0, 243, 0, 445)
    RightSection.Position = UDim2.new(0.52, 0, 0.5, 25)
    RightSection.AnchorPoint = Vector2.new(0, 0.5)
    RightSection.BackgroundTransparency = 1
    RightSection.BorderSizePixel = 0
    RightSection.ScrollBarThickness = 0
    RightSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
    RightSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    RightSection.Visible = false
    RightSection.ZIndex = 6
    RightSection.Parent = self._sections
    local rightList = Instance.new("UIListLayout", RightSection)
    rightList.Padding = UDim.new(0, 18)
    rightList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rightList.SortOrder = Enum.SortOrder.LayoutOrder

    local record = { Tab = Tab, Left = LeftSection, Right = RightSection }
    table.insert(self._tabs, record)

    local function activate()
        for _, rec in pairs(self._tabs) do
            rec.Left.Visible = false
            rec.Right.Visible = false
        end
        LeftSection.Visible = true
        RightSection.Visible = true

        for _, rec in pairs(self._tabs) do
            if rec.Tab == Tab then
                TweenService:Create(rec.Tab, TweenInfo.new(0.25), {
                    BackgroundTransparency = 0.7,
                    BackgroundColor3 = Color3.fromRGB(140, 90, 220)
                }):Play()
                TweenService:Create(rec.Tab, TweenInfo.new(0.25), {
                    TextTransparency = 0.1
                }):Play()
            else
                TweenService:Create(rec.Tab, TweenInfo.new(0.25), {
                    BackgroundTransparency = 1
                }):Play()
                TweenService:Create(rec.Tab, TweenInfo.new(0.25), {
                    TextTransparency = 0.6
                }):Play()
            end
        end
    end

    if tabIndex == 0 then activate() end

    Tab.MouseButton1Click:Connect(function() task.defer(activate) end)
    Tab.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.defer(activate)
        end
    end)

    local TabManager = {}

    function TabManager:create_module(settings)
        local section = (settings.section == "right") and RightSection or LeftSection

        local Module = Instance.new("Frame", section)
        Module.Name = "Module"
        Module.Size = UDim2.new(0, 241, 0, 93)
        Module.Position = UDim2.new(0.004, 0, 0, -5)
        Module.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
        Module.BackgroundTransparency = 0.05
        Module.BorderSizePixel = 0
        Module.ClipsDescendants = true
        Module.ZIndex = 7
        Instance.new("UICorner", Module).CornerRadius = UDim.new(0, 8)
        local ms = Instance.new("UIStroke", Module)
        ms.Color = Color3.fromRGB(180, 130, 255)
        ms.Transparency = 0.55
        ms.Thickness = 1
        ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local Header = Instance.new("TextButton", Module)
        Header.Name = "Header"
        Header.Text = ""
        Header.AutoButtonColor = false
        Header.BackgroundTransparency = 1
        Header.Size = UDim2.new(0, 241, 0, 93)
        Header.BorderSizePixel = 0
        Header.ZIndex = 8

        local ModuleName = Instance.new("TextLabel", Header)
        ModuleName.FontFace = FONT.semi
        ModuleName.Text = settings.title or "Module"
        ModuleName.TextColor3 = Color3.fromRGB(255, 255, 255)
        ModuleName.TextTransparency = 0.2
        ModuleName.BackgroundTransparency = 1
        ModuleName.Size = UDim2.new(0, 205, 0, 13)
        ModuleName.AnchorPoint = Vector2.new(0, 0.5)
        ModuleName.Position = UDim2.new(0.073, 0, 0.24, 0)
        ModuleName.TextXAlignment = Enum.TextXAlignment.Left
        ModuleName.TextSize = 13
        ModuleName.ZIndex = 9

        local Description = Instance.new("TextLabel", Header)
        Description.FontFace = FONT.reg
        Description.Text = settings.description or ""
        Description.TextColor3 = Color3.fromRGB(220, 210, 240)
        Description.TextTransparency = 0.6
        Description.BackgroundTransparency = 1
        Description.Size = UDim2.new(0, 205, 0, 13)
        Description.AnchorPoint = Vector2.new(0, 0.5)
        Description.Position = UDim2.new(0.073, 0, 0.42, 0)
        Description.TextXAlignment = Enum.TextXAlignment.Left
        Description.TextSize = 10
        Description.ZIndex = 9

        local Toggle = Instance.new("Frame", Header)
        Toggle.Name = "Toggle"
        Toggle.BackgroundTransparency = 0.7
        Toggle.BackgroundColor3 = Color3.fromRGB(60, 45, 90)
        Toggle.Size = UDim2.new(0, 25, 0, 12)
        Toggle.Position = UDim2.new(0.82, 0, 0.757, 0)
        Toggle.BorderSizePixel = 0
        Toggle.ZIndex = 9
        Instance.new("UICorner", Toggle).CornerRadius = UDim.new(1, 0)

        local Circle = Instance.new("Frame", Toggle)
        Circle.Name = "Circle"
        Circle.AnchorPoint = Vector2.new(0, 0.5)
        Circle.Position = UDim2.new(0, 0, 0.5, 0)
        Circle.BackgroundColor3 = Color3.fromRGB(140, 120, 180)
        Circle.BackgroundTransparency = 0.2
        Circle.Size = UDim2.new(0, 12, 0, 12)
        Circle.BorderSizePixel = 0
        Circle.ZIndex = 10
        Instance.new("UICorner", Circle).CornerRadius = UDim.new(1, 0)

        local Divider = Instance.new("Frame", Header)
        Divider.Name = "Divider"
        Divider.AnchorPoint = Vector2.new(0.5, 0)
        Divider.Position = UDim2.new(0.5, 0, 0.62, 0)
        Divider.BackgroundColor3 = Color3.fromRGB(200, 160, 255)
        Divider.BackgroundTransparency = 0.7
        Divider.Size = UDim2.new(0, 241, 0, 1)
        Divider.BorderSizePixel = 0
        Divider.ZIndex = 9

        local Options = Instance.new("Frame", Module)
        Options.Name = "Options"
        Options.BackgroundTransparency = 1
        Options.Position = UDim2.new(0, 0, 1, 0)
        Options.Size = UDim2.new(0, 241, 0, 8)
        Options.ZIndex = 8
        local opPad = Instance.new("UIPadding", Options)
        opPad.PaddingTop = UDim.new(0, 8)
        local opList = Instance.new("UIListLayout", Options)
        opList.Padding = UDim.new(0, 5)
        opList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        opList.SortOrder = Enum.SortOrder.LayoutOrder

        local ModuleManager = { _state = false, _size = 0, _multiplier = 0 }

        function ModuleManager:change_state(state)
            self._state = state
            if self._state then
                TweenService:Create(Module, TweenInfo.new(0.35), {
                    Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                }):Play()
                TweenService:Create(Toggle, TweenInfo.new(0.35), {
                    BackgroundColor3 = Color3.fromRGB(180, 140, 255)
                }):Play()
                TweenService:Create(Circle, TweenInfo.new(0.35), {
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Position = UDim2.fromScale(0.53, 0.5)
                }):Play()
            else
                TweenService:Create(Module, TweenInfo.new(0.35), {
                    Size = UDim2.fromOffset(241, 93)
                }):Play()
                TweenService:Create(Toggle, TweenInfo.new(0.35), {
                    BackgroundColor3 = Color3.fromRGB(60, 45, 90)
                }):Play()
                TweenService:Create(Circle, TweenInfo.new(0.35), {
                    BackgroundColor3 = Color3.fromRGB(140, 120, 180),
                    Position = UDim2.fromScale(0, 0.5)
                }):Play()
            end
            Azure._config._flags[settings.flag] = self._state
            Config:save(game.GameId, Azure._config)
            if settings.callback then pcall(settings.callback, self._state) end
        end

        if Azure._config._flags[settings.flag] then
            ModuleManager._state = true
            Toggle.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
            Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Circle.Position = UDim2.fromScale(0.53, 0.5)
            pcall(function()
                if settings.callback then settings.callback(true) end
            end)
        end

        Header.MouseButton1Click:Connect(function()
            ModuleManager:change_state(not ModuleManager._state)
        end)

        -- ★ يحدّث الحجم مباشرة بدون شرط
        local function refresh_size()
            local new_size = 93 + ModuleManager._size + (ModuleManager._multiplier or 0)
            Module.Size = UDim2.fromOffset(241, new_size)
            Options.Size = UDim2.fromOffset(241, ModuleManager._size + (ModuleManager._multiplier or 0))
        end

        function ModuleManager:create_checkbox(s)
            if self._size == 0 then self._size = 11 end
            self._size += 20
            refresh_size()

            local CM = { _state = false }
            local Checkbox = Instance.new("TextButton", Options)
            Checkbox.Name = "Checkbox"
            Checkbox.Text = ""
            Checkbox.AutoButtonColor = false
            Checkbox.BackgroundTransparency = 1
            Checkbox.Size = UDim2.new(0, 207, 0, 15)
            Checkbox.BorderSizePixel = 0
            Checkbox.ZIndex = 9

            local TitleLabel = Instance.new("TextLabel", Checkbox)
            TitleLabel.FontFace = FONT.semi
            TitleLabel.Text = s.title
            TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            TitleLabel.TextTransparency = 0.2
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Size = UDim2.new(0, 142, 0, 13)
            TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
            TitleLabel.Position = UDim2.new(0, 0, 0.5, 0)
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.TextSize = 11
            TitleLabel.ZIndex = 10

            local Box = Instance.new("Frame", Checkbox)
            Box.Name = "Box"
            Box.AnchorPoint = Vector2.new(1, 0.5)
            Box.Position = UDim2.new(1, 0, 0.5, 0)
            Box.Size = UDim2.new(0, 15, 0, 15)
            Box.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
            Box.BackgroundTransparency = 0.9
            Box.BorderSizePixel = 0
            Box.ZIndex = 10
            Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 7)

            local Fill = Instance.new("Frame", Box)
            Fill.Name = "Fill"
            Fill.AnchorPoint = Vector2.new(0.5, 0.5)
            Fill.Position = UDim2.new(0.5, 0, 0.5, 0)
            Fill.Size = UDim2.fromOffset(0, 0)
            Fill.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
            Fill.BackgroundTransparency = 0.2
            Fill.BorderSizePixel = 0
            Fill.ZIndex = 11
            Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 6)

            function CM:change_state(state)
                self._state = state
                if state then
                    TweenService:Create(Box, TweenInfo.new(0.25), { BackgroundTransparency = 0.7 }):Play()
                    TweenService:Create(Fill, TweenInfo.new(0.25), { Size = UDim2.fromOffset(9, 9) }):Play()
                else
                    TweenService:Create(Box, TweenInfo.new(0.25), { BackgroundTransparency = 0.9 }):Play()
                    TweenService:Create(Fill, TweenInfo.new(0.25), { Size = UDim2.fromOffset(0, 0) }):Play()
                end
                Azure._config._flags[s.flag] = self._state
                Config:save(game.GameId, Azure._config)
                if s.callback then pcall(s.callback, self._state) end
            end

            if Azure._config._flags[s.flag] ~= nil then
                CM:change_state(Azure._config._flags[s.flag])
            end

            Checkbox.MouseButton1Click:Connect(function()
                CM:change_state(not CM._state)
            end)

            return CM
        end

        function ModuleManager:create_slider(s)
            if self._size == 0 then self._size = 11 end
            self._size += 27
            refresh_size()

            local Slider = Instance.new("TextButton", Options)
            Slider.Name = "Slider"
            Slider.Text = ""
            Slider.AutoButtonColor = false
            Slider.BackgroundTransparency = 1
            Slider.Size = UDim2.new(0, 207, 0, 22)
            Slider.BorderSizePixel = 0
            Slider.ZIndex = 9

            local TitleLabel = Instance.new("TextLabel", Slider)
            TitleLabel.FontFace = FONT.semi
            TitleLabel.Text = s.title
            TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            TitleLabel.TextTransparency = 0.2
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Size = UDim2.new(0, 153, 0, 13)
            TitleLabel.Position = UDim2.new(0, 0, 0.05, 0)
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.TextSize = 11
            TitleLabel.ZIndex = 10

            local Drag = Instance.new("Frame", Slider)
            Drag.Name = "Drag"
            Drag.AnchorPoint = Vector2.new(0.5, 1)
            Drag.Position = UDim2.new(0.5, 0, 0.95, 0)
            Drag.Size = UDim2.new(0, 207, 0, 4)
            Drag.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
            Drag.BackgroundTransparency = 0.7
            Drag.BorderSizePixel = 0
            Drag.ZIndex = 10
            Instance.new("UICorner", Drag).CornerRadius = UDim.new(1, 0)

            local Fill = Instance.new("Frame", Drag)
            Fill.Name = "Fill"
            Fill.AnchorPoint = Vector2.new(0, 0.5)
            Fill.Position = UDim2.new(0, 0, 0.5, 0)
            Fill.Size = UDim2.new(0, 0, 0, 4)
            Fill.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
            Fill.BackgroundTransparency = 0.15
            Fill.BorderSizePixel = 0
            Fill.ZIndex = 11
            Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 3)

            local Circle2 = Instance.new("Frame", Fill)
            Circle2.Name = "Circle"
            Circle2.AnchorPoint = Vector2.new(1, 0.5)
            Circle2.Position = UDim2.new(1, 0, 0.5, 0)
            Circle2.Size = UDim2.new(0, 6, 0, 6)
            Circle2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Circle2.BorderSizePixel = 0
            Circle2.ZIndex = 12
            Instance.new("UICorner", Circle2).CornerRadius = UDim.new(1, 0)

            local Value = Instance.new("TextLabel", Slider)
            Value.Name = "Value"
            Value.FontFace = FONT.semi
            Value.TextColor3 = Color3.fromRGB(255, 255, 255)
            Value.TextTransparency = 0.2
            Value.Text = "0"
            Value.BackgroundTransparency = 1
            Value.Size = UDim2.new(0, 42, 0, 13)
            Value.AnchorPoint = Vector2.new(1, 0)
            Value.Position = UDim2.new(1, 0, 0, 0)
            Value.TextXAlignment = Enum.TextXAlignment.Right
            Value.TextSize = 10
            Value.ZIndex = 10

            local SM = {}
            local min_v = s.minimum_value or 0
            local max_v = s.maximum_value or 100
            local cur = s.value or min_v

            function SM:set_value(v)
                cur = math.clamp(v, min_v, max_v)
                if s.round_number then cur = math.floor(cur + 0.5) end
                local pct = (cur - min_v) / (max_v - min_v)
                Value.Text = tostring(cur)
                TweenService:Create(Fill, TweenInfo.new(0.15), {
                    Size = UDim2.new(pct, 0, 0, 4)
                }):Play()
                Azure._config._flags[s.flag] = cur
                if s.callback then pcall(s.callback, cur) end
            end

            if Azure._config._flags[s.flag] then SM:set_value(Azure._config._flags[s.flag])
            else SM:set_value(cur) end

            local dragging = false
            local function update_from_input(input)
                local rel = math.clamp((input.Position.X - Drag.AbsolutePosition.X) / Drag.AbsoluteSize.X, 0, 1)
                SM:set_value(min_v + rel * (max_v - min_v))
            end
            Slider.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    update_from_input(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if not dragging then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                    update_from_input(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        dragging = false
                        Config:save(game.GameId, Azure._config)
                    end
                end
            end)

            return SM
        end

        function ModuleManager:create_range_slider(s)
            if self._size == 0 then self._size = 11 end
            self._size += 27
            refresh_size()

            local Slider = Instance.new("TextButton", Options)
            Slider.Name = "RangeSlider"
            Slider.Text = ""
            Slider.AutoButtonColor = false
            Slider.BackgroundTransparency = 1
            Slider.Size = UDim2.new(0, 207, 0, 22)
            Slider.BorderSizePixel = 0
            Slider.ZIndex = 9

            local TitleLabel = Instance.new("TextLabel", Slider)
            TitleLabel.FontFace = FONT.semi
            TitleLabel.Text = s.title
            TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            TitleLabel.TextTransparency = 0.2
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Size = UDim2.new(0, 130, 0, 13)
            TitleLabel.Position = UDim2.new(0, 0, 0.05, 0)
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.TextSize = 11
            TitleLabel.ZIndex = 10

            local Value = Instance.new("TextLabel", Slider)
            Value.Name = "Value"
            Value.FontFace = FONT.semi
            Value.TextColor3 = Color3.fromRGB(255, 255, 255)
            Value.TextTransparency = 0.2
            Value.Text = "0 - 0"
            Value.BackgroundTransparency = 1
            Value.Size = UDim2.new(0, 80, 0, 13)
            Value.AnchorPoint = Vector2.new(1, 0)
            Value.Position = UDim2.new(1, 0, 0.05, 0)
            Value.TextXAlignment = Enum.TextXAlignment.Right
            Value.TextSize = 10
            Value.ZIndex = 10

            local Drag = Instance.new("Frame", Slider)
            Drag.Name = "Drag"
            Drag.AnchorPoint = Vector2.new(0.5, 1)
            Drag.Position = UDim2.new(0.5, 0, 0.95, 0)
            Drag.Size = UDim2.new(0, 207, 0, 4)
            Drag.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
            Drag.BackgroundTransparency = 0.7
            Drag.BorderSizePixel = 0
            Drag.ZIndex = 10
            Instance.new("UICorner", Drag).CornerRadius = UDim.new(1, 0)

            local RangeFill = Instance.new("Frame", Drag)
            RangeFill.Name = "RangeFill"
            RangeFill.AnchorPoint = Vector2.new(0, 0.5)
            RangeFill.Position = UDim2.new(0, 0, 0.5, 0)
            RangeFill.Size = UDim2.new(0, 0, 0, 4)
            RangeFill.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
            RangeFill.BackgroundTransparency = 0.15
            RangeFill.BorderSizePixel = 0
            RangeFill.ZIndex = 11
            Instance.new("UICorner", RangeFill).CornerRadius = UDim.new(0, 3)

            local MinHandle = Instance.new("Frame", Drag)
            MinHandle.Name = "MinHandle"
            MinHandle.AnchorPoint = Vector2.new(0.5, 0.5)
            MinHandle.Size = UDim2.new(0, 8, 0, 8)
            MinHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            MinHandle.BorderSizePixel = 0
            MinHandle.ZIndex = 12
            Instance.new("UICorner", MinHandle).CornerRadius = UDim.new(1, 0)

            local MaxHandle = Instance.new("Frame", Drag)
            MaxHandle.Name = "MaxHandle"
            MaxHandle.AnchorPoint = Vector2.new(0.5, 0.5)
            MaxHandle.Size = UDim2.new(0, 8, 0, 8)
            MaxHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            MaxHandle.BorderSizePixel = 0
            MaxHandle.ZIndex = 12
            Instance.new("UICorner", MaxHandle).CornerRadius = UDim.new(1, 0)

            local SM = {}
            local min_v = s.minimum_value or 0
            local max_v = s.maximum_value or 100
            local cur_min = (s.value and s.value.min) or min_v
            local cur_max = (s.value and s.value.max) or max_v

            local function refresh()
                local span = max_v - min_v
                local pmin = span > 0 and (cur_min - min_v) / span or 0
                local pmax = span > 0 and (cur_max - min_v) / span or 1
                RangeFill.Position = UDim2.new(pmin, 0, 0.5, 0)
                RangeFill.Size = UDim2.new(math.max(pmax - pmin, 0.01), 0, 0, 4)
                MinHandle.Position = UDim2.new(pmin, 0, 0.5, 0)
                MaxHandle.Position = UDim2.new(pmax, 0, 0.5, 0)
                Value.Text = tostring(math.floor(cur_min)) .. " - " .. tostring(math.floor(cur_max))
                Azure._config._flags[s.flag] = { min = cur_min, max = cur_max }
                if s.callback then pcall(s.callback, cur_min, cur_max) end
            end

            if Azure._config._flags[s.flag] then
                local saved = Azure._config._flags[s.flag]
                cur_min = saved.min or cur_min
                cur_max = saved.max or cur_max
            end
            refresh()

            local active = "min"
            local dragging = false
            local function update_from_input(input)
                local rel = math.clamp((input.Position.X - Drag.AbsolutePosition.X) / Drag.AbsoluteSize.X, 0, 1)
                local val = min_v + rel * (max_v - min_v)
                if active == "min" then
                    cur_min = math.clamp(val, min_v, cur_max)
                else
                    cur_max = math.clamp(val, cur_min, max_v)
                end
                refresh()
            end
            Slider.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    local rel = math.clamp((input.Position.X - Drag.AbsolutePosition.X) / Drag.AbsoluteSize.X, 0, 1)
                    local span = max_v - min_v
                    local pmin = (cur_min - min_v) / span
                    local pmax = (cur_max - min_v) / span
                    active = math.abs(rel - pmin) < math.abs(rel - pmax) and "min" or "max"
                    update_from_input(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if not dragging then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                    update_from_input(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        dragging = false
                        Config:save(game.GameId, Azure._config)
                    end
                end
            end)

            return SM
        end

        function ModuleManager:create_dropdown(s)
            if self._size == 0 then self._size = 11 end
            self._size += 44
            refresh_size()

            local DM = { _state = false, _size = 0 }
            local Dropdown = Instance.new("TextButton", Options)
            Dropdown.Name = "Dropdown"
            Dropdown.Text = ""
            Dropdown.AutoButtonColor = false
            Dropdown.BackgroundTransparency = 1
            Dropdown.Size = UDim2.new(0, 207, 0, 39)
            Dropdown.BorderSizePixel = 0
            Dropdown.ZIndex = 9

            local TitleLabel = Instance.new("TextLabel", Dropdown)
            TitleLabel.FontFace = FONT.semi
            TitleLabel.Text = s.title
            TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            TitleLabel.TextTransparency = 0.2
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Size = UDim2.new(0, 207, 0, 13)
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.TextSize = 11
            TitleLabel.ZIndex = 10

            local Box = Instance.new("Frame", TitleLabel)
            Box.Name = "Box"
            Box.ClipsDescendants = true
            Box.AnchorPoint = Vector2.new(0.5, 0)
            Box.Position = UDim2.new(0.5, 0, 1.2, 0)
            Box.Size = UDim2.new(0, 207, 0, 22)
            Box.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
            Box.BackgroundTransparency = 0.4
            Box.BorderSizePixel = 0
            Box.ZIndex = 11
            Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)

            local CurrentOption = Instance.new("TextLabel", Box)
            CurrentOption.Name = "CurrentOption"
            CurrentOption.FontFace = FONT.semi
            CurrentOption.TextColor3 = Color3.fromRGB(255, 255, 255)
            CurrentOption.TextTransparency = 0.2
            CurrentOption.BackgroundTransparency = 1
            CurrentOption.Size = UDim2.new(0, 161, 0, 13)
            CurrentOption.AnchorPoint = Vector2.new(0, 0.5)
            CurrentOption.Position = UDim2.new(0.05, 0, 0.5, 0)
            CurrentOption.TextXAlignment = Enum.TextXAlignment.Left
            CurrentOption.TextSize = 10
            CurrentOption.ZIndex = 12

            local OptionsFrame = Instance.new("ScrollingFrame", Box)
            OptionsFrame.Name = "Options"
            OptionsFrame.ScrollBarThickness = 0
            OptionsFrame.BackgroundTransparency = 1
            OptionsFrame.Position = UDim2.new(0, 0, 1, 0)
            OptionsFrame.Size = UDim2.new(0, 207, 0, 0)
            OptionsFrame.CanvasSize = UDim2.new(0, 0, 0.5, 0)
            OptionsFrame.ZIndex = 12
            local optsList = Instance.new("UIListLayout", OptionsFrame)
            optsList.SortOrder = Enum.SortOrder.LayoutOrder

            function DM:update(option)
                CurrentOption.Text = (typeof(option) == "string" and option) or option.Name
                Azure._config._flags[s.flag] = option
                Config:save(game.GameId, Azure._config)
                if s.callback then pcall(s.callback, option) end
            end

            if s.options and #s.options > 0 then
                DM._size = 3
                for index, value in ipairs(s.options) do
                    local Option = Instance.new("TextButton", OptionsFrame)
                    Option.Name = "Option"
                    Option.FontFace = FONT.semi
                    Option.Text = (typeof(value) == "string" and value) or value.Name
                    Option.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Option.TextTransparency = 0.6
                    Option.TextSize = 10
                    Option.BackgroundTransparency = 1
                    Option.TextXAlignment = Enum.TextXAlignment.Left
                    Option.AutoButtonColor = false
                    Option.Size = UDim2.new(0, 186, 0, 16)
                    Option.ZIndex = 13
                    Option.MouseButton1Click:Connect(function()
                        DM:update(value)
                        for _, child in OptionsFrame:GetChildren() do
                            if child.Name == "Option" then
                                child.TextTransparency = (child.Text == CurrentOption.Text) and 0.2 or 0.6
                            end
                        end
                    end)
                    if index > (s.maximum_options or 10) then continue end
                    DM._size += 16
                    OptionsFrame.Size = UDim2.fromOffset(207, DM._size)
                end
            end

            if Azure._config._flags[s.flag] then DM:update(Azure._config._flags[s.flag])
            elseif s.options and s.options[1] then DM:update(s.options[1]) end

            Dropdown.MouseButton1Click:Connect(function()
                self._state = not self._state
                if self._state then
                    ModuleManager._multiplier += self._size
                    TweenService:Create(Module, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                    }):Play()
                    TweenService:Create(Options, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                    }):Play()
                    TweenService:Create(Dropdown, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(207, 39 + self._size)
                    }):Play()
                    TweenService:Create(Box, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(207, 22 + self._size)
                    }):Play()
                else
                    ModuleManager._multiplier -= self._size
                    TweenService:Create(Module, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                    }):Play()
                    TweenService:Create(Options, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                    }):Play()
                    TweenService:Create(Dropdown, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(207, 39)
                    }):Play()
                    TweenService:Create(Box, TweenInfo.new(0.35), {
                        Size = UDim2.fromOffset(207, 22)
                    }):Play()
                end
            end)

            return DM
        end

        return ModuleManager
    end

    return TabManager
end

-- ============================================================
-- 9. TABS + MODULES
-- ============================================================
local AzureWindow = Azure.new()

local MainTab   = AzureWindow:create_tab("Main")
local SpamTab   = AzureWindow:create_tab("Spam")
local DetTab    = AzureWindow:create_tab("Detection")
local VisualTab = AzureWindow:create_tab("Visual")

-- MAIN — Auto Parry + كل العناصر تحته
local autoparry_module = MainTab:create_module({
    title = "Auto Parry",
    description = "Auto Parry Settings",
    flag = "AutoParryModule",
    section = "left",
    callback = function(state)
        System.__properties.__autoparry_enabled = state
        if state then System.autoparry.start() else System.autoparry.stop() end
    end,
})

autoparry_module:create_slider({
    title = "Parry Accuracy",
    flag = "ParryAccuracy",
    maximum_value = 100,
    minimum_value = 1,
    value = 100,
    round_number = true,
    callback = function(value)
        if not System.__properties.__humanizer_enabled then
            System.__properties.__accuracy = value
            update_divisor()
        end
    end,
})

autoparry_module:create_checkbox({
    title = "Randomize Accuracy",
    flag = "ParryRandomizeAccuracy",
    callback = function(value)
        System.__properties.__humanizer_enabled = value
    end,
})

autoparry_module:create_dropdown({
    title = "Parry Mode",
    flag = "AutoParryMode",
    options = {"Remote", "Keypress"},
    maximum_options = 10,
    callback = function(value)
        getgenv().AutoParryMode = value
    end,
})

autoparry_module:create_dropdown({
    title = "Mode curve",
    flag = "ModeCurve",
    options = System.__config.__curve_names,
    maximum_options = 10,
    callback = function(value)
        for i, name in ipairs(System.__config.__curve_names) do
            if name == value then System.__properties.__curve_mode = i; break end
        end
    end,
})

autoparry_module:create_checkbox({
    title = "Cooldown Protection",
    flag = "CooldownProtection",
    callback = function(value)
        getgenv().CooldownProtection = value
    end,
})

autoparry_module:create_checkbox({
    title = "Auto Ability",
    flag = "AutoAbility",
    callback = function(value)
        getgenv().AutoAbility = value
    end,
})

autoparry_module:create_checkbox({
    title = "Notify",
    flag = "AutoParryNotify",
    callback = function(value)
        getgenv().AutoParryNotify = value
    end,
})

-- SPAM — Auto Spam
local auto_spam_module = SpamTab:create_module({
    title = "Auto Spam",
    description = "Automatically spam parries ball",
    flag = "AutoSpamModule",
    section = "right",
    callback = function(state)
        System.__properties.__auto_spam_enabled = state
        if state then System.auto_spam.start() else System.auto_spam.stop() end
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

auto_spam_module:create_slider({
    title = "Distance Multiplier",
    flag = "DistanceMultiplier",
    maximum_value = 3,
    minimum_value = 0.3,
    value = 1,
    round_number = false,
    callback = function(value)
        System.__properties.__distance_multiplier = value
    end,
})

auto_spam_module:create_dropdown({
    title = "Mode",
    flag = "AutoSpamMode",
    options = {"Remote", "Keypress"},
    maximum_options = 10,
    callback = function(value)
        getgenv().AutoSpamMode = value
    end,
})

auto_spam_module:create_checkbox({
    title = "Animation Fix",
    flag = "AutoSpamAnimationFix",
    callback = function(value)
        getgenv().AutoSpamAnimationFix = value
    end,
})

-- SPAM — Manual Spam
local manual_spam_module = SpamTab:create_module({
    title = "Manual Spam",
    description = "Spam parries continuously",
    flag = "ManualSpamModule",
    section = "left",
    callback = function(state)
        System.__properties.__manual_spam_enabled = state
        if state then System.manual_spam.start() else System.manual_spam.stop() end
    end,
})

manual_spam_module:create_slider({
    title = "CPS",
    flag = "ManualSpamCPS",
    maximum_value = 200,
    minimum_value = 1,
    value = 100,
    round_number = true,
    callback = function(value)
        System.__properties.__spam_rate = value
    end,
})

-- DETECTION
local inf_mod = DetTab:create_module({
    title = "Infinity Ball",
    description = "skip parry while active",
    flag = "InfModule",
    section = "left",
    callback = function(state) System.__config.__detections.__infinity = state end,
})
inf_mod:change_state(true)

local ds_mod = DetTab:create_module({
    title = "Death Slash",
    description = "skip parry while active",
    flag = "DSModule",
    section = "left",
    callback = function(state) System.__config.__detections.__deathslash = state end,
})
ds_mod:change_state(true)

local th_mod = DetTab:create_module({
    title = "Time Hole",
    description = "skip parry while active",
    flag = "THModule",
    section = "right",
    callback = function(state) System.__config.__detections.__timehole = state end,
})
th_mod:change_state(true)

local sof_mod = DetTab:create_module({
    title = "Slashes of Fury",
    description = "parry loop while active",
    flag = "SoFModule",
    section = "right",
    callback = function(state) System.__config.__detections.__slashesoffury = state end,
})
sof_mod:change_state(true)

-- VISUAL
local nr_mod = VisualTab:create_module({
    title = "No Render",
    description = "disable effects completely",
    flag = "NRModule",
    section = "left",
    callback = function(state) System.no_render_set(state) end,
})

local fps_mod = VisualTab:create_module({
    title = "FPS Boost",
    description = "hide shadows & particles + boost",
    flag = "FPSModule",
    section = "right",
    callback = function(state) System.fps_boost_set(state) end,
})

-- ============================================================
-- 10. AUTO START
-- ============================================================
System.__properties.__autoparry_enabled = true
System.__properties.__auto_spam_enabled = true
System.autoparry.start()
System.auto_spam.start()
System.manual_spam.stop()
update_divisor()

-- ★ يفتح الـ module بعد ما تنضاف كل العناصر
task.defer(function()
    task.wait(0.1)
    autoparry_module:change_state(true)
    auto_spam_module:change_state(true)
end)
