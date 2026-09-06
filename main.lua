-- Timebomb Duels Mobile - Smooth Arena Auto Play
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
ToggleCircle.Text = "⚡"
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
Title.Text = "⚡ Smooth Arena Follower"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
Title.BorderSizePixel = 0
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
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
AutoPlayBtn.Text = "Auto Play: OFF"
AutoPlayBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPlayBtn.Font = Enum.Font.GothamBold
AutoPlayBtn.TextSize = 14
AutoPlayBtn.AutoButtonColor = false
AutoPlayBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 10)
BtnCorner.Parent = AutoPlayBtn

-- Status Text
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

AutoPlayBtn.MouseButton1Click:Connect(function()
    isAutoPlayOn = not isAutoPlayOn
    if isAutoPlayOn then
        AutoPlayBtn.Text = "Auto Play: ON"
        animateColor(AutoPlayBtn, Color3.fromRGB(40, 167, 69))
        StatusLabel.Text = "Status: Active in Arena"
        StatusLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    else
        AutoPlayBtn.Text = "Auto Play: OFF"
        animateColor(AutoPlayBtn, Color3.fromRGB(220, 53, 69))
        StatusLabel.Text = "Status: Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(130, 135, 150)
    end
end)

-- Check if player is inside Match / Arena (Not in Lobby)
local function isInMatch(player)
    if not player or not player.Character then return false end
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    if not hrp or not hum or hum.Health <= 0 then return false end
    
    -- تجاهل اللاعبين في اللوبي إذا كانت المسافة بعيدة جداً عن الحلبة المباشرة
    -- أو إذا كان لديهم عناصر القيم (قنبلة / أدوات قيم)
    local hasBomb = char:FindFirstChild("Bomb") or player.Backpack:FindFirstChild("Bomb")
    return true
end

-- Find Arena Target Player Only
local function getInGameTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    
    local nearest = nil
    local shortestDist = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = player.Character.HumanoidRootPart
            local dist = (myPos - targetHRP.Position).Magnitude
            
            -- تصفية: لا يطارد اللاعبين البعيدين جداً الذين يقفون في اللوبي (أكبر من 150 ستود)
            if dist < 150 then
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- Smooth Movement Engine
local currentWaypointIndex = 1
local currentWaypoints = {}

RunService.RenderStepped:Connect(function()
    if not isAutoPlayOn then return end
    
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") or not myChar:FindFirstChild("Humanoid") then return end
    
    local myHRP = myChar.HumanoidRootPart
    local humanoid = myChar.Humanoid
    
    local targetPlayer = getInGameTarget()
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        StatusLabel.Text = "Status: Waiting for Game..."
        return
    end

    StatusLabel.Text = "Status: Chasing Opponent"
    local targetHRP = targetPlayer.Character.HumanoidRootPart
    local distToTarget = (myHRP.Position - targetHRP.Position).Magnitude
    
    -- إذا كان في مجال الرؤية والقرب، ملاحقة مباشرة بدون توقف (حركة سلسة 100%)
    if distToTarget < 20 then
        humanoid:MoveTo(targetHRP.Position)
    else
        -- حساب المسار للالتفاف حول الجدران دون تلعثم
        local ray = Ray.new(myHRP.Position, (targetHRP.Position - myHRP.Position).Unit * distToTarget)
        local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, {myChar, targetPlayer.Character})
        
        if not hitPart then
            -- لا توجد جدران تعترض الطريق: اركض مباشرة بسرعة وسلاسة
            humanoid:MoveTo(targetHRP.Position)
        else
            -- توجد جدران: استخدم نقاط المسار بسلاسة
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true
            })
            pcall(function()
                path:ComputeAsync(myHRP.Position, targetHRP.Position)
                if path.Status == Enum.PathStatus.Success then
                    local waypoints = path:GetWaypoints()
                    if #waypoints >= 2 then
                        if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
                        humanoid:MoveTo(waypoints[2].Position)
                    end
                else
                    humanoid:MoveTo(targetHRP.Position)
                end
            end)
        end
    end
end)
