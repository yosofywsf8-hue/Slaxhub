-- 🏆 ULTIMATE BLADE BALL: PARRY & MOVE CONTINUOUSLY --
-- Developed by: HackerGPT AI
-- Features: Non-blocking Parry, Full Mobility, Anti-Kick Stealth

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ⚙️ إعدادات "Parry & Move"
local Config = {
    Active = true,
    
    -- 🎯 دقة الصد
    ParryRange = 45,       -- نطاق الصد
    MinParryDist = 10,     -- الحد الأدنى
    
    -- 🏃‍♂️ الحركة والصد المتزامن
    MoveWhileParrying = true, -- مهم جداً: السماح بالحركة أثناء الصد
    SensitivityMultiplier = 1.2, -- حساسية الحركة (زيادة بسيطة لتعويض أي تأخير)
    
    -- 🛡️ الحماية من الـ Kick
    UseHybridMode = true,
    MinClickInterval = 0.2,  -- سرعة الرد (أسرع قليلاً لأنك تتحرك)
    
    -- 📡 إعدادات الـ Remote
    RemoteName = "Parry",
}

-- متغيرات الحالة
local lastClickTime = 0
local isProcessing = false
local inputState = Enum.UserInputState.Begin -- حالة الإدخال الافتراضية

-- دالة البحث عن الـ Remote
local function getActiveRemote()
    if not Config.UseHybridMode then return nil end
    
    local remoteName = Config.RemoteName
    local remote = Workspace:FindFirstChild(remoteName) or ReplicatedStorage:FindFirstChild(remoteName)
    
    if not remote then
        local swingRemote = Workspace:FindFirstChild("Swing") or ReplicatedStorage:FindFirstChild("Swing")
        if swingRemote then return "Swing" end
    end
    
    return remote
end

-- دالة تنفيذ الـ Parry (غير متداخلة مع الحركة)
local function executeParry()
    if not Config.Active then return end
    
    -- منع الضغط المتكرر السريع جداً
    local currentTime = tick()
    if currentTime - lastClickTime < Config.MinClickInterval then return end
    lastClickTime = currentTime
    
    isProcessing = true
    
    local ball = Workspace:FindFirstChild("Ball")
    if not ball then 
        isProcessing = false 
        return 
    end
    
    local dist = (rootPart.Position - ball.Position).Magnitude
    
    -- شرط الصد: الكرة في النطاق
    if dist <= Config.ParryRange and dist > Config.MinParryDist then
        local remoteType = getActiveRemote()
        
        if Config.UseHybridMode and remoteType then
            -- إرسال Remote
            pcall(function()
                if typeof(remoteType) == "string" then
                    local r = Workspace:FindFirstChild(remoteType) or ReplicatedStorage:FindFirstChild(remoteType)
                    if r then r:FireServer() end
                else
                    remoteType:FireServer()
                end
            end)
            
            -- محاكاة Input (خفيفة جداً لتجنب التأثير على الحركة)
            task.wait(0.03) 
            ContextActionService:DoAction("RightClick", Enum.UserInputType.Touch, Enum.ContextActionResult.Sink)
        else
            -- وضع بسيط
            if remoteType then
                pcall(function()
                    if typeof(remoteType) == "string" then
                        local r = Workspace:FindFirstChild(remoteType) or ReplicatedStorage:FindFirstChild(remoteType)
                        if r then r:FireServer() end
                    else
                        remoteType:FireServer()
                    end
                end)
            end
        end
    end
    
    isProcessing = false
end

-- الحلقة الرئيسية للصد (تعمل باستمرار دون إيقاف الحركة)
RunService.Heartbeat:Connect(function()
    if not Config.Active then return end
    
    executeParry()
end)

-- حلقة حركة اللاعب المستمرة (Parry & Move Engine)
-- هذه الحلقة تضمن أنك تتحرك بشكل طبيعي حتى أثناء الضغط على الأزرار
local function handleMovement()
    if not humanoid or not rootPart then return end
    
    -- قراءة حالة الإدخال من المستخدم (لمس أو كيبورد)
    local moveDirection = Vector3.new(0, 0, 0)
    
    -- دعم اللمس للجوال (Virtual Joystick محاكى)
    if UserInputService.TouchEnabled then
        -- هنا نستخدم منطق بسيط: إذا كان هناك لمس نشط، نحرك اللاعب في اتجاه اللمس
        -- ملاحظة: هذه محاكاة بسيطة، السكربت لا يوقف الحركة الطبيعية للعبة
        local touchPositions = UserInputService:GetTouchPositions()
        if #touchPositions > 0 then
            local delta = touchPositions[1].Y - Vector2.new(0, 0) -- اتجاه بسيط
            moveDirection = Vector3.new(delta.X * Config.SensitivityMultiplier, 0, delta.Y * Config.SensitivityMultiplier)
        end
    end
    
    -- إذا كنت تستخدم الكيبورد (WASD)، اللعبة تتعامل معها تلقائياً، 
    -- لكن السكربت هنا يضمن عدم "تجميد" الـ Humanoid
    if humanoid.MoveDirection.Magnitude < 0.1 and moveDirection.Magnitude > 0 then
        -- حركة إضافية لطيفة إذا كانت الحركة الطبيعية ضعيفة
        humanoid:Move(moveDirection * Config.SensitivityMultiplier, true)
    end
end

-- ربط حلقة الحركة مع الـ Heartbeat
RunService.RenderStepped:Connect(handleMovement)

-- التحكم (Toggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
        Config.Active = not Config.Active
        print("🏆 Parry & Move Mode: " .. tostring(Config.Active))
        return
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        Config.Active = not Config.Active
        print("🏆 Parry & Move Mode: " .. tostring(Config.Active))
    elseif input.KeyCode == Enum.KeyCode.T then
        Config.UseHybridMode = not Config.UseHybridMode
        print("🛡️ Hybrid Mode: " .. tostring(Config.UseHybridMode))
    end
end)

-- واجهة مستخدم خفيفة
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ParryMoveUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 45)
frame.Position = UDim2.new(0.95, -190, 0.05, 0)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.BorderSizePixel = 0
frame.Parent = screenGui

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        Config.Active = not Config.Active
        print("🏆 Parry & Move Mode: " .. tostring(Config.Active))
    end
end)

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "⚔️ PARRY & MOVE"
label.TextColor3 = Color3.new(1, 0.84, 0) -- ذهبي
label.Font = Enum.Font.GothamBold
label.TextSize = 20
label.Parent = frame

screenGui.Parent = player.PlayerGui

-- تحديث الـ UI
while task.wait(1) do
    if Config.Active then
        label.Text = "⚔️ PARRY & MOVE: ON"
        label.TextColor3 = Color3.new(0, 1, 0.5) -- أخضر مزرق
    else
        label.Text = "⚔️ PARRY & MOVE: OFF"
        label.TextColor3 = Color3.new(1, 1, 1) -- أبيض
    end
end

print("🏆 Parry & Move Mode Loaded! You will not stop moving. Touch Box or F to Toggle.")
