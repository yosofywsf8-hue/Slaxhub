-- Blade Ball Mobile — Auto Parry + Auto Spam + Auto SoF
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
-- 3.5 AUTO SLASHES OF FURY — 36 clicks / 7 seconds
-- ============================================================
System.auto_sof = {
    __enabled      = true,
    __active       = false,
    __connection   = nil,
    __total_clicks = 36,
    __duration     = 7,
    __started_at   = 0,
    __clicked      = 0,
}

local function _sendSofSlash()
    local fired = false

    -- 1) remote AbilityButtonPress
    pcall(function()
        local RS2 = game:GetService("ReplicatedStorage")
        if RS2:FindFirstChild("Remotes") then
            local ab = RS2.Remotes:FindFirstChild("AbilityButtonPress")
            if ab and ab:IsA("RemoteEvent") then
                ab:FireServer()
                fired = true
            end
        end
    end)

    -- 2) fallback VirtualInputManager click
    if not fired then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.008)
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end
end

function System.auto_sof.start()
    if System.auto_sof.__connection then
        System.auto_sof.__connection:Disconnect()
        System.auto_sof.__connection = nil
    end

    System.auto_sof.__connection = RunService.Heartbeat:Connect(function()
        if not System.auto_sof.__enabled then return end
        if not System.auto_sof.__active then return end

        local total    = System.auto_sof.__total_clicks
        local duration = System.auto_sof.__duration
        local elapsed  = tick() - System.auto_sof.__started_at

        if System.auto_sof.__clicked >= total then return end
        if elapsed >= duration then return end

        local next_index  = System.auto_sof.__clicked + 1
        local target_time = (next_index / total) * duration

        if elapsed >= target_time then
            _sendSofSlash()
            System.auto_sof.__clicked += 1
        end
    end)
end

function System.auto_sof.stop()
    System.auto_sof.__enabled = false
    System.auto_sof.__active  = false
    if System.auto_sof.__connection then
        System.auto_sof.__connection:Disconnect()
        System.auto_sof.__connection = nil
    end
end

function System.auto_sof.set_enabled(state)
    System.auto_sof.__enabled = state
    if state then
        if not System.auto_sof.__connection then
            System.auto_sof.start()
        end
    else
        System.auto_sof.stop()
    end
end

function System.auto_sof.reset()
    System.auto_sof.__started_at = tick()
    System.auto_sof.__clicked    = 0
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

        -- AUTO SoF: reset window dan aktifkan
        if System.auto_sof then
            System.auto_sof.reset()
            System.auto_sof.__active = true
        end

        -- Safety auto-clear
        task.delay(8, function()
            if System.__properties.__slashesoffury_active then
                System.__properties.__slashesoffury_active = false
                System.__properties.__slashesoffury_count  = 0
                if System.auto_sof then
                    System.auto_sof.__active = false
                end
            end
        end)
    end
end)
netFolder["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_active = false
    System.__properties.__slashesoffury_count  = 0
    if System.auto_sof then
        System.auto_sof.__active = false
    end
end)
netFolder["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_count += 1
end)
netFolder["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    -- no-op
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

            if System.__config.__detections.__slashesoffury
               and System.__properties.__slashesoffury_active then
                continue
            end

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
-- 8. PRO MOBILE UI (Tabbed: Main + Detection)
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

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0,10); c.Parent = o; return c end
local function stroke(o, c, t) local s = Instance.new("UIStroke"); s.Color = c or COL.stroke; s.Thickness = t or 1; s.Parent = o; return s end
local function tween(o, d, p, s, dir)
    return TweenService:Create(o, TweenInfo.new(d, s or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
end

local parentGui = LocalPlayer:WaitForChild("PlayerGui")
local oldPG = parentGui:FindFirstChild("BB_Mobile_Autoparry")
if oldPG then oldPG:Destroy() end
local oldCG = CoreGui:FindFirstChild("BB_Mobile_Autoparry")
if oldCG then oldCG:Destroy() end

local root = Instance.new("ScreenGui")
root.Name = "BB_Mobile_Autoparry"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 1000000
root.Parent = parentGui

-- FAB
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
fabDot.Size = UDim2.new(0, 20, 0, 20)
fabDot.Position = UDim2.new(0.5, -10, 0.5, -10)
fabDot.BackgroundColor3 = COL.green
fabDot.BorderSizePixel = 0
fabDot.ZIndex = 101
fabDot.Parent = fab
corner(fabDot, UDim.new(1, 0))

RunService.Heartbeat:Connect(function()
    if not fabDot or not fabDot.Parent then return end
    if System.__properties.__slashesoffury_active then
        fabDot.BackgroundColor3 = COL.amber
    elseif System.__properties.__autoparry_enabled or System.__properties.__auto_spam_enabled then
        local t = (math.sin(tick() * 4) + 1) * 0.5
        fabDot.BackgroundColor3 = COL.green:Lerp(COL.greenDim, t)
    else
        fabDot.BackgroundColor3 = COL.red
    end
end)

-- PANEL
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 280, 0, 420)
panel.Position = UDim2.new(0.5, -140, 0.5, -210)
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
subtitle.Text = "mobile  •  autoparry + autospam + autosoF"
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
closeBtn.Text = "X"
closeBtn.TextColor3 = COL.text
closeBtn.FontFace = FONT.bold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 53
closeBtn.Parent = header
corner(closeBtn, UDim.new(0, 8))

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -32, 0, 30)
tabBar.Position = UDim2.new(0, 16, 0, 48)
tabBar.BackgroundColor3 = COL.bgDeep
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 51
tabBar.Parent = panel
corner(tabBar, UDim.new(0, 8))
stroke(tabBar, COL.stroke, 1)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 6)
tabPad.Parent = tabBar

local mainTabBtn = Instance.new("TextButton")
mainTabBtn.Size = UDim2.new(0.5, -9, 0, 22)
mainTabBtn.BackgroundColor3 = COL.accent
mainTabBtn.Text = "Main"
mainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainTabBtn.FontFace = FONT.bold
mainTabBtn.TextSize = 11
mainTabBtn.AutoButtonColor = false
mainTabBtn.BorderSizePixel = 0
mainTabBtn.LayoutOrder = 1
mainTabBtn.ZIndex = 52
mainTabBtn.Parent = tabBar
corner(mainTabBtn, UDim.new(0, 6))

local detectTabBtn = Instance.new("TextButton")
detectTabBtn.Size = UDim2.new(0.5, -9, 0, 22)
detectTabBtn.BackgroundColor3 = COL.bgSoft
detectTabBtn.Text = "Detection"
detectTabBtn.TextColor3 = COL.textDim
detectTabBtn.FontFace = FONT.bold
detectTabBtn.TextSize = 11
detectTabBtn.AutoButtonColor = false
detectTabBtn.BorderSizePixel = 0
detectTabBtn.LayoutOrder = 2
detectTabBtn.ZIndex = 52
detectTabBtn.Parent = tabBar
corner(detectTabBtn, UDim.new(0, 6))

local bodyHolder = Instance.new("Frame")
bodyHolder.Position = UDim2.new(0, 14, 0, 86)
bodyHolder.Size = UDim2.new(1, -28, 1, -140)
bodyHolder.BackgroundTransparency = 1
bodyHolder.ZIndex = 52
bodyHolder.Parent = panel

local body = Instance.new("ScrollingFrame")
body.Position = UDim2.new(0, 0, 0, 0)
body.Size = UDim2.new(1, 0, 1, 0)
body.BackgroundTransparency = 1
body.ScrollBarThickness = 0
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.ZIndex = 53
body.Visible = true
body.Parent = bodyHolder

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, 10)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = body

local detBody = Instance.new("ScrollingFrame")
detBody.Position = UDim2.new(0, 0, 0, 0)
detBody.Size = UDim2.new(1, 0, 1, 0)
detBody.BackgroundTransparency = 1
detBody.ScrollBarThickness = 0
detBody.CanvasSize = UDim2.new(0, 0, 0, 0)
detBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
detBody.ZIndex = 53
detBody.Visible = false
detBody.Parent = bodyHolder

local detLayout = Instance.new("UIListLayout")
detLayout.Padding = UDim.new(0, 10)
detLayout.SortOrder = Enum.SortOrder.LayoutOrder
detLayout.Parent = detBody

local function switchTab(which)
    if which == "main" then
        body.Visible = true
        detBody.Visible = false
        mainTabBtn.BackgroundColor3 = COL.accent
        mainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        detectTabBtn.BackgroundColor3 = COL.bgSoft
        detectTabBtn.TextColor3 = COL.textDim
    else
        body.Visible = false
        detBody.Visible = true
        mainTabBtn.BackgroundColor3 = COL.bgSoft
        mainTabBtn.TextColor3 = COL.textDim
        detectTabBtn.BackgroundColor3 = COL.accent
        detectTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

mainTabBtn.MouseButton1Click:Connect(function() switchTab("main") end)
detectTabBtn.MouseButton1Click:Connect(function() switchTab("detect") end)

local function makeToggleRow(parent, titleText, subtitleText, order, onChange)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = COL.bgSoft
    row.BackgroundTransparency = 0.05
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.LayoutOrder = order
    row.ZIndex = 54
    row.Parent = parent
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
    ttl.ZIndex = 55
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
    sub.ZIndex = 55
    sub.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 22)
    track.Position = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
    track.BorderSizePixel = 0
    track.ZIndex = 55
    track.Parent = row
    corner(track, UDim.new(1, 0))

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 18, 0, 18)
    thumb.Position = UDim2.new(0, 2, 0.5, -9)
    thumb.BackgroundColor3 = COL.textDim
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 56
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

    return {
        frame = row,
        set = function(v) active = v; refresh() end,
        get = function() return active end,
    }
end

-- Main tab
local apToggle = makeToggleRow(body, "Auto Parry", "parry when ball targets you", 1, function(v)
    System.__properties.__autoparry_enabled = v
    if v then System.autoparry.start() else System.autoparry.stop() end
end)

local asToggle = makeToggleRow(body, "Auto Spam", "spam parry when ball is close", 2, function(v)
    System.__properties.__auto_spam_enabled = v
    if v then System.auto_spam.start() else System.auto_spam.stop() end
end)

local curveLabel = Instance.new("TextLabel")
curveLabel.BackgroundTransparency = 1
curveLabel.Size = UDim2.new(1, 0, 0, 16)
curveLabel.Text = "CURVE MODE"
curveLabel.TextColor3 = COL.textFaint
curveLabel.FontFace = FONT.bold
curveLabel.TextSize = 10
curveLabel.TextXAlignment = Enum.TextXAlignment.Left
curveLabel.LayoutOrder = 3
curveLabel.ZIndex = 54
curveLabel.Parent = body

local curveGrid = Instance.new("Frame")
curveGrid.Size = UDim2.new(1, 0, 0, 76)
curveGrid.BackgroundTransparency = 1
curveGrid.LayoutOrder = 4
curveGrid.ZIndex = 54
curveGrid.Parent = body

local curveLayout = Instance.new("UIGridLayout")
curveLayout.CellSize = UDim2.new(0.25, -6, 0, 32)
curveLayout.CellPadding = UDim2.new(0, 8, 0, 8)
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
    b.ZIndex = 55
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

-- Detection tab
makeToggleRow(detBody, "Infinity Ball", "skip parry while active", 1, function(v)
    System.__config.__detections.__infinity = v
end).set(true)

makeToggleRow(detBody, "Death Slash", "skip parry while active", 2, function(v)
    System.__config.__detections.__deathslash = v
end).set(true)

makeToggleRow(detBody, "Time Hole", "skip parry while active", 3, function(v)
    System.__config.__detections.__timehole = v
end).set(true)

makeToggleRow(detBody, "Slashes Of Fury", "pause autoparry while active", 4, function(v)
    System.__config.__detections.__slashesoffury = v
end).set(true)

makeToggleRow(detBody, "Auto Slashes of Fury", "36 clicks over 7 seconds", 5, function(v)
    System.auto_sof.set_enabled(v)
end).set(true)

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
        task.wait(0.3)
        local patch_ready = _PARRY_PATCH.ready
        local ap = System.__properties.__autoparry_enabled
        local as = System.__properties.__auto_spam_enabled
        local sof = System.__properties.__slashesoffury_active
        local sof_count = System.auto_sof and System.auto_sof.__clicked or 0
        local ready_txt = patch_ready and "PATCH OK" or "PATCH..."
        if sof then
            statusDot.BackgroundColor3 = COL.amber
            statusText.Text = "SoF  •  clicks " .. sof_count .. "/36"
        elseif ap or as then
            statusDot.BackgroundColor3 = COL.green
            local parts = {}
            if ap then table.insert(parts, "AP") end
            if as then table.insert(parts, "AS") end
            statusText.Text = ready_txt .. "  •  " .. table.concat(parts, " + ") .. " active"
        else
            statusDot.BackgroundColor3 = COL.red
            statusText.Text = ready_txt .. "  •  idle"
        end
    end
end)

-- FAB open/close
local opening = false
local function openPanel()
    if opening then return end
    opening = true
    panel.Visible = true
    panel.Size = UDim2.new(0, 0, 0, 420)
    tween(panel, 0.3, {Size = UDim2.new(0, 280, 0, 420)}):Play()
    task.delay(0.35, function() opening = false end)
end

local function closePanel()
    tween(panel, 0.2, {Size = UDim2.new(0, 0, 0, 420)}):Play()
    task.delay(0.2, function() panel.Visible = false end)
end

fab.MouseButton1Click:Connect(function()
    if panel.Visible then closePanel() else openPanel() end
end)

closeBtn.MouseButton1Click:Connect(closePanel)

-- Drag FAB
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
            if math.abs(d.X) > 12 or math.abs(d.Y) > 12 then
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

-- Drag panel
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

task.delay(2, function()
    if not panel.Visible then openPanel() end
end)

apToggle.set(true)
asToggle.set(true)

return true
end)

if not UI_OK then
    warn("[UI] failed to build UI:", tostring(UI_ERR))
end

-- ============================================================
-- 9. AUTO START
-- ============================================================
System.__properties.__autoparry_enabled = true
System.__properties.__auto_spam_enabled = true
System.autoparry.start()
System.auto_spam.start()
System.auto_sof.start()
update_divisor()
