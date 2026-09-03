
--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--      VBL - True Touch Hitbox & Precise Ground    --
--==================================================--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().Config = {
    HitboxEnabled = true,
    HitboxSize = 20,
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

-- البحث المتطور عن الكرة الحقيقية المفعّلة
local function getBall()
    if CachedBall and CachedBall.Parent and CachedBall:IsDescendantOf(workspace) then
        return CachedBall
    end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") and not obj:IsDescendantOf(Players) then
            if obj.Transparency < 1 and obj.Size.Magnitude > 0 then
                CachedBall = obj
                return obj
            end
        end
    end
    return nil
end

-- إنشاء مجسم الهيتبوكس التفاعلي المباشر (3D Hitbox Zone)
local RealHitboxZone = Instance.new("Part")
RealHitboxZone.Name = "SlaxHitboxZone"
RealHitboxZone.Shape = Enum.PartType.Ball
RealHitboxZone.Color = Color3.fromRGB(0, 170, 255)
RealHitboxZone.Material = Enum.Material.SmoothPlastic
RealHitboxZone.Transparency = 0.5
RealHitboxZone.CanCollide = false
RealHitboxZone.Anchored = false
RealHitboxZone.Massless = true
RealHitboxZone.Parent = nil

-- Weld لتكبير نطاق تصادم/لمس الكرة الحقيقي
local HitboxWeld = Instance.new("Weld")
HitboxWeld.Parent = RealHitboxZone

-- المترجمات المرئية للأرض
local PlayerCircle = Instance.new("CylinderHandleAdornment")
PlayerCircle.Height = 0.05
PlayerCircle.Color3 = Color3.fromRGB(220, 220, 255)
PlayerCircle.Transparency = 0.6
PlayerCircle.AlwaysOnTop = true
PlayerCircle.Parent = workspace.Terrain

local BallCircle = Instance.new("CylinderHandleAdornment")
BallCircle.Height = 0.05
BallCircle.Color3 = Color3.fromRGB(50, 255, 100)
BallCircle.Transparency = 0.4
BallCircle.AlwaysOnTop = true
BallCircle.Parent = workspace.Terrain

-- واجهة Rayfield
local Window = Rayfield:CreateWindow({
   Name = "SLAX HUB | VBL",
   LoadingTitle = "Slax Hub Loaded",
   LoadingSubtitle = "by yossef",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local MainTab = Window:CreateTab("Main Features", 4483362458)

MainTab:CreateSection("Ball Hitbox (Expansion Zone)")

MainTab:CreateToggle({
   Name = "Expand Ball Hitbox Zone",
   CurrentValue = true,
   Callback = function(Value)
      getgenv().Config.HitboxEnabled = Value
      if not Value then RealHitboxZone.Parent = nil end
   end,
})

MainTab:CreateSlider({
   Name = "Hitbox Size",
   Range = {5, 50},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 20,
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
   Name = "Ball Ground Circle",
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

-- حساب الارتفاع الدقيق لأرضية الملعب الخشبية
local function getExactFloorY(pos)
    local ray = RaycastParams.new()
    ray.FilterType = RaycastFilterType.Include
    
    -- البحث عن الملعب الخشبي الأرضي
    local court = workspace:FindFirstChild("Court") or workspace:FindFirstChild("Map") or workspace
    ray.FilterDescendantsInstances = {court}
    
    local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 10, pos.Z), Vector3.new(0, -50, 0), ray)
    if hit then
        return hit.Position.Y + 0.1
    end
    return 0.2 -- ارتفاع الأرضية الافتراضي في الماب
end

-- التحديث السريع
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local ball = getBall()

    -- 1. الهيتبوكس التفاعلي المربوط بالكرة
    if getgenv().Config.HitboxEnabled and ball then
        local sz = getgenv().Config.HitboxSize
        RealHitboxZone.Size = Vector3.new(sz, sz, sz)
        
        if RealHitboxZone.Parent ~= ball.Parent then
            RealHitboxZone.Parent = ball.Parent
            HitboxWeld.Part0 = ball
            HitboxWeld.Part1 = RealHitboxZone
            HitboxWeld.C0 = CFrame.new()
        end

        -- إرسال لمس تلقائي عند دخول نطاق كرة الهيتبوكس
        if hrp and (hrp.Position - ball.Position).Magnitude <= (sz / 2) + 3 then
            firetouchinterest(hrp, ball, 0)
            firetouchinterest(hrp, ball, 1)
        end
    else
        RealHitboxZone.Parent = nil
    end

    -- 2. دائرة اللاعب الأرضية
    if getgenv().Config.PlayerCircleEnabled and hrp then
        local floorY = getExactFloorY(hrp.Position)
        PlayerCircle.Radius = getgenv().Config.PlayerCircleRadius
        PlayerCircle.InnerRadius = PlayerCircle.Radius - 0.25
        PlayerCircle.Adornee = workspace.Terrain
        PlayerCircle.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    else
        PlayerCircle.Adornee = nil
    end

    -- 3. دائرة الكرة الأرضية
    if getgenv().Config.BallCircleEnabled and ball then
        local floorY = getExactFloorY(ball.Position)
        BallCircle.Radius = getgenv().Config.BallCircleRadius
        BallCircle.InnerRadius = BallCircle.Radius - 0.25
        BallCircle.Adornee = workspace.Terrain
        BallCircle.CFrame = CFrame.new(ball.Position.X, floorY, ball.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    else
        BallCircle.Adornee = nil
    end

    -- 4. خطوط الليزر وتبيتها على أرضية الخشب
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

                    local floorY = getExactFloorY(eHrp.Position)
                    local lookVector = head.CFrame.LookVector
                    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

                    local startPos = Vector3.new(eHrp.Position.X, floorY, eHrp.Position.Z)
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
