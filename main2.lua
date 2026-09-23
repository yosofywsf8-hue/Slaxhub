-- Blade Ball Script - Pro Custom UI & Sleek Float Controls
-- Slax Hub - Developed by yossef

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = cloneref(game:GetService('Stats'))
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))

local LocalPlayer = Players.LocalPlayer

-- Logic Variables
local AutoParryEnabled = true
local ParryAccuracyValue = 8

local AutoSpamEnabled = false
local ManualSpamActive = false
local SpamDistance = 15
local SpamCPS = 200

local TriggerBotActive = false
local TriggerDistance = 30

-- Token & Remote Bypass
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

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.25)
end

-- ==================== SCREEN GUI SETUP ====================

local MainGui = Instance.new("ScreenGui")
MainGui.Name = "SlaxHubProCustomUI"
MainGui.Parent = (gethui and gethui()) or CoreGui
MainGui.ResetOnSpawn = false

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

-- ==================== TOGGLE MENU BUTTON (OPEN/CLOSE) ====================

local ToggleUIRoundBtn = Instance.new("TextButton")
ToggleUIRoundBtn.Name = "ToggleUIRoundBtn"
ToggleUIRoundBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleUIRoundBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
ToggleUIRoundBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
ToggleUIRoundBtn.Text = "SLAX"
ToggleUIRoundBtn.TextColor3 = Color3.fromRGB(0, 180, 255)
ToggleUIRoundBtn.TextSize = 12
ToggleUIRoundBtn.Font = Enum.Font.GothamBold
ToggleUIRoundBtn.Parent = MainGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleUIRoundBtn

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(0, 180, 255)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleUIRoundBtn

MakeDraggable(ToggleUIRoundBtn)

-- ==================== MAIN CUSTOM WINDOW ====================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 310)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -155)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainGui

local MainFrameCorner = Instance.new("UICorner")
MainFrameCorner.CornerRadius = UDim.new(0, 16)
MainFrameCorner.Parent = MainFrame

local MainFrameStroke = Instance.new("UIStroke")
MainFrameStroke.Color = Color3.fromRGB(0, 150, 255)
MainFrameStroke.Thickness = 1.5
MainFrameStroke.Transparency = 0.3
MainFrameStroke.Parent = MainFrame

MakeDraggable(MainFrame)

-- Top Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Position = UDim2.new(0, 18, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "SLAX HUB <font color='#00A8FF'>v6.0</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

-- Toggle Menu Visibility Event
local MenuVisible = true
local function ToggleMenu()
    MenuVisible = not MenuVisible
    MainFrame.Visible = MenuVisible
    if MenuVisible then
        ToggleStroke.Color = Color3.fromRGB(0, 180, 255)
    else
        ToggleStroke.Color = Color3.fromRGB(80, 80, 100)
    end
end

ToggleUIRoundBtn.MouseButton1Click:Connect(ToggleMenu)
CloseBtn.MouseButton1Click:Connect(ToggleMenu)

-- Navigation Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -55)
Sidebar.Position = UDim2.new(0, 10, 0, 45)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 19, 26)
Sidebar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 12)
SideCorner.Parent = Sidebar

local ContainerArea = Instance.new("Frame")
ContainerArea.Size = UDim2.new(1, -160, 1, -55)
ContainerArea.Position = UDim2.new(0, 150, 0, 45)
ContainerArea.BackgroundTransparency = 1
ContainerArea.Parent = MainFrame

-- Page Containers
local Pages = {}

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    Page.Visible = false
    Page.Parent = ContainerArea

    local Layout = Instance.new("UIListLayout")
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 10)
    Layout.Parent = Page

    Pages[name] = Page
    return Page
end

local MainPage = CreatePage("Main")
local SpamPage = CreatePage("Spam")
local TriggerPage = CreatePage("Trigger")

MainPage.Visible = true

-- Sidebar Buttons Generator
local TabButtons = {}
local function AddTab(name, title, icon)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -12, 0, 36)
    TabBtn.Position = UDim2.new(0, 6, 0, #TabButtons * 42 + 8)
    TabBtn.BackgroundColor3 = (#TabButtons == 0) and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(24, 25, 35)
    TabBtn.Text = icon .. "  " .. title
    TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabBtn.TextSize = 12
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.Parent = Sidebar

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 8)
    TabCorner.Parent = TabBtn

    TabBtn.MouseButton1Click:Connect(function()
        for pageName, pageFrame in pairs(Pages) do
            pageFrame.Visible = (pageName == name)
        end
        for _, btn in pairs(TabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(24, 25, 35)
        end
        TabBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    end)

    table.insert(TabButtons, TabBtn)
end

AddTab("Main", "Main Auto", "⚔️")
AddTab("Spam", "Spam Mode", "⚡")
AddTab("Trigger", "TriggerBot", "🎯")

-- UI Controls Generator Helpers
local function AddToggle(parent, text, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -10, 0, 42)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 21, 29)
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Switch = Instance.new("TextButton")
    Switch.Size = UDim2.new(0, 42, 0, 22)
    Switch.Position = UDim2.new(1, -52, 0.5, -11)
    Switch.BackgroundColor3 = default and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 55)
    Switch.Text = ""
    Switch.Parent = Frame

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = Switch

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 16, 0, 16)
    Circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Circle.Parent = Switch

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local enabled = default
    Switch.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            TweenService:Create(Switch, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 170, 255)}):Play()
            TweenService:Create(Circle, TweenInfo.new(0.15), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
        else
            TweenService:Create(Switch, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
            TweenService:Create(Circle, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
        end
        callback(enabled)
    end)
end

-- Setup Page Controls
AddToggle(MainPage, "Enable Auto Parry", true, function(val)
    AutoParryEnabled = val
end)

AddToggle(SpamPage, "Smart Auto Spam", false, function(val)
    AutoSpamEnabled = val
end)

-- FLOATING BUTTONS
local function CreateFloatButton(name, pos, defaultText, activeColor, inactiveColor)
    local Container = Instance.new("Frame")
    Container.Name = name .. "Container"
    Container.Size = UDim2.new(0, 65, 0, 65)
    Container.Position = pos
    Container.BackgroundTransparency = 1
    Container.Parent = MainGui

    local MainBtn = Instance.new("TextButton")
    MainBtn.Size = UDim2.new(1, 0, 1, 0)
    MainBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    MainBtn.Text = ""
    MainBtn.AutoButtonColor = false
    MainBtn.Parent = Container

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(1, 0)
    UICorner.Parent = MainBtn

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = inactiveColor
    UIStroke.Thickness = 2.5
    UIStroke.Parent = MainBtn

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0.6, 0)
    Label.Position = UDim2.new(0, 0, 0.2, 0)
    Label.BackgroundTransparency = 1
    Label.Text = defaultText
    Label.TextColor3 = Color3.fromRGB(240, 240, 240)
    Label.TextSize = 10
    Label.Font = Enum.Font.GothamBold
    Label.Parent = MainBtn

    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 7, 0, 7)
    StatusDot.Position = UDim2.new(0.5, -3.5, 0.8, -4)
    StatusDot.BackgroundColor3 = inactiveColor
    StatusDot.Parent = MainBtn

    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = StatusDot

    MakeDraggable(Container)

    return Container, MainBtn, UIStroke, StatusDot, Label
end

local SpamContainer, SpamBtn, SpamStroke, SpamDot, SpamLabel = CreateFloatButton(
    "SpamBtn", UDim2.new(0.88, 0, 0.42, 0), "⚡\nSPAM", Color3.fromRGB(255, 50, 80), Color3.fromRGB(70, 70, 90)
)

SpamBtn.MouseButton1Click:Connect(function()
    ManualSpamActive = not ManualSpamActive
    if ManualSpamActive then
        SpamStroke.Color = Color3.fromRGB(255, 50, 80)
        SpamDot.BackgroundColor3 = Color3.fromRGB(255, 50, 80)
    else
        SpamStroke.Color = Color3.fromRGB(70, 70, 90)
        SpamDot.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    end
end)

local TriggerContainer, TriggerBtn, TriggerStroke, TriggerDot, TriggerLabel = CreateFloatButton(
    "TriggerBtn", UDim2.new(0.88, 0, 0.56, 0), "🎯\nTRIGGER", Color3.fromRGB(0, 170, 255), Color3.fromRGB(70, 70, 90)
)

TriggerBtn.MouseButton1Click:Connect(function()
    TriggerBotActive = not TriggerBotActive
    if TriggerBotActive then
        TriggerStroke.Color = Color3.fromRGB(0, 170, 255)
        TriggerDot.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    else
        TriggerStroke.Color = Color3.fromRGB(70, 70, 90)
        TriggerDot.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
    end
end)

AddToggle(SpamPage, "Show Spam Float Button", true, function(val)
    SpamContainer.Visible = val
end)

AddToggle(TriggerPage, "Show Trigger Float Button", true, function(val)
    TriggerContainer.Visible = val
end)

-- ==================== CORE AUTO PARRY LOOPS ====================

task.spawn(function()
    local lastTriggerTime = 0
    while task.wait(0.002) do
        if TriggerBotActive and not ManualSpamActive then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude
                    local target = ball:GetAttribute("target")
                    if (target == LocalPlayer.Name) and distance <= TriggerDistance then
                        if tick() - lastTriggerTime >= 0.25 then
                            lastTriggerTime = tick()
                            FireParryBypass()
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local lastParryTime = 0
    while task.wait(0.002) do
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
                    local directionToPlayer = (playerPos - ballPos).Unit
                    local dotProduct = velocity:Dot(directionToPlayer)
                    local target = ball:GetAttribute("target")

                    local timeToReach = (speed > 0) and (distance / speed) or 999

                    if AutoSpamEnabled and distance <= SpamDistance and (target == LocalPlayer.Name) then
                        FireParryBypass()
                        task.wait(1 / SpamCPS)
                    elseif (target == LocalPlayer.Name) and dotProduct > 0.15 then
                        local pingSec = GetPing()
                        local threshold = (0.32 - ((ParryAccuracyValue / 10) * 0.18)) + (pingSec * 0.6)
                        local minCooldown = 0.35 + pingSec

                        if timeToReach <= threshold then
                            if tick() - lastParryTime >= minCooldown then
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
