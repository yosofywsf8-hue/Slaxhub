-- ============================================
-- Blade Ball Auto Parry (Mobile-Friendly)
-- بدون Immortality
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- انتظر اللعبة تحمّل
local Balls = workspace:WaitForChild("Balls", 30)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)

-- الريموت المسؤول عن الباري
local ParryRemote = Remotes:WaitForChild("ParryButtonPress", 30)

if not ParryRemote then
    warn("[AutoParry] ما لقيت ParryButtonPress")
    return
end

-- ============================================
-- الإعدادات
-- ============================================
local CONFIG = {
    AutoParry = true,       -- باري تلقائي
    AutoSpam = false,       -- ضغط تلقائي
    SpamDelay = 0.1,        -- سرعة الس팸
    ParryCooldown = 0.15,   -- كول داون بين كل باري
    MaxDistance = 60,       -- أقصى مسافة
}

local lastParry = 0
local spamThread = nil

-- ============================================
-- دالة الباري
-- ============================================
local function doParry()
    if tick() - lastParry < CONFIG.ParryCooldown then
        return
    end
    lastParry = tick()
    pcall(function()
        ParryRemote:Fire()
    end)
end

-- ============================================
-- فحص إذا الكرة تستهدف اللاعب
-- ============================================
local function isTargetingMe(ball)
    local target = ball:GetAttribute("target")
    if target == Player.Name then
        return true
    end
    -- فحص إضافي: Highlight أو علامة
    for _, v in ipairs(Player.Character:GetChildren()) do
        if v:IsA("Highlight") then
            return true
        end
    end
    return false
end

-- ============================================
-- حساب وقت الوصول
-- ============================================
local function timeToReach(ball)
    if not Player.Character then return math.huge end
    local root = Player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return math.huge end
    
    local speed = ball.AssemblyLinearVelocity.Magnitude
    if speed < 1 then return math.huge end
    
    local distance = (ball.Position - root.Position).Magnitude
    return distance / speed
end

-- ============================================
-- المراقبة الرئيسية
-- ============================================
local function watchBall(ball)
    if not ball:IsA("BasePart") then return end
    
    -- نتأكد إنها كرة حقيقية
    if ball:GetAttribute("realBall") ~= true then
        -- ننتظر ممكن تصير حقيقية
        ball:GetAttributeChangedSignal("realBall"):Connect(function()
            if ball:GetAttribute("realBall") == true then
                -- نبدأ المراقبة
            end
        end)
    end
    
    -- مراقبة تغير الهدف
    ball:GetAttributeChangedSignal("target"):Connect(function()
        if not CONFIG.AutoParry then return end
        if isTargetingMe(ball) then
            doParry()
        end
    end)
    
    -- مراقبة مستمرة (احتياط)
    task.spawn(function()
        while ball.Parent do
            if CONFIG.AutoParry and isTargetingMe(ball) then
                local t = timeToReach(ball)
                if t < 0.4 then
                    doParry()
                end
            end
            task.wait(0.01)
        end
    end)
end

-- ============================================
-- تشغيل
-- ============================================
for _, ball in ipairs(Balls:GetChildren()) do
    watchBall(ball)
end

Balls.ChildAdded:Connect(watchBall)

-- ============================================
-- Auto Spam
-- ============================================
local function startSpam()
    if spamThread then return end
    spamThread = task.spawn(function()
        while CONFIG.AutoSpam do
            doParry()
            task.wait(CONFIG.SpamDelay)
        end
        spamThread = nil
    end)
end

-- ============================================
-- واجهة بسيطة للجوال
-- ============================================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoParryGUI"
gui.ResetOnSpawn = false
gui.Parent = Player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 150)
frame.Position = UDim2.new(0, 20, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Auto Parry"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local function makeButton(name, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = name
    btn.Parent = frame
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local parryBtn = makeButton("Auto Parry: ON", 40, function()
    CONFIG.AutoParry = not CONFIG.AutoParry
    parryBtn.Text = "Auto Parry: " .. (CONFIG.AutoParry and "ON" or "OFF")
end)

local spamBtn = makeButton("Auto Spam: OFF", 85, function()
    CONFIG.AutoSpam = not CONFIG.AutoSpam
    spamBtn.Text = "Auto Spam: " .. (CONFIG.AutoSpam and "ON" or "OFF")
    if CONFIG.AutoSpam then
        startSpam()
    end
end)

print("[AutoParry] تم التشغيل بنجاح ✅")
