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

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local AutoParry = false
local AutoSpam = false
local SpamSpeed = 0.01

local function triggerParry()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(0.01)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
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
    AutoSpam = Value
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

-- ==================== [ نظام Auto Accuracy القائم على اتجاه وسرعة الكرة ] ====================

RunService.RenderStepped:Connect(function()
    if not AutoParry then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    for _, ball in pairs(ballsFolder:GetChildren()) do
        if ball:GetAttribute("target") == LocalPlayer.Name or ball:GetAttribute("Target") == LocalPlayer.Name then
            local ballPosition = ball.Position
            local ballVelocity = ball.AssemblyLinearVelocity
            local distance = (ballPosition - rootPart.Position).Magnitude
            
            -- حساب اتجاه حركة الكرة (هل تقترب أم تبتعد)
            local directionToPlayer = (rootPart.Position - ballPosition).Unit
            local ballDirection = ballVelocity.Unit
            local dotProduct = ballDirection:Dot(directionToPlayer)
            
            -- تنفيذ الصد فقط إذا كانت الكرة متجهة نحو اللاعب (Dot > 0)
            if dotProduct > 0 then
                local speed = ballVelocity.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                
                -- معادلة الدقة الديناميكية (Dynamic Auto Accuracy)
                local dynamicParryDistance = math.clamp((speed * (0.28 + ping)), 12, 90)
                
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
                        if distance <= 12 then
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
    Content = "تم تفعيل نظام Auto Accuracy بنجاح!",
    Duration = 4
})
