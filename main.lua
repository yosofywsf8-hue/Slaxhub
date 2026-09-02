-- ==========================================
-- 📱 BLADE BALL FULL UI SCRIPT (V8)
-- Custom UI with Auto Parry & Manual Spam Toggles
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION ---
local Settings = {
    AutoParry = true,
    ManualSpam = false,
    SpamDelay = 0.005,
    ParryRange = 35,
    DynamicTiming = true,
    PingOffset = 0.05
}

-- --- REMOTES SETUP ---
local ParryRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ParryButtonPress")
if not ParryRemote then
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:find("Parry") or v.Name:find("Swing")) then
            ParryRemote = v
            break
        end
    end
end

-- --- EXECUTE PARRY FUNCTION ---
local function executeParry()
    if ParryRemote then
        ParryRemote:FireServer()
    else
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.001)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end

-- --- MANUAL SPAM LOOP ---
task.spawn(function()
    while true do
        if Settings.ManualSpam then
            executeParry()
            task.wait(Settings.SpamDelay)
        else
            task.wait(0.05)
        end
    end
end)

-- --- BALL DETECTION FOR AUTO PARRY ---
local function getTargetBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:GetAttribute("realBall") == true or ball:FindFirstChild("Ball") then
            return ball
        end
    end
    return ballsFolder:GetChildren()[1]
end

RunService.PreRender:Connect(function()
    if not Settings.AutoParry or Settings.ManualSpam then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ball = getTargetBall()
    
    if ball and ball:FindFirstChild("AssemblyLinearVelocity") then
        local ballTarget = ball:GetAttribute("target") or ball:GetAttribute("Target")
        
        if ballTarget == LocalPlayer.Name or (ball:FindFirstChild("Highlight") and ball.Highlight.FillColor == Color3.fromRGB(255, 0, 0)) then
            local distance = (rootPart.Position - ball.Position).Magnitude
            local ballSpeed = ball.AssemblyLinearVelocity.Magnitude
            
            local dynamicDistance = Settings.ParryRange
            if Settings.DynamicTiming and ballSpeed > 0 then
                dynamicDistance = math.clamp((ballSpeed * 0.15) + (Settings.PingOffset * 10), 20, 80)
            end
            
            if distance <= dynamicDistance then
                executeParry()
            end
        end
    end
end)

-- ==========================================
-- 🎨 CUSTOM GUI CREATION
-- ==========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallCustomUI"
ScreenGui.Parent = game.CoreGui

-- Main Container (Window)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

-- Title Bar
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleText = Instance.new("TextLabel", TitleBar)
TitleText.Size = UDim2.new(1, -10, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.Text = "⚔️ Blade Ball Hub"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 15
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.BackgroundTransparency = 1

-- Toggle 1: Auto Parry Button
local AutoBtn = Instance.new("TextButton", MainFrame)
AutoBtn.Size = UDim2.new(0.9, 0, 0, 40)
AutoBtn.Position = UDim2.new(0.05, 0, 0.28, 0)
AutoBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
AutoBtn.TextColor3 = Color3.fromRGB(0, 255, 127)
AutoBtn.Text = "AUTO PARRY: ON ✅"
AutoBtn.Font = Enum.Font.SourceSansBold
AutoBtn.TextSize = 13
Instance.new("UICorner", AutoBtn).CornerRadius = UDim.new(0, 8)

AutoBtn.MouseButton1Click:Connect(function()
    Settings.AutoParry = not Settings.AutoParry
    if Settings.AutoParry then
        AutoBtn.Text = "AUTO PARRY: ON ✅"
        AutoBtn.TextColor3 = Color3.fromRGB(0, 255, 127)
        AutoBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    else
        AutoBtn.Text = "AUTO PARRY: OFF ❌"
        AutoBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
        AutoBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
    end
end)

-- Toggle 2: Manual Spam Button
local SpamBtn = Instance.new("TextButton", MainFrame)
SpamBtn.Size = UDim2.new(0.9, 0, 0, 40)
SpamBtn.Position = UDim2.new(0.05, 0, 0.58, 0)
SpamBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
SpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
SpamBtn.Text = "MANUAL SPAM: OFF ❌"
SpamBtn.Font = Enum.Font.SourceSansBold
SpamBtn.TextSize = 13
Instance.new("UICorner", SpamBtn).CornerRadius = UDim.new(0, 8)

SpamBtn.MouseButton1Click:Connect(function()
    Settings.ManualSpam = not Settings.ManualSpam
    if Settings.ManualSpam then
        SpamBtn.Text = "MANUAL SPAM: ON 🔥"
        SpamBtn.TextColor3 = Color3.fromRGB(255, 170, 0)
        SpamBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 10)
    else
        SpamBtn.Text = "MANUAL SPAM: OFF ❌"
        SpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
        SpamBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
    end
end)

print("✅ Blade Ball Full UI Loaded Successfully!")
