--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--        VBL - Rayfield UI Edition                 --
--==================================================--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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
    Color3.fromRGB(255, 50, 50),
    Color3.fromRGB(50, 255, 50),
    Color3.fromRGB(50, 150, 255),
    Color3.fromRGB(255, 255, 50),
    Color3.fromRGB(255, 50, 255),
    Color3.fromRGB(255, 150, 0),
    Color3.fromRGB(0, 255, 255)
}

-- البحث عن الكرة الحقيقية المفعّلة بالماب
local function getActiveBall()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local pName = obj.Parent.Name:lower()
            local oName = obj.Name:lower()
            if (oName:find("ball") or pName:find("ball")) and not obj:IsDescendantOf(Players) then
                if obj.Size.Magnitude > 0 and obj.Transparency < 1 then
                    return obj
                end
            end
        end
    end
    return nil
end

-- إنشاء مجسم الهيتبوكس المرئي
local HitboxPart = Instance.new("Part")
HitboxPart.Name = "SlaxHitboxVisualPart"
HitboxPart.Shape = Enum.PartType.Ball
HitboxPart.Color = Color3.fromRGB(0, 170, 255)
HitboxPart.Material = Enum.Material.SmoothPlastic
HitboxPart.Transparency = 0.5
HitboxPart.CanCollide = false
HitboxPart.Anchored = true
HitboxPart.Size = Vector3.new(15, 15, 15)
HitboxPart.Parent = nil

-- إنشـاء النافذة الرئيسية عبر Rayfield
local Window = Rayfield:CreateWindow({
   Name = "SLAX HUB | VBL",
   LoadingTitle = "Slax Hub Loading...",
   LoadingSubtitle = "by yossef",
   ConfigurationSaving = {
      Enabled = false
   },
   KeySystem = false
})

local MainTab = Window:CreateTab("Main Features", 4483362458)

-- خيارات الهيتبوكس
MainTab:CreateSection("Ball Hitbox Settings")

MainTab:CreateToggle({
   Name = "3D Ball Hitbox",
   CurrentValue = false,
   Flag = "BallHitboxToggle",
   Callback = function(Value)
      getgenv().HitboxConfig.Enabled = Value
      if not Value then
         HitboxPart.Parent = nil
      end
   end,
})

MainTab:CreateSlider({
   Name = "Hitbox Size (Width/Height/Length)",
   Range = {5, 40},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 15,
   Flag = "HitboxSizeSlider",
   Callback = function(Value)
      getgenv().HitboxConfig.Size = Value
   end,
})

-- خيارات خطوط النظر
MainTab:CreateSection("Enemy Look Lines")

local function cleanupEnemyVisuals()
    for _, item in pairs(EnemyVisuals) do
        if item.Beam then item.Beam:Destroy() end
        if item.Attachment0 then item.Attachment0:Destroy() end
        if item.Attachment1 then item.Attachment1:Destroy() end
    end
    EnemyVisuals = {}
end

MainTab:CreateToggle({
   Name = "Enemy Look Lines (Ground Locked)",
   CurrentValue = false,
   Flag = "EnemyLinesToggle",
   Callback = function(Value)
      getgenv().VisualConfig.EnemyLookIndicators = Value
      if not Value then
         cleanupEnemyVisuals()
      end
   end,
})

MainTab:CreateSlider({
   Name = "Line Distance",
   Range = {20, 120},
   Increment = 5,
   Suffix = "Studs",
   CurrentValue = 60,
   Flag = "LineDistanceSlider",
   Callback = function(Value)
      getgenv().VisualConfig.Distance = Value
   end,
})

-- الحلقة البرمجية المستمرة (RenderStepped)
RunService.RenderStepped:Connect(function()
    -- 1. تحديث الهيتبوكس
    if getgenv().HitboxConfig.Enabled then
        local ball = getActiveBall()
        if ball then
            local sz = getgenv().HitboxConfig.Size
            ball.Size = Vector3.new(sz, sz, sz)
            ball.CanCollide = false
            
            HitboxPart.Size = Vector3.new(sz, sz, sz)
            HitboxPart.CFrame = ball.CFrame
            HitboxPart.Parent = workspace
        else
            HitboxPart.Parent = nil
        end
    else
        HitboxPart.Parent = nil
    end

    -- 2. تحديث خطوط الليزر المثبتة على الأرض
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
                        local att0 = Instance.new("Attachment", workspace.Terrain)
                        local att1 = Instance.new("Attachment", workspace.Terrain)
                        local beam = Instance.new("Beam", workspace.Terrain)

                        local color = ColorList[((idx - 1) % #ColorList) + 1]
                        beam.Color = ColorSequence.new(color)
                        beam.Width0 = 0.6
                        beam.Width1 = 0.6
                        beam.FaceCamera = true
                        beam.Attachment0 = att0
                        beam.Attachment1 = att1

                        EnemyVisuals[player] = {
                            Beam = beam,
                            Attachment0 = att0,
                            Attachment1 = att1
                        }
                    end

                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = RaycastFilterType.Exclude
                    rayParams.FilterDescendantsInstances = {char}
                    
                    local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -100, 0), rayParams)
                    local groundY = rayResult and (rayResult.Position.Y + 0.5) or (hrp.Position.Y - 3)

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
