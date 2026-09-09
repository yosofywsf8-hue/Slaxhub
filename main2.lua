-- SlaxHub Pro Engine | Blade Ball Core
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- إزالة الواجهة القديمة إن وجدت لتجنب التداخل
if CoreGui:FindFirstChild("SlaxHubPro") then
    CoreGui.SlaxHubPro:Destroy()
end

-- بناء واجهة احترافية وخفيفة جداً (Custom Minimal GUI)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubPro"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 130)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "SLAX HUB // PRO"
Title.TextColor3 = Color3.fromRGB(0, 255, 150)
Title.TextSize = 14
Title.Font = Enum.Font.Code
Title.Parent = MainFrame

-- زر تفعيل الأوتو باري الاحترافي
local ParryBtn = Instance.new("TextButton")
ParryBtn.Size = UDim2.new(0.9, 0, 0, 35)
ParryBtn.Position = UDim2.new(0.05, 0, 0.3, 0)
ParryBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ParryBtn.Text = "Auto Parry: [ OFF ]"
ParryBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
ParryBtn.TextSize, ParryBtn.Font = 12, Enum.Font.Code
ParryBtn.Parent = MainFrame
Instance.new("UICorner", ParryBtn).CornerRadius = UDim.new(0, 6)

-- زر تفعيل الـ Trigger Bot
local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Size = UDim2.new(0.9, 0, 0, 35)
TriggerBtn.Position = UDim2.new(0.05, 0, 0.65, 0)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TriggerBtn.Text = "Trigger Bot: [ OFF ]"
TriggerBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
TriggerBtn.TextSize, TriggerBtn.Font = 12, Enum.Font.Code
TriggerBtn.Parent = MainFrame
Instance.new("UICorner", TriggerBtn).CornerRadius = UDim.new(0, 6)

local autoParryActive = false
local triggerBotActive = false
local lastAction = 0

ParryBtn.MouseButton1Click:Connect(function()
    autoParryActive = not autoParryActive
    ParryBtn.Text = autoParryActive and "Auto Parry: [ ON ]" or "Auto Parry: [ OFF ]"
    ParryBtn.TextColor3 = autoParryActive and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 50, 50)
end)

TriggerBtn.MouseButton1Click:Connect(function()
    triggerBotActive = not triggerBotActive
    TriggerBtn.Text = triggerBotActive and "Trigger Bot: [ ON ]" or "Trigger Bot: [ OFF ]"
    TriggerBtn.TextColor3 = triggerBotActive and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 50, 50)
end)

-- محرك الاستدعاء المباشر والآمن المتوافق مع Delta
local function getRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and remotes:FindFirstChild("ParryButtonPress") then
        return remotes.ParryButtonPress
    end
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name == "ParryButtonPress" or v.Name == "Parry") then
            return v
        end
    end
    return nil
end

RunService.Heartbeat:Connect(function()
    if not autoParryActive and not triggerBotActive then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hrp = char.HumanoidRootPart
        
        local remote = getRemote()
        if not remote then return end
        
        local balls = workspace:FindFirstChild("Balls")
        if not balls then return end
        
        local now = tick()
        if now - lastAction < 0.08 then return end
        
        for _, ball in pairs(balls:GetChildren()) do
            if ball:IsA("BasePart") then
                local dist = (hrp.Position - ball.Position).Magnitude
                local vel = ball.AssemblyLinearVelocity.Magnitude
                
                if vel > 0 then
                    local timeToHit = dist / vel
                    
                    if autoParryActive and (timeToHit <= 0.38 or dist <= 15) then
                        remote:FireServer()
                        lastAction = now + 0.03
                    elseif triggerBotActive and dist <= 10 then
                        remote:FireServer()
                        lastAction = now + 0.01
                    end
                end
            end
        end
    end)
end)
