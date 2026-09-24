--[[
    ========================================
    BLADE BALL ULTIMATE AUTO-PARRY SYSTEM v4.0
    Features:
      - High Precision Accuracy Logic
      - Dynamic Reaction Time
      - Proximity & Angle Detection
      - Advanced WInd UI with Status Indicators
      - Anti-Ban Humanization
    ========================================
]]

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- // Configuration & Settings
local Config = {
    Enabled = false,
    AutoParryMode = true, -- True = Auto, False = Manual Trigger
    Cooldown = 0.15,       -- Minimum time between parries (seconds)
    BaseReactionDelay = 0.12, -- Base reaction time
    RandomizeDelay = true, -- Add random variance to delay
    UseSound = true,
    SoundVolume = 0.5,
    VisualFeedback = true,
    UIOpacity = 0.9,
    
    -- Accuracy Settings
    MaxParryDistance = 25,   -- Maximum distance from player to parry (studs)
    MinParryDistance = 1,    -- Minimum distance (don't parry if touching)
    MaxAngleDifference = 45, -- Max angle between player facing and ball (degrees)
    
    ParryRemoteName = "Parry",
    HitRemoteName = "Hit"
}

-- // Global Variables
local RemoteEvents = {}
local LastParryTime = 0
local IsParrying = false
local UIInstance = nil
local CurrentBallCFrame = CFrame.new()
local BallDistance = 0
local BallAngle = 0

-- =========================================
-- 1. WIND UI LIBRARY (Advanced)
-- =========================================

local Library = {}

function Library:CreateWindow(title, subtitle, width, height)
    local Window = Instance.new("ScreenGui")
    Window.Name = "BladeBallWIndUI_Accuracy"
    Window.ResetOnSpawn = false
    Window.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Window.Parent = CoreGui

    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = Window
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = Config.UIOpacity - 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -width/2, 0.5, -height/2)
    MainFrame.Size = UDim2.new(0, width, 0, height)
    MainFrame.ClipsDescendants = true

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame

    -- Top Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Parent = MainFrame
    TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BorderSizePixel = 0

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 12)
    TopCorner.Parent = TopBar

    -- Title Label
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

    -- Subtitle Label
    local SubtitleLabel = Instance.new("TextLabel")
    SubtitleLabel.Parent = TopBar
    SubtitleLabel.BackgroundTransparency = 1
    SubtitleLabel.Position = UDim2.new(0, 15, 0.75, -4)
    SubtitleLabel.Size = UDim2.new(0.7, 0, 0, 16)
    SubtitleLabel.Font = Enum.Font.Gotham
    SubtitleLabel.Text = subtitle or "Precision Parry System"
    SubtitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    SubtitleLabel.TextSize = 12

    -- Content Area
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Parent = MainFrame
    ContentArea.BackgroundTransparency = 1
    ContentArea.Position = UDim2.new(0, 10, 0, 50)
    ContentArea.Size = UDim2.new(1, -20, 1, -60)

    -- Dragging Logic
    local dragging, dragInput, dragStart, startPos
    
    MainFrame.InputBegan:Connect(function(input)
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

    MainFrame.InputChanged:Connect(function(input)
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

    -- Helper Functions for UI Elements
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

        local originalColor = button.BackgroundColor3
        
        button.MouseButton1Down:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
        end)
        
        button.MouseButton1Up:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = originalColor}):Play()
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
        valueLabelInst.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green by default
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
-- 2. BLADE BALL CORE LOGIC & ACCURACY
-- =========================================

-- Function to find the correct RemoteEvents dynamically
local function findRemotes()
    local remotes = {}
    
    -- Try standard paths first
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotesFolder = replicatedStorage:FindFirstChild("Remotes")
    
    if remotesFolder then
        for _, child in pairs(remotesFolder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                table.insert(remotes, child)
            end
        end
    else
        -- Fallback: Scan entire ReplicatedStorage
        for _, child in pairs(replicatedStorage:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                table.insert(remotes, child)
            end
        end
    end
    
    return remotes
end

-- Hook into RemoteEvents to detect parries and inject logic
local function hookRemotes()
    local allRemotes = findRemotes()
    
    for _, remote in pairs(allRemotes) do
        -- Check if this is likely a Blade Ball remote by name or position
        local isParryRemote = string.find(string.lower(remote.Name), "parry") or 
                              string.find(string.lower(remote.Name), "hit") or
                              remote == Config.ParryRemoteName or
                              remote == Config.HitRemoteName
        
        if isParryRemote then
            -- Store for later use
            table.insert(RemoteEvents, remote)
            
            -- Hook FireServer
            local originalFire = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                
                -- If Auto Parry is enabled and we are in a valid state
                if Config.Enabled and Config.AutoParryMode then
                    -- Check cooldown
                    if os.clock() - LastParryTime >= Config.Cooldown then
                        
                        -- ACCURACY CHECK: Is the ball close enough and facing us?
                        local isInPosition = checkAccuracy()
                        
                        if isInPosition then
                            -- Add artificial delay based on distance (closer = faster reaction)
                            local delay = Config.BaseReactionDelay + (BallDistance / 100) 
                            
                            if Config.RandomizeDelay then
                                delay = delay + (math.random(-5, 5) / 1000) -- +/- 0.005s
                            end
                            
                            task.delay(delay, function()
                                if Config.Enabled and not IsParrying then
                                    -- Ensure we haven't been overridden by manual input recently
                                    if os.clock() - LastParryTime >= Config.Cooldown then
                                        IsParrying = true
                                        
                                        -- Fire the remote
                                        pcall(function()
                                            remote:FireServer(unpack(args))
                                        end)
                                        
                                        -- Visual Feedback
                                        if Config.VisualFeedback then
                                            spawnVisualFeedback()
                                        end
                                        
                                        -- Sound Feedback
                                        if Config.UseSound then
                                            spawnSoundFeedback()
                                        end
                                        
                                        LastParryTime = os.clock()
                                        
                                        task.delay(0.1, function()
                                            IsParrying = false
                                        end)
                                    end
                                end
                            end)
                        end
                    end
                end
                
                return originalFire(self, ...)
            end
        end
    end
    
    if #RemoteEvents == 0 then
        warn("[AutoParry] No valid RemoteEvents found. Ensure you are in Blade Ball.")
    else
        print("[AutoParry] Successfully hooked " .. #RemoteEvents .. " remote events.")
    end
end

-- ACCURACY LOGIC: Check if ball is in parry range and angle
local function checkAccuracy()
    -- Find the Ball (Assuming it's a Part named "Ball" or similar in Workspace)
    local ball = workspace:FindFirstChild("Ball")
    
    if not ball then
        -- Try to find any part that looks like a ball
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
    
    -- Calculate Distance
    BallDistance = (playerPos - ballPos).Magnitude
    
    -- Check Distance Limits
    if BallDistance < Config.MinParryDistance or BallDistance > Config.MaxParryDistance then
        return false
    end
    
    -- Calculate Angle
    local directionToBall = (ballPos - playerPos).Unit
    local playerFacing = HumanoidRootPart.CFrame.LookVector
    local angle = math.deg(math.acos(directionToBall:Dot(playerFacing)))
    
    BallAngle = angle
    
    -- Check Angle Limits
    if angle > Config.MaxAngleDifference then
        return false
    end
    
    return true
end

-- Visual Feedback Effect
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

-- Sound Feedback Effect
local function spawnSoundFeedback()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://602817594" -- Classic click/pop sound
    sound.Volume = Config.SoundVolume
    sound.Parent = SoundService
    sound:Play()
    
    task.delay(0.3, function()
        sound:Destroy()
    end)
end

-- =========================================
-- 3. INPUT HANDLING (Mobile & PC)
-- =========================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not Config.Enabled then return end
    
    -- Only trigger on Touch or Mouse Click
    if input.UserInputType == Enum.UserInputType.Touch or 
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        
        -- If Auto Parry is ON, we let the hook handle it.
        -- If Auto Parry is OFF (Manual Mode), we trigger here.
        if not Config.AutoParryMode then
            if os.clock() - LastParryTime >= Config.Cooldown then
                IsParrying = true
                
                for _, remote in pairs(RemoteEvents) do
                    pcall(function()
                        remote:FireServer()
                    end)
                end
                
                LastParryTime = os.clock()
                
                if Config.VisualFeedback then
                    spawnVisualFeedback()
                end
                if Config.UseSound then
                    spawnSoundFeedback()
                end
                
                task.delay(0.1, function()
                    IsParrying = false
                end)
            end
        end
    end
end)

-- =========================================
-- 4. INITIALIZATION & UI SETUP
-- =========================================

-- Wait for player character
repeat task.wait() until LocalPlayer.Character

-- Find remotes initially
hookRemotes()

-- Create UI
local UI = Library:CreateWindow("Blade Ball", "Precision Parry System", 300, 400)

-- Add Controls to UI
UI.CreateToggle("Enable Auto Parry", function(state)
    Config.Enabled = state
    if state then
        print("[AutoParry] System Enabled")
    else
        print("[AutoParry] System Disabled")
    end
end)

UI.CreateToggle("Manual Mode", function(state)
    Config.AutoParryMode = not state -- Toggle is inverted here for logic clarity
    if state then
        print("[AutoParry] Manual Mode: ON (Click to Parry)")
    else
        print("[AutoParry] Auto Mode: ON")
    end
end)

UI.CreateButton("Refresh Remotes", function()
    RemoteEvents = {}
    hookRemotes()
    print("[AutoParry] Refreshed.")
end)

-- Accuracy Status Boxes
local distStatus = UI.CreateStatusBox("Distance:", "N/A")
local angleStatus = UI.CreateStatusBox("Angle:", "N/A")
local readyStatus = UI.CreateStatusBox("Ready:", "NO")

UI.CreateLabel("Max Distance: " .. Config.MaxParryDistance .. " studs")
UI.CreateLabel("Max Angle: " .. Config.MaxAngleDifference .. " degrees")

-- Main Loop for Continuous Updates (Accuracy Tracking)
RunService.Heartbeat:Connect(function()
    if Config.Enabled then
        local isInPosition = checkAccuracy()
        
        -- Update UI Status
        distStatus.Value.Text = string.format("%.1f", BallDistance)
        angleStatus.Value.Text = string.format("%.1f°", BallAngle)
        
        if isInPosition and os.clock() - LastParryTime >= Config.Cooldown then
            readyStatus.Value.Text = "YES"
            readyStatus.Value.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
        else
            readyStatus.Value.Text = "NO"
            readyStatus.Value.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red
        end
    end
end)

print("[AutoParry] System Initialized Successfully with Accuracy Logic.")
