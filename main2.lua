-- Blade Ball Script - Bypass & Fluent UI (Auto-Off on Distance)
-- Slax Hub v13.6 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v13.6 (Auto-Off on Distance)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "swords" }),
    Spam = Window:AddTab({ Title = "Auto Spam", Icon = "zap" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- State
local AutoParryEnabled = false
local AutoSpamEnabled = false
local BallIncoming = false
local ParryAccuracyValue = 50

-- Auto Parry Config
local MAX_PARRY_DISTANCE = 120
local MAX_PARRY_ANGLE = 75
local PREDICTION_FRAMES = 3
local BALL_LOCK_DURATION = 0.6
local GLOBAL_COOLDOWN_BASE = 0.06

-- Auto Spam Config
local SPAM_CPS = 350
local SPAM_CURVE_BIAS = 0
local SPAM_POWER = 0.5
local SPAM_BURST_PER_FRAME = 5

-- Proximity Config
local PROXIMITY_ENABLED = true
local PROXIMITY_RANGE = 30
local PROXIMITY_CHECK_PLAYERS = true
local PROXIMITY_CHECK_BALL = false
local AUTO_OFF_ON_DISTANCE = true    -- ✅ إطفاء تلقائي لما نبعد
local FAR_CHECK_DELAY = 3.0          -- ثواني بعيد قبل ما يطفى
local farTimer = 0                   -- timer للعد

-- =========================================
-- Token Retrieval
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
-- Fire Parry
-- =========================================
local function FireParryBypass()
    for _remote, _origArgs in pairs(_reverted) do
        local _packet = {
            _origArgs[1],
            _origArgs[2],
            _tokenize(_origArgs[2]),
            SPAM_POWER,
            workspace.CurrentCamera.CFrame,
            {},
            {SPAM_CURVE_BIAS, 0},
            false
        }
        if _remote:IsA('RemoteEvent') then
            _remote:FireServer(unpack(_packet))
        elseif _remote:IsA('RemoteFunction') then
            _remote:InvokeServer(unpack(_packet))
        end
        break
    end
end

-- =========================================
-- Ping
-- =========================================
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- Proximity
-- =========================================
local function IsPlayerNearby(playerPos, range)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if (hrp.Position - playerPos).Magnitude <= range then
            return true
        end
    end
    return false
end

local function IsBallNearby(playerPos, range)
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return false end
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if (ball.Position - playerPos).Magnitude <= range then
            return true
        end
    end
    return false
end

local function ShouldSpam(playerPos)
    if not PROXIMITY_ENABLED then return true end
    local nearPlayer = PROXIMITY_CHECK_PLAYERS and IsPlayerNearby(playerPos, PROXIMITY_RANGE)
    local nearBall = PROXIMITY_CHECK_BALL and IsBallNearby(playerPos, PROXIMITY_RANGE)
    return nearPlayer or nearBall
end

-- =========================================
-- Prediction
-- =========================================
local function PredictBallPosition(ball, frames)
    return ball.Position + (ball.AssemblyLinearVelocity * (frames * (1/60)))
end

-- =========================================
-- Max Angle
-- =========================================
local function IsWithinParryAngle(playerPos, ballPos, ballVel)
    local toPlayer = (playerPos - ballPos).Unit
    local velDir = ballVel.Unit
    local dot = velDir:Dot(toPlayer)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MAX_PARRY_ANGLE
end

-- =========================================
-- 🔍 BALL TRACKER
-- =========================================
task.spawn(function()
    while task.wait(0.02) do
        if not AutoParryEnabled then
            BallIncoming = false
            continue
        end

        local character = LocalPlayer.Character
        if not character then BallIncoming = false continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then BallIncoming = false continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then BallIncoming = false continue end

        local detectionWindow = 0.5 + ((ParryAccuracyValue / 100) * 0.4)

        BallIncoming = false
        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local timeToReach = distance / speed

            if timeToReach <= detectionWindow then
                BallIncoming = true
                break
            end
        end
    end
end)

-- =========================================
-- ⚡ AUTO-OFF WATCHER (يطفئ لما نبعد)
-- =========================================
task.spawn(function()
    while task.wait(0.2) do
        if not AutoSpamEnabled then
            farTimer = 0
            continue
        end
        if not AUTO_OFF_ON_DISTANCE then continue end
        if not PROXIMITY_ENABLED then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        if ShouldSpam(hrp.Position) then
            -- قريب من لاعب → نصفر الـ timer
            farTimer = 0
        else
            -- بعيد → نزيد الـ timer
            farTimer = farTimer + 0.2
            if farTimer >= FAR_CHECK_DELAY then
                -- ⚡ بعيد لمدة كافية → نطفي Auto Spam
                AutoSpamEnabled = false
                farTimer = 0
                pcall(function()
                    if SpamToggle then SpamToggle:SetValue(false) end
                end)
                Fluent:Notify({
                    Title = "Auto Spam",
                    Content = "Turned off - No players nearby",
                    Duration = 3
                })
            end
        end
    end
end)

-- =========================================
-- ⚡ AUTO SPAM LOOP
-- =========================================
task.spawn(function()
    while task.wait() do
        if not AutoSpamEnabled then continue end
        if BallIncoming then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        if not ShouldSpam(hrp.Position) then continue end

        for _remote, _origArgs in pairs(_reverted) do
            local _tokens = {}
            for i = 1, SPAM_BURST_PER_FRAME do
                _tokens[i] = _tokenize(_origArgs[2])
            end

            for i = 1, SPAM_BURST_PER_FRAME do
                local _packet = {
                    _origArgs[1],
                    _origArgs[2],
                    _tokens[i],
                    SPAM_POWER,
                    workspace.CurrentCamera.CFrame,
                    {},
                    {SPAM_CURVE_BIAS, 0},
                    false
                }
                if _remote:IsA('RemoteEvent') then
                    _remote:FireServer(unpack(_packet))
                elseif _remote:IsA('RemoteFunction') then
                    _remote:InvokeServer(unpack(_packet))
                end
            end
            break
        end
    end
end)

-- =========================================
-- ⚔️ Auto Parry Loop
-- =========================================
task.spawn(function()
    local lastFireTime = 0
    local ballLocks = {}

    while task.wait() do
        if not AutoParryEnabled then
            ballLocks = {}
            lastFireTime = 0
            continue
        end

        local now = tick()
        local currentPing = GetPing()

        for ball, unlockTime in pairs(ballLocks) do
            if not ball.Parent or now >= unlockTime then
                ballLocks[ball] = nil
            end
        end

        local cooldown = GLOBAL_COOLDOWN_BASE + (currentPing * 0.5)
        if (now - lastFireTime) < cooldown then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        local buffer = 0.05 + ((ParryAccuracyValue / 100) * 0.35)
        local window = currentPing + buffer

        local bestBall = nil
        local bestTime = math.huge

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local predictedPos = PredictBallPosition(ball, PREDICTION_FRAMES)
            local predictedDistance = (playerPos - predictedPos).Magnitude

            if predictedDistance > MAX_PARRY_DISTANCE then continue end
            if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

            local targetAttr = ball:GetAttribute("target")
            local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
            if not isTarget then continue end

            local timeToReach = predictedDistance / speed

            if timeToReach <= window and timeToReach >= 0 then
                if timeToReach < bestTime then
                    bestTime = timeToReach
                    bestBall = ball
                end
            end
        end

        if bestBall then
            lastFireTime = now
            ballLocks[bestBall] = now + BALL_LOCK_DURATION
            FireParryBypass()
        end
    end
end)

-- =========================================
-- UI - Main Tab
-- =========================================
local ParryToggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry", Default = false })
ParryToggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = Early | 1 = Perfect",
    Default = 50,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- =========================================
-- UI - Auto Spam Tab
-- =========================================
local SpamToggle = Tabs.Spam:AddToggle("AutoSpam", {Title = "Auto Spam", Default = false })
SpamToggle:OnChanged(function(Value)
    AutoSpamEnabled = Value
    farTimer = 0
end)

local ProximityToggle = Tabs.Spam:AddToggle("ProximityMode", {Title = "Proximity Trigger", Default = true })
ProximityToggle:OnChanged(function(Value)
    PROXIMITY_ENABLED = Value
end)

local AutoOffToggle = Tabs.Spam:AddToggle("AutoOffOnDistance", {Title = "Auto-Off When Far From Players", Default = true })
AutoOffToggle:OnChanged(function(Value)
    AUTO_OFF_ON_DISTANCE = Value
    farTimer = 0
end)

Tabs.Spam:AddSlider("FarCheckDelay", {
    Title = "Auto-Off Delay (seconds)",
    Description = "Time away before turning off",
    Default = 3,
    Min = 1,
    Max = 15,
    Rounding = 0,
    Callback = function(Value)
        FAR_CHECK_DELAY = Value
    end
})

Tabs.Spam:AddSlider("ProximityRange", {
    Title = "Proximity Range (studs)",
    Description = "Distance to trigger",
    Default = 30,
    Min = 5,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        PROXIMITY_RANGE = Value
    end
})

local CheckPlayersToggle = Tabs.Spam:AddToggle("CheckPlayers", {Title = "Detect Nearby Players", Default = true })
CheckPlayersToggle:OnChanged(function(Value)
    PROXIMITY_CHECK_PLAYERS = Value
end)

local CheckBallToggle = Tabs.Spam:AddToggle("CheckBall", {Title = "Detect Nearby Ball", Default = false })
CheckBallToggle:OnChanged(function(Value)
    PROXIMITY_CHECK_BALL = Value
end)

Tabs.Spam:AddSlider("SpamCPS", {
    Title = "Spam CPS",
    Description = "200-500 CPS",
    Default = 350,
    Min = 200,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        SPAM_CPS = Value
        SPAM_BURST_PER_FRAME = math.max(1, math.floor(Value / 60))
    end
})

Tabs.Spam:AddSlider("SpamPower", {
    Title = "Spam Power",
    Description = "Power of each shot",
    Default = 50,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        SPAM_POWER = Value / 100
    end
})

Tabs.Spam:AddSlider("SpamCurve", {
    Title = "Curve Bias",
    Description = "Ball curve",
    Default = 0,
    Min = -100,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        SPAM_CURVE_BIAS = Value / 100
    end
})

-- =========================================
-- Settings
-- =========================================
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v13.6",
    Content = "Auto-Off on Distance loaded",
    Duration = 5
})
