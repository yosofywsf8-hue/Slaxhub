-- Blade Ball Script - Bypass & Fluent UI (500 CPS Auto Spam)
-- Slax Hub v13.1 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v13.1 (500 CPS)",
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

-- Auto Parry Config
local MAX_PARRY_DISTANCE = 120
local MAX_PARRY_ANGLE = 75
local PREDICTION_FRAMES = 3
local BALL_LOCK_DURATION = 0.6
local GLOBAL_COOLDOWN_BASE = 0.06

-- Auto Spam Config (500 CPS)
local SPAM_CPS = 500                    -- الرميات بالثانية
local SPAM_CURVE_BIAS = 0
local SPAM_POWER = 0.5
local SPAM_BURST_PER_FRAME = 8          -- 8 رميات لكل فريم (500 CPS @ 60 FPS)

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
-- Adaptive Accuracy
-- =========================================
local function GetEffectiveAccuracy()
    local pingMs = GetPing() * 1000
    if pingMs < 30 then return 30
    elseif pingMs < 60 then return 25
    elseif pingMs < 90 then return 20
    elseif pingMs < 130 then return 15
    else return 10 end
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
-- ⚡ AUTO SPAM LOOP - 500 CPS (Burst Per Frame)
-- =========================================
task.spawn(function()
    while task.wait() do
        if not AutoSpamEnabled then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        -- 🚀 Burst: نرسل عدة رميات في الفريم الواحد
        for _remote, _origArgs in pairs(_reverted) do
            local _tokens = {}
            -- نجهز 8 tokens دفعة وحدة (أسرع)
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
-- ⚔️ Auto Parry Loop (Beast)
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

        local effectiveAccuracy = GetEffectiveAccuracy()
        local buffer = 0.05 + ((effectiveAccuracy / 100) * 0.35)
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

-- =========================================
-- UI - Auto Spam Tab
-- =========================================
local SpamToggle = Tabs.Spam:AddToggle("AutoSpam", {Title = "Auto Spam (500 CPS)", Default = false })
SpamToggle:OnChanged(function(Value)
    AutoSpamEnabled = Value
end)

Tabs.Spam:AddSlider("SpamCPS", {
    Title = "Spam CPS",
    Description = "Clicks per second",
    Default = 500,
    Min = 100,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value)
        SPAM_CPS = Value
        -- حساب عدد الرميات لكل فريم (60 FPS)
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
    Title = "Slax Hub v13.1",
    Content = "500 CPS Auto Spam loaded",
    Duration = 5
})
