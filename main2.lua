local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "SlaxHub // Optimized Mobile",
    LoadingTitle = "Loading Lightweight Engine...",
    LoadingSubtitle = "Delta Edition",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SlaxHub",
        FileName = "TLF_Opt_Config"
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Combat", 4483362458)
local ESPTab = Window:CreateTab("Visuals", 4483362458)

local Settings = {
    SilentAim = false,
    FOV = 150,
    TargetBone = "Head",
    ESP_Enabled = false,
    TeamCheck = true,
    NameESP = false
}

MainTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Flag = "Silent_Toggle",
    Callback = function(Value)
        Settings.SilentAim = Value
    end,
})

MainTab:CreateDropdown({
    Name = "Target Bone",
    Options = {"Head", "HumanoidRootPart"},
    CurrentOption = "Head",
    Flag = "Bone_Dropdown",
    Callback = function(Option)
        Settings.TargetBone = Option
    end,
})

MainTab:CreateSlider({
    Name = "FOV Range",
    Range = {50, 250},
    Increment = 10,
    CurrentValue = 150,
    Flag = "FOV_Slider",
    Callback = function(Value)
        Settings.FOV = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        Settings.ESP_Enabled = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Flag = "TeamCheck_Toggle",
    Callback = function(Value)
        Settings.TeamCheck = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Name Tags",
    CurrentValue = false,
    Flag = "Name_Toggle",
    Callback = function(Value)
        Settings.NameESP = Value
    end,
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- التحقق من الفريق بطريقة خفيفة
local function isEnemy(player)
    if player == LocalPlayer then return false end
    if Settings.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    return true
end

-- استهداف أقرب عدو للـ Silent Aim
local function getClosestTarget()
    local target = nil
    local shortestDist = Settings.FOV
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local char = player.Character
            if char and char:FindFirstChild(Settings.TargetBone) and char:FindFirstChild("Humanoid") then
                if char.Humanoid.Health > 0 then
                    local part = char[Settings.TargetBone]
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(part.Position)
                    
                    if onScreen then
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

-- إدارة أسمائهم بذكاء دون تكرار مزعج يسبب لاج
local activeTags = {}

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local shouldShow = Settings.ESP_Enabled and Settings.NameESP and isEnemy(player) and char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
            
            if shouldShow and head then
                local tag = activeTags[player]
                if not tag then
                    tag = Instance.new("BillboardGui")
                    tag.Name = "OptTag"
                    tag.Size = UDim2.new(0, 70, 0, 25)
                    tag.AlwaysOnTop = true
                    tag.StudsOffset = Vector3.new(0, 2, 0)
                    
                    local txt = Instance.new("TextLabel", tag)
                    txt.Name = "Txt"
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextScaled = true
                    txt.Font = Enum.Font.SourceSansBold
                    txt.TextColor3 = Color3.fromRGB(255, 60, 60)
                    
                    tag.Parent = head
                    activeTags[player] = tag
                else
                    tag.Enabled = true
                    tag.Parent = head
                    tag.Txt.Text = player.Name
                end
            else
                if activeTags[player] then
                    activeTags[player].Enabled = false
                end
            end
        end
    end
end

-- تحديث خفيف جداً لا يؤثر على إطارات الجوال (FPS)
RunService.Heartbeat:Connect(function()
    if Settings.ESP_Enabled then
        pcall(updateESP)
    else
        for _, tag in pairs(activeTags) do
            tag.Enabled = false
        end
    end
end)

-- Silent Aim Hook الخفيف
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
