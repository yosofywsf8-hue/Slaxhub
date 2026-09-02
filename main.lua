local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local SetClipboard = setclipboard or function() end

local LocalPlayer = Players.LocalPlayer

-- Variables
local AutoParry = false
local Accuracy = 3.3
local CurveType = "straight"
local AutoSpam = false
local SpamSpeed = 0.01

-- UI Root Creation
local SlaxUI = Instance.new("ScreenGui")
SlaxUI.Name = "SlaxHubUI"
SlaxUI.Parent = CoreGui
SlaxUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ==================== [ زر السبام العلوي (Spam UI) ] ====================
local SpamFrame = Instance.new("Frame")
local SpamButton = Instance.new("TextButton")
local SpamCorner = Instance.new("UICorner")
local SpamStroke = Instance.new("UIStroke")

SpamFrame.Name = "SpamFrame"
SpamFrame.Parent = SlaxUI
SpamFrame.AnchorPoint = Vector2.new(0.5, 0)
SpamFrame.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
SpamFrame.Position = UDim2.new(0.5, 0, 0.03, 0)
SpamFrame.Size = UDim2.new(0, 160, 0, 50)
SpamFrame.Active = true
SpamFrame.Draggable = true

SpamCorner.CornerRadius = UDim.new(0, 10)
SpamCorner.Parent = SpamFrame

SpamStroke.Color = Color3.fromRGB(220, 120, 30)
SpamStroke.Thickness = 1.5
SpamStroke.Parent = SpamFrame

SpamButton.Name = "SpamButton"
SpamButton.Parent = SpamFrame
SpamButton.BackgroundTransparency = 1
SpamButton.Size = UDim2.new(1, 0, 1, 0)
SpamButton.Font = Enum.Font.GothamBold
SpamButton.Text = "SPAM"
SpamButton.TextColor3 = Color3.fromRGB(220, 120, 30)
SpamButton.TextSize = 16

SpamButton.MouseButton1Click:Connect(function()
    AutoSpam = not AutoSpam
    if AutoSpam then
        SpamButton.TextColor3 = Color3.fromRGB(50, 220, 100)
        SpamStroke.Color = Color3.fromRGB(50, 220, 100)
    else
        SpamButton.TextColor3 = Color3.fromRGB(220, 120, 30)
        SpamStroke.Color = Color3.fromRGB(220, 120, 30)
    end
end)

-- ==================== [ النافذة الرئيسية (Main Window) ] ====================
local MainFrame = Instance.new("Frame")
local MainCorner = Instance.new("UICorner")
local CloseButton = Instance.new("TextButton")

MainFrame.Name = "MainFrame"
MainFrame.Parent = SlaxUI
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 500, 0, 300)
MainFrame.Active = true
MainFrame.Draggable = true

MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Close Button (X)
CloseButton.Parent = MainFrame
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(0.92, 0, 0.03, 0)
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseButton.TextSize = 18

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Left Side Header (Logo & Name)
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = MainFrame
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0.05, 0, 0.03, 0)
TitleLabel.Size = UDim2.new(0, 200, 0, 40)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.Text = "SLAX"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 28
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Parent = MainFrame
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
SubTitleLabel.Size = UDim2.new(0, 100, 0, 20)
SubTitleLabel.Font = Enum.Font.GothamBold
SubTitleLabel.Text = "HUB"
SubTitleLabel.TextColor3 = Color3.fromRGB(220, 120, 30)
SubTitleLabel.TextSize = 14
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ==================== [ قسم Main ] ====================
local MainSection = Instance.new("Frame")
MainSection.Parent = MainFrame
MainSection.BackgroundColor3 = Color3.fromRGB(16, 17, 20)
MainSection.Position = UDim2.new(0.05, 0, 0.25, 0)
MainSection.Size = UDim2.new(0, 230, 0, 200)

local MainSectionCorner = Instance.new("UICorner")
MainSectionCorner.CornerRadius = UDim.new(0, 6)
MainSectionCorner.Parent = MainSection

local MainTitle = Instance.new("TextLabel")
MainTitle.Parent = MainSection
MainTitle.BackgroundTransparency = 1
MainTitle.Position = UDim2.new(0.05, 0, 0.05, 0)
MainTitle.Size = UDim2.new(0, 200, 0, 20)
MainTitle.Font = Enum.Font.GothamBold
MainTitle.Text = "Main"
MainTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
MainTitle.TextSize = 14
MainTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Auto Parry Toggle
local AutoParryLabel = Instance.new("TextLabel")
AutoParryLabel.Parent = MainSection
AutoParryLabel.BackgroundTransparency = 1
AutoParryLabel.Position = UDim2.new(0.05, 0, 0.25, 0)
AutoParryLabel.Size = UDim2.new(0, 120, 0, 25)
AutoParryLabel.Font = Enum.Font.Gotham
AutoParryLabel.Text = "Auto Parry"
AutoParryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoParryLabel.TextSize = 13
AutoParryLabel.TextXAlignment = Enum.TextXAlignment.Left

local AutoParryBtn = Instance.new("TextButton")
AutoParryBtn.Parent = MainSection
AutoParryBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
AutoParryBtn.Position = UDim2.new(0.7, 0, 0.25, 0)
AutoParryBtn.Size = UDim2.new(0, 45, 0, 22)
AutoParryBtn.Font = Enum.Font.GothamBold
AutoParryBtn.Text = ""

local ParryBtnCorner = Instance.new("UICorner")
ParryBtnCorner.CornerRadius = UDim.new(1, 0)
ParryBtnCorner.Parent = AutoParryBtn

AutoParryBtn.MouseButton1Click:Connect(function()
    AutoParry = not AutoParry
    if AutoParry then
        AutoParryBtn.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
    else
        AutoParryBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    end
end)

-- Accuracy Label & Value
local AccLabel = Instance.new("TextLabel")
AccLabel.Parent = MainSection
AccLabel.BackgroundTransparency = 1
AccLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
AccLabel.Size = UDim2.new(0, 100, 0, 25)
AccLabel.Font = Enum.Font.Gotham
AccLabel.Text = "Accuracy"
AccLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
AccLabel.TextSize = 13
AccLabel.TextXAlignment = Enum.TextXAlignment.Left

local AccValue = Instance.new("TextLabel")
AccValue.Parent = MainSection
AccValue.BackgroundTransparency = 1
AccValue.Position = UDim2.new(0.75, 0, 0.5, 0)
AccValue.Size = UDim2.new(0, 35, 0, 25)
AccValue.Font = Enum.Font.Gotham
AccValue.Text = "3.3"
AccValue.TextColor3 = Color3.fromRGB(200, 200, 200)
AccValue.TextSize = 12

-- Curve Type Dropdown Label
local CurveLabel = Instance.new("TextLabel")
CurveLabel.Parent = MainSection
CurveLabel.BackgroundTransparency = 1
CurveLabel.Position = UDim2.new(0.05, 0, 0.75, 0)
CurveLabel.Size = UDim2.new(0, 100, 0, 25)
CurveLabel.Font = Enum.Font.Gotham
CurveLabel.Text = "Curve Type"
CurveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CurveLabel.TextSize = 13
CurveLabel.TextXAlignment = Enum.TextXAlignment.Left

local CurveBtn = Instance.new("TextButton")
CurveBtn.Parent = MainSection
CurveBtn.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
CurveBtn.Position = UDim2.new(0.55, 0, 0.75, 0)
CurveBtn.Size = UDim2.new(0, 80, 0, 22)
CurveBtn.Font = Enum.Font.Gotham
CurveBtn.Text = "straight v"
CurveBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CurveBtn.TextSize = 11

local CurveCorner = Instance.new("UICorner")
CurveCorner.CornerRadius = UDim.new(0, 4)
CurveCorner.Parent = CurveBtn

-- ==================== [ قسم Social / الحقوق ] ====================
local SocialSection = Instance.new("Frame")
SocialSection.Parent = MainFrame
SocialSection.BackgroundColor3 = Color3.fromRGB(16, 17, 20)
SocialSection.Position = UDim2.new(0.54, 0, 0.1, 0)
SocialSection.Size = UDim2.new(0, 215, 0, 245)

local SocialCorner = Instance.new("UICorner")
SocialCorner.CornerRadius = UDim.new(0, 6)
SocialCorner.Parent = SocialSection

local SocialTitle = Instance.new("TextLabel")
SocialTitle.Parent = SocialSection
SocialTitle.BackgroundTransparency = 1
SocialTitle.Position = UDim2.new(0.08, 0, 0.05, 0)
SocialTitle.Size = UDim2.new(0, 180, 0, 25)
SocialTitle.Font = Enum.Font.GothamBold
SocialTitle.Text = "Social & Developer"
SocialTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
SocialTitle.TextSize = 14
SocialTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Social Info (تعديل الحقوق لـ dev:yosef و Slax)
local InfoText = Instance.new("TextLabel")
InfoText.Parent = SocialSection
InfoText.BackgroundTransparency = 1
InfoText.Position = UDim2.new(0.08, 0, 0.2, 0)
InfoText.Size = UDim2.new(0, 180, 0, 120)
InfoText.Font = Enum.Font.Gotham
InfoText.Text = "DEV: yosef\n\nTG: @slaxscript\n\nDC: discord.gg/slaxhub\n\nTT: @slax_dev"
InfoText.TextColor3 = Color3.fromRGB(180, 180, 180)
InfoText.TextSize = 12
InfoText.TextXAlignment = Enum.TextXAlignment.Left
InfoText.TextYAlignment = Enum.TextYAlignment.Top

-- Copy Discord Button
local CopyDiscordBtn = Instance.new("TextButton")
CopyDiscordBtn.Parent = SocialSection
CopyDiscordBtn.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
CopyDiscordBtn.Position = UDim2.new(0.08, 0, 0.75, 0)
CopyDiscordBtn.Size = UDim2.new(0, 180, 0, 35)
CopyDiscordBtn.Font = Enum.Font.GothamBold
CopyDiscordBtn.Text = "Copy Discord"
CopyDiscordBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
CopyDiscordBtn.TextSize = 13

local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 6)
CopyCorner.Parent = CopyDiscordBtn

CopyDiscordBtn.MouseButton1Click:Connect(function()
    SetClipboard("https://discord.gg/slaxhub")
    CopyDiscordBtn.Text = "Copied!"
    task.wait(1.5)
    CopyDiscordBtn.Text = "Copy Discord"
end)

-- ==================== [ زر الأيقونة لإظهار/إخفاء السكربت ] ====================
local OpenButton = Instance.new("ImageButton")
local OpenCorner = Instance.new("UICorner")

OpenButton.Name = "SlaxToggle"
OpenButton.Parent = SlaxUI
OpenButton.Position = UDim2.new(0, 15, 0.35, 0)
OpenButton.Size = UDim2.new(0, 45, 0, 45)
OpenButton.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
OpenButton.Image = "rbxassetid://6031068426" -- أيقونة النينجا/السكربت
OpenButton.Active = true
OpenButton.Draggable = true

OpenCorner.CornerRadius = UDim.new(0, 10)
OpenCorner.Parent = OpenButton

OpenButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- ==================== [ Remote Parry System ] ====================
local function triggerParry()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
    for _, obj in pairs(remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("parry") or obj.Name:lower():find("ability")) then
            obj:FireServer()
            break
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not AutoParry then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    for _, ball in pairs(ballsFolder:GetChildren()) do
        local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
        if target == LocalPlayer.Name or target == LocalPlayer.DisplayName then
            local ballPosition = ball.Position
            local ballVelocity = ball.AssemblyLinearVelocity
            local distance = (ballPosition - rootPart.Position).Magnitude
            
            local directionToPlayer = (rootPart.Position - ballPosition).Unit
            local ballDirection = ballVelocity.Unit
            local dotProduct = ballDirection:Dot(directionToPlayer)
            
            if dotProduct > 0 then
                local speed = ballVelocity.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                
                local dynamicParryDistance = math.clamp((speed * (0.32 + ping)), 14, 100)
                
                if distance <= dynamicParryDistance then
                    triggerParry()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(SpamSpeed)
        if AutoSpam then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local ballsFolder = workspace:FindFirstChild("Balls")
                if ballsFolder then
                    for _, ball in pairs(ballsFolder:GetChildren()) do
                        local distance = (ball.Position - character.HumanoidRootPart.Position).Magnitude
                        if distance <= 14 then
                            triggerParry()
                        end
                    end
                end
            end
        end
    end
end)
