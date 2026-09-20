--[[
    ================================================================================
    SLAX HUB v2.5 - ULTIMATE ADVANCED EDITION (FULL INVIS & XENO ENGINE)
    Designed & Engineered for: Blade Ball (Roblox)
    Author: yossef
    Optimization: Extreme High-Frequency Reaction Loops & Custom GUI Framework
    ================================================================================
--]]

-- [SECTION 1: SINGLETON EXECUTION GUARD]
if getgenv().SlaxHubLoaded then
    warn("[SLAX HUB]: Script is already running!")
    return
end
getgenv().SlaxHubLoaded = true

-- [SECTION 2: CORE SERVICES & DEPENDENCIES]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- [SECTION 3: GLOBAL CONFIGURATION MATRIX]
local SlaxConfig = {
    -- Auto Parry Settings
    AutoParry = true,
    AntiCurve = true,
    CurveCorrectionMultiplier = 1.35,
    ParryDistance = 30,
    BasePredictionTime = 0.16,
    DynamicPingCompensation = true,
    
    -- Spam & Combat Overdrive
    AutoSpam = false,
    ManualSpam = false,
    SpamDistance = 14,
    SpamDelay = 0.001,
    ClashDetector = true,
    
    -- Abilities & Utility
    AutoAbility = true,
    AbilityActivationDistance = 18,
    AutoJump = false,
    AntiAFK = true,
    
    -- Visuals & ESP
    PlayerESP = true,
    ESPBoxes = true,
    ESPTracers = false,
    ESPColor = Color3.fromRGB(0, 255, 170),
    
    -- Customization & World Effects
    SkinChanger = false,
    CustomFX = false,
    BallHighlight = true,
    
    -- Internal Engine Settings
    DebugLogs = false
}

-- [SECTION 4: EXECUTOR DETECTION & BYPASS LAYER]
local ExecutorInfo = {
    Name = "Unknown",
    IsXeno = false,
    IsSolara = false,
    IsDelta = false
}

if identifyexecutor then
    local execName = string.lower(identifyexecutor())
    ExecutorInfo.Name = execName
    if string.find(execName, "xeno") then
        ExecutorInfo.IsXeno = true
    elseif string.find(execName, "solara") then
        ExecutorInfo.IsSolara = true
    elseif string.find(execName, "delta") then
        ExecutorInfo.IsDelta = true
    end
end

local function OutputLog(msg)
    if SlaxConfig.DebugLogs then
        print("[SLAX HUB LOG]: " .. tostring(msg))
    end
end

-- Fast Input Dispatcher
local function ExecuteClick()
    if ExecutorInfo.IsXeno and mouse1press and mouse1release then
        mouse1press()
        task.wait(0.005)
        mouse1release()
    else
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

-- [SECTION 5: PHYSICS & ANTI-CURVE MATHEMATICAL ENGINE]
local BallEngine = {
    CurrentBall = nil,
    LastPosition = Vector3.zero,
    Velocity = Vector3.zero,
    IsCurveDetected = false
}

function BallEngine:FetchActiveBall()
    local container = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("TrainingBalls")
    if not container then return nil end

    for _, obj in pairs(container:GetChildren()) do
        if obj:IsA("BasePart") and (obj:GetAttribute("realBall") == true or obj:FindFirstChild("zoomies") or obj.Name == "RealBall") then
            return obj
        end
    end
    return nil
end

function BallEngine:IsPlayerTargeted(ball)
    if not ball then return false end
    local targetVal = ball:GetAttribute("target") or (ball:FindFirstChild("target") and ball.target.Value)
    if type(targetVal) == "string" then
        return targetVal == LocalPlayer.Name
    elseif typeof(targetVal) == "Instance" and targetVal:IsA("Player") then
        return targetVal == LocalPlayer
    end
    return false
end

function BallEngine:CalculateAntiCurveFactor(ball, playerHrp)
    if not ball or not playerHrp or not SlaxConfig.AntiCurve then return 1 end

    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    if ballVel.Magnitude < 1 then return 1 end

    local dirToPlayer = (playerHrp.Position - ballPos).Unit
    local ballDir = ballVel.Unit
    local dotProduct = ballDir:Dot(dirToPlayer)

    -- Detect curving angle divergence
    if dotProduct < 0.7 then
        self.IsCurveDetected = true
        return (1 - math.clamp(dotProduct, -1, 1)) * SlaxConfig.CurveCorrectionMultiplier
    end

    self.IsCurveDetected = false
    return 1
end

-- [SECTION 6: CORE RUNTIME & PRE-RENDER CONNECTIONS]
RunService.PreRender:Connect(function()
    if not SlaxConfig.AutoParry then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = BallEngine:FetchActiveBall()
    if not ball then return end

    local isTarget = BallEngine:IsPlayerTargeted(ball)
    if not isTarget then return end

    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    local distance = (ballPos - hrp.Position).Magnitude
    local speed = ballVel.Magnitude

    if speed > 0.1 then
        -- Ping Calculation
        local currentPing = 0
        if SlaxConfig.DynamicPingCompensation then
            local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pingStat then
                currentPing = (pingStat:GetValue() / 1000)
            end
        end

        local curveFactor = BallEngine:CalculateAntiCurveFactor(ball, hrp)
        local timeToReach = (distance / speed) - currentPing
        local calculatedThreshold = (SlaxConfig.ParryDistance + (curveFactor * 8))

        if timeToReach <= SlaxConfig.BasePredictionTime or distance <= calculatedThreshold then
            ExecuteClick()
            OutputLog("Auto Parry Triggered | Distance: " .. math.floor(distance) .. " | Time: " .. string.format("%.3f", timeToReach))

            -- Smart Ability Trigger Logic
            if SlaxConfig.AutoAbility and distance <= SlaxConfig.AbilityActivationDistance then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end
        end
    end
end)

-- [SECTION 7: HIGH-FREQUENCY SPAM ENGINE]
task.spawn(function()
    while true do
        task.wait(SlaxConfig.SpamDelay)
        if SlaxConfig.AutoSpam or SlaxConfig.ManualSpam then
            local ball = BallEngine:FetchActiveBall()
            local char = LocalPlayer.Character
            if ball and char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (ball.Position - char.HumanoidRootPart.Position).Magnitude
                if dist <= SlaxConfig.SpamDistance or SlaxConfig.ManualSpam then
                    ExecuteClick()
                end
            end
        end
    end
end)

-- Manual Hotkey Controls (Default: E Key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.E then
        SlaxConfig.ManualSpam = not SlaxConfig.ManualSpam
        OutputLog("Manual Spam Toggled: " .. tostring(SlaxConfig.ManualSpam))
    end
end)

-- Anti-AFK Routine
if SlaxConfig.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
    end)
end

-- Auto Jump Connection
RunService.Stepped:Connect(function()
    if SlaxConfig.AutoJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- [SECTION 8: ESP & VISUAL OVERLAYS SYSTEM]
local ESPManager = {
    Storage = {}
}

function ESPManager:ApplyESP(player)
    if player == LocalPlayer then return end

    local function AttachHighlight(character)
        if not character then return end

        local existing = character:FindFirstChild("SlaxHighlight")
        if existing then existing:Destroy() end

        local highlight = Instance.new("Highlight")
        highlight.Name = "SlaxHighlight"
        highlight.FillColor = SlaxConfig.ESPColor
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.6
        highlight.OutlineTransparency = 0
        highlight.Enabled = SlaxConfig.PlayerESP
        highlight.Parent = character
    end

    player.CharacterAdded:Connect(AttachHighlight)
    if player.Character then
        AttachHighlight(player.Character)
    end
end

for _, plr in pairs(Players:GetPlayers()) do
    ESPManager:ApplyESP(plr)
end
Players.PlayerAdded:Connect(function(plr)
    ESPManager:ApplyESP(plr)
end)

-- [SECTION 9: ADVANCED CYBERPUNK USER INTERFACE (GUI)]
local UIContainer = Instance.new("ScreenGui")
UIContainer.Name = "SlaxHubUI_v25"
UIContainer.ResetOnSpawn = false
UIContainer.Parent = (gethui and gethui()) or CoreGui

-- Clean previous UI instances
for _, oldUI in pairs(CoreGui:GetChildren()) do
    if oldUI.Name == "SlaxHubUI_v25" and oldUI ~= UIContainer then
        oldUI:Destroy()
    end
end

-- Floating Action Button
local FloatButton = Instance.new("TextButton")
FloatButton.Name = "SlaxFloatingButton"
FloatButton.Size = UDim2.new(0, 55, 0, 55)
FloatButton.Position = UDim2.new(0.02, 0, 0.2, 0)
FloatButton.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
FloatButton.Text = "SLAX"
FloatButton.TextColor3 = Color3.fromRGB(0, 255, 170)
FloatButton.TextSize = 14
FloatButton.Font = Enum.Font.GothamBold
FloatButton.Active = true
FloatButton.Draggable = true
FloatButton.Parent = UIContainer

local FloatCorner = Instance.new("UICorner", FloatButton)
FloatCorner.CornerRadius = UDim.new(1, 0)

local FloatStroke = Instance.new("UIStroke", FloatButton)
FloatStroke.Color = Color3.fromRGB(0, 255, 170)
FloatStroke.Thickness = 2

-- Main Frame Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 360, 0, 440)
MainWindow.Position = UDim2.new(0.3, 0, 0.2, 0)
MainWindow.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainWindow.BorderSizePixel = 0
MainWindow.Active = true
MainWindow.Draggable = true
MainWindow.Visible = true
MainWindow.Parent = UIContainer

local MainCorner = Instance.new("UICorner", MainWindow)
MainCorner.CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", MainWindow)
MainStroke.Color = Color3.fromRGB(30, 30, 45)
MainStroke.Thickness = 1.5

-- Header Title
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Header.Parent = MainWindow

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 10)

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -15, 1, 0)
HeaderTitle.Position = UDim2.new(0, 15, 0, 0)
HeaderTitle.Text = "SLAX HUB v2.5 | INVIS & XENO"
HeaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderTitle.TextSize = 13
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Parent = Header

-- Scroll Container
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -60)
ScrollFrame.Position = UDim2.new(0, 10, 0, 50)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
ScrollFrame.Parent = MainWindow

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Parent = ScrollFrame
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Padding = UDim.new(0, 8)

-- UI Toggle Factory Function
local function AddToggleOption(labelText, configParam)
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(1, 0, 0, 38)
    ToggleBtn.BackgroundColor3 = SlaxConfig[configParam] and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(25, 25, 35)
    ToggleBtn.Text = "   " .. labelText
    ToggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    ToggleBtn.TextSize = 12
    ToggleBtn.Font = Enum.Font.GothamSemibold
    ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left
    ToggleBtn.Parent = ScrollFrame

    local BtnCorner = Instance.new("UICorner", ToggleBtn)
    BtnCorner.CornerRadius = UDim.new(0, 6)

    local Indicator = Instance.new("Frame")
    Indicator.Size = UDim2.new(0, 12, 0, 12)
    Indicator.Position = UDim2.new(0.9, -10, 0.5, -6)
    Indicator.BackgroundColor3 = SlaxConfig[configParam] and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(60, 60, 75)
    Indicator.Parent = ToggleBtn

    local IndCorner = Instance.new("UICorner", Indicator)
    IndCorner.CornerRadius = UDim.new(1, 0)

    ToggleBtn.MouseButton1Click:Connect(function()
        SlaxConfig[configParam] = not SlaxConfig[configParam]
        
        -- Smooth UI transition
        TweenService:Create(ToggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = SlaxConfig[configParam] and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(25, 25, 35)
        }):Play()

        TweenService:Create(Indicator, TweenInfo.new(0.2), {
            BackgroundColor3 = SlaxConfig[configParam] and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(60, 60, 75)
        }):Play()

        -- Dynamic updates
        if configParam == "PlayerESP" then
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("SlaxHighlight") then
                    p.Character.SlaxHighlight.Enabled = SlaxConfig.PlayerESP
                end
            end
        end
    end)
end

-- [SECTION 10: POPULATING INTERFACE CONTROL ELEMENTS]
AddToggleOption("Auto Parry (Physics Engine)", "AutoParry")
AddToggleOption("Anti-Curve Angle Resolver", "AntiCurve")
AddToggleOption("Auto Spam Engine (Clash)", "AutoSpam")
AddToggleOption("Smart Auto Ability (Q Key)", "AutoAbility")
AddToggleOption("Dynamic Ping Compensation", "DynamicPingCompensation")
AddToggleOption("Player Wallhack (ESP)", "PlayerESP")
AddToggleOption("Auto Jump On Land", "AutoJump")

-- Update Canvas Size Automatically
ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 15)
end)

-- Toggle Visibility Handler
FloatButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

-- Final Startup Print
print("==================================================")
print(" Slax Hub v2.5 Executed Successfully!")
print(" Detected Executor: " .. ExecutorInfo.Name)
print(" Developer: yossef")
print("==================================================")
