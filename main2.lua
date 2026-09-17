-- ==========================================
-- 🚀 BLADE BALL: SAFE & SMART ENGINE v9.0
-- (Anti-Kick Bypass + Smart Target + Mobile Fix)
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local PrimaryPart = Character:WaitForChild("HumanoidRootPart")

local Settings = {
    AutoParry = true,
    LastParryTime = 0,
    MinCooldown = 0.08, -- أبطأ قليلاً لتفادي الطرد
    MaxCooldown = 0.12  -- تأخير عشوائي ليبدو كلاعب حقيقي
}

-- [1] واجهة بسيطة لتفعيل/إيقاف السكربت
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SafeBladeBallUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 130, 0, 45)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
ToggleBtn.Text = "AUTO-PARRY: ON"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.Parent = ScreenGui

ToggleBtn.MouseButton1Click:Connect(function()
    Settings.AutoParry = not Settings.AutoParry
    ToggleBtn.Text = Settings.AutoParry and "AUTO-PARRY: ON" or "AUTO-PARRY: OFF"
    ToggleBtn.BackgroundColor3 = Settings.AutoParry and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
end)

-- [2] دالة مطورة للعثور على الكرة النشطة
local function GetActiveBall()
    -- البحث في المجلدات التي تضع فيها اللعبة الكرات عادة
    local ballsFolder = Workspace:FindFirstChild("Balls") or Workspace
    for _, obj in ipairs(ballsFolder:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "Ball" or obj:GetAttribute("realBall") == true) then
            if obj.Transparency < 1 then
                return obj
            end
        end
    end
    return nil
end

-- [3] محاكاة اللمس الآمنة (تفادي الطرد)
local function TriggerSafeTap()
    local currentTime = tick()
    -- إضافة وقت عشوائي بسيط للكوول داون لكي لا يكشفه نظام الحماية
    local randomCooldown = math.random(Settings.MinCooldown * 100, Settings.MaxCooldown * 100) / 100
    
    if currentTime - Settings.LastParryTime < randomCooldown then return end
    Settings.LastParryTime = currentTime
    
    task.spawn(function()
        pcall(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            
            -- لمس الشاشة في منطقة خالية لعمل الصد
            local tapX = cam.ViewportSize.X * 0.75 
            local tapY = cam.ViewportSize.Y * 0.75

            VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.Begin, tapX, tapY)
            task.wait(math.random(2, 4) / 100) -- ضغطة واقعية قصيرة
            VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.End, tapX, tapY)
        end)
    end)
end

-- [4] محرك الذكاء والفيزياء المطور
RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        Character = LocalPlayer.Character
        if Character then PrimaryPart = Character:FindFirstChild("HumanoidRootPart") end
        return
    end

    local ball = GetActiveBall()
    if not ball then return end

    local distance = (ball.Position - PrimaryPart.Position).Magnitude
    local ballVelocity = ball.AssemblyLinearVelocity
    local ballSpeed = ballVelocity.Magnitude

    if ballSpeed > 0 then
        -- [مهم جداً] التأكد من أن الكرة تتجه نحوك وليس نحو لاعب آخر!
        -- نستخدم (Dot Product) لحساب الاتجاه
        local directionToMe = (PrimaryPart.Position - ball.Position).Unit
        local ballDirection = ballVelocity.Unit
        local isHeadingTowardsMe = directionToMe:Dot(ballDirection) > 0.5 -- إذا كانت النتيجة موجبة وعالية، الكرة تقصدك

        if isHeadingTowardsMe then
            local timeToReach = distance / ballSpeed
            local pingCompensation = (ballSpeed * 0.12) + 14

            if distance <= pingCompensation or timeToReach <= 0.18 then
                TriggerSafeTap()
            end
        end
    elseif distance <= 15 then
        -- إذا كانت الكرة متوقفة وقريبة جداً (Clash بداية)
        TriggerSafeTap()
    end
end)

print("✅ v9.0 Safe Target Engine Loaded!")
