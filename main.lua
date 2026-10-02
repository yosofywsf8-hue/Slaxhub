-- Blade Ball — Azure UI + Auto Parry + Auto Spam (Smart) + Manual Spam + Detections + Visual
-- Runtime: Roblox mobile / PC
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
        __accuracy            = 1,
        __divisor_multiplier  = 1.1,
        __parried             = false,
        __training_parried    = false,
        __parries             = 0,
        __spam_threshold      = 1.5,
        __spam_accumulator    = 0,
        __spam_rate           = 1000,
        __auto_spam_range     = 12,
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
-- 7. AUTO SPAM — SMART
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
    local bv = ball.AssemblyLinearVelocity or Vector3.new()
    local dv = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    local ds = dv.Magnitude
    local bd = Vector3.new()
    local dot = 0
    if ds > 0 then
        bd = dv.Unit
        if bv.Magnitude > 0 then dot = bd:Dot(bv.Unit) end
    end
    return { Velocity = bv, Direction = bd, Distance = ds, Dot = dot }
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
    _G.In_Close_Contact = _G.In_Close_Contact or false
    local now = tick()
    if X <= 3 then _G.In_Close_Contact = true end
    if _G.In_Close_Contact and X > 3.3 then _G.In_Close_Contact = false; _G.Last_Close_Contact = now end
    local u = (not _G.In_Close_Contact) and (now - (_G.Last_Close_Contact or 0) >= 1.5)
    if u and (Fmove.Magnitude > 0.2 and Fmove:Dot(N) < -0.4) then E = 10 end
    if u and (lmove.Magnitude > 0.2 and lmove:Dot(-N) < -0.4) then E = 10 end
    local B = (self.Ping or 50) * 0.7 + math.min(n / (E * 1.2), 80)
    if (self.Entity_Properties and self.Entity_Properties.Distance or math.huge) > B then return D end
    if (self.Ball_Properties and self.Ball_Properties.Distance or math.huge) > B then return D end
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
            Ball_Properties = bp, Entity_Properties = ep, Ping = ping_thr,
        })
        local target_pos  = Closest_Entity.PrimaryPart.Position
        local target_dist = LocalPlayer:DistanceFromCharacter(target_pos)
        local ball_dist   = LocalPlayer:DistanceFromCharacter(ball.Position)
        local ball_target = ball:GetAttribute("target")
        if not ball_target then return end
        local pulsed = LocalPlayer.Character:GetAttribute("Pulsed")
        if pulsed then return end
        local is_targeted = (ball_target == LocalPlayer.Name)
        local near_enemy  = target_dist <= (System.__properties.__auto_spam_range or 12)
        if not (is_targeted or near_enemy) then return end
        if ball_dist > spam_acc then return end
        System.parry.execute()
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
    local interval
    if getgenv().ManualSpamCPSEnabled then
        interval = 1 / math.max(1, System.__properties.__spam_rate or 100)
    else
        interval = 1 / math.max(1, System.__properties.__spam_rate or 100)
    end
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
-- 8. AZURE UI
-- ============================================================
local Config = setmetatable({
    save = function(self, file_name, config)
        pcall(function()
            if not writefile then return end
            if isfolder and makefolder and not isfolder("Azure") then makefolder("Azure") end
            writefile("Azure/"..file_name..".json", HttpService:JSONEncode(config))
        end)
    end,
    load = function(self, file_name)
        local result
        pcall(function()
            if not isfile or not isfile("Azure/"..file_name..".json") then return end
            result = HttpService:JSONDecode(readfile("Azure/"..file_name..".json"))
        end)
        return result or { _flags = {}, _keybinds = {}, _library = {} }
    end,
}, {})

local Connections = setmetatable({
    disconnect = function(self, c)
        if not self[c] then return end
        self[c]:Disconnect()
        self[c] = nil
    end,
    disconnect_all = function(self)
        for _, v in self do
            if typeof(v) == 'function' then continue end
            pcall(function() v:Disconnect() end)
        end
    end,
}, {})

local Library = {
    _config = Config:load(game.GameId),
    _tab = 0,
    _ui = nil,
    _loaded = false,
}
Library.__index = Library

function Library:create_ui()
    local old = CoreGui:FindFirstChild("Azure")
    if old then old:Destroy() end

    local AzureUI = Instance.new("ScreenGui")
    AzureUI.ResetOnSpawn = false
    AzureUI.Name = "Azure"
    AzureUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AzureUI.IgnoreGuiInset = true
    AzureUI.DisplayOrder = 1000
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

    local CGC = Instance.new('UICorner'); CGC.CornerRadius = UDim.new(0, 12); CGC.Parent = Container
    local CGS = Instance.new('UIStroke')
    CGS.Color = Color3.fromRGB(78, 92, 122)
    CGS.Thickness = 1
    CGS.Transparency = 0.28
    CGS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    CGS.Parent = Container

    local SideBar = Instance.new("Frame")
    SideBar.Name = "GradientSide"
    SideBar.Size = UDim2.new(0, 10, 1, 0)
    SideBar.BackgroundTransparency = 1
    SideBar.Parent = Container
    local SideGradient = Instance.new("UIGradient")
    SideGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(30, 30, 34)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(55, 110, 190)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(110, 80, 200)),
    }
    SideGradient.Rotation = 90
    SideGradient.Parent = SideBar

    local Handler = Instance.new('Frame')
    Handler.BackgroundTransparency = 1
    Handler.Name = 'Handler'
    Handler.Size = UDim2.new(0, 750, 0, 530)
    Handler.BorderSizePixel = 0
    Handler.Parent = Container

    local Tabs = Instance.new('ScrollingFrame')
    Tabs.ScrollBarImageTransparency = 1
    Tabs.ScrollBarThickness = 0
    Tabs.Name = 'Tabs'
    Tabs.Size = UDim2.new(0, 140, 0, 445)
    Tabs.Selectable = false
    Tabs.AutomaticCanvasSize = Enum.AutomaticSize.XY
    Tabs.BackgroundTransparency = 1
    Tabs.Position = UDim2.new(0.026, 0, 0.111, 10)
    Tabs.BorderSizePixel = 0
    Tabs.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    Tabs.Parent = Handler

    local ULL = Instance.new('UIListLayout')
    ULL.Padding = UDim.new(0, 4)
    ULL.SortOrder = Enum.SortOrder.LayoutOrder
    ULL.Parent = Tabs

    local ClientName = Instance.new('TextLabel')
    ClientName.Font = Enum.Font.GothamBold
    ClientName.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClientName.Text = "Blade Ball"
    ClientName.Size = UDim2.new(0, 100, 0, 13)
    ClientName.AnchorPoint = Vector2.new(0, 0.5)
    ClientName.Position = UDim2.new(0.06, 0, 0.049, 1.5)
    ClientName.BackgroundTransparency = 1
    ClientName.TextXAlignment = Enum.TextXAlignment.Left
    ClientName.TextSize = 16
    ClientName.Parent = Handler

    local Divider = Instance.new('Frame')
    Divider.BackgroundTransparency = 0.5
    Divider.Position = UDim2.new(0.225, 0, 0, 68)
    Divider.Size = UDim2.new(0, 1, 0, 440)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Divider.Parent = Handler

    local Minimize = Instance.new('TextButton')
    Minimize.Text = ""
    Minimize.AutoButtonColor = false
    Minimize.BackgroundTransparency = 1
    Minimize.Position = UDim2.new(0.02, 0, 0.029, 0)
    Minimize.Size = UDim2.new(0, 24, 0, 24)
    Minimize.Parent = Handler
    local MinimizeLabel = Instance.new('TextLabel')
    MinimizeLabel.Size = UDim2.new(1, 0, 1, 0)
    MinimizeLabel.BackgroundTransparency = 1
    MinimizeLabel.Text = "—"
    MinimizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeLabel.TextSize = 20
    MinimizeLabel.Font = Enum.Font.GothamBold
    MinimizeLabel.Parent = Minimize

    local Sections = Instance.new('Folder')
    Sections.Name = 'Sections'
    Sections.Parent = Handler

    local UIScale = Instance.new('UIScale')
    UIScale.Parent = Container

    self._ui = AzureUI

    -- drag
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

    function self:load()
        local vp_x = workspace.CurrentCamera.ViewportSize.X
        if UserInputService.TouchEnabled then UIScale.Scale = vp_x / 1400 end
        TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
            Size = UDim2.fromOffset(750, 530)
        }):Play()
        self._loaded = true
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
                TweenService:Create(object, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
                TweenService:Create(object.TextLabel, TweenInfo.new(0.4), {
                    TextTransparency = 0.6, TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
            end
        end
    end

    function self:update_sections(left, right)
        for _, object in Sections:GetChildren() do
            object.Visible = (object == left or object == right)
        end
    end

    function self:create_tab(title)
        local TabManager = {}
        local first_tab = not Tabs:FindFirstChild("Tab")

        local Tab = Instance.new('TextButton')
        Tab.Font = Enum.Font.GothamBold
        Tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        Tab.Text = ""
        Tab.AutoButtonColor = false
        Tab.BackgroundTransparency = 1
        Tab.Name = 'Tab'
        Tab.Size = UDim2.new(0, 129, 0, 38)
        Tab.BorderSizePixel = 0
        Tab.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        Tab.Parent = Tabs
        Tab.LayoutOrder = self._tab
        local TC = Instance.new('UICorner'); TC.CornerRadius = UDim.new(0, 8); TC.Parent = Tab

        local TextLabel = Instance.new('TextLabel')
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
        local L1 = Instance.new("UIListLayout")
        L1.Padding = UDim.new(0, 18)
        L1.HorizontalAlignment = Enum.HorizontalAlignment.Center
        L1.SortOrder = Enum.SortOrder.LayoutOrder
        L1.Parent = LeftSection

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
        local L2 = Instance.new("UIListLayout")
        L2.Padding = UDim.new(0, 18)
        L2.HorizontalAlignment = Enum.HorizontalAlignment.Center
        L2.SortOrder = Enum.SortOrder.LayoutOrder
        L2.Parent = RightSection

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
            local ModuleManager = { _state = false, _size = 0, _multiplier = 0 }
            if settings.section == "right" then settings.section = RightSection
            else settings.section = LeftSection end

            local Module = Instance.new("Frame")
            Module.ClipsDescendants = true
            Module.BackgroundTransparency = 0.02
            Module.Position = UDim2.new(0.004, 0, 0, -5)
            Module.Name = "Module"
            Module.Size = UDim2.new(0, 241, 0, 93)
            Module.BorderSizePixel = 0
            Module.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
            Module.Parent = settings.section
            local UL = Instance.new("UIListLayout"); UL.SortOrder = Enum.SortOrder.LayoutOrder; UL.Parent = Module
            local UC = Instance.new("UICorner"); UC.CornerRadius = UDim.new(0, 8); UC.Parent = Module
            local US = Instance.new("UIStroke")
            US.Color = Color3.fromRGB(255, 255, 255)
            US.Transparency = 0.72
            US.Thickness = 1
            US.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            US.Parent = Module

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
            local UTC = Instance.new("UICorner"); UTC.CornerRadius = UDim.new(1, 0); UTC.Parent = Toggle

            local Circle = Instance.new("Frame")
            Circle.AnchorPoint = Vector2.new(0, 0.5)
            Circle.BackgroundTransparency = 0.2
            Circle.Position = UDim2.new(0, 0, 0.5, 0)
            Circle.Size = UDim2.new(0, 12, 0, 12)
            Circle.BorderSizePixel = 0
            Circle.BackgroundColor3 = Color3.fromRGB(120, 120, 132)
            Circle.Parent = Toggle
            local UCC = Instance.new("UICorner"); UCC.CornerRadius = UDim.new(1, 0); UCC.Parent = Circle

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
            local ULP = Instance.new('UIPadding'); ULP.PaddingTop = UDim.new(0, 8); ULP.Parent = Options
            local UL2 = Instance.new('UIListLayout')
            UL2.Padding = UDim.new(0, 5)
            UL2.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UL2.SortOrder = Enum.SortOrder.LayoutOrder
            UL2.Parent = Options

            function ModuleManager:change_state(state)
                self._state = state
                if self._state then
                    TweenService:Create(Module, TweenInfo.new(0.4), {
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
                    TweenService:Create(Module, TweenInfo.new(0.4), {
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
                if settings.callback then settings.callback(self._state) end
            end

            if Library._config._flags[settings.flag] then
                ModuleManager._state = true
                pcall(function() if settings.callback then settings.callback(true) end end)
                Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle.Position = UDim2.fromScale(0.53, 0.5)
            end

            Header.MouseButton1Click:Connect(function()
                ModuleManager:change_state(not ModuleManager._state)
            end)

            function ModuleManager:create_checkbox(s)
                if self._size == 0 then self._size = 11 end
                self._size += 20
                if ModuleManager._state then Module.Size = UDim2.fromOffset(241, 93 + self._size) end
                Options.Size = UDim2.fromOffset(241, self._size)

                local CM = { _state = false }
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
                local BC = Instance.new("UICorner"); BC.CornerRadius = UDim.new(0, 7); BC.Parent = Box

                local Fill = Instance.new("Frame")
                Fill.AnchorPoint = Vector2.new(0.5, 0.5)
                Fill.BackgroundTransparency = 0.2
                Fill.Position = UDim2.new(0.5, 0, 0.5, 0)
                Fill.Size = UDim2.fromOffset(0, 0)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
                Fill.Parent = Box
                local FC = Instance.new("UICorner"); FC.CornerRadius = UDim.new(0, 6); FC.Parent = Fill

                function CM:change_state(state)
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
                    if s.callback then s.callback(self._state) end
                end

                if Library._config._flags[s.flag] ~= nil then
                    CM:change_state(Library._config._flags[s.flag])
                end

                Checkbox.MouseButton1Click:Connect(function()
                    CM:change_state(not CM._state)
                end)

                return CM
            end

            function ModuleManager:create_slider(s)
                if self._size == 0 then self._size = 11 end
                self._size += 27
                if ModuleManager._state then Module.Size = UDim2.fromOffset(241, 93 + self._size) end
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
                local DC = Instance.new("UICorner"); DC.CornerRadius = UDim.new(1, 0); DC.Parent = Drag

                local Fill = Instance.new("Frame")
                Fill.AnchorPoint = Vector2.new(0, 0.5)
                Fill.BackgroundTransparency = 0.15
                Fill.Position = UDim2.new(0, 0, 0.5, 0)
                Fill.Size = UDim2.new(0, 103, 0, 4)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Fill.Parent = Drag
                local FCD = Instance.new("UICorner"); FCD.CornerRadius = UDim.new(0, 3); FCD.Parent = Fill

                local Circle2 = Instance.new("Frame")
                Circle2.AnchorPoint = Vector2.new(1, 0.5)
                Circle2.Position = UDim2.new(1, 0, 0.5, 0)
                Circle2.Size = UDim2.new(0, 6, 0, 6)
                Circle2.BorderSizePixel = 0
                Circle2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Circle2.Parent = Fill
                local CC2 = Instance.new("UICorner"); CC2.CornerRadius = UDim.new(1, 0); CC2.Parent = Circle2

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

                local SM = {}
                function SM:set_percentage(pct)
                    local rounded
                    if s.round_number then rounded = math.floor(pct) else rounded = math.floor(pct * 10) / 10 end
                    pct = (pct - s.minimum_value) / (s.maximum_value - s.minimum_value)
                    local slider_size = math.clamp(pct, 0.02, 1) * Drag.AbsoluteSize.X
                    local num = math.clamp(rounded, s.minimum_value, s.maximum_value)
                    Library._config._flags[s.flag] = num
                    Value.Text = num
                    TweenService:Create(Fill, TweenInfo.new(0.2), {
                        Size = UDim2.fromOffset(slider_size, Drag.AbsoluteSize.Y)
                    }):Play()
                    if s.callback then s.callback(num) end
                end
                function SM:update()
                    local mouse = UserInputService:GetMouseLocation()
                    local pct = s.minimum_value + (s.maximum_value - s.minimum_value) *
                                ((mouse.X - Drag.AbsolutePosition.X) / Drag.AbsoluteSize.X)
                    self:set_percentage(pct)
                end
                function SM:input()
                    SM:update()
                    Connections["slider_drag_"..s.flag] = UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch then SM:update() end
                    end)
                    Connections["slider_input_"..s.flag] = UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        Connections:disconnect("slider_drag_"..s.flag)
                        Connections:disconnect("slider_input_"..s.flag)
                        Config:save(game.GameId, Library._config)
                    end)
                end

                if Library._config._flags[s.flag] then SM:set_percentage(Library._config._flags[s.flag])
                else SM:set_percentage(s.value) end

                Slider.MouseButton1Down:Connect(function() SM:input() end)
                return SM
            end

            function ModuleManager:create_dropdown(s)
                local DM = { _state = false, _size = 0 }
                if self._size == 0 then self._size = 11 end
                self._size += 44
                if ModuleManager._state then Module.Size = UDim2.fromOffset(241, 93 + self._size) end
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
                local BC2 = Instance.new("UICorner"); BC2.CornerRadius = UDim.new(0, 4); BC2.Parent = Box

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
                local UL3 = Instance.new('UIListLayout'); UL3.SortOrder = Enum.SortOrder.LayoutOrder; UL3.Parent = OptionsFrame

                function DM:update(option)
                    CurrentOption.Text = (typeof(option) == "string" and option) or option.Name
                    Library._config._flags[s.flag] = option
                    Config:save(game.GameId, Library._config)
                    if s.callback then s.callback(option) end
                end

                if #s.options > 0 then
                    DM._size = 3
                    for index, value in ipairs(s.options) do
                        local Option = Instance.new("TextButton")
                        Option.Font = Enum.Font.GothamSemiBold
                        Option.TextTransparency = 0.6
                        Option.TextSize = 10
                        Option.Size = UDim2.new(0, 186, 0, 16)
                        Option.TextColor3 = Color3.fromRGB(255, 255, 255)
                        Option.Text = (typeof(value) == "string" and value) or value.Name
                        Option.AutoButtonColor = false
                        Option.Name = "Option"
                        Option.BackgroundTransparency = 1
                        Option.TextXAlignment = Enum.TextXAlignment.Left
                        Option.Parent = OptionsFrame
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

                if Library._config._flags[s.flag] then DM:update(Library._config._flags[s.flag])
                else DM:update(s.options[1]) end

                Dropdown.MouseButton1Click:Connect(function()
                    self._state = not self._state
                    if self._state then
                        ModuleManager._multiplier += self._size
                        TweenService:Create(Module, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Module.Options, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Dropdown, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(207, 39 + self._size)
                        }):Play()
                        TweenService:Create(Box, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(207, 22 + self._size)
                        }):Play()
                    else
                        ModuleManager._multiplier -= self._size
                        TweenService:Create(Module, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Module.Options, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        }):Play()
                        TweenService:Create(Dropdown, TweenInfo.new(0.4), {
                            Size = UDim2.fromOffset(207, 39)
                        }):Play()
                        TweenService:Create(Box, TweenInfo.new(0.4), {
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

    return self
end

local library = Library:create_ui()
library:load()

-- ============================================================
-- 9. TABS + MODULES
-- ============================================================
local MainTab   = library:create_tab("Main")
local SpamTab   = library:create_tab("Spam")
local DetTab    = library:create_tab("Detection")
local VisualTab = library:create_tab("Visual")

-- MAIN — Auto Parry
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
autoparry_module:change_state(true)

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

-- SPAM — Auto Spam (بلوكات ردز)
local auto_spam_module = SpamTab:create_module({
    title = "Auto Spam",
    description = "Automatically spam parries ball",
    flag = "AutoSpamModule",
    section = "right",
    callback = function(state)
        if System and System.auto_spam then
            System.__properties.__auto_spam_enabled = state
            if state then
                if System.auto_spam and System.auto_spam.start then pcall(System.auto_spam.start) end
            else
                if System.auto_spam and System.auto_spam.stop then pcall(System.auto_spam.stop) end
            end
        end
    end,
})
auto_spam_module:change_state(true)

auto_spam_module:create_dropdown({
    title = "Mode",
    flag = "AutoSpamMode",
    options = {"Remote", "Keypress"},
    maximum_options = 10,
    callback = function(Value)
        getgenv().AutoSpamMode = Value
    end,
})

auto_spam_module:create_checkbox({
    title = "Animation Fix",
    flag = "AutoSpamAnimationFix",
    callback = function(value)
        getgenv().AutoSpamAnimationFix = value
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
        if System then System.__properties.__spam_threshold = value end
    end,
})

auto_spam_module:create_slider({
    title = "Auto Spam Range",
    flag = "AutoSpamRange",
    maximum_value = 30,
    minimum_value = 5,
    value = 12,
    round_number = true,
    callback = function(value)
        System.__properties.__auto_spam_range = value
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
