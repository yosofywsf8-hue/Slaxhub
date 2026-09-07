-- Miranda Hub - Ultimate Fix & Multi-Zone Collector by Slax Hub
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

if LocalPlayer.PlayerGui:FindFirstChild("SlaxSafeHub") then
    LocalPlayer.PlayerGui.SlaxSafeHub:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxSafeHub"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 340)
MainFrame.Position = UDim2.new(0.60, 0, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 200, 100)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "MIRANDA HUB - 100% SAFE"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Parent = MainFrame

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, 0, 0, 15)
SubTitle.Position = UDim2.new(0, 0, 0, 25)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "discord.gg/SlaxHub"
SubTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 9
SubTitle.Parent = MainFrame

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(0.92, 0, 0, 200)
ScrollingFrame.Position = UDim2.new(0.04, 0, 0.22, 0)
ScrollingFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.ScrollBarThickness = 4
ScrollingFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollingFrame
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)

local SafeBtn = Instance.new("TextButton")
SafeBtn.Size = UDim2.new(0.44, 0, 0, 35)
SafeBtn.Position = UDim2.new(0.04, 0, 0.84, 0)
SafeBtn.Text = "SET SAFE 🏠"
SafeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
SafeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SafeBtn.Font = Enum.Font.GothamBold
SafeBtn.TextSize = 10
SafeBtn.Parent = MainFrame

local SafeCorner = Instance.new("UICorner")
SafeCorner.CornerRadius = UDim.new(0, 6)
SafeCorner.Parent = SafeBtn

local GoBtn = Instance.new("TextButton")
GoBtn.Size = UDim2.new(0.23, 0, 0, 35)
GoBtn.Position = UDim2.new(0.50, 0, 0.84, 0)
GoBtn.Text = "GO"
GoBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 50)
GoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GoBtn.Font = Enum.Font.GothamBold
GoBtn.TextSize = 11
GoBtn.Parent = MainFrame

local GoCorner = Instance.new("UICorner")
GoCorner.CornerRadius = UDim.new(0, 6)
GoCorner.Parent = GoBtn

local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(0.23, 0, 0, 35)
StopBtn.Position = UDim2.new(0.75, 0, 0.84, 0)
StopBtn.Text = "STOP"
StopBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.Font = Enum.Font.GothamBold
StopBtn.TextSize = 11
StopBtn.Parent = MainFrame

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopBtn

local safeZonePosition = nil
local selectedTargetPart = nil
local isRunning = false

SafeBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        safeZonePosition = char.HumanoidRootPart.CFrame
        SafeBtn.Text = "SAVED! ✅"
    end
end)

StopBtn.MouseButton1Click:Connect(function()
    isRunning = false
    selectedTargetPart = nil
    GoBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 50)
end)

GoBtn.MouseButton1Click:Connect(function()
    if not safeZonePosition then return end
    isRunning = true
    GoBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
end)

-- Noclip آمن تماماً
RunService.Stepped:Connect(function()
    if isRunning and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- استخراج الأيقونات بدقة من أي عنصر داخل الماب
local function getObjectImage(obj)
    for _, descendant in pairs(obj:GetDescendants()) do
        if (descendant:IsA("Decal") or descendant:IsA("Texture")) and descendant.Texture ~= "" then
            return descendant.Texture
        elseif (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) and descendant.Image ~= "" then
            return descendant.Image
        end
    end
    return "rbxassetid://6023426915"
end

-- دالة التنقل الآمن عبر المشي الحقيقي لمنع الموت نهائياً
local function safeMoveToTarget(targetPart)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not targetPart then return end
    local rootPart = char.HumanoidRootPart
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if not humanoid then return end
    
    local targetPos = targetPart.Position + Vector3.new(0, 1, 0)
    
    -- استخدام نظام المشي الحقيقي Humanoid:MoveTo لتجنب كشف الحراس للأنتشيت
    humanoid:MoveTo(targetPos)
    
    local reached = false
    local connection
    connection = humanoid.MoveFinished:Connect(function(success)
        reached = true
        connection:Disconnect()
    end)
    
    -- انتظار الوصول مع مهلة زمنية قصيرة
    local tickCount = 0
    while not reached and tickCount < 60 and isRunning do
        task.wait(0.1)
        tickCount = tickCount + 1
        if (rootPart.Position - targetPos).Magnitude < 4 then
            break
        end
    end
    if connection then connection:Disconnect() end
    
    rootPart.CFrame = CFrame.new(targetPos)
    task.wait(0.2)
    
    -- تفاعل التجميع والشيل
    pcall(function()
        for _, desc in pairs(targetPart.Parent:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                fireclickdetector(desc)
            elseif desc:IsA("ProximityPrompt") then
                fireproximityprompt(desc)
            end
        end
        firetouchinterest(rootPart, targetPart, 0)
        firetouchinterest(rootPart, targetPart, 1)
        
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") then
                local name = string.lower(remote.Name)
                if string.find(name, "egg") or string.find(name, "steal") or string.find(name, "collect") or string.find(name, "pickup") or string.find(name, "claim") then
                    pcall(function() remote:FireServer(targetPart.Parent) remote:FireServer(targetPart) end)
                end
            end
        end
    end)
    
    task.wait(0.3)
    
    -- العودة لمنطقة الأمان بأمان
    if safeZonePosition then
        humanoid:MoveTo(safeZonePosition.Position)
        task.wait(1.5)
        rootPart.CFrame = safeZonePosition
    end
end

-- تحديث القائمة ليشمل كل مناطق الماب وكل البيوض المتاحة
task.spawn(function()
    while true do
        task.wait(2)
        
        for _, child in pairs(ScrollingFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local count = 0
        -- فحص شامل لكل محتويات الـ Workspace لجلب جميع المناطق
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (string.find(string.lower(obj.Name), "egg") or string.find(string.lower(obj.Name), "spawn") or string.find(string.lower(obj.Name), "item") or obj:FindFirstChild("Rarity")) then
                local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if root and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude
                    local distStr = string.format("%.1fm", dist)
                    local itemName = obj.Name
                    local imgId = getObjectImage(obj)
                    
                    count = count + 1
                    local itemBtn = Instance.new("TextButton")
                    itemBtn.Size = UDim2.new(1, 0, 0, 42)
                    itemBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
                    itemBtn.BorderSizePixel = 0
                    itemBtn.Text = ""
                    itemBtn.Parent = ScrollingFrame
                    
                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0, 6)
                    c.Parent = itemBtn
                    
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 32, 0, 32)
                    icon.Position = UDim2.new(0.02, 0, 0.12, 0)
                    icon.BackgroundTransparency = 1
                    icon.Image = imgId
                    icon.Parent = itemBtn
                    
                    local iconCorner = Instance.new("UICorner")
                    iconCorner.CornerRadius = UDim.new(0, 4)
                    iconCorner.Parent = icon
                    
                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(0.72, 0, 1, 0)
                    txt.Position = UDim2.new(0.18, 0, 0, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = string.format("Egg: %s\nDist: %s", tostring(itemName), distStr)
                    txt.TextColor3 = Color3.fromRGB(220, 220, 230)
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 9
                    txt.TextXAlignment = Enum.TextXAlignment.Left
                    txt.Parent = itemBtn
                    
                    itemBtn.MouseButton1Click:Connect(function()
                        selectedTargetPart = root
                        for _, b in pairs(ScrollingFrame:GetChildren()) do
                            if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(25, 25, 32) end
                        end
                        itemBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
                    end)
                end
            end
        end
        ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, count * 47)
    end
end)

-- التشغيل التلقائي
task.spawn(function()
    while true do
        task.wait(0.5)
        if isRunning and safeZonePosition and selectedTargetPart and selectedTargetPart.Parent then
            safeMoveToTarget(selectedTargetPart)
            task.wait(1)
        end
    end
end)
