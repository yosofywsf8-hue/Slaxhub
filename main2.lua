-- Blade Ball - Universal Safe Auto Parry by Slax Hub
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if LocalPlayer.PlayerGui:FindFirstChild("BladeBallHub") then
    LocalPlayer.PlayerGui.BladeBallHub:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallHub"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 150)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 200, 100)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "BLADE BALL - AUTO PARRY"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 35)
StatusLabel.Position = UDim2.new(0, 10, 0, 32)
StatusLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
StatusLabel.Text = "Status: Ready & Active ✅"
StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 10
StatusLabel.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -20, 0, 35)
ToggleBtn.Position = UDim2.new(0, 10, 0, 85)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
ToggleBtn.Text = "AUTO PARRY: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 11
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

local autoParryEnabled = false

ToggleBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    if autoParryEnabled then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 60)
        ToggleBtn.Text = "AUTO PARRY: ON"
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        ToggleBtn.Text = "AUTO PARRY: OFF"
    end
end)

-- البحث التلقائي عن حدث الـ Parry في اللعبة وتفعيله مباشرة
local function getParryRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = string.lower(obj.Name)
            if string.find(name, "parry") or string.find(name, "ability") or string.find(name, "deflect") then
                return obj
            end
        end
    end
    return nil
end

-- حلقة التتبع والصد الذكي
task.spawn(function()
    while true do
        task.wait(0.01)
        if autoParryEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            local remote = getParryRemote()
            
            for _, ball in pairs(workspace:GetChildren()) do
                if (ball.Name == "Ball" or string.find(string.lower(ball.Name), "ball")) and ball:IsA("BasePart") then
                    local distance = (root.Position - ball.Position).Magnitude
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    
                    -- مسافة الصد تتناسب طردياً مع سرعة الكرة القادمة نحو اللاعب
                    local triggerDistance = math.clamp(velocity * 0.12, 14, 30)
                    
                    if distance <= triggerDistance and remote then
                        pcall(function()
                            remote:FireServer()
                        end)
                        task.wait(0.2) -- فاصل زمني بسيط لمنع الحظر
                    end
                end
            end
        end
    end
end)
