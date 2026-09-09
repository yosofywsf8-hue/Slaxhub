-- SlaxHub Pro - Final Optimized Engine (FireServer Edition)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

if CoreGui:FindFirstChild("SlaxHubPro") then
    CoreGui.SlaxHubPro:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubPro"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 175)
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
Title.Text = "SLAX HUB // COUNTER MODE"
Title.TextColor3 = Color3.fromRGB(0, 255, 150)
Title.TextSize, Title.Font = 13, Enum.Font.Code
Title.Parent = MainFrame

local ParryBtn = Instance.new("TextButton")
ParryBtn.Size = UDim2.new(0.9, 0, 0, 32)
ParryBtn.Position = UDim2.new(0.05, 0, 0.22, 0)
ParryBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ParryBtn.Text = "Auto Parry: [ OFF ]"
ParryBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
ParryBtn.TextSize, ParryBtn.Font = 12, Enum.Font.Code
ParryBtn.Parent = MainFrame
Instance.new("UICorner", ParryBtn).CornerRadius = UDim.new(0, 6)

local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Size = UDim2.new(0.9, 0, 0, 32)
TriggerBtn.Position = UDim2.new(0.05, 0, 0.45, 0)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TriggerBtn.Text = "Trigger Bot: [ OFF ]"
TriggerBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
TriggerBtn.TextSize, TriggerBtn.Font = 12, Enum.Font.Code
TriggerBtn.Parent = MainFrame
Instance.new("UICorner", TriggerBtn).CornerRadius = UDim.new(0, 6)

local CounterLabel = Instance.new("TextLabel")
CounterLabel.Size = UDim2.new(0.9, 0, 0, 28)
CounterLabel.Position = UDim2.new(0.05, 0, 0.68, 0)
CounterLabel.BackgroundTransparency = 1
CounterLabel.Text = "Strikes Count: 0 / Required: 2"
CounterLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
CounterLabel.TextSize, CounterLabel.Font = 11, Enum.Font.Code
CounterLabel.Parent = MainFrame

local ModeBtn = Instance.new("TextButton")
ModeBtn.Size = UDim2.new(0.9, 0, 0, 25)
ModeBtn.Position = UDim2.new(0.05, 0, 0.84, 0)
ModeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ModeBtn.Text = "Target Hits: 2 (Click to Change)"
ModeBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
ModeBtn.TextSize, ModeBtn.Font = 10, Enum.Font.Code
ModeBtn.Parent = MainFrame
Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 5)

local autoParryActive = false
local triggerBotActive = false
local requiredHits = 2
local currentHits = 0
local lastAction = 0
local lastBallTarget = nil

ParryBtn.MouseButton1Click:Connect(function()
    autoParryActive = not autoParryActive
    ParryBtn.Text = autoParryActive and "Auto Parry: [ ON ]" or "Auto Parry: [ OFF ]"
    ParryBtn.TextColor3 = autoParryActive and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 50, 50)
    currentHits = 0
end)

TriggerBtn.MouseButton1Click:Connect(function()
    triggerBotActive = not triggerBotActive
    TriggerBtn.Text = triggerBotActive and "Trigger Bot: [ ON ]" or "Trigger Bot: [ OFF ]"
    TriggerBtn.TextColor3 = triggerBotActive and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 50, 50)
end)

ModeBtn.MouseButton1Click:Connect(function()
    requiredHits = requiredHits + 1
    if requiredHits > 3 then requiredHits = 1 end
    ModeBtn.Text = "Target Hits: " .. requiredHits .. " (Click to Change)"
end)

RunService.Heartbeat:Connect(function()
    if not autoParryActive and not triggerBotActive then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hrp = char.HumanoidRootPart
        
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then return end
        
        local now = tick()
        if now - lastAction < 0.05 then return end
        
        for _, ball in pairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") then
                local dist = (hrp.Position - ball.Position).Magnitude
                local vel = ball.AssemblyLinearVelocity.Magnitude
                
                local target = ball:GetAttribute("realBallLockedPlayer") or ball:GetAttribute("target")
                if target ~= lastBallTarget then
                    if target == LocalPlayer.Name then
                        currentHits = currentHits + 1
                    end
                    lastBallTarget = target
                end
                
                CounterLabel.Text = "Strikes: " .. currentHits .. " / Req: " .. requiredHits
                
                local isTargettingMe = (target == LocalPlayer.Name or dist <= 16)
                
                if vel > 0 and isTargettingMe then
                    local timeToHit = dist / vel
                    
                    if autoParryActive and currentHits >= requiredHits and (timeToHit <= 0.45 or dist <= 18) then
                        Game:GetService("ReplicatedStorage").Remotes.ParryButtonPress:FireServer()
                        lastAction = now + 0.1
                        currentHits = 0
                    elseif triggerBotActive and dist <= 12 then
                        Game:GetService("ReplicatedStorage").Remotes.ParryButtonPress:FireServer()
                        lastAction = now + 0.05
                    end
                end
            end
        end
    end)
end)
