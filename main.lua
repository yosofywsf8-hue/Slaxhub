--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--      VBL - Fixed 3D Ball Hitbox & Ground Lasers  --
--==================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().HitboxConfig = {
    Enabled = false,
    Size = 15
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

-- البحث الشامل عن جميع الكرات في الماب
local function getAllBalls()
    local balls = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("ball") or name:find("volleyball") or obj.Parent.Name:lower():find("ball") then
                table.insert(balls, obj)
            end
        end
    end
    return balls
end

-- إنشاء مجسم مرئي للهيتبوكس (طول + عرض + ارتفاع)
local HitboxPart = Instance.new("Part")
HitboxPart.Name = "SlaxHitboxVisualPart"
HitboxPart.Shape = Enum.PartType.Ball
HitboxPart.Color = Color3.fromRGB(0, 170, 255)
HitboxPart.Material = Enum.Material.Forcefield
HitboxPart.Transparency = 0.6
HitboxPart.CanCollide = false
HitboxPart.Anchored = true
HitboxPart.Size = Vector3.new(15, 15, 15)
HitboxPart.Parent = nil

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
ToggleHitbox.Text = "3D Ball Hitbox (15): OFF"
ToggleHitbox.Font = Enum.Font.SourceSansBold
ToggleHitbox.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleHitbox.TextSize = 15.000

-- أزرار تكبير وتصغير الهيتبوكس
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
        ToggleHitbox.Text = "3D Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): ON"
        HitboxPart.Parent = workspace
    else
        ToggleHitbox.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleHitbox.Text = "3D Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): OFF"
        HitboxPart.Parent = nil
    end
end)

SizeMinus.MouseButton1Click:Connect(function()
    if getgenv().HitboxConfig.Size > 5 then
        getgenv().HitboxConfig.Size = getgenv().HitboxConfig.Size - 1
        local currentText = getgenv().HitboxConfig.Enabled and "ON" or "OFF"
        ToggleHitbox.Text = "3D Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): " .. currentText
    end
end)

SizePlus.MouseButton1Click:Connect(function()
    if getgenv().HitboxConfig.Size < 40 then
        getgenv().HitboxConfig.Size = getgenv().HitboxConfig.Size + 1
        local currentText = getgenv().HitboxConfig.Enabled and "ON" or "OFF"
        ToggleHitbox.Text = "3D Ball Hitbox (" .. tostring(getgenv().HitboxConfig.Size) .. "): " .. currentText
    end
end)

-- زر خطوط نظر الأعداء
ToggleEnemy.Parent = MainFrame
ToggleEnemy.Position = UDim2.new(0.06, 0, 0.56, 0)
ToggleEnemy.Size = UDim2.new(0.88, 0, 0.18, 0)
ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleEnemy.Text = "Enemy Look Lines (Fixed Height): OFF"
ToggleEnemy.Font = Enum.Font.SourceSansBold
ToggleEnemy.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleEnemy.TextSize = 12.000

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
        ToggleEnemy.Text = "Enemy Look Lines (Fixed Height): ON"
    else
        ToggleEnemy.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleEnemy.Text = "Enemy Look Lines (Fixed Height): OFF"
        cleanupEnemyVisuals()
    end
end)

-- Main Loop
RunService.RenderStepped:Connect(function()
    -- 1. Hitbox Logic (ثلاثي الأبعاد: طول، عرض، ارتفاع)
    if getgenv().HitboxConfig.Enabled then
        local balls = getAllBalls()
        if #balls > 0 then
            local mainBall = balls[1]
            local s = getgenv().HitboxConfig.Size
            
            -- تكبير الكرة الحقيقية + إظهار الدائرة الحجمية حولها
            mainBall.Size = Vector3.new(s, s, s)
            mainBall.CanCollide = false
            
            HitboxPart.Size = Vector3.new(s, s, s)
            HitboxPart.CFrame = mainBall.CFrame
            HitboxPart.Parent = workspace
        else
            HitboxPart.Parent = nil
        end
    else
        HitboxPart.Parent = nil
    end

    -- 2. Enemy Ground Laser Lines Logic (مُثبتة تماماً على الأرض)
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
                        beam.Width0 = 0.5
                        beam.Width1 = 0.5
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

                    -- تثبيت ارتفاع خط الليزر أرضياً نهائياً عند مستوى 3.5 لمنع ارتفاعه مع قفز اللاعب
                    local groundY = 3.5 
                    local lookVector = head.CFrame.LookVector
                    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

                    local startPos = Vector3.new(hrp.Position.X, groundY, hrp.Position.Z)
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
