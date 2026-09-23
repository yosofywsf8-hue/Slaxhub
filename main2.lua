-- Blade Ball Script - Bypass & Fluent UI (Ultimate Auto Parry Edition)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v4.0 (Ultimate Auto Parry)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Auto", Icon = "swords" }),
    Spam = Window:AddTab({ Title = "Spam Modes", Icon = "zap" }),
    Trigger = Window:AddTab({ Title = "TriggerBot", Icon = "target" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Services & References
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = true
local ParryAccuracyValue = 9 -- الدقة الافتراضية القصوى الموصى بها

local AutoSpamEnabled = false
local ManualSpamActive = false
local SpamDistance = 15
local SpamCPS = 200

local TriggerBotActive = false
local TriggerDistance = 35

-- Token Retrieval Logic
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

-- Hooking Logic for Remote Capture
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

-- Fire Parry Remote
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
    end
end

-- Find Ball
local function GetBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") and obj:GetAttribute("realBall") == true then
                return obj
            end
        end
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") then
                return obj
            end
        end
    end
    return nil
end

-- Get Current Real-time Ping
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.015, 0.35)
end

-- Create Screen GUI for Mobile Touch Buttons
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubTouchUI"
ScreenGui.Parent = (gethui and gethui()) or CoreGui
ScreenGui.ResetOnSpawn = false

local function MakeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Manual Spam On-Screen Button
local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "SpamBtn"
SpamBtn.Size = UDim2.new(0, 75, 0, 75)
SpamBtn.Position = UDim2.new(0.85, 0, 0.45, 0)
SpamBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
SpamBtn.Text = "SPAM\nOFF"
SpamBtn.TextSize = 14
SpamBtn.Font = Enum.Font.SourceSansBold
SpamBtn.Visible = true
SpamBtn.Parent = ScreenGui

local UICorner1 = Instance.new("UICorner")
UICorner1.CornerRadius = UDim.new(0, 16)
UICorner1.Parent = SpamBtn

local UIStroke1 = Instance.new("UIStroke")
UIStroke1.Color = Color3.fromRGB(255, 60, 60)
UIStroke1.Thickness = 2
UIStroke1.Parent = SpamBtn

MakeDraggable(SpamBtn)

SpamBtn.MouseButton1Click:Connect(function()
    ManualSpamActive = not ManualSpamActive
    if ManualSpamActive then
        SpamBtn.Text = "SPAM\nON"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        SpamBtn.Text = "SPAM\nOFF"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        SpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    end
end)

-- TriggerBot On-Screen Button
local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name = "TriggerBtn"
TriggerBtn.Size = UDim2.new(0, 75, 0, 75)
TriggerBtn.Position = UDim2.new(0.85, 0, 0.60, 0)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TriggerBtn.TextColor3 = Color3.fromRGB(60, 180, 255)
TriggerBtn.Text = "FAST BALL\nTRIGGER\nOFF"
TriggerBtn.TextSize = 12
TriggerBtn.Font = Enum.Font.SourceSansBold
TriggerBtn.Visible = true
TriggerBtn.Parent = ScreenGui

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 16)
UICorner2.Parent = TriggerBtn

local UIStroke2 = Instance.new("UIStroke")
UIStroke2.Color = Color3.fromRGB(60, 180, 255)
UIStroke2.Thickness = 2
UIStroke2.Parent = TriggerBtn

MakeDraggable(TriggerBtn)

TriggerBtn.MouseButton1Click:Connect(function()
    TriggerBotActive = not TriggerBotActive
    if TriggerBotActive then
        TriggerBtn.Text = "FAST BALL\nTRIGGER\nON"
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 220)
        TriggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        TriggerBtn.Text = "FAST BALL\nTRIGGER\nOFF"
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        TriggerBtn.TextColor3 = Color3.fromRGB(60, 180, 255)
    end
end)

-- TriggerBot Dedicated Loop
task.spawn(function()
    local lastTriggerTime = 0

    while task.wait(0.001) do
        if TriggerBotActive and not ManualSpamActive then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude

                    local target = ball:GetAttribute("target")
                    local isTarget = (target == LocalPlayer.Name)

                    if isTarget and distance <= TriggerDistance then
                        if tick() - lastTriggerTime >= 0.12 then
                            lastTriggerTime = tick()
                            FireParryBypass()
                        end
                    end
                end
            end
        end
    end
end)

-- Ultimate Auto Parry Loop (Precision Curve & Latency Adaptation)
task.spawn(function()
    local lastParryTime = 0
    local lastBallPos = nil
    local lastBallTick = tick()

    while task.wait(0.0015) do
        if AutoParryEnabled and not ManualSpamActive and not TriggerBotActive then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude
                    
                    local velocity = ball.AssemblyLinearVelocity
                    local speed = velocity.Magnitude

                    -- Real Velocity Calculation (حساب السرعة الواقعية للمنحنيات)
                    local currentTick = tick()
                    if lastBallPos and (currentTick - lastBallTick) > 0 then
                        local calculatedVelocity = (ballPos - lastBallPos) / (currentTick - lastBallTick)
                        if calculatedVelocity.Magnitude > speed then
                            speed = calculatedVelocity.Magnitude
                        end
                    end
                    lastBallPos = ballPos
                    lastBallTick = currentTick

                    local directionToPlayer = (playerPos - ballPos).Unit
                    local dotProduct = velocity:Dot(directionToPlayer)

                    local target = ball:GetAttribute("target")
                    local isTarget = (target == LocalPlayer.Name)

                    local timeToReach = (speed > 0) and (distance / speed) or 999

                    -- Smart Auto Spam in Close Combat
                    if AutoSpamEnabled and distance <= SpamDistance and isTarget then
                        FireParryBypass()
                        task.wait(1 / SpamCPS)
                    elseif isTarget then
                        -- Dynamic Accuracy Based on Speed & Ping
                        local pingSec = GetPing()
                        local accuracyRatio = (ParryAccuracyValue / 10)
                        
                        -- معادلة حساب التوقيت الخارق الخالية من التأخير
                        local targetThreshold = (0.55 - (accuracyRatio * 0.32)) + (pingSec * 0.85)
                        
                        -- للكرات السريعة جداً يتسع النطاق لضمان الصد الدقيق
                        if speed > 100 then
                            targetThreshold = targetThreshold + (speed * 0.0012)
                        end

                        local cooldownThreshold = math.clamp(0.28 + (pingSec * 0.8), 0.2, 0.6)

                        if (timeToReach <= targetThreshold or distance <= 12) and (dotProduct > -0.2) then
                            if tick() - lastParryTime >= cooldownThreshold then
                                lastParryTime = tick()
                                FireParryBypass()
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Manual Spam Loop
task.spawn(function()
    while true do
        if ManualSpamActive then
            FireParryBypass()
            task.wait(1 / SpamCPS)
        else
            task.wait(0.01)
        end
    end
end)

-- UI Controls
local ToggleAuto = Tabs.Main:AddToggle("AutoParry", {Title = "Ultimate Auto Parry", Default = true })
ToggleAuto:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy (الدقة)",
    Description = "المستوى 9 إلى 10 يعطي أفضل أداء خارق للكرات العادية والسريعة",
    Default = 9,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- Spam Controls
local ToggleSpamBtnVisible = Tabs.Spam:AddToggle("ShowSpamBtn", {Title = "Show On-Screen Spam Button", Default = true })
ToggleSpamBtnVisible:OnChanged(function(Value)
    SpamBtn.Visible = Value
end)

local ToggleAutoSpam = Tabs.Spam:AddToggle("AutoSpam", {Title = "Enable Smart Auto Spam", Default = false })
ToggleAutoSpam:OnChanged(function(Value)
    AutoSpamEnabled = Value
end)

Tabs.Spam:AddSlider("SpamCPS", {
    Title = "Spam Speed (CPS)",
    Description = "سرعة الضغطات في الثانية (200 إلى 500)",
    Default = 200,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        SpamCPS = Value
    end
})

-- TriggerBot Controls
Tabs.Trigger:AddParagraph({
    Title = "Fast-Ball TriggerBot",
    Content = "مجهز تلقائياً بأعلى دقة للكرات السريعة جداً. استخدم الزر الأزرق على الشاشة للتفعيل عند الحاجة."
})

local ToggleTriggerBtnVisible = Tabs.Trigger:AddToggle("ShowTriggerBtn", {Title = "Show On-Screen Trigger Button", Default = true })
ToggleTriggerBtnVisible:OnChanged(function(Value)
    TriggerBtn.Visible = Value
end)

-- UI Settings Manager
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "تم تفعيل الـ Ultimate Auto Parry الخارق والمحسن بالكامل!",
    Duration = 5
})
