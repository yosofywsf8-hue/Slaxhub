-- Timebomb Duels Mobile - Premium Features with Credits
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Cleanup previous GUI
if LocalPlayer.PlayerGui:FindFirstChild("TimebombUltraGUI") then
    LocalPlayer.PlayerGui.TimebombUltraGUI:Destroy()
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimebombUltraGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Draggable Floating Circle Button
local ToggleCircle = Instance.new("TextButton")
ToggleCircle.Size = UDim2.new(0, 50, 0, 50)
ToggleCircle.Position = UDim2.new(0.02, 0, 0.25, 0)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
ToggleCircle.Text = "💣"
ToggleCircle.TextSize = 24
ToggleCircle.Active = true
ToggleCircle.Draggable = true
ToggleCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(90, 100, 125)
CircleStroke.Thickness = 2
CircleStroke.Parent = ToggleCircle

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 310)
MainFrame.Position = UDim2.new(0.18, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 55, 70)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Title Bar
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.75, 0, 0, 28)
Title.Position = UDim2.new(0.04, 0, 0.02, 0)
Title.Text = "Timebomb Ultra Hub"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

-- Credits
local Credits = Instance.new("TextLabel")
Credits.Size = UDim2.new(0.92, 0, 0, 16)
Credits.Position = UDim2.new(0.04, 0, 0.1, 0)
Credits.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
Credits.TextColor3 = Color3.fromRGB(160, 170, 190)
Credits.BackgroundTransparency = 1
Credits.Font = Enum.Font.Gotham
Credits.TextSize = 10
Credits.TextXAlignment = Enum.TextXAlignment.Left
Credits.Parent = MainFrame

-- Close Button (❌)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(0.86, 0, 0.02, 0)
CloseBtn.Text = "❌"
CloseBtn.TextSize = 11
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Auto Pass Toggle Button
local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(0.92, 0, 0, 36)
AutoBtn.Position = UDim2.new(0.04, 0, 0.18, 0)
AutoBtn.Text = "Auto Play: OFF"
AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 13
AutoBtn.Parent = MainFrame

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoBtn

-- Noclip Toggle Button
local NoclipBtn = Instance.new("TextButton")
NoclipBtn.Size = UDim2.new(0.92, 0, 0, 34)
NoclipBtn.Position = UDim2.new(0.04, 0, 0.31, 0)
NoclipBtn.Text = "Noclip: OFF 👻"
NoclipBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
NoclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NoclipBtn.Font = Enum.Font.GothamBold
NoclipBtn.TextSize = 12
NoclipBtn.Parent = MainFrame

local NoclipCorner = Instance.new("UICorner")
NoclipCorner.CornerRadius = UDim.new(0, 8)
NoclipCorner.Parent = NoclipBtn

-- Speed Section Label
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0.92, 0, 0, 18)
SpeedLabel.Position = UDim2.new(0.04, 0, 0.44, 0)
SpeedLabel.Text = "WalkSpeed: 16 (Normal)"
SpeedLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextSize = 11
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = MainFrame

-- Speed Buttons Frame (1 to 10)
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(0.92, 0, 0, 32)
SpeedFrame.Position = UDim2.new(0.04, 0, 0.51, 0)
SpeedFrame.BackgroundTransparency = 1
SpeedFrame.Parent = MainFrame

local SpeedLayout = Instance.new("UIListLayout")
SpeedLayout.FillDirection = Enum.FillDirection.Horizontal
SpeedLayout.Padding = UDim.new(0, 4)
SpeedLayout.Parent = SpeedFrame

local selectedSpeedLevel = 1
for i = 1, 10 do
    local SBtn = Instance.new("TextButton")
    SBtn.Size = UDim2.new(0, 19, 0, 28)
    SBtn.Text = tostring(i)
    SBtn.BackgroundColor3 = (i == 1) and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 45, 60)
    SBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SBtn.Font = Enum.Font.GothamBold
    SBtn.TextSize = 10
    SBtn.Parent = SpeedFrame
    
    local SCorner = Instance.new("UICorner")
    SCorner.CornerRadius = UDim.new(0, 5)
    SCorner.Parent = SBtn
    
    SBtn.MouseButton1Click:Connect(function()
        selectedSpeedLevel = i
        for _, btn in pairs(SpeedFrame:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            end
        end
        SBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        -- حساب السرعة من مستوى 1 إلى 10 (المستوى 1 = 16، المستوى 10 = 50)
        local calculatedSpeed = 16 + (i - 1) * 3.8
        SpeedLabel.Text = "WalkSpeed: " .. string.format("%.1f", calculatedSpeed) .. " (Lvl " .. i .. ")"
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = calculatedSpeed
        end
    end)
end

-- Music Input Box
local MusicBox = Instance.new("TextBox")
MusicBox.Size = UDim2.new(0.65, 0, 0, 32)
MusicBox.Position = UDim2.new(0.04, 0, 0.64, 0)
MusicBox.PlaceholderText = "حط ID الاغنية هنا"
MusicBox.Text = ""
MusicBox.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
MusicBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicBox.PlaceholderColor3 = Color3.fromRGB(130, 140, 160)
MusicBox.Font = Enum.Font.Gotham
MusicBox.TextSize = 11
MusicBox.Parent = MainFrame

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = MusicBox

-- Play Music Button
local PlayMusicBtn = Instance.new("TextButton")
PlayMusicBtn.Size = UDim2.new(0.12, 0, 0, 32)
PlayMusicBtn.Position = UDim2.new(0.71, 0, 0.64, 0)
PlayMusicBtn.Text = "▶️"
PlayMusicBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
PlayMusicBtn.TextSize = 12
PlayMusicBtn.Parent = MainFrame

local PlayCorner = Instance.new("UICorner")
PlayCorner.CornerRadius = UDim.new(0, 6)
PlayCorner.Parent = PlayMusicBtn

-- Stop Music Button
local StopMusicBtn = Instance.new("TextButton")
StopMusicBtn.Size = UDim2.new(0.12, 0, 0, 32)
StopMusicBtn.Position = UDim2.new(0.84, 0, 0.64, 0)
StopMusicBtn.Text = "⏹️"
StopMusicBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
StopMusicBtn.TextSize = 12
StopMusicBtn.Parent = MainFrame

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopMusicBtn

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0.88, 0)
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

-- Logic & Sound Setup
local currentSound = Instance.new("Sound")
currentSound.Name = "TimebombCustomMusic"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = workspace

local isAutoActive = false
local isNoclipActive = false

-- Music Play Action
PlayMusicBtn.MouseButton1Click:Connect(function()
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then
        currentSound.SoundId = "rbxassetid://" .. tostring(soundId)
        currentSound:Play()
        StatusLabel.Text = "Status: Playing Music 🎵"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
    else
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "ID غير صحيح!"
    end
end)

-- Music Stop Action
StopMusicBtn.MouseButton1Click:Connect(function()
    currentSound:Stop()
    StatusLabel.Text = "Status: Music Stopped ⏹️"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
end)

-- Toggle Circle Visibility
ToggleCircle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Destroy Script Completely
CloseBtn.MouseButton1Click:Connect(function()
    isAutoActive = false
    isNoclipActive = false
    currentSound:Destroy()
    ScreenGui:Destroy()
end)

-- Auto Pass Toggle
AutoBtn.MouseButton1Click:Connect(function()
    isAutoActive = not isAutoActive
    if isAutoActive then
        AutoBtn.Text = "Auto Play: ON"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
        StatusLabel.Text = "Status: Auto Active 🚀"
        StatusLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    else
        AutoBtn.Text = "Auto Play: OFF"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        StatusLabel.Text = "Status: Auto OFF"
        StatusLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
    end
end)

-- Noclip Toggle
NoclipBtn.MouseButton1Click:Connect(function()
    isNoclipActive = not isNoclipActive
    if isNoclipActive then
        NoclipBtn.Text = "Noclip: ON 👻"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 210)
    else
        NoclipBtn.Text = "Noclip: OFF 👻"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
    end
end)

-- Check Bomb
local function holdsBomb()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    
    local inChar = myChar:FindFirstChild("Bomb") or myChar:FindFirstChildWhichIsA("Tool")
    if inChar and string.find(string.lower(inChar.Name), "bomb") then return true end
    
    local inBackpack = LocalPlayer.Backpack:FindFirstChild("Bomb") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if inBackpack and string.find(string.lower(inBackpack.Name), "bomb") then return true end
    
    return false
end

-- Target Detection
local function getArenaTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    
    local nearest = nil
    local shortestDist = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < 120 and dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- Main Stepped Execution Loop
RunService.Stepped:Connect(function()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or not myChar:FindFirstChild("HumanoidRootPart") then return end
    
    -- Noclip Logic
    if isNoclipActive then
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    -- Auto Pass Logic
    if isAutoActive and holdsBomb() then
        local targetPlayer = getArenaTarget()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "Status: PASSING BOMB!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            
            myChar.Humanoid:MoveTo(targetPlayer.Character.HumanoidRootPart.Position)
        end
    end
end)
