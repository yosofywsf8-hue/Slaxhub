-- Slax Hub | Optimized Auto Parry Logic (From MyCompiler)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local Balls = Workspace:WaitForChild("Balls", 9e9)

-- دالة التحقق من أن الكائن هو الكرة الحقيقية المستهدفة
local function VerifyBall(Ball)
    if typeof(Ball) == "Instance" and Ball:IsA("BasePart") and Ball:IsDescendantOf(Balls) and Ball:GetAttribute("realBall") == true then
        return true
    end
end

-- دالة التحقق مما إذا كان اللاعب مستهدفاً عبر الـ Highlight
local function IsTarget()
    return (Player.Character and Player.Character:FindFirstChild("Highlight") ~= nil)
end

-- دالة إرسال ريموت ParryButtonPress الخاص باللعبة
local function Parry()
    local parryRemote = Remotes:FindFirstChild("ParryButtonPress")
    if parryRemote then
        parryRemote:Fire()
    end
end

-- ربط منطق الحسابات عند ظهور الكرة
local function TrackBall(Ball)
    if not VerifyBall(Ball) then return end
    
    local OldPosition = Ball.Position
    local OldTick = tick()
    
    Ball:GetPropertyChangedSignal("Position"):Connect(function()
        if IsTarget() then
            local Distance = (Ball.Position - Workspace.CurrentCamera.Focus.Position).Magnitude
            local Velocity = (OldPosition - Ball.Position).Magnitude
            
            if Velocity > 0 then
                local TimeToReach = Distance / Velocity
                if TimeToReach <= 10 then
                    Parry()
                end
            end
        end
        
        if (tick() - OldTick >= 1/60) then
            OldTick = tick()
            OldPosition = Ball.Position
        end
    end)
end

-- تفعيل الفحص على الكرات الحالية والجديدة
for _, ball in ipairs(Balls:GetChildren()) do
    TrackBall(ball)
end

Balls.ChildAdded:Connect(function(Ball)
    TrackBall(Ball)
end)
