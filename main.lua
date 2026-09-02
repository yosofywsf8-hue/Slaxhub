-- Slax Hub | Universal Blade Ball Auto Parry & Spam
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- البحث عن مجلد الكرات باللعبة
local function getBallsFolder()
    return workspace:FindFirstChild("Balls") or workspace
end

-- استدعاء ريموت الضرب بجميع الأساليب المحتملة
local function triggerParry()
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
        
        -- البحث عن الريموت المباشر
        for _, obj in ipairs(remotes:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (obj.Name:find("Parry") or obj.Name:find("parry") or obj.Name:find("Hit")) then
                obj:FireServer()
                return
            end
        end
        
        -- طريقة احتياطية لقراءة الأزرار
        if remotes:FindFirstChild("ParryButtonPress") then
            remotes.ParryButtonPress:FireServer()
        end
    end)
end

-- معرفة الكرة النشطة حالياً
local function getCurrentBall()
    local ballsFolder = getBallsFolder()
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") or ball:FindFirstChild("RealBall") or ball:GetAttribute("realBall") then
            return ball
        end
    end
    return nil
end

-- فحص استهداف الكرة للاعب
local function isPlayerTargeted(ball)
    if not ball then return false end
    
    -- 1. فحص Target Attribute
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
    if target and (target == LocalPlayer.Name or target == LocalPlayer.DisplayName) then
        return true
    end
    
    -- 2. فحص Highlight الشخصية
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Highlight") then
        return true
    end
    
    return false
end

-- المحرك الرئيسي المباشر (Auto Parry + Spam)
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local ball = getCurrentBall()
    
    if ball and isPlayerTargeted(ball) then
        local distance = (ball.Position - hrp.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        
        -- حساب البنق والمسافة الفعالة للضرب
        local ping = 0.05
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        
        local parryRange = math.clamp((velocity * (0.32 + ping)), 14, 120)
        
        -- الـ Spam التلقائي عند المسافة القريبة جداً (Clash)
        if distance <= 18 then
            for i = 1, 4 do
                triggerParry()
            end
        -- الـ Auto Parry التلقائي عند وصول الكرة لمسافة الحساب
        elseif distance <= parryRange then
            triggerParry()
        end
    end
end)
