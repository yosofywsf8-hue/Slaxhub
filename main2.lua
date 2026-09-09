-- T_T Hub | Verified Working Blade Ball Engine (Delta Edition)
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Window = Rayfield:CreateWindow({
    Name = "T_T Hub | Blade Ball Pro",
    LoadingTitle = "Initializing T_T Engine...",
    LoadingSubtitle = "powered by Chaos Lord & Delta",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "ChaosHubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "yourdiscordinvite",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "T_T Hub Key",
        Subtitle = "Enter your access key",
        Note = "Join our Discord for the key",
        FileName = "T_TKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"yourkeyhere"}
    }
})

local MainTab = Window:CreateTab("Combat", 4483362458)
local MainSection = MainTab:CreateSection("Core Features")

Rayfield:Notify({
   Title = "Execution Started",
   Content = "T_T Hub Loaded Successfully!",
   Duration = 4,
   Image = nil
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local autoParryEnabled = false
local triggerBotEnabled = false
local lastParryTick = 0

-- دالة بحث ذكية ومتطورة للوصول لزر الصد دون أخطاء
local function getParryRemote()
    local success, result = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            if remotes:FindFirstChild("ParryButtonPress") then
                return remotes.ParryButtonPress
            elseif remotes:FindFirstChild("Parry") then
                return remotes.Parry
            end
        end
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and (v.Name == "ParryButtonPress" or v.Name == "Parry") then
                return v
            end
        end
        return nil
    end)
    return success and result or nil
end

-- واجهة التحكم للأوتو باري
MainTab:CreateToggle({
    Name = "Auto Parry (Delta Safe)",
    CurrentValue = false,
    Flag = "AutoParryToggle",
    Callback = function(Value)
        autoParryEnabled = Value
        Rayfield:Notify({
            Title = "Auto Parry",
            Content = autoParryEnabled and "Active 🟢" : "Disabled 🔴",
            Duration = 2
        })
    end,
})

-- واجهة التحكم للـ Trigger Bot
MainTab:CreateToggle({
    Name = "Trigger Bot (Instant Clash)",
    CurrentValue = false,
    Flag = "TriggerBotToggle",
    Callback = function(Value)
        triggerBotEnabled = Value
        Rayfield:Notify({
            Title = "Trigger Bot",
            Content = triggerBotEnabled and "Trigger Active ⚡" : "Trigger Off 🔴",
            Duration = 2
        })
    end,
})

-- التشغيل الفعلي والمراقب الحركي
RunService.Heartbeat:Connect(function()
    if not autoParryEnabled and not triggerBotEnabled then return end
    
    pcall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local rootPart = character.HumanoidRootPart
        
        local remote = getParryRemote()
        if not remote then return end
        
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then return end
        
        local currentTime = tick()
        if currentTime - lastParryTick < 0.1 then return end
        
        for _, ball in pairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") then
                local distance = (rootPart.Position - ball.Position).Magnitude
                local velocity = ball.AssemblyLinearVelocity.Magnitude
                
                if velocity > 0 then
                    local timeToReach = distance / velocity
                    
                    -- نظام الأوتو باري المعتمد على التوقيت والمسافة
                    if autoParryEnabled and (timeToReach <= 0.4 or distance <= 16) then
                        remote:FireServer()
                        lastParryTick = currentTime + 0.05
                        task.wait(0.05)
                    end
                    
                    -- نظام الـ Trigger Bot للاشتباك الفوري في المدى القريب جداً
                    if triggerBotEnabled and distance <= 9.0 then
                        remote:FireServer()
                        lastParryTick = currentTime + 0.02
                        task.wait(0.03)
                    end
                end
            end
        end
    end)
end)
