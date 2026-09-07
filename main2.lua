-- Steal An Egg - Optimized No-Lag Script by Slax Hub
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxTweenEggGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- UI Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 190, 0, 185)
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 40, 40)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Set Safe Zone Button
local SetSafeBtn = Instance.new("TextButton")
SetSafeBtn.Size = UDim2.new(0.9, 0, 0, 30)
SetSafeBtn.Position = UDim2.new(0.05, 0, 0.06, 0)
SetSafeBtn.Text = "Set Safe Zone 🏠"
SetSafeBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
SetSafeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SetSafeBtn.Font = Enum.Font.GothamBold
SetSafeBtn.TextSize = 10
SetSafeBtn.Parent = MainFrame

local SafeCorner = Instance.new("UICorner")
SafeCorner.CornerRadius = UDim.new(0, 6)
SafeCorner.Parent = SetSafeBtn

-- Auto Tween Farm Toggle
local AutoTweenBtn = Instance.new("TextButton")
AutoTweenBtn.Size = UDim2.new(0.9, 0, 0, 30)
AutoTweenBtn.Position = UDim2.new(0.05, 0, 0.32, 0)
AutoTweenBtn.Text = "Auto Tween Farm: OFF"
AutoTweenBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoTweenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoTweenBtn.Font = Enum.Font.GothamBold
AutoTweenBtn.TextSize = 10
AutoTweenBtn.Parent = MainFrame

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 6)
AutoCorner.Parent = AutoTweenBtn

-- Universal ESP Toggle
local EspBtn = Instance.new("TextButton")
EspBtn.Size = UDim2.new(0.9, 0, 0, 30)
EspBtn.Position = UDim2.new(0.05, 0, 0.58, 0)
EspBtn.Text = "Universal Eggs ESP: OFF"
EspBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
EspBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EspBtn.Font = Enum.Font.GothamBold
EspBtn.TextSize = 10
EspBtn.Parent = MainFrame

local EspCorner = Instance.new("UICorner")
EspCorner.CornerRadius = UDim.new(0, 6)
EspCorner.Parent = EspBtn

-- Status Label
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(0.9, 0, 0, 25)
StatusLbl.Position = UDim2.new(0.05, 0, 0.84, 0)
StatusLbl.Text = "Status: Set Safe Zone First"
StatusLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 9
StatusLbl.Parent = MainFrame

local safeZonePosition = nil
local isTweenRunning = false
local isEspActive = false
local espCache = {}

SetSafeBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        safeZonePosition = char.HumanoidRootPart.CFrame
        StatusLbl.Text = "Status: Safe Zone Saved! ✅"
        StatusLbl.TextColor3 = Color3.fromRGB(40, 167, 69)
    end
end)

AutoTweenBtn.MouseButton1Click:Connect(function()
    if not safeZonePosition then
        StatusLbl.Text = "Error: Set Safe Zone First! ❌"
        StatusLbl.TextColor3 = Color3.fromRGB(220, 53, 69)
        return
    end
    
    isTweenRunning = not isTweenRunning
    AutoTweenBtn.Text = isTweenRunning and "Auto Tween Farm: ON" or "Auto Tween Farm: OFF"
    AutoTweenBtn.BackgroundColor3 = isTweenRunning and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

EspBtn.MouseButton1Click:Connect(function()
    isEspActive = not isEspActive
    EspBtn.Text = isEspActive and "Universal Eggs ESP: ON" or "Universal Eggs ESP: OFF"
    EspBtn.BackgroundColor3 = isEspActive and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
    
    if not isEspActive then
        for _, cache in pairs(espCache) do
            if cache.Gui then cache.Gui:Destroy() end
        end
        espCache = {}
    end
end)

-- دالة بحث محسنة وخفيفة لا تسبب دروب فريم
local function getStrongestEggPart()
    local bestPart = nil
    local maxScore = -1
    local weights = {["Divine"] = 5000, ["Secret"] = 4000, ["Cosmic"] = 3000, ["Mythic"] = 2000, ["Legendary"] = 1000}
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("Model") and (string.find(string.lower(child.Name), "egg") or child:FindFirstChild("Rarity") or child:FindFirstChild("PetName")) then
                    local primaryPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        local score = 100
                        local rarityObj = child:FindFirstChild("Rarity")
                        if rarityObj and weights[tostring(rarityObj.Value)] then
                            score = weights[tostring(rarityObj.Value)]
                        end
                        
                        if score > maxScore then
                            maxScore = score
                            bestPart = primaryPart
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

-- نظام ESP خفيف ومحدث كل فترة بدل الضغط على الإطارات
task.spawn(function()
    while true do
        task.wait(1) -- تحديث الـ ESP كل ثانية لعدم التسبب بأي لاج
        if isEspActive then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and (string.find(string.lower(obj.Name), "egg") or obj:FindFirstChild("Rarity") or obj:FindFirstChild("PetName")) then
                    local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if root then
                        if not espCache[obj] then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "SlaxUniversalEggESP"
                            billboard.Size = UDim2.new(0, 200, 0, 60)
                            billboard.StudsOffset = Vector3.new(0, 3, 0)
                            billboard.AlwaysOnTop = true
                            
                            local textLabel = Instance.new("TextLabel")
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                            textLabel.TextStrokeTransparency = 0
                            textLabel.TextSize = 11
                            textLabel.Font = Enum.Font.GothamBold
                            textLabel.Parent = billboard
                            
                            billboard.Parent = root
                            espCache[obj] = {Gui = billboard, Text = textLabel}
                        end
                        
                        local cache = espCache[obj]
                        if cache and cache.Text then
                            local rarityVal = obj:FindFirstChild("Rarity") and obj.Rarity.Value or "Legendary"
                            local petVal = obj:FindFirstChild("PetName") and obj.PetName.Value or obj.Name
                            local tierVal = obj:FindFirstChild("Tier") and obj.Tier.Value or obj:FindFirstChild("Level") and obj.Level.Value or "Max"
                            
                            cache.Text.Text = string.string and string.format("🥚 %s\n⭐ Rarity: %s\n⚡ Tier: %s", tostring(petVal), tostring(rarityVal), tostring(tierVal)) or ("🥚 " .. tostring(petVal))
                            
                            if string.find(string.lower(tostring(rarityVal)), "divine") or string.find(string.lower(tostring(rarityVal)), "secret") then
                                cache.Text.TextColor3 = Color3.fromRGB(255, 50, 50)
                            elseif string.find(string.lower(tostring(rarityVal)), "cosmic") or string.find(string.lower(tostring(rarityVal)), "mythic") then
                                cache.Text.TextColor3 = Color3.fromRGB(180, 50, 255)
                            else
                                cache.Text.TextColor3 = Color3.fromRGB(255, 215, 0)
                            end
                        end
                    end
                end
            end
        end
        
        -- تنظيف البيانات التالفة
        for obj, cache in pairs(espCache) do
            if not obj or not obj.Parent then
                if cache.Gui then cache.Gui:Destroy() end
                espCache[obj] = nil
            end
        end
    end
end)

-- دالة التنقل السريع بسرعة 500
local function tweenTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = char.HumanoidRootPart
    
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local speed = 500
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Wait()
end

-- حلقة زراعة خفيفة وآمنة
task.spawn(function()
    while true do
        task.wait(0.8)
        if isTweenRunning and safeZonePosition then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                StatusLbl.Text = "Status: Searching Egg... 🔍"
                local eggPart = getStrongestEggPart()
                
                if eggPart then
                    StatusLbl.Text = "Status: Tweening to Egg... ⚡"
                    tweenTo(eggPart.CFrame + Vector3.new(0, 3, 0))
                    task.wait(0.5)
                    
                    StatusLbl.Text = "Status: Returning to Safe Zone 🏠"
                    tweenTo(safeZonePosition)
                    task.wait(1)
                else
                    StatusLbl.Text = "Status: No Eggs Found ⏳"
                end
            end
        end
    end
end)
