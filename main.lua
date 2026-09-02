-- ==========================================
-- 📱 BLADE BALL FIXED FOR DELTA (V9)
-- Anti-Error + Manual Spam UI + Auto Parry
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
    ParryRange = 35
}

-- --- ADVANCED EVENT FINDER (FIXED) ---
local function getParryRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local p = remotes:FindFirstChild("ParryButtonPress") or remotes:FindFirstChild("ParryAttempt")
        if p then return p end
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("parry") or v.Name:lower():find("swing")) then
            return v
        end
    end
    return nil
end

local ParryRemote = getParryRemote()

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

-- --- AUTO PARRY LOOP ---
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
            if distance <= Settings.ParryRange then
                executeParry()
            end
        end
    end
end)

-- --- GUI WINDOW ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaBladeBallUI"
ScreenGui.Parent = game.CoreGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 210, 0, 160)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "⚡ Delta Blade Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14
Title.BackgroundTransparency = 1

-- Auto Parry Button
local AutoBtn = Instance.new("TextButton", MainFrame)
AutoBtn.Size = UDim2.new(0.9, 0, 0, 38)
AutoBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
AutoBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
AutoBtn.TextColor3 = Color3.fromRGB(0, 255, 127)
AutoBtn.Text = "AUTO PARRY: ON ✅"
AutoBtn.Font = Enum.Font.SourceSansBold
AutoBtn.TextSize = 13
Instance.new("UICorner", AutoBtn).CornerRadius = UDim.new(0, 6)

AutoBtn.MouseButton1Click:Connect(function()
    Settings.AutoParry = not Settings.AutoParry
    AutoBtn.Text = Settings.AutoParry and "AUTO PARRY: ON ✅" or "AUTO PARRY: OFF ❌"
    AutoBtn.TextColor3 = Settings.AutoParry and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(255, 60, 60)
    AutoBtn.BackgroundColor3 = Settings.AutoParry and Color3.fromRGB(20, 60, 30) or Color3.fromRGB(50, 25, 25)
end)

-- Manual Spam Button
local SpamBtn = Instance.new("TextButton", MainFrame)
SpamBtn.Size = UDim2.new(0.9, 0, 0, 38)
SpamBtn.Position = UDim2.new(0.05, 0, 0.58, 0)
SpamBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
SpamBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
SpamBtn.Text = "MANUAL SPAM: OFF ❌"
SpamBtn.Font = Enum.Font.SourceSansBold
SpamBtn.TextSize = 13
Instance.new("UICorner", SpamBtn).CornerRadius = UDim.new(0, 6)

SpamBtn.MouseButton1Click:Connect(function()
    Settings.ManualSpam = not Settings.ManualSpam
    SpamBtn.Text = Settings.ManualSpam and "MANUAL SPAM: ON 🔥" or "MANUAL SPAM: OFF ❌"
    SpamBtn.TextColor3 = Settings.ManualSpam and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 60, 60)
    SpamBtn.BackgroundColor3 = Settings.ManualSpam and Color3.fromRGB(80, 50, 10) or Color3.fromRGB(50, 25, 25)
end)

print("✅ Script Fixed & Ready!")
