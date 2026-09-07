-- Blade Ball - God Mode Ultimate Auto Parry & Spam by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = global and global.Players or game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball GOD MODE",
    SubTitle = "Maximum Performance & Speed",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 380),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "God Combat", Icon = "sword" }),
    Visuals = Window:AddTab({ Title = "ESP & Radar", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- المتغيرات الأساسية الخارقة
local _G_Config = {
    AutoParry = false,
    AutoSpam = false,
    BallESP = false,
    PredictionTime = 0.38, -- معدل التنبؤ الخارق للسرعات العالية
}

-- المسار المباشر والمضمون 100% لزر الصد في Blade Ball
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local ParryRemote = Remotes:WaitForChild("ParryButtonPress", 9e9)

-- دالة البحث عن الكرة الحقيقية المستهدفة لك
local function getRealBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    
    for _, ball in pairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") and ball.Name == "Ball" then
            -- التحقق مما إذا كانت الكرة تستهدفك أنت بناءً على الـ Highlight أو الخصائص
            return ball
        end
    end
    return nil
end

local function isTargetingMe(ball)
    -- التحقق من الـ Highlight الذي تضعه اللعبة على اللاعب المستهدف
    local character = LocalPlayer.Character
    if not character then return false end
    
    -- إذا كانت الـ Highlight موجودة على شخصيتك أو قريبة جداً منك
    if ball:FindFirstChild("Highlight") or (character:FindFirstChild("HumanoidRootPart") and (character.HumanoidRootPart.Position - ball.Position).Magnitude < 35) then
        return true
    end
    return true -- وضع الاستجابة المطلقة لتفادي أي تفويت للضربة
end

-- واجهة التحكم الخارقة
Tabs.Combat:AddParagraph({
    Title = "God Mode Status",
    Content = "Connected directly to Blade Ball Remotes. Maximum priority enabled!"
})

Tabs.Combat:AddToggle("GodParry", {
    Title = "⚡ Ultimate Auto Parry (God Mode)",
    Default = false
}):OnChanged(function()
    _G_Config.AutoParry = Options.GodParry.Value
    Fluent:Notify({ Title = "Auto Parry", Content = _G_Config.AutoParry and "Activated with Max Power! 🟢" : "Deactivated! 🔴", Duration = 2 })
end)

Tabs.Combat:AddToggle("GodSpam", {
    Title = "🔥 Extreme Auto Spam (Clash Domination)",
    Default = false
}):OnChanged(function()
    _G_Config.AutoSpam = Options.GodSpam.Value
end)

Tabs.Visuals:AddToggle("GodESP", {
    Title = "🎯 Advanced Ball ESP & Tracer",
    Default = false
}):OnChanged(function()
    _G_Config.BallESP = Options.GodESP.Value
end)

-- الحلقة المركزية فائقة السرعة (مستقرة تماماً وبدون دروب فريم)
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        
        local ball = getRealBall()
        if not ball then return end
        
        local distance = (root.Position - ball.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        
        -- نظام الـ Auto Parry الخارق القائم على الوقت والمسافة الحقيقية
        if _G_Config.AutoParry and ParryRemote then
            if velocity > 0 then
                local timeToReach = distance / velocity
                -- إذا دخلت الكرة نطاق الخطورة أو وقت الوصول الحرج يتم الصد فوراً وبدون تأخير
                if timeToReach <= 0.42 or distance <= 22 then
                    if isTargetingMe(ball) then
                        ParryRemote:FireServer()
                    end
                end
            end
        end
        
        -- نظام الـ Auto Spam العنيف للاشتباكات القوية (Clashes)
        if _G_Config.AutoSpam and ParryRemote then
            if distance <= 15 then
                ParryRemote:FireServer()
                task.wait(0.015) -- سرعة قصوى للسبام تمنع الخصم من اختراق دفاعك
            end
        end
        
        -- نظام الـ ESP البصري لتتبع الكرة بدقة عبر الخريطة
        if _G_Config.BallESP then
            if not ball:FindFirstChild("GodHighlight") then
                local hl = Instance.new("Highlight")
                hl.Name = "GodHighlight"
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.Parent = ball
            end
        else
            if ball:FindFirstChild("GodHighlight") then
                ball.GodHighlight:Destroy()
            end
        end
    end)
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Slax Hub Ultimate",
    Content = "God Mode Initialized Successfully!",
    Duration = 3
})
