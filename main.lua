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

-- Window Setup
local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Volleyball Legends",
    SubTitle = "by yossef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false, -- تم إيقاف الأكريليك لضمان عدم التقطيع في الهاتف
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Hitbox = Window:AddTab({ Title = "Ball Hitbox", Icon = "target" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

getgenv().HitboxConfig = { Enabled = false, Size = 15, Transparency = 0.5 }
getgenv().VisualConfig = { EnemyLookIndicators = false, Distance = 60 }

local EnemyIndicators = {}
local ColorList = {
    Color3.fromRGB(255, 50, 50),
    Color3.fromRGB(50, 255, 50),
    Color3.fromRGB(50, 150, 255),
    Color3.fromRGB(255, 255, 50),
    Color3.fromRGB(255, 50, 255),
    Color3.fromRGB(255, 150, 0),
    Color3.fromRGB(0, 255, 255)
}

-- البحث المتقدم عن الكرة
local function getBall()
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("ball") or obj.Name:lower():find("volleyball")) then
            return obj
        end
    end
    if workspace:FindFirstChild("Balls") then
        return workspace.Balls:FindFirstChildOfClass("BasePart")
    end
    return nil
end

-- UI Controls
local HitboxToggle = Tabs.Hitbox:AddToggle("HitboxToggle", { Title = "Enable Ball Hitbox", Default = false })
HitboxToggle:OnChanged(function(Value)
    getgenv().HitboxConfig.Enabled = Value
    if not Value then
        local ball = getBall()
        if ball then
            ball.Size = Vector3.new(2, 2, 2)
            ball.Transparency = 0
        end
    end
end)

Tabs.Hitbox:AddSlider("HitboxSize", {
    Title = "Hitbox Size",
    Default = 15, Min = 5, Max = 30, Rounding = 0,
    Callback = function(Value) getgenv().HitboxConfig.Size = Value end
})

Tabs.Hitbox:AddSlider("HitboxTransparency", {
    Title = "Hitbox Transparency",
    Default = 5, Min = 0, Max = 10, Rounding = 1,
    Callback = function(Value) getgenv().HitboxConfig.Transparency = Value / 10 end
})

local EnemyToggle = Tabs.Visuals:AddToggle("EnemyLookToggle", { Title = "Enemies Look Indicators (60 Studs)", Default = false })
EnemyToggle:OnChanged(function(Value)
    getgenv().VisualConfig.EnemyLookIndicators = Value
    if not Value then
        for _, item in pairs(EnemyIndicators) do
            if item.Part then item.Part:Destroy() end
        end
        EnemyIndicators = {}
    end
end)

Tabs.Settings:AddParagraph({ Title = "Slax Hub Rights", Content = "Developed exclusively by yossef.\nAll Rights Reserved © 2026." })

Fluent:Notify({ Title = "Slax Hub Loaded", Content = "تم تحميل السكربت بنجاح! الحقوق لـ yossef.", Duration = 5 })

-- Main Loop
RunService.RenderStepped:Connect(function()
    -- Hitbox Logic
    if getgenv().HitboxConfig.Enabled then
        local ball = getBall()
        if ball then
            local s = getgenv().HitboxConfig.Size
            ball.Size = Vector3.new(s, s, s)
            ball.Transparency = getgenv().HitboxConfig.Transparency
            ball.CanCollide = false
        end
    end

    -- Enemy Look Indicator Logic
    if getgenv().VisualConfig.EnemyLookIndicators then
        local activePlayers = {}
        local idx = 0

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and (player.Team == nil or player.Team ~= LocalPlayer.Team) then
                idx = idx + 1
                activePlayers[player] = true

                local char = player.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))

                if head then
                    if not EnemyIndicators[player] then
                        local part = Instance.new("Part")
                        part.Size = Vector3.new(1.5, 1.5, 1.5)
                        part.Shape = Enum.PartType.Ball
                        part.Material = Enum.Material.Neon
                        part.Color = ColorList[((idx - 1) % #ColorList) + 1]
                        part.CanCollide = false
                        part.Anchored = true
                        part.Parent = workspace
                        EnemyIndicators[player] = { Part = part }
                    end

                    local p = EnemyIndicators[player].Part
                    p.Transparency = 0.3
                    p.Position = head.CFrame.Position + (head.CFrame.LookVector * getgenv().VisualConfig.Distance)
                end
            end
        end

        for player, data in pairs(EnemyIndicators) do
            if not activePlayers[player] then
                if data.Part then data.Part:Destroy() end
                EnemyIndicators[player] = nil
            end
        end
    end
end)
