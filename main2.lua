-- Blade Ball - Delta Optimized Auto Parry
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- التحقق من الاتصال بالريموت الخاص باللعبة
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local parryEvent = remotes and remotes:FindFirstChild("ParryButtonPress")

if not parryEvent then
    warn("[Delta Hub] Parry Remote not found! Make sure you are inside an active match.")
else
    print("[Delta Hub] Auto Parry successfully loaded and linked!")
end

RunService.Heartbeat:Connect(function()
    if not parryEvent then return end
    
    pcall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local rootPart = character.HumanoidRootPart
        
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then return end
        
        for _, ball in pairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") then
                local distance = (rootPart.Position - ball.Position).Magnitude
                local velocity = ball.AssemblyLinearVelocity.Magnitude
                
                if velocity > 0 then
                    local timeToReach = distance / velocity
                    
                    -- عتبة الاستجابة المتوافقة مع أداء دلتا
                    if timeToReach <= 0.38 or distance <= 15 then
                        parryEvent:FireServer()
                        task.wait(0.1)
                    end
                end
            end
        end
    end)
end)
