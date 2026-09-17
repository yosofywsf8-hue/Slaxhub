-- ==========================================
-- 🚀 BLADE BALL: ULTIMATE ADVANCED ENGINE v8.0
-- (Direct Feature Tabs + Spam Parry + Anti-Curve + 100ms Ping)
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local PrimaryPart = Character:WaitForChild("HumanoidRootPart")

-- الإعدادات المتطورة
local Settings = {
    AutoParry = true,
    SpamParry = true,
    AntiCurve = true,
    AntiStun = true,
    LastParryTime = 0,
    ParryCooldown = 0.03
}

-- [1] بناء الواجهة المقسمة حسب الخصائص والميزات
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallAdvancedUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 330, 0, 185)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- شريط العنوان
local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
TitleBar.Text = "⚡ BLADE BALL ADVANCED ENGINE"
TitleBar.TextColor3 = Color3.fromRGB(0, 255, 150)
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextSize = 11
TitleBar.Parent = MainFrame

-- شريط التنقل بالخيارات المباشرة
local NavHeader = Instance.new("Frame")
NavHeader.Size = UDim2.new(1, 0, 0, 25)
NavHeader.Position = UDim2.new(0, 0, 0, 28)
NavHeader.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
NavHeader.BorderSizePixel = 0
NavHeader.Parent = MainFrame

local BtnAuto = Instance.new("TextButton")
BtnAuto.Size = UDim2.new(0.25, 0, 1, 0)
BtnAuto.Text = "Auto Parry"
BtnAuto.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnAuto.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
BtnAuto.Font = Enum.Font.GothamSemibold
BtnAuto.TextSize = 10
BtnAuto.Parent = NavHeader

local BtnSpam = Instance.new("TextButton")
BtnSpam.Size = UDim2.new(0.25, 0, 1, 0)
BtnSpam.Position = UDim2.new(0.25, 0, 0, 0)
BtnSpam.Text = "Spam Parry"
BtnSpam.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnSpam.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
BtnSpam.Font = Enum.Font.GothamSemibold
BtnSpam.TextSize = 10
BtnSpam.Parent = NavHeader

local BtnCurve = Instance.new("TextButton")
BtnCurve.Size = UDim2.new(0.25, 0, 1, 0)
BtnCurve.Position = UDim2.new(0.50, 0, 0, 0)
BtnCurve.Text = "Anti-Curve"
BtnCurve.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnCurve.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
BtnCurve.Font = Enum.Font.GothamSemibold
BtnCurve.TextSize = 10
BtnCurve.Parent = NavHeader

local BtnStun = Instance.new("TextButton")
BtnStun.Size = UDim2.new(0.25, 0, 1, 0)
BtnStun.Position = UDim2.new(0.75, 0, 0, 0)
BtnStun.Text = "Anti-Stun"
BtnStun.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnStun.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
BtnStun.Font = Enum.Font.GothamSemibold
BtnStun.TextSize = 10
BtnStun.Parent = NavHeader

-- إطارات الصفحات
local FrameAuto = Instance.new("Frame")
FrameAuto.Size = UDim2.new(1, 0, 1, -53)
FrameAuto.Position = UDim2.new(0, 0, 0, 53)
FrameAuto.BackgroundTransparency = 1
FrameAuto.Parent = MainFrame

local FrameSpam = Instance.new("Frame")
FrameSpam.Size = UDim2.new(1, 0, 1, -53)
FrameSpam.Position = UDim2.new(0, 0, 0, 53)
FrameSpam.BackgroundTransparency = 1
FrameSpam.Visible = false
FrameSpam.Parent = MainFrame

local FrameCurve = Instance.new("Frame")
FrameCurve.Size = UDim2.new(1, 0, 1, -53)
FrameCurve.Position = UDim2.new(0, 0, 0, 53)
FrameCurve.BackgroundTransparency = 1
FrameCurve.Visible = false
FrameCurve.Parent = MainFrame

local FrameStun = Instance.new("Frame")
FrameStun.Size = UDim2.new(1, 0, 1, -53)
FrameStun.Position = UDim2.new(0, 0, 0, 53)
FrameStun.BackgroundTransparency = 1
FrameStun.Visible = false
FrameStun.Parent = MainFrame

-- [2] محتوى قسم Auto Parry
local ToggleAuto = Instance.new("TextButton")
ToggleAuto.Size = UDim2.new(0.8, 0, 0, 38)
ToggleAuto.Position = UDim2.new(0.1, 0, 0.25, 0)
ToggleAuto.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
ToggleAuto.Text = "Auto Parry: ON"
ToggleAuto.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleAuto.Font = Enum.Font.GothamBold
ToggleAuto.TextSize = 12
ToggleAuto.Parent = FrameAuto

ToggleAuto.MouseButton1Click:Connect(function()
    Settings.AutoParry = not Settings.AutoParry
    ToggleAuto.Text = Settings.AutoParry and "Auto Parry: ON" or "Auto Parry: OFF"
    ToggleAuto.BackgroundColor3 = Settings.AutoParry and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 40, 40)
end)

-- [3] محتوى قسم Spam Parry
local ToggleSpam = Instance.new("TextButton")
ToggleSpam.Size = UDim2.new(0.8, 0, 0, 38)
ToggleSpam.Position = UDim2.new(0.1, 0, 0.25, 0)
ToggleSpam.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
ToggleSpam.Text = "Spam Parry (Clash): ON"
ToggleSpam.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleSpam.Font = Enum.Font.GothamBold
ToggleSpam.TextSize = 12
ToggleSpam.Parent = FrameSpam

ToggleSpam.MouseButton1Click:Connect(function()
    Settings.SpamParry = not Settings.SpamParry
    ToggleSpam.Text = Settings.SpamParry and "Spam Parry (Clash): ON" or "Spam Parry (Clash): OFF"
    ToggleSpam.BackgroundColor3 = Settings.SpamParry and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 40, 40)
end)

-- [4] محتوى قسم Anti-Curve
local ToggleCurve = Instance.new("TextButton")
ToggleCurve.Size = UDim2.new(0.8, 0, 0, 38)
ToggleCurve.Position = UDim2.new(0.1, 0, 0.25, 0)
ToggleCurve.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
ToggleCurve.Text = "Anti-Curve Tracking: ON"
ToggleCurve.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleCurve.Font = Enum.Font.GothamBold
ToggleCurve.TextSize = 12
ToggleCurve.Parent = FrameCurve

ToggleCurve.MouseButton1Click:Connect(function()
    Settings.AntiCurve = not Settings.AntiCurve
    ToggleCurve.Text = Settings.AntiCurve and "Anti-Curve Tracking: ON" or "Anti-Curve Tracking: OFF"
    ToggleCurve.BackgroundColor3 = Settings.AntiCurve and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 40, 40)
end)

-- [5] محتوى قسم Anti-Stun
local ToggleStun = Instance.new("TextButton")
ToggleStun.Size = UDim2.new(0.8, 0, 0, 38)
ToggleStun.Position = UDim2.new(0.1, 0, 0.25, 0)
ToggleStun.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
ToggleStun.Text = "Anti-Stun & Ragdoll: ON"
ToggleStun.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleStun.Font = Enum.Font.GothamBold
ToggleStun.TextSize = 12
ToggleStun.Parent = FrameStun

ToggleStun.MouseButton1Click:Connect(function()
    Settings.AntiStun = not Settings.AntiStun
    ToggleStun.Text = Settings.AntiStun and "Anti-Stun & Ragdoll: ON" or "Anti-Stun & Ragdoll: OFF"
    ToggleStun.BackgroundColor3 = Settings.AntiStun and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 40, 40)
end)

-- [6] التنقل بين الخيارات
local function SwitchSection(targetFrame, targetBtn)
    FrameAuto.Visible = false
    FrameSpam.Visible = false
    FrameCurve.Visible = false
    FrameStun.Visible = false
    
    BtnAuto.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    BtnSpam.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    BtnCurve.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    BtnStun.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

    targetFrame.Visible = true
    targetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
end

BtnAuto.MouseButton1Click:Connect(function() SwitchSection(FrameAuto, BtnAuto) end)
BtnSpam.MouseButton1Click:Connect(function() SwitchSection(FrameSpam, BtnSpam) end)
BtnCurve.MouseButton1Click:Connect(function() SwitchSection(FrameCurve, BtnCurve) end)
BtnStun.MouseButton1Click:Connect(function() SwitchSection(FrameStun, BtnStun) end)

-- [7] محرك الحسابات المطور
local function GetActiveBall()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "Ball" or obj.Name:lower():find("ball")) then
            if obj.Transparency < 1 then return obj end
        end
    end
    return nil
end

local function TriggerTap()
    local currentCooldown = Settings.ParryCooldown
    if Settings.SpamParry then currentCooldown = 0.015 end
    
    if tick() - Settings.LastParryTime < currentCooldown then return end
    Settings.LastParryTime = tick()
    
    task.spawn(function()
        pcall(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            
            local viewportSize = cam.ViewportSize
            local tapX = viewportSize.X * 0.85 
            local tapY = viewportSize.Y * 0.75

            VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.Begin, tapX, tapY)
            task.wait()
            VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.End, tapX, tapY)
        end)
    end)
end

RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        Character = LocalPlayer.Character
        if Character then PrimaryPart = Character:FindFirstChild("HumanoidRootPart") end
        return
    end

    if Settings.AntiStun then
        local humanoid = Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
    end

    local ball = GetActiveBall()
    if not ball then return end

    local distance = (ball.Position - PrimaryPart.Position).Magnitude
    local ballVelocity = ball.AssemblyLinearVelocity
    local ballSpeed = ballVelocity.Magnitude

    if ballSpeed > 0 then
        local timeToReach = distance / ballSpeed
        local pingCompensation = (ballSpeed * 0.13) + 15

        -- ميزة حساب الاتجاه والانحناء Anti-Curve
        if Settings.AntiCurve then
            local dotProduct = (PrimaryPart.Position - ball.Position).Unit:Dot(ballVelocity.Unit)
            if dotProduct > 0.3 then
                pingCompensation = pingCompensation + 3
            end
        end

        if distance <= pingCompensation or timeToReach <= 0.16 then
            TriggerTap()
        end
    elseif distance <= 16 then
        TriggerTap()
    end
end)

print("🚀 Full Direct Feature Tabs UI Loaded!")
