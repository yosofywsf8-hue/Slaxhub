-- ==========================================
-- 📱 BLADE BALL MANUAL SPAM + AUTO PARRY (V7)
-- Fully Manual Controlled UI
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION ---
local Settings = {
    AutoParry = false,
    ManualSpam = false,
    SpamDelay = 0.005, -- سرعة الضغط أثناء التفعيل (بالثواني)
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

-- --- UI PANEL ---
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 150, 0, 110)
MainFrame.Position = UDim2.new(0.02, 0, 0.35, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "BLADE BALL MENU"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 12
Title.BackgroundTransparency = 1

-- Toggle 1: Manual Spam
local SpamToggle = Instance.new("TextButton", MainFrame)
SpamToggle.Size = UDim2.new(0.9, 0, 0, 32)
SpamToggle.Position = UDim2.new(0.05, 0, 0.28, 0)
SpamToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
SpamToggle.TextColor3 = Color3.fromRGB(255, 50, 50)
SpamToggle.Text = "MANUAL SPAM: OFF"
SpamToggle.Font = Enum.Font.SourceSansBold
SpamToggle.TextSize = 12
Instance.new("UICorner", SpamToggle).CornerRadius = UDim.new(0, 6)

SpamToggle.MouseButton1Click:Connect(function()
    Settings.ManualSpam = not Settings.ManualSpam
    if Settings.ManualSpam then
        SpamToggle.Text = "MANUAL SPAM: ON 🔥"
        SpamToggle.TextColor3 = Color3.fromRGB(0, 255, 127)
        SpamToggle.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    else
        SpamToggle.Text = "MANUAL SPAM: OFF"
        SpamToggle.TextColor3 = Color3.fromRGB(255, 50, 50)
        SpamToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
end)

-- Toggle 2: Auto Parry
local AutoToggle = Instance.new("TextButton", MainFrame)
AutoToggle.Size = UDim2.new(0.9, 0, 0, 32)
AutoToggle.Position = UDim2.new(0.05, 0, 0.63, 0)
AutoToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
AutoToggle.TextColor3 = Color3.fromRGB(255, 50, 50)
AutoToggle.Text = "AUTO PARRY: OFF"
AutoToggle.Font = Enum.Font.SourceSansBold
AutoToggle.TextSize = 12
Instance.new("UICorner", AutoToggle).CornerRadius = UDim.new(0, 6)

AutoToggle.MouseButton1Click:Connect(function()
    Settings.AutoParry = not Settings.AutoParry
    if Settings.AutoParry then
        AutoToggle.Text = "AUTO PARRY: ON"
        AutoToggle.TextColor3 = Color3.fromRGB(0, 255, 127)
        AutoToggle.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    else
        AutoToggle.Text = "AUTO PARRY: OFF"
        AutoToggle.TextColor3 = Color3.fromRGB(255, 50, 50)
        AutoToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
end)

print("✅ UI Loaded Successfully!")
