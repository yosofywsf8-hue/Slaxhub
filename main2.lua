-- Blade Ball Script - Bypass & Fluent UI (Adaptive Auto Parry)
-- Slax Hub v12.1 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v12.1 (Adaptive Accuracy)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Auto", Icon = "swords" }),
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

local AutoParryEnabled = false

-- ⚙️ إعدادات Auto Parry (Beast)
local MAX_PARRY_DISTANCE = 120
local MAX_PARRY_ANGLE = 75
local PREDICTION_FRAMES = 3
local BALL_LOCK_DURATION = 0.6
local GLOBAL_COOLDOWN_BASE = 0.06

-- 🎯 Adaptive Accuracy (يضبط نفسه حسب البينج)
local ACCURACY_MODE = "AUTO" -- "AUTO" أو "MANUAL"
local MANUAL_ACCURACY = 25

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
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
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
-- 🎯 Adaptive Accuracy (Auto-Adjust Based on Ping)
-- =========================================
local function GetEffectiveAccuracy()
    if ACCURACY_MODE == "MANUAL" then
        return MANUAL_ACCURACY
    end

    -- 🎯 AUTO MODE - أفضل قيمة لكل بينج
    local ping = GetPing()
    local pingMs = ping * 1000

    -- الجدول الأمثل:
    -- < 30ms  → Accuracy = 30 (مبكر شوي)
    -- 30-60ms → Accuracy = 25 (متوازن) ⭐ الأفضل
    -- 60-90ms → Accuracy = 20 (دقيق)
    -- 90-130ms → Accuracy = 15 (دقيق جداً)
    -- > 130ms → Accuracy = 10 (مثالي - البينج يعوض)
    
    if pingMs < 30 then
        return 30
    elseif pingMs < 60 then
        return 25
    elseif pingMs < 90 then
        return 20
    elseif pingMs < 130 then
        return 15
    else
        return 10
    end
end

-- =========================================
-- 🧠 Prediction
-- =========================================
local function PredictBallPosition(ball, frames)
    return ball.Position + (ball.AssemblyLinearVelocity * (frames * (1/60)))
end

-- =========================================
-- 📐 Max Angle
-- =========================================
local function IsWithinParryAngle(playerPos, ballPos, ballVel)
    local toPlayer = (playerPos - ballPos).Unit
    local velDir = ballVel.Unit
    local dot = velDir:Dot(toPlayer)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MAX_PARRY_ANGLE
end

-- =========================================
-- ⚔️ Auto Parry Loop (Adaptive Beast)
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

        -- 🔓 تنظيف الأقفال
        for ball, unlockTime in pairs(ballLocks) do
            if not ball.Parent or now >= unlockTime then
                ballLocks[ball] = nil
            end
        end

        -- 🔒 كولداون
        local cooldown = GLOBAL_COOLDOWN_BASE + (currentPing * 0.5)
        if (now - lastFireTime) < cooldown then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- 🎯 Accuracy الحالية (Auto أو Manual)
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
-- UI Controls
-- =========================================
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "⚔️ Auto Parry (Adaptive Beast)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

-- 🎯 Slider للـ Manual (يعمل فقط لو الـ Mode = MANUAL)
local AccuracySlider = Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy (Manual Mode)",
    Description = "يُستخدم فقط إذا AUTO معطل - يُنصح بـ 20-35",
    Default = 25,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        MANUAL_ACCURACY = Value
    end
})

-- 🎯 Toggle للـ Adaptive Mode
local AdaptiveToggle = Tabs.Main:AddToggle("AdaptiveMode", {Title = "🎯 Adaptive Accuracy (Auto)", Default = true })
AdaptiveToggle:OnChanged(function(Value)
    if Value then
        ACCURACY_MODE = "AUTO"
    else
        ACCURACY_MODE = "MANUAL"
    end
end)

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
    Title = "Slax Hub v12.1 👑",
    Content = "Adaptive Accuracy جاهز! يضبط نفسه حسب البينج",
    Duration = 6
})
