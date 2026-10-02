-- Blade Ball — Auto Parry + Auto Spam + Manual Spam + No Render + FPS Boost + SoF
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
local SoundService     = cloneref(game:GetService("SoundService"))
local Debris           = cloneref(game:GetService("Debris"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

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
        __accuracy            = 1,
        __divisor_multiplier  = 1.1,
        __parried             = false,
        __training_parried    = false,
        __parries             = 0,
        __spam_threshold      = 1.5,
        __spam_accumulator    = 0,
        __spam_rate           = 1000,
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

-- SoF constants (dari gist)
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
-- 5. DETECTION HOOKS — NASKAH GIST ASLI
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
    local args = {...}
    local player = args[1]
    if player == LocalPlayer or player == LocalPlayer.Name or (player and player.Name == LocalPlayer.Name) then
        System.__properties.__timehole_active = true
    end
end)

netFolder["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
    System.__properties.__timehole_active = false
end)

netFolder["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    local args = {...}
    local player = args[1]
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
            else
                break
            end
        end
    end)
end)

-- ============================================================
-- 6. AUTOPARRY — NASKAH GIST ASLI
-- ============================================================
System.autoparry = {}

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or
           not LocalPlayer.Character.PrimaryPart then
            return
        end
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        local training_ball = nil
        if workspace:FindFirstChild("TrainingBalls") then
            for _, Instance in pairs(workspace.TrainingBalls:GetChildren()) do
                if Instance:GetAttribute("realBall") then
                    training_ball = Instance
                    break
                end
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
                   (Runtime.Tornado:GetAttribute('TornadoTime') or 1) + 0.314159 then
                    continue
                end
            end
            if one_ball and one_ball:GetAttribute('target') == LocalPlayer.Name and curved then
                continue
            end
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
            repeat
                RunService.Stepped:Wait()
            until (tick() - last_parrys) >= 1 or not System.__properties.__parried
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
                        repeat
                            RunService.Stepped:Wait()
                        until (tick() - last_parrys) >= 1 or not System.__properties.__training_parried
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
-- 7. AUTO SPAM — NASKAH GIST ASLI
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
        if System.__properties.__slashesoffury_active then return end

        local ball = System.ball.get()
        if not ball then return end

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
-- 7.5 MANUAL SPAM — logika persis gist
-- ============================================================
System.manual_spam = {}

function System.manual_spam.loop(delta)
    if not System.__properties.__manual_spam_enabled then return end
    if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= Alive then return end
    if getgenv().spamui then return end

    System.__properties.__spam_accumulator =
        (System.__properties.__spam_accumulator or 0) + delta

    local interval
    if getgenv().ManualSpamCPSEnabled then
        interval = 1 / math.max(1, System.__properties.__spam_rate or 100)
    else
        interval = 1 / math.max(1, System.__properties.__spam_rate or 100)
    end
    if (System.__properties.__spam_accumulator or 0) < interval then
        return
    end

    System.__properties.__spam_accumulator = 0
    System.parry.execute()
end

function System.manual_spam.start()
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
    end
    System.__properties.__manual_spam_enabled = true
    System.__properties.__connections.__manual_spam =
        RunService.Heartbeat:Connect(System.manual_spam.loop)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
        System.__properties.__connections.__manual_spam = nil
    end
end

-- ============================================================
-- 7.55 MANUAL SPAM FLOATING BUTTON
-- ============================================================
System.manual_button = {
    __gui    = nil,
    __btn    = nil,
    __dot    = nil,
    __label  = nil,
    __active = false,
}

function System.manual_button.create()
    if System.manual_button.__gui then return end
    local parentGui = LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "BB_ManualSpamBtn"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1000001
    gui.Parent = parentGui

    local btn = Instance.new("TextButton")
    btn.Name = "Btn"
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = UDim2.new(0, 20, 0.5, 100)
    btn.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = 100
    btn.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = btn
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(78, 84, 100)
    s.Thickness = 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 0, 0.5, -8)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Text = "SPAM"
    lbl.TextColor3 = Color3.fromRGB(238, 240, 246)
    lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.ZIndex = 101
    lbl.Parent = btn

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = UDim2.new(1, -6, 0, -6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(230, 90, 100)
    dot.BorderSizePixel = 0
    dot.ZIndex = 102
    dot.Parent = btn
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
    local ds = Instance.new("UIStroke")
    ds.Color = Color3.fromRGB(16, 17, 22)
    ds.Thickness = 2
    ds.Parent = dot

    System.manual_button.__gui   = gui
    System.manual_button.__btn   = btn
    System.manual_button.__dot   = dot
    System.manual_button.__label = lbl

    btn.MouseButton1Click:Connect(function()
        local new = not System.manual_button.__active
        System.manual_button.set(new)
    end)

    local dragging, dragStart, startPos, moved
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = btn.Position
        end
    end)
    btn.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            if math.abs(d.X) > 8 or math.abs(d.Y) > 8 then
                moved = true
                btn.Position = UDim2.new(
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

function System.manual_button.set(state)
    System.manual_button.__active = state
    System.__properties.__manual_spam_enabled = state

    if state then
        System.manual_spam.start()
        if System.manual_button.__dot then
            System.manual_button.__dot.BackgroundColor3 = Color3.fromRGB(88, 210, 140)
        end
        if System.manual_button.__label then
            System.manual_button.__label.Text = "SPAM"
            System.manual_button.__label.TextColor3 = Color3.fromRGB(88, 210, 140)
        end
        if System.manual_button.__btn then
            System.manual_button.__btn.BackgroundColor3 = Color3.fromRGB(26, 40, 32)
        end
    else
        System.manual_spam.stop()
        if System.manual_button.__dot then
            System.manual_button.__dot.BackgroundColor3 = Color3.fromRGB(230, 90, 100)
        end
        if System.manual_button.__label then
            System.manual_button.__label.Text = "SPAM"
            System.manual_button.__label.TextColor3 = Color3.fromRGB(238, 240, 246)
        end
        if System.manual_button.__btn then
            System.manual_button.__btn.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
        end
    end
end

System.manual_button.create()

-- ============================================================
-- 7.6 NO RENDER — sama persis kayak gist
-- ============================================================
function System.no_render_set(state)
    System.__properties.__no_render_enabled = state

    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local effectScripts = playerScripts and playerScripts:FindFirstChild("EffectScripts")
    local clientFX      = effectScripts and effectScripts:FindFirstChild("ClientFX")

    if clientFX then
        clientFX.Disabled = state
    end

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
-- 7.7 FPS BOOST — sama persis kayak gist
-- ============================================================
local original_fog_end   = Lighting.FogEnd
local original_fog_start = Lighting.FogStart
local postprocessing_backup = {}
local decals_backup         = {}
local scene_backup          = {}
local sound_backup          = nil
local lighting_backup       = nil
local fog_backup            = nil
local fps_boost_loop        = nil
local fps_boost_enabled     = false

local function apply_disable_fog(state)
    if state then
        Lighting.FogEnd = math.huge
        Lighting.FogStart = math.huge
    else
        Lighting.FogEnd = original_fog_end
        Lighting.FogStart = original_fog_start
    end
end

local function apply_disable_postprocessing(state)
    if state then
        for _, v in pairs(Lighting:GetDescendants()) do
            pcall(function()
                if v.Enabled ~= nil then
                    postprocessing_backup[v] = v.Enabled
                    v.Enabled = false
                end
            end)
        end
        fog_backup = {
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
        }
        pcall(function()
            Lighting.FogEnd = math.huge
            Lighting.FogStart = math.huge
            Lighting.FogColor = Color3.new(0, 0, 0)
        end)
    else
        for v, enabled in pairs(postprocessing_backup) do
            pcall(function()
                if v and v.Parent and v.Enabled ~= nil then
                    v.Enabled = enabled
                end
            end)
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
    local local_character = LocalPlayer and LocalPlayer.Character
    if local_character and obj:IsDescendantOf(local_character) then return true end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and obj:IsDescendantOf(player.Character) then
            return true
        end
    end
    return false
end

function System.fps_boost_set(state)
    fps_boost_enabled = state
    System.__properties.__fps_boost_enabled = state

    if fps_boost_loop then
        fps_boost_loop:Disconnect()
        fps_boost_loop = nil
    end

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

        if SoundService and sound_backup ~= nil then
            SoundService.Volume = sound_backup
            sound_backup = nil
        end

        return
    end

    apply_disable_fog(true)
    apply_disable_postprocessing(true)
    apply_remove_decals(true)

    lighting_backup = {
        Brightness = Lighting.Brightness,
        ExposureCompensation = Lighting.ExposureCompensation,
        GlobalShadows = Lighting.GlobalShadows,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        ClockTime = Lighting.ClockTime,
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
                    if not stored then
                        scene_backup[obj] = { CastShadow = obj.CastShadow, Material = obj.Material }
                    end
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
        if new then System.autoparry.start() else System.autoparry.stop() end
    end,
    [Enum.KeyCode.C] = function()
        local new = not System.__properties.__auto_spam_enabled
        System.__properties.__auto_spam_enabled = new
        if new then System.auto_spam.start() else System.auto_spam.stop() end
    end,
    [Enum.KeyCode.E] = function()
        local new = not System.manual_button.__active
        System.manual_button.set(new)
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
        if fn then pcall(fn) end
    end)
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
        Desc = "toggle with on-screen button too",
        Value = false,
        Callback = function(v)
            System.manual_button.set(v)
        end,
    })

    MainTab:Slider({
        Title = "Manual Spam Rate (CPS)",
        Desc = "clicks per second",
        Value = { Min = 1, Max = 200, Default = 100 },
        Callback = function(v)
            System.__properties.__spam_rate = v
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
        Desc = "parry loop while active (gist)",
        Value = true,
        Callback = function(v) System.__config.__detections.__slashesoffury = v end,
    })

    local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

    VisualTab:Toggle({
        Title = "No Render",
        Desc = "disable effects completely",
        Value = false,
        Callback = function(v)
            System.no_render_set(v)
        end,
    })

    VisualTab:Toggle({
        Title = "FPS Boost",
        Desc = "hide shadows & particles + boost",
        Value = false,
        Callback = function(v)
            System.fps_boost_set(v)
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
System.manual_spam.stop()
update_divisor()
