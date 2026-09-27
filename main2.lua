-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V11 — Auto Parry (Ssin-Inspired)
-- Author: ALPHA XK | Learn-from: Ssin Hub X
-- Hookfunction + Ssin formula + DebugId lock + multi-fallback target
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._v11_loaded then
    pcall(function() if _G.v11_unload then _G.v11_unload() end end)
    getgenv()._v11_loaded = nil
    task.wait(0.15)
end
getgenv()._v11_loaded = true

-- ═══ SERVICES ═══════════════════════════════════════════════════
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local LP                = Players.LocalPlayer
local UIS               = game:GetService("UserInputService")
local Stats             = game:GetService("Stats")
local RS                = game:GetService("ReplicatedStorage")
local WS                = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

-- ═══ STATE ══════════════════════════════════════════════════════
local AutoParry        = false
local ShowBallStats    = false
local AnimFix          = false
local CurrentCurve     = "camera"

local remote, f_raw    = nil, nil
local c                = {nil, nil, nil, nil, nil, nil, nil}
local remoteHooked     = false
local hookUsedStr      = "None"

local parried_balls    = {}       -- [DebugId] = true
local cachedEvents     = {}
local lastEventCache   = 0

local infinity_active  = false
local deathslash_active= false
local timehole_active  = false
local detections = {
    infinity   = true,
    deathslash = true,
    timehole   = true,
}

local peakVel          = 0
local lastBall         = nil
local cachedHrp        = nil
local lastHrpCache     = 0

-- ═══ EXECUTOR GLOBAL RESOLVER (15 fallback) ═════════════════════
local function getExecutorGlobal(name)
    if getfenv(0) and getfenv(0)[name] then return getfenv(0)[name] end
    if getgenv and getgenv()[name] then return getgenv()[name] end
    if getrenv and getrenv()[name] then return getrenv()[name] end
    if _G and _G[name] then return _G[name] end
    if shared and shared[name] then return shared[name] end

    local val
    pcall(function() if gethui and gethui()[name] then val = gethui()[name] end end)
    if val then return val end
    pcall(function() if getsenv and getsenv()[name] then val = getsenv()[name] end end)
    if val then return val end
    pcall(function() if gettenv and gettenv()[name] then val = gettenv()[name] end end)
    if val then return val end
    pcall(function() if getmenv and getmenv()[name] then val = getmenv()[name] end end)
    if val then return val end

    pcall(function()
        if getscriptenvs then
            for _, env in pairs(getscriptenvs()) do
                if type(env) == "table" and env[name] then val = env[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        if getscripts and getsenv then
            for _, scr in pairs(getscripts()) do
                local ok, e = pcall(getsenv, scr)
                if ok and e and e[name] then val = e[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        if getloadedmodules and getmenv then
            for _, mod in pairs(getloadedmodules()) do
                local ok, e = pcall(getmenv, mod)
                if ok and e and e[name] then val = e[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        if getcallingscript and getsenv then
            local e = getsenv(getcallingscript())
            if e and e[name] then val = e[name] end
        end
    end)
    if val then return val end

    pcall(function()
        if getreg then
            for _, v in pairs(getreg()) do
                if type(v) == "table" and v[name] then val = v[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        if debug and debug.getregistry then
            for _, v in pairs(debug.getregistry()) do
                if type(v) == "table" and v[name] then val = v[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        if getgc then
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and v[name] then val = v[name] break end
            end
        end
    end)
    if val then return val end

    pcall(function()
        for i = 1, 30 do
            local env = getfenv(i)
            if env and env[name] then val = env[name] break end
        end
    end)
    return val
end

local hookfunction = hookfunction or getExecutorGlobal("hookfunction") or getExecutorGlobal("hookfunc")
local newcclosure  = newcclosure  or getExecutorGlobal("newcclosure") or function(f) return f end

print("[V11] hookfunction:", type(hookfunction))
print("[V11] newcclosure :", type(newcclosure))

-- ═══ TOKEN (dari Ssin — pakai getupvalues) ══════════════════════
local _token = nil
local getgcFn = getgc or getExecutorGlobal("getgc")
if getgcFn then
    for _, f in ipairs(getgcFn(true)) do
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
end
print("[V11] token:", _token and "OK" or "FAIL")

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

-- ═══ CURVE ══════════════════════════════════════════════════════
local function getCurveCFrame()
    local camera = WS.CurrentCamera
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return camera.CFrame end

    local closestDot = -math.huge
    local targetPos
    local Alive = WS:FindFirstChild("Alive")
    if Alive then
        for _, e in pairs(Alive:GetChildren()) do
            if e ~= char and e:FindFirstChild("HumanoidRootPart") then
                local dir = (e.HumanoidRootPart.Position - camera.CFrame.Position).Unit
                local dot = camera.CFrame.LookVector:Dot(dir)
                if dot > closestDot then
                    closestDot = dot
                    targetPos = e.HumanoidRootPart.Position
                end
            end
        end
    end
    targetPos = targetPos or (root.Position + camera.CFrame.LookVector * 1000)
    local toTarget = (targetPos - root.Position).Unit

    local m = CurrentCurve
    if m == "dot" then
        return CFrame.lookAt(root.Position, targetPos + Vector3.new(0, 1.75, 0))
    elseif m == "backwards" then
        return CFrame.new(root.Position, root.Position + (-toTarget) * 1000)
    elseif m == "slow" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, -350, 0))
    elseif m == "random" then
        local dir = (targetPos - root.Position).Unit
        local off
        local tries = 0
        repeat
            off = Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
            local cd = (targetPos + off - root.Position).Unit
            tries = tries + 1
        until dir:Dot(cd) < 0.95 or tries > 10
        return CFrame.new(root.Position, targetPos + off)
    elseif m == "accelerated" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 5, 0))
    elseif m == "high" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 9e18, 0))
    else
        return camera.CFrame
    end
end

-- ═══ HOOK — hookfunction ke dummy FireServer/InvokeServer ════════
local function isValidRemoteArgs(args)
    return #args >= 4 and typeof(args[4]) == "CFrame"
end

if hookfunction and newcclosure then
    local ok, err = pcall(function()
        local dummyEvent = Instance.new("RemoteEvent")
        local dummyFunc  = Instance.new("RemoteFunction")

        local origFS
        origFS = hookfunction(dummyEvent.FireServer, newcclosure(function(self, ...)
            local args = { ... }
            if isValidRemoteArgs(args) then
                if not remoteHooked then
                    remoteHooked = true
                    remote = self
                    f_raw = origFS
                    for i = 1, 7 do c[i] = args[i] end
                    print("[V11] Remote captured:", self.Name or "?")
                end
                if getCurveCFrame then
                    local cf = getCurveCFrame()
                    if cf then args[4] = cf end
                end
                return origFS(self, unpack(args))
            end
            return origFS(self, ...)
        end))

        local origIS
        origIS = hookfunction(dummyFunc.InvokeServer, newcclosure(function(self, ...)
            local args = { ... }
            if isValidRemoteArgs(args) then
                if not remoteHooked then
                    remoteHooked = true
                    remote = self
                    f_raw = origIS
                    for i = 1, 7 do c[i] = args[i] end
                    print("[V11] Remote captured (Invoke):", self.Name or "?")
                end
                if getCurveCFrame then
                    local cf = getCurveCFrame()
                    if cf then args[4] = cf end
                end
                return origIS(self, unpack(args))
            end
            return origIS(self, ...)
        end))

        hookUsedStr = "HookFunction"
    end)
    if not ok then warn("[V11] hook failed:", err) end
else
    warn("[V11] hookfunction not available — auto parry disabled")
end

-- ═══ BALL FINDER ═════════════════════════════════════════════════
local function findBall()
    local bc = WS:FindFirstChild("Balls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:IsA("BasePart") and b:GetAttribute("realBall") then return b end
        end
        local b = bc:GetChildren()[1]
        if b and b:IsA("BasePart") then return b end
    end
    return nil
end

-- ═══ PING ════════════════════════════════════════════════════════
local function getPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ok and v or 0.08
end

-- ═══ FIRE PARRY (pakai f_raw langsung) ═══════════════════════════
local function fireParry()
    if not (remote and f_raw) then return false end
    local cam = WS.CurrentCamera
    local char = LP.Character
    if not char then return false end

    local now = tick()
    if now - lastEventCache > 0.1 then
        cachedEvents = {}
        local Alive = WS:FindFirstChild("Alive")
        if Alive then
            for _, v in ipairs(Alive:GetChildren()) do
                if v ~= char and v.PrimaryPart then
                    local sp, vis = cam:WorldToScreenPoint(v.PrimaryPart.Position)
                    if vis then cachedEvents[tostring(v)] = sp end
                end
            end
        end
        lastEventCache = now
    end

    local vp = cam.ViewportSize
    local curveCF = getCurveCFrame()
    c[3] = curveCF.LookVector
    c[4] = curveCF
    c[5] = cachedEvents
    c[6] = {vp.X / 2, vp.Y / 2}

    local ok = pcall(function() f_raw(remote, unpack(c)) end)
    return ok
end

-- ═══ DETECTION EVENTS ════════════════════════════════════════════
pcall(function()
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b)
        infinity_active = b or false
    end)
end)
pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, d)
        deathslash_active = d or false
    end)
end)
pcall(function()
    local pkg = RS:FindFirstChild("Packages")
    if pkg then
        local idx = pkg:FindFirstChild("_Index")
        if idx then
            local netMod = idx:FindFirstChild("sleitnick_net@0.1.0")
            if netMod then
                local net = require(netMod.net)
                net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
                    local p = (...)
                    if p == LP or (p and p.Name == LP.Name) then timehole_active = true end
                end)
                net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
                    timehole_active = false
                end)
            end
        end
    end
end)

-- ═══ TARGET ATTRIBUTE MULTI-FALLBACK ═════════════════════════════
local function isMyTarget(ball)
    local t = ball:GetAttribute("target")
        or ball:GetAttribute("Target")
        or ball:GetAttribute("targetPlayer")
        or ball:GetAttribute("TargetPlayer")
    if t == nil then return false end
    if t == LP.Name then return true end
    if t == LP.UserId then return true end
    if tostring(t) == tostring(LP.UserId) then return true end
    return false
end

-- ═══ MAIN LOOP — SIN FORMULA ═════════════════════════════════════
RunService.Heartbeat:Connect(function()
    local now = tick()

    if now - lastHrpCache > 0.15 then
        local ch = LP.Character
        cachedHrp = ch and ch:FindFirstChild("HumanoidRootPart")
        lastHrpCache = now
    end
    local hrp = cachedHrp
    if not hrp then return end

    local ball = findBall()
    lastBall = ball

    if not AutoParry or not remote or not f_raw then return end
    if not ball or not ball:IsA("BasePart") then return end

    if not isMyTarget(ball) then return end

    -- detection skip
    if detections.infinity   and infinity_active   then return end
    if detections.deathslash and deathslash_active then return end
    if detections.timehole   and timehole_active   then return end

    local bID = ball:GetDebugId()
    if parried_balls[bID] then return end

    local ping = getPing()
    local dist = (hrp.Position - ball.Position).Magnitude

    local shouldParry = false
    local zoomies = ball:FindFirstChild("zoomies")
    if zoomies then
        local vel = zoomies.VectorVelocity
        local speed = vel.Magnitude
        local dir = (hrp.Position - ball.Position).Unit
        local dot = dir:Dot(vel.Unit)

        if dot >= (0.3 - ping * 0.5) then
            local threshold = speed * (ping + 0.016) * 8 * 0.43
            if dist <= threshold or dist <= 9 then
                shouldParry = true
            end
        end
    else
        local speed = ball.AssemblyLinearVelocity.Magnitude
        if dist <= 12 and speed > 1 then
            shouldParry = true
        end
    end

    if shouldParry then
        fireParry()
        parried_balls[bID] = true
        task.spawn(function()
            ball:GetAttributeChangedSignal("target"):Wait()
            parried_balls[bID] = nil
        end)
        -- safety reset 3s kalau target nggak berubah
        task.delay(3, function()
            parried_balls[bID] = nil
        end)
    end
end)

-- ═══ BALL STATS ══════════════════════════════════════════════════
local StatsGui = Instance.new("ScreenGui", CoreGui)
StatsGui.Name = "V11Stats"
StatsGui.ResetOnSpawn = false
StatsGui.DisplayOrder = 999
StatsGui.IgnoreGuiInset = true

local PFrame = Instance.new("Frame", StatsGui)
PFrame.Size = UDim2.new(0, 160, 0, 100)
PFrame.Position = UDim2.new(0, 20, 0.5, -50)
PFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
PFrame.BorderSizePixel = 0
PFrame.Visible = false
Instance.new("UICorner", PFrame).CornerRadius = UDim.new(0, 10)
local PS = Instance.new("UIStroke", PFrame)
PS.Color = Color3.fromRGB(255, 80, 80)
PS.Thickness = 1.5

local PTitle = Instance.new("TextLabel", PFrame)
PTitle.Size = UDim2.new(1, 0, 0, 24)
PTitle.Text = " BALL SPEED"
PTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
PTitle.BackgroundTransparency = 1
PTitle.Font = Enum.Font.GothamBold
PTitle.TextSize = 12
PTitle.TextXAlignment = Enum.TextXAlignment.Left

local VLog = Instance.new("TextLabel", PFrame)
VLog.Position = UDim2.new(0.08, 0, 0.35, 0)
VLog.Size = UDim2.new(0.8, 0, 0, 30)
VLog.Text = "0.0"
VLog.TextColor3 = Color3.fromRGB(220, 220, 220)
VLog.BackgroundTransparency = 1
VLog.Font = Enum.Font.GothamBold
VLog.TextSize = 22
VLog.TextXAlignment = Enum.TextXAlignment.Left

local PLabel = Instance.new("TextLabel", PFrame)
PLabel.Position = UDim2.new(0.08, 0, 0.72, 0)
PLabel.Size = UDim2.new(0.8, 0, 0, 16)
PLabel.Text = "peak: 0.0"
PLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
PLabel.BackgroundTransparency = 1
PLabel.Font = Enum.Font.Gotham
PLabel.TextSize = 11
PLabel.TextXAlignment = Enum.TextXAlignment.Left

RunService.Heartbeat:Connect(function()
    if not ShowBallStats then return end
    if not lastBall or not lastBall.Parent then
        VLog.Text = "0.0"
        return
    end
    local v = lastBall.AssemblyLinearVelocity.Magnitude
    VLog.Text = string.format("%.1f", v)
    if v > peakVel then
        peakVel = v
        PLabel.Text = string.format("peak: %.1f", peakVel)
    end
end)

-- ═══ UI — pakai WindUI v2 ════════════════════════════════════════
local ok_windui, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)

if not ok_windui or not WindUI then
    warn("[V11] WindUI load failed")
    return
end

local Window = WindUI:CreateWindow({
    Title       = "Slax V11",
    Icon        = "solar:crown-bold",
    Author      = "ALPHA XK",
    Folder      = "SlaxV11",
    Size        = UDim2.fromOffset(520, 440),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth= 150,
})

Window:EditOpenButton({
    Title        = "V11",
    Icon         = "solar:crown-bold",
    CornerRadius = UDim.new(0, 14),
    Color        = ColorSequence.new(
        Color3.fromRGB(255, 60, 60),
        Color3.fromRGB(255, 200, 80)
    ),
    OnlyMobile   = true,
})

local TabMain = Window:Tab({ Title = "Combat", Icon = "solar:sword-bold" })
local TabDet  = Window:Tab({ Title = "Detection", Icon = "solar:shield-bold" })
local TabCurve= Window:Tab({ Title = "Curve", Icon = "solar:activity-bold" })
local TabVis  = Window:Tab({ Title = "Visual", Icon = "solar:eye-bold" })
local TabInfo = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

-- COMBAT
local SecMain = TabMain:Section({ Title = "Auto Parry" })

SecMain:Toggle({
    Title    = "Auto Parry",
    Desc     = "Ssin formula — ping + speed adaptive",
    Value    = false,
    Callback = function(v)
        AutoParry = v
        parried_balls = {}
        WindUI:Notify({ Title = "Auto Parry", Content = v and "ON" or "OFF", Duration = 2 })
    end,
})

SecMain:Toggle({
    Title    = "Animation Fix",
    Desc     = "Play parry animation (stealth)",
    Value    = false,
    Callback = function(v) AnimFix = v end,
})

-- DETECTION
local SecDet = TabDet:Section({ Title = "Skip Parry Saat Ability Ini Aktif" })

SecDet:Toggle({
    Title    = "Infinity Ball",
    Desc     = "Skip parry saat Infinity aktif",
    Value    = true,
    Callback = function(v) detections.infinity = v end,
})

SecDet:Toggle({
    Title    = "Death Slash",
    Desc     = "Skip parry saat Death Slash aktif",
    Value    = true,
    Callback = function(v) detections.deathslash = v end,
})

SecDet:Toggle({
    Title    = "Time Hole",
    Desc     = "Skip parry saat Time Hole aktif",
    Value    = true,
    Callback = function(v) detections.timehole = v end,
})

-- CURVE
local SecCurve = TabCurve:Section({ Title = "Curve Method" })

SecCurve:Dropdown({
    Title    = "Curve",
    Values   = {"camera", "dot", "backwards", "slow", "random", "accelerated", "high"},
    Value    = "camera",
    Callback = function(v) CurrentCurve = v end,
})

-- VISUAL
local SecVis = TabVis:Section({ Title = "Display" })

SecVis:Toggle({
    Title    = "Ball Speed Stats",
    Desc     = "Show ball velocity + peak",
    Value    = false,
    Callback = function(v)
        ShowBallStats = v
        PFrame.Visible = v
        if not v then
            peakVel = 0
            PLabel.Text = "peak: 0.0"
        end
    end,
})

-- INFO
local SecInfo = TabInfo:Section({ Title = "Runtime" })
local infoPara = SecInfo:Paragraph({ Title = "Status", Desc = "init..." })

task.spawn(function()
    while getgenv()._v11_loaded do
        pcall(function()
            infoPara:Set(string.format(
                "Hook: %s\nToken: %s\nRemote: %s\nParry count: %d",
                hookUsedStr,
                _token and "OK" or "FAIL",
                remote and (remote.Name or "captured") or "waiting",
                (function()
                    local n = 0
                    for _ in pairs(parried_balls) do n = n + 1 end
                    return n
                end)()
            ))
        end)
        task.wait(1)
    end
end)

-- Keybind E / END
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        AutoParry = not AutoParry
        print("[V11] AutoParry:", AutoParry and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.End then
        AutoParry = false
        print("[V11] PANIC")
    end
end)

-- Curve hotkeys 1-7
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
        CurrentCurve = curveKeyMap[input.KeyCode]
        print("[V11] Curve:", CurrentCurve)
    end
end)

-- Wait capture notify
task.spawn(function()
    local t0 = tick()
    while not remoteHooked and tick() - t0 < 30 do task.wait(0.3) end
    if remoteHooked then
        WindUI:Notify({
            Title = "V11",
            Content = "Remote captured: " .. (remote.Name or "?"),
            Duration = 5,
        })
    else
        WindUI:Notify({
            Title = "V11",
            Content = "Remote not captured — parry manual 1-3x",
            Duration = 6,
        })
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V11",
    Content = "Loaded — parry manual sekali kalau belum",
    Duration = 5,
})

print("[V11] Slax V11 loaded")
print("[V11] Toggle: E | Panic: END | Curves: 1-7")

-- Unload
_G.v11_unload = function()
    getgenv()._v11_loaded = nil
    pcall(function() StatsGui:Destroy() end)
    pcall(function() Window:Destroy() end)
end
