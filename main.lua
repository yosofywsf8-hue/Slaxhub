-- Blade Ball Mobile — Auto Parry + Auto Spam + Manual Spam + No Render + FPS Boost
-- Runtime: Roblox mobile / PC
-- Executor: cloneref, getupvalues, getrawmetatable, setreadonly, loadstring

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
            if child.Name:sub(1, 16) == "SwordsController" then
                SC = child
                break
            end
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
        if (key == "FireServer"   and self:IsA("RemoteEvent"))
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
            _PARRY_PATCH.parryHash,
            currentKey,
            token,
            0.5,
            curveCFrame,
            screenPositions,
            mouseLocation,
            false
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

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local Alive   = workspace:FindFirstChild("Alive")   or workspace:WaitForChild("Alive")
local Runtime = workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime")

-- ============================================================
-- 3. STATE
-- ============================================================
local System = {
    __properties = {
        __autoparry_enabled  = false,
        __auto_spam_enabled  = false,
        __manual_spam_enabled = false,
        __curve_mode         = 1,
        __accuracy           = 1,
        __divisor_multiplier = 1.1,
        __parried            = false,
        __training_parried   = false,
        __parries            = 0,
        __spam_threshold     = 1.5,
        __tornado_time       = tick(),
        __connections        = {},
        __infinity_active    = false,
        __deathslash_active  = false,
        __timehole_active    = false,
        __slashesoffury_active = false,
        __slashesoffury_count  = 0,
        __no_render_enabled  = false,
        __fps_boost_enabled  = false,
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

        if System.__config.__detections.__slashesoffury
           and System.__properties.__slashesoffury_active then
            return
        end

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

        if System.__properties.__slashesoffury_active then return end

        local ball = System.ball.get()
        if not ball then return end

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
System.manual_spam = {
    __enabled = false,
    __rate    = 20,
    __conn    = nil,
    __accum   = 0,
}

function System.manual_spam.start()
    if System.manual_spam.__conn then
        System.manual_spam.__conn:Disconnect()
        System.manual_spam.__conn = nil
    end

    System.manual_spam.__accum = 0

    System.manual_spam.__conn = RunService.Heartbeat:Connect(function(delta)
        if not System.__properties.__manual_spam_enabled then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end

        local rate = math.clamp(System.manual_spam.__rate or 20, 1, 200)
        local interval = 1 / rate

        System.manual_spam.__accum += delta
        if System.manual_spam.__accum < interval then return end
        System.manual_spam.__accum = 0

        System.parry.execute()
    end)
end

function System.manual_spam.stop()
    if System.manual_spam.__conn then
        System.manual_spam.__conn:Disconnect()
        System.manual_spam.__conn = nil
    end
    System.__properties.__manual_spam_enabled = false
end

-- ============================================================
-- 7.6 NO RENDER
-- ============================================================
System.no_render = {
    __conn = nil,
}

function System.no_render.start()
    if System.no_render.__conn then
        System.no_render.__conn:Disconnect()
        System.no_render.__conn = nil
    end

    -- Disable ClientFX scripts
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local es = ps and ps:FindFirstChild("EffectScripts")
        local cfx = es and es:FindFirstChild("ClientFX")
        if cfx then cfx.Disabled = true end
    end)

    -- Destroy runtime effects as they spawn
    System.no_render.__conn = workspace.ChildAdded:Connect(function(child)
        if not System.__properties.__no_render_enabled then return end
        if child.Name == "Runtime" then
            child.ChildAdded:Connect(function(grand)
                if System.__properties.__no_render_enabled then
                    pcall(function()
                        game:GetService("Debris"):AddItem(grand, 0)
                    end)
                end
            end)
        end
    end)
end

function System.no_render.stop()
    if System.no_render.__conn then
        System.no_render.__conn:Disconnect()
        System.no_render.__conn = nil
    end
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local es = ps and ps:FindFirstChild("EffectScripts")
        local cfx = es and es:FindFirstChild("ClientFX")
        if cfx then cfx.Disabled = false end
    end)
end

-- ============================================================
-- 7.7 FPS BOOST
-- ============================================================
System.fps_boost = {
    __orig = {},
    __loop = nil,
}

local function _fps_boost_apply()
    local L = Lighting

    if not System.fps_boost.__orig.Brightness then
        System.fps_boost.__orig.Brightness       = L.Brightness
        System.fps_boost.__orig.GlobalShadows    = L.GlobalShadows
        System.fps_boost.__orig.OutdoorAmbient   = L.OutdoorAmbient
        System.fps_boost.__orig.Ambient          = L.Ambient
        System.fps_boost.__orig.FogEnd           = L.FogEnd
        System.fps_boost.__orig.FogStart         = L.FogStart
        System.fps_boost.__orig.EnvironmentDiffuseScale  = L.EnvironmentDiffuseScale
        System.fps_boost.__orig.EnvironmentSpecularScale = L.EnvironmentSpecularScale
    end

    pcall(function()
        L.GlobalShadows = false
        L.Brightness = 2
        L.EnvironmentDiffuseScale = 0
        L.EnvironmentSpecularScale = 0
        L.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        L.FogEnd = 100000
        L.FogStart = 0
    end)

    -- Disable post effects
    for _, v in ipairs(L:GetDescendants()) do
        pcall(function()
            if v:IsA("PostEffect") and v.Enabled then
                System.fps_boost.__orig[v] = true
                v.Enabled = false
            end
        end)
    end

    -- Lower quality
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    -- Disable particles / cast shadows in workspace
    System.fps_boost.__loop = RunService.Heartbeat:Connect(function()
        if not System.__properties.__fps_boost_enabled then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire")
                or obj:IsA("Smoke") or obj:IsA("Sparkles")
                or obj:IsA("Trail") or obj:IsA("Beam") then
                    obj.Enabled = false
                elseif obj:IsA("BasePart") then
                    obj.CastShadow = false
                end
            end)
        end
    end)
end

local function _fps_boost_restore()
    local L = Lighting
    local o = System.fps_boost.__orig
    pcall(function()
        if o.Brightness then L.Brightness = o.Brightness end
        if o.GlobalShadows ~= nil then L.GlobalShadows = o.GlobalShadows end
        if o.OutdoorAmbient then L.OutdoorAmbient = o.OutdoorAmbient end
        if o.Ambient then L.Ambient = o.Ambient end
        if o.FogEnd then L.FogEnd = o.FogEnd end
        if o.FogStart then L.FogStart = o.FogStart end
        if o.EnvironmentDiffuseScale then L.EnvironmentDiffuseScale = o.EnvironmentDiffuseScale end
        if o.EnvironmentSpecularScale then L.EnvironmentSpecularScale = o.EnvironmentSpecularScale end
    end)

    for effect, _ in pairs(System.fps_boost.__orig) do
        if typeof(effect) == "Instance" and effect:IsA("PostEffect") then
            pcall(function() effect.Enabled = true end)
        end
    end

    if System.fps_boost.__loop then
        System.fps_boost.__loop:Disconnect()
        System.fps_boost.__loop = nil
    end
end

function System.fps_boost.start()
    if System.__properties.__fps_boost_enabled then return end
    System.__properties.__fps_boost_enabled = true
    _fps_boost_apply()
end

function System.fps_boost.stop()
    System.__properties.__fps_boost_enabled = false
    _fps_boost_restore()
end

-- ============================================================
-- 7.8 HOTKEYS (PC) — T / C / E
-- ============================================================
System.hotkeys = {
    __enabled = true,
    __conn    = nil,
}

local HOTKEY_MAP = {
    [Enum.KeyCode.T] = function()
        local new = not System.__properties.__autoparry_enabled
        System.__properties.__autoparry_enabled = new
        if new then
            System.autoparry.start()
        else
            System.autoparry.stop()
        end
    end,

    [Enum.KeyCode.C] = function()
        local new = not System.__properties.__auto_spam_enabled
        System.__properties.__auto_spam_enabled = new
        if new then
            System.auto_spam.start()
        else
            System.auto_spam.stop()
        end
    end,

    [Enum.KeyCode.E] = function()
        local new = not System.__properties.__manual_spam_enabled
        System.__properties.__manual_spam_enabled = new
        if new then
            System.manual_spam.start()
        else
            System.manual_spam.stop()
        end
    end,
}

function System.hotkeys.start()
    if System.hotkeys.__conn then
        System.hotkeys.__conn:Disconnect()
        System.hotkeys.__conn = nil
    end

    System.hotkeys.__conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not System.hotkeys.__enabled then return end

        local fn = HOTKEY_MAP[input.KeyCode]
        if fn then
            pcall(fn)
        end
    end)
end

function System.hotkeys.stop()
    if System.hotkeys.__conn then
        System.hotkeys.__conn:Disconnect()
        System.hotkeys.__conn = nil
    end
end

System.hotkeys.start()

-- ============================================================
-- 8. WIND UI
-- ============================================================
local WindUI_OK, WindUI_ERR = pcall(function()

    for _, gui_name in ipairs({"WindUI", "WindUI_Parent"}) do
        local cg = CoreGui:FindFirstChild(gui_name)
        if cg then cg:Destroy() end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local pgc = pg:FindFirstChild(gui_name)
            if pgc then pgc:Destroy() end
        end
    end

    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

    WindUI:SetTheme("Dark")

    local Window = WindUI:CreateWindow({
        Title = "Blade Ball",
        Icon = "swords",
        Author = "mobile",
        Folder = "BladeBallAuto",
        Size = UDim2.fromOffset(520, 340),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 180,
        HasOutline = true,
    })

    pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)

    WindUI:Notify({
        Title = "Blade Ball",
        Content = "Hotkeys: T = AutoParry / C = AutoSpam / E = ManualSpam",
        Duration = 6,
    })

    -- MAIN TAB
    local MainTab = Window:Tab({ Title = "Main", Icon = "home" })

    MainTab:Toggle({
        Title = "Auto Parry  [T]",
        Desc = "parry when ball targets you",
        Value = true,
        Callback = function(v)
            System.__properties.__autoparry_enabled = v
            if v then System.autoparry.start() else System.autoparry.stop() end
        end,
    })

    MainTab:Toggle({
        Title = "Auto Spam  [C]",
        Desc = "spam parry when ball is close",
        Value = true,
        Callback = function(v)
            System.__properties.__auto_spam_enabled = v
            if v then System.auto_spam.start() else System.auto_spam.stop() end
        end,
    })

    MainTab:Toggle({
        Title = "Manual Spam  [E]",
        Desc = "spam parry at fixed rate",
        Value = false,
        Callback = function(v)
            System.__properties.__manual_spam_enabled = v
            if v then System.manual_spam.start() else System.manual_spam.stop() end
        end,
    })

    MainTab:Slider({
        Title = "Manual Spam Rate",
        Desc = "clicks per second",
        Value = {
            Min = 1,
            Max = 200,
            Default = 20,
        },
        Callback = function(v)
            System.manual_spam.__rate = v
        end,
    })

    MainTab:Dropdown({
        Title = "Curve Mode",
        Values = System.__config.__curve_names,
        Value = 1,
        Multi = false,
        Callback = function(v)
            for i, name in ipairs(System.__config.__curve_names) do
                if name == v then
                    System.__properties.__curve_mode = i
                    break
                end
            end
        end,
    })

    -- DETECTION TAB
    local DetectTab = Window:Tab({ Title = "Detection", Icon = "shield" })

    DetectTab:Toggle({
        Title = "Infinity Ball",
        Desc = "pause parry while active",
        Value = true,
        Callback = function(v) System.__config.__detections.__infinity = v end,
    })

    DetectTab:Toggle({
        Title = "Death Slash",
        Desc = "pause parry while active",
        Value = true,
        Callback = function(v) System.__config.__detections.__deathslash = v end,
    })

    DetectTab:Toggle({
        Title = "Time Hole",
        Desc = "pause parry while active",
        Value = true,
        Callback = function(v) System.__config.__detections.__timehole = v end,
    })

    DetectTab:Toggle({
        Title = "Slashes Of Fury",
        Desc = "pause parry while active",
        Value = true,
        Callback = function(v) System.__config.__detections.__slashesoffury = v end,
    })

    -- VISUAL TAB
    local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

    VisualTab:Toggle({
        Title = "No Render",
        Desc = "disable in-game effects",
        Value = false,
        Callback = function(v)
            System.__properties.__no_render_enabled = v
            if v then System.no_render.start() else System.no_render.stop() end
        end,
    })

    VisualTab:Toggle({
        Title = "FPS Boost",
        Desc = "disable shadows & post effects",
        Value = false,
        Callback = function(v)
            System.__properties.__fps_boost_enabled = v
            if v then System.fps_boost.start() else System.fps_boost.stop() end
        end,
    })

    return true
end)

if not WindUI_OK then
    warn("[WindUI] failed:", tostring(WindUI_ERR))
end

-- ============================================================
-- 9. AUTO START
-- ============================================================
System.__properties.__autoparry_enabled = true
System.__properties.__auto_spam_enabled = true
System.autoparry.start()
System.auto_spam.start()
System.manual_spam.start()
System.no_render.start()
update_divisor()
