-- Blade Ball Script - Bypass & Fluent UI (Remote/Keypress Methods & Toggleable Spam)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v3.4 (Remote & Keypress Methods)",
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
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ManualSpamUiEnabled = false
local ParryAccuracyValue = 80
local SelectedParryMethod = "Remote" -- الخيار الافتراضي: Remote أو Keypress

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

-- Fire Parry Remote Method
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

-- Keypress Parry Method
local function FireParryKeypress()
    VirtualInputManager:SendKeyPressEvent(Enum.KeyCode.F, false, game)
    task.wait(0.01)
    VirtualInputManager:SendKeyReleaseEvent(Enum.KeyCode.F, false, game)
end

-- Unified Parry Trigger
local function ExecuteParry()
    if SelectedParryMethod == "Remote" then
        FireParryBypass()
    elseif SelectedParryMethod == "Keypress" then
        FireParryKeypress()
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

-- Auto Parry Loop
task.spawn(function()
    local lastParryTime = 0

    while task.wait(0.001) do
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

                    local convertedAccuracy = 0.12 + ((ParryAccuracyValue / 100) * 0.30)
                    local currentPing = GetPing()
                    local adjustedAccuracy = convertedAccuracy + (currentPing * 0.6)
                    local doubleCooldown = (speed > 80) and 0.05 or 0.15

                    if isTarget and dotProduct > 0 then
                        if timeToReach <= adjustedAccuracy then
                            if tick() - lastParryTime >= doubleCooldown then
                                lastParryTime = tick()
                                ExecuteParry()
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =========================================
-- Manual Spam UI Button Creation
-- =========================================
local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpamGui"
SpamGui.Parent = CoreGui
SpamGui.Enabled = false
SpamGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "ManualSpamBtn"
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
SpamBtn.BorderSizePixel = 0
SpamBtn.Position = UDim2.new(0.82, 0, 0.45, 0)
SpamBtn.Size = UDim2.new(0, 110, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "Spam"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 18
SpamBtn.AutoButtonColor = true

local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = SpamBtn
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 1.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Dragging Logic
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

-- Double Spam Execution
local function TriggerSpam()
    task.spawn(function()
        for i = 1, 6 do
            ExecuteParry()
            task.wait(0.008)
        end
    end)
end

SpamBtn.MouseButton1Click:Connect(function()
    TriggerSpam()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.E and ManualSpamUiEnabled then
        TriggerSpam()
    end
end)

-- =========================================
-- UI Controls in Main Tab
-- =========================================
local AutoParryToggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry", Default = false })
AutoParryToggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

local ParryMethodDropdown = Tabs.Main:AddDropdown("ParryMethod", {
    Title = "Parry Method",
    Values = {"Remote", "Keypress"},
    Default = "Remote",
    Callback = function(Value)
        SelectedParryMethod = Value
    end
})

local SpamToggle = Tabs.Main:AddToggle("ManualSpamToggle", {Title = "Manual Spam Button", Default = false })
SpamToggle:OnChanged(function(Value)
    ManualSpamUiEnabled = Value
    SpamGui.Enabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = صد مبكر جداً | 1 = صد متأخر جداً (Perfect)",
    Default = 80,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- UI Settings Manager
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "تم إضافة خياري الصد (Remote & Keypress) بنجاح!",
    Duration = 5
})
