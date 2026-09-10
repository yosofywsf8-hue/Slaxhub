local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "SlaxHub // The Last Front Pro",
    LoadingTitle = "Initializing SlaxHub...",
    LoadingSubtitle = "Delta Mobile Edition",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SlaxHub",
        FileName = "TLF_Config"
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Combat", 4483362458)
local ESPTab = Window:CreateTab("Visuals (ESP)", 4483362458)

local Settings = {
    SilentAim = false,
    FOV = 180,
    TargetBone = "Head",
    
    ESP_Enabled = false,
    TeamCheck = true,
    NameESP = false,
    Tracers = false,
    Skeleton = false
}

-- عناصر قسم القتال
MainTab:CreateToggle({
    Name = "Silent Aim (Raycast Hook)",
    CurrentValue = false,
    Flag = "Silent_Toggle",
    Callback = function(Value)
        Settings.SilentAim = Value
    end,
})

MainTab:CreateDropdown({
    Name = "Target Bone",
    Options = {"Head", "HumanoidRootPart", "Left Leg", "Right Leg"},
    CurrentOption = "Head",
    Flag = "Bone_Dropdown",
    Callback = function(Option)
        if Option == "Head" then
            Settings.TargetBone = "Head"
        elseif Option == "HumanoidRootPart" then
            Settings.TargetBone = "HumanoidRootPart"
        elseif Option == "Left Leg" then
            Settings.TargetBone = "LeftLowerLeg"
        elseif Option == "Right Leg" then
            Settings.TargetBone = "RightLowerLeg"
        end
    end,
})

MainTab:CreateSlider({
    Name = "FOV Range",
    Range = {50, 400},
    Increment = 10,
    CurrentValue = 180,
    Flag = "FOV_Slider",
    Callback = function(Value)
        Settings.FOV = Value
    end,
})

-- عناصر قسم الـ ESP
ESPTab:CreateToggle({
    Name = "Enable ESP Hub",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        Settings.ESP_Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Team Check (Hide Teammates)",
    CurrentValue = true,
    Flag = "TeamCheck_Toggle",
    Callback = function(Value)
        Settings.TeamCheck = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Name ESP",
    CurrentValue = false,
    Flag = "Name_Toggle",
    Callback = function(Value)
        Settings.NameESP = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Tracers (Lines)",
    CurrentValue = false,
    Flag = "Tracer_Toggle",
    Callback = function(Value)
        Settings.Tracers = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = false,
    Flag = "Skeleton_Toggle",
    Callback = function(Value)
        Settings.Skeleton = Value
    end,
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local function isEnemy(player)
    if player == LocalPlayer then return false end
    if Settings.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    return true
end

local function getClosestTarget()
    local target = nil
    local shortestDist = Settings.FOV
    
    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local char = player.Character
            if char and char:FindFirstChild(Settings.TargetBone) and char:FindFirstChild("Humanoid") then
                if char.Humanoid.Health > 0 then
                    local part = char[Settings.TargetBone]
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(part.Position)
                    
                    if onScreen then
                        local mousePos = UserInputService:GetMouseLocation()
                        local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            target = part
                        end
                    end
                end
            end
        end
    end
    return target
end

-- رسومات التتبع الخطية (Drawing Library لـ Tracers و Skeleton)
local tracersList = {}
local skeletonList = {}

local function createVisuals(player)
    if player == LocalPlayer then return end

    -- Tracer Line
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1.5
    tracer.Color = Color3.fromRGB(255, 50, 50)
    tracersList[player] = tracer

    -- Skeleton Lines (Head to Torso, Torso to Arms/Legs)
    local limbs = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"}
    }
    
    local skelLines = {}
    for _, pair in ipairs(limbs) do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = 1.2
        line.Color = Color3.fromRGB(255, 255, 255)
        table.insert(skelLines, {line, pair[1], pair[2]})
    end
    skeletonList[player] = skelLines
end

Players.PlayerAdded:Connect(createVisuals)
for _, p in ipairs(Players:GetPlayers()) do
    createVisuals(p)
end

Players.PlayerRemoving:Connect(function(player)
    if tracersList[player] then
        tracersList[player]:Remove()
        tracersList[player] = nil
    end
    if skeletonList[player] then
        for _, data in ipairs(skeletonList[player]) do
            data[1]:Remove()
        end
        skeletonList[player] = nil
    end
end)

-- تحديث الـ ESP في كل إطار
RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local tracer = tracersList[player]
            local skel = skeletonList[player]
            
            -- التحقق من الفريق والوجود
            local canShow = Settings.ESP_Enabled and isEnemy(player) and char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
            
            -- تحديث التتبعات (Tracers)
            if tracer then
                if canShow and Settings.Tracers and char:FindFirstChild("HumanoidRootPart") then
                    local rootPart = char.HumanoidRootPart
                    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        tracer.Color = (player.Team and player.Team == LocalPlayer.Team) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 50, 50)
                        tracer.Visible = true
                    else
                        tracer.Visible = false
                    end
                else
                    tracer.Visible = false
                end
            end
            
            -- تحديث الهيكل العظمي (Skeleton)
            if skel then
                if canShow and Settings.Skeleton then
                    for _, data in ipairs(skel) do
                        local line, p1Name, p2Name = data[1], data[2], data[3]
                        local part1, part2 = char:FindFirstChild(p1Name), char:FindFirstChild(p2Name)
                        if part1 and part2 then
                            local pos1, on1 = Camera:WorldToViewportPoint(part1.Position)
                            local pos2, on2 = Camera:WorldToViewportPoint(part2.Position)
                            if on1 or on2 then
                                line.From = Vector2.new(pos1.X, pos1.Y)
                                line.To = Vector2.new(pos2.X, pos2.Y)
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                else
                    for _, data in ipairs(skel) do
                        data[1].Visible = false
                    end
                end
            end
            
            -- تحديث الاسم (Name Tag)
            pcall(function()
                local head = char and char:FindFirstChild("Head")
                if head then
                    local tag = head:FindFirstChild("TLF_NameTag")
                    if canShow and Settings.NameESP then
                        if not tag then
                            local bill = Instance.new("BillboardGui", head)
                            bill.Name = "TLF_NameTag"
                            bill.Size = UDim2.new(0, 100, 0, 40)
                            bill.AlwaysOnTop = true
                            bill.StudsOffset = Vector3.new(0, 2.5, 0)
                            
                            local txt = Instance.new("TextLabel", bill)
                            txt.Name = "Label"
                            txt.Size = UDim2.new(1, 0, 1, 0)
                            txt.BackgroundTransparency = 1
                            txt.TextScaled = true
                            txt.Font = Enum.Font.Code
                            txt.TextColor3 = Color3.fromRGB(255, 50, 50)
                        else
                            tag.Enabled = true
                            tag.Label.Text = player.Name
                        end
                    else
                        if tag then tag.Enabled = false end
                    end
                end
            end)
        end
    end
end)

-- اعتراض الـ Raycast لتطبيق الـ Silent Aim
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if Settings.SilentAim and not checkcaller() then
        if method == "FindPartOnRay" or method == "Raycast" then
            local targetPart = getClosestTarget()
            if targetPart then
                if method == "FindPartOnRay" then
                    local ray = args[1]
                    if ray then
                        local origin = ray.Origin
                        local newDirection = (targetPart.Position - origin).Unit * ray.Direction.Magnitude
                        args[1] = Ray.new(origin, newDirection)
                    end
                elseif method == "Raycast" then
                    local origin = args[1]
                    local direction = args[2]
                    if origin and direction then
                        args[2] = (targetPart.Position - origin).Unit * direction.Magnitude
                    end
                end
                return oldNamecall(self, unpack(args))
            end
        end
    end
    
    return oldNamecall(self, ...)
end)
