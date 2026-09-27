-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V8.1 MOBILE — Blade Ball Auto Parry
-- Author: ALPHA XK | For: Redz
-- UI: WindUI v2 Modern | Core: V8 (token regen + multi-target)
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._slax_mobile_loaded then
    pcall(function() if _G.slax_mobile_unload then _G.slax_mobile_unload() end end)
    getgenv()._slax_mobile_loaded = nil
    task.wait(0.15)
end
getgenv()._slax_mobile_loaded = true

-- == Services =============================================================
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local WS            = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local Stats         = game:GetService("Stats")
local LP            = Players.LocalPlayer

-- == Config ===============================================================
local Config = {
    enabled         = true,
    accuracy        = 100,
    curveMethod     = "camera",
    autoSpam        = false,
    autoSpamCPS     = 200,
    triggerBot      = false,
    invisEnabled    = false,
    toggleKey       = "E",
    panicKey        = "END",
    maxPerFrame     = 6,
    lockDuration    = 0.7,
    maxDist         = 150,
}

-- == State ================================================================
local State = {
    running         = true,
    parried         = setmetatable({}, { __mode = "k" }),
    ballLastFire    = setmetatable({}, { __mode = "k" }),
    parryCount      = 0,
    lastParry       = 0,
    lastSpam        = 0,
    ping            = 0.06,
    pingSmooth      = 60,
    curveState      = setmetatable({}, { __mode = "k" }),
    parryCDUntil    = 0,
    parriedMain     = false,
    currentCurve    = "camera",
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

print('[V8.1M] Token:', _token and 'OK' or 'FAIL')

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK
-- ═══════════════════════════════════════════════════════════════════════════
local Captured = { remote = nil, method = nil, args = nil, done = false }

local _hookedMT = {}
for _, r in ipairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        local ok, mt = pcall(getrawmetatable, r)
        if ok and mt and not _hookedMT[mt] then
            _hookedMT[mt] = true
            pcall(setreadonly, mt, false)
            local old = mt.__index
            mt.__index = function(self, key)
                if key == 'FireServer' or key == 'InvokeServer' then
                    return function(_, ...)
                        local args = { ... }
                        if not Captured.remote and #args >= 6
                        and type(args[2]) == 'string'
                        and type(args[3]) == 'string'
                        and typeof(args[5]) == 'CFrame' then
                            Captured.remote = self
                            Captured.method = key
                            Captured.args = args
                            Captured.done = true
                            print('[V8.1M] Captured:', self.Name, '#args=' .. #args)
                        end
                        return old(self, key)(_, ...)
                    end
                end
                return old(self, key)
            end
            pcall(setreadonly, mt, true)
        end
    end
end

print('[V8.1M] Remotes hooked')

-- == Character ============================================================
local function isAlive()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if hrp:FindFirstChild("SingularityCape") then return false end
    return true, char, hrp
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

local function computeWindow(speed)
    local ping = State.pingSmooth or State.ping * 1000
    local pingThr = math.clamp(ping / 80, 4, 25)
    local mult = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035353535353535
    local divisor = (2.2 + 0.9 * math.log(1 + speed / 80)) * mult
    local sf = 1
    if speed > 200 then sf = 1 + math.min((speed - 200) / 1000, 0.3) end
    return pingThr + math.max(speed / divisor, 9.5) * sf
end

-- == Fire =================================================================
local cachedAim = {0, 0}
local cachedEvents = {}
local _camUpdateAcc = 0

RunService.RenderStepped:Connect(function(dt)
    _camUpdateAcc = _camUpdateAcc + dt
    if _camUpdateAcc < 0.05 then return end
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
local lastFrame = tick()

RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    local now = tick()
    lastFrame = now

    local alive, char, hrp = isAlive()
    if not alive then return end

    local folder = WS:FindFirstChild("Balls")
    if not folder then return end

    local myPos = hrp.Position
    local myName = LP.Name

    if not State._ballCache or now - (State._ballCacheTime or 0) > 0.1 then
        State._ballCache = folder:GetChildren()
        State._ballCacheTime = now
    end

    for ball, t in pairs(State.ballLastFire) do
        if not ball.Parent or (now - t) > Config.lockDuration then
            State.ballLastFire[ball] = nil
        end
    end

    local candidates = {}

    for _, ball in ipairs(State._ballCache) do
        if not ball.Parent then continue end
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ball:FindFirstChild("ComboCounter") then continue end

        local lastFired = State.ballLastFire[ball]
        if lastFired and (now - lastFired) < Config.lockDuration then continue end

        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        local vel = z.VectorVelocity
        local speed = vel.Magnitude
        if speed < 5 then continue end

        local rawDist = (myPos - ball.Position).Magnitude
        if rawDist > Config.maxDist then continue end

        local targetAttr = ball:GetAttribute("target")
        local isTargeted = (targetAttr == myName)
        if not isTargeted then
            local toPlayer = myPos - ball.Position
            if toPlayer.Magnitude > 0.1 then
                local approach = vel.Unit:Dot(toPlayer.Unit)
                if approach > 0.85 then isTargeted = true end
            end
        end
        if not isTargeted then continue end

        local t = State.ping / 2
        local predPos = ball.Position + vel * t
        local dist = (myPos - predPos).Magnitude

        local curved = isCurved(ball, myPos)
        local window = computeWindow(speed)
        if curved then window = window * 0.7 end

        if dist <= window then
            local score = dist - speed * 0.05
            table.insert(candidates, {
                ball = ball,
                score = score,
                speed = speed,
                z = z,
            })
        end
    end

    if #candidates > 0 then
        table.sort(candidates, function(a, b) return a.score < b.score end)
        local fireN = math.min(#candidates, Config.maxPerFrame)

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
            fireParry(aim)
        end

        State.lastParry = now
        State.parriedMain = true
        State.parryCDUntil = now + 0.1
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

-- == Trigger Bot ==========================================================
local triggerConn = nil
local triggerBusy = false
local function startTriggerBot()
    if triggerConn then triggerConn:Disconnect() end
    triggerConn = RunService.Heartbeat:Connect(function()
        if not Config.triggerBot then return end
        if triggerBusy then return end
        local alive = isAlive()
        if not alive then return end
        local folder = WS:FindFirstChild("Balls")
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:IsA("BasePart") and ball:GetAttribute("target") == LP.Name then
                triggerBusy = true
                fireParry()
                task.delay(0.5, function() triggerBusy = false end)
                break
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
        print("[V8.1M] Curve:", State.currentCurve)
    end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[V8.1M]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        Config.autoSpam = false
        Config.triggerBot = false
        toggleInvis(false)
        print("[V8.1M] PANIC")
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — WINDUI v2 MODERN
-- ═══════════════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title       = "Slax Hub",
    Icon        = "solar:crown-bold",
    Author      = "ALPHA XK",
    Folder      = "SlaxV8",
    Size        = UDim2.fromOffset(560, 440),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth= 150,
    HasOutline  = true,
})

Window:EditOpenButton({
    Title        = "Slax V8",
    Icon         = "solar:crown-bold",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color        = ColorSequence.new(
        Color3.fromRGB(120, 100, 255),
        Color3.fromRGB(255, 100, 200)
    ),
    OnlyMobile   = true,
})

-- Tabs
local TabCombat = Window:Tab({ Title = "Combat", Icon = "solar:sword-bold" })
local TabCurve  = Window:Tab({ Title = "Curve",  Icon = "solar:activity-bold" })
local TabExtra  = Window:Tab({ Title = "Extra",  Icon = "solar:zap-bold" })
local TabInfo   = Window:Tab({ Title = "Info",   Icon = "solar:info-circle-bold" })

-- ─── COMBAT ───
local SecMain = TabCombat:Section({ Title = "Auto Parry" })

SecMain:Toggle({
    Title    = "Auto Parry",
    Desc     = "Master switch — predictive multi-target",
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
    Desc     = "1 = late | 100 = early",
    Value    = { Min = 1, Max = 100, Default = Config.accuracy, Rounding = 0 },
    Callback = function(v) Config.accuracy = v end,
})

SecMain:Slider({
    Title    = "Max Parry / Frame",
    Desc     = "Banyak bola per frame — 6 = safe, 10 = aggressive",
    Value    = { Min = 1, Max = 12, Default = Config.maxPerFrame, Rounding = 0 },
    Callback = function(v) Config.maxPerFrame = v end,
})

SecMain:Slider({
    Title    = "Anti-Double Lock (s)",
    Desc     = "Skip bola yang baru di-fire N detik",
    Value    = { Min = 0.3, Max = 2.0, Default = Config.lockDuration, Rounding = 2 },
    Callback = function(v) Config.lockDuration = v end,
})

SecMain:Slider({
    Title    = "Max Distance",
    Desc     = "Radius deteksi bola (studs)",
    Value    = { Min = 50, Max = 400, Default = Config.maxDist, Rounding = 0 },
    Callback = function(v) Config.maxDist = v end,
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

local SecTrigger = TabCombat:Section({ Title = "Triggerbot" })

SecTrigger:Toggle({
    Title    = "Trigger Bot",
    Desc     = "Fire saat target = lo",
    Value    = Config.triggerBot,
    Callback = function(v)
        Config.triggerBot = v
        if v then startTriggerBot() end
    end,
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
        _hookedMT = {}
        for _, r in ipairs(RS:GetDescendants()) do
            if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
                local ok, mt = pcall(getrawmetatable, r)
                if ok and mt and not _hookedMT[mt] then
                    _hookedMT[mt] = true
                    pcall(setreadonly, mt, false)
                    local old = mt.__index
                    mt.__index = function(self, key)
                        if key == 'FireServer' or key == 'InvokeServer' then
                            return function(_, ...)
                                local args = { ... }
                                if not Captured.remote and #args >= 6
                                and type(args[2]) == 'string'
                                and type(args[3]) == 'string'
                                and typeof(args[5]) == 'CFrame' then
                                    Captured.remote = self
                                    Captured.method = key
                                    Captured.args = args
                                    Captured.done = true
                                end
                                return old(self, key)(_, ...)
                            end
                        end
                        return old(self, key)
                    end
                    pcall(setreadonly, mt, true)
                end
            end
        end
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
            infoPara:Set(string.format(
                "Token: %s\nRemote: %s\nParry count: %d\nPing: %d ms",
                _token and "OK" or "FAIL",
                Captured.remote and Captured.remote.Name or "not captured",
                State.parryCount,
                math.floor(State.pingSmooth or 0)
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
        print("[V8.1M] Remote captured: " .. tostring(Captured.remote.Name))
    else
        print("[V8.1M] Remote not captured — parry manual 1-3x")
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V8.1",
    Content = "Auto Parry loaded — parry manual sekali",
    Duration = 5,
})

print("[V8.1M] Slax V8.1 Mobile loaded")
print("[V8.1M] Toggle: E | Panic: END | Curves: 1-7")

-- == Unload ===============================================================
_G.slax_mobile_unload = function()
    State.running = false
    if autoSpamConn then autoSpamConn:Disconnect() end
    if triggerConn then triggerConn:Disconnect() end
    if InvisState.conn then InvisState.conn:Disconnect() end
    getgenv()._slax_mobile_loaded = nil
end
