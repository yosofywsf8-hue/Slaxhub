-- Blade Ball Script - Bypass & Fluent UI (Fixed Accuracy & Manual Spam)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v3.0 (Fixed Accuracy & Manual Spam)",
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

-- Services & References
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryAccuracyValue = 80 -- القيمة الافتراضية

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

-- Get Current Ping in Seconds
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- Corrected Accuracy Scale Loop
task.spawn(function()
    local lastParryTime = 0

    while task.wait(0.003) do
        if AutoParryEnabled then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude
                    local velocity = ball.AssemblyLinearVelocity
                    local speed = velocity.Magnitude

                    local directionToPlayer = (playerPos - ballPos).Unit
                    local dotProduct = velocity:Dot(directionToPlayer)

                    local target = ball:GetAttribute("target")
                    local isTarget = (target == LocalPlayer.Name)

                    local timeToReach = (speed > 0) and (distance / speed) or 999

                    local convertedAccuracy = 0.40 - ((ParryAccuracyValue / 100) * 0.28)
                    local currentPing = GetPing()
                    local adjustedAccuracy = convertedAccuracy + (currentPing * 0.6)
                    local safeCooldown = 0.25 + (currentPing * 0.8)

                    if isTarget and dotProduct > 0 then
                        if timeToReach <= adjustedAccuracy then
                            if tick() - lastParryTime >= safeCooldown then
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

-- UI Controls
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry (Ping Adaptive)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "1 = صد مبكر | 100 = صد متأخر جداً ومثالي (Perfect)",
    Default = 80,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- =========================================
-- Manual Spam UI Button (Sharp Edges Rectangular)
-- =========================================
local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpamGui"
SpamGui.Parent = CoreGui
SpamGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "ManualSpamBtn"
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
SpamBtn.BorderSizePixel = 0 -- زوايا مستطيلة حادة وقاطعة بدون انحناء
SpamBtn.Position = UDim2.new(0.82, 0, 0.45, 0)
SpamBtn.Size = UDim2.new(0, 110, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "Spam"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 18
SpamBtn.AutoButtonColor = true

-- إضافة خط إطار أنيق للزر المستطيل
local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = SpamBtn
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 1.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- نظام سحب الزر على الشاشة (Drag)
local dragging, dragInput, dragStart, startPos
SpamBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        SpamBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- تنفيذ الـ Manual Spam عند الضغط على الزر أو عند الضغط على حرف E
local isSpamming = false

local function TriggerSpam()
    task.spawn(function()
        for i = 1, 5 do
            FireParryBypass()
            task.wait(0.015)
        end
    end)
end

SpamBtn.MouseButton1Click:Connect(function()
    TriggerSpam()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.E then
        TriggerSpam()
    end
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
    Content = "تم إضافة زر Manual Spam المستطيل بنجاح!",
    Duration = 5
})
