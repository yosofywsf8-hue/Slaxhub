-- Blade Ball Script - Bypass & Fluent UI (God-Tier Auto Parry)
-- Slax Hub v5.0 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v5.0 (God-Tier Auto Parry)",
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

-- Services
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryAccuracyValue = 20
local MaxParryAngle = 45       -- زاوية قصوى للصد (بالدرجات)
local PredictionFrames = 3     -- عدد إطارات التنبؤ

-- =========================================
-- Token Retrieval Logic
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
-- Hooking Logic
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
-- Fire Parry (Single Remote)
-- =========================================
local _parryRemote = nil
local _parryArgs = nil

local function FireParryBypass()
    if not _parryRemote then
        for _remote, _origArgs in pairs(_reverted) do
            _parryRemote = _remote
            _parryArgs = _origArgs
            break
        end
    end
    if not _parryRemote or not _parryArgs then return end

    local _packet = {
        _parryArgs[1],
        _parryArgs[2],
        _tokenize(_parryArgs[2]),
        0.5,
        workspace.CurrentCamera.CFrame,
        {},
        {0, 0},
        false
    }
    if _parryRemote:IsA('RemoteEvent') then
        _parryRemote:FireServer(unpack(_packet))
    elseif _parryRemote:IsA('RemoteFunction') then
        _parryRemote:InvokeServer(unpack(_packet))
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
-- 🧠 Prediction System (مستوحى من Soluna Hub)
-- =========================================
local function PredictBallPosition(ball, frames)
    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity
    return pos + (vel * (frames * (1/60)))
end

-- =========================================
-- 📐 Max Parry Angle Checker
-- =========================================
local function IsWithinParryAngle(playerPos, ballPos, ballVel)
    local toPlayer = (playerPos - ballPos).Unit
    local velDir = ballVel.Unit
    local dot = velDir:Dot(toPlayer)
    -- الزاوية بين اتجاه الكرة واتجاه اللاعب
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MaxParryAngle
end

-- =========================================
-- 🔒 Auto Parry Loop (God-Tier)
-- =========================================
task.spawn(function()
    local lastParryTime = 0
    local globalLockUntil = 0
    local parriedBallNames = {}
    local parriedBallInstances = {}
    local ballReturnTracker = {}  -- يتتبع الكرات اللي رجعت

    while task.wait() do
        if not AutoParryEnabled then
            parriedBallNames = {}
            parriedBallInstances = {}
            globalLockUntil = 0
            ballReturnTracker = {}
            continue
        end

        local now = tick()
        local currentPing = GetPing()

        -- ⛔ Global Lock
        if now < globalLockUntil then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- معكوس: 100 = مبكر | 1 = متأخر مثالي
        local convertedAccuracy = 0.10 + ((ParryAccuracyValue / 100) * 0.45)
        local adjustedAccuracy = convertedAccuracy + (currentPing * 0.85)
        local globalLockDuration = 0.45 + (currentPing * 0.7)

        local bestBall = nil
        local bestTime = math.huge

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            local realAttr = ball:GetAttribute("realBall")
            if realAttr == false then continue end

            -- 🔒 Instance Lock
            if parriedBallInstances[ball] and (now - parriedBallInstances[ball]) < 2 then
                -- 🔄 Ball Return Detection: لو الكرة انعكست، نصدها
                local vel = ball.AssemblyLinearVelocity
                local toPlayer = (playerPos - ball.Position).Unit
                local dot = vel.Unit:Dot(toPlayer)
                if dot > 0.5 and vel.Magnitude > 5 then
                    -- الكرة رجعت لنا! نصدها
                    parriedBallInstances[ball] = nil
                    parriedBallNames[ball.Name] = nil
                else
                    continue
                end
            end

            -- 🔒 Name Lock
            local lockTime = parriedBallNames[ball.Name]
            if lockTime and (now - lockTime) < 2.5 then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 5 then continue end

            -- 🧠 Prediction: نتنبأ بمكان الكرة بعد بضعة إطارات
            local predictedPos = PredictBallPosition(ball, PredictionFrames)
            local distance = (playerPos - predictedPos).Magnitude

            -- 📐 Max Parry Angle Check
            if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

            -- Target check
            local targetAttr = ball:GetAttribute("target")
            local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
            if not isTarget then continue end

            -- حساب وقت الوصول مع التنبؤ
            local timeToReach = distance / speed

            if timeToReach <= adjustedAccuracy and timeToReach > 0 then
                if timeToReach < bestTime then
                    bestTime = timeToReach
                    bestBall = ball
                end
            end
        end

        -- ⚡ صد مرة واحدة + تفعيل كل الأقفال
        if bestBall then
            globalLockUntil = now + globalLockDuration
            lastParryTime = now
            parriedBallNames[bestBall.Name] = now
            parriedBallInstances[bestBall] = now
            FireParryBypass()
        end

        -- تنظيف
        for name, t in pairs(parriedBallNames) do
            if now - t > 3 then parriedBallNames[name] = nil end
        end
        for inst, t in pairs(parriedBallInstances) do
            if now - t > 3 then parriedBallInstances[inst] = nil end
        end
    end
end)

-- =========================================
-- UI Controls
-- =========================================
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry (God-Tier)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = صد مبكر | 1 = صد متأخر مثالي (Perfect) - يُنصح بـ 15-25",
    Default = 20,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

Tabs.Main:AddSlider("MaxParryAngle", {
    Title = "Max Parry Angle (°)",
    Description = "أقصى زاوية للصد - يُنصح بـ 40-60",
    Default = 45,
    Min = 10,
    Max = 90,
    Rounding = 0,
    Callback = function(Value)
        MaxParryAngle = Value
    end
})

Tabs.Main:AddSlider("PredictionFrames", {
    Title = "Prediction Frames",
    Description = "عدد إطارات التنبؤ - يُنصح بـ 2-4",
    Default = 3,
    Min = 0,
    Max = 6,
    Rounding = 0,
    Callback = function(Value)
        PredictionFrames = Value
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
    Title = "Slax Hub v5.0 👑",
    Content = "God-Tier Auto Parry جاهز! Prediction + Max Angle + Return Detection",
    Duration = 6
})
