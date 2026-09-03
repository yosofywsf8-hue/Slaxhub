--==================================================--
--                    SLAX HUB                      --
--               Created By: yossef                 --
--        VBL - Ground Circle & Line Indicators     --
--==================================================--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().VisualConfig = {
    PlayerCircleEnabled = true,
    PlayerCircleRadius = 15,
    BallCircleEnabled = true,
    BallCircleRadius = 8,
    ConnectLineEnabled = true
}

local CachedBall = nil

-- دالة سريعة ومحسنة للبحث عن الكرة
local function findBall()
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

-- 1. دائرة اللاعب المسطحة على الأرض
local PlayerCircle = Instance.new("CylinderHandleAdornment")
PlayerCircle.Name = "SlaxPlayerCircle"
PlayerCircle.Height = 0.1
PlayerCircle.Color3 = Color3.fromRGB(200, 200, 255)
PlayerCircle.Transparency = 0.7
PlayerCircle.AlwaysOnTop = true
PlayerCircle.CFrame = CFrame.Angles(math.rad(90), 0, 0)
PlayerCircle.Parent = workspace.Terrain

-- 2. دائرة الكرة الخضراء المسطحة على الأرض
local BallCircle = Instance.new("CylinderHandleAdornment")
BallCircle.Name = "SlaxBallCircle"
BallCircle.Height = 0.1
BallCircle.Color3 = Color3.fromRGB(50, 255, 100)
BallCircle.Transparency = 0.5
BallCircle.AlwaysOnTop = true
BallCircle.CFrame = CFrame.Angles(math.rad(90), 0, 0)
BallCircle.Parent = workspace.Terrain

-- 3. خط ليزر واصل بين الكرة واللاعب على الأرض
local Att0 = Instance.new("Attachment", workspace.Terrain)
local Att1 = Instance.new("Attachment", workspace.Terrain)
local ConnectBeam = Instance.new("Beam", workspace.Terrain)
ConnectBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
ConnectBeam.Width0 = 0.3
ConnectBeam.Width1 = 0.3
ConnectBeam.FaceCamera = true
ConnectBeam.Attachment0 = Att0
ConnectBeam.Attachment1 = Att1
ConnectBeam.Enabled = false

-- إنشـاء النافذة بـ Rayfield
local Window = Rayfield:CreateWindow({
   Name = "SLAX HUB | VBL",
   LoadingTitle = "Slax Hub Loaded",
   LoadingSubtitle = "by yossef",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local MainTab = Window:CreateTab("Visual Indicators", 4483362458)

MainTab:CreateSection("Player & Ball Circles")

MainTab:CreateToggle({
   Name = "Player Ground Circle",
   CurrentValue = true,
   Flag = "PlayerCircleToggle",
   Callback = function(Value)
      getgenv().VisualConfig.PlayerCircleEnabled = Value
      PlayerCircle.Visible = Value
   end,
})

MainTab:CreateSlider({
   Name = "Player Circle Radius (Studs)",
   Range = {5, 30},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 15,
   Flag = "PlayerRadiusSlider",
   Callback = function(Value)
      getgenv().VisualConfig.PlayerCircleRadius = Value
   end,
})

MainTab:CreateToggle({
   Name = "Ball Target Ground Circle",
   CurrentValue = true,
   Flag = "BallCircleToggle",
   Callback = function(Value)
      getgenv().VisualConfig.BallCircleEnabled = Value
      BallCircle.Visible = Value
   end,
})

MainTab:CreateSlider({
   Name = "Ball Circle Radius",
   Range = {3, 20},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 8,
   Flag = "BallRadiusSlider",
   Callback = function(Value)
      getgenv().VisualConfig.BallCircleRadius = Value
   end,
})

MainTab:CreateToggle({
   Name = "Line Between Player & Ball",
   CurrentValue = true,
   Flag = "ConnectLineToggle",
   Callback = function(Value)
      getgenv().VisualConfig.ConnectLineEnabled = Value
   end,
})

-- الحلقة البرمجية لتحديث المترجمات المرئية بدون لاق
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if not hrp then
        PlayerCircle.Adornee = nil
        BallCircle.Adornee = nil
        ConnectBeam.Enabled = false
        return
    end

    -- الارتفاع الثابت للأرضية لعدم الارتفاع عند القفز
    local groundY = 3.2

    -- 1. تحديث دائرة اللاعب
    if getgenv().VisualConfig.PlayerCircleEnabled then
        PlayerCircle.Radius = getgenv().VisualConfig.PlayerCircleRadius
        PlayerCircle.InnerRadius = PlayerCircle.Radius - 0.2
        PlayerCircle.Adornee = workspace.Terrain
        PlayerCircle.CFrame = CFrame.new(hrp.Position.X, groundY, hrp.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
    else
        PlayerCircle.Adornee = nil
    end

    -- 2. تحديث دائرة الكرة والخط
    local ball = findBall()
    if ball and getgenv().VisualConfig.BallCircleEnabled then
        BallCircle.Radius = getgenv().VisualConfig.BallCircleRadius
        BallCircle.InnerRadius = BallCircle.Radius - 0.2
        BallCircle.Adornee = workspace.Terrain
        BallCircle.CFrame = CFrame.new(ball.Position.X, groundY, ball.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)

        -- 3. تحديث الخط الرابط بينهما على الأرض
        if getgenv().VisualConfig.ConnectLineEnabled then
            Att0.WorldPosition = Vector3.new(hrp.Position.X, groundY + 0.1, hrp.Position.Z)
            Att1.WorldPosition = Vector3.new(ball.Position.X, groundY + 0.1, ball.Position.Z)
            ConnectBeam.Enabled = true
        else
            ConnectBeam.Enabled = false
        end
    else
        BallCircle.Adornee = nil
        ConnectBeam.Enabled = false
    end
end)
