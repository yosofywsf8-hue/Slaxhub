-- Steal An Egg - Auto-Collect & Anti-Cheat Hub by Slax Hub
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
Title.Text = "SLAX HUB - AUTO COLLECT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
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

-- دالة التفاعل التلقائي مع البيضة (تفعيل الـ ProximityPrompt أو النقر)
local function interactWithTarget(targetPart)
    if not targetPart or not targetPart.Parent then return end
    local model = targetPart.Parent
    
    -- محاولة تفعيل ProximityPrompt إن وجد
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            pcall(function()
                fireproximityprompt(desc)
            end)
        end
    end
    
    -- إرسال حدث لمس أو تفعيل مباشر للبارت
    pcall(function()
        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, targetPart, 0)
        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, targetPart, 1)
    end)
end

-- دالة الحركة الآمنة مع أخذ البيضة فوراً
local function safeTweenTo(targetPart)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not targetPart then return end
    local rootPart = char.HumanoidRootPart
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    
    local highOffset = Vector3.new(0, 25, 0)
    local currentPos = rootPart.Position
    local targetPos = targetPart.Position
    
    -- الارتفاع للأعلى لتفادي الحراس
    local upCFrame = CFrame.new(currentPos + highOffset)
    local tweenUp = TweenService:Create(rootPart, TweenInfo.new((rootPart.Position - upCFrame.Position).Magnitude / 350, Enum.EasingStyle.Linear), {CFrame = upCFrame})
    tweenUp:Play()
    tweenUp.Completed:Wait()
    
    -- الذهاب فوق البيضة
    local aboveTargetCFrame = CFrame.new(targetPos + Vector3.new(0, 25, 0))
    local tweenMove = TweenService:Create(rootPart, TweenInfo.new((rootPart.Position - aboveTargetCFrame.Position).Magnitude / 350, Enum.EasingStyle.Linear), {CFrame = aboveTargetCFrame})
    tweenMove:Play()
    tweenMove.Completed:Wait()
    
    -- الهبوط على البيضة تماماً
    rootPart.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.2)
    
    -- تنفيذ الالتقاط التلقائي عدة مرات لضمان الشيل
    for i = 1, 3 do
        interactWithTarget(targetPart)
        task.wait(0.1)
    end
    
    -- الصعود السريع للعودة لمنطقة الأمان
    local safeHighCFrame = CFrame.new(safeZonePosition.Position + highOffset)
    local tweenSafe = TweenService:Create(rootPart, TweenInfo.new((rootPart.Position - safeHighCFrame.Position).Magnitude / 350, Enum.EasingStyle.Linear), {CFrame = safeHighCFrame})
    tweenSafe:Play()
    tweenSafe.Completed:Wait()
    
    rootPart.CFrame = safeZonePosition
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

-- استخراج الصورة
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

-- تحديث القائمة والصور
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
                    
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 28, 0, 28)
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

-- تنفيذ الأخذ التلقائي عند الضغط على GO
task.spawn(function()
    while true do
        task.wait(0.5)
        if isRunning and safeZonePosition and selectedTargetPart and selectedTargetPart.Parent then
            safeTweenTo(selectedTargetPart)
            task.wait(1)
        end
    end
end)
