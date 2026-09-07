-- Blade Ball - Smart Auto Parry (Hooked to Manual Block) by Slax Hub
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

if LocalPlayer.PlayerGui:FindFirstChild("BladeBallHub") then
    LocalPlayer.PlayerGui.BladeBallHub:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallHub"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 160)
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
UIStroke.Color = Color3.fromRGB(255, 60, 60)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "BLADE BALL - HOOK FIX"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 45)
StatusLabel.Position = UDim2.new(0, 10, 0, 35)
StatusLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
StatusLabel.Text = "Status: Press Block Manually Once! ⚠️"
StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 10
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -20, 0, 35)
ToggleBtn.Position = UDim2.new(0, 10, 0, 95)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
ToggleBtn.Text = "AUTO PARRY: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 11
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

local capturedRemote = nil
local autoParryEnabled = false

-- التقاط الـ Remote تلقائياً عند أول ضغطة يدويّة يقوم بها اللاعب
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "FireServer" and self:IsA("RemoteEvent") then
        local name = string.lower(self.Name)
        -- البحث عن أحداث الصد أو الـ Parry
        if string.find(name, "parry") or string.find(name, "block") or string.find(name, "hit") or string.find(name, "deflect") then
            if not capturedRemote then
                capturedRemote = self
                StatusLabel.Text = "Status: Hooked Successfully! ✅"
                StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
            end
        end
    end
    
    return oldNamecall(self, ...)
end)

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

-- نظام التتبع والصد التلقائي بناءً على المسافة والسرعة للكرة
task.spawn(function()
    while true() do
        task.wait(0.01)
        if autoParryEnabled and capturedRemote and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            
            for _, ball in pairs(workspace:GetChildren()) do
                if ball.Name == "Ball" and ball:IsA("BasePart") then
                    local distance = (root.Position - ball.Position).Magnitude
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    
                    -- معادلة حساب المسافة والسرعة للصد التلقائي
                    local threshold = math.clamp(velocity * 0.15, 15, 35)
                    
                    if distance <= threshold then
                        pcall(function()
                            capturedRemote:FireServer()
                        end)
                        task.wait(0.15) -- منع السبام السريع للحظر
                    end
                end
            end
        end
    end
end)
