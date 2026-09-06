-- Timebomb Duels Mobile - Smart Wall Bypass with Custom Credits
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Cleanup previous GUI
if LocalPlayer.PlayerGui:FindFirstChild("TimebombCreditGUI") then
    LocalPlayer.PlayerGui.TimebombCreditGUI:Destroy()
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimebombCreditGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Draggable Floating Circle Button
local ToggleCircle = Instance.new("TextButton")
ToggleCircle.Size = UDim2.new(0, 50, 0, 50)
ToggleCircle.Position = UDim2.new(0.02, 0, 0.25, 0)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
ToggleCircle.Text = "💣"
ToggleCircle.TextSize = 24
ToggleCircle.Active = true
ToggleCircle.Draggable = true
ToggleCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(90, 100, 125)
CircleStroke.Thickness = 2
CircleStroke.Parent = ToggleCircle

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 180)
MainFrame.Position = UDim2.new(0.18, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 55, 70)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Title Bar
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.75, 0, 0, 30)
Title.Position = UDim2.new(0.04, 0, 0.02, 0)
Title.Text = "Timebomb Auto-Pass"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

-- Credits Label (Made by aki | TikTok: 1x.ud | DC: oa2a)
local Credits = Instance.new("TextLabel")
Credits.Size = UDim2.new(0.92, 0, 0, 18)
Credits.Position = UDim2.new(0.04, 0, 0.19, 0)
Credits.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
Credits.TextColor3 = Color3.fromRGB(160, 170, 190)
Credits.BackgroundTransparency = 1
Credits.Font = Enum.Font.Gotham
Credits.TextSize = 10
Credits.TextXAlignment = Enum.TextXAlignment.Left
Credits.Parent = MainFrame

-- Close Button (X in Corner)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(0.85, 0, 0.05, 0)
CloseBtn.Text = "❌"
CloseBtn.TextSize = 11
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Toggle Button (ON / OFF)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.92, 0, 0, 42)
ToggleBtn.Position = UDim2.new(0.04, 0, 0.38, 0)
ToggleBtn.Text = "Auto Play: OFF"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = ToggleBtn

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0.82, 0)
StatusLabel.Text = "Status: OFF"
StatusLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

local isScriptActive = false

-- Open / Hide GUI via Circle Button
ToggleCircle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Close Script Permanently
CloseBtn.MouseButton1Click:Connect(function()
    isScriptActive = false
    ScreenGui:Destroy()
end)

-- Toggle Button State
ToggleBtn.MouseButton1Click:Connect(function()
    isScriptActive = not isScriptActive
    if isScriptActive then
        ToggleBtn.Text = "Auto Play: ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
        StatusLabel.Text = "Status: Active (Waiting)"
        StatusLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    else
        ToggleBtn.Text = "Auto Play: OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        StatusLabel.Text = "Status: OFF"
        StatusLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
    end
end)

-- Check if player currently holds the Bomb
local function holdsBomb()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    
    local inChar = myChar:FindFirstChild("Bomb") or myChar:FindFirstChildWhichIsA("Tool")
    if inChar and string.find(string.lower(inChar.Name), "bomb") then
        return true
    end
    
    local inBackpack = LocalPlayer.Backpack:FindFirstChild("Bomb") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if inBackpack and string.find(string.lower(inBackpack.Name), "bomb") then
        return true
    end
    
    return false
end

-- Get Opponent Target in Arena
local function getArenaTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    
    local nearest = nil
    local shortestDist = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < 120 and dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- Main Stepped Loop (Smart Raycast Steering Around Walls)
RunService.Stepped:Connect(function()
    if not isScriptActive then return end
    
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or not myChar:FindFirstChild("HumanoidRootPart") then return end
    
    local humanoid = myChar.Humanoid
    local hrp = myChar.HumanoidRootPart
    
    if holdsBomb() then
        local targetPlayer = getArenaTarget()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "Status: PASSING BOMB!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            
            local targetHRP = targetPlayer.Character.HumanoidRootPart
            local moveTargetPos = targetHRP.Position
            
            -- فحص وجود جدار معترض
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {myChar, targetPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local dirToTarget = (targetHRP.Position - hrp.Position)
            local rayResult = workspace:Raycast(hrp.Position, dirToTarget, raycastParams)
            
            -- الانحراف والانزلاق حول الجدار بشكل آمن
            if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
                local normal = rayResult.Normal
                local sideVector = Vector3.new(-normal.Z, 0, normal.X)
                
                moveTargetPos = hrp.Position + (dirToTarget.Unit + sideVector).Unit * 6
            end
            
            humanoid:MoveTo(moveTargetPos)
        end
    else
        StatusLabel.Text = "Status: Manual Control / Lobby Mode"
        StatusLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    end
end)
