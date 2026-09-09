-- Blade Ball - Direct Working Auto Parry (No Crash)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryEvent = remotes:WaitForChild("ParryButtonPress")

-- تشغيل تلقائي بمجرد تفعيل السكربت
print("[Slax Hub] Auto Parry Initialized & Running!")

RunService.Heartbeat:Connect(function()
    pcall(function()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local rootPart = character.HumanoidRootPart
        
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then return end
        
        for _, ball in pairs(ballsFolder:GetChildren()) do
            -- التحقق من الكرة الحقيقية الموجهة إليك
            if ball:IsA("BasePart") then
                local distance = (rootPart.Position - ball.Position).Magnitude
                local velocity = ball.AssemblyLinearVelocity.Magnitude
                
                if velocity > 0 then
                    local timeToReach = distance / velocity
                    
                    -- المسافة ووقت الاستجابة المباشر للصد الفوري
                    if timeToReach <= 0.4 or distance <= 16 then
                        parryEvent:Fire()
                        task.wait(0.1)
                    end
                end
            end
        end
    end)
end)
