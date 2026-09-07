-- Steal An Egg - Miranda Style with Pet Images by Slax Hub
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxMirandaHub"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Main Hub Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 230, 0, 320)
MainFrame.Position = UDim2.new(0.65, 0, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(220, 40, 40)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- Title Header
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "SLAX HUB - STEAL AN EGG"
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

-- Scrolling Frame for Items List
local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(0.92, 0, 0, 190)
ScrollingFrame.Position = UDim2.new(0.04, 0, 0.22, 0)
ScrollingFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.ScrollBarThickness = 4
ScrollingFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollingFrame
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)

-- Safe Zone Button
local SafeBtn = Instance.new("TextButton")
SafeBtn.Size = UDim2.new(0.44, 0, 0, 35)
SafeBtn.Position = UDim2.new(0.04, 0, 0.85, 0)
SafeBtn.Text = "SET SAFE 🏠"
SafeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
SafeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SafeBtn.Font = Enum.Font.GothamBold
SafeBtn.TextSize = 10
SafeBtn.Parent = MainFrame

local SafeCorner = Instance.new("UICorner")
SafeCorner.CornerRadius = UDim.new(0, 6)
SafeCorner.Parent = SafeBtn

-- GO Button
local GoBtn = Instance.new("TextButton")
GoBtn.Size = UDim2.new(0.23, 0, 0, 35)
GoBtn.Position = UDim2.new(0.50, 0, 0.85, 0)
GoBtn.Text = "GO"
GoBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 50)
GoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GoBtn.Font = Enum.Font.GothamBold
GoBtn.TextSize = 11
GoBtn.Parent = MainFrame

local GoCorner = Instance.new("UICorner")
GoCorner.CornerRadius = UDim.new(0, 6)
GoCorner.Parent = GoBtn

-- STOP Button
local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(0.23, 0, 0, 35)
StopBtn.Position = UDim2.new(0.75, 0, 0.85, 0)
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

-- دالة التنقل بالسرعة 350 الثابتة
local function tweenTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = char.HumanoidRootPart
    
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local speed = 350
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Wait()
end

-- استخراج صورة الحيوان أو البيضة ديناميكياً
local function getObjectImage(obj)
    local decal = obj:FindFirstChildWhichIsA("Decal", true) or obj:FindFirstChildWhichIsA("Texture", true)
    if decal and decal.Texture ~= "" then
        return decal.Texture
    end
    -- صورة افتراضية بيضة في حال عدم توفر صورة مخصصة
    return "rbxassetid://6031094678"
end

-- تحديث القائمة مع الصور والبيانات
task.spawn(function()
    while true do
        task.wait(1.5)
        
        for _, child in pairs(ScrollingFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (string.find(string.lower(obj.Name), "egg") or obj:FindFirstChild("Rarity") or obj:GetAttribute("Rarity")) then
                local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if root and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude
                    local distStr = string.format("%.1fm", dist)
                    local petName = obj:FindFirstChild("PetName") and obj.PetName.Value or obj:GetAttribute("PetName") or obj.Name
                    local rarityVal = obj:FindFirstChild("Rarity") and obj.Rarity.Value or obj:GetAttribute("Rarity") or "Egg"
                    local imgId = getObjectImage(obj)
                    
                    count = count + 1
                    local itemBtn = Instance.new("TextButton")
                    itemBtn.Size = UDim2.new(1, 0, 0, 36)
                    itemBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
                    itemBtn.BorderSizePixel = 0
                    itemBtn.Text = ""
                    itemBtn.Parent = ScrollingFrame
                    
                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0, 4)
                    c.Parent = itemBtn
                    
                    -- أيقونة / صورة الحيوان أو البيضة
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 28, 0, 28)
                    icon.Position = UDim2.new(0.02, 0, 0.12, 0)
                    icon.BackgroundTransparency = 1
                    icon.Image = imgId
                    icon.Parent = itemBtn
                    
                    local iconCorner = Instance.new("UICorner")
                    iconCorner.CornerRadius = UDim.new(0, 4)
                    iconCorner.Parent = icon
                    
                    -- النص والمعلومات
                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(0.72, 0, 1, 0)
                    txt.Position = UDim2.new(0.18, 0, 0, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = string.format("%s (%s)\nDist: %s", tostring(petName), tostring(rarityVal), distStr)
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
        ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, count * 40)
    end
end)

-- حلقة التنفيذ التلقائي عند الضغط على GO
task.spawn(function()
    while true do
        task.wait(0.5)
        if isRunning and safeZonePosition and selectedTargetPart and selectedTargetPart.Parent then
            tweenTo(selectedTargetPart.CFrame + Vector3.new(0, 3, 0))
            task.wait(0.5)
            tweenTo(safeZonePosition)
            task.wait(1)
        end
    end
end)
