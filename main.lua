-- Blade Ball Mobile — Auto Parry + Auto Spam (FIXED FAB → PANEL)
-- Runtime: Roblox mobile (touch)
-- Executor: cloneref, getupvalues, getrawmetatable, setreadonly

local cloneref = cloneref or function(o) return o end

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
local TweenService     = cloneref(game:GetService("TweenService"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local Alive   = workspace:FindFirstChild("Alive")   or workspace:WaitForChild("Alive")
local Runtime = workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime")

-- ============================================================
-- 3. STATE
-- ============================================================
local System = {
    __properties = {
        __autoparry_enabled  = false,
        __auto_spam_enabled  = false,
        __curve_mode         = 1,
        __accuracy           = 1,
        __divisor_multiplier = 1.1,
        __parried            = false,
        __training_parried   = false,
        __parries            = 0,
        __tornado_time       = tick(),
        __connections        = {},
        __infinity_active    = false,
        __deathslash_active  = false,
        __timehole_active    = false,
        __slashesoffury_active = false,
        __slashesoffury_count  = 0,
        __humanizer_enabled  = false,
        __humanizer_min_accuracy = 1,
        __humanizer_max_accuracy = 50,
        __humanizer_last_update  = 0,
        __humanizer_next_change  = 0.8,
        __auto_spam_cps      = 200,
        __auto_spam_accum    = 0,
        __auto_spam_last_fire = 0,
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
-- 4. BALL / PLAYER / CURVE / PARRY / DETECTION
-- ============================================================
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
    local out   = {}
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
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
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
    if closest and closest:FindFirstChild("HumanoidRootPart") then
        targetPart = closest.HumanoidRootPart
    end
    local target_pos = targetPart and targetPart.Position
        or (root.Position + camera.CFrame.LookVector * 100)

    local fns = {
        function() return camera.CFrame end,
        function()
            local direction = (target_pos - root.Position).Unit
            local random_offset
            local attempts = 0
            repeat
                random_offset = Vector3.new(
                    math.random(-4000, 4000),
                    math.random(-4000, 4000),
                    math.random(-4000, 4000)
                )
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
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0, 9e18, 0))  end,
        function()
            local left = -camera.CFrame.RightVector * 10000
            return CFrame.new(root.Position, root.Position + left)
        end,
        function()
            local right = camera.CFrame.RightVector * 10000
            return CFrame.new(root.Position, root.Position + right)
        end,
    }
    local idx = math.clamp(System.__properties.__curve_mode, 1, #fns)
    return fns[idx]()
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
                local ok, sp = pcall(function()
                    return camera:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if ok then screenPositions[entity.Name] = sp end
            end
        end
    end

    local curveCF = System.curve.get_cframe() or camera.CFrame
    local mouseLocation = {vp.X / 2, vp.Y / 2}

    _PARRY_PATCH.fire(curveCF, screenPositions, mouseLocation)

    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then
            System.__properties.__parries -= 1
        end
    end)
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

    local ball_dir = velocity.Unit
    local dv       = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if dv.Magnitude == 0 then return false end
    local direction = dv.Unit

    local dot = direction:Dot(ball_dir)
    local speed_thr = math.min(speed / 100, 40)

    local dir_diff = ball_dir - velocity
    local dir_sim  = 0
    if dir_diff.Magnitude > 0 then dir_sim = direction:Dot(dir_diff.Unit) end
    local dot_diff = dot - dir_sim

    local distance = dv.Magnitude
    local ping     = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local dot_thr  = 0.5 - (ping / 1000)
    local reach    = distance / speed - (ping / 1000)
    local bdt      = 15 - math.min(distance / 1000, 15) + speed_thr

    local clamped = math.clamp(dot, -1, 1)
    local radians = math.rad(math.asin(clamped))
    bp.__lerp_radians = linear_predict(bp.__lerp_radians, radians, 0.8)

    if speed > 0 and reach > ping / 10 then
        bdt = math.max(bdt - 15, 15)
    end
    if distance < bdt then return false end
    if dot_diff < dot_thr then return true end
    if bp.__lerp_radians < 0.018 then bp.__last_warping = tick() end
    if (tick() - bp.__last_warping) < (reach / 1.5) then return true end
    if (tick() - bp.__curving)     < (reach / 1.5) then return true end
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

-- ============================================================
-- 6. AUTOPARRY
-- ============================================================
System.autoparry = {}

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end

        local balls    = System.ball.get_all()
        local one_ball = System.ball.get()
        local training_ball = nil

        if workspace:FindFirstChild("TrainingBalls") then
            for _, inst in pairs(workspace.TrainingBalls:GetChildren()) do
                if inst:GetAttribute("realBall") then
                    training_ball = inst
                    break
                end
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
            local velocity    = zoomies.VectorVelocity
            local distance    = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            local ping        = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
            local ping_thr    = math.clamp(ping / 10, 5, 17)
            local speed       = velocity.Magnitude
            local capped      = math.min(math.max(speed - 9.5, 0), 650)
            local speed_div   = (2.4 + capped * 0.002) * System.__properties.__divisor_multiplier
            local parry_acc   = ping_thr + math.max(speed / speed_div, 9.5)

            local curved = System.detection.is_curved()

            if ball:FindFirstChild("AeroDynamicSlashVFX") then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            if Runtime:FindFirstChild("Tornado") then
                local tt = Runtime.Tornado:GetAttribute("TornadoTime") or 1
                if (tick() - System.__properties.__tornado_time) < tt + 0.314159 then
                    continue
                end
            end
            if one_ball and one_ball:GetAttribute("target") == LocalPlayer.Name and curved then
                continue
            end
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

            local last = tick()
            repeat RunService.Stepped:Wait() until
                (tick() - last) >= 1 or not System.__properties.__parried
            System.__properties.__parried = false
        end

        if training_ball then
            local zoomies = training_ball:FindFirstChild("zoomies")
            if zoomies and not System.__properties.__training_parried then
                training_ball:GetAttributeChangedSignal("target"):Once(function()
                    System.__properties.__training_parried = false
                end)
                local bt = training_ball:GetAttribute("target")
                local v  = zoomies.VectorVelocity
                local d  = LocalPlayer:DistanceFromCharacter(training_ball.Position)
                local s  = v.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                local pt = math.clamp(ping / 10, 5, 17)
                local capped = math.min(math.max(s - 9.5, 0), 650)
                local sd = (2.4 + capped * 0.002) * System.__properties.__divisor_multiplier
                local acc = pt + math.max(s / sd, 9.5)

                if bt == LocalPlayer.Name and d <= acc then
                    System.parry.execute()
                    System.__properties.__training_parried = true
                    local last = tick()
                    repeat RunService.Stepped:Wait() until
                        (tick() - last) >= 1 or not System.__properties.__training_parried
                    System.__properties.__training_parried = false
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
    local ev = Closest_Entity.PrimaryPart.Velocity
    local ed = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local ds = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude
    return { Velocity = ev, Direction = ed, Distance = ds }
end

function System.auto_spam:get_ball_properties()
    local ball = System.ball.get()
    if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local bv  = ball.AssemblyLinearVelocity or Vector3.new()
    local dv  = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    local ds  = dv.Magnitude
    local bd  = Vector3.new()
    local dot = 0
    if ds > 0 then
        bd = dv.Unit
        if bv.Magnitude > 0 then dot = bd:Dot(bv.Unit) end
    end
    return { Velocity = bv, Direction = bd, Distance = ds, Dot = dot }
end

function System.auto_spam.spam_service(self)
    local ball   = System.ball.get()
    local entity = System.player.get_closest()
    if not ball or not entity or not entity.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end

    local D = 5
    local velocity = ball.AssemblyLinearVelocity or Vector3.new()
    local n = velocity.Magnitude
    if n == 0 then return D end

    local to_ball = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if to_ball.Magnitude == 0 then return D end
    local r = to_ball.Unit

    local t = 0
    if velocity.Magnitude > 0 then t = r:Dot(velocity.Unit) end

    local target_pos = entity.PrimaryPart.Position
    local X = LocalPlayer:DistanceFromCharacter(target_pos)

    local E = 1
    local Fmove = Vector3.new()
    local ok, hum = pcall(function()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end)
    if ok and hum and hum.MoveDirection then Fmove = hum.MoveDirection end

    local N = (target_pos - LocalPlayer.Character.PrimaryPart.Position)
    if N.Magnitude > 0 then N = N.Unit else N = Vector3.new() end

    local lmove = Vector3.new()
    if entity then
        local ehum = entity:FindFirstChildOfClass("Humanoid")
        if ehum and ehum.MoveDirection then lmove = ehum.MoveDirection end
    end

    _G.Last_Close_Contact = _G.Last_Close_Contact or 0
    _G.In_Close_Contact   = _G.In_Close_Contact or false
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
    if (self.Ball_Properties   and self.Ball_Properties.Distance   or math.huge) > B then return D end
    if X > B then return D end

    local U = math.clamp(-t, 0, 1)
    local q = math.clamp(U * (n / 40), 0, 4)
    return B - q
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
        local ping_thr = math.clamp(ping / 10, 1, 16)

        local bp = System.auto_spam:get_ball_properties()
        local ep = System.auto_spam:get_entity_properties()
        if not bp or not ep then return end

        local spam_acc = System.auto_spam.spam_service({
            Ball_Properties   = bp,
            Entity_Properties = ep,
            Ping              = ping_thr,
        })

        local target_pos  = Closest_Entity.PrimaryPart.Position
        local target_dist = LocalPlayer:DistanceFromCharacter(target_pos)
        local ball_dist   = LocalPlayer:DistanceFromCharacter(ball.Position)

        local ball_target = ball:GetAttribute("target")
        if not ball_target then return end

        local pulsed = LocalPlayer.Character:GetAttribute("Pulsed")
        if pulsed then return end

        if target_dist > spam_acc or ball_dist > spam_acc then return end
        if ball_target == LocalPlayer.Name and target_dist > 30 and ball_dist > 30 then return end

        if ball_dist <= spam_acc then
            local cps = math.clamp(System.__properties.__auto_spam_cps or 200, 200, 2000)
            local interval = 1 / cps
            local now = tick()
            if now - System.__properties.__auto_spam_last_fire >= interval then
                System.__properties.__auto_spam_last_fire = now
                System.parry.execute()
            end
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
-- 8. UI — DIPISAH TOTAL DARI LOGIC
-- Semua UI dibungkus pcall biar walau ada error, script logic tetap hidup
-- ============================================================
local UI_OK, UI_ERR = pcall(function()

    local COL = {
        bg      = Color3.fromRGB(14, 15, 20),
        bgSoft  = Color3.fromRGB(24, 26, 34),
        bgDeep  = Color3.fromRGB(10, 11, 15),
        stroke  = Color3.fromRGB(52, 56, 70),
        strokeLit = Color3.fromRGB(78, 84, 100),
        text    = Color3.fromRGB(238, 240, 246),
        textDim = Color3.fromRGB(152, 158, 172),
        textFaint = Color3.fromRGB(96, 102, 118),
        green   = Color3.fromRGB(88, 210, 140),
        greenDim= Color3.fromRGB(50, 140, 90),
        red     = Color3.fromRGB(230, 90, 100),
        redDim  = Color3.fromRGB(150, 55, 65),
        accent  = Color3.fromRGB(98, 160, 226),
        amber   = Color3.fromRGB(230, 180, 90),
    }

    local FONT = {
        reg  = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
        med  = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium,   Enum.FontStyle.Normal),
        bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
    }

    local function corner(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = r or UDim.new(0,10)
        c.Parent = o
        return c
    end

    local function stroke(o, c, t)
        local s = Instance.new("UIStroke")
        s.Color = c or COL.stroke
        s.Thickness = t or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = o
        return s
    end

    local function tween(o, d, p, s, dir)
        return TweenService:Create(o, TweenInfo.new(d, s or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
    end

    -- Parent ke PlayerGui (lebih aman dari CoreGui)
    local parentGui = PlayerGui
    if not parentGui then
        parentGui = game:GetService("CoreGui")
    end

    -- Destroy GUI lama kalau ada (biar reload bersih)
    local old = parentGui:FindFirstChild("BB_Mobile_Autoparry")
    if old then old:Destroy() end

    local root = Instance.new("ScreenGui")
    root.Name = "BB_Mobile_Autoparry"
    root.ResetOnSpawn = false
    root.IgnoreGuiInset = true
    root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    root.DisplayOrder = 2147483000 -- Hampir max, biar nggak ketiban GUI lain
    root.Parent = parentGui

    -- ========================================================
    -- FAB (floating action button)
    -- ========================================================
    local fab = Instance.new("TextButton")
    fab.Name = "FAB"
    fab.Size = UDim2.new(0, 60, 0, 60)
    fab.Position = UDim2.new(0, 20, 0.5, -30)
    fab.BackgroundColor3 = COL.bg
    fab.BorderSizePixel = 0
    fab.Text = ""
    fab.AutoButtonColor = false
    fab.Active = true
    fab.ZIndex = 100
    fab.Parent = root
    corner(fab, UDim.new(1, 0))
    stroke(fab, COL.strokeLit, 1)

    local fabDot = Instance.new("Frame")
    fabDot.Size = UDim2.new(0, 18, 0, 18)
    fabDot.Position = UDim2.new(0.5, -9, 0.5, -9)
    fabDot.BackgroundColor3 = COL.red
    fabDot.BorderSizePixel = 0
    fabDot.ZIndex = 101
    fabDot.Parent = fab
    corner(fabDot, UDim.new(1, 0))

    task.spawn(function()
        while root.Parent do
            task.wait(0.1)
            if System.__properties.__autoparry_enabled or System.__properties.__auto_spam_enabled then
                local t = (math.sin(tick() * 4) + 1) * 0.5
                fabDot.BackgroundColor3 = COL.green:Lerp(COL.greenDim, t)
            else
                fabDot.BackgroundColor3 = COL.red
            end
        end
    end)

    -- ========================================================
    -- PANEL
    -- ========================================================
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 300, 0, 540)
    panel.Position = UDim2.new(0.5, -150, 0.5, -270)
    panel.BackgroundColor3 = COL.bg
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.ZIndex = 50
    panel.Parent = root
    corner(panel, UDim.new(0, 16))
    stroke(panel, COL.strokeLit, 1)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 22, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 11, 15)),
    }
    grad.Rotation = 90
    grad.Parent = panel

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundTransparency = 1
    header.ZIndex = 51
    header.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 16, 0, 0)
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Text = "BLADE BALL"
    title.TextColor3 = COL.text
    title.FontFace = FONT.bold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 52
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 16, 0, 22)
    subtitle.Size = UDim2.new(1, -60, 0, 14)
    subtitle.Text = "mobile  •  autoparry + autospam"
    subtitle.TextColor3 = COL.textFaint
    subtitle.FontFace = FONT.reg
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 52
    subtitle.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 6)
    closeBtn.BackgroundColor3 = COL.bgSoft
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = COL.text
    closeBtn.FontFace = FONT.bold
    closeBtn.TextSize = 15
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 53
    closeBtn.Parent = header
    corner(closeBtn, UDim.new(0, 8))

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.new(0, 16, 0, 44)
    divider.BackgroundColor3 = COL.stroke
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.ZIndex = 51
    divider.Parent = panel

    -- Body (scroll)
    local body = Instance.new("ScrollingFrame")
    body.Position = UDim2.new(0, 14, 0, 56)
    body.Size = UDim2.new(1, -28, 1, -110)
    body.BackgroundTransparency = 1
    body.ScrollBarThickness = 0
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.ZIndex = 52
    body.Parent = panel

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 10)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    -- Toggle row helper
    local function makeToggleRow(titleText, subtitleText, order, onChange)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 56)
        row.BackgroundColor3 = COL.bgSoft
        row.BackgroundTransparency = 0.05
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.LayoutOrder = order
        row.ZIndex = 53
        row.Parent = body
        corner(row, UDim.new(0, 12))
        stroke(row, COL.stroke, 1)

        local ttl = Instance.new("TextLabel")
        ttl.BackgroundTransparency = 1
        ttl.Position = UDim2.new(0, 14, 0, 8)
        ttl.Size = UDim2.new(1, -80, 0, 18)
        ttl.Text = titleText
        ttl.TextColor3 = COL.text
        ttl.FontFace = FONT.bold
        ttl.TextSize = 13
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.ZIndex = 54
        ttl.Parent = row

        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.new(0, 14, 0, 28)
        sub.Size = UDim2.new(1, -80, 0, 16)
        sub.Text = subtitleText or ""
        sub.TextColor3 = COL.textFaint
        sub.FontFace = FONT.reg
        sub.TextSize = 10
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.ZIndex = 54
        sub.Parent = row

        local track = Instance.new("Frame")
        track.Size = UDim2.new(0, 40, 0, 22)
        track.Position = UDim2.new(1, -52, 0.5, -11)
        track.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        track.BorderSizePixel = 0
        track.ZIndex = 54
        track.Parent = row
        corner(track, UDim.new(1, 0))

        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, 18, 0, 18)
        thumb.Position = UDim2.new(0, 2, 0.5, -9)
        thumb.BackgroundColor3 = COL.textDim
        thumb.BorderSizePixel = 0
        thumb.ZIndex = 55
        thumb.Parent = track
        corner(thumb, UDim.new(1, 0))

        local active = false
        local function refresh()
            if active then
                tween(track, 0.25, {BackgroundColor3 = COL.greenDim}):Play()
                tween(thumb, 0.25, {Position = UDim2.new(0, 20, 0.5, -9), BackgroundColor3 = COL.green}):Play()
            else
                tween(track, 0.25, {BackgroundColor3 = Color3.fromRGB(40, 42, 50)}):Play()
                tween(thumb, 0.25, {Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = COL.textDim}):Play()
            end
        end

        row.MouseButton1Click:Connect(function()
            active = not active
            refresh()
            if onChange then onChange(active) end
        end)

        return { frame = row, set = function(v) active = v; refresh() end, get = function() return active end }
    end

    local apToggle = makeToggleRow("Auto Parry", "parry when ball targets you", 1, function(v)
        System.__properties.__autoparry_enabled = v
        if v then System.autoparry.start() else System.autoparry.stop() end
    end)

    local asToggle = makeToggleRow("Auto Spam", "spam parry when ball is close", 2, function(v)
        System.__properties.__auto_spam_enabled = v
        if v then System.auto_spam.start() else System.auto_spam.stop() end
    end)

    -- CPS row
    local cpsLabel = Instance.new("TextLabel")
    cpsLabel.BackgroundTransparency = 1
    cpsLabel.Size = UDim2.new(1, 0, 0, 16)
    cpsLabel.Text = "AUTO SPAM CPS  (200 – 2000)"
    cpsLabel.TextColor3 = COL.textFaint
    cpsLabel.FontFace = FONT.bold
    cpsLabel.TextSize = 10
    cpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    cpsLabel.LayoutOrder = 3
    cpsLabel.ZIndex = 53
    cpsLabel.Parent = body

    local cpsRow = Instance.new("Frame")
    cpsRow.Size = UDim2.new(1, 0, 0, 50)
    cpsRow.BackgroundColor3 = COL.bgSoft
    cpsRow.BackgroundTransparency = 0.05
    cpsRow.BorderSizePixel = 0
    cpsRow.LayoutOrder = 4
    cpsRow.ZIndex = 53
    cpsRow.Parent = body
    corner(cpsRow, UDim.new(0, 12))
    stroke(cpsRow, COL.stroke, 1)

    local cpsMinus = Instance.new("TextButton")
    cpsMinus.Size = UDim2.new(0, 46, 0, 40)
    cpsMinus.Position = UDim2.new(0, 6, 0.5, -20)
    cpsMinus.BackgroundColor3 = COL.bgDeep
    cpsMinus.Text = "−"
    cpsMinus.TextColor3 = COL.text
    cpsMinus.FontFace = FONT.bold
    cpsMinus.TextSize = 22
    cpsMinus.AutoButtonColor = false
    cpsMinus.BorderSizePixel = 0
    cpsMinus.ZIndex = 54
    cpsMinus.Parent = cpsRow
    corner(cpsMinus, UDim.new(0, 9))

    local cpsPlus = Instance.new("TextButton")
    cpsPlus.Size = UDim2.new(0, 46, 0, 40)
    cpsPlus.Position = UDim2.new(1, -52, 0.5, -20)
    cpsPlus.BackgroundColor3 = COL.bgDeep
    cpsPlus.Text = "+"
    cpsPlus.TextColor3 = COL.text
    cpsPlus.FontFace = FONT.bold
    cpsPlus.TextSize = 22
    cpsPlus.AutoButtonColor = false
    cpsPlus.BorderSizePixel = 0
    cpsPlus.ZIndex = 54
    cpsPlus.Parent = cpsRow
    corner(cpsPlus, UDim.new(0, 9))

    local cpsValue = Instance.new("TextLabel")
    cpsValue.BackgroundTransparency = 1
    cpsValue.Position = UDim2.new(0, 54, 0, 0)
    cpsValue.Size = UDim2.new(1, -108, 1, 0)
    cpsValue.Text = tostring(System.__properties.__auto_spam_cps)
    cpsValue.TextColor3 = COL.text
    cpsValue.FontFace = FONT.bold
    cpsValue.TextSize = 20
    cpsValue.ZIndex = 54
    cpsValue.Parent = cpsRow

    local CPS_MIN, CPS_MAX = 200, 2000
    local function setCPS(v)
        v = math.clamp(math.floor(v), CPS_MIN, CPS_MAX)
        System.__properties.__auto_spam_cps = v
        cpsValue.Text = tostring(v)
    end
    setCPS(System.__properties.__auto_spam_cps)

    cpsMinus.MouseButton1Click:Connect(function()
        setCPS(System.__properties.__auto_spam_cps - 50)
    end)
    cpsPlus.MouseButton1Click:Connect(function()
        setCPS(System.__properties.__auto_spam_cps + 50)
    end)

    -- Curve
    local curveLabel = Instance.new("TextLabel")
    curveLabel.BackgroundTransparency = 1
    curveLabel.Size = UDim2.new(1, 0, 0, 16)
    curveLabel.Text = "CURVE MODE"
    curveLabel.TextColor3 = COL.textFaint
    curveLabel.FontFace = FONT.bold
    curveLabel.TextSize = 10
    curveLabel.TextXAlignment = Enum.TextXAlignment.Left
    curveLabel.LayoutOrder = 5
    curveLabel.ZIndex = 53
    curveLabel.Parent = body

    local curveGrid = Instance.new("Frame")
    curveGrid.Size = UDim2.new(1, 0, 0, 76)
    curveGrid.BackgroundTransparency = 1
    curveGrid.LayoutOrder = 6
    curveGrid.ZIndex = 53
    curveGrid.Parent = body

    local curveLayout = Instance.new("UIGridLayout")
    curveLayout.CellSize = UDim2.new(0.25, -6, 0, 32)
    curveLayout.CellPadding = UDim.new(0, 8, 0, 8)
    curveLayout.SortOrder = Enum.SortOrder.LayoutOrder
    curveLayout.Parent = curveGrid

    local curveButtons = {}
    local function refreshCurve()
        for i, btn in ipairs(curveButtons) do
            if i == System.__properties.__curve_mode then
                tween(btn, 0.15, {BackgroundColor3 = COL.accent}):Play()
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                tween(btn, 0.15, {BackgroundColor3 = COL.bgSoft}):Play()
                btn.TextColor3 = COL.textDim
            end
        end
    end

    for i, name in ipairs(System.__config.__curve_names) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.BackgroundColor3 = COL.bgSoft
        b.Text = name
        b.TextColor3 = COL.textDim
        b.FontFace = FONT.bold
        b.TextSize = 10
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.LayoutOrder = i
        b.ZIndex = 54
        b.Parent = curveGrid
        corner(b, UDim.new(0, 8))
        stroke(b, COL.stroke, 1)
        b.MouseButton1Click:Connect(function()
            System.__properties.__curve_mode = i
            refreshCurve()
        end)
        curveButtons[i] = b
    end
    refreshCurve()

    -- Parry Accuracy
    local accLabel = Instance.new("TextLabel")
    accLabel.BackgroundTransparency = 1
    accLabel.Size = UDim2.new(1, 0, 0, 16)
    accLabel.Text = "PARRY ACCURACY"
    accLabel.TextColor3 = COL.textFaint
    accLabel.FontFace = FONT.bold
    accLabel.TextSize = 10
    accLabel.TextXAlignment = Enum.TextXAlignment.Left
    accLabel.LayoutOrder = 7
    accLabel.ZIndex = 53
    accLabel.Parent = body

    local accRow = Instance.new("Frame")
    accRow.Size = UDim2.new(1, 0, 0, 50)
    accRow.BackgroundColor3 = COL.bgSoft
    accRow.BackgroundTransparency = 0.05
    accRow.BorderSizePixel = 0
    accRow.LayoutOrder = 8
    accRow.ZIndex = 53
    accRow.Parent = body
    corner(accRow, UDim.new(0, 12))
    stroke(accRow, COL.stroke, 1)

    local accMinus = Instance.new("TextButton")
    accMinus.Size = UDim2.new(0, 46, 0, 40)
    accMinus.Position = UDim2.new(0, 6, 0.5, -20)
    accMinus.BackgroundColor3 = COL.bgDeep
    accMinus.Text = "−"
    accMinus.TextColor3 = COL.text
    accMinus.FontFace = FONT.bold
    accMinus.TextSize = 22
    accMinus.AutoButtonColor = false
    accMinus.BorderSizePixel = 0
    accMinus.ZIndex = 54
    accMinus.Parent = accRow
    corner(accMinus, UDim.new(0, 9))

    local accPlus = Instance.new("TextButton")
    accPlus.Size = UDim2.new(0, 46, 0, 40)
    accPlus.Position = UDim2.new(1, -52, 0.5, -20)
    accPlus.BackgroundColor3 = COL.bgDeep
    accPlus.Text = "+"
    accPlus.TextColor3 = COL.text
    accPlus.FontFace = FONT.bold
    accPlus.TextSize = 22
    accPlus.AutoButtonColor = false
    accPlus.BorderSizePixel = 0
    accPlus.ZIndex = 54
    accPlus.Parent = accRow
    corner(accPlus, UDim.new(0, 9))

    local accValue = Instance.new("TextLabel")
    accValue.BackgroundTransparency = 1
    accValue.Position = UDim2.new(0, 54, 0, 0)
    accValue.Size = UDim2.new(1, -108, 1, 0)
    accValue.Text = tostring(System.__properties.__accuracy)
    accValue.TextColor3 = COL.text
    accValue.FontFace = FONT.bold
    accValue.TextSize = 20
    accValue.ZIndex = 54
    accValue.Parent = accRow

    local function setAcc(v)
        v = math.clamp(math.floor(v), 1, 50)
        System.__properties.__accuracy = v
        accValue.Text = tostring(v)
        if not System.__properties.__humanizer_enabled then
            update_divisor()
        end
    end
    setAcc(System.__properties.__accuracy)
    accMinus.MouseButton1Click:Connect(function() setAcc(System.__properties.__accuracy - 1) end)
    accPlus.MouseButton1Click:Connect(function() setAcc(System.__properties.__accuracy + 1) end)

    -- Humanizer
    local humLabel = Instance.new("TextLabel")
    humLabel.BackgroundTransparency = 1
    humLabel.Size = UDim2.new(1, 0, 0, 16)
    humLabel.Text = "HUMANIZER"
    humLabel.TextColor3 = COL.textFaint
    humLabel.FontFace = FONT.bold
    humLabel.TextSize = 10
    humLabel.TextXAlignment = Enum.TextXAlignment.Left
    humLabel.LayoutOrder = 9
    humLabel.ZIndex = 53
    humLabel.Parent = body

    local humToggle = makeToggleRow("Random Accuracy", "vary parry timing ±", 10, function(v)
        System.__properties.__humanizer_enabled = v
        if v then update_randomized_accuracy() end
    end)

    local humRangeRow = Instance.new("Frame")
    humRangeRow.Size = UDim2.new(1, 0, 0, 56)
    humRangeRow.BackgroundColor3 = COL.bgSoft
    humRangeRow.BackgroundTransparency = 0.05
    humRangeRow.BorderSizePixel = 0
    humRangeRow.LayoutOrder = 11
    humRangeRow.ZIndex = 53
    humRangeRow.Parent = body
    corner(humRangeRow, UDim.new(0, 12))
    stroke(humRangeRow, COL.stroke, 1)

    local minLbl = Instance.new("TextLabel")
    minLbl.BackgroundTransparency = 1
    minLbl.Position = UDim2.new(0, 12, 0, 6)
    minLbl.Size = UDim2.new(0.5, -18, 0, 14)
    minLbl.Text = "MIN"
    minLbl.TextColor3 = COL.textFaint
    minLbl.FontFace = FONT.bold
    minLbl.TextSize = 9
    minLbl.TextXAlignment = Enum.TextXAlignment.Left
    minLbl.ZIndex = 54
    minLbl.Parent = humRangeRow

    local maxLbl = Instance.new("TextLabel")
    maxLbl.BackgroundTransparency = 1
    maxLbl.Position = UDim2.new(0.5, 6, 0, 6)
    maxLbl.Size = UDim2.new(0.5, -18, 0, 14)
    maxLbl.Text = "MAX"
    maxLbl.TextColor3 = COL.textFaint
    maxLbl.FontFace = FONT.bold
    maxLbl.TextSize = 9
    maxLbl.TextXAlignment = Enum.TextXAlignment.Left
    maxLbl.ZIndex = 54
    maxLbl.Parent = humRangeRow

    local function stepperRow(parent, xPos, initVal, minV, maxV, onChanged)
        local minus = Instance.new("TextButton")
        minus.Size = UDim2.new(0, 32, 0, 26)
        minus.Position = UDim2.new(xPos, 0, 0, 22)
        minus.BackgroundColor3 = COL.bgDeep
        minus.Text = "−"
        minus.TextColor3 = COL.text
        minus.FontFace = FONT.bold
        minus.TextSize = 16
        minus.AutoButtonColor = false
        minus.BorderSizePixel = 0
        minus.ZIndex = 55
        minus.Parent = parent
        corner(minus, UDim.new(0, 7))

        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Position = UDim2.new(xPos, 34, 0, 22)
        val.Size = UDim2.new(0, 40, 0, 26)
        val.Text = tostring(initVal)
        val.TextColor3 = COL.text
        val.FontFace = FONT.bold
        val.TextSize = 14
        val.ZIndex = 55
        val.Parent = parent

        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 32, 0, 26)
        plus.Position = UDim2.new(xPos, 76, 0, 22)
        plus.BackgroundColor3 = COL.bgDeep
        plus.Text = "+"
        plus.TextColor3 = COL.text
        plus.FontFace = FONT.bold
        plus.TextSize = 16
        plus.AutoButtonColor = false
        plus.BorderSizePixel = 0
        plus.ZIndex = 55
        plus.Parent = parent
        corner(plus, UDim.new(0, 7))

        local current = initVal
        local function set(v)
            v = math.clamp(math.floor(v), minV, maxV)
            current = v
            val.Text = tostring(v)
            if onChanged then onChanged(v) end
        end
        minus.MouseButton1Click:Connect(function() set(current - 1) end)
        plus.MouseButton1Click:Connect(function() set(current + 1) end)
        return { set = set, get = function() return current end }
    end

    stepperRow(humRangeRow, 12, System.__properties.__humanizer_min_accuracy, 1, 50, function(v)
        System.__properties.__humanizer_min_accuracy = v
    end)

    stepperRow(humRangeRow, 130, System.__properties.__humanizer_max_accuracy, 1, 50, function(v)
        System.__properties.__humanizer_max_accuracy = v
    end)

    -- Status bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, -32, 0, 34)
    statusBar.Position = UDim2.new(0, 16, 1, -46)
    statusBar.BackgroundColor3 = COL.bgDeep
    statusBar.BorderSizePixel = 0
    statusBar.ZIndex = 53
    statusBar.Parent = panel
    corner(statusBar, UDim.new(0, 10))
    stroke(statusBar, COL.stroke, 1)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 12, 0.5, -4)
    statusDot.BackgroundColor3 = COL.red
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 54
    statusDot.Parent = statusBar
    corner(statusDot, UDim.new(1, 0))

    local statusText = Instance.new("TextLabel")
    statusText.BackgroundTransparency = 1
    statusText.Position = UDim2.new(0, 26, 0, 0)
    statusText.Size = UDim2.new(1, -36, 1, 0)
    statusText.Text = "Waiting for patch..."
    statusText.TextColor3 = COL.textDim
    statusText.FontFace = FONT.med
    statusText.TextSize = 10
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.ZIndex = 54
    statusText.Parent = statusBar

    task.spawn(function()
        while root.Parent do
            task.wait(0.5)
            local patch_ready = _PARRY_PATCH.ready
            local ap = System.__properties.__autoparry_enabled
            local as = System.__properties.__auto_spam_enabled
            local ready_txt = patch_ready and "PATCH OK" or "PATCH..."
            if ap or as then
                statusDot.BackgroundColor3 = COL.green
                local parts = {}
                if ap then table.insert(parts, "AP") end
                if as then table.insert(parts, "AS @" .. System.__properties.__auto_spam_cps) end
                statusText.Text = ready_txt .. "  •  " .. table.concat(parts, " + ") .. " active"
            else
                statusDot.BackgroundColor3 = COL.red
                statusText.Text = ready_txt .. "  •  idle"
            end
        end
    end)

    -- ========================================================
    -- FAB CLICK → BUKA PANEL
    -- Pakai MouseButton1Click polos, nggak pakai manual tap detection
    -- ========================================================
    local opening = false
    local function openPanel()
        if opening then return end
        opening = true
        panel.Visible = true
        panel.Size = UDim2.new(0, 0, 0, 540)
        tween(panel, 0.3, {Size = UDim2.new(0, 300, 0, 540)}):Play()
        task.delay(0.35, function() opening = false end)
    end

    local function closePanel()
        tween(panel, 0.2, {Size = UDim2.new(0, 0, 0, 540)}):Play()
        task.delay(0.2, function()
            panel.Visible = false
        end)
    end

    fab.MouseButton1Click:Connect(function()
        if panel.Visible then
            closePanel()
        else
            openPanel()
        end
    end)

    closeBtn.MouseButton1Click:Connect(closePanel)

    -- Drag FAB (via InputBegan/InputChanged, TIDAK memblokir tap)
    do
        local dragging, dragStart, startPos, moved
        fab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                moved    = false
                dragStart = input.Position
                startPos  = fab.Position
            end
        end)
        fab.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - dragStart
                if math.abs(d.X) > 10 or math.abs(d.Y) > 10 then
                    moved = true
                    fab.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + d.X,
                        startPos.Y.Scale, startPos.Y.Offset + d.Y
                    )
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    -- Drag panel via header
    do
        local dragging, dragStart, startPos
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = panel.Position
            end
        end)
        header.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - dragStart
                panel.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    -- Auto open panel setelah 2 detik (biar keliatan)
    task.delay(2, function()
        if not panel.Visible then
            openPanel()
        end
    end)

    return true
end)

if not UI_OK then
    warn("[UI] gagal build UI:", tostring(UI_ERR))
    -- fallback notifikasi biar Redz tau UI gagal, tapi script tetap jalan
    pcall(function()
        local msg = Instance.new("Message")
        msg.Text = "[BB] UI gagal dibuild. Cek console. Logic autoparry tetap jalan."
        msg.Parent = PlayerGui
        task.delay(6, function() msg:Destroy() end)
    end)
end

-- ============================================================
-- 9. AUTO START LOGIC
-- ============================================================
System.__properties.__autoparry_enabled = true
System.__properties.__auto_spam_enabled = true
System.autoparry.start()
System.auto_spam.start()
update_divisor()
