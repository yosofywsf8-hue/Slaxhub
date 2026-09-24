-- Blade Ball Script - Slax Hub v21.6 (MS Timing + Slash Pause)
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "Open Slax Hub",
    Icon = "sword",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 80, 255)),
    OnlyMobile = false,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamEnabled = false
local AutoSlashEnabled = false
local SlashesCounterEnabled = false
local AutoAccuracyEnabled = true
local AutoSpamCPS = 350

local PARRY_TIME_MS = 100

local GLOBAL_LOCK = 0.18
local ULTRA_FAST_LOCK = 0.06
local EMERGENCY_LOCK = 0.05
local BALL_LOCK_DURATION = 0.5
local MAX_PARRY_DISTANCE = 200
local SPAM_PROXIMITY_RANGE = 60

local CLOSE_RANGE_DISTANCE = 50
local VERY_CLOSE_DISTANCE = 25
local POINT_BLANK_DISTANCE = 12

local DANGER_ZONE_RANGE = 40
local DANGER_ZONE_CRITICAL = 20

local ULTRA_FAST_SPEED = 180
local FAST_SPEED = 100
local MANUAL_SPAM_BURST = 10

local SUDDEN_BALL_TTL = 0.15
local SUDDEN_TRACK_INTERVAL = 0.02
local knownBalls = {}

local SLASH_DISTANCE = 35
local SLASH_SPEED_THRESHOLD = 80
local SLASH_COOLDOWN = 1.5
local lastSlashTime = 0

local ParryPaused = false
local ParryPauseUntil = 0
local SLASH_PAUSE_DURATION = 1.2

local SlashCount = 0
local SlashAttempts = 0
local SlashFails = 0

local SLASH_COUNTER_RANGE = 50
local SLASH_COUNTER_COOLDOWN = 0.15
local SLASH_COUNTER_BURST = 8
local lastCounterTime = 0
local SlashCounterActive = false
local SlashCounterPlayer = nil
local SlashCounterCount = 0

-- =========================================
-- Token
-- =========================================
local _token = nil
for _, Function in getgc(true) do
    if type(Function) == 'function' and debug.info(Function, 's'):find('PRY', 1, true) then
        for _, value in debug.getupvalues(Function) do
            if type(value) == 'function' then
                _token = value
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(_remote_uid)
    if not _token then return "" end
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)
    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

-- =========================================
-- Hooking
-- =========================================
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
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
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

-- =========================================
-- Remotes
-- =========================================
local _parryRemote = nil
local _parryArgs = nil
local _abilityRemote = nil

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

local function GetAbilityRemote()
    if not _abilityRemote or not _abilityRemote.Parent then
        _abilityRemote = nil
        local remotesFolder = replicated_storage:FindFirstChild("Remotes")
        if remotesFolder then
            _abilityRemote = remotesFolder:FindFirstChild("AbilityButtonPress")
        end
        if not _abilityRemote then
            for _, remote in pairs(replicated_storage:GetDescendants()) do
                if remote:IsA('RemoteEvent') and remote.Name:lower():find("ability") then
                    _abilityRemote = remote
                    break
                end
            end
        end
    end
    return _abilityRemote
end

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    local packet = {
        args[1], args[2], _tokenize(args[2]), 0.5,
        workspace.CurrentCamera.CFrame, {}, {0, 0}, false
    }
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
end

local function FireAbility()
    local remote = GetAbilityRemote()
    if not remote then return false end
    if remote:IsA('RemoteEvent') then
        remote:FireServer()
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer()
    end
    return true
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- Slashes Detection
-- =========================================
local function DetectSlashesOfFury(playerPos)
    local closestAttacker = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local distance = (hrp.Position - playerPos).Magnitude
        if distance > SLASH_COUNTER_RANGE then continue end

        local isSlashing = false
        local attrs = {"IsSlashing", "SlashesOfFury", "AbilityActive", "IsAttacking", "UsingAbility", "FuryMode", "Slashing"}
        for _, attrName in ipairs(attrs) do
            if char:GetAttribute(attrName) == true or hrp:GetAttribute(attrName) == true or player:GetAttribute(attrName) == true then
                isSlashing = true
                break
            end
        end

        if not isSlashing then
            for _, child in pairs(char:GetChildren()) do
                if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Attachment") or child:IsA("ParticleEmitter") or child:IsA("Trail") then
                    local name = child.Name:lower()
                    if name:find("slash") or name:find("fury") or name:find("ability") then
                        isSlashing = true
                        break
                    end
                end
            end
        end

        if not isSlashing then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        local animName = ""
                        if track.Animation then animName = track.Animation.Name:lower() end
                        if animName:find("slash") or animName:find("fury") or animName:find("ability") or animName:find("attack") then
                            isSlashing = true
                            break
                        end
                    end
                end
            end
        end

        if isSlashing then
            if distance < closestDist then
                closestDist = distance
                closestAttacker = player
            end
        end
    end

    return closestAttacker, closestDist
end

-- =========================================
-- Danger Zone
-- =========================================
local DangerLevel = 0
local ClosestPlayerDist = math.huge

task.spawn(function()
    while task.wait(0.05) do
        if not AutoParryEnabled then
            DangerLevel = 0
            ClosestPlayerDist = math.huge
            continue
        end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local closest = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local p_hrp = char:FindFirstChild("HumanoidRootPart")
            if not p_hrp then continue end
            local d = (p_hrp.Position - playerPos).Magnitude
            if d < closest then closest = d end
        end

        ClosestPlayerDist = closest
        if closest <= DANGER_ZONE_CRITICAL then DangerLevel = 2
        elseif closest <= DANGER_ZONE_RANGE then DangerLevel = 1
        else DangerLevel = 0 end
    end
end)

-- =========================================
-- Anti Curve
-- =========================================
local ballTracking = {}

local function TrackBall(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return 0, false end

    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = { lastVel = vel, curveScore = 0, curveActive = false }
        return 0, false
    end

    local prevDir = data.lastVel.Unit
    local currDir = vel.Unit
    local dot = prevDir:Dot(currDir)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))

    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
    else
        data.curveScore = data.curveScore * 0.95
    end

    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel
    return data.curveScore, data.curveActive
end

task.spawn(function()
    while task.wait(2) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then ballTracking[ball] = nil end
        end
    end
end)

-- =========================================
-- Sudden Threat Tracker
-- =========================================
task.spawn(function()
    while task.wait(SUDDEN_TRACK_INTERVAL) do
        if not AutoParryEnabled then
            knownBalls = {}
            continue
        end

        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then
            knownBalls = {}
            continue
        end

        local now = tick()
        local currentBalls = {}
        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            currentBalls[ball] = true
            if not knownBalls[ball] then knownBalls[ball] = now end
        end
        for ball in pairs(knownBalls) do
            if not currentBalls[ball] then knownBalls[ball] = nil end
        end
    end
end)

-- =========================================
-- Auto Accuracy
-- =========================================
local AutoAccuracyDebug = { Value = 50, Reason = "Starting" }

local function GetAutoAccuracy(ballSpeed, curveActive, isClose, dangerLevel, distance)
    local pingMs = GetPing() * 1000
    local base = 50

    if pingMs < 30 then base = base - 5
    elseif pingMs < 60 then base = base
    elseif pingMs < 90 then base = base + 15
    elseif pingMs < 130 then base = base + 25
    else base = base + 35 end

    if ballSpeed > 250 then base = base + 40
    elseif ballSpeed > 200 then base = base + 32
    elseif ballSpeed > 150 then base = base + 24
    elseif ballSpeed > 120 then base = base + 18
    elseif ballSpeed > 90 then base = base + 12
    elseif ballSpeed > 60 then base = base + 6 end

    if curveActive then base = base + 12 end
    if isClose then base = base + 10 end
    if dangerLevel == 2 then base = base + 30
    elseif dangerLevel == 1 then base = base + 15 end

    if distance < POINT_BLANK_DISTANCE then base = base + 25
    elseif distance < VERY_CLOSE_DISTANCE then base = base + 18
    elseif distance < CLOSE_RANGE_DISTANCE then base = base + 10 end

    return math.clamp(math.floor(base), 1, 100)
end

local function GetParryTimeMs(usedAccuracy, dangerLevel, distance, ballSpeed)
    local baseMs
    if AutoAccuracyEnabled then
        baseMs = 50 + (usedAccuracy / 100) * 200
    else
        baseMs = PARRY_TIME_MS
    end

    if dangerLevel == 2 then baseMs = baseMs + 200
    elseif dangerLevel == 1 then baseMs = baseMs + 100 end

    if distance < POINT_BLANK_DISTANCE then baseMs = baseMs + 100
    elseif distance < VERY_CLOSE_DISTANCE then baseMs = baseMs + 60
    elseif distance < CLOSE_RANGE_DISTANCE then baseMs = baseMs + 30 end

    return baseMs
end

-- =========================================
-- Main Heartbeat
-- =========================================
local lastParryTime = 0
local lastEmergencyTime = 0
local ballLocks = {}
local ballNameLocks = {}

task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then ballLocks[ball] = nil end
        end
        for name, t in pairs(ballNameLocks) do
            if now >= t then ballNameLocks[name] = nil end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local now = tick()

    if ParryPaused then
        if now >= ParryPauseUntil then
            ParryPaused = false
        else
            -- متوقف لكن Counter يستمر
        end
    end

    if SlashesCounterEnabled then
        local character = LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local attacker, dist = DetectSlashesOfFury(hrp.Position)
                if attacker then
                    SlashCounterActive = true
                    SlashCounterPlayer = attacker.Name
                    if (now - lastCounterTime) >= SLASH_COUNTER_COOLDOWN then
                        lastCounterTime = now
                        SlashCounterCount = SlashCounterCount + 1
                        task.spawn(function()
                            for i = 1, SLASH_COUNTER_BURST do FireParry() end
                        end)
                    end
                else
                    SlashCounterActive = false
                    SlashCounterPlayer = nil
                end
            end
        end
    end

    if AutoSlashEnabled then
        if (now - lastSlashTime) >= SLASH_COOLDOWN then
            local character = LocalPlayer.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local playerPos = hrp.Position
                    local ballsFolder = workspace:FindFirstChild("Balls")
                    if ballsFolder then
                        for _, ball in ipairs(ballsFolder:GetChildren()) do
                            if not ball:IsA("BasePart") then continue end
                            if ball:GetAttribute("realBall") == false then continue end
                            local ballPos = ball.Position
                            local velocity = ball.AssemblyLinearVelocity
                            local speed = velocity.Magnitude
                            if speed < SLASH_SPEED_THRESHOLD then continue end
                            local distance = (playerPos - ballPos).Magnitude
                            if distance > SLASH_DISTANCE then continue end
                            local toPlayer = (playerPos - ballPos).Unit
                            local dot = velocity.Unit:Dot(toPlayer)
                            if dot <= 0.3 then continue end
                            SlashAttempts = SlashAttempts + 1
                            lastSlashTime = now
                            local success = FireAbility()
                            if success then
                                SlashCount = SlashCount + 1
                                ParryPaused = true
                                ParryPauseUntil = now + SLASH_PAUSE_DURATION
                            else
                                SlashFails = SlashFails + 1
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    if ParryPaused then return end
    if not AutoParryEnabled then
        ballLocks = {}
        ballNameLocks = {}
        return
    end

    local ping = GetPing()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end
    local balls = ballsFolder:GetChildren()

    -- PHASE -1: POINT BLANK
    if (now - lastEmergencyTime) >= EMERGENCY_LOCK then
        for i = 1, #balls do
            local ball = balls[i]
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] or ballNameLocks[ball.Name] then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local shouldFire = false

            if distance <= POINT_BLANK_DISTANCE and dot > 0.2 then shouldFire = true
            elseif distance <= VERY_CLOSE_DISTANCE and dot > 0.3 then shouldFire = true
            elseif distance <= CLOSE_RANGE_DISTANCE and dot > 0.4 and speed > 40 then shouldFire = true end

            if shouldFire then
                lastEmergencyTime = now
                lastParryTime = now
                ballLocks[ball] = now + BALL_LOCK_DURATION
                ballNameLocks[ball.Name] = now + BALL_LOCK_DURATION
                FireParry()
                return
            end
        end
    end

    -- PHASE 0: SUDDEN THREAT
    if (now - lastEmergencyTime) >= EMERGENCY_LOCK then
        for i = 1, #balls do
            local ball = balls[i]
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] or ballNameLocks[ball.Name] then continue end

            local firstSeen = knownBalls[ball]
            if not firstSeen then continue end
            if (now - firstSeen) > SUDDEN_BALL_TTL then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0 then continue end

            local distance = (playerPos - ballPos).Magnitude
            if distance < 80 and dot > 0.3 then
                lastEmergencyTime = now
                lastParryTime = now
                ballLocks[ball] = now + BALL_LOCK_DURATION
                ballNameLocks[ball.Name] = now + BALL_LOCK_DURATION
                FireParry()
                return
            end
        end
    end

    -- PHASE 1: ULTRA FAST
    if (now - lastEmergencyTime) >= EMERGENCY_LOCK then
        for i = 1, #balls do
            local ball = balls[i]
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] or ballNameLocks[ball.Name] then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local shouldFire = false

            if speed >= ULTRA_FAST_SPEED and distance < 120 and dot > 0.3 then shouldFire = true
            elseif speed >= FAST_SPEED and distance < 70 and dot > 0.3 then shouldFire = true end

            if shouldFire then
                lastEmergencyTime = now
                lastParryTime = now
                ballLocks[ball] = now + BALL_LOCK_DURATION
                ballNameLocks[ball.Name] = now + BALL_LOCK_DURATION
                FireParry()
                return
            end
        end
    end

    -- PHASE 2: NORMAL
    local currentLock = GLOBAL_LOCK
    if DangerLevel == 2 then currentLock = ULTRA_FAST_LOCK
    elseif DangerLevel == 1 then currentLock = 0.10 end

    if (now - lastParryTime) < currentLock then return end

    local bestBall = nil
    local bestTime = math.huge
    local bestSpeed = 0
    local bestDistance = math.huge
    local bestCurve = false

    for i = 1, #balls do
        local ball = balls[i]
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] or ballNameLocks[ball.Name] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0 then continue end

        local distance = (playerPos - ballPos).Magnitude
        if distance > MAX_PARRY_DISTANCE then continue end

        local targetAttr = ball:GetAttribute("target")
        local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
        if not isTarget then continue end

        local _, curveActive = TrackBall(ball)

        local frames = 1
        if distance < 30 then frames = 0
        elseif speed < 40 then frames = 4
        elseif speed < 80 then frames = 3
        elseif speed < 130 then frames = 2
        else frames = 0 end

        local predictedPos = ballPos + (velocity * (frames * (1/60)))
        local predictedDistance = (playerPos - predictedPos).Magnitude
        local timeToReach = predictedDistance / speed

        if timeToReach < bestTime then
            bestTime = timeToReach
            bestBall = ball
            bestSpeed = speed
            bestDistance = distance
            bestCurve = curveActive
        end
    end

    if bestBall then
        local usedAccuracy = 50
        if AutoAccuracyEnabled then
            usedAccuracy = GetAutoAccuracy(bestSpeed, bestCurve, DangerLevel >= 1, DangerLevel, bestDistance)
            AutoAccuracyDebug.Value = usedAccuracy
            AutoAccuracyDebug.Reason = string.format("P:%d S:%d D:%d", math.floor(ping * 1000), math.floor(bestSpeed), math.floor(bestDistance))
        end

        local windowMs = GetParryTimeMs(usedAccuracy, DangerLevel, bestDistance, bestSpeed)
        local timeWindow = ping + (windowMs / 1000)

        local emergencyRange = 20
        if DangerLevel == 2 then emergencyRange = 40
        elseif DangerLevel == 1 then emergencyRange = 30 end

        if bestDistance < POINT_BLANK_DISTANCE then emergencyRange = 50
        elseif bestDistance < VERY_CLOSE_DISTANCE then emergencyRange = 40
        elseif bestDistance < CLOSE_RANGE_DISTANCE then emergencyRange = 30 end

        if (bestTime <= timeWindow and bestTime >= -0.1) or bestDistance <= emergencyRange then
            lastParryTime = now
            ballLocks[bestBall] = now + BALL_LOCK_DURATION
            ballNameLocks[bestBall.Name] = now + BALL_LOCK_DURATION
            FireParry()
        end
    end
end)

-- =========================================
-- Auto Spam
-- =========================================
local lastSpamTime = 0
local spamPlayerCheck = 0
local nearPlayerSpam = false

RunService.Heartbeat:Connect(function()
    if not AutoSpamEnabled then return end
    local now = tick()

    if (now - spamPlayerCheck) > 0.05 then
        spamPlayerCheck = now
        nearPlayerSpam = false
        local character = LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local playerPos = hrp.Position
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local c = p.Character
                        if c then
                            local p_hrp = c:FindFirstChild("HumanoidRootPart")
                            if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SPAM_PROXIMITY_RANGE then
                                nearPlayerSpam = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if not nearPlayerSpam then return end
    if (now - lastSpamTime) < 0.016 then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    local burst = math.max(1, math.floor(AutoSpamCPS / 60))
    for _ = 1, burst do
        local packet = {args[1], args[2], _tokenize(args[2]), 0.5, workspace.CurrentCamera.CFrame, {}, {0, 0}, false}
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- Manual Spam
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

pcall(function()
    for _, gui in pairs(GetGuiParent():GetChildren()) do
        if gui.Name:find("SlaxManualSpam") then gui:Destroy() end
    end
end)

local ManualGui = Instance.new("ScreenGui")
ManualGui.Name = "SlaxManualSpam_" .. math.random(1, 99999)
ManualGui.Parent = GetGuiParent()
ManualGui.ResetOnSpawn = false
ManualGui.IgnoreGuiInset = true
ManualGui.DisplayOrder = 99999

local ManualBtn = Instance.new("TextButton")
ManualBtn.Name = "ManualSpamBtn"
ManualBtn.Parent = ManualGui
ManualBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
ManualBtn.BackgroundTransparency = 0.15
ManualBtn.BorderSizePixel = 0
ManualBtn.Position = UDim2.new(0.35, 0, 0.42, 0)
ManualBtn.Size = UDim2.new(0, 100, 0, 42)
ManualBtn.Font = Enum.Font.GothamBold
ManualBtn.Text = "SPAM: OFF"
ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
ManualBtn.TextSize = 13
ManualBtn.AutoButtonColor = false
ManualBtn.Active = true
ManualBtn.Selectable = true

local ManualCorner = Instance.new("UICorner")
ManualCorner.CornerRadius = UDim.new(0, 10)
ManualCorner.Parent = ManualBtn

local ManualStroke = Instance.new("UIStroke")
ManualStroke.Parent = ManualBtn
ManualStroke.Thickness = 1.5
ManualStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Parent = ManualStroke
StrokeGradient.Rotation = 45
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(230, 80, 230)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 90, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 100, 255))
})

local ManualGlow = Instance.new("UIStroke")
ManualGlow.Parent = ManualBtn
ManualGlow.Thickness = 4
ManualGlow.Transparency = 0.7
ManualGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local GlowGradient = Instance.new("UIGradient")
GlowGradient.Parent = ManualGlow
GlowGradient.Rotation = 45
GlowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(210, 100, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 110, 255))
})

local BgGradient = Instance.new("UIGradient")
BgGradient.Parent = ManualBtn
BgGradient.Rotation = 45
BgGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.00, 0.15),
    NumberSequenceKeypoint.new(0.50, 0.25),
    NumberSequenceKeypoint.new(1.00, 0.15)
})
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
})

local function UpdateManualBtnVisual()
    if ManualSpamEnabled then
        ManualBtn.Text = "SPAM: ON"
        ManualBtn.TextColor3 = Color3.fromRGB(80, 255, 180)
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
        })
    else
        ManualBtn.Text = "SPAM: OFF"
        ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
        })
    end
end

local dragging, dragStart, startPos, dragMoved
local lastTap = 0

ManualBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = ManualBtn.Position
    end
end)

ManualBtn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then dragMoved = true end
        ManualBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

ManualBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local function ToggleManualSpam()
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateManualBtnVisual()
    if ManualSpamEnabled then
        task.spawn(function()
            local remote, args = GetParryRemote()
            if not remote or not args then return end
            for _ = 1, 30 do
                local packet = {args[1], args[2], _tokenize(args[2]), 0.5, workspace.CurrentCamera.CFrame, {}, {0, 0}, false}
                if remote:IsA('RemoteEvent') then
                    remote:FireServer(unpack(packet))
                elseif remote:IsA('RemoteFunction') then
                    remote:InvokeServer(unpack(packet))
                end
            end
        end)
    end
end

ManualBtn.MouseButton1Click:Connect(function()
    if not dragMoved then
        local now = tick()
        if now - lastTap > 0.3 then
            lastTap = now
            ToggleManualSpam()
        end
    end
end)

ManualBtn.TouchTap:Connect(function()
    local now = tick()
    if now - lastTap > 0.3 then
        lastTap = now
        ToggleManualSpam()
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then ToggleManualSpam() end
end)

local lastManualSpamTime = 0
RunService.Heartbeat:Connect(function()
    if not ManualSpamEnabled then return end
    local now = tick()
    if (now - lastManualSpamTime) < 0.005 then return end
    lastManualSpamTime = now
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    for _ = 1, MANUAL_SPAM_BURST do
        local packet = {args[1], args[2], _tokenize(args[2]), 0.5, workspace.CurrentCamera.CFrame, {}, {0, 0}, false}
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- Slash Counter Alert
-- =========================================
local CounterGui = Instance.new("ScreenGui")
CounterGui.Name = "SlaxCounterAlert_" .. math.random(1, 99999)
CounterGui.Parent = GetGuiParent()
CounterGui.ResetOnSpawn = false
CounterGui.IgnoreGuiInset = true
CounterGui.DisplayOrder = 100000

local CounterAlert = Instance.new("TextLabel")
CounterAlert.Name = "CounterAlert"
CounterAlert.Parent = CounterGui
CounterAlert.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
CounterAlert.BackgroundTransparency = 0.2
CounterAlert.BorderSizePixel = 0
CounterAlert.Position = UDim2.new(0.5, -150, 0.15, 0)
CounterAlert.Size = UDim2.new(0, 300, 0, 50)
CounterAlert.Font = Enum.Font.GothamBold
CounterAlert.Text = "COUNTERED!"
CounterAlert.TextColor3 = Color3.fromRGB(255, 100, 100)
CounterAlert.TextSize = 16
CounterAlert.Visible = false

local CounterCorner = Instance.new("UICorner")
CounterCorner.CornerRadius = UDim.new(0, 12)
CounterCorner.Parent = CounterAlert

local CounterStroke = Instance.new("UIStroke")
CounterStroke.Parent = CounterAlert
CounterStroke.Color = Color3.fromRGB(255, 80, 80)
CounterStroke.Thickness = 2.5

task.spawn(function()
    while task.wait(0.1) do
        if SlashesCounterEnabled and SlashCounterActive and SlashCounterPlayer then
            CounterAlert.Visible = true
            CounterAlert.Text = string.format("COUNTERING %s!", SlashCounterPlayer)
        else
            CounterAlert.Visible = false
        end
    end
end)

-- =========================================
-- Slash Counter Display
-- =========================================
local SlashGui = Instance.new("ScreenGui")
SlashGui.Name = "SlaxSlashCounter_" .. math.random(1, 99999)
SlashGui.Parent = GetGuiParent()
SlashGui.ResetOnSpawn = false
SlashGui.IgnoreGuiInset = true
SlashGui.DisplayOrder = 99996

local SlashFrame = Instance.new("Frame")
SlashFrame.Name = "SlashFrame"
SlashFrame.Parent = SlashGui
SlashFrame.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
SlashFrame.BackgroundTransparency = 0.15
SlashFrame.BorderSizePixel = 0
SlashFrame.Position = UDim2.new(0.02, 0, 0.55, 0)
SlashFrame.Size = UDim2.new(0, 180, 0, 125)
SlashFrame.Active = true
SlashFrame.Draggable = true

local SlashCorner = Instance.new("UICorner")
SlashCorner.CornerRadius = UDim.new(0, 14)
SlashCorner.Parent = SlashFrame

local SlashStroke = Instance.new("UIStroke")
SlashStroke.Parent = SlashFrame
SlashStroke.Thickness = 2.5
SlashStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local SlashStrokeGradient = Instance.new("UIGradient")
SlashStrokeGradient.Parent = SlashStroke
SlashStrokeGradient.Rotation = 45
SlashStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 200, 80)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 120, 200)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(180, 100, 255))
})

local SlashTitle = Instance.new("TextLabel")
SlashTitle.Name = "Title"
SlashTitle.Parent = SlashFrame
SlashTitle.BackgroundTransparency = 1
SlashTitle.Position = UDim2.new(0, 0, 0, 6)
SlashTitle.Size = UDim2.new(1, 0, 0, 20)
SlashTitle.Font = Enum.Font.GothamBold
SlashTitle.Text = "SLASHES OF FURY"
SlashTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
SlashTitle.TextSize = 12

local SlashCountLabel = Instance.new("TextLabel")
SlashCountLabel.Name = "Count"
SlashCountLabel.Parent = SlashFrame
SlashCountLabel.BackgroundTransparency = 1
SlashCountLabel.Position = UDim2.new(0, 0, 0, 26)
SlashCountLabel.Size = UDim2.new(1, 0, 0, 26)
SlashCountLabel.Font = Enum.Font.GothamBold
SlashCountLabel.Text = "0"
SlashCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SlashCountLabel.TextSize = 22

local SlashStatusLabel = Instance.new("TextLabel")
SlashStatusLabel.Name = "Status"
SlashStatusLabel.Parent = SlashFrame
SlashStatusLabel.BackgroundTransparency = 1
SlashStatusLabel.Position = UDim2.new(0, 0, 0, 52)
SlashStatusLabel.Size = UDim2.new(1, 0, 0, 16)
SlashStatusLabel.Font = Enum.Font.Gotham
SlashStatusLabel.Text = "READY"
SlashStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
SlashStatusLabel.TextSize = 11

local PauseLabel = Instance.new("TextLabel")
PauseLabel.Name = "Pause"
PauseLabel.Parent = SlashFrame
PauseLabel.BackgroundTransparency = 1
PauseLabel.Position = UDim2.new(0, 0, 0, 68)
PauseLabel.Size = UDim2.new(1, 0, 0, 14)
PauseLabel.Font = Enum.Font.GothamBold
PauseLabel.Text = "PARRY: ACTIVE"
PauseLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
PauseLabel.TextSize = 10

local CounterTitle = Instance.new("TextLabel")
CounterTitle.Name = "CounterTitle"
CounterTitle.Parent = SlashFrame
CounterTitle.BackgroundTransparency = 1
CounterTitle.Position = UDim2.new(0, 0, 0, 84)
CounterTitle.Size = UDim2.new(1, 0, 0, 16)
CounterTitle.Font = Enum.Font.GothamBold
CounterTitle.Text = "COUNTERS"
CounterTitle.TextColor3 = Color3.fromRGB(120, 200, 255)
CounterTitle.TextSize = 11

local CounterCountLabel = Instance.new("TextLabel")
CounterCountLabel.Name = "CounterCount"
CounterCountLabel.Parent = SlashFrame
CounterCountLabel.BackgroundTransparency = 1
CounterCountLabel.Position = UDim2.new(0, 0, 0, 100)
CounterCountLabel.Size = UDim2.new(1, 0, 0, 20)
CounterCountLabel.Font = Enum.Font.GothamBold
CounterCountLabel.Text = "0"
CounterCountLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
CounterCountLabel.TextSize = 16

task.spawn(function()
    while task.wait(0.1) do
        if not AutoSlashEnabled then
            SlashStatusLabel.Text = "OFF"
            SlashStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        else
            local now = tick()
            local remaining = SLASH_COOLDOWN - (now - lastSlashTime)
            if remaining > 0 then
                SlashStatusLabel.Text = string.format("CD: %.1fs", remaining)
                SlashStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            else
                SlashStatusLabel.Text = "READY"
                SlashStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
            end
            SlashCountLabel.Text = tostring(SlashCount)
        end

        if ParryPaused then
            local remaining = ParryPauseUntil - tick()
            PauseLabel.Text = string.format("PAUSED %.1fs", remaining)
            PauseLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
        else
            PauseLabel.Text = "PARRY: ACTIVE"
            PauseLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        end

        CounterCountLabel.Text = tostring(SlashCounterCount)

        if not SlashesCounterEnabled then
            CounterTitle.TextColor3 = Color3.fromRGB(120, 120, 120)
            CounterCountLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
        else
            if SlashCounterActive then
                CounterTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
                CounterCountLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                CounterTitle.TextColor3 = Color3.fromRGB(120, 200, 255)
                CounterCountLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
            end
        end
    end
end)

-- =========================================
-- Accuracy Display
-- =========================================
local AccGui = Instance.new("ScreenGui")
AccGui.Name = "SlaxAccDisplay_" .. math.random(1, 99999)
AccGui.Parent = GetGuiParent()
AccGui.ResetOnSpawn = false
AccGui.IgnoreGuiInset = true
AccGui.DisplayOrder = 99998

local AccLabel = Instance.new("TextLabel")
AccLabel.Name = "AccLabel"
AccLabel.Parent = AccGui
AccLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
AccLabel.BackgroundTransparency = 0.3
AccLabel.BorderSizePixel = 0
AccLabel.Position = UDim2.new(0.68, 0, 0.02, 0)
AccLabel.Size = UDim2.new(0, 200, 0, 60)
AccLabel.Font = Enum.Font.GothamBold
AccLabel.Text = "Parry Time: 100ms"
AccLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
AccLabel.TextSize = 12

local AccCorner = Instance.new("UICorner")
AccCorner.CornerRadius = UDim.new(0, 10)
AccCorner.Parent = AccLabel

local AccStroke = Instance.new("UIStroke")
AccStroke.Parent = AccLabel
AccStroke.Color = Color3.fromRGB(255, 180, 230)
AccStroke.Thickness = 1.2

task.spawn(function()
    while task.wait(0.15) do
        if AutoParryEnabled and AutoAccuracyEnabled then
            local value = AutoAccuracyDebug.Value
            local color
            if value < 30 then color = Color3.fromRGB(100, 255, 100)
            elseif value < 60 then color = Color3.fromRGB(255, 220, 100)
            elseif value < 85 then color = Color3.fromRGB(255, 150, 100)
            else color = Color3.fromRGB(255, 100, 100) end
            AccLabel.Text = string.format("AUTO: %dms\n%s", PARRY_TIME_MS, AutoAccuracyDebug.Reason)
            AccLabel.TextColor3 = color
            AccStroke.Color = color
        elseif AutoParryEnabled then
            AccLabel.Text = string.format("MANUAL: %dms", PARRY_TIME_MS)
            AccLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
            AccStroke.Color = Color3.fromRGB(255, 200, 80)
        else
            AccLabel.Text = "Parry: OFF"
            AccLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            AccStroke.Color = Color3.fromRGB(150, 150, 150)
        end
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "Auto Parry (Close Range Fix)",
    Desc = "Strong at close & far range",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballTracking = {}
            ballLocks = {}
            ballNameLocks = {}
            knownBalls = {}
        end
    end
})

MainTab:Toggle({
    Title = "Auto Accuracy",
    Desc = "Auto-adjust timing",
    Value = true,
    Callback = function(Value)
        AutoAccuracyEnabled = Value
    end
})

MainTab:Slider({
    Title = "Parry Time (ms)",
    Desc = "Used when Auto Accuracy is OFF - 100ms recommended",
    Value = {
        Min = 30,
        Max = 300,
        Default = 100,
    },
    Callback = function(Value)
        PARRY_TIME_MS = Value
    end
})

MainTab:Toggle({
    Title = "Slashes of Fury Counter",
    Desc = "Counters enemy Slashes of Fury",
    Value = false,
    Callback = function(Value)
        SlashesCounterEnabled = Value
        SlashCounterCount = 0
    end
})

MainTab:Toggle({
    Title = "Auto Slashes of Fury",
    Desc = "Auto-cast + pauses Parry 1.2s",
    Value = false,
    Callback = function(Value)
        AutoSlashEnabled = Value
        lastSlashTime = 0
    end
})

MainTab:Button({
    Title = "Reset Counters",
    Desc = "Reset all counters",
    Callback = function()
        SlashCount = 0
        SlashAttempts = 0
        SlashFails = 0
        SlashCounterCount = 0
    end
})

MainTab:Toggle({
    Title = "Auto Spam",
    Desc = "Spams near players (60 studs)",
    Value = false,
    Callback = function(Value)
        AutoSpamEnabled = Value
    end
})

MainTab:Slider({
    Title = "Auto Spam CPS",
    Desc = "200-500 CPS",
    Value = {
        Min = 200,
        Max = 500,
        Default = 350,
    },
    Callback = function(Value)
        AutoSpamCPS = Value
    end
})

SettingsTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
        ManualGui:Destroy()
        AccGui:Destroy()
        SlashGui:Destroy()
        CounterGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v21.6",
    Content = "MS Timing + Slash Pause loaded",
    Duration = 6
})
