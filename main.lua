local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "by dev:yosef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.Unknown
})

local Tabs = {
    Parry = Window:AddTab({ Title = "الصد (Parry)", Icon = "shield" }),
    Spam = Window:AddTab({ Title = "السبام (Spam)", Icon = "zap" }),
    Player = Window:AddTab({ Title = "اللاعب (Player)", Icon = "user" }),
    Settings = Window:AddTab({ Title = "الإعدادات", Icon = "settings" })
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local AutoParry = false
local AutoSpam = false
local SpamSpeed = 0.01

-- ==================== [ إنشاء زر فتح وإغلاق النافذة ] ====================
local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner1 = Instance.new("UICorner")

ScreenGui.Name = "SlaxHubGui"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
ToggleButton.Position = UDim2.new(0, 15, 0.35, 0)
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "Slax"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 18.000
ToggleButton.Active = true
ToggleButton.Draggable = true

UICorner1.CornerRadius = UDim.new(0, 12)
UICorner1.Parent = ToggleButton

local isWindowVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    isWindowVisible = not isWindowVisible
    if Window.Root then
        Window.Root.Visible = isWindowVisible
    end
end)

-- ==================== [ إنشاء زر السبام العائم (Spam UI Button) ] ====================
local SpamButton = Instance.new("TextButton")
local UICorner2 = Instance.new("UICorner")

SpamButton.Name = "SpamButton"
SpamButton.Parent = ScreenGui
SpamButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40) -- أحمر (معطل)
SpamButton.Position = UDim2.new(0, 15, 0.45, 0)
SpamButton.Size = UDim2.new(0, 60, 0, 50)
SpamButton.Font = Enum.Font.SourceSansBold
SpamButton.Text = "Spam: OFF"
SpamButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamButton.TextSize = 14.000
SpamButton.Active = true
SpamButton.Draggable = true

UICorner2.CornerRadius = UDim.new(0, 12)
UICorner2.Parent = SpamButton

local function updateSpamState(state)
    AutoSpam = state
    if AutoSpam then
        SpamButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80) -- أخضر (مفعل)
        SpamButton.Text = "Spam: ON"
    else
        SpamButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40) -- أحمر (معطل)
        SpamButton.Text = "Spam: OFF"
    end
end

SpamButton.MouseButton1Click:Connect(function()
    updateSpamState(not AutoSpam)
end)

-- نظام الصد المباشر عبر RemoteEvent
local function triggerParry()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
    for _, obj in pairs(remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("parry") or obj.Name:lower():find("ability")) then
            obj:FireServer()
            break
        end
    end
end

-- ==================== [ قسم الصد - Parry ] ====================
Tabs.Parry:AddSection("نظام الصد الدقيق الحركي")

local AutoParryToggle = Tabs.Parry:AddToggle("AutoParry", {
    Title = "تفعيل Auto Accuracy Parry",
    Default = false,
    Description = "صد تلقائي ذكي يحسب مسافة واقتراب وسرعة الكرة بدقة"
})

AutoParryToggle:OnChanged(function(Value)
    AutoParry = Value
end)

-- ==================== [ قسم السبام - Spam ] ====================
Tabs.Spam:AddSection("خيارات تكرار الصد (Spam)")

local AutoSpamToggle = Tabs.Spam:AddToggle("AutoSpam", {
    Title = "تفعيل Auto Spam",
    Default = false,
    Description = "صد متكرر وسريع عند الاشتباك القريب جداً"
})

AutoSpamToggle:OnChanged(function(Value)
    updateSpamState(Value)
end)

Tabs.Spam:AddKeybind("ManualSpamKey", {
    Title = "زر السبام اليدوي (Manual Spam Key)",
    Mode = "Hold",
    Default = "E",
    Callback = function(Value)
        if Value then
            triggerParry()
        end
    end
})

Tabs.Spam:AddSlider("SpamDelay", {
    Title = "سرعة السبام (Spam Speed Delay)",
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        SpamSpeed = Value / 1000
    end
})

-- ==================== [ قسم اللاعب - Player ] ====================
Tabs.Player:AddSection("قدرات وميزات الشخصية")

Tabs.Player:AddSlider("WalkSpeed", {
    Title = "سرعة المشي (WalkSpeed)",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
    end
})

-- ==================== [ نظام Auto Accuracy ] ====================

RunService.RenderStepped:Connect(function()
    if not AutoParry then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    for _, ball in pairs(ballsFolder:GetChildren()) do
        local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
        if target == LocalPlayer.Name or target == LocalPlayer.DisplayName then
            local ballPosition = ball.Position
            local ballVelocity = ball.AssemblyLinearVelocity
            local distance = (ballPosition - rootPart.Position).Magnitude
            
            local directionToPlayer = (rootPart.Position - ballPosition).Unit
            local ballDirection = ballVelocity.Unit
            local dotProduct = ballDirection:Dot(directionToPlayer)
            
            if dotProduct > 0 then
                local speed = ballVelocity.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                
                local dynamicParryDistance = math.clamp((speed * (0.32 + ping)), 14, 100)
                
                if distance <= dynamicParryDistance then
                    triggerParry()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(SpamSpeed)
        if AutoSpam then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local ballsFolder = workspace:FindFirstChild("Balls")
                if ballsFolder then
                    for _, ball in pairs(ballsFolder:GetChildren()) do
                        local distance = (ball.Position - character.HumanoidRootPart.Position).Magnitude
                        if distance <= 14 then
                            triggerParry()
                        end
                    end
                end
            end
        end
    end
end)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "تم إضافة زر السبام العائم بنجاح!",
    Duration = 4
})
