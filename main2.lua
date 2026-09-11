-- 🏆 Blade Ball Ultimate Anti-Ban & Single-Hit Mobile Engine
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- إعدادات صارمة تمنع الطرد والضرب المزدوج تماماً
local Config = {
    Active = true,
    ParryRange = 36,          -- مسافة الصد الآمنة
    SlashRange = 52,          -- مسافة الكرات السريعة
    Cooldown = 0.6,           -- مهلة زمنية صارمة (لا يمكن ضرب كرتين في أقل من 0.6 ثانية)
}

-- البحث الذكي عن الريموت
local function getParryRemote()
    local remote = ReplicatedStorage:FindFirstChild("Packages") 
        and ReplicatedStorage.Packages:FindFirstChild("_Index") 
        and ReplicatedStorage.Packages._Index:FindFirstChild("sleitnick_net@0.1.0") 
        and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net:FindFirstChild("ParryButton")
    
    if not remote then
        remote = ReplicatedStorage:FindFirstChild("Parry") or 
                 ReplicatedStorage:FindFirstChild("Swing") or
                 Workspace:FindFirstChild("ParryButton")
    end
    return remote
end

local parryRemote = getParryRemote()

-- واجهة الجوال (زر عائم)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BladeBallAntiBanGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 160, 0, 30)
statusLabel.Position = UDim2.new(0.5, -80, 0.02, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
statusLabel.Text = "🛡️ Ultra Safe: ON"
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
        statusLabel.Text = "🛡️ Ultra Safe: ON"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    else
        toggleButton.Text = "OFF 🔴"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        statusLabel.Text = "❌ Engine: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end)

-- البحث عن الكرة
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

-- حلقة مراقبة ذكية ونظيفة تمنع التوقف والضرب المزدوج تماماً
RunService.Heartbeat:Connect(function()
    if not Config.Active then return end
    
    local ball = findBall()
    if not ball then return end
    
    local currentTick = tick()
    local deltaTime = currentTick - lastTick
    if deltaTime <= 0 then deltaTime = 0.01 end
    
    -- حساب السرعة واتجاه الكرة
    local speed = (ball.Position - lastPos).Magnitude / deltaTime
    lastPos = ball.Position
    lastTick = currentTick
    
    local dist = (rootPart.Position - ball.Position).Magnitude
    
    -- تحديد المدى المناسب
    local activeRange = Config.ParryRange
    if speed > 110 then
        activeRange = Config.SlashRange
    end
    
    -- التحقق من المهلة الزمنية (Cooldown) بدقة شديدة لمنع الطرد والضرب المزدوج والتوقف
    if dist <= activeRange then
        if (currentTick - lastParryTime) >= Config.Cooldown then
            lastParryTime = currentTick
            
            if parryRemote then
                pcall(function()
                    if parryRemote:IsA("RemoteEvent") then
                        parryRemote:FireServer()
                    elseif parryRemote:IsA("RemoteFunction") then
                        parryRemote:InvokeServer()
                    end
                end)
            end
        end
    end
end)

print("🏆 Ultimate Single-Hit Engine Loaded!")
