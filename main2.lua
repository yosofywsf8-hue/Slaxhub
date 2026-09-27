-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V9.2 MOBILE — Clean UI (Only Accuracy + Auto Parry Toggle)
-- Author: ALPHA XK | For: Redz
-- All tuning locked inside Config — UI cuma toggle + accuracy
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._slax_mobile_loaded then
    pcall(function() if _G.slax_mobile_unload then _G.slax_mobile_unload() end end)
    getgenv()._slax_mobile_loaded = nil
    task.wait(0.15)
end
getgenv()._slax_mobile_loaded = true

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local WS            = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local Stats         = game:GetService("Stats")
local LP            = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG — semua tuning di sini (nggak ada di UI)
-- ═══════════════════════════════════════════════════════════════════════════
local Config = {
    enabled         = true,
    accuracy        = 100,

    -- NORMAL MODE
    maxPerFrame     = 10,
    lockDuration    = 1.3,      -- anti-double lock (request Redz)
    maxDist         = 300,
    pingCompFactor  = 0.90,
    curveOnCurved   = 0.85,
    predictAhead    = 0.07,
    angleMax        = 140,

    -- CLOSE COMBAT MODE (auto aktif kalau musuh deket)
    closeRangeDist  = 60,
    closePerFrame   = 20,
    closeLock       = 0.12,
    closeWindowMult = 1.8,
    closeAngleMax   = 180,
    closeBurst      = 2,

    -- DANGER MODE (auto)
    dangerHpThresh  = 60,
    dangerBallNear  = 2,
    dangerRadius    = 60,
    emergencyRadius = 18,
    reflexWindow    = 0.5,
    reflexCount     = 3,

    -- internal
    closeCombat     = true,     -- selalu aktif
    survivalMode    = true,     -- selalu aktif

    -- UI
    curveMethod     = "camera",
    autoSpam        = false,
    autoSpamCPS     = 200,
    invisEnabled    = false,
    toggleKey       = "E",
    panicKey        = "END",
}

local State = {
    running         = true,
    parried         = setmetatable({}, { __mode = "k" }),
    ballLastFire    = setmetatable({}, { __mode = "k" }),
    parryCount      = 0,
    parrySuccess    = 0,
    lastParry       = 0,
    lastSpam        = 0,
    ping            = 0.06,
    pingSmooth      = 60,
    currentCurve    = "camera",
    recentFires     = {},
    dangerMode      = false,
    closeMode       = false,
    nearestEnemy    = math.huge,
    hp              = 100,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKEN
-- ═══════════════════════════════════════════════════════════════════════════
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' then
        local ok, src = pcall(function() return debug.info(f, 's') end)
        if ok and src and tostring(src):find('PRY', 1, true) then
            local ok2, ups = pcall(function() return debug.getupvalues(f) end)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if type(v) == 'function' then _token = v; break end
                end
            end
            if _token then break end
        end
    end
end

local function _tokenize(uid)
    if not _token then return nil end
    local ok, res = pcall(function()
        local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
        local k = _token(uid, 'TIME')
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

print('[V9.2M] Token:', _token and 'OK' or 'FAIL')

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK
-- ═══════════════════════════════════════════════════════════════════════════
local Captured = { remote = nil, method = nil, args = nil, done = false }

local function _attach_hook(self, mt)
    pcall(setreadonly, mt, false)
    local old = mt.__index
    mt.__index = function(inst, key)
        if key == 'FireServer' or key == 'InvokeServer' then
            return function(_, ...)
                local args = { ... }
                if not Captured.remote and #args >= 6
                and type(args[2]) == 'string'
                and type(args[3]) == 'string'
                and typeof(args[5]) == 'CFrame' then
                    Captured.remote = inst
                    Captured.method = key
                    Captured.args = args
                    Captured.done = true
                    print('[V9.2M] Captured:', inst.Name, '#args=' .. #args)
                end
                return old(inst, key)(_, ...)
            end
        end
        return old(inst, key)
    end
    pcall(setreadonly, mt, true)
end

local _hookedMT = {}
for _, r in ipairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        local ok, mt = pcall(getrawmetatable, r)
        if ok and mt and not _hookedMT[mt] then
            _hookedMT[mt] = true
            _attach_hook(r, mt)
        end
    end
end

print('[V9.2M] Remotes hooked')

-- == Character ============================================================
local function isAlive()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if hrp:FindFirstChild("SingularityCape") then return false end
    State.hp = hum.Health
    return true, char, hrp, hum
end

-- == Ping =================================================================
task.spawn(function()
    while State.running do
        pcall(function()
            local raw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            State.ping = raw / 1000
            State.pingSmooth = State.pingSmooth * 0.6 + raw * 0.4
        end)
        task.wait(1)
    end
end)

-- == Nearest Enemy ========================================================
local function getNearestEnemyDist(myPos)
    local nearest = math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local ehrp = p.Character:FindFirstChild("HumanoidRootPart")
            if ehrp then
                local d = (ehrp.Position - myPos).Magnitude
                if d < nearest then nearest = d end
            end
        end
    end
    return nearest
end

-- == Curve ================================================================
local function getCurveCFrame(myPos)
    local cam = WS.CurrentCamera
    if not cam then return CFrame.new(myPos) end
    local targetPos = myPos + cam.CFrame.LookVector * 1000
    local aliveFolder = WS:FindFirstChild("Alive")
    if aliveFolder then
        local bestDot, bestPos = -math.huge, nil
        for _, e in ipairs(aliveFolder:GetChildren()) do
            local hrp = e:FindFirstChild("HumanoidRootPart")
            if hrp and e ~= LP.Character then
                local dir = (hrp.Position - cam.CFrame.Position).Unit
                local dot = cam.CFrame.LookVector:Dot(dir)
                if dot > bestDot then bestDot, bestPos = dot, hrp.Position end
            end
        end
        if bestPos then targetPos = bestPos end
    end

    local m = State.currentCurve
    if m == "dot" then
        return CFrame.lookAt(myPos, targetPos + Vector3.new(0, 1.75, 0))
    elseif m == "backwards" then
        return CFrame.new(myPos, myPos + (myPos - targetPos).Unit * 1000)
    elseif m == "high" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 9e18, 0))
    elseif m == "slow" then
        return CFrame.new(myPos, myPos + Vector3.new(0, -350, 0))
    elseif m == "random" then
        local rnd = Vector3.new(math.random(-3000,3000), math.random(-3000,3000), math.random(-3000,3000))
        return CFrame.new(myPos, targetPos + rnd)
    elseif m == "accelerated" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 5, 0))
    else
        return cam.CFrame
    end
end

local function isCurved(ball, myPos)
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local vel = z.VectorVelocity
    local spd = vel.Magnitude
    if spd < 5 then return false end
    local dir = (myPos - ball.Position).Unit
    local dot = dir:Dot(vel.Unit)
    if dot < -0.1 then return true end
    local lat = (vel - (vel:Dot(dir) * dir)).Magnitude
    if lat / spd > 0.35 then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FIRE WINDOW
-- ═══════════════════════════════════════════════════════════════════════════
local function computeWindow(speed, isDanger, isClose)
    local ping = State.pingSmooth or State.ping * 1000
    local pingThr = math.clamp((ping / 80) * Config.pingCompFactor * 1.4, 5, 32)
    local mult = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035353535353535
    local divisor = (2.2 + 0.9 * math.log(1 + speed / 80)) * mult
    local sf = 1
    if speed > 200 then sf = 1 + math.min((speed - 200) / 800, 0.5) end
    if speed > 350 then sf = sf * 1.3 end
    local w = pingThr + math.max(speed / divisor, 9.5) * sf
    if isDanger then w = w * 1.5 end
    if isClose then w = w * Config.closeWindowMult end
    return w
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FIRE
-- ═══════════════════════════════════════════════════════════════════════════
local cachedAim = {0, 0}
local cachedEvents = {}
local _camUpdateAcc = 0

RunService.RenderStepped:Connect(function(dt)
    _camUpdateAcc = _camUpdateAcc + dt
    if _camUpdateAcc < 0.04 then return end
    _camUpdateAcc = 0
    local cam = WS.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        cachedAim = {vp.X / 2, vp.Y / 2}
    else
        local ok, mouse = pcall(UIS.GetMouseLocation, UIS)
        cachedAim = ok and {mouse.X, mouse.Y} or {vp.X / 2, vp.Y / 2}
    end
    local aliveFolder = WS:FindFirstChild("Alive")
    if aliveFolder then
        local data = {}
        for _, e in ipairs(aliveFolder:GetChildren()) do
            local pp = e.PrimaryPart
            if pp then
                local ok2, sp = pcall(cam.WorldToScreenPoint, cam, pp.Position)
                if ok2 then data[e.Name] = sp end
            end
        end
        cachedEvents = data
    end
end)

local function fireParry(aim)
    if not Captured.remote or not Captured.args then return false end
    local cam = WS.CurrentCamera
    if not cam then return false end
    local char = LP.Character
    if not char or not char.PrimaryPart then return false end

    aim = aim or cachedAim
    local curveCF = getCurveCFrame(char.PrimaryPart.Position)

    local uid = Captured.args[2]
    local tok = _tokenize(uid) or Captured.args[3]

    local pkt = {
        Captured.args[1],
        uid,
        tok,
        0.5,
        curveCF,
        cachedEvents,
        aim,
        false
    }
    if #Captured.args > 8 then
        pkt[6] = Captured.args[6] or cachedEvents
        pkt[7] = Captured.args[7] or aim
        pkt[8] = Captured.args[8] or false
    end

    local ok = pcall(function()
        if Captured.method == 'FireServer' then
            Captured.remote:FireServer(unpack(pkt))
        else
            Captured.remote:InvokeServer(unpack(pkt))
        end
    end)
    if ok then State.parryCount = State.parryCount + 1 end
    return ok
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════════════
RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    local now = tick()

    local alive, char, hrp, hum = isAlive()
    if not alive then return end

    local folder = WS:FindFirstChild("Balls")
    if not folder then return end

    local myPos = hrp.Position
    local myName = LP.Name

    if not State._ballCache or now - (State._ballCacheTime or 0) > 0.08 then
        State._ballCache = folder:GetChildren()
        State._ballCacheTime = now
    end

    -- close combat check
    if Config.closeCombat then
        State.nearestEnemy = getNearestEnemyDist(myPos)
        State.closeMode = State.nearestEnemy <= Config.closeRangeDist
    else
        State.closeMode = false
    end

    local lockDur = State.closeMode and Config.closeLock or Config.lockDuration
    local maxPerFrame = State.closeMode and Config.closePerFrame or Config.maxPerFrame
    local angleMax = State.closeMode and Config.closeAngleMax or Config.angleMax
    local burst = State.closeMode and Config.closeBurst or 1

    for ball, t in pairs(State.ballLastFire) do
        if not ball.Parent or (now - t) > lockDur then
            State.ballLastFire[ball] = nil
        end
    end

    local recent = {}
    for _, t in ipairs(State.recentFires) do
        if now - t < Config.reflexWindow then table.insert(recent, t) end
    end
    State.recentFires = recent

    local hpPercent = State.hp or 100
    local ballsNear = 0
    local ballList = {}

    for _, ball in ipairs(State._ballCache) do
        if not ball.Parent then continue end
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ball:FindFirstChild("ComboCounter") then continue end

        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        local vel = z.VectorVelocity
        local speed = vel.Magnitude
        if speed < 5 then continue end

        local toPlayer = myPos - ball.Position
        local dist = toPlayer.Magnitude
        if dist > Config.maxDist then continue end

        local targetAttr = ball:GetAttribute("target")
        local isTargeted = (targetAttr == myName)
        if not isTargeted then
            if toPlayer.Magnitude > 0.1 then
                local approach = vel.Unit:Dot(toPlayer.Unit)
                if approach > 0.7 then isTargeted = true end
            end
        end

        if isTargeted then
            table.insert(ballList, { ball = ball, z = z, dist = dist, speed = speed })
            if dist < Config.dangerRadius then ballsNear = ballsNear + 1 end
        end
    end

    State.dangerMode = Config.survivalMode and (
        hpPercent < Config.dangerHpThresh
        or ballsNear >= Config.dangerBallNear
    ) or false

    local reflex = #State.recentFires >= Config.reflexCount

    local candidates = {}

    for _, entry in ipairs(ballList) do
        local ball = entry.ball
        local z = entry.z
        local speed = entry.speed
        local vel = z.VectorVelocity

        local lastFired = State.ballLastFire[ball]
        if lastFired and (now - lastFired) < lockDur then continue end

        local toPlayer = myPos - ball.Position

        local angleOk = true
        if toPlayer.Magnitude > 0.1 then
            local dot = vel.Unit:Dot(toPlayer.Unit)
            local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
            if angle > angleMax then angleOk = false end
        end
        if not angleOk then continue end

        local t_total = (State.ping / 2) + Config.predictAhead
        local predPos = ball.Position + vel * t_total
        local dist = (myPos - predPos).Magnitude

        local curved = isCurved(ball, myPos)
        local window = computeWindow(speed, State.dangerMode, State.closeMode)
        if curved then window = window * Config.curveOnCurved end

        local emergency = entry.dist <= Config.emergencyRadius

        if emergency or dist <= window then
            local score = dist - speed * 0.05
            table.insert(candidates, {
                ball = ball,
                score = score,
                speed = speed,
                z = z,
                emergency = emergency,
            })
        end
    end

    if #candidates > 0 then
        table.sort(candidates, function(a, b) return a.score < b.score end)

        local cap = maxPerFrame
        if State.dangerMode then cap = math.min(cap * 2, 24) end
        if reflex then cap = math.min(cap + 4, 28) end
        if State.closeMode then cap = math.min(cap, Config.closePerFrame) end

        local fireN = math.min(#candidates, cap)

        for i = 1, fireN do
            State.ballLastFire[candidates[i].ball] = now
        end

        local best = candidates[1].ball
        local cam = WS.CurrentCamera
        local aim
        if cam then
            local sp = cam:WorldToScreenPoint(best.Position + candidates[1].z.VectorVelocity * 0.05)
            if sp then aim = {math.floor(sp.X), math.floor(sp.Y)} end
        end

        for i = 1, fireN do
            for _ = 1, burst do
                fireParry(aim)
            end
            table.insert(State.recentFires, now)
        end

        State.lastParry = now
    end
end)

-- == Auto Spam ============================================================
local autoSpamConn = nil
local function startAutoSpam()
    if autoSpamConn then autoSpamConn:Disconnect() end
    autoSpamConn = RunService.PreSimulation:Connect(function()
        if not Config.autoSpam then return end
        local alive = isAlive()
        if not alive then return end
        local now = tick()
        if now - State.lastSpam < (1 / Config.autoSpamCPS) then return end
        State.lastSpam = now
        local folder = WS:FindFirstChild("Balls")
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:GetAttribute("target") == LP.Name then
                fireParry()
                return
            end
        end
    end)
end

-- == Invis ================================================================
local InvisState = { enabled = false, conn = nil, desync = {} }
local function performInvis()
    if not InvisState.enabled then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local alive = WS:FindFirstChild("Alive")
    if not alive or char.Parent ~= alive then return end
    InvisState.desync[1] = hrp.CFrame
    InvisState.desync[2] = hrp.AssemblyLinearVelocity
    local angle = math.random() * math.pi * 2
    hrp.CFrame = CFrame.new(
        hrp.Position.X + math.cos(angle) * 25,
        hrp.Position.Y + 15,
        hrp.Position.Z + math.sin(angle) * 25
    )
    hrp.AssemblyLinearVelocity = Vector3.zero
    RunService.RenderStepped:Wait()
    hrp.CFrame = InvisState.desync[1]
    hrp.AssemblyLinearVelocity = InvisState.desync[2]
end
local function toggleInvis(enabled)
    InvisState.enabled = enabled
    if enabled then
        if not InvisState.conn then
            InvisState.conn = RunService.Heartbeat:Connect(performInvis)
        end
    else
        if InvisState.conn then
            InvisState.conn:Disconnect()
            InvisState.conn = nil
        end
    end
end

-- == Keybinds =============================================================
local curveKeyMap = {
    [Enum.KeyCode.One]   = "camera",
    [Enum.KeyCode.Two]   = "dot",
    [Enum.KeyCode.Three] = "backwards",
    [Enum.KeyCode.Four]  = "slow",
    [Enum.KeyCode.Five]  = "random",
    [Enum.KeyCode.Six]   = "accelerated",
    [Enum.KeyCode.Seven] = "high",
}

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeyMap[input.KeyCode] then
        State.currentCurve = curveKeyMap[input.KeyCode]
        print("[V9.2M] Curve:", State.currentCurve)
    end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[V9.2M]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        Config.autoSpam = false
        toggleInvis(false)
        print("[V9.2M] PANIC")
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — cuma Auto Parry Toggle + Accuracy Slider
-- ═══════════════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title       = "Slax V9.2",
    Icon        = "solar:crown-bold",
    Author      = "ALPHA XK",
    Folder      = "SlaxV92",
    Size        = UDim2.fromOffset(560, 440),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth= 150,
    HasOutline  = true,
})

Window:EditOpenButton({
    Title        = "Slax V9.2",
    Icon         = "solar:crown-bold",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color        = ColorSequence.new(
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(255, 180, 80)
    ),
    OnlyMobile   = true,
})

local TabCombat = Window:Tab({ Title = "Combat", Icon = "solar:sword-bold" })
local TabCurve  = Window:Tab({ Title = "Curve",  Icon = "solar:activity-bold" })
local TabExtra  = Window:Tab({ Title = "Extra",  Icon = "solar:zap-bold" })
local TabInfo   = Window:Tab({ Title = "Info",   Icon = "solar:info-circle-bold" })

-- ─── COMBAT ─── (cuma 2 item)
local SecMain = TabCombat:Section({ Title = "Auto Parry" })

SecMain:Toggle({
    Title    = "Auto Parry",
    Desc     = "Proximity beast — dekat musuh auto brutal",
    Value    = Config.enabled,
    Callback = function(v)
        Config.enabled = v
        WindUI:Notify({
            Title = "Auto Parry",
            Content = v and "Enabled" or "Disabled",
            Duration = 2,
        })
    end,
})

SecMain:Slider({
    Title    = "Accuracy",
    Desc     = "1 = late | 50 = balanced | 100 = early",
    Value    = { Min = 1, Max = 100, Default = Config.accuracy, Rounding = 0 },
    Callback = function(v) Config.accuracy = v end,
})

local SecSpam = TabCombat:Section({ Title = "Auto Spam" })

SecSpam:Toggle({
    Title    = "Auto Spam",
    Desc     = "Spam parry di dekat player",
    Value    = Config.autoSpam,
    Callback = function(v)
        Config.autoSpam = v
        if v then startAutoSpam() end
    end,
})

SecSpam:Slider({
    Title    = "Spam CPS",
    Desc     = "Clicks per second (50-1000)",
    Value    = { Min = 50, Max = 1000, Default = Config.autoSpamCPS, Rounding = 0 },
    Callback = function(v) Config.autoSpamCPS = v end,
})

-- ─── CURVE ───
local SecCurve = TabCurve:Section({ Title = "Curve Method" })

SecCurve:Dropdown({
    Title    = "Curve",
    Values   = {"camera", "dot", "backwards", "slow", "random", "accelerated", "high"},
    Value    = Config.curveMethod,
    Callback = function(v)
        Config.curveMethod = v
        State.currentCurve = v
    end,
})

SecCurve:Paragraph({
    Title = "Hotkeys",
    Desc  = "1=camera  2=dot  3=backwards\n4=slow  5=random  6=accelerated  7=high",
})

-- ─── EXTRA ───
local SecInvis = TabExtra:Section({ Title = "Extras" })

SecInvis:Toggle({
    Title    = "Invisibility",
    Desc     = "HRP desync — hati-hati, bisa lag di server",
    Value    = Config.invisEnabled,
    Callback = function(v)
        Config.invisEnabled = v
        toggleInvis(v)
    end,
})

SecInvis:Button({
    Title    = "Force Re-Hook",
    Desc     = "Re-scan remotes + reset capture",
    Callback = function()
        Captured.remote = nil
        Captured.args = nil
        Captured.done = false
        WindUI:Notify({
            Title = "Re-Hook",
            Content = "Parry manual sekali lagi",
            Duration = 3,
        })
    end,
})

SecInvis:Button({
    Title    = "Unload Script",
    Desc     = "Stop semua loop + hapus UI",
    Callback = function()
        pcall(function() _G.slax_mobile_unload() end)
        pcall(function() Window:Destroy() end)
    end,
})

-- ─── INFO ───
local SecInfo = TabInfo:Section({ Title = "Status" })

local infoPara = SecInfo:Paragraph({
    Title = "Runtime",
    Desc  = "init...",
})

task.spawn(function()
    while State.running do
        pcall(function()
            local mode = "normal"
            if State.dangerMode then mode = "DANGER" end
            if State.closeMode then mode = "CLOSE" end
            if State.dangerMode and State.closeMode then mode = "CLOSE+DANGER" end
            infoPara:Set(string.format(
                "Token: %s\nRemote: %s\nParry: %d\nPing: %d ms\nHP: %d\nNearest: %.0f\nMode: %s",
                _token and "OK" or "FAIL",
                Captured.remote and Captured.remote.Name or "not captured",
                State.parryCount,
                math.floor(State.pingSmooth or 0),
                math.floor(State.hp or 0),
                State.nearestEnemy == math.huge and -1 or State.nearestEnemy,
                mode
            ))
        end)
        task.wait(1)
    end
end)

-- == Init =================================================================
task.spawn(function()
    local deadline = tick() + 30
    while not Captured.done and tick() < deadline do task.wait(0.5) end
    if Captured.done then
        print("[V9.2M] Remote captured: " .. tostring(Captured.remote.Name))
    else
        print("[V9.2M] Remote not captured — parry manual 1-3x")
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V9.2",
    Content = "Clean UI — tuning internal aktif",
    Duration = 5,
})

print("[V9.2M] Slax V9.2 loaded")
print("[V9.2M] Toggle: E | Panic: END | Curves: 1-7")

-- == Unload ===============================================================
_G.slax_mobile_unload = function()
    State.running = false
    if autoSpamConn then autoSpamConn:Disconnect() end
    if InvisState.conn then InvisState.conn:Disconnect() end
    getgenv()._slax_mobile_loaded = nil
end
