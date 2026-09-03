--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--      VBL - Fixed Hitbox & Floor Laser Height     --
--==================================================--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().Config = {
    HitboxEnabled = true,
    HitboxSize = 15,
    PlayerCircleEnabled = true,
    PlayerCircleRadius = 12,
    BallCircleEnabled = true,
    BallCircleRadius = 8,
    EnemyLinesEnabled = true,
    LineDistance = 60
}

local CachedBall = nil
local EnemyVisuals = {}
local ColorList = {
    Color3.fromRGB(255, 50, 50),
    Color3.fromRGB(50, 255, 50),
    Color3.fromRGB(50, 150, 255),
    Color3.fromRGB(255, 255, 50),
    Color3.fromRGB(255, 50, 255),
    Color3.fromRGB(255, 150, 0)
}

-- البحث عن الكرة الحقيقية المفعّلة
local function getBall()
    if CachedBall and CachedBall.Parent and CachedBall:IsDescendantOf(workspace) then
        return CachedBall
    end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") then
            CachedBall = obj
            return obj
        end
    end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") and not obj:IsDescendantOf(Players) then
            CachedBall = obj
            return obj
        end
    end
    return nil
end

-- دالة لمعرفة ارتفاع الأرضية تحت أي نقطة بدقة
local function getGroundY(position, ignoreChar)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = RaycastFilterType.Exclude
    if ignoreChar then
        rayParams.FilterDescendantsInstances = {ignoreChar}
    end
    local rayResult = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)
    if rayResult then
        return rayResult.Position.Y + 0.15
    end
    return position.Y - 3
end

-- 1. كرة الهيتبوكس المرئية
local HitboxPart = Instance.new("Part")
HitboxPart.Name = "SlaxRealHitbox"
HitboxPart.Shape = Enum.PartType.Ball
HitboxPart.Color = Color3.fromRGB(0, 170, 255)
HitboxPart.Material = Enum.Material.SmoothPlastic
HitboxPart.Transparency = 0.6
HitboxPart.CanCollide = false
HitboxPart.Anchored = true
HitboxPart.Size = Vector3.new(15, 15, 15)
HitboxPart.Parent = nil

-- 2. دائرة اللاعب الأرضية
local PlayerCircle = Instance.new("CylinderHandleAdornment")
PlayerCircle.Height = 0.05
PlayerCircle.Color3 = Color3.fromRGB(220, 220, 255)
PlayerCircle.Transparency = 0.6
PlayerCircle.AlwaysOnTop = true
PlayerCircle.Parent = workspace.Terrain

-- 3. دائرة الكرة الأرضية
local BallCircle = Instance.new("CylinderHandleAdornment")
BallCircle.Height = 0.05
BallCircle.Color3 = Color3.fromRGB(50, 255, 100)
BallCircle.Transparency = 0.4
BallCircle.AlwaysOnTop = true
BallCircle.Parent = workspace.Terrain

-- واجهة التحكم Rayfield
local Window = Rayfield:CreateWindow({
   Name = "SLAX HUB | VBL",
   LoadingTitle = "Slax Hub Loaded",
   LoadingSubtitle = "by yossef",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local MainTab = Window:CreateTab("Main Features", 4483362458)

MainTab:CreateSection("Ball Hitbox (3D Sphere)")

MainTab:CreateToggle({
   Name = "Ball Hitbox Sphere",
   CurrentValue = true,
   Callback = function(Value)
      getgenv().Config.HitboxEnabled = Value
      if not Value then HitboxPart.Parent = nil end
   end,
})

MainTab:CreateSlider({
   Name = "Hitbox Size (Radius)",
   Range = {5, 50},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 15,
   Callback = function(Value)
      getgenv().Config.HitboxSize = Value
   end,
})

MainTab:CreateSection("Ground Visuals")

MainTab:CreateToggle({
   Name = "Player Ground Circle",
   CurrentValue = true,
   Callback = function(Value)
      getgenv().Config.PlayerCircleEnabled = Value
   end,
})

MainTab:CreateToggle({
   Name = "Ball Ground Circle (Green)",
   CurrentValue = true,
   Callback = function(Value)
      getgenv().Config.BallCircleEnabled = Value
   end,
})

MainTab:CreateToggle({
   Name = "Enemy Look Laser Lines",
   CurrentValue = true,
   Callback = function(Value)
      getgenv().Config.EnemyLinesEnabled = Value
      if not Value then
         for _, v in pairs(EnemyVisuals) do
            if v.Beam then v.Beam:Destroy() end
            if v.A0 then v.A0:Destroy() end
            if v.A1 then v.A1:Destroy() end
         end
         EnemyVisuals = {}
      end
   end,
})

-- الحلقة الرئيسية للتحديث المباشر
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local ball = getBall()

    -- 1. تحديث الهيتبوكس وتفعيل لمس الكرة لمسافات بعيدة
    if getgenv().Config.HitboxEnabled and ball then
        local sz = getgenv().Config.HitboxSize
        HitboxPart.Size = Vector3.new(sz, sz, sz)
        HitboxPart.CFrame = ball.CFrame
        HitboxPart.Parent = workspace

        if hrp then
            local dist = (hrp.Position - ball.Position).Magnitude
            if dist <= (sz / 2) + 4 then
                if firetouchinterest then
                    firetouchinterest(hrp, ball, 0)
                    firetouchinterest(hrp, ball, 1)
                end
            end
        end
    else
        HitboxPart.Parent = nil
    end

    -- 2. تحديث دائرة اللاعب وموقعها الملاصق للأرض
    if getgenv().Config.PlayerCircleEnabled and hrp then
        local playerGroundY = getGroundY(hrp.Position, char)
        PlayerCircle.Radius = getgenv().Config.PlayerCircleRadius
        PlayerCircle.InnerRadius = PlayerCircle.Radius - 0.25
        PlayerCircle.Adornee = workspace.Terrain
        PlayerCircle.CFrame = CFrame.new(hrp.Position.X, playerGroundY, hrp.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    else
        PlayerCircle.Adornee = nil
    end

    -- 3. تحديث دائرة الكرة وموقعها الملاصق للأرض
    if getgenv().Config.BallCircleEnabled and ball then
        local ballGroundY = getGroundY(ball.Position, nil)
        BallCircle.Radius = getgenv().Config.BallCircleRadius
        BallCircle.InnerRadius = BallCircle.Radius - 0.25
        BallCircle.Adornee = workspace.Terrain
        BallCircle.CFrame = CFrame.new(ball.Position.X, ballGroundY, ball.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    else
        BallCircle.Adornee = nil
    end

    -- 4. تحديث خطوط الليزر وتنزيلها لأسفل الأرضية
    if getgenv().Config.EnemyLinesEnabled then
        local active = {}
        local idx = 0
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (p.Team == nil or p.Team ~= LocalPlayer.Team) then
                idx = idx + 1
                active[p] = true
                local eChar = p.Character
                local head = eChar and eChar:FindFirstChild("Head")
                local eHrp = eChar and eChar:FindFirstChild("HumanoidRootPart")

                if head and eHrp then
                    if not EnemyVisuals[p] then
                        local a0 = Instance.new("Attachment", workspace.Terrain)
                        local a1 = Instance.new("Attachment", workspace.Terrain)
                        local beam = Instance.new("Beam", workspace.Terrain)
                        beam.Color = ColorSequence.new(ColorList[((idx-1)%#ColorList)+1])
                        beam.Width0 = 0.4
                        beam.Width1 = 0.4
                        beam.FaceCamera = true
                        beam.Attachment0 = a0
                        beam.Attachment1 = a1
                        EnemyVisuals[p] = {Beam = beam, A0 = a0, A1 = a1}
                    end

                    local enemyGroundY = getGroundY(eHrp.Position, eChar)
                    local lookVector = head.CFrame.LookVector
                    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

                    local startPos = Vector3.new(eHrp.Position.X, enemyGroundY, eHrp.Position.Z)
                    local endPos = startPos + (flatLook * getgenv().Config.LineDistance)

                    EnemyVisuals[p].A0.WorldPosition = startPos
                    EnemyVisuals[p].A1.WorldPosition = endPos
                    EnemyVisuals[p].Beam.Enabled = true
                end
            end
        end

        for p, data in pairs(EnemyVisuals) do
            if not active[p] then
                if data.Beam then data.Beam:Destroy() end
                if data.A0 then data.A0:Destroy() end
                if data.A1 then data.A1:Destroy() end
                EnemyVisuals[p] = nil
            end
        end
    end
end)
