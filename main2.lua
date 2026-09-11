-- 🏆 Blade Ball Mobile Auto Parry & Slash Engine
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- إعدادات المحرك للجوال
local Config = {
    Active = true,
    ParryRange = 42,          -- مسافة الصد الأساسية
    SlashRange = 65,          -- مسافة الصد للكرات السريعة (Fury)
    Prediction = 0.06,        -- تأخير متوافق مع بنج الجوال
}

-- البحث الذكي عن الريموت في اللعبة
local function getParryRemote()
    local remote = ReplicatedStorage:FindFirstChild("Packages") 
        and ReplicatedStorage.Packages:FindFirstChild("_Index") 
        and ReplicatedStorage.Packages._Index:FindFirstChild("sleitnick_net@0.1.0") 
        and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net:FindFirstChild("ParryButton")
    
    if not remote then
        remote = ReplicatedStorage:FindFirstChild("Parry") or 
                 ReplicatedStorage:FindFirstChild("Swing") or
                 Workspace:FindFirstChild("ParryButton") or
                 ReplicatedStorage:FindFirstChild("ParryButton")
    end
    return remote
end

local parryRemote = getParryRemote()

-- 📱 تصميم واجهة مخصصة للجوال (زر عائم + شاشة حالة)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BladeBallMobileGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- لوحة الحالة في الأعلى
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 150, 0, 30)
statusLabel.Position = UDim2.new(0.5, -75, 0.02, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.Text = "⚡ Mobile Engine: ON"
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.Parent = screenGui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 6)
corner1.Parent = statusLabel

-- زر تشغيل/إيقاف عائم (قابل للضغط باللمس على الشاشة)
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 90, 0, 45)
toggleButton.Position = UDim2.new(0.85, -10, 0.2, 0) -- على جانب الشاشة الأيمن لسهولة الوصول بالإصبع
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "ON 🟢"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.Parent = screenGui

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 10)
corner2.Parent = toggleButton

-- تفعيل الزر باللمس للجوال
toggleButton.MouseButton1Click:Connect(function()
    Config.Active = not Config.Active
    if Config.Active then
        toggleButton.Text = "ON 🟢"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        statusLabel.Text = "⚡ Mobile Engine: ON"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    else
        toggleButton.Text = "OFF 🔴"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        statusLabel.Text = "❌ Engine: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end)

-- دالة تنفيذ الصد
local function triggerParry()
    if not Config.Active then return end
    
    if parryRemote then
        pcall(function()
            if parryRemote:IsA("RemoteEvent") then
                parryRemote:FireServer()
            elseif parryRemote:IsA("RemoteFunction") then
                parryRemote:InvokeServer()
            end
        end)
    else
        -- محاكاة اللمس في حال لم يوجد ريموت
        local vim = game:GetService("VirtualInputManager")
        if vim then
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.04)
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end

-- دالة بحث سريعة وخفيفة عن الكرة
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
local isParrying = false

-- الحلقة الأساسية للأداء العالي على الموبايل
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
    
    -- تحديد نطاق الصد
    local activeRange = Config.ParryRange
    if speed > 110 then
        activeRange = Config.SlashRange
    end
    
    -- تنفيذ الصد التلقائي
    if dist <= activeRange and not isParrying then
        isParrying = true
        task.wait(Config.Prediction)
        triggerParry()
        task.wait(0.2) -- فاصل زمني لتجنب التعليق
        isParrying = false
    end
end)

print("🏆 Blade Ball Mobile Engine Loaded Successfully!")
