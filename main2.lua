-- Steal An Egg - Ultimate ESP & Auto Strongest Egg by Slax Hub
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxStealEggGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- UI Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 180, 0, 110)
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

-- Auto Best Egg Toggle
local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(0.9, 0, 0, 40)
AutoBtn.Position = UDim2.new(0.05, 0, 0.08, 0)
AutoBtn.Text = "Auto Strongest Egg: OFF"
AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 10
AutoBtn.Parent = MainFrame

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 6)
AutoCorner.Parent = AutoBtn

-- ESP Toggle
local EspBtn = Instance.new("TextButton")
EspBtn.Size = UDim2.new(0.9, 0, 0, 40)
EspBtn.Position = UDim2.new(0.05, 0, 0.54, 0)
EspBtn.Text = "Eggs ESP: OFF"
EspBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
EspBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EspBtn.Font = Enum.Font.GothamBold
EspBtn.TextSize = 10
EspBtn.Parent = MainFrame

local EspCorner = Instance.new("UICorner")
EspCorner.CornerRadius = UDim.new(0, 6)
EspCorner.Parent = EspBtn

local isAutoActive = false
local isEspActive = false

AutoBtn.MouseButton1Click:Connect(function()
    isAutoActive = not isAutoActive
    AutoBtn.Text = isAutoActive and "Auto Strongest Egg: ON" or "Auto Strongest Egg: OFF"
    AutoBtn.BackgroundColor3 = isAutoActive and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

EspBtn.MouseButton1Click:Connect(function()
    isEspActive = not isEspActive
    EspBtn.Text = isEspActive and "Eggs ESP: ON" or "Eggs ESP: OFF"
    EspBtn.BackgroundColor3 = isEspActive and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

-- نظام الـ ESP وعرض اسم الحيوان، الندرة (Divine، إلخ) ومستوى التطوير
local espCache = {}

local function updateEsp()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (string.find(string.lower(obj.Name), "egg") or obj:FindFirstChild("Rarity") or obj:FindFirstChild("PetName")) then
            local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if root then
                if not espCache[obj] and isEspActive then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "SlaxEggESP"
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
                if cache then
                    cache.Gui.Enabled = isEspActive
                    if isEspActive then
                        -- استخراج بيانات الحيوان والندرة وتطويره من خصائص البيضة
                        local rarityVal = obj:FindFirstChild("Rarity") and obj.Rarity.Value or "Legendary"
                        local petVal = obj:FindFirstChild("PetName") and obj.PetName.Value or obj.Name
                        local tierVal = obj:FindFirstChild("Tier") and obj.Tier.Value or obj:FindFirstChild("Level") and obj.Level.Value or "Max"
                        
                        cache.Text.Text = string.format("🥚 %s\n⭐ Rarity: %s\n⚡ Tier/Upgrade: %s", tostring(petVal), tostring(rarityVal), tostring(tierVal))
                        
                        -- تلوين النص حسب الندرة
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
    
    -- تنظيف العناصر القديمة
    for obj, cache in pairs(espCache) do
        if not obj or not obj.Parent then
            if cache.Gui then cache.Gui:Destroy() end
            espCache[obj] = nil
        end
    end
end

-- دالة لتحديد أقوى بيضة كلياً
local function getStrongestEgg()
    local bestEgg = nil
    local maxScore = -1
    
    local weights = {["Divine"] = 5000, ["Secret"] = 4000, ["Cosmic"] = 3000, ["Mythic"] = 2000, ["Legendary"] = 1000, ["Epic"] = 500}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (string.find(string.lower(obj.Name), "egg") or obj:FindFirstChild("Rarity")) then
            local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                local score = 100
                local rarityObj = obj:FindFirstChild("Rarity")
                if rarityObj and weights[tostring(rarityObj.Value)] then
                    score = weights[tostring(rarityObj.Value)]
                end
                
                if score > maxScore then
                    maxScore = score
                    bestEgg = primaryPart
                end
            end
        end
    end
    return bestEgg
end

RunService.Stepped:Connect(function()
    updateEsp()
    
    if isAutoActive then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
            local targetEgg = getStrongestEgg()
            if targetEgg then
                char.Humanoid:MoveTo(targetEgg.Position)
            end
        end
    end
end)

