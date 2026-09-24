--[[
    BLADE BALL ULTIMATE AUTO-PARRY SYSTEM v4.1 (FIXED)
    Fixed: Missing quote on line 16
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")  -- ✅ FIXED
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Configuration
local Config = {
    Enabled = false,
    AutoParryMode = true,
    Cooldown = 0.15,
    BaseReactionDelay = 0.12,
    RandomizeDelay = true,
    UseSound = true,
    SoundVolume = 0.5,
    VisualFeedback = true,
    UIOpacity = 0.9,
    MaxParryDistance = 25,
    MinParryDistance = 1,
    MaxAngleDifference = 45,
    ParryRemoteName = "Parry",
    HitRemoteName = "Hit"
}

local RemoteEvents = {}
local LastParryTime = 0
local IsParrying = false
local CurrentBallCFrame = CFrame.new()
local BallDistance = 0
local BallAngle = 0

-- =========================================
-- WIND UI LIBRARY
-- =========================================
local Library = {}

function Library:CreateWindow(title, subtitle, width, height)
    local Window = Instance.new("ScreenGui")
    Window.Name = "SlaxAutoParry"
    Window.ResetOnSpawn = false
    Window.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Window.Parent = CoreGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = Window
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -width/2, 0.5, -height/2)
    MainFrame.Size = UDim2.new(0, width, 0, height)
    MainFrame.ClipsDescendants = true

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Parent = MainFrame
    TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BorderSizePixel = 0

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 12)
    TopCorner.Parent = TopBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Parent = TopBar
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 15, 0.5, -8)
    TitleLabel.Size = UDim2.new(0.7, 0, 0, 20)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = title or "Blade Ball"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 16
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Parent = TopBar
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Position = UDim2.new(0, 15, 0.75, -4)
    SubtitleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.Text = subtitle or "Precision Parry System"
    SubtitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    SubtitleLabel.TextSize = 12

    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Parent = MainFrame
    ContentArea.BackgroundTransparency = 1
    ContentArea.Position = UDim2.new(0, 10, 0, 50)
    ContentArea.Size = UDim2.new(1, -20, 1, -60)
    
    local layout = Instance.new("UIListLayout")
    layout.Parent = ContentArea
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)

    -- Dragging
    local dragging, dragInput, dragStart, startPos
    
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local function createToggle(name, callback)
        local state = false
        local frame = Instance.new("Frame")
        frame.Parent = ContentArea
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        frame.Size = UDim2.new(1, 0, 0, 45)
        frame.BorderSizePixel = 0

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Parent = frame
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 15, 0.5, -7)
        label.Size = UDim2.new(0.7, 0, 0, 20)
        label.Font = Enum.Font.GothamMedium
        label.Text = name
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left

        local switch = Instance.new("Frame")
        switch.Parent = frame
        switch.Position = UDim2.new(0.85, 0, 0.25, 0)
        switch.Size = UDim2.new(0, 36, 0, 18)
        switch.BackgroundColor3 = Color3.fromRGB(40, 40, 45)

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(1, 0)
        sCorner.Parent = switch

        local knob = Instance.new("Frame")
        knob.Parent = switch
        knob.Position = UDim2.new(0, 3, 0.15, 0)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

        local kCorner = Instance.new("UICorner")
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        local click = Instance.new("TextButton")
        click.Parent = frame
        click.BackgroundTransparency = 1
        click.Size = UDim2.new(1, 0, 1, 0)
        click.Text = ""

        click.MouseButton1Click:Connect(function()
            state = not state
            
            if state then
                TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(85, 95, 220)}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -15, 0.15, 0)}):Play()
            else
                TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 45)}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.15, 0)}):Play()
            end
            
            if callback then callback(state) end
        end)

        return frame
    end

    local function createButton(name, callback)
        local button = Instance.new("TextButton")
        button.Parent = ContentArea
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        button.Size = UDim2.new(1, 0, 0, 45)
        button.Font = Enum.Font.GothamMedium
        button.Text = name
        button.TextColor3 = Color3.fromRGB(220, 220, 220)
        button.TextSize = 14
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 8)
        bCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)

        return button
    end

    local function createLabel(text)
        local label = Instance.new("TextLabel")
        label.Parent = ContentArea
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 30)
        label.Font = Enum.Font.Gotham
        label.Text = text
        label.TextColor3 = Color3.fromRGB(150, 150, 150)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        return label
    end

    local function createStatusBox(name, valueLabel)
        local frame = Instance.new("Frame")
        frame.Parent = ContentArea
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = frame
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 10, 0.5, -7)
        nameLabel.Size = UDim2.new(0.6, 0, 0, 20)
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left

        local valueLabelInst = Instance.new("TextLabel")
        valueLabelInst.Parent = frame
        valueLabelInst.BackgroundTransparency = 1
        valueLabelInst.Position = UDim2.new(0.65, 0, 0.5, -7)
        valueLabelInst.Size = UDim2.new(0.35, 0, 0, 20)
        valueLabelInst.Font = Enum.Font.GothamBold
        valueLabelInst.Text = valueLabel or "N/A"
        valueLabelInst.TextColor3 = Color3.fromRGB(100, 255, 100)
        valueLabelInst.TextSize = 12
        valueLabelInst.TextXAlignment = Enum.TextXAlignment.Right
        
        return {Frame = frame, Name = nameLabel, Value = valueLabelInst}
    end

    return {
        Window = Window,
        MainFrame = MainFrame,
        CreateToggle = createToggle,
        CreateButton = createButton,
        CreateLabel = createLabel,
        CreateStatusBox = createStatusBox
    }
end

-- =========================================
-- BLADE BALL CORE LOGIC
-- =========================================

local function findRemotes()
    local remotes = {}
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    
    if remotesFolder then
        for _, child in pairs(remotesFolder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                table.insert(remotes, child)
            end
        end
    else
        for _, child in pairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                table.insert(remotes, child)
            end
        end
    end
    
    return remotes
end

-- Visual Feedback
local function spawnVisualFeedback()
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.5, 0.1, 0.5)
    part.Position = HumanoidRootPart.Position + Vector3.new(0, 1, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.BrickColor = BrickColor.new("Bright blue")
    part.Parent = workspace
    
    local tween = TweenService:Create(part, TweenInfo.new(0.3), {Transparency = 1, Size = Vector3.new(2, 2, 2)})
    tween:Play()
    
    task.delay(0.3, function()
        part:Destroy()
    end)
end

-- Sound Feedback
local function spawnSoundFeedback()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://602817594"
    sound.Volume = Config.SoundVolume
    sound.Parent = SoundService
    sound:Play()
    
    task.delay(0.3, function()
        sound:Destroy()
    end)
end

-- ACCURACY CHECK
local function checkAccuracy()
    local ball = workspace:FindFirstChild("Ball")
    
    if not ball then
        for _, child in pairs(workspace:GetDescendants()) do
            if child:IsA("Part") and (child.Name == "Ball" or child.Name == "Hitbox") then
                ball = child
                break
            end
        end
    end
    
    if not ball then return false end
    
    local ballPos = ball.Position
    local playerPos = HumanoidRootPart.Position
    
    BallDistance = (playerPos - ballPos).Magnitude
    
    if BallDistance < Config.MinParryDistance or BallDistance > Config.MaxParryDistance then
        return false
    end
    
    local directionToBall = (ballPos - playerPos).Unit
    local playerFacing = HumanoidRootPart.CFrame.LookVector
    local angle = math.deg(math.acos(directionToBall:Dot(playerFacing)))
    
    BallAngle = angle
    
    if angle > Config.MaxAngleDifference then
        return false
    end
    
    return true
end

-- Hook Remotes
local function hookRemotes()
    local allRemotes = findRemotes()
    
    for _, remote in pairs(allRemotes) do
        local lowerName = string.lower(remote.Name)
        local isParryRemote = string.find(lowerName, "parry") or 
                              string.find(lowerName, "hit")
        
        if isParryRemote then
            table.insert(RemoteEvents, remote)
        end
    end
    
    if #RemoteEvents == 0 then
        warn("[AutoParry] No valid RemoteEvents found.")
    else
        print("[AutoParry] Hooked " .. #RemoteEvents .. " remote events.")
    end
end

-- =========================================
-- INPUT HANDLING
-- =========================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not Config.Enabled then return end
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.Touch or 
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        
        if not Config.AutoParryMode then
            if os.clock() - LastParryTime >= Config.Cooldown then
                IsParrying = true
                
                for _, remote in pairs(RemoteEvents) do
                    pcall(function()
                        remote:FireServer()
                    end)
                end
                
                LastParryTime = os.clock()
                
                if Config.VisualFeedback then spawnVisualFeedback() end
                if Config.UseSound then spawnSoundFeedback() end
                
                task.delay(0.1, function()
                    IsParrying = false
                end)
            end
        end
    end
end)

-- =========================================
-- INITIALIZATION
-- =========================================

repeat task.wait() until LocalPlayer.Character
hookRemotes()

local UI = Library:CreateWindow("Slax AutoParry", "Precision System v4.1", 300, 400)

UI.CreateToggle("Enable Auto Parry", function(state)
    Config.Enabled = state
    print("[AutoParry] " .. (state and "Enabled" or "Disabled"))
end)

UI.CreateToggle("Manual Mode", function(state)
    Config.AutoParryMode = not state
    print("[AutoParry] Mode: " .. (state and "Manual" or "Auto"))
end)

UI.CreateButton("Refresh Remotes", function()
    RemoteEvents = {}
    hookRemotes()
end)

local distStatus = UI.CreateStatusBox("Distance:", "N/A")
local angleStatus = UI.CreateStatusBox("Angle:", "N/A")
local readyStatus = UI.CreateStatusBox("Ready:", "NO")

UI.CreateLabel("Max Distance: " .. Config.MaxParryDistance .. " studs")
UI.CreateLabel("Max Angle: " .. Config.MaxAngleDifference .. "°")

-- Main Loop
RunService.Heartbeat:Connect(function()
    if Config.Enabled then
        local isInPosition = checkAccuracy()
        
        distStatus.Value.Text = string.format("%.1f", BallDistance)
        angleStatus.Value.Text = string.format("%.1f°", BallAngle)
        
        if isInPosition and os.clock() - LastParryTime >= Config.Cooldown then
            readyStatus.Value.Text = "YES"
            readyStatus.Value.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            readyStatus.Value.Text = "NO"
            readyStatus.Value.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
end)

print("[Slax AutoParry] System Loaded Successfully! ✅"). 
