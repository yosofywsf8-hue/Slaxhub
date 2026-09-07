-- Slax Hub - Bloxstrap FPS & Quality Optimizer
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Cleanup previous UI
if LocalPlayer.PlayerGui:FindFirstChild("SlaxHubPremium") then
    LocalPlayer.PlayerGui.SlaxHubPremium:Destroy()
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubPremium"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

---------------------------------------------------------
-- SQUARE TOGGLE BUTTON
---------------------------------------------------------
local ToggleButton = Instance.new("ImageButton")
ToggleButton.Size = UDim2.new(0, 55, 0, 55)
ToggleButton.Position = UDim2.new(0.02, 0, 0.2, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ToggleButton.BorderSizePixel = 0
ToggleButton.Active = true
ToggleButton.Draggable = true
ToggleButton.ScaleType = Enum.ScaleType.Crop
ToggleButton.Parent = ScreenGui

ToggleButton.Image = "rbxthumb://type=Asset&id=124643845022233&w=420&h=420" 

local SquareCorner = Instance.new("UICorner")
SquareCorner.CornerRadius = UDim.new(0, 10)
SquareCorner.Parent = ToggleButton

local SquareStroke = Instance.new("UIStroke")
SquareStroke.Color = Color3.fromRGB(255, 30, 30)
SquareStroke.Thickness = 2
SquareStroke.Parent = ToggleButton

---------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------
local MainFrame = Instance.new("ImageLabel")
MainFrame.Size = UDim2.new(0, 310, 0, 520)
MainFrame.Position = UDim2.new(0.2, 0, 0.1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

MainFrame.Image = "rbxthumb://type=Asset&id=108512464651627&w=420&h=420"
MainFrame.ScaleType = Enum.ScaleType.Crop
MainFrame.ImageTransparency = 0.15
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 40, 40)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Readability Overlay
local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
Overlay.BackgroundTransparency = 0.35
Overlay.BorderSizePixel = 0
Overlay.Parent = MainFrame

local OverlayCorner = Instance.new("UICorner")
OverlayCorner.CornerRadius = UDim.new(0, 10)
OverlayCorner.Parent = Overlay

-- Top Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.04, 0, 0, 0)
Title.Text = "Slax Hub | Timebomb Duels"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(0.9, 0, 0.18, 0)
CloseBtn.Text = "❌"
CloseBtn.TextSize = 9
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

---------------------------------------------------------
-- ALL OPTIONS LIST
---------------------------------------------------------
local ScrollContainer = Instance.new("ScrollingFrame")
ScrollContainer.Size = UDim2.new(0.92, 0, 0.88, 0)
ScrollContainer.Position = UDim2.new(0.04, 0, 0.09, 0)
ScrollContainer.BackgroundTransparency = 1
ScrollContainer.BorderSizePixel = 0
ScrollContainer.ScrollBarThickness = 3
ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 480)
ScrollContainer.Parent = MainFrame

local MainLayout = Instance.new("UIListLayout")
MainLayout.Padding = UDim.new(0, 8)
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.Parent = ScrollContainer

-- 1. Auto Play Button
local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(1, 0, 0, 36)
AutoBtn.Text = "Auto Play: OFF"
AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 11
AutoBtn.Parent = ScrollContainer

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 6)
AutoCorner.Parent = AutoBtn

-- 2. Noclip Button
local NoclipBtn = Instance.new("TextButton")
NoclipBtn.Size = UDim2.new(1, 0, 0, 36)
NoclipBtn.Text = "Noclip: OFF 👻"
NoclipBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
NoclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NoclipBtn.Font = Enum.Font.GothamBold
NoclipBtn.TextSize = 11
NoclipBtn.Parent = ScrollContainer

local NoclipCorner = Instance.new("UICorner")
NoclipCorner.CornerRadius = UDim.new(0, 6)
NoclipCorner.Parent = NoclipBtn

-- 3. Daas (W+S) Button
local DaasBtn = Instance.new("TextButton")
DaasBtn.Size = UDim2.new(1, 0, 0, 36)
DaasBtn.Text = "دعس (W+S): OFF ⚡"
DaasBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
DaasBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DaasBtn.Font = Enum.Font.GothamBold
DaasBtn.TextSize = 11
DaasBtn.Parent = ScrollContainer

local DaasCorner = Instance.new("UICorner")
DaasCorner.CornerRadius = UDim.new(0, 6)
DaasCorner.Parent = DaasBtn

-- 4. Bloxstrap Graphics Optimizer Button (جديد!)
local BloxstrapBtn = Instance.new("TextButton")
BloxstrapBtn.Size = UDim2.new(1, 0, 0, 36)
BloxstrapBtn.Text = "Bloxstrap Boost: OFF 🚀"
BloxstrapBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
BloxstrapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BloxstrapBtn.Font = Enum.Font.GothamBold
BloxstrapBtn.TextSize = 11
BloxstrapBtn.Parent = ScrollContainer

local BloxstrapCorner = Instance.new("UICorner")
BloxstrapCorner.CornerRadius = UDim.new(0, 6)
BloxstrapCorner.Parent = BloxstrapBtn

-- 5. Music Input Row
local MusicControlsFrame = Instance.new("Frame")
MusicControlsFrame.Size = UDim2.new(1, 0, 0, 32)
MusicControlsFrame.BackgroundTransparency = 1
MusicControlsFrame.Parent = ScrollContainer

local MusicBox = Instance.new("TextBox")
MusicBox.Size = UDim2.new(0.52, 0, 1, 0)
MusicBox.PlaceholderText = "حط ID الاغنية هنا"
MusicBox.Text = ""
MusicBox.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
MusicBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicBox.PlaceholderColor3 = Color3.fromRGB(140, 150, 170)
MusicBox.Font = Enum.Font.Gotham
MusicBox.TextSize = 9
MusicBox.Parent = MusicControlsFrame

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = MusicBox

local PlayMusicBtn = Instance.new("TextButton")
PlayMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
PlayMusicBtn.Position = UDim2.new(0.55, 0, 0, 0)
PlayMusicBtn.Text = "▶️"
PlayMusicBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
PlayMusicBtn.TextSize = 9
PlayMusicBtn.Parent = MusicControlsFrame

local PlayCorner = Instance.new("UICorner")
PlayCorner.CornerRadius = UDim.new(0, 6)
PlayCorner.Parent = PlayMusicBtn

local StopMusicBtn = Instance.new("TextButton")
StopMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
StopMusicBtn.Position = UDim2.new(0.70, 0, 0, 0)
StopMusicBtn.Text = "⏹️"
StopMusicBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
StopMusicBtn.TextSize = 9
StopMusicBtn.Parent = MusicControlsFrame

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopMusicBtn

local SaveMusicBtn = Instance.new("TextButton")
SaveMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
SaveMusicBtn.Position = UDim2.new(0.85, 0, 0, 0)
SaveMusicBtn.Text = "💾"
SaveMusicBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
SaveMusicBtn.TextSize = 9
SaveMusicBtn.Parent = MusicControlsFrame

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveMusicBtn

-- 6. Saved Songs Frame
local SavedSongsScroll = Instance.new("Frame")
SavedSongsScroll.Size = UDim2.new(1, 0, 0, 170)
SavedSongsScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
SavedSongsScroll.BackgroundTransparency = 0.2
SavedSongsScroll.Parent = ScrollContainer

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 6)
ScrollCorner.Parent = SavedSongsScroll

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, 0, 1, 0)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.Parent = SavedSongsScroll

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Padding = UDim.new(0, 4)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = ScrollList

-- 7. Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 9
StatusLabel.Parent = ScrollContainer

-- 8. Credits Label
local CreditsLabel = Instance.new("TextLabel")
CreditsLabel.Size = UDim2.new(1, 0, 0, 20)
CreditsLabel.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
CreditsLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
CreditsLabel.BackgroundTransparency = 1
CreditsLabel.Font = Enum.Font.Gotham
CreditsLabel.TextSize = 8
CreditsLabel.Parent = ScrollContainer

---------------------------------------------------------
-- CORE LOGIC
---------------------------------------------------------
local currentSound = Instance.new("Sound")
currentSound.Name = "SlaxLocalSound"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = SoundService

local isAutoActive = false
local isNoclipActive = false
local isDaasActive = false
local isBloxstrapActive = false

local savedSongsList = {
    {Name = "Song 1", Id = 102710215948261, Loud = false},
    {Name = "Song 2", Id = 86503267790406, Loud = false},
    {Name = "Song 3", Id = 111018848542448, Loud = true}
}

local function playSongById(id)
    if id then
        currentSound.SoundId = "rbxassetid://" .. tostring(id)
        currentSound:Play()
        StatusLabel.Text = "Status: Playing ID " .. tostring(id) .. " 🎵"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
    end
end

local function stopSong()
    currentSound:Stop()
    StatusLabel.Text = "Status: Stopped ⏹️"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
end

local function refreshSavedSongsUI()
    for _, child in pairs(ScrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local ySize = 0
    for index, songData in ipairs(savedSongsList) do
        ySize = ySize + 32
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Size = UDim2.new(0.98, 0, 0, 28)
        ItemFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        ItemFrame.BackgroundTransparency = 0.1
        ItemFrame.Parent = ScrollList
        
        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 4)
        ItemCorner.Parent = ItemFrame
        
        local SongText = Instance.new("TextLabel")
        SongText.Size = UDim2.new(0.38, 0, 1, 0)
        SongText.Position = UDim2.new(0.02, 0, 0, 0)
        SongText.Text = songData.Name
        SongText.TextColor3 = Color3.fromRGB(230, 230, 240)
        SongText.BackgroundTransparency = 1
        SongText.Font = Enum.Font.Gotham
        SongText.TextSize = 8
        SongText.TextXAlignment = Enum.TextXAlignment.Left
        SongText.Parent = ItemFrame
        
        if songData.Loud then
            local WarnBadge = Instance.new("TextLabel")
            WarnBadge.Size = UDim2.new(0.22, 0, 0.7, 0)
            WarnBadge.Position = UDim2.new(0.38, 0, 0.15, 0)
            WarnBadge.Text = "⚠️عالية"
            WarnBadge.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
            WarnBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
            WarnBadge.Font = Enum.Font.GothamBold
            WarnBadge.TextSize = 7
            WarnBadge.Parent = ItemFrame
            
            local BadgeCorner = Instance.new("UICorner")
            BadgeCorner.CornerRadius = UDim.new(0, 4)
            BadgeCorner.Parent = WarnBadge
        end
        
        local PlayItemBtn = Instance.new("TextButton")
        PlayItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        PlayItemBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
        PlayItemBtn.Text = "▶️"
        PlayItemBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
        PlayItemBtn.TextSize = 7
        PlayItemBtn.Parent = ItemFrame
        
        local ItemPlayCorner = Instance.new("UICorner")
        ItemPlayCorner.CornerRadius = UDim.new(0, 4)
        ItemPlayCorner.Parent = PlayItemBtn
        
        local StopItemBtn = Instance.new("TextButton")
        StopItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        StopItemBtn.Position = UDim2.new(0.74, 0, 0.1, 0)
        StopItemBtn.Text = "⏹️"
        StopItemBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        StopItemBtn.TextSize = 7
        StopItemBtn.Parent = ItemFrame
        
        local ItemStopCorner = Instance.new("UICorner")
        ItemStopCorner.CornerRadius = UDim.new(0, 4)
        ItemStopCorner.Parent = StopItemBtn
        
        local DelItemBtn = Instance.new("TextButton")
        DelItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        DelItemBtn.Position = UDim2.new(0.86, 0, 0.1, 0)
        DelItemBtn.Text = "🗑️"
        DelItemBtn.BackgroundColor3 = Color3.fromRGB(80, 85, 100)
        DelItemBtn.TextSize = 7
        DelItemBtn.Parent = ItemFrame
        
        local ItemDelCorner = Instance.new("UICor`ner")
        ItemDelCorner.CornerRadius = UDim.new(0, 4)
        ItemDelCorner.Parent = DelItemBtn
        
        PlayItemBtn.MouseButton1Click:Connect(function() playSongById(songData.Id) end)
        StopItemBtn.MouseButton1Click:Connect(stopSong)
        DelItemBtn.MouseButton1Click:Connect(function()
            table.remove(savedSongsList, index)
            refreshSavedSongsUI()
        end)
    end
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, ySize)
end

refreshSavedSongsUI()

PlayMusicBtn.MouseButton1Click:Connect(function()
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then playSongById(soundId) else MusicBox.Text = ""; MusicBox.PlaceholderText = "ID غير صحيح!" end
end)

StopMusicBtn.MouseButton1Click:Connect(stopSong)

SaveMusicBtn.MouseButton1Click:Connect(function()
    if #savedSongsList >= 5 then
        StatusLabel.Text = "⚠️ وصلت الحد الأقصى! (5 أغاني فقط)"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        return
    end
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then
        table.insert(savedSongsList, {Name = "Song " .. tostring(#savedSongsList + 1), Id = soundId, Loud = false})
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "تم الحفظ!"
        refreshSavedSongsUI()
    end
end)

ToggleButton.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

CloseBtn.MouseButton1Click:Connect(function()
    isAutoActive = false
    isNoclipActive = false
    isDaasActive = false
    isBloxstrapActive = false
    currentSound:Destroy()
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
    ScreenGui:Destroy()
end)

AutoBtn.MouseButton1Click:Connect(function()
    isAutoActive = not isAutoActive
    AutoBtn.Text = isAutoActive and "Auto Play: ON" or "Auto Play: OFF"
    AutoBtn.BackgroundColor3 = isAutoActive and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

NoclipBtn.MouseButton1Click:Connect(function()
    isNoclipActive = not isNoclipActive
    NoclipBtn.Text = isNoclipActive and "Noclip: ON 👻" or "Noclip: OFF 👻"
    NoclipBtn.BackgroundColor3 = isNoclipActive and Color3.fromRGB(140, 50, 210) or Color3.fromRGB(40, 45, 60)
    if not isNoclipActive and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCoordinate = true end
        end
    end
end)

DaasBtn.MouseButton1Click:Connect(function()
    isDaasActive = not isDaasActive
    DaasBtn.Text = isDaasActive and "دعس (W+S): ON ⚡" or "دعس (W+S): OFF ⚡"
    DaasBtn.BackgroundColor3 = isDaasActive and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(40, 45, 60)
end)

-- خيار تحسين الجودة والأداء (Bloxstrap Style)
BloxstrapBtn.MouseButton1Click:Connect(function()
    isBloxstrapActive = not isBloxstrapActive
    BloxstrapBtn.Text = isBloxstrapActive and "Bloxstrap Boost: ON 🚀" or "Bloxstrap Boost: OFF 🚀"
    BloxstrapBtn.BackgroundColor3 = isBloxstrapActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 45, 60)
    
    if isBloxstrapActive then
        -- إعدادات مشابهة لـ Bloxstrap لتقليل الضغط ورفع الفريمات
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.Brightness = 2
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("Sky") or v:IsA("Atmosphere") then
                v.Enabled = false
            end
        end
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Material = Enum.Material.SmoothPlastic
                part.Reflectance = 0
            end
        end
        StatusLabel.Text = "Status: Bloxstrap Boost Enabled 🚀"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
    else
        StatusLabel.Text = "Status: Boost Disabled ⚠️"
        StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

task.spawn(function()
    while task.wait(0.12) do
        if isDaasActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            root.CFrame = root.CFrame * CFrame.new(0, 0, -1.8)
            task.wait(0.06)
            root.CFrame = root.CFrame * CFrame.new(0, 0, 1.8)
        end
    end
end)

local function holdsBomb()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local inChar = myChar:FindFirstChild("Bomb") or myChar:FindFirstChildWhichIsA("Tool")
    if inChar and string.find(string.lower(inChar.Name), "bomb") then return true end
    local inBackpack = LocalPlayer.Backpack:FindFirstChild("Bomb") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if inBackpack and string.find(string.lower(inBackpack.Name), "bomb") then return true end
    return false
end

local function getArenaTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local nearest = nil
    local shortestDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < 120 and dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

RunService.Stepped:Connect(function()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or not myChar:FindFirstChild("HumanoidRootPart") then return end
    
    if isNoclipActive then
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    
    if isAutoActive and holdsBomb() then
        local targetPlayer = getArenaTarget()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            myChar.Humanoid:MoveTo(targetPlayer.Character.HumanoidRootPart.Position)
        end
    end
end)
