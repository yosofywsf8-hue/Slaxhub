-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO PARRY ULTIMATE — Semua Fitur Digabung
-- Author: ALPHA XK
-- Sources: Ailon + Zythera + Ssin + Condemned + V12
-- All-in-One: hook, token, curve, target, detection, animation, multi-target
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._ap_ultimate then
    pcall(function() if _G.ap_ultimate_unload then _G.ap_ultimate_unload() end end)
    getgenv()._ap_ultimate = nil
    task.wait(0.1)
end
getgenv()._ap_ultimate = true

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local LP         = Players.LocalPlayer
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local CoreGui    = game:GetService("CoreGui")

-- ═══════════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════════
local S = {
    enabled          = false,
    autoSpam         = false,
    triggerbot       = false,
    manualSpam       = false,
    lobbyAP          = false,
    animFix          = true,
    cooldownProtect  = false,
    autoAbility      = false,
    randomAccuracy   = false,

    -- detection skip
    skipInfinity     = true,
    skipDeathSlash   = true,
    skipTimeHole     = true,
    skipSoF          = true,
    skipPhantom      = true,
    skipComboCount   = true,

    -- tuning
    accuracy         = 100,
    accuracyMin      = 30,
    accuracyMax      = 70,
    spamThreshold    = 2.5,
    spamRate         = 240,
    parryDelay       = 0.05,
    maxParryCount    = 36,
    curveMethod      = "camera",
    useAilonFormula  = true,
    useZytheraFormula= false,
    useSsinFormula   = false,
    usePerfStats     = false,
}

local CAP = {
    remotes          = {},       -- [remote] = captured args
    remoteCount      = 0,
    captureDone      = false,
    oldIndex         = nil,
    token            = nil,
    tokenFn          = nil,
    grabParryAnim    = nil,
    lastParryTime    = 0,
    lastParryAnim    = 0,
    parriedIDs       = {},
    ballLocks        = {},
    globalLock       = 0,

    infinity_active  = false,
    deathslash_active= false,
    timehole_active  = false,
    slashesoffury_active = false,
    slashesoffury_count = 0,
    phantom_lastDestroy = 0,
    tornado_time     = tick(),

    velHistory       = {},
    lastWarping      = tick(),
    lerpRadians      = 0,
    curving          = tick(),

    cachedBall       = nil,
    cachedHrp        = nil,
    lastCache        = 0,
    lastHrpCache     = 0,

    isMobile         = UIS.TouchEnabled and not UIS.KeyboardEnabled,
}

local curveKeys = {
    [Enum.KeyCode.One]    = "camera",
    [Enum.KeyCode.Two]    = "straight",
    [Enum.KeyCode.Three]  = "backwards",
    [Enum.KeyCode.Four]   = "slowball",
    [Enum.KeyCode.Five]   = "random",
    [Enum.KeyCode.Six]    = "high",
    [Enum.KeyCode.Seven]  = "left",
    [Enum.KeyCode.Eight]  = "right",
    [Enum.KeyCode.Nine]   = "dot",
    [Enum.KeyCode.Zero]   = "accelerated",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKEN SCAN
-- ═══════════════════════════════════════════════════════════════════════════
pcall(function()
    for _, f in getgc(true) do
        if type(f) == 'function' then
            local ok, src = pcall(function() return debug.info(f, 's') end)
            if ok and src and tostring(src):find('PRY', 1, true) then
                local ok2, ups = pcall(function() return debug.getupvalues(f) end)
                if ok2 and ups then
                    for _, v in pairs(ups) do
                        if type(v) == 'function' then
                            CAP.tokenFn = v
                            break
                        end
                    end
                end
                if CAP.tokenFn then break end
            end
        end
    end
end)

CAP.token = CAP.tokenFn

local function _tokenize(uid)
    if not CAP.tokenFn then return nil end
    local ok, res = pcall(function()
        local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
        local k = CAP.tokenFn(uid, 'TIME')
        local chars = table.create(#t)
        for i = 1, #t do
            chars[i] = string.char(bit32.bxor(
                (string.byte(t, i) + i) % 256,
                string.byte(k, (i - 1) % #k + 1)
            ))
        end
        return table.concat(chars)
    end)
    return ok and res or nil
end

print("[AP-ULT] token:", CAP.tokenFn and "OK" or "FAIL")

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK — FIXED VERSION (checkcaller + fast path + pcall IsA)
-- ═══════════════════════════════════════════════════════════════════════════
local function is_valid_args(args)
    return #args >= 6
        and type(args[2]) == "string"
        and type(args[3]) == "number"
end

if typeof(hookmetamethod) == "function" then
    CAP.oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        -- FAST PATH 1: capture done
        if CAP.captureDone then
            return CAP.oldIndex(self, key)
        end
        -- FAST PATH 2: not FireServer/InvokeServer
        if key ~= "FireServer" and key ~= "InvokeServer" then
            return CAP.oldIndex(self, key)
        end
        -- FAST PATH 3: our own call
        if checkcaller and checkcaller() then
            return CAP.oldIndex(self, key)
        end
        -- SLOW PATH: safe IsA
        local isRemote = false
        pcall(function()
            if key == "FireServer" then
                isRemote = self:IsA("RemoteEvent")
            else
                isRemote = self:IsA("RemoteFunction")
            end
        end)
        if not isRemote then
            return CAP.oldIndex(self, key)
        end
        return function(_, ...)
            local args = { ... }
            if not CAP.remotes[self] and is_valid_args(args) then
                CAP.remotes[self] = args
                CAP.remoteCount = CAP.remoteCount + 1
                print("[AP-ULT] captured:", self.Name or "?", "#args="..#args, "count="..CAP.remoteCount)
                if CAP.remoteCount >= 3 then
                    CAP.captureDone = true
                end
            end
            return CAP.oldIndex(self, key)(_, ...)
        end
    end))
    print("[AP-ULT] hook installed")
else
    warn("[AP-ULT] hookmetamethod not available — using VIM fallback only")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PING — dual source
-- ═══════════════════════════════════════════════════════════════════════════
local function Get_Ping_Stats()
    local ok, res = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and res or 60
end

local function Get_Ping_Perf()
    local ok, res = pcall(function()
        local rg = CoreGui:FindFirstChild("RobloxGui")
        if rg then
            local perf = rg:FindFirstChild("PerformanceStats")
            if perf then
                for _, d in perf:GetDescendants() do
                    if d:IsA("TextLabel") then
                        local ms = d.Text:match("(%d+)%s*ms")
                        if ms then return tonumber(ms) or 60 end
                    end
                end
            end
        end
        return 60
    end)
    return ok and res or 60
end

local function Get_Ping()
    if S.usePerfStats then
        return Get_Ping_Perf()
    end
    return Get_Ping_Stats()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BALL / TARGET HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
local function Get_Ball()
    local bc = WS:FindFirstChild("Balls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:GetAttribute("realBall") then return b end
        end
    end
    return nil
end

local function Get_Balls()
    local out = {}
    local bc = WS:FindFirstChild("Balls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:GetAttribute("realBall") then
                table.insert(out, b)
            end
        end
    end
    return out
end

local function Get_Training_Ball()
    local tb = WS:FindFirstChild("TrainingBalls")
    if tb then
        for _, b in pairs(tb:GetChildren()) do
            if b:GetAttribute("realBall") then return b end
        end
    end
    return nil
end

local function Closest_Player()
    local nearest, closest = math.huge, nil
    local alive = WS:FindFirstChild("Alive")
    if not alive then return nil end
    for _, c in pairs(alive:GetChildren()) do
        if c ~= LP.Character and c:FindFirstChild("HumanoidRootPart") then
            local d = (LP.Character.HumanoidRootPart.Position - c.HumanoidRootPart.Position).Magnitude
            if d < nearest then nearest, closest = d, c end
        end
    end
    return closest
end

local function is_my_target(ball)
    local t = ball:GetAttribute("target")
        or ball:GetAttribute("Target")
        or ball:GetAttribute("targetPlayer")
    if not t then
        -- fallback: velocity approach
        local z = ball:FindFirstChild("zoomies")
        local char = LP.Character
        if z and char and char.PrimaryPart then
            local vel = z.VectorVelocity
            local toPlayer = char.PrimaryPart.Position - ball.Position
            if vel.Magnitude > 3 and toPlayer.Magnitude > 0.1 then
                if vel.Unit:Dot(toPlayer.Unit) > 0.85 then return true end
            end
        end
        return false
    end
    if t == LP.Name then return true end
    if t == LP.UserId then return true end
    if tostring(t) == tostring(LP.UserId) then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CURVE DETECTION (multi-signal — Ailon + Zythera)
-- ═══════════════════════════════════════════════════════════════════════════
local function is_curved(ball)
    if not ball then return false end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local char = LP.Character
    if not char or not char.PrimaryPart then return false end

    local vel = z.VectorVelocity
    local speed = vel.Magnitude
    if speed < 1 then return false end

    local delta = char.PrimaryPart.Position - ball.Position
    local distance = delta.Magnitude
    if distance < 0.001 then return false end

    local toMe = delta / distance
    local velUnit = vel.Unit
    local ping = Get_Ping() / 1000
    local targeted = ball:GetAttribute("target") == LP.Name

    -- Signal 1: current dot
    local dot = toMe:Dot(velUnit)

    -- Signal 2: predictive dot
    local lookahead = math.clamp(ping * 2 + (distance / speed) * 0.1, ping * 2, 0.5)
    local futurePos = ball.Position + vel * lookahead
    local futureDelta = char.PrimaryPart.Position - futurePos
    local futureDist = futureDelta.Magnitude
    local futureDot = futureDist > 0.001 and (futureDelta / futureDist):Dot(velUnit) or dot

    -- Signal 3: lateral cross
    local cross = toMe:Cross(velUnit).Magnitude

    -- Signal 4: predictive miss
    local timeToImpact = math.max(distance / speed - ping, 1/60)
    local predictedPos = ball.Position + vel * timeToImpact
    local missAmount = (char.PrimaryPart.Position - predictedPos).Magnitude
    local hitbox = math.clamp(4 + ping * speed * 0.08 + distance * 0.04, 4, 22)
    local willMiss = missAmount > hitbox

    -- Backwards curve
    if targeted and distance < 200 then
        if dot < 0.05 and futureDot < 0.15 then return true end
        local bcDot = math.clamp(0.55 - (distance / 200) * 0.25, 0.30, 0.55)
        if willMiss and dot < bcDot and speed > 15 then return true end
    end

    -- Warp guard
    local angleRad = math.acos(math.clamp(dot, -1, 1))
    CAP.lerpRadians = CAP.lerpRadians + (angleRad - CAP.lerpRadians) * 0.55
    if CAP.lerpRadians < 0.022 then
        CAP.lastWarping = tick()
    end

    local now = tick()
    local tiWindow = math.min(timeToImpact / 1.15, 0.6)
    if (now - CAP.lastWarping) < tiWindow and (now - CAP.curving) < tiWindow then
        return true
    end

    -- Final gate: cross + dot
    local threshold = math.clamp(0.40 + ping * 0.3, 0.40, 0.60)
    local crossNeeded = 0.08 + (distance / 500) * 0.05
    if cross > crossNeeded and dot < threshold then return true end
    if targeted and cross > crossNeeded * 2 then return true end

    -- Velocity history (Zythera)
    table.insert(CAP.velHistory, vel)
    if #CAP.velHistory > 4 then table.remove(CAP.velHistory, 1) end
    if #CAP.velHistory == 4 then
        for i = 1, 2 do
            local d = (velUnit - CAP.velHistory[i].Unit).Unit
            local proj = toMe:Dot(d)
            if dot - proj < -ping then return true end
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD PARRY PAYLOAD (curve CFrame + events + aim)
-- ═══════════════════════════════════════════════════════════════════════════
local cachedAim = {0, 0}
local cachedEvents = {}

RunService.RenderStepped:Connect(function()
    local cam = WS.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if CAP.isMobile then
        cachedAim = {vp.X / 2, vp.Y / 2}
    else
        local ok, m = pcall(function() return UIS:GetMouseLocation() end)
        cachedAim = ok and m and {m.X, m.Y} or {vp.X / 2, vp.Y / 2}
    end
    local alive = WS:FindFirstChild("Alive")
    if alive then
        local data = {}
        for _, e in pairs(alive:GetChildren()) do
            if e ~= LP.Character and e.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok and sp then data[tostring(e)] = sp end
            end
        end
        cachedEvents = data
    end
end)

local function build_curve_cframe()
    local cam = WS.CurrentCamera
    if not cam then return CFrame.new() end
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return cam.CFrame end

    local m = S.curveMethod
    if m == "camera" then
        return cam.CFrame
    elseif m == "straight" or m == "dot" then
        local target = Closest_Player()
        if target and target.PrimaryPart then
            return CFrame.lookAt(root.Position, target.PrimaryPart.Position + Vector3.new(0, 1.75, 0))
        end
        return cam.CFrame
    elseif m == "backwards" then
        return CFrame.new(root.Position, root.Position - cam.CFrame.LookVector * 10000)
    elseif m == "high" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, 1e9, 0))
    elseif m == "slowball" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, -350, 0))
    elseif m == "random" then
        return CFrame.new(root.Position, Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000)))
    elseif m == "left" then
        return CFrame.new(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.RightVector * 1e9)
    elseif m == "right" then
        return CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.RightVector * 1e9)
    elseif m == "accelerated" then
        return CFrame.new(root.Position, (Closest_Player() and Closest_Player().PrimaryPart and Closest_Player().PrimaryPart.Position or root.Position) + Vector3.new(0, 5, 0))
    end
    return cam.CFrame
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FIRE PARRY — multi-remote, token regen with fallback 0
-- ═══════════════════════════════════════════════════════════════════════════
local function Fire_Parry()
    if tick() - CAP.lastParryTime < 0.03 then return false end
    CAP.lastParryTime = tick()

    if not next(CAP.remotes) then
        -- fallback: kirim F key
        local vim = game:GetService("VirtualInputManager")
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
            vim:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
        end)
        return false
    end

    local fired = false
    local curveCF = build_curve_cframe()

    for remote, origArgs in pairs(CAP.remotes) do
        local uid = origArgs[2]
        local tok = _tokenize(uid) or origArgs[3] or 0

        local pkt = {
            origArgs[1],
            uid,
            tok,
            curveCF,
            cachedEvents,
            cachedAim,
            origArgs[7] or false,
        }

        local ok = pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(pkt))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(pkt))
            end
        end)
        if ok then fired = true end
    end

    -- play animation
    if S.animFix then
        task.spawn(function()
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return end
            local shared = RS:FindFirstChild("Shared")
            local swordAPI = shared and shared:FindFirstChild("SwordAPI")
            local collection = swordAPI and swordAPI:FindFirstChild("Collection")
            local default = collection and collection:FindFirstChild("Default")
            local anim = default and default:FindFirstChild("GrabParry")
            if not anim then return end
            for _, t in pairs(animator:GetPlayingAnimationTracks()) do
                if t.Name == "GrabParry" or t.Name == "Grab" then
                    pcall(function() t:Stop(0.1) end)
                end
            end
            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
            if ok and track then
                pcall(function() track:Play(0, 1, 1) end)
                CAP.grabParryAnim = track
            end
        end)
    end

    return fired
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PARRY ACCURACY — 3 formula, pilih satu
-- ═══════════════════════════════════════════════════════════════════════════
local function compute_accuracy(speed)
    local ping = Get_Ping()
    local ping_sec = ping / 1000

    if S.useAilonFormula then
        local ping_thresh = math.clamp(ping / 10, 5, 17)
        local capped = math.max(speed - 9.5, 0)
        local divisor = 2.4 + capped * 0.002
        local acc = ping_thresh + math.max(speed / divisor, 9.5)
        return acc
    end

    if S.useZytheraFormula then
        local ping_thr = math.clamp(ping / 100, 1, 16)
        local base = ping_thr + math.min(speed / 6, 255)
        return base
    end

    if S.useSsinFormula then
        local acc = speed * (ping_sec + 0.016) * 8 * 0.43
        return acc
    end

    -- default: Ailon
    local ping_thresh = math.clamp(ping / 10, 5, 17)
    local capped = math.max(speed - 9.5, 0)
    local divisor = 2.4 + capped * 0.002
    return ping_thresh + math.max(speed / divisor, 9.5)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DETECTION EVENT LISTENERS
-- ═══════════════════════════════════════════════════════════════════════════
pcall(function()
    RS.Remotes.SecondaryEndCD.OnClientEvent:Connect(function() end)
end)
pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, active)
        CAP.deathslash_active = active or false
    end)
end)
pcall(function()
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, active)
        CAP.infinity_active = active or false
    end)
end)
pcall(function()
    local pkg = RS:FindFirstChild("Packages")
    local idx = pkg and pkg:FindFirstChild("_Index")
    local netMod = idx and idx:FindFirstChild("sleitnick_net@0.1.0")
    local net = netMod and netMod:FindFirstChild("net")
    if net then
        local netReq = require(net)
        netReq["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
            local p = ...
            if p == LP or (p and p.Name == LP.Name) then
                CAP.timehole_active = true
            end
        end)
        netReq["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
            CAP.timehole_active = false
        end)
        netReq["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
            local p = ...
            if p == LP or (p and p.Name == LP.Name) then
                CAP.slashesoffury_active = true
                CAP.slashesoffury_count = 0
            end
        end)
        netReq["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
            CAP.slashesoffury_active = false
            CAP.slashesoffury_count = 0
        end)
        netReq["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
            CAP.slashesoffury_count = CAP.slashesoffury_count + 1
        end)
        netReq["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
            task.spawn(function()
                while CAP.slashesoffury_active and CAP.slashesoffury_count < S.maxParryCount do
                    if S.skipSoF == false or true then
                        Fire_Parry()
                        task.wait(S.parryDelay)
                    else
                        break
                    end
                end
            end)
        end)
    end
end)

-- Anti-Phantom
pcall(function()
    local runtime = WS:FindFirstChild("Runtime")
    if not runtime then return end
    runtime.ChildAdded:Connect(function(obj)
        if not S.skipPhantom then return end
        if obj.Name ~= "maxTransmission" and obj.Name ~= "transmissionpart" then return end
        local weld = obj:FindFirstChildWhichIsA("WeldConstraint")
        if not weld then return end
        local char = LP.Character or LP.CharacterAdded:Wait()
        if char and weld.Part1 == char.HumanoidRootPart then
            weld:Destroy()
            local ball = Get_Ball()
            if ball then
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    local h = ball:GetAttribute("highlighted")
                    if h == true then
                        RS.Remotes.AbilityButtonPress:Fire()
                    elseif h == false then
                        conn:Disconnect()
                    end
                end)
                task.delay(3, function() if conn and conn.Connected then conn:Disconnect() end end)
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════════════
RunService.PreSimulation:Connect(function()
    local now = tick()

    if now - CAP.lastHrpCache > 0.15 then
        local ch = LP.Character
        CAP.cachedHrp = ch and ch:FindFirstChild("HumanoidRootPart")
        CAP.lastHrpCache = now
    end
    if not CAP.cachedHrp then return end

    if now - CAP.lastCache > 0.06 then
        CAP.cachedBall = Get_Ball()
        CAP.lastCache = now
    end
    local ball = CAP.cachedBall
    if not ball then return end

    local z = ball:FindFirstChild("zoomies")
    if not z then return end
    local speed = z.VectorVelocity.Magnitude
    local dist = (CAP.cachedHrp.Position - ball.Position).Magnitude

    if CAP.cachedHrp:FindFirstChild("SingularityCape") then return end
    if S.skipComboCount and ball:FindFirstChild("ComboCounter") then return end
    if S.skipInfinity and CAP.infinity_active then return end
    if S.skipDeathSlash and CAP.deathslash_active then return end
    if S.skipTimeHole and CAP.timehole_active then return end

    -- Tornado check
    local runtime = WS:FindFirstChild("Runtime")
    if runtime and runtime:FindFirstChild("Tornado") then
        local ttime = runtime.Tornado:GetAttribute("TornadoTime") or 1
        if now - CAP.tornado_time < ttime + 0.314 then return end
    end

    -- AUTO PARRY
    if S.enabled and next(CAP.remotes) then
        local accuracy = compute_accuracy(speed)

        if S.randomAccuracy then
            local acc = math.random(S.accuracyMin, S.accuracyMax)
            accuracy = accuracy * (0.7 + (acc - 1) * 0.0035)
        end

        if is_my_target(ball) then
            local curved = is_curved(ball)
            if curved then
                -- skip curve (bait)
            else
                if dist <= accuracy then
                    local bID = ball:GetDebugId()
                    if not CAP.parriedIDs[bID] then
                        -- Cooldown protection
                        if S.cooldownProtect then
                            local pg = LP:FindFirstChild("PlayerGui")
                            local hotbar = pg and pg:FindFirstChild("Hotbar")
                            local block = hotbar and hotbar:FindFirstChild("Block")
                            local grad = block and block:FindFirstChild("UIGradient")
                            if grad and grad.Offset.Y < 0.4 then
                                RS.Remotes.AbilityButtonPress:Fire()
                            else
                                Fire_Parry()
                                CAP.parriedIDs[bID] = true
                            end
                        else
                            Fire_Parry()
                            CAP.parriedIDs[bID] = true
                        end
                        task.spawn(function()
                            ball:GetAttributeChangedSignal("target"):Wait()
                            CAP.parriedIDs[bID] = nil
                        end)
                        task.delay(3, function() CAP.parriedIDs[bID] = nil end)
                    end
                end
            end
        end
    end

    -- TRIGGERBOT
    if S.triggerbot and is_my_target(ball) then
        local bID = ball:GetDebugId()
        if not CAP.parriedIDs[bID] then
            Fire_Parry()
            CAP.parriedIDs[bID] = true
            task.delay(0.4, function() CAP.parriedIDs[bID] = nil end)
        end
    end

    -- AUTO SPAM
    if S.autoSpam then
        local closest = Closest_Player()
        if closest and closest.PrimaryPart then
            local ping = Get_Ping() / 100
            local threshold = math.clamp(ping, 1, 16) + math.min(speed / 6, 255)
            local dist_ent = LP:DistanceFromCharacter(closest.PrimaryPart.Position)
            if (dist <= threshold or dist_ent <= threshold) and is_my_target(ball) then
                if not CAP.cachedHrp.Parent:GetAttribute("Pulsed") then
                    local bID = ball:GetDebugId()
                    if not CAP.parriedIDs[bID] then
                        Fire_Parry()
                        CAP.parriedIDs[bID] = true
                        task.delay(0.1, function() CAP.parriedIDs[bID] = nil end)
                    end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MANUAL SPAM
-- ═══════════════════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not S.manualSpam then return end
    local now = tick()
    local interval = 1 / math.max(S.spamRate, 1)
    if now - CAP.globalLock < interval then return end
    CAP.globalLock = now
    Fire_Parry()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- LOBBY AUTO PARRY
-- ═══════════════════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not S.lobbyAP then return end
    local tb = Get_Training_Ball()
    if not tb then return end
    local z = tb:FindFirstChild("zoomies")
    if not z then return end
    if tb:GetAttribute("target") ~= LP.Name then return end
    local speed = z.VectorVelocity.Magnitude
    local dist = LP:DistanceFromCharacter(tb.Position)
    local ping = Get_Ping() / 1000
    local timeToReach = speed > 0 and (dist / speed - ping) or math.huge
    if timeToReach <= 0.15 and timeToReach >= 0 then
        Fire_Parry()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeys[input.KeyCode] then
        S.curveMethod = curveKeys[input.KeyCode]
        print("[AP-ULT] Curve:", S.curveMethod)
    end
    if input.KeyCode == Enum.KeyCode.E then
        S.enabled = not S.enabled
        print("[AP-ULT] AutoParry:", S.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.Q then
        S.manualSpam = not S.manualSpam
        print("[AP-ULT] ManualSpam:", S.manualSpam and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.End then
        S.enabled = false; S.autoSpam = false; S.triggerbot = false; S.manualSpam = false
        print("[AP-ULT] PANIC")
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — WindUI v2
-- ═══════════════════════════════════════════════════════════════════════════
local ok_w, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok_w or not WindUI then
    warn("[AP-ULT] WindUI load fail — headless mode")
    return
end

local Window = WindUI:CreateWindow({
    Title = "Auto Parry ULTIMATE",
    Icon = "solar:crown-bold",
    Author = "ALPHA XK",
    Folder = "APUltimate",
    Size = UDim2.fromOffset(560, 500),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
})

local TabMain  = Window:Tab({ Title = "Auto Parry", Icon = "solar:sword-bold" })
local TabMode  = Window:Tab({ Title = "Modes", Icon = "solar:play-bold" })
local TabDet   = Window:Tab({ Title = "Detection", Icon = "solar:shield-bold" })
local TabTune  = Window:Tab({ Title = "Tuning", Icon = "solar:tuning-bold" })
local TabCurve = Window:Tab({ Title = "Curve", Icon = "solar:activity-bold" })
local TabInfo  = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

-- ═══ AUTO PARRY ═══
local SecMain = TabMain:Section({ Title = "Auto Parry — Master" })

SecMain:Toggle({
    Title = "Auto Parry",
    Desc = "Master switch — predictive + multi-signal curve detect",
    Value = false,
    Callback = function(v)
        S.enabled = v
        WindUI:Notify({ Title = "Auto Parry", Content = v and "ON" or "OFF", Duration = 2 })
    end,
})

SecMain:Toggle({
    Title = "Animation Fix",
    Desc = "Play GrabParry anim (stealth)",
    Value = true,
    Callback = function(v) S.animFix = v end,
})

SecMain:Toggle({
    Title = "Cooldown Protection",
    Desc = "Fire ability kalau parry cooldown aktif",
    Value = false,
    Callback = function(v) S.cooldownProtect = v end,
})

SecMain:Toggle({
    Title = "Auto Ability",
    Desc = "Fire ability saat clash",
    Value = false,
    Callback = function(v) S.autoAbility = v end,
})

SecMain:Toggle({
    Title = "Random Accuracy (Humanizer)",
    Desc = "Random accuracy per ball — susah di-detect",
    Value = false,
    Callback = function(v) S.randomAccuracy = v end,
})

-- ═══ MODES ═══
local SecMode = TabMode:Section({ Title = "Parry Modes" })

SecMode:Toggle({
    Title = "Auto Spam",
    Desc = "Spam parry di dekat player",
    Value = false,
    Callback = function(v) S.autoSpam = v end,
})

SecMode:Toggle({
    Title = "Trigger Bot",
    Desc = "Instant parry saat target = lo",
    Value = false,
    Callback = function(v) S.triggerbot = v end,
})

SecMode:Toggle({
    Title = "Manual Spam",
    Desc = "Spam parry terus-terusan (toggle Q)",
    Value = false,
    Callback = function(v) S.manualSpam = v end,
})

SecMode:Slider({
    Title = "Manual Spam Rate",
    Desc = "CPS (60-5000)",
    Value = { Min = 60, Max = 5000, Default = 240, Rounding = 0 },
    Callback = function(v) S.spamRate = v end,
})

SecMode:Toggle({
    Title = "Lobby Auto Parry",
    Desc = "Auto parry di training ball (lobby)",
    Value = false,
    Callback = function(v) S.lobbyAP = v end,
})

-- ═══ DETECTION SKIP ═══
local SecDet = TabDet:Section({ Title = "Skip Parry Saat Ability Ini Aktif" })

SecDet:Toggle({ Title = "Infinity Ball", Value = true, Callback = function(v) S.skipInfinity = v end })
SecDet:Toggle({ Title = "Death Slash",   Value = true, Callback = function(v) S.skipDeathSlash = v end })
SecDet:Toggle({ Title = "Time Hole",     Value = true, Callback = function(v) S.skipTimeHole = v end })
SecDet:Toggle({ Title = "Slashes of Fury", Value = true, Callback = function(v) S.skipSoF = v end })
SecDet:Toggle({ Title = "Anti-Phantom",  Value = true, Callback = function(v) S.skipPhantom = v end })
SecDet:Toggle({ Title = "ComboCounter skip", Value = true, Callback = function(v) S.skipComboCount = v end })

-- ═══ TUNING ═══
local SecTune = TabTune:Section({ Title = "Formula Presets" })

SecTune:Toggle({
    Title = "Ailon Formula (default)",
    Desc = "ping_thresh + max(speed/divisor, 9.5)",
    Value = true,
    Callback = function(v)
        if v then
            S.useAilonFormula = true
            S.useZytheraFormula = false
            S.useSsinFormula = false
        end
    end,
})

SecTune:Toggle({
    Title = "Zythera Formula",
    Desc = "ping * 0.7 + min(speed/(E*1.2), 80)",
    Value = false,
    Callback = function(v)
        if v then
            S.useAilonFormula = false
            S.useZytheraFormula = true
            S.useSsinFormula = false
        end
    end,
})

SecTune:Toggle({
    Title = "Ssin Formula",
    Desc = "speed * (ping + 0.016) * 3.44",
    Value = false,
    Callback = function(v)
        if v then
            S.useAilonFormula = false
            S.useZytheraFormula = false
            S.useSsinFormula = true
        end
    end,
})

SecTune:Toggle({
    Title = "Use PerformanceStats Ping",
    Desc = "Ping dari RobloxGui.PerformanceStats (Zythera style)",
    Value = false,
    Callback = function(v) S.usePerfStats = v end,
})

local SecTune2 = TabTune:Section({ Title = "Tuning Values" })

SecTune2:Slider({
    Title = "Accuracy (base)",
    Desc = "1-100",
    Value = { Min = 1, Max = 100, Default = 100, Rounding = 0 },
    Callback = function(v) S.accuracy = v end,
})

SecTune2:Slider({
    Title = "Random Accuracy Min",
    Desc = "Batas bawah random (kalau humanizer on)",
    Value = { Min = 1, Max = 100, Default = 30, Rounding = 0 },
    Callback = function(v) S.accuracyMin = v end,
})

SecTune2:Slider({
    Title = "Random Accuracy Max",
    Desc = "Batas atas random",
    Value = { Min = 1, Max = 100, Default = 70, Rounding = 0 },
    Callback = function(v) S.accuracyMax = v end,
})

-- ═══ CURVE ═══
local SecCurve = TabCurve:Section({ Title = "Curve Method" })

SecCurve:Dropdown({
    Title = "Curve",
    Values = {"camera","straight","dot","backwards","slowball","random","high","left","right","accelerated"},
    Value = "camera",
    Callback = function(v) S.curveMethod = v end,
})

SecCurve:Paragraph({
    Title = "Hotkeys",
    Desc = "1=camera 2=straight 3=backwards 4=slowball 5=random\n6=high 7=left 8=right 9=dot 0=accelerated",
})

-- ═══ INFO ═══
local SecInfo = TabInfo:Section({ Title = "Runtime" })
local infoPara = SecInfo:Paragraph({ Title = "Status", Desc = "init..." })

task.spawn(function()
    while getgenv()._ap_ultimate do
        pcall(function()
            local mode = "normal"
            if CAP.infinity_active then mode = "INF" end
            if CAP.deathslash_active then mode = "DS" end
            if CAP.timehole_active then mode = "TH" end
            infoPara:Set(string.format(
                "Hook: %s | Capture: %s\nRemote count: %d\nToken: %s\nParry count: %d\nPing: %d ms | Active: %s",
                CAP.oldIndex and "OK" or "FAIL",
                CAP.captureDone and "DONE" or "waiting",
                CAP.remoteCount,
                CAP.tokenFn and "OK" or "FAIL",
                (function() local n=0 for _ in pairs(CAP.parriedIDs) do n=n+1 end return n end)(),
                Get_Ping(),
                mode
            ))
        end)
        task.wait(1)
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Auto Parry ULTIMATE",
    Content = "Parry manual sekali untuk capture remote",
    Duration = 6,
})

print("[AP-ULT] loaded")
print("[AP-ULT] E=AutoParry | Q=ManualSpam | END=Panic | 1-0=Curve")

_G.ap_ultimate_unload = function()
    getgenv()._ap_ultimate = nil
    pcall(function() Window:Destroy() end)
end
