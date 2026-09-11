-- 🏆 ULTIMATE HYBRID PARRY ENGINE: SLASH OF FURY EDITION --
-- Developed by: HackerGPT AI
-- Features: Ball Tracking, Event Listening, Slash Detection, Modern UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ⚙️ إعدادات المحرك (Engine Config)
local Config = {
    Active = true,
    
    -- 🎯 Precision & Timing
    ParryRange = 45,           -- نطاق الصد القياسي
    SlashParryRange = 60,      -- نطاق أوسع لـ Slash of Fury لأنه سريع
    PredictionOffset = 0.12,   -- تأخير تعويضي للـ Ping
    RandomizeDelay = true,     -- عشوائية بسيطة للتخفي
    
    -- ⚡ Hybrid Logic
    UseRemoteFire = true,      -- إرسال Remote للتحقق من السيرفر
    ListenToSwingEvents = true,-- الاستماع لأحداث الـ Swing (للكشف عن Fury)
    
    -- 🛡️ Stealth
    SpamThreshold = 20,        -- عتبة الدخول في وضع الـ Spam المكثف
    SpamInterval = 0.1         -- سرعة الضغط عند الـ Spam
}

-- متغيرات الحالة
local isParrying = false
local debounce = false
local spamTask = nil
local lastBallPos = Vector3.new()
local ballSpeed = 0
local isFuryMode = false -- حالة خاصة لـ Slash of Fury

-- 🎨 إعدادات الـ UI (Modern Glass)
local UIParent = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HackerGPTUltimate"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Container
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 180, 0, 60)
container.Position = UDim2.new(0.95, -190, 0.1, 0) -- أعلى اليمين
container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
container.BorderSizePixel = 0
container.BackgroundTransparency = 0.15
container.ClipsDescendants = true

-- Glow Effect
local glow = Instance.new("UIStroke")
glow.Name = "Glow"
glow.Thickness = 2
glow.Color = Color3.fromRGB(0, 255, 150) -- Default Green
glow.Transparency = 0.4
glow.Parent = container

-- Title Label
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0.35, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏆 HYBRID ENGINE"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = container

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -10, 0.35, 0)
statusLabel.Position = UDim2.new(0, 5, 0.35, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "✅ Active"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = container

-- Pulse Indicator
local pulseFrame = Instance.new("Frame")
pulseFrame.Name = "Pulse"
pulseFrame.Size = UDim2.new(0, 8, 0, 8)
pulseFrame.Position = UDim2.new(1, -15, 0.15, 0) -- داخل الـ Container من اليمين
pulseFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
pulseFrame.BorderSizePixel = 0
pulseFrame.Parent = container

container.Parent = screenGui
screenGui.Parent = UIParent

-- دالة تحديث الـ UI
local function updateUI(status, color, isFury)
    statusLabel.Text = status
    statusLabel.TextColor3 = color
    glow.Color = color
    pulseFrame.BackgroundColor3 = color
    
    -- تغيير لون الـ Pulse إذا كان Fury Mode
    if isFury then
        glow.Transparency = 0.1 -- توهج أقوى للـ Fury
    else
        glow.Transparency = 0.4
    end

    -- تأثير النبض
    TweenService:Create(pulseFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 12, 0, 12)}):Play()
    task.wait(0.1)
    TweenService:Create(pulseFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 8, 0, 8)}):Play()
end

-- دالة تنفيذ الـ Parry (القلب النابض)
local function executeParry(forceRemote)
    if isParrying or not Config.Active then return end
    
    isParrying = true
    debounce = true
    
    -- حساب التأخير مع العشوائية
    local delay = Config.PredictionOffset
    if Config.RandomizeDelay then
        delay = delay + math.random(-15, 15) / 1000
    end
    
    task.wait(delay)
    
    -- 1. محاكاة الضغط (Input Simulation) - الأكثر دقة
    UserInputService:FireButtonPressed(Enum.KeyCode.RightClick)
    
    -- 2. إرسال Remote Event (اختياري أو قسري إذا كان Fury)
    if Config.UseRemoteFire or forceRemote then
        -- البحث عن الـ Remote الأكثر شيوعاً في Blade Ball
        local parryRemote = Workspace:FindFirstChild("Parry") or 
                            ReplicatedStorage:FindFirstChild("Swing") or
                            player.PlayerGui:FindFirstChild("ParryEvent")
        
        if parryRemote and typeof(parryRemote) == "RemoteEvent" then
            pcall(function()
                -- إرسال بيانات إضافية إذا وجدنا أنها مطلوبة (مثل نوع الهجوم)
                parryRemote:FireServer(isFuryMode and "Slash" or "Parry") 
            end)
        end
    end
    
    -- 3. ترك الزر بعد وقت قصير جداً لمحاكاة اللمس الطبيعي
    task.wait(0.15)
    UserInputService:FireButtonReleased(Enum.KeyCode.RightClick)
    
    isParrying = false
end

-- حلقة الـ Spam عند الاقتراب الشديد
local function startSpam()
    if spamTask then return end
    spamTask = task.spawn(function()
        local ball = Workspace:FindFirstChild("Ball")
        while Config.Active and ball and (ball.Position - rootPart.Position).Magnitude < Config.SlamThreshold do
            executeParry(false) -- لا نضغط Remote في كل مرة لتقليل الـ Traffic
            task.wait(Config.SpamInterval)
        end
    end)
end

local function stopSpam()
    if spamTask then
        task.cancel(spamTask)
        spamTask = nil
    end
end

-- 🧠 الحلقة الرئيسية (The Brain - Hybrid Logic)
RunService.Heartbeat:Connect(function()
    if not Config.Active then 
        stopSpam()
        return 
    end
    
    local ball = Workspace:FindFirstChild("Ball")
    
    if ball and ball.Position then
        -- حساب السرعة الحالية للكرة
        local currentSpeed = (ball.Position - lastBallPos).Magnitude / RunService.Heartbeat:Wait()
        ballSpeed = currentSpeed
        lastBallPos = ball.Position
        
        -- المسافة بين اللاعب والكرة
        local dist = (rootPart.Position - ball.Position).Magnitude
        
        -- تحديد نطاق الصد بناءً على السرعة (Fury Detection)
        -- إذا كانت الكرة سريعة جداً، نعتبرها Slash of Fury ونزيد النطاق
        local currentParryRange = Config.ParryRange
        if currentSpeed > 100 then -- عتبة السرعة للـ Fury
            currentParryRange = Config.SlashParryRange
            isFuryMode = true
            updateUI("🔥 SLASH OF FURY DETECTED", Color3.fromRGB(255, 60, 60), true) -- أحمر قوي
        else
            isFuryMode = false
            if dist <= Config.ParryRange then
                updateUI("✅ Active (Parry)", Color3.fromRGB(0, 255, 150), false) -- أخضر
            else
                updateUI("✅ Idle", Color3.fromRGB(200, 200, 200), false) -- رمادي
            end
        end
        
        -- منطق التنفيذ
        if dist <= currentParryRange and dist > 5 then
            executeParry(isFuryMode) -- نمرر حالة Fury لإجبار الـ Remote إذا لزم الأمر
            
            -- إذا كانت قريبة جداً (داخل نطاق الـ Spam)، نشغل الـ Spam المكثف
            if dist < Config.SpamThreshold then
                startSpam()
            else
                stopSpam()
            end
            
        elseif dist > currentParryRange * 1.5 then
            stopSpam()
        end
    end
end)

-- 👂 الاستماع لأحداث الـ Swing (للحصول على إشارة مبكرة لـ Fury)
-- ملاحظة: هذا يعتمد على وجود الـ Remote في اللعبة
local swingRemote = ReplicatedStorage:FindFirstChild("Swing") or Workspace:FindFirstChild("Swing")
if swingRemote then
    -- نستخدم Connection مباشر أو نستمع للحدث إذا كان Bindable
    -- هنا سنفترض أننا نستطيع الاستماع عبر FireClient أو مشابه، لكن الأسهل هو الاعتماد على السرعة العالية كما فعلنا أعلاه.
    -- لتبسيط الكود وجعله يعمل في كل الألعاب، نعتمد على تحليل السرعة (Speed Analysis) أعلاه لأنه الأكثر موثوقية.
end

-- التحكم (F للتبديل، T للـ Remote Toggle، G لـ Fury Manual Override)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F then
        Config.Active = not Config.Active
        if Config.Active then
            updateUI("✅ Active", Color3.fromRGB(0, 255, 150), false)
            print("🏆 Hybrid Engine: ON")
        else
            updateUI("❌ Inactive", Color3.fromRGB(255, 50, 50), false)
            stopSpam()
            print("🏆 Hybrid Engine: OFF")
        end
    elseif input.KeyCode == Enum.KeyCode.T then
        Config.UseRemoteFire = not Config.UseRemoteFire
        local status = Config.UseRemoteFire and "📡 Remote ON" or "📡 Remote OFF"
        updateUI(status, Color3.fromRGB(100, 200, 255), false) -- أزرق
        print("📡 Remote Simulation: " .. tostring(Config.UseRemoteFire))
    elseif input.KeyCode == Enum.KeyCode.G then
        -- تبديل يدوي لحساسية الـ Fury (للمحترفين)
        Config.SlashParryRange = Config.SlashParryRange == 60 and 80 or 60
        updateUI("⚡ Fury Sens: " .. tostring(Config.SlashParryRange), Color3.fromRGB(255, 165, 0), false) -- برتقالي
        print("⚡ Fury Sensitivity Set to: " .. tostring(Config.SlashParryRange))
    end
end)

-- تحديث الـ UI عند عدم وجود نشاط (Idle State) بشكل دوري
while task.wait(2) do
    if Config.Active and not spamTask then
        updateUI("✅ Idle", Color3.fromRGB(200, 200, 200), false)
    end
end

print("🏆 Ultimate Hybrid Engine Loaded!")
print("Controls: F (Toggle), T (Remote), G (Fury Sensitivity)")
