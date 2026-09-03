--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--       VBL - Ball Hitbox & Enemy Look Indicators  --
--==================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration
getgenv().HitboxConfig = {
    Enabled = false,
    Size = 15,
    Transparency = 0.5
}

getgenv().VisualConfig = {
    EnemyLookIndicators = false,
    Distance = 60
}

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

-- البحث عن الكرة
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

-- بناء واجهة GUI خفيفة ومستقرة
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local SubTitle = Instance.new("TextLabel")
local ToggleHitbox = Instance.new("TextButton")
local ToggleEnemy = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

MainFrame.Name = "SlaxHubUI"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.Size = UDim2.new(0, 280, 0, 230)
MainFrame.Active = true
MainFrame.Draggable = true

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "SLAX HUB"
Title.Font = Enum.Font.SourceSansBold
Title.TextColor3 = Color3.fromRGB(0, 170, 255)
Title.TextSize = 20.000

SubTitle.Parent = MainFrame
SubTitle.Position = UDim2.new(0, 0, 0.85, 0)
SubTitle.Size = UDim2.new(1, 0, 0, 25)
SubTitle.Text = "by yossef | All Rights Reserved"
SubTitle.Font = Enum.Font.SourceSansItalic
SubTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
SubTitle.TextSize = 13.000

-- زر الهيتبوكس
ToggleHitbox.Parent = MainFrame
ToggleHitbox.Position = UDim2.new(0.08, 0, 0.22, 0)
ToggleHitbox.Size = UDim2.new(0.84, 0, 0.22, 0)
ToggleHitbox.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleHitbox.Text = "Ball Hitbox (15): OFF"
ToggleHitbox.Font = Enum.Font.SourceSansBold
ToggleHitbox.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleHitbox.TextSize = 15.000

ToggleHitbox.MouseButton1Click:Connect(function()
    getgenv().HitboxConfig.Enabled = not getgenv().HitboxConfig.Enabled
    if getgenv().HitboxConfig.Enabled then
        ToggleHitbox.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleHitbox.Text = "Ball Hitbox (15): ON"
    else
        ToggleHitbox.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleHitbox.Text = "Ball Hitbox (15): OFF"
        local ball = getBall()
        if ball then
            ball.Size = Vector3.new(2, 2, 2)
            ball.Transparency = 0
        end
    end
end)

-- زر مؤشر الأعداء
ToggleEnemy.Parent = MainFrame
ToggleEnemy.Position = UDim2.new(0.08, 0, 0.52, 0)
ToggleEnemy.Size = UDim2.new(0.84, 0, 0.22, 0)
ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleEnemy.Text = "Enemy Look (60 Studs): OFF"
ToggleEnemy.Font = Enum.Font.SourceSansBold
ToggleEnemy.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleEnemy.TextSize = 14.000

ToggleEnemy.MouseButton1Click:Connect(function()
    getgenv().VisualConfig.EnemyLookIndicators = not getgenv().VisualConfig.EnemyLookIndicators
    if getgenv().VisualConfig.EnemyLookIndicators then
        ToggleEnemy.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleEnemy.Text = "Enemy Look (60 Studs): ON"
    else
        ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleEnemy.Text = "Enemy Look (60 Studs): OFF"
        for _, item in pairs(EnemyIndicators) do
            if item.Part then item.Part:Destroy() end
        end
        EnemyIndicators = {}
    end
end)

-- Main Render Loop
RunService.RenderStepped:Connect(function()
    -- 1. Ball Hitbox
    if getgenv().HitboxConfig.Enabled then
        local ball = getBall()
        if ball then
            local size = getgenv().HitboxConfig.Size
            ball.Size = Vector3.new(size, size, size)
            ball.Transparency = getgenv().HitboxConfig.Transparency
            ball.CanCollide = false
        end
    end

    -- 2. Enemy Look Indicators
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
