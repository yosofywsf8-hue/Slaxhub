-- Blade Ball Script - Bypass & Fluent UI (Auto Parry Beast)
-- Slax Hub v12.0 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v12.0 (Auto Parry Beast)",
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
local ParryAccuracyValue = 25

-- ⚙️ إعدادات Auto Parry (Beast)
local MAX_PARRY_DISTANCE = 120     -- أقصى مسافة للصد
local MAX_PARRY_ANGLE = 75         -- أقصى زاوية (واسعة)
local PREDICTION_FRAMES = 3        -- إطارات التنبؤ
local BALL_LOCK_DURATION = 0.6     -- قفل الكرة بعد الصد
local GLOBAL_COOLDOWN_BASE = 0.06  -- كولداون أساسي (يمنع spam)

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
-- Fire Parry (Single Shot)
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
-- 🧠 Prediction System
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
-- ⚔️ Auto Parry Loop (BEAST LEVEL)
-- =========================================
task.spawn(function()
    local lastFireTime = 0
    local ballLocks = {} -- {[ball] = unlockTime}

    while task.wait() do
        if not AutoParryEnabled then
            ballLocks = {}
            lastFireTime = 0
            continue
        end

        local now = tick()
        local currentPing = GetPing()

        -- 🔓 تنظيف الأقفال المنتهية + الكرات المحذوفة
        for ball, unlockTime in pairs(ballLocks) do
            if not ball.Parent or now >= unlockTime then
                ballLocks[ball] = nil
            end
        end

        -- 🔒 كولداون عالمي (يمنع spam)
        local cooldown = GLOBAL_COOLDOWN_BASE + (currentPing * 0.5)
        if (now - lastFireTime) < cooldown then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- 🎯 نافذة الصد (حسب البينج + Buffer)
        local buffer = 0.05 + ((ParryAccuracyValue / 100) * 0.35)
        local window = currentPing + buffer

        local bestBall = nil
        local bestTime = math.huge

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end

            -- 🔒 تجاهل الكرة إذا كانت مقفولة
            if ballLocks[ball] then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            -- 🧠 Prediction
            local predictedPos = PredictBallPosition(ball, PREDICTION_FRAMES)
            local predictedDistance = (playerPos - predictedPos).Magnitude

            -- 📏 Max Distance
            if predictedDistance > MAX_PARRY_DISTANCE then continue end

            -- 📐 Max Angle
            if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

            -- 🎯 Target Check
            local targetAttr = ball:GetAttribute("target")
            local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
            if not isTarget then continue end

            -- ⚡ Time to Reach
            local timeToReach = predictedDistance / speed

            -- 🎯 Parry Window
            if timeToReach <= window and timeToReach >= 0 then
                if timeToReach < bestTime then
                    bestTime = timeToReach
                    bestBall = ball
                end
            end
        end

        -- 🚀 Execute Parry
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
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "⚔️ Auto Parry (Beast)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = صد مبكر | 1 = صد مثالي - يُنصح بـ 20-35",
    Default = 25,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
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
    Title = "Slax Hub v12.0 👑",
    Content = "Auto Parry Beast Level - بدون Triggerbot، فقط Auto Parry قوي",
    Duration = 6
})
