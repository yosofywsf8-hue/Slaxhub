-- 🏆 Blade Ball Lag-Free & Anti-Freeze Mobile Engine
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local Config = {
    Active = true,
    ParryRange = 36,
    SlashRange = 50,
    Cooldown = 0.5,
}

-- البحث عن زر الصد الحقيقي في واجهة اللعبة
local function getParryButtonUI()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("GuiButton") and (string.lower(gui.Name):find("parry") or string.lower(gui.Name):find("ability") or string.lower(gui.Name):find("skill")) then
                return gui
            end
        end
    end
    return nil
end

-- واجهة الجوال
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BladeBallInstantGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 160, 0, 30)
statusLabel.Position = UDim2.new(0.5, -80, 0.02, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.Text = "🛡️ Smooth: ON"
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.Parent = screenGui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 6)
corner1.Parent = statusLabel

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 90, 0, 45)
toggleButton.Position = UDim2.new(0.85, -10, 0.2, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "ON 🟢"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.Parent = screenGui

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 10)
corner2.Parent = toggleButton

toggleButton.MouseButton1Click:Connect(function()
    Config.Active = not Config.Active
    if Config.Active then
        toggleButton.Text = "ON 🟢"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        statusLabel.Text = "🛡️ Smooth: ON"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    else
        toggleButton.Text = "OFF 🔴"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        statusLabel.Text = "❌ Engine: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end)

local function findBall()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and (obj.Name == "Ball" or obj.Name == "DefaultBall" or obj:FindFirstChild("Trail")) then
            return obj
        end
    end
    if Workspace:FindFirstChild("Balls") then
        for _, obj in ipairs(Workspace.Balls:GetChildren()) do
            if obj:IsA("BasePart") then return obj end
        end
    end
    return nil
end

local lastPos = Vector3.new()
local lastTick = tick()
local lastParryTime = 0

-- حلقة خالية من أي تجميد أو توقف للحركة
RunService.Heartbeat:Connect(function()
    if not Config.Active then return end
    
    local ball = findBall()
    if not ball then return end
    
    local currentTick = tick()
    local deltaTime = currentTick - lastTick
    if deltaTime <= 0 then deltaTime = 0.01 end
    
    local speed = (ball.Position - lastPos).Magnitude / deltaTime
    lastPos = ball.Position
    lastTick = currentTick
    
    local dist = (rootPart.Position - ball.Position).Magnitude
    local activeRange = Config.ParryRange
    if speed > 110 then
        activeRange = Config.SlashRange
    end
    
    if dist <= activeRange then
        if (currentTick - lastParryTime) >= Config.Cooldown then
            lastParryTime = currentTick
            
            -- تنفيذ الضغط الفوري في مسار منفصل (Task) لمنع تجميد حركة اللاعب نهائياً
            task.spawn(function()
                local parryBtn = getParryButtonUI()
                if parryBtn then
                    local absPos = parryBtn.AbsolutePosition
                    local absSize = parryBtn.AbsoluteSize
                    local clickX = absPos.X + (absSize.X / 2)
                    local clickY = absPos.Y + (absSize.Y / 2)
                    
                    VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
                    task.wait(0.01) -- وقت قصير جداً لا يؤثر على حركة الشخصية
                    VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
                end
            end)
        end
    end
end)

print("🏆 Smooth Anti-Freeze Engine Loaded!")
