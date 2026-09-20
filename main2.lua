--[[
    ================================================================================
    SLAX HUB v3.0 - MOBILE ULTIMATE EDITION (TOUCH OPTIMIZED)
    Target Game: Blade Ball (Roblox Mobile)
    Author: yossef
    Supported Executors: Delta, Codex, Vega X, Arceus X, Fluxus Mobile, Hydrogen
    ================================================================================
--]]

if getgenv().SlaxHubMobileLoaded then
    return
end
getgenv().SlaxHubMobileLoaded = true

-- [SERVICES]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- [CONFIG]
local SlaxConfig = {
    AutoParry = true,
    AntiCurve = true,
    CurveMultiplier = 1.4,
    ParryDistance = 28,
    BasePredictionTime = 0.17,
    DynamicPing = true,
    
    AutoSpam = false,
    TouchSpamActive = false,
    SpamDistance = 15,
    SpamDelay = 0.005,
    
    AutoAbility = true,
    AbilityDistance = 16,
    AutoJump = false,
    AntiAFK = true,
    
    PlayerESP = true,
    ESPColor = Color3.fromRGB(0, 255, 170)
}

-- [INPUT DISPATCHER - MOBILE SAFE]
local function TriggerParry()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- [BALL DETECTOR]
local function GetBall()
    local container = Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("TrainingBalls")
    if not container then return nil end

    for _, obj in pairs(container:GetChildren()) do
        if obj:IsA("BasePart") and (obj:GetAttribute("realBall") == true or obj:FindFirstChild("zoomies") or obj.Name == "RealBall") then
            return obj
        end
    end
    return nil
end

local function IsTargetingMe(ball)
    if not ball then return false end
    local targetVal = ball:GetAttribute("target") or (ball:FindFirstChild("target") and ball.target.Value)
    if type(targetVal) == "string" then
        return targetVal == LocalPlayer.Name
    elseif typeof(targetVal) == "Instance" and targetVal:IsA("Player") then
        return targetVal == LocalPlayer
    end
    return false
end

-- [MATH & PHYSICS ENGINE]
RunService.PreRender:Connect(function()
    if not SlaxConfig.AutoParry then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = GetBall()
    if not ball or not IsTargetingMe(ball) then return end

    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    local distance = (ballPos - hrp.Position).Magnitude
    local speed = ballVel.Magnitude

    if speed > 0.1 then
        local ping = 0
        if SlaxConfig.DynamicPing then
            local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pingStat then ping = (pingStat:GetValue() / 1000) end
        end

        local curveFactor = 1
        if SlaxConfig.AntiCurve then
            local dirToPlayer = (hrp.Position - ballPos).Unit
            local ballDir = ballVel.Unit
            local dot = ballDir:Dot(dirToPlayer)
            if dot < 0.7 then
                curveFactor = (1 - math.clamp(dot, -1, 1)) * SlaxConfig.CurveMultiplier
            end
        end

        local timeToReach = (distance / speed) - ping
        local threshold = (SlaxConfig.ParryDistance + (curveFactor * 8))

        if timeToReach <= SlaxConfig.BasePredictionTime or distance <= threshold then
            TriggerParry()

            if SlaxConfig.AutoAbility and distance <= SlaxConfig.AbilityDistance then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end
        end
    end
end)

-- [SPAM LOOP]
task.spawn(function()
    while true do
        task.wait(SlaxConfig.SpamDelay)
        if SlaxConfig.AutoSpam or SlaxConfig.TouchSpamActive then
            local ball = GetBall()
            local char = LocalPlayer.Character
            if ball and char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (ball.Position - char.HumanoidRootPart.Position).Magnitude
                if dist <= SlaxConfig.SpamDistance or SlaxConfig.TouchSpamActive then
                    TriggerParry()
                end
            end
        end
    end
end)

-- [AUTO JUMP & ANTI-AFK]
RunService.Stepped:Connect(function()
    if SlaxConfig.AutoJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Landed then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

if SlaxConfig.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
    end)
end

-- [ESP SYSTEM]
local function ApplyESP(plr)
    if plr == LocalPlayer then return end
    local function AddHighlight(char)
        if not char then return end
        local hl = Instance.new("Highlight")
        hl.Name = "SlaxHighlight"
        hl.FillColor = SlaxConfig.ESPColor
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.6
        hl.Enabled = SlaxConfig.PlayerESP
        hl.Parent = char
    end
    plr.CharacterAdded:Connect(AddHighlight)
    if plr.Character then AddHighlight(plr.Character) end
end

for _, p in pairs(Players:GetPlayers()) do ApplyESP(p) end
Players.PlayerAdded:Connect(ApplyESP)

-- [MOBILE GUI INTERFACE]
local UIContainer = Instance.new("ScreenGui")
UIContainer.Name = "SlaxHubMobile_v3"
UIContainer.ResetOnSpawn = false
UIContainer.Parent = (gethui and gethui()) or CoreGui

for _, old in pairs(CoreGui:GetChildren()) do
    if old.Name == "SlaxHubMobile_v3" and old ~= UIContainer then
        old:Destroy()
    end
end

-- 1. Floating Menu Button
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "SlaxFloatBtn"
FloatBtn.Size = UDim2.new(0, 60, 0, 60)
FloatBtn.Position = UDim2.new(0.03, 0, 0.15, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
FloatBtn.Text = "SLAX"
FloatBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
FloatBtn.TextSize = 14
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.Active = true
FloatBtn.Draggable = true
FloatBtn.Parent = UIContainer

local FloatCorner = Instance.new("UICorner", FloatBtn)
FloatCorner.CornerRadius = UDim.new(1, 0)

local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.fromRGB(0, 255, 170)
FloatStroke.Thickness = 2.5

-- 2. Dedicated Touch Spam Overlay Button (For Mobile Clash)
local TouchSpamBtn = Instance.new("TextButton")
TouchSpamBtn.Name = "TouchSpamBtn"
TouchSpamBtn.Size = UDim2.new(0, 75, 0, 75)
TouchSpamBtn.Position = UDim2.new(0.82, 0, 0.55, 0)
TouchSpamBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TouchSpamBtn.Text = "SPAM\nOFF"
TouchSpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
TouchSpamBtn.TextSize = 13
TouchSpamBtn.Font = Enum.Font.GothamBold
TouchSpamBtn.Active = true
TouchSpamBtn.Draggable = true
TouchSpamBtn.Parent = UIContainer

local SpamCorner = Instance.new("UICorner", TouchSpamBtn)
SpamCorner.CornerRadius = UDim.new(1, 0)

local SpamStroke = Instance.new("UIStroke", TouchSpamBtn)
SpamStroke.Color = Color3.fromRGB(255, 60, 60)
SpamStroke.Thickness = 2.5

TouchSpamBtn.MouseButton1Click:Connect(function()
    SlaxConfig.TouchSpamActive = not SlaxConfig.TouchSpamActive
    if SlaxConfig.TouchSpamActive then
        TouchSpamBtn.Text = "SPAM\nON"
        TouchSpamBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        SpamStroke.Color = Color3.fromRGB(0, 255, 170)
        TouchSpamBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 80)
    else
        TouchSpamBtn.Text = "SPAM\nOFF"
        TouchSpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
        SpamStroke.Color = Color3.fromRGB(255, 60, 60)
        TouchSpamBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    end
end)

-- 3. Main GUI Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 310, 0, 380)
MainWindow.Position = UDim2.new(0.5, -155, 0.5, -190)
MainWindow.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainWindow.Active = true
MainWindow.Draggable = true
MainWindow.Visible = true
MainWindow.Parent = UIContainer

local MainCorner = Instance.new("UICorner", MainWindow)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainWindow)
MainStroke.Color = Color3.fromRGB(35, 35, 50)
MainStroke.Thickness = 2

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Header.Parent = MainWindow

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Text = "SLAX HUB MOBILE v3.0"
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.BackgroundTransparency = 1
Title.Parent = Header

-- Scroll List
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -55)
Scroll.Position = UDim2.new(0, 10, 0, 50)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
Scroll.Parent = MainWindow

local Layout = Instance.new("UIListLayout")
Layout.Parent = Scroll
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 10)

-- Mobile Toggle Creator
local function AddMobileToggle(text, configKey)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 45) -- Larger touch target for mobile
    Btn.BackgroundColor3 = SlaxConfig[configKey] and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(25, 25, 35)
    Btn.Text = "  " .. text
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 13
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = Scroll

    local Corner = Instance.new("UICorner", Btn)
    Corner.CornerRadius = UDim.new(0, 8)

    local StateBox = Instance.new("Frame")
    StateBox.Size = UDim2.new(0, 18, 0, 18)
    StateBox.Position = UDim2.new(0.9, -15, 0.5, -9)
    StateBox.BackgroundColor3 = SlaxConfig[configKey] and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(60, 60, 75)
    StateBox.Parent = Btn

    local BoxCorner = Instance.new("UICorner", StateBox)
    BoxCorner.CornerRadius = UDim.new(1, 0)

    Btn.MouseButton1Click:Connect(function()
        SlaxConfig[configKey] = not SlaxConfig[configKey]
        
        TweenService:Create(Btn, TweenInfo.new(0.2), {
            BackgroundColor3 = SlaxConfig[configKey] and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(25, 25, 35)
        }):Play()

        TweenService:Create(StateBox, TweenInfo.new(0.2), {
            BackgroundColor3 = SlaxConfig[configKey] and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(60, 60, 75)
        }):Play()

        if configKey == "PlayerESP" then
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("SlaxHighlight") then
                    p.Character.SlaxHighlight.Enabled = SlaxConfig.PlayerESP
                end
            end
        end
    end)
end

-- Toggles
AddMobileToggle("Auto Parry", "AutoParry")
AddMobileToggle("Anti-Curve Engine", "AntiCurve")
AddMobileToggle("Auto Spam (Clash)", "AutoSpam")
AddMobileToggle("Smart Auto Ability", "AutoAbility")
AddMobileToggle("Player ESP", "PlayerESP")
AddMobileToggle("Auto Jump", "AutoJump")

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 15)
end)

FloatBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

print("Slax Hub Mobile Loaded Successfully!")
