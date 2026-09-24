-- Slax Hub v30.0 - STRONGEST AUTO PARRY
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(650, 500),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "Slax Hub",
    Icon = "sword",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 80, 255)),
    OnlyMobile = false,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- =========================================
-- Services
-- =========================================
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- =========================================
-- State
-- =========================================
local AutoParryEnabled = false
local AccuracyValue = 75
local UseAutoAccuracy = true

-- =========================================
-- Token Retrieval (Bypass)
-- =========================================
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' and debug.info(f, 's'):find('PRY', 1, true) then
        for _, v in debug.getupvalues(f) do
            if type(v) == 'function' then
                _token = v
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(uid)
    if not _token then return "" end
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
end

-- =========================================
-- Remote Hooking
-- =========================================
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" 
        and type(args[4]) == "number" and typeof(args[5]) == "CFrame" 
        and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)
        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent')) or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _args = {...}
                    if _is_valid(_args) and not _reverted[self] then
                        _reverted[self] = _args
                    end
                    return _old(self, key)(_, unpack(_args))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

-- =========================================
-- Fire Parry (Cached Remote)
-- =========================================
local _parryRemote = nil
local _parryArgs = nil

local function GetParryRemote()
    if not _parryRemote or not _parryRemote.Parent then
        _parryRemote = nil
        _parryArgs = nil
        for r, a in pairs(_reverted) do
            _parryRemote = r
            _parryArgs = a
            break
        end
    end
    return _parryRemote, _parryArgs
end

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    local packet = {
        args[1], args[2], _tokenize(args[2]), 0.5,
        WS.CurrentCamera.CFrame, {}, {0, 0}, false
    }
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- 🧠 ADVANCED TRAJECTORY ANALYSIS
-- =========================================
-- Determine if ball will hit player (projectile-like collision prediction)
-- Returns: willHit (bool), timeToImpact (sec), missDistance (studs)
-- =========================================
local function AnalyzeTrajectory(ballPos, ballVel, playerPos, playerVel)
    local relPos = playerPos - ballPos
    local relVel = ballVel - (playerVel or Vector3.zero)

    local speed = relVel.Magnitude
    if speed < 3 then return false, 999, 999 end

    -- 🎯 Closest approach time
    local timeToClosest = relPos:Dot(relVel) / (speed * speed)
    if timeToClosest < 0 then
        return false, 999, 999  -- ball is moving away
    end

    -- 🎯 Closest distance
    local closestPoint = ballPos + (ballVel * timeToClosest)
    local closestDist = (playerPos - closestPoint).Magnitude

    -- 🎯 Hit radius (account for character size)
    local HIT_RADIUS = 6

    if closestDist > HIT_RADIUS then
        return false, 999, closestDist
    end

    return true, timeToClosest, closestDist
end

-- =========================================
-- 🌀 ANTI-CURVE TRACKING
-- =========================================
local ballTracking = {}

local function TrackCurve(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return false end

    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = { lastVel = vel, curveScore = 0, curveActive = false }
        return false
    end

    local dot = data.lastVel.Unit:Dot(vel.Unit)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))

    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
    else
        data.curveScore = data.curveScore * 0.9
    end

    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel

    return data.curveActive
end

task.spawn(function()
    while task.wait(1) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then ballTracking[ball] = nil end
        end
    end
end)

-- =========================================
-- 🎯 ADAPTIVE TIMING CALCULATOR
-- =========================================
local function CalculateParryWindow(ballSpeed, curveActive, distance, isClose)
    -- Base window based on AccuracyValue (inverted: 100 = safety)
    local baseMs
    if UseAutoAccuracy then
        -- Auto: Adaptive
        baseMs = 80  -- base 80ms
        
        -- ⚡ Speed adjustment
        if ballSpeed > 250 then baseMs = baseMs + 120
        elseif ballSpeed > 200 then baseMs = baseMs + 90
        elseif ballSpeed > 150 then baseMs = baseMs + 60
        elseif ballSpeed > 100 then baseMs = baseMs + 40
        elseif ballSpeed > 60 then baseMs = baseMs + 20
        end
        
        -- 🌀 Curve adjustment
        if curveActive then baseMs = baseMs + 40 end
        
        -- 📏 Distance adjustment
        if distance < 12 then baseMs = baseMs + 80
        elseif distance < 25 then baseMs = baseMs + 50
        elseif distance < 40 then baseMs = baseMs + 25
        end
    else
        -- Manual: 30ms (perfect) → 250ms (safe)
        baseMs = 30 + ((AccuracyValue / 100) * 220)
    end

    -- 🛡️ Close combat bonus (independent)
    if isClose then baseMs = baseMs + 40 end

    return baseMs
end

-- =========================================
-- 🔥⚡ THE STRONGEST AUTO PARRY LOOP
-- =========================================
local lastParryTime = 0
local GLOBAL_LOCK = 0.10
local BALL_LOCK = 0.6
local ballLocks = {}

-- Cleanup lock table
task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then ballLocks[ball] = nil end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        return
    end

    local now = tick()
    local ping = GetPing()

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local playerVel = hrp.AssemblyLinearVelocity
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end

    local balls = ballsFolder:GetChildren()

    -- =========================================
    -- 🚨 PHASE 1: ULTRA-EMERGENCY (Point Blank + Fast)
    -- =========================================
    -- Critical: أي كرة قريبة جدا (<15 studs) أو سريعة جدا → صد فوري
    if (now - lastParryTime) < 0.04 then
        -- منع double parry
    else
        for i = 1, #balls do
            local ball = balls[i]
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local dot = velocity.Unit:Dot((playerPos - ballPos).Unit)
            if dot <= 0.3 then continue end

            -- 🚨 Emergency trigger
            local isEmergency = false

            -- Point blank (قريب جداً)
            if distance <= 15 then
                isEmergency = true
            -- Ultra fast + relatively close
            elseif speed >= 200 and distance <= 60 then
                isEmergency = true
            -- Fast + very close
            elseif speed >= 130 and distance <= 30 then
                isEmergency = true
            end

            if isEmergency then
                -- Verify trajectory (even in emergency)
                local willHit = AnalyzeTrajectory(ballPos, velocity, playerPos, playerVel)
                if willHit then
                    lastParryTime = now
                    ballLocks[ball] = now + BALL_LOCK
                    FireParry()
                    return
                end
            end
        end
    end

    -- =========================================
    -- 🎯 PHASE 2: PRECISION PARRY (Main)
    -- =========================================
    if (now - lastParryTime) < GLOBAL_LOCK then return end

    local bestBall = nil
    local bestTime = math.huge
    local bestSpeed = 0
    local bestDistance = math.huge
    local bestCurve = false

    for i = 1, #balls do
        local ball = balls[i]
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        local distance = (playerPos - ballPos).Magnitude
        if distance > 150 then continue end

        -- 🎯 Full trajectory analysis
        local willHit, timeToImpact, missDist = AnalyzeTrajectory(ballPos, velocity, playerPos, playerVel)
        if not willHit then continue end

        -- 🌀 Curve detection
        local curveActive = TrackCurve(ball)

        -- Track best ball (earliest impact)
        if timeToImpact < bestTime then
            bestTime = timeToImpact
            bestBall = ball
            bestSpeed = speed
            bestDistance = distance
            bestCurve = curveActive
        end
    end

    if bestBall then
        -- 🎯 Calculate parry window
        local windowMs = CalculateParryWindow(bestSpeed, bestCurve, bestDistance, false)
        local windowSec = windowMs / 1000

        -- ⏱️ Fire when ball will arrive within (ping + window)
        local effectiveWindow = ping + windowSec

        if bestTime <= effectiveWindow then
            lastParryTime = now
            ballLocks[bestBall] = now + BALL_LOCK
            FireParry()
        end
    end
end)

-- =========================================
-- FPS/Ping UI
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "SlaxStatsUI_" .. math.random(1, 99999)
StatsGui.Parent = GetGuiParent()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 99999

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Parent = StatsGui
StatsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
StatsLabel.BackgroundTransparency = 0.3
StatsLabel.BorderSizePixel = 0
StatsLabel.Position = UDim2.new(0.72, 0, 0.02, 0)
StatsLabel.Size = UDim2.new(0, 260, 0, 50)
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.Text = "Slax Hub v30.0"
StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
StatsLabel.TextSize = 11

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsLabel

local StatsStroke = Instance.new("UIStroke")
StatsStroke.Parent = StatsLabel
StatsStroke.Color = Color3.fromRGB(80, 255, 160)
StatsStroke.Thickness = 1.2

local frameCounter = 0
local timeCounter = tick()

RunService.RenderStepped:Connect(function()
    frameCounter = frameCounter + 1
    if (tick() - timeCounter) >= 1 then
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        StatsLabel.Text = string.format("⚡ FPS: %d | Ping: %d ms\nParry: %s", 
            frameCounter, ping, AutoParryEnabled and "ACTIVE" or "OFF")
        if AutoParryEnabled then
            StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
            StatsStroke.Color = Color3.fromRGB(80, 255, 160)
        else
            StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            StatsStroke.Color = Color3.fromRGB(150, 150, 150)
        end
        frameCounter = 0
        timeCounter = tick()
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "⚡ Auto Parry (STRONGEST)",
    Desc = "Trajectory-based + Ultra-fast + Anti-curve",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballLocks = {}
            ballTracking = {}
        end
    end
})

MainTab:Toggle({
    Title = "Auto Accuracy",
    Desc = "Auto-adjust timing based on speed/distance/curve",
    Value = true,
    Callback = function(Value)
        UseAutoAccuracy = Value
    end
})

MainTab:Slider({
    Title = "Parry Accuracy",
    Desc = "100 = Very early | 1 = Perfect (used only when Auto Accuracy is OFF)",
    Value = {
        Min = 1,
        Max = 100,
        Default = 75,
    },
    Callback = function(Value)
        AccuracyValue = Value
    end
})

SettingsTab:Button({
    Title = "Reset Locks",
    Desc = "Clear ball locks if stuck",
    Callback = function()
        ballLocks = {}
        ballTracking = {}
    end
})

SettingsTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
        StatsGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v30.0 🔥",
    Content = "STRONGEST Auto Parry loaded - Trajectory + Adaptive",
    Duration = 6
})
