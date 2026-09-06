-- Timebomb Duels Mobile - Smart Pathfinding Auto Follow (Wall-Bypass)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

-- Clean previous GUI if exists
if LocalPlayer.PlayerGui:FindFirstChild("TimebombMobileGUI") then
    LocalPlayer.PlayerGui.TimebombMobileGUI:Destroy()
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimebombMobileGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Floating Toggle Circle Button
local ToggleCircle = Instance.new("TextButton")
ToggleCircle.Size = UDim2.new(0, 45, 0, 45)
ToggleCircle.Position = UDim2.new(0.02, 0, 0.2, 0)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
ToggleCircle.Text = "🧠"
ToggleCircle.TextSize = 22
ToggleCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(80, 90, 110)
CircleStroke.Thickness = 2
CircleStroke.Parent = ToggleCircle

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 150)
MainFrame.Position = UDim2.new(0.15, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainUICorner = Instance.new("UICorner")
MainUICorner.CornerRadius = UDim.new(0, 14)
MainUICorner.Parent = MainFrame

local MainUIStroke = Instance.new("UIStroke")
MainUIStroke.Color = Color3.fromRGB(50, 55, 70)
MainUIStroke.Thickness = 1.5
MainUIStroke.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "⚡ Smart AI Follower"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
Title.BorderSizePixel = 0
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent = Title

-- Toggle GUI Visibility
ToggleCircle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Auto Play Button
local AutoPlayBtn = Instance.new("TextButton")
AutoPlayBtn.Size = UDim2.new(0.85, 0, 0, 45)
AutoPlayBtn.Position = UDim2.new(0.075, 0, 0.35, 0)
AutoPlayBtn.Text = "Smart AI: OFF"
AutoPlayBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPlayBtn.Font = Enum.Font.GothamBold
AutoPlayBtn.TextSize = 14
AutoPlayBtn.AutoButtonColor = false
AutoPlayBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 10)
BtnCorner.Parent = AutoPlayBtn

-- Status Indicator Text
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0.78, 0)
StatusLabel.Text = "Status: Disabled"
StatusLabel.TextColor3 = Color3.fromRGB(130, 135, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.Parent = MainFrame

local function animateColor(object, targetColor)
    TweenService:Create(object, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = targetColor
    }):Play()
end

local isAutoPlayOn = false

-- Button Toggle Action
AutoPlayBtn.MouseButton1Click:Connect(function()
    isAutoPlayOn = not isAutoPlayOn
    if isAutoPlayOn then
        AutoPlayBtn.Text = "Smart AI: ON"
        animateColor(AutoPlayBtn, Color3.fromRGB(40, 167, 69))
        StatusLabel.Text = "Status: Smart Pathfinding..."
        StatusLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    else
        AutoPlayBtn.Text = "Smart AI: OFF"
        animateColor(AutoPlayBtn, Color3.fromRGB(220, 53, 69))
        StatusLabel.Text = "Status: Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(130, 135, 150)
    end
end)

-- Helper: Get Nearest Alive Player
local function getNearestPlayer()
    local nearest = nil
    local shortestDist = math.huge
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (myChar.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- Smart Pathfinding System
local lastPathTime = 0

RunService.Heartbeat:Connect(function()
    if not isAutoPlayOn then return end
    
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") or not myChar:FindFirstChild("Humanoid") then return end
    
    local targetPlayer = getNearestPlayer()
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local myHRP = myChar.HumanoidRootPart
    local targetHRP = targetPlayer.Character.HumanoidRootPart
    local humanoid = myChar.Humanoid
    local dist = (myHRP.Position - targetHRP.Position).Magnitude

    -- إذا كان قريب جداً ومكشوف مباشرة (لا توجد جدران)، تحرك إليه مباشرة بسرعة
    if dist < 12 then
        humanoid:MoveTo(targetHRP.Position)
    else
        -- تحديث المسار الذكي كل 0.25 ثانية لتجنب التأخير والتعليق
        if tick() - lastPathTime > 0.25 then
            lastPathTime = tick()
            
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentJumpHeight = 10,
            })
            
            pcall(function()
                path:ComputeAsync(myHRP.Position, targetHRP.Position)
                if path.Status == Enum.PathStatus.Success then
                    local waypoints = path:GetWaypoints()
                    -- التحرك نحو ثاني نقطة مسار للتفاف حقيقي حول الزوايا والجدران
                    if #waypoints >= 2 then
                        if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
                        humanoid:MoveTo(waypoints[2].Position)
                    end
                else
                    -- في حال فشل المسار، التحرك المباشر
                    humanoid:MoveTo(targetHRP.Position)
                end
            end)
        end
    end
end)
