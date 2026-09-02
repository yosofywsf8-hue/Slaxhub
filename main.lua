-- Slax Hub | High-Speed Auto Parry & Clash Spam (Mobile Fast Engine)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- البحث عن مجلد الكرات
local function getBalls()
    return workspace:FindFirstChild("Balls") or workspace
end

-- استدعاء ريموت Parry السريع
local function sendParry()
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
        
        -- البحث المباشر السريع عن ريموت الضرب
        local parryRemote = remotes:FindFirstChild("ParryButtonPress") 
                         or remotes:FindFirstChild("Parry") 
                         or remotes:FindFirstChild("ParryAttempt")
        
        if parryRemote and parryRemote:IsA("RemoteEvent") then
            parryRemote:FireServer()
        else
            for _, obj in ipairs(remotes:GetChildren()) do
                if obj:IsA("RemoteEvent") and (obj.Name:lower():find("parry") or obj.Name:lower():find("hit")) then
                    obj:FireServer()
                    break
                end
            end
        end
    end)
end

-- معرفة الكرة الحقيقية
local function getBall()
    for _, ball in ipairs(getBalls():GetChildren()) do
        if ball:IsA("BasePart") or ball:FindFirstChild("RealBall") or ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

-- التحقق من استهداف الكرة للاعب
local function isTargeting(ball)
    if not ball then return false end
    
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
    if target and (target == LocalPlayer.Name or target == LocalPlayer.DisplayName) then
        return true
    end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Highlight") then
        return true
    end
    
    return false
end

-- المحرك الرئيسي الفائق السرعة
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local ball = getBall()
    
    if ball and isTargeting(ball) then
        local distance = (ball.Position - hrp.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        
        -- حساب البنق
        local ping = 0.04
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        
        -- المسافة الديناميكية للـ Auto Parry
        local parryDistance = math.clamp((velocity * (0.33 + ping)), 13, 150)
        
        -- الـ Spam التلقائي عند المواجهة القريبة (Clash Spam) مثل الفيديو
        if distance <= 20 then
            for i = 1, 5 do
                sendParry()
            end
        -- Auto Parry تلقائي عند اقتراب الكرة
        elseif distance <= parryDistance then
            sendParry()
        end
    end
end)
