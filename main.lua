local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "by dev:yosef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Parry = Window:AddTab({ Title = "الصد (Parry)", Icon = "shield" }),
    Spam = Window:AddTab({ Title = "السبام (Spam)", Icon = "zap" }),
    Player = Window:AddTab({ Title = "اللاعب (Player)", Icon = "user" }),
    Settings = Window:AddTab({ Title = "الإعدادات", Icon = "settings" })
}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AutoParry = false
local AutoSpam = false
local ManualSpamActive = false
local SpamSpeed = 0.02
local LastParryTime = 0

-- دالة الصد الآمنة المحاكاة للبشر لتفادي الطرد
local function safeParry()
    local currentTime = tick()
    if currentTime - LastParryTime < 0.15 then return end
    LastParryTime = currentTime
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(math.random(25, 45) / 1000) -- تأخير بشري عشوائي بين الضغطة والرفع
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
end

-- ==================== [ إنشاء زر الشاشة للمانوال سبام ] ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxSpamGui"
ScreenGui.Parent = CoreGui:FindFirstChild("RobloxGui") or CoreGui
ScreenGui.ResetOnSpawn = false

local SpamButton = Instance.new("TextButton")
SpamButton.Name = "SpamToggleButton"
SpamButton.Size = UDim2.new(0, 110, 0, 50)
SpamButton.Position = UDim2.new(0.5, -55, 0.2, 0)
SpamButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
SpamButton.TextColor3 = Color3.fromRGB(255, 60, 60)
SpamButton.Text = "SPAM: OFF"
SpamButton.TextSize = 16
SpamButton.Font = Enum.Font.SourceSansBold
SpamButton.Active = true
SpamButton.Draggable = true
SpamButton.Visible = false
SpamButton.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = SpamButton

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 60, 60)
UIStroke.Thickness = 2
UIStroke.Parent = SpamButton

SpamButton.MouseButton1Click:Connect(function()
    ManualSpamActive = not ManualSpamActive
    if ManualSpamActive then
        SpamButton.Text = "SPAM: ON"
        SpamButton.TextColor3 = Color3.fromRGB(60, 255, 60)
        UIStroke.Color = Color3.fromRGB(60, 255, 60)
    else
        SpamButton.Text = "SPAM: OFF"
        SpamButton.TextColor3 = Color3.fromRGB(255, 60, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 60)
    end
end)

-- ==================== [ قسم الصد - Parry ] ====================
Tabs.Parry:AddSection("نظام الصد المحمي")

local AutoParryToggle = Tabs.Parry:AddToggle("AutoParry", {
    Title = "تفعيل Auto Accuracy Parry",
    Default = false,
    Description = "صد ذكي آمن من حظر الأنتي تشيت"
})

AutoParryToggle:OnChanged(function(Value)
    AutoParry = Value
end)

-- ==================== [ قسم السبام - Spam ] ====================
Tabs.Spam:AddSection("خيارات السبام")

local AutoSpamToggle = Tabs.Spam:AddToggle("AutoSpam", {
    Title = "تفعيل Auto Spam",
    Default = false,
    Description = "صد متكرر آمن عند الاشتباك القريب"
})

AutoSpamToggle:OnChanged(function(Value)
    AutoSpam = Value
end)

local ManualSpamButtonToggle = Tabs.Spam:AddToggle("ShowManualSpamButton", {
    Title = "إظهار زر السبام على الشاشة (Manual Spam Button)",
    Default = false,
    Description = "يظهر زر عائم يمكنك تحريكه والضغط عليه لتشغيل/إيقاف السبام"
})

ManualSpamButtonToggle:OnChanged(function(Value)
    SpamButton.Visible = Value
    if not Value then
        ManualSpamActive = false
        SpamButton.Text = "SPAM: OFF"
        SpamButton.TextColor3 = Color3.fromRGB(255, 60, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 60)
    end
end)

Tabs.Spam:AddSlider("SpamDelay", {
    Title = "سرعة السبام",
    Default = 20,
    Min = 10,
    Max = 60,
    Rounding = 0,
    Callback = function(Value)
        SpamSpeed = Value / 1000
    end
})

-- ==================== [ قسم اللاعب - Player ] ====================
Tabs.Player:AddSection("قدرات الشخصية")

Tabs.Player:AddSlider("WalkSpeed", {
    Title = "سرعة المشي",
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

-- ==================== [ الحلقات البرمجية آمنة التوقيت ] ====================

task.spawn(function()
    while true do
        task.wait(0.03) -- تخفيف معدل التكرار لتفادي كشف الـ High Frequency Spam
        if AutoParry then
            pcall(function()
                local character = LocalPlayer.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then return end
                
                local rootPart = character.HumanoidRootPart
                local ballsFolder = workspace:FindFirstChild("Balls")
                if not ballsFolder then return end
                
                for _, ball in pairs(ballsFolder:GetChildren()) do
                    -- فحص كائن الكرة وتحديد النوايا
                    local target = ball:GetAttribute("target") or ball:GetAttribute("Target")
                    if target == LocalPlayer.Name then
                        local ballPosition = ball.Position
                        local ballVelocity = ball.AssemblyLinearVelocity
                        local distance = (ballPosition - rootPart.Position).Magnitude
                        
                        local directionToPlayer = (rootPart.Position - ballPosition).Unit
                        local ballDirection = ballVelocity.Unit
                        local dotProduct = ballDirection:Dot(directionToPlayer)
                        
                        if dotProduct > 0 then
                            local speed = ballVelocity.Magnitude
                            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                            -- حساب المسافة المحمية ديناميكياً
                            local dynamicParryDistance = math.clamp((speed * (0.18 + ping)), 8, 60)
                            
                            if distance <= dynamicParryDistance then
                                safeParry()
                            end
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(SpamSpeed)
        if AutoSpam or ManualSpamActive then
            safeParry()
        end
    end
end)

Fluent:Notify({
    Title = "Slax Hub",
    Content = "تم تحديث الحماية وتخطي الطرد بنجاح!",
    Duration = 4
})
