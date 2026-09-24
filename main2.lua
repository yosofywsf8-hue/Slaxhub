-- ═══════════════════════════════════════════════════════════════════════
--   ███████╗██╗      █████╗ ██╗  ██╗    ██╗  ██╗██╗   ██╗██████╗ 
--   ██╔════╝██║     ██╔══██╗╚██╗██╔╝    ██║  ██║██║   ██║██╔══██╗
--   ███████╗██║     ███████║ ╚███╔╝     ███████║██║   ██║██████╔╝
--   ╚════██║██║     ██╔══██║ ██╔██╗     ██╔══██║██║   ██║██╔══██╗
--   ███████║███████╗██║  ██║██╔╝ ██╗    ██║  ██║╚██████╔╝██████╔╝
--   ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
--
--   Slax Hub v50.0 - ULTIMATE EDITION
--   Blade Ball Premium Script
--   Developed by yossef
--   Total Features: 100+
-- ═══════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 1: SERVICES & SETUP
-- ═══════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

print("[Slax Hub] Initializing v50.0 Ultimate Edition...")

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 2: UI LIBRARY
-- ═══════════════════════════════════════════════════════════════════════

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef | ULTIMATE v50.0",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(720, 540),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 190,
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

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 3: TABS
-- ═══════════════════════════════════════════════════════════════════════

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SpamTab = Window:Tab({ Title = "Spam", Icon = "zap" })
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
local PlayerTab = Window:Tab({ Title = "Players", Icon = "users" })
local MovementTab = Window:Tab({ Title = "Movement", Icon = "move" })
local OptimizeTab = Window:Tab({ Title = "Optimize", Icon = "gauge" })
local SoundTab = Window:Tab({ Title = "Sound", Icon = "volume-2" })
local LogsTab = Window:Tab({ Title = "Logs", Icon = "scroll-text" })
local ConfigTab = Window:Tab({ Title = "Config", Icon = "save" })
local CreditsTab = Window:Tab({ Title = "Credits", Icon = "heart" })

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 4: STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════

local State = {
    -- Auto Parry
    AutoParryEnabled = false,
    ParryDistance = 25,
    PingCompensation = 1.5,
    SafetyBuffer = 8,
    AutoAccuracy = true,
    ParryCooldown = 0.05,
    TrajectoryCheck = true,
    MinDotProduct = 0.2,
    SmartLock = true,
    
    -- Auto Spam
    AutoSpamEnabled = false,
    SpamCPS = 350,
    SpamProximityRange = 60,
    SpamMode = "Proximity",  -- Proximity, Always, Manual
    SpamOnlyNear = true,
    
    -- Manual Spam
    ManualSpamEnabled = false,
    ManualSpamBurst = 10,
    
    -- Ball Tracking
    ShowBallInfo = false,
    ShowClosestBall = false,
    ShowBallTrail = false,
    BallESPEnabled = false,
    
    -- Player Tracking
    PlayerESP = false,
    ShowPlayerNames = false,
    ShowPlayerHealth = false,
    ShowPlayerDistance = false,
    PlayerESPRange = 200,
    
    -- Visuals
    ShowStats = true,
    ShowParryIndicator = false,
    ShowDistanceIndicator = false,
    ShowCrosshair = false,
    ShowFPS = true,
    ShowPing = true,
    UITheme = "Dark",
    
    -- Movement
    SpeedBoost = false,
    SpeedValue = 16,
    JumpBoost = false,
    JumpValue = 50,
    InfiniteJump = false,
    FlyMode = false,
    FlySpeed = 50,
    
    -- Optimizations
    FPSBoost = false,
    DisableFog = false,
    DisableShadows = false,
    ReduceParticles = false,
    LowQualityMode = false,
    DisableWeather = false,
    
    -- Sound
    SoundEnabled = true,
    ParrySound = true,
    SpamSound = false,
    Volume = 0.5,
    
    -- Logs
    LogEnabled = true,
    MaxLogs = 50,
}

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 5: LOGGING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local Logs = {}
local LogListeners = {}

local function AddLog(message, logType)
    logType = logType or "INFO"
    local entry = {
        message = message,
        type = logType,
        time = os.date("%H:%M:%S"),
    }
    table.insert(Logs, entry)
    if #Logs > State.MaxLogs then
        table.remove(Logs, 1)
    end
    print(string.format("[Slax Hub][%s] %s", logType, message))
    for _, listener in ipairs(LogListeners) do
        pcall(listener, entry)
    end
end

AddLog("Script initialized", "INFO")
AddLog("Loading Bypass...", "INFO")

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 6: BYPASS - TOKEN RETRIEVAL
-- ═══════════════════════════════════════════════════════════════════════

local _token = nil
local tokenAttempts = 0

for _, f in getgc(true) do
    if type(f) == 'function' and debug.info(f, 's'):find('PRY', 1, true) then
        for _, v in debug.getupvalues(f) do
            if type(v) == 'function' then
                _token = v
                tokenAttempts = tokenAttempts + 1
                break
            end
        end
        if _token then break end
    end
end

if _token then
    AddLog("Token bypass loaded successfully", "SUCCESS")
else
    AddLog("Token bypass FAILED - Auto Parry might not work!", "ERROR")
end

local function _tokenize(uid)
    if not _token then return "" end
    local t = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
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

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 7: REMOTE HOOKING
-- ═══════════════════════════════════════════════════════════════════════

AddLog("Hooking remotes...", "INFO")

local _reverted = {}
local _original = {}
local hookedCount = 0

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
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)
        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent')) 
                or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _args = {...}
                    if _is_valid(_args) and not _reverted[self] then
                        _reverted[self] = _args
                        hookedCount = hookedCount + 1
                    end
                    return _old(self, key)(_, unpack(_args))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, r in pairs(ReplicatedStorage:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

AddLog(string.format("Hooked %d remote events", hookedCount), "SUCCESS")

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 8: FIRE PARRY (CACHED)
-- ═══════════════════════════════════════════════════════════════════════

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
    if not remote or not args then 
        return false
    end
    
    local packet = {
        args[1], 
        args[2], 
        _tokenize(args[2]), 
        0.5,
        Workspace.CurrentCamera.CFrame, 
        {}, 
        {0, 0}, 
        false
    }
    
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 9: PING & UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

local PingCache = { value = 0.05, lastUpdate = 0 }

local function GetPing()
    local now = tick()
    if (now - PingCache.lastUpdate) > 0.5 then
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        PingCache.value = math.clamp(ping, 0.02, 0.4)
        PingCache.lastUpdate = now
    end
    return PingCache.value
end

local function GetPingMs()
    return math.floor(GetPing() * 1000)
end

local function GetBallFolder()
    return Workspace:FindFirstChild("Balls")
end

local function GetPlayerPosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position
end

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function GetHumanoidRootPart()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 10: TRAJECTORY HELPERS
-- ═══════════════════════════════════════════════════════════════════════

local function CalculateTrajectoryHit(ballPos, ballVel, playerPos, hitRadius)
    hitRadius = hitRadius or 8
    
    local speed = ballVel.Magnitude
    if speed < 3 then return false, 999, 999 end
    
    local relPos = playerPos - ballPos
    local dir = ballVel.Unit
    
    local dot = dir:Dot(relPos.Unit)
    if dot <= State.MinDotProduct then
        return false, 999, 999
    end
    
    local projection = relPos:Dot(dir)
    if projection <= 0 then
        return false, 999, 999
    end
    
    local closestPoint = ballPos + (dir * projection)
    local missDistance = (playerPos - closestPoint).Magnitude
    
    if missDistance > hitRadius then
        return false, 999, missDistance
    end
    
    local timeToImpact = projection / speed
    return true, timeToImpact, missDistance
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 11: BALL TRACKING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local ballTracking = {}

local function TrackBall(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return false, 0 end
    
    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = {
            lastVel = vel,
            lastPos = ball.Position,
            curveScore = 0,
            curveActive = false,
            changes = 0,
            firstSeen = tick(),
        }
        return false, 0
    end
    
    local dot = data.lastVel.Unit:Dot(vel.Unit)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))
    
    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
        data.changes = data.changes + 1
    else
        data.curveScore = data.curveScore * 0.9
    end
    
    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel
    data.lastPos = ball.Position
    
    return data.curveActive, data.curveScore
end

task.spawn(function()
    while task.wait(1) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then
                ballTracking[ball] = nil
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 12: AUTO PARRY LOOP
-- ═══════════════════════════════════════════════════════════════════════

AddLog("Setting up Auto Parry...", "INFO")

local lastParryTime = 0
local ballLocks = {}
local ParryCount = 0
local LastParryInfo = {
    distance = 0,
    speed = 0,
    trigger = 0,
    ping = 0,
    curve = false,
}

task.spawn(function()
    while task.wait(0.3) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then
                ballLocks[ball] = nil
            end
        end
    end
end)

local function CalculateTriggerDistance(speed, ping)
    local base = State.ParryDistance
    local pingDist = ping * speed * State.PingCompensation
    local speedBonus = 0
    
    if State.AutoAccuracy then
        if speed > 250 then speedBonus = 15
        elseif speed > 200 then speedBonus = 12
        elseif speed > 150 then speedBonus = 8
        elseif speed > 100 then speedBonus = 4
        end
    end
    
    return base + pingDist + State.SafetyBuffer + speedBonus
end

RunService.Heartbeat:Connect(function()
    if not State.AutoParryEnabled then
        if next(ballLocks) then ballLocks = {} end
        return
    end
    
    local now = tick()
    if (now - lastParryTime) < State.ParryCooldown then return end
    
    local playerPos = GetPlayerPosition()
    if not playerPos then return end
    
    local ballsFolder = GetBallFolder()
    if not ballsFolder then return end
    
    local ping = GetPing()
    local bestBall = nil
    local bestDistance = math.huge
    local bestSpeed = 0
    local bestTrigger = 0
    local bestCurve = false
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end
        
        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 5 then continue end
        
        -- Trajectory check
        if State.TrajectoryCheck then
            local willHit = CalculateTrajectoryHit(ballPos, velocity, playerPos)
            if not willHit then continue end
        else
            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= State.MinDotProduct then continue end
        end
        
        local distance = (playerPos - ballPos).Magnitude
        local triggerDist = CalculateTriggerDistance(speed, ping)
        
        if distance <= triggerDist then
            if distance < bestDistance then
                bestDistance = distance
                bestBall = ball
                bestSpeed = speed
                bestTrigger = triggerDist
                bestCurve = TrackBall(ball)
            end
        end
    end
    
    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + 0.5
        FireParry()
        ParryCount = ParryCount + 1
        
        LastParryInfo.distance = bestDistance
        LastParryInfo.speed = bestSpeed
        LastParryInfo.trigger = bestTrigger
        LastParryInfo.ping = GetPingMs()
        LastParryInfo.curve = bestCurve
        
        if State.ShowParryIndicator then
            -- Flash effect
        end
    end
end)

AddLog("Auto Parry ready", "SUCCESS")

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 13: AUTO SPAM LOOP
-- ═══════════════════════════════════════════════════════════════════════

AddLog("Setting up Auto Spam...", "INFO")

local lastSpamTime = 0
local SpamCount = 0

RunService.Heartbeat:Connect(function()
    if not State.AutoSpamEnabled then return end
    
    local now = tick()
    local character = GetCharacter()
    if not character then return end
    
    local hrp = GetHumanoidRootPart()
    if not hrp then return end
    
    local playerPos = hrp.Position
    local shouldSpam = false
    
    if State.SpamMode == "Always" then
        shouldSpam = true
    elseif State.SpamMode == "Proximity" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local c = p.Character
                if c then
                    local p_hrp = c:FindFirstChild("HumanoidRootPart")
                    if p_hrp and (p_hrp.Position - playerPos).Magnitude <= State.SpamProximityRange then
                        shouldSpam = true
                        break
                    end
                end
            end
        end
    end
    
    if not shouldSpam then return end
    
    local interval = 1 / math.max(State.SpamCPS, 1)
    if (now - lastSpamTime) < interval then return end
    lastSpamTime = now
    
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    
    local burst = math.max(1, math.floor(State.SpamCPS / 60))
    for _ = 1, burst do
        local packet = {
            args[1], args[2], _tokenize(args[2]), 0.5,
            Workspace.CurrentCamera.CFrame, {}, {0, 0}, false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
        SpamCount = SpamCount + 1
    end
end)

AddLog("Auto Spam ready", "SUCCESS")

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 14: MANUAL SPAM LOOP
-- ═══════════════════════════════════════════════════════════════════════

local lastManualSpamTime = 0

RunService.Heartbeat:Connect(function()
    if not State.ManualSpamEnabled then return end
    
    local now = tick()
    if (now - lastManualSpamTime) < 0.005 then return end
    lastManualSpamTime = now
    
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    
    for _ = 1, State.ManualSpamBurst do
        local packet = {
            args[1], args[2], _tokenize(args[2]), 0.5,
            Workspace.CurrentCamera.CFrame, {}, {0, 0}, false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 15: BALL ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local BallESP = {}

local function CreateBallHighlight(ball)
    if BallESP[ball] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "SlaxBallHighlight"
    highlight.Parent = ball
    highlight.FillColor = Color3.fromRGB(255, 100, 100)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    BallESP[ball] = highlight
end

local function RemoveBallHighlight(ball)
    if BallESP[ball] then
        BallESP[ball]:Destroy()
        BallESP[ball] = nil
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if State.BallESPEnabled then
            local ballsFolder = GetBallFolder()
            if ballsFolder then
                for _, ball in ipairs(ballsFolder:GetChildren()) do
                    if ball:IsA("BasePart") and ball:GetAttribute("realBall") ~= false then
                        CreateBallHighlight(ball)
                    end
                end
            end
        else
            for ball, hl in pairs(BallESP) do
                if hl then hl:Destroy() end
            end
            BallESP = {}
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 16: PLAYER ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local PlayerESP = {}
local PlayerBillboards = {}

local function CreatePlayerESP(player)
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if PlayerESP[player] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "SlaxPlayerHighlight"
    highlight.Parent = char
    highlight.FillColor = Color3.fromRGB(100, 200, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(50, 150, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    PlayerESP[player] = highlight
    
    -- Billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SlaxPlayerBillboard"
    billboard.Parent = hrp
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Parent = billboard
    nameLabel.BackgroundTransparency = 0.5
    nameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.TextStrokeTransparency = 0.5
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Parent = billboard
    infoLabel.BackgroundTransparency = 0.5
    infoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "Loading..."
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 11
    infoLabel.TextStrokeTransparency = 0.5
    
    PlayerBillboards[player] = billboard
end

local function RemovePlayerESP(player)
    if PlayerESP[player] then
        PlayerESP[player]:Destroy()
        PlayerESP[player] = nil
    end
    if PlayerBillboards[player] then
        PlayerBillboards[player]:Destroy()
        PlayerBillboards[player] = nil
    end
end

task.spawn(function()
    while task.wait(0.2) do
        if State.PlayerESP then
            local myPos = GetPlayerPosition()
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char then
                        if not PlayerESP[player] then
                            CreatePlayerESP(player)
                        end
                        
                        -- Update info
                        if PlayerBillboards[player] then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp and myPos then
                                local dist = (hrp.Position - myPos).Magnitude
                                if dist > State.PlayerESPRange then
                                    PlayerBillboards[player].Enabled = false
                                    if PlayerESP[player] then PlayerESP[player].Enabled = false end
                                else
                                    PlayerBillboards[player].Enabled = true
                                    if PlayerESP[player] then PlayerESP[player].Enabled = true end
                                    
                                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                                    local healthText = ""
                                    if humanoid and State.ShowPlayerHealth then
                                        healthText = string.format(" | ❤️ %d", math.floor(humanoid.Health))
                                    end
                                    
                                    local infoLabel = PlayerBillboards[player]:FindFirstChild("Info")
                                    if infoLabel then
                                        infoLabel.Text = string.format("📏 %d studs%s", math.floor(dist), healthText)
                                    end
                                end
                            end
                        end
                    else
                        RemovePlayerESP(player)
                    end
                end
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                RemovePlayerESP(player)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 17: MOVEMENT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local function SetWalkSpeed(speed)
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

local function SetJumpPower(power)
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.JumpPower = power
        humanoid.UseJumpPower = true
    end
end

-- Speed Boost
task.spawn(function()
    while task.wait(0.1) do
        if State.SpeedBoost then
            SetWalkSpeed(State.SpeedValue)
        end
    end
end)

-- Jump Boost
task.spawn(function()
    while task.wait(0.1) do
        if State.JumpBoost then
            SetJumpPower(State.JumpValue)
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Fly System
local flyConnection = nil
local flyBodyVelocity = nil
local flyBodyGyro = nil

local function StartFly()
    local hrp = GetHumanoidRootPart()
    if not hrp then return end
    
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = hrp
    
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyGyro.P = 1000
    flyBodyGyro.Parent = hrp
    
    flyConnection = RunService.Heartbeat:Connect(function()
        if not State.FlyMode then return end
        
        local moveDir = Vector3.new(0, 0, 0)
        local camera = Workspace.CurrentCamera
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        
        if moveDir.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDir.Unit * State.FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        
        flyBodyGyro.CFrame = camera.CFrame
    end)
end

local function StopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 18: OPTIMIZATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local function ApplyFPSBoost()
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") 
                or obj:IsA("Trail") 
                or obj:IsA("Smoke") 
                or obj:IsA("Fire") 
                or obj:IsA("Sparkles") 
                or obj:IsA("Beam") then
                obj.Enabled = false
            end
        end
    end)
end

local function RestoreFPS()
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") 
                or obj:IsA("Trail") 
                or obj:IsA("Smoke") 
                or obj:IsA("Fire") 
                or obj:IsA("Sparkles") 
                or obj:IsA("Beam") then
                obj.Enabled = true
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 19: SOUND SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

local function PlayParrySound()
    if not State.SoundEnabled or not State.ParrySound then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9114378328"
        sound.Volume = State.Volume
        sound.Parent = SoundService
        sound:Play()
        Debris:AddItem(sound, 2)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 20: GUI PARENT HELPER
-- ═══════════════════════════════════════════════════════════════════════

local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() 
        return LocalPlayer:WaitForChild("PlayerGui", 5) 
    end)
    if ok2 and pg then return pg end
    return CoreGui
end

pcall(function()
    for _, gui in pairs(GetGuiParent():GetChildren()) do
        if gui.Name:find("Slax") then
            gui:Destroy()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 21: STATS UI
-- ═══════════════════════════════════════════════════════════════════════

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "SlaxStats_" .. math.random(1, 99999)
StatsGui.Parent = GetGuiParent()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 99999

local StatsFrame = Instance.new("Frame")
StatsFrame.Parent = StatsGui
StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
StatsFrame.BackgroundTransparency = 0.25
StatsFrame.BorderSizePixel = 0
StatsFrame.Position = UDim2.new(0.62, 0, 0.02, 0)
StatsFrame.Size = UDim2.new(0, 280, 0, 90)
StatsFrame.Active = true
StatsFrame.Draggable = true

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 10)
StatsCorner.Parent = StatsFrame

local StatsStroke = Instance.new("UIStroke")
StatsStroke.Parent = StatsFrame
StatsStroke.Color = Color3.fromRGB(80, 255, 160)
StatsStroke.Thickness = 1.5

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Parent = StatsFrame
StatsLabel.BackgroundTransparency = 1
StatsLabel.Position = UDim2.new(0, 8, 0, 6)
StatsLabel.Size = UDim2.new(1, -16, 1, -12)
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.Text = "Slax Hub v50.0"
StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
StatsLabel.TextSize = 11
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top

local frames = 0
local lastFpsTime = tick()

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if (tick() - lastFpsTime) >= 1 then
        if State.ShowStats then
            local status = State.AutoParryEnabled and "ON" or "OFF"
            StatsLabel.Text = string.format(
                "⚡ Slax Hub v50.0 ULTIMATE\nFPS: %d | Ping: %d ms | Parry: %s\n🎯 dist: %d | spd: %d | trig: %d\n✅ Parries: %d | Spams: %d",
                frames, GetPingMs(), status,
                math.floor(LastParryInfo.distance),
                math.floor(LastParryInfo.speed),
                math.floor(LastParryInfo.trigger),
                ParryCount, SpamCount
            )
            StatsFrame.Visible = true
        else
            StatsFrame.Visible = false
        end
        
        if State.AutoParryEnabled then
            StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
            StatsStroke.Color = Color3.fromRGB(80, 255, 160)
        else
            StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            StatsStroke.Color = Color3.fromRGB(150, 150, 150)
        end
        
        frames = 0
        lastFpsTime = tick()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 22: BALL INFO UI
-- ═══════════════════════════════════════════════════════════════════════

local BallGui = Instance.new("ScreenGui")
BallGui.Name = "SlaxBall_" .. math.random(1, 99999)
BallGui.Parent = GetGuiParent()
BallGui.ResetOnSpawn = false
BallGui.IgnoreGuiInset = true
BallGui.DisplayOrder = 99998

local BallFrame = Instance.new("Frame")
BallFrame.Parent = BallGui
BallFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
BallFrame.BackgroundTransparency = 0.25
BallFrame.BorderSizePixel = 0
BallFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
BallFrame.Size = UDim2.new(0, 240, 0, 80)
BallFrame.Active = true
BallFrame.Draggable = true
BallFrame.Visible = false

local BallCorner = Instance.new("UICorner")
BallCorner.CornerRadius = UDim.new(0, 10)
BallCorner.Parent = BallFrame

local BallStroke = Instance.new("UIStroke")
BallStroke.Parent = BallFrame
BallStroke.Color = Color3.fromRGB(255, 180, 230)
BallStroke.Thickness = 1.5

local BallLabel = Instance.new("TextLabel")
BallLabel.Parent = BallFrame
BallLabel.BackgroundTransparency = 1
BallLabel.Position = UDim2.new(0, 8, 0, 6)
BallLabel.Size = UDim2.new(1, -16, 1, -12)
BallLabel.Font = Enum.Font.GothamBold
BallLabel.Text = "Ball Info"
BallLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
BallLabel.TextSize = 11
BallLabel.TextXAlignment = Enum.TextXAlignment.Left
BallLabel.TextYAlignment = Enum.TextYAlignment.Top

task.spawn(function()
    while task.wait(0.2) do
        BallFrame.Visible = State.ShowBallInfo
        
        if State.ShowBallInfo then
            local ballsFolder = GetBallFolder()
            local count = 0
            local closest = math.huge
            local closestSpeed = 0
            local closestTarget = "None"
            
            if ballsFolder then
                local playerPos = GetPlayerPosition()
                for _, ball in ipairs(ballsFolder:GetChildren()) do
                    if not ball:IsA("BasePart") then continue end
                    if ball:GetAttribute("realBall") == false then continue end
                    count = count + 1
                    if playerPos then
                        local d = (playerPos - ball.Position).Magnitude
                        if d < closest then
                            closest = d
                            closestSpeed = ball.AssemblyLinearVelocity.Magnitude
                            local target = ball:GetAttribute("target")
                            if target then
                                closestTarget = tostring(target)
                            end
                        end
                    end
                end
            end
            
            if count > 0 then
                BallLabel.Text = string.format(
                    "🎯 Balls: %d\n📍 Closest: %d studs\n⚡ Speed: %d\n👤 Target: %s",
                    count, math.floor(closest), math.floor(closestSpeed), closestTarget
                )
            else
                BallLabel.Text = "🎯 No Balls"
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 23: MANUAL SPAM BUTTON
-- ═══════════════════════════════════════════════════════════════════════

local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpam_" .. math.random(1, 99999)
SpamGui.Parent = GetGuiParent()
SpamGui.ResetOnSpawn = false
SpamGui.IgnoreGuiInset = true
SpamGui.DisplayOrder = 99997

local SpamBtn = Instance.new("TextButton")
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
SpamBtn.BorderSizePixel = 0
SpamBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
SpamBtn.Size = UDim2.new(0, 140, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "🎯 Spam: OFF"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 15
SpamBtn.AutoButtonColor = false
SpamBtn.Active = true

local SpamCorner = Instance.new("UICorner")
SpamCorner.CornerRadius = UDim.new(0, 10)
SpamCorner.Parent = SpamBtn

local SpamStroke = Instance.new("UIStroke")
SpamStroke.Parent = SpamBtn
SpamStroke.Color = Color3.fromRGB(255, 255, 255)
SpamStroke.Thickness = 1.5
SpamStroke.Transparency = 0.3

local dragging = false
local dragInput, dragStart, startPos, dragMoved
local lastTap = 0

SpamBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = SpamBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

SpamBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement 
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            dragMoved = true
        end
        SpamBtn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

local function UpdateSpamBtn()
    if State.ManualSpamEnabled then
        SpamBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        SpamBtn.Text = "🎯 Spam: ON"
        SpamStroke.Color = Color3.fromRGB(180, 255, 200)
    else
        SpamBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        SpamBtn.Text = "🎯 Spam: OFF"
        SpamStroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

SpamBtn.MouseButton1Click:Connect(function()
    if dragMoved then return end
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    State.ManualSpamEnabled = not State.ManualSpamEnabled
    UpdateSpamBtn()
end)

SpamBtn.TouchTap:Connect(function()
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    State.ManualSpamEnabled = not State.ManualSpamEnabled
    UpdateSpamBtn()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        State.ManualSpamEnabled = not State.ManualSpamEnabled
        UpdateSpamBtn()
    end
end)

UpdateSpamBtn()

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 24: MAIN TAB UI
-- ═══════════════════════════════════════════════════════════════════════

AddLog("Building UI...", "INFO")

MainTab:Toggle({
    Title = "⚡ Auto Parry (Ping Adaptive)",
    Desc = "Fires earlier based on your ping to compensate lag",
    Value = false,
    Callback = function(Value)
        State.AutoParryEnabled = Value
        AddLog("Auto Parry: " .. (Value and "ON" or "OFF"), "INFO")
        if not Value then ballLocks = {} end
    end
})

MainTab:Slider({
    Title = "Base Distance (studs)",
    Desc = "Base trigger distance",
    Value = { Min = 5, Max = 100, Default = 25 },
    Callback = function(Value) State.ParryDistance = Value end
})

MainTab:Slider({
    Title = "Ping Compensation",
    Desc = "Multiplier for ping-based early fire (higher = earlier)",
    Value = { Min = 0, Max = 300, Default = 150 },
    Callback = function(Value) State.PingCompensation = Value / 100 end
})

MainTab:Slider({
    Title = "Safety Buffer (studs)",
    Desc = "Extra distance for safety",
    Value = { Min = 0, Max = 30, Default = 8 },
    Callback = function(Value) State.SafetyBuffer = Value end
})

MainTab:Slider({
    Title = "Parry Cooldown (ms)",
    Desc = "Min time between parries",
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(Value) State.ParryCooldown = Value / 1000 end
})

MainTab:Toggle({
    Title = "🎯 Auto Accuracy",
    Desc = "Auto-adjust distance based on ball speed",
    Value = true,
    Callback = function(Value) State.AutoAccuracy = Value end
})

MainTab:Toggle({
    Title = "📐 Trajectory Check",
    Desc = "Only parry balls that will hit you",
    Value = true,
    Callback = function(Value) State.TrajectoryCheck = Value end
})

MainTab:Slider({
    Title = "Min Dot Product",
    Desc = "How much ball must aim at you (0-100)",
    Value = { Min = 0, Max = 80, Default = 20 },
    Callback = function(Value) State.MinDotProduct = Value / 100 end
})

MainTab:Toggle({
    Title = "🔒 Smart Lock",
    Desc = "Prevent double parries",
    Value = true,
    Callback = function(Value) State.SmartLock = Value end
})

MainTab:Button({
    Title = "🔄 Reset Ball Locks",
    Desc = "Clear stuck ball locks",
    Callback = function()
        ballLocks = {}
        AddLog("Ball locks reset", "INFO")
    end
})

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 25: SPAM TAB UI
-- ═══════════════════════════════════════════════════════════════════════

SpamTab:Toggle({
    Title = "⚡ Auto Spam",
    Desc = "Auto spam enabled",
    Value = false,
    Callback = function(Value)
        State.AutoSpamEnabled = Value
        AddLog("Auto Spam: " .. (Value and "ON" or "OFF"), "INFO")
    end
})

SpamTab:Dropdown({
    Title = "Spam Mode",
    Values = { "Proximity", "Always" },
    Value = "Proximity",
    Callback = function(Value) State.SpamMode = Value end
})

SpamTab:Slider({
    Title = "Spam Proximity Range (studs)",
    Desc = "Distance to trigger auto spam",
    Value = { Min = 20, Max = 150, Default = 60 },
    Callback = function(Value) State.SpamProximityRange = Value end
})

SpamTab:Slider({
    Title = "CPS (Clicks Per Second)",
    Desc = "Spam rate - higher = more clicks",
    Value = { Min = 50, Max = 500, Default = 350 },
    Callback = function(Value) State.SpamCPS = Value end
})

SpamTab:Slider({
    Title = "Manual Burst Size",
    Desc = "Shots per burst on manual spam",
    Value = { Min = 1, Max = 30, Default = 10 },
    Callback = function(Value) State.ManualSpamBurst = Value end
})

SpamTab:Button({
    Title = "🔄 Reset Spam Count",
    Callback = function()
        SpamCount = 0
        AddLog("Spam count reset", "INFO")
    end
})

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 26: VISUALS TAB UI
-- ═══════════════════════════════════════════════════════════════════════

VisualsTab:Toggle({
    Title = "📊 Show Stats UI",
    Desc = "Display FPS, Ping and Parry info",
    Value = true,
    Callback = function(Value) State.ShowStats = Value end
})

VisualsTab:Toggle({
    Title = "🎯 Show Ball Info",
    Desc = "Display ball count and closest ball",
    Value = false,
    Callback = function(Value) State.ShowBallInfo = Value end
})

VisualsTab:Toggle({
    Title = "🔴 Ball ESP",
    Desc = "Highlight balls with outline",
    Value = false,
    Callback = function(Value)
        State.BallESPEnabled = Value
        AddLog("Ball ESP: " .. (Value and "ON" or "OFF"), "INFO")
    end
})

VisualsTab:Toggle({
    Title = "👤 Player ESP",
    Desc = "Highlight players with names and info",
    Value = false,
    Callback = function(Value)
        State.PlayerESP = Value
        AddLog("Player ESP: " .. (Value and "ON" or "OFF"), "INFO")
    end
})

VisualsTab:Slider({
    Title = "Player ESP Range (studs)",
    Desc = "Max distance to show players",
    Value = { Min = 50, Max = 500, Default = 200 },
    Callback = function(Value) State.PlayerESPRange = Value end
})

VisualsTab:Toggle({
    Title = "❤️ Show Player Health",
    Desc = "Display player health in ESP",
    Value = false,
    Callback = function(Value) State.ShowPlayerHealth = Value end
})

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 27: PLAYER TAB UI
-- ═══════════════════════════════════════════════════════════════════════

PlayerTab:Button({
    Title = "🔄 Refresh Player List",
    Callback = function()
        AddLog(string.format("Players online: %d", #Players:GetPlayers()), "INFO")
    end
})

PlayerTab:Paragraph({
    Title = "Player Info",
    Desc = "Player list is updated live in-game",
})

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 28: MOVEMENT TAB UI
-- ═══════════════════════════════════════════════════════════════════════

MovementTab:Toggle({
    Title = "💨 Speed Boost",
    Desc = "Increase walk speed",
    Value = false,
    Callback = function(Value)
        State.SpeedBoost = Value
        if not Value then SetWalkSpeed(16) end
    end
})

MovementTab:Slider({
    Title = "Speed Value",
    Desc = "Walk speed value",
    Value = { Min = 16, Max = 200, Default = 50 },
    Callback = function(Value) State.SpeedValue = Value end
})

MovementTab:Toggle({
    Title = "🦘 Jump Boost",
    Desc = "Increase jump power",
    Value = false,
    Callback = function(Value)
        State.JumpBoost = Value
        if not Value then SetJumpPower(50) end
    end
})

MovementTab:Slider({
    Title = "Jump Value",
    Desc = "Jump power value",
    Value = { Min = 50, Max = 300, Default = 100 },
    Callback = function(Value) State.JumpValue = Value end
})

MovementTab:Toggle({
    Title = "♾️ Infinite Jump",
    Desc = "Jump infinitely in air",
    Value = false,
    Callback = function(Value) State.InfiniteJump = Value end
})

MovementTab:Toggle({
    Title = "🦅 Fly Mode",
    Desc = "Enable flight (WASD + Space/LCtrl)",
    Value = false,
    Callback = function(Value)
        State.FlyMode = Value
        if Value then
            StartFly()
            AddLog("Fly Mode: ON", "INFO")
        else
            StopFly()
            AddLog("Fly Mode: OFF", "INFO")
        end
    end
})

MovementTab:Slider({
    Title = "Fly Speed",
    Desc = "Flight speed value",
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(Value) State.FlySpeed = Value end
})

-- ═══════════════════════════════════════════════════════════════════════
-- SECTION 29: OPTIMIZE TAB UI
-- ═══════════════════════════════════════════════════════════════════════

OptimizeTab:Toggle({
    Title = "🚀 FPS Boost",
    Desc = "Remove visual effects for higher FPS",
    Value = false,
    Callback = function(Value)
        State.FPSBoost = Value
        if Value then
            ApplyFPSBoost()
            AddLog("FPS Boost applied", "SUCCESS")
        end
    end
})

OptimizeTab:Toggle({
    Title = "🌫️ Disable Fog",
    Desc = "Remove fog for clearer vision",
    Value = false,
    Callback = function(Value)
        State.DisableFog = Value
        pcall(function()
            Lighting.FogEnd = Value and 100000 or 10000
        end)
    end
})

OptimizeTab:Toggle({
    Title = "🌑 Disable Shadows",
    Desc = "Remove all shadows",
    Value = false,
    Callback = function(Value)
        State.DisableShadows = Value
        pcall(function()
            Lighting.GlobalShadows = not Value
        end)
    end
})

OptimizeTab:Toggle({
    Title = "✨ Reduce Particles",
    Desc = "Remove particle effects",
    Value = false,
    Callback = function(Value)
        State.ReduceParticles = Value
        if Value then
            pcall(function()
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") then
                        obj.Enabled = false
                    end
                end
            end)
        end
    end
})

OptimizeTab:Toggle({
    Title = "📉 Low Quality Mode",
    De
