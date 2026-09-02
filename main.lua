-- Slax Hub | Ultimate Auto Parry & Clash Spam Engine
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- المتغيرات الأساسية للتحكم
getgenv().AutoParry = true
getgenv().AutoSpam = true
getgenv().SpamDistance = 18 -- المسافة القريبة لتفعيل السبام السريع جداً
getgenv().ParryAccuracy = 3.5

-- ==================== [ محرك إرسال الضربات المباشر ] ====================

local function sendParrySignal()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
    for _, obj in ipairs(remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("parry") or obj.Name:lower():find("ability") or obj.Name:lower():find("hit")) then
            obj:FireServer()
            break
        end
    end
end

-- ==================== [ البحث عن الكرة والهدف ] ====================

local function getTargetBall()
    local ballsFolder = workspace:FindFirstChild("Balls") or workspace
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") or ball:FindFirstChild("RealBall") then
            return ball
        end
    end
    return nil
end

-- ==================== [ Auto Parry & High-Speed Spam Loop ] ====================

RunService.RenderStepped:Connect(function()
    if not (getgenv().AutoParry or getgenv().AutoSpam) then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ball = getTargetBall()
    
    if ball then
        local ballPosition = ball.Position
        local ballVelocity = ball.AssemblyLinearVelocity
        local distance = (ballPosition - rootPart.Position).Magnitude
        
        -- التحقق مما إذا كانت الكرة تستهدف اللاعب الحالي
        local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
        local isTargetingMe = (target == LocalPlayer.Name or target == LocalPlayer.DisplayName)
        
        if isTargetingMe then
            local speed = ballVelocity.Magnitude
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            
            -- حساب مسافة الضرب الفائقة حسب سرعة الكرة والبنق
            local dynamicParryDistance = math.clamp((speed * (0.35 + ping)) * (getgenv().ParryAccuracy / 3.3), 12, 150)
            
            -- 1. تفعيل الـ Spam عند الاقتراب المباشر (Clash Spam)
            if getgenv().AutoSpam and distance <= getgenv().SpamDistance then
                for i = 1, 3 do
                    sendParrySignal()
                end
            -- 2. تفعيل الـ Auto Parry عند الوصول لمسافة الحسابات
            elseif getgenv().AutoParry and distance <= dynamicParryDistance then
                sendParrySignal()
            end
        end
    end
end)
