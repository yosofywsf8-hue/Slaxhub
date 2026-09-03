--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--       VBL - Ball Hitbox & Fixed Enemy Lasers     --
--==================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().HitboxConfig = {
    Enabled = false,
    Size = 15,
    Transparency = 0.5
}

getgenv().VisualConfig = {
    EnemyLookIndicators = false,
    Distance = 60
}

local EnemyVisuals = {}
local ColorList = {
    Color3.fromRGB(255, 50, 50),   -- أحمر
    Color3.fromRGB(50, 255, 50),   -- أخضر
    Color3.fromRGB(50, 150, 255),  -- أزرق
    Color3.fromRGB(255, 255, 50),  -- أصفر
    Color3.fromRGB(255, 50, 255),  -- وردي
    Color3.fromRGB(255, 150, 0),   -- برتقالي
    Color3.fromRGB(0, 255, 255)    -- تركوازي
}

-- دالة البحث عن كائن الكرة
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

-- إنشاء دائرة الهيتبوكس المرئية حول الكرة
local BallSelection = Instance.new("SelectionBox")
BallSelection.Name = "SlaxBallHitboxVisual"
BallSelection.LineThickness = 0.15
BallSelection.Color3 = Color3.fromRGB(0, 170, 255)
BallSelection.Transparency = 0.2
BallSelection.Parent = workspace

-- بناء واجهة GUI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local SubTitle = Instance.new("TextLabel")
local ToggleHitbox = Instance.new("TextButton")
local SizePlus = Instance.new("TextButton")
local SizeMinus = Instance.new("TextButton")
local ToggleEnemy = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

MainFrame.Name = "SlaxHubUI"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.Size = UDim2.new(0, 290, 0, 260)
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
SubTitle.Position = UDim2.new(0, 0, 0.88, 0)
SubTitle.Size = UDim2.new(1, 0, 0, 25)
SubTitle.Text = "by yossef | All Rights Reserved"
SubTitle.Font = Enum.Font.SourceSansItalic
SubTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
SubTitle.TextSize = 13.000

-- زر تفعيل الهيتبوكس
ToggleHitbox.Parent = MainFrame
ToggleHitbox.Position = UDim2.new(0.06, 0, 0.18, 0)
ToggleHitbox.Size = UDim2.new(0.88, 0, 0.18, 0)
ToggleHitbox.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleHitbox.Text = "Ball Hitbox (15): OFF"
ToggleHitbox.Font = Enum.Font.SourceSansBold
ToggleHitbox.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleHitbox.TextSize = 15.000

-- أزرار التحكم بحجم الهيتبوكس (من 5 إلى 30)
SizeMinus.Parent = MainFrame
SizeMinus.Position = UDim2.new(0.06, 0, 0.38, 0)
SizeMinus.Size = UDim2.new(0.42, 0, 0.14, 0)
SizeMinus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SizeMinus.Text = "Size - 1"
SizeMinus.Font = Enum.Font.SourceSansBold
SizeMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
SizeMinus.TextSize = 14.000

SizePlus.Parent = MainFrame
SizePlus.Position = UDim2.new(0.52, 0, 0.38, 0)
SizePlus.Size = UDim2.new(0.42, 0, 0.14, 0)
SizePlus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SizePlus.Text = "Size + 1"
SizePlus.Font = Enum.Font.SourceSansBold
SizePlus.TextColor3 = Color3.fromRGB(255, 255, 255)
SizePlus.TextSize = 14.000

ToggleHitbox.MouseButton1Click:Connect(function()
    getgenv().HitboxConfig.Enabled = not getgenv().HitboxConfig.Enabled
    if getgenv().HitboxConfig.Enabled then
        ToggleHitbox.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): ON"
    else
        ToggleHitbox.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): OFF"
        BallSelection.Adornee = nil
        local ball = getBall()
        if ball then
            ball.Size = Vector3.new(2, 2, 2)
            ball.Transparency = 0
        end
    end
end)

SizeMinus.MouseButton1Click:Connect(function()
    if getgenv().HitboxConfig.Size > 5 then
        getgenv().HitboxConfig.Size = getgenv().HitboxConfig.Size - 1
        if getgenv().HitboxConfig.Enabled then
            ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): ON"
        else
            ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): OFF"
        end
    end
end)

SizePlus.MouseButton1Click:Connect(function()
    if getgenv().HitboxConfig.Size < 30 then
        getgenv().HitboxConfig.Size = getgenv().HitboxConfig.Size + 1
        if getgenv().HitboxConfig.Enabled then
            ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): ON"
        else
            ToggleHitbox.Text = "Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): OFF"
        end
    end
end)

-- زر تفعيل خطوط نظر الأعداء
ToggleEnemy.Parent = MainFrame
ToggleEnemy.Position = UDim2.new(0.06, 0, 0.56, 0)
ToggleEnemy.Size = UDim2.new(0.88, 0, 0.18, 0)
ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleEnemy.Text = "Enemy Look Lines (60 Studs): OFF"
ToggleEnemy.Font = Enum.Font.SourceSansBold
ToggleEnemy.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleEnemy.TextSize = 13.000

local function cleanupEnemyVisuals()
    for _, item in pairs(EnemyVisuals) do
        if item.Beam then item.Beam:Destroy() end
        if item.Attachment0 then item.Attachment0:Destroy() end
        if item.Attachment1 then item.Attachment1:Destroy() end
    end
    EnemyVisuals = {}
end

ToggleEnemy.MouseButton1Click:Connect(function()
    getgenv().VisualConfig.EnemyLookIndicators = not getgenv().VisualConfig.EnemyLookIndicators
    if getgenv().VisualConfig.EnemyLookIndicators then
        ToggleEnemy.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        ToggleEnemy.Text = "Enemy Look Lines (60 Studs): ON"
    else
        ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleEnemy.Text = "Enemy Look Lines (60 Studs): OFF"
        cleanupEnemyVisuals()
    end
end)

-- Main Render Loop
RunService.RenderStepped:Connect(function()
    -- 1. Ball Hitbox Logic
    if getgenv().HitboxConfig.Enabled then
        local ball = getBall()
        if ball then
            local size = getgenv().HitboxConfig.Size
            ball.Size = Vector3.new(size, size, size)
            ball.Transparency = getgenv().HitboxConfig.Transparency
            ball.CanCollide = false
            BallSelection.Adornee = ball
        else
            BallSelection.Adornee = nil
        end
    else
        BallSelection.Adornee = nil
    end

    -- 2. Fixed Ground-Level Laser Lines Logic
    if getgenv().VisualConfig.EnemyLookIndicators then
        local activePlayers = {}
        local idx = 0

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and (player.Team == nil or player.Team ~= LocalPlayer.Team) then
                idx = idx + 1
                activePlayers[player] = true

                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")

                if head and hrp then
                    if not EnemyVisuals[player] then
                        local att0 = Instance.new("Attachment")
                        local att1 = Instance.new("Attachment")
                        local beam = Instance.new("Beam")

                        att0.Parent = workspace.Terrain
                        att1.Parent = workspace.Terrain

                        local color = ColorList[((idx - 1) % #ColorList) + 1]
                        beam.Color = ColorSequence.new(color)
                        beam.Width0 = 0.4
                        beam.Width1 = 0.4
                        beam.FaceCamera = true
                        beam.Attachment0 = att0
                        beam.Attachment1 = att1
                        beam.Parent = workspace.Terrain

                        EnemyVisuals[player] = {
                            Beam = beam,
                            Attachment0 = att0,
                            Attachment1 = att1
                        }
                    end

                    -- تثبيت الارتفاع عند مستوى الأرض الطبيعي حتى لو نط اللاعب
                    local fixedY = 3.5 -- الارتفاع المظبوط لمستوى جسم/رأس اللاعب وهو واقف
                    local ray = Ray.new(hrp.Position, Vector3.new(0, -20, 0))
                    local hit, hitPos = workspace:FindPartOnWithIgnoreList(ray, {char})
                    if hit then
                        fixedY = hitPos.Y + 3
                    else
                        fixedY = hrp.Position.Y < 15 and hrp.Position.Y or 3.5
                    end

                    local lookVector = head.CFrame.LookVector
                    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

                    local startPos = Vector3.new(hrp.Position.X, fixedY, hrp.Position.Z)
                    local endPos = startPos + (flatLook * getgenv().VisualConfig.Distance)

                    EnemyVisuals[player].Attachment0.WorldPosition = startPos
                    EnemyVisuals[player].Attachment1.WorldPosition = endPos
                    EnemyVisuals[player].Beam.Enabled = true
                end
            end
        end

        for player, data in pairs(EnemyVisuals) do
            if not activePlayers[player] then
                if data.Beam then data.Beam:Destroy() end
                if data.Attachment0 then data.Attachment0:Destroy() end
                if data.Attachment1 then data.Attachment1:Destroy() end
                EnemyVisuals[player] = nil
            end
        end
    end
end)
