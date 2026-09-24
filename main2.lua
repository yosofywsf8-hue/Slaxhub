-- Blade Ball Script - Bypass & Fluent UI (Mobile Triggerbot)
-- Slax Hub v6.4 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v6.4 (Mobile)",
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
local ParryAccuracyValue = 20
local MaxParryAngle = 45
local PredictionFrames = 3
local PanicModeEnabled = true
local PanicSpeedThreshold = 120
local PanicDistanceThreshold = 35

local TriggerbotEnabled = false
local TriggerDistance = 12
local TriggerSpeed = 5
local TriggerCooldown = 0.15

-- Token Retrieval
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

-- Hooking
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

-- Fire Parry
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

-- Ping
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- Prediction
local function PredictBallPosition(ball, frames)
    return ball.Position + (ball.AssemblyLinearVelocity * (frames * (1/60)))
end

-- Max Angle
local function IsWithinParryAngle(playerPos, ballPos, ballVel)
    local toPlayer = (playerPos - ballPos).Unit
    local velDir = ballVel.Unit
    local dot = velDir:Dot(toPlayer)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MaxParryAngle
end

-- =========================================
-- 🎯 TRIGGERBOT LOOP
-- =========================================
task.spawn(function()
    local lastTriggerTime = 0

    while task.wait() do
        if not TriggerbotEnabled then
            lastTriggerTime = 0
            continue
        end

        local now = tick()
        if (now - lastTriggerTime) < TriggerCooldown then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            local realAttr = ball:GetAttribute("realBall")
            if realAttr == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < TriggerSpeed then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0.3 then continue end

            local distance = (playerPos - ballPos).Magnitude
            if distance > TriggerDistance then continue end

            lastTriggerTime = now
            FireParryBypass()
            break
        end
    end
end)

-- =========================================
-- ⚡ Auto Parry Loop
-- =========================================
task.spawn(function()
    local lastParryTime = 0
    local globalLockUntil = 0
    local panicLockUntil = 0
    local trackedBalls = {}

    while task.wait() do
        if not AutoParryEnabled then
            trackedBalls = {}
            globalLockUntil = 0
            panicLockUntil = 0
            continue
        end

        local now = tick()
        local currentPing = GetPing()

        local globalLocked = now < globalLockUntil
        local panicLocked = now < panicLockUntil

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        local convertedAccuracy = 0.10 + ((ParryAccuracyValue / 100) * 0.45)
        local adjustedAccuracy = convertedAccuracy + (currentPing * 0.85)
        local globalLockDuration = 0.35 + (currentPing * 0.6)
        local panicLockDuration = 0.10 + (currentPing * 0.3)

        local panicSpeed = PanicSpeedThreshold
        local panicDist = PanicDistanceThreshold

        for ball, info in pairs(trackedBalls) do
            if not ball.Parent or (now - info.time) > 4 then
                trackedBalls[ball] = nil
            end
        end

        -- PHASE 1: PANIC SCAN
        local panicBall = nil
        local panicTime = math.huge

        if PanicModeEnabled and not panicLocked then
            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                local realAttr = ball:GetAttribute("realBall")
                if realAttr == false then continue end

                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < panicSpeed then continue end

                local toPlayer = (playerPos - ballPos).Unit
                local dot = velocity.Unit:Dot(toPlayer)
                if dot < 0.5 then continue end

                local distance = (playerPos - ballPos).Magnitude
                if distance > panicDist then continue end

                local timeToReach = distance / speed
                if timeToReach < 0.25 and timeToReach > 0 then
                    if timeToReach < panicTime then
                        panicTime = timeToReach
                        panicBall = ball
                    end
                end
            end
        end

        if panicBall then
            panicLockUntil = now + panicLockDuration
            globalLockUntil = now + globalLockDuration
            trackedBalls[panicBall] = { time = now, movedAway = false, returnFrames = 0 }
            FireParryBypass()
            continue
        end

        -- PHASE 2: NORMAL PARRY
        if globalLocked then continue end

        local bestBall = nil
        local bestTime = math.huge

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            local realAttr = ball:GetAttribute("realBall")
            if realAttr == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 5 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            local distance = (playerPos - ballPos).Magnitude

            local info = trackedBalls[ball]
            if info then
                if not info.movedAway then
                    if dot < -0.4 then
                        info.movedAway = true
                        info.awayTime = now
                    end
                    continue
                end

                if dot > 0.7 and speed > 10 then
                    info.returnFrames = info.returnFrames + 1
                    if info.returnFrames < 4 then continue end
                    if (now - info.time) < 0.30 then continue end
                    trackedBalls[ball] = nil
                else
                    info.returnFrames = 0
                    continue
                end
            end

            local targetAttr = ball:GetAttribute("target")
            local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
            if not isTarget then continue end

            if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

            local predictedPos = PredictBallPosition(ball, PredictionFrames)
            local predictedDistance = (playerPos - predictedPos).Magnitude

            if predictedDistance >= 60 then continue end
            if dot <= 0.3 then continue end

            local timeToReach = predictedDistance / speed

            if timeToReach <= adjustedAccuracy and timeToReach > 0 then
                if timeToReach < bestTime then
                    bestTime = timeToReach
                    bestBall = ball
                end
            end
        end

        if bestBall then
            globalLockUntil = now + globalLockDuration
            lastParryTime = now
            trackedBalls[bestBall] = { time = now, movedAway = false, returnFrames = 0 }
            FireParryBypass()
        end
    end
end)

-- =========================================
-- 📱 Floating Triggerbot Button (MOBILE TOUCH FIX)
-- =========================================
local TriggerGui = Instance.new("ScreenGui")
TriggerGui.Name = "SlaxTriggerBotGui"
TriggerGui.Parent = CoreGui
TriggerGui.ResetOnSpawn = false
TriggerGui.DisplayOrder = 999

local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name = "TriggerBtn"
TriggerBtn.Parent = TriggerGui
TriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
TriggerBtn.BorderSizePixel = 0
TriggerBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
TriggerBtn.Size = UDim2.new(0, 150, 0, 50)  -- أكبر شوي للمس
TriggerBtn.Font = Enum.Font.GothamBold
TriggerBtn.Text = "🎯 Trigger: OFF"
TriggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerBtn.TextSize = 16
TriggerBtn.AutoButtonColor = false
TriggerBtn.Active = true
TriggerBtn.Selectable = true

local TriggerCorner = Instance.new("UICorner")
TriggerCorner.CornerRadius = UDim.new(0, 10)
TriggerCorner.Parent = TriggerBtn

local TriggerStroke = Instance.new("UIStroke")
TriggerStroke.Parent = TriggerBtn
TriggerStroke.Color = Color3.fromRGB(255, 255, 255)
TriggerStroke.Thickness = 2
TriggerStroke.Transparency = 0.3

-- دالة تغيير الشكل
local function UpdateBtnVisual()
    if TriggerbotEnabled then
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        TriggerBtn.Text = "🎯 Trigger: ON"
        TriggerStroke.Color = Color3.fromRGB(180, 255, 200)
    else
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        TriggerBtn.Text = "🎯 Trigger: OFF"
        TriggerStroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

-- 📱 TouchTap - الأفضل للجوال
local lastTap = 0
TriggerBtn.TouchTap:Connect(function(touchPositions)
    local now = tick()
    if now - lastTap < 0.3 then return end  -- منع الضغط المزدوج
    lastTap = now
    
    TriggerbotEnabled = not TriggerbotEnabled
    UpdateBtnVisual()
    
    if TriggerToggle then
        pcall(function()
            TriggerToggle:SetValue(TriggerbotEnabled)
        end)
    end
end)

-- 💻 MouseButton1Click - للكمبيوتر
TriggerBtn.MouseButton1Click:Connect(function()
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    
    TriggerbotEnabled = not TriggerbotEnabled
    UpdateBtnVisual()
    
    if TriggerToggle then
        pcall(function()
            TriggerToggle:SetValue(TriggerbotEnabled)
        end)
    end
end)

-- =========================================
-- 🖐️ نظام السحب (Drag) للموبايل والكمبيوتر
-- =========================================
local dragging = false
local dragStart = nil
local startPos = nil

TriggerBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = TriggerBtn.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TriggerBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            TriggerBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
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
    Description = "100 = صد مبكر | 1 = صد متأخر مثالي - يُنصح بـ 15-25",
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

local PanicToggle = Tabs.Main:AddToggle("PanicMode", {Title = "Panic Mode (كرات سريعة)", Default = true })
PanicToggle:OnChanged(function(Value)
    PanicModeEnabled = Value
end)

Tabs.Main:AddSlider("PanicSpeed", {
    Title = "Panic Speed Threshold",
    Description = "الحد الأدنى لسرعة الكرة لتفعيل Panic - يُنصح بـ 100-150",
    Default = 120,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        PanicSpeedThreshold = Value
    end
})

Tabs.Main:AddSlider("PanicDistance", {
    Title = "Panic Distance Threshold",
    Description = "أقصى مسافة لتفعيل Panic - يُنصح بـ 30-40",
    Default = 35,
    Min = 15,
    Max = 60,
    Rounding = 0,
    Callback = function(Value)
        PanicDistanceThreshold = Value
    end
})

-- =========================================
-- 🎯 TRIGGERBOT UI
-- =========================================
local TriggerToggle = Tabs.Main:AddToggle("Triggerbot", {Title = "🎯 Triggerbot (يصد لحظة اللمس)", Default = false })
TriggerToggle:OnChanged(function(Value)
    TriggerbotEnabled = Value
    UpdateBtnVisual()
end)

Tabs.Main:AddSlider("TriggerDistance", {
    Title = "Trigger Distance (studs)",
    Description = "المسافة لتفعيل الـ Triggerbot - يُنصح بـ 10-15",
    Default = 12,
    Min = 5,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        TriggerDistance = Value
    end
})

Tabs.Main:AddSlider("TriggerSpeed", {
    Title = "Trigger Min Speed",
    Description = "أدنى سرعة للكرة لتفعيل Trigger - يُنصح بـ 5-15",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        TriggerSpeed = Value
    end
})

Tabs.Main:AddSlider("TriggerCooldown", {
    Title = "Trigger Cooldown (ms)",
    Description = "الفاصل بين كل trigger - يُنصح بـ 100-200",
    Default = 150,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        TriggerCooldown = Value / 1000
    end
})

InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v6.4 📱",
    Content = "زر Triggerbot جاهز للجوال! المس الزر مرة واحدة",
    Duration = 6
})
