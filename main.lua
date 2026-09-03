--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--       VBL - Ball Hitbox & Enemy Look Indicators  --
--==================================================--

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- إنشاء النافذة الرئيسية
local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Volleyball Legends",
    SubTitle = "by yossef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- إضافة التبويبات
local Tabs = {
    Hitbox = Window:AddTab({ Title = "Ball Hitbox", Icon = "target" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- المتغيرات العامة
getgenv().HitboxConfig = {
    Enabled = false,
    Size = 15,
    Transparency = 0.5,
    CanCollide = false
}

getgenv().VisualConfig = {
    EnemyLookIndicators = false,
    Distance = 60 -- مسافة 60 Studs
}

-- جدول حفظ المؤشرات والألوان الخاصة بكل منافس
local EnemyIndicators = {}

-- قائمة الألوان المتاحة للمنافسين لضمان اختلاف الألوان
local ColorList = {
    Color3.fromRGB(255, 50, 50),   -- أحمر
    Color3.fromRGB(50, 255, 50),   -- أخضر
    Color3.fromRGB(50, 150, 255),  -- أزرق
    Color3.fromRGB(255, 255, 50),  -- أصفر
    Color3.fromRGB(255, 50, 255),  -- وردي / بنفسجي
    Color3.fromRGB(255, 150, 0),   -- برتقالي
    Color3.fromRGB(0, 255, 255)    -- تركوازي
}

----------------------------------------------------
-- [قسم الهيتبوكس - Ball Hitbox Tab]
----------------------------------------------------

local HitboxToggle = Tabs.Hitbox:AddToggle("HitboxToggle", {
    Title = "Enable Ball Hitbox",
    Default = false,
    Description = "تكبير نطاق لمس الكرة للضرب بسهولة"
})

HitboxToggle:OnChanged(function(Value)
    getgenv().HitboxConfig.Enabled = Value
    if not Value then
        local ball = workspace:FindFirstChild("Ball") or workspace:FindFirstChild("CLIENT_BALL_")
        if ball then
            ball.Size = Vector3.new(2, 2, 2)
            ball.Transparency = 0
            ball.CanCollide = true
        end
    end
end)

Tabs.Hitbox:AddSlider("HitboxSize", {
    Title = "Hitbox Size",
    Description = "تحديد حجم هيتبوكس الكرة (5 إلى 30)",
    Default = 15,
    Min = 5,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        getgenv().HitboxConfig.Size = Value
    end
})

Tabs.Hitbox:AddSlider("HitboxTransparency", {
    Title = "Hitbox Transparency",
    Description = "التحكم في درجة رؤية الهيتبوكس",
    Default = 5,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        getgenv().HitboxConfig.Transparency = Value / 10
    end
end)

----------------------------------------------------
-- [قسم المؤشرات البصرية - Visuals Tab]
----------------------------------------------------

local EnemyToggle = Tabs.Visuals:AddToggle("EnemyLookToggle", {
    Title = "Enemies Look Indicators (60 Studs)",
    Default = false,
    Description = "إظهار مؤشر اتجاه نظر اللاعبين المنافسين فقط (لكل منافس لون مختلف)"
})

-- تنظيف جميع المؤشرات عند إيقاف الخيار
local function clearIndicators()
    for _, item in pairs(EnemyIndicators) do
        if item.Part then
            item.Part:Destroy()
        end
    end
    EnemyIndicators = {}
end

EnemyToggle:OnChanged(function(Value)
    getgenv().VisualConfig.EnemyLookIndicators = Value
    if not Value then
        clearIndicators()
    end
end)

----------------------------------------------------
-- [قسم الحقوق والإعدادات - Settings Tab]
----------------------------------------------------

Tabs.Settings:AddParagraph({
    Title = "Slax Hub Rights",
    Content = "Developed exclusively by yossef.\nAll Rights Reserved © 2026."
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("SlaxHubConfig")
SaveManager:SetFolder("SlaxHubConfig/configs")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "تم تحميل السكربت بنجاح! الحقوق لـ yossef.",
    Duration = 5
})

----------------------------------------------------
-- [دوال وإدارة مؤشرات الأعداء]
----------------------------------------------------

local function getOrCreateIndicator(player, colorIndex)
    if not EnemyIndicators[player] then
        local part = Instance.new("Part")
        part.Name = "EnemyLookIndicator_" .. player.Name
        part.Size = Vector3.new(1.5, 1.5, 1.5)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        local assignedColor = ColorList[((colorIndex - 1) % #ColorList) + 1]
        part.Color = assignedColor
        part.CanCollide = false
        part.Anchored = true
        part.Transparency = 0.3
        part.Parent = workspace

        EnemyIndicators[player] = {
            Part = part,
            Color = assignedColor
        }
    end
    return EnemyIndicators[player].Part
end

----------------------------------------------------
-- [المحرك الأساسي - Main Loop]
----------------------------------------------------

RunService.RenderStepped:Connect(function()
    -- 1. تحديث هيتبوكس الكرة
    if getgenv().HitboxConfig.Enabled then
        local ball = workspace:FindFirstChild("Ball") or workspace:FindFirstChild("CLIENT_BALL_")
        if ball and ball:IsA("BasePart") then
            local size = getgenv().HitboxConfig.Size
            ball.Size = Vector3.new(size, size, size)
            ball.Transparency = getgenv().HitboxConfig.Transparency
            ball.CanCollide = getgenv().HitboxConfig.CanCollide
        end
    end

    -- 2. تحديث مؤشرات اتجاه نظر المنافسين (Enemies Only)
    if getgenv().VisualConfig.EnemyLookIndicators then
        local activePlayers = {}
        local enemyIndex = 0

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and (player.Team == nil or player.Team ~= LocalPlayer.Team) then
                enemyIndex = enemyIndex + 1
                activePlayers[player] = true

                local char = player.Character
                local head = char and char:FindFirstChild("Head")

                if head then
                    local indicatorPart = getOrCreateIndicator(player, enemyIndex)
                    indicatorPart.Transparency = 0.3
                    
                    local lookDirection = head.CFrame.LookVector
                    local targetPosition = head.CFrame.Position + (lookDirection * getgenv().VisualConfig.Distance)
                    indicatorPart.Position = targetPosition
                else
                    if EnemyIndicators[player] and EnemyIndicators[player].Part then
                        EnemyIndicators[player].Part.Transparency = 1
                    end
                end
            end
        end

        for player, data in pairs(EnemyIndicators) do
            if not activePlayers[player] then
                if data.Part then
                    data.Part:Destroy()
                end
                EnemyIndicators[player] = nil
            end
        end
    end
end)
