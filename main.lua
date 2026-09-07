-- Timebomb Duels Mobile - Music Hub & Auto Pass (No Speed / Fixed List)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Cleanup previous GUI
if LocalPlayer.PlayerGui:FindFirstChild("TimebombMusicGUI") then
    LocalPlayer.PlayerGui.TimebombMusicGUI:Destroy()
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimebombMusicGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Draggable Floating Circle Button
local ToggleCircle = Instance.new("TextButton")
ToggleCircle.Size = UDim2.new(0, 50, 0, 50)
ToggleCircle.Position = UDim2.new(0.02, 0, 0.25, 0)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
ToggleCircle.Text = "💣"
ToggleCircle.TextSize = 24
ToggleCircle.Active = true
ToggleCircle.Draggable = true
ToggleCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(90, 100, 125)
CircleStroke.Thickness = 2
CircleStroke.Parent = ToggleCircle

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 350)
MainFrame.Position = UDim2.new(0.18, 0, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 55, 70)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Title Bar
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.75, 0, 0, 25)
Title.Position = UDim2.new(0.04, 0, 0.02, 0)
Title.Text = "Timebomb Ultra Hub"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

-- Credits
local Credits = Instance.new("TextLabel")
Credits.Size = UDim2.new(0.92, 0, 0, 15)
Credits.Position = UDim2.new(0.04, 0, 0.08, 0)
Credits.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
Credits.TextColor3 = Color3.fromRGB(160, 170, 190)
Credits.BackgroundTransparency = 1
Credits.Font = Enum.Font.Gotham
Credits.TextSize = 10
Credits.TextXAlignment = Enum.TextXAlignment.Left
Credits.Parent = MainFrame

-- Close Button (❌)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(0.87, 0, 0.02, 0)
CloseBtn.Text = "❌"
CloseBtn.TextSize = 10
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Auto Pass Toggle Button
local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(0.92, 0, 0, 32)
AutoBtn.Position = UDim2.new(0.04, 0, 0.14, 0)
AutoBtn.Text = "Auto Play: OFF"
AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 12
AutoBtn.Parent = MainFrame

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 6)
AutoCorner.Parent = AutoBtn

-- Noclip Toggle Button
local NoclipBtn = Instance.new("TextButton")
NoclipBtn.Size = UDim2.new(0.92, 0, 0, 32)
NoclipBtn.Position = UDim2.new(0.04, 0, 0.25, 0)
NoclipBtn.Text = "Noclip: OFF 👻"
NoclipBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
NoclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NoclipBtn.Font = Enum.Font.GothamBold
NoclipBtn.TextSize = 12
NoclipBtn.Parent = MainFrame

local NoclipCorner = Instance.new("UICorner")
NoclipCorner.CornerRadius = UDim.new(0, 6)
NoclipCorner.Parent = NoclipBtn

-- Music Input Box
local MusicBox = Instance.new("TextBox")
MusicBox.Size = UDim2.new(0.5, 0, 0, 30)
MusicBox.Position = UDim2.new(0.04, 0, 0.36, 0)
MusicBox.PlaceholderText = "حط ID الاغنية هنا"
MusicBox.Text = ""
MusicBox.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
MusicBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicBox.PlaceholderColor3 = Color3.fromRGB(130, 140, 160)
MusicBox.Font = Enum.Font.Gotham
MusicBox.TextSize = 10
MusicBox.Parent = MainFrame

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = MusicBox

-- Play Button
local PlayMusicBtn = Instance.new("TextButton")
PlayMusicBtn.Size = UDim2.new(0.12, 0, 0, 30)
PlayMusicBtn.Position = UDim2.new(0.56, 0, 0.36, 0)
PlayMusicBtn.Text = "▶️"
PlayMusicBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
PlayMusicBtn.TextSize = 11
PlayMusicBtn.Parent = MainFrame

local PlayCorner = Instance.new("UICorner")
PlayCorner.CornerRadius = UDim.new(0, 6)
PlayCorner.Parent = PlayMusicBtn

-- Save Button
local SaveMusicBtn = Instance.new("TextButton")
SaveMusicBtn.Size = UDim2.new(0.12, 0, 0, 30)
SaveMusicBtn.Position = UDim2.new(0.70, 0, 0.36, 0)
SaveMusicBtn.Text = "💾"
SaveMusicBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
SaveMusicBtn.TextSize = 11
SaveMusicBtn.Parent = MainFrame

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveMusicBtn

-- Stop Button
local StopMusicBtn = Instance.new("TextButton")
StopMusicBtn.Size = UDim2.new(0.12, 0, 0, 30)
StopMusicBtn.Position = UDim2.new(0.84, 0, 0.36, 0)
StopMusicBtn.Text = "⏹️"
StopMusicBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
StopMusicBtn.TextSize = 11
StopMusicBtn.Parent = MainFrame

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopMusicBtn

-- Saved Songs Label
local ListLabel = Instance.new("TextLabel")
ListLabel.Size = UDim2.new(0.92, 0, 0, 16)
ListLabel.Position = UDim2.new(0.04, 0, 0.46, 0)
ListLabel.Text = "📁 قائمة الأغاني المحفوظة:"
ListLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
ListLabel.BackgroundTransparency = 1
ListLabel.Font = Enum.Font.GothamBold
ListLabel.TextSize = 10
ListLabel.TextXAlignment = Enum.TextXAlignment.Left
ListLabel.Parent = MainFrame

-- Saved Songs Scroll List Frame
local SavedSongsScroll = Instance.new("ScrollingFrame")
SavedSongsScroll.Size = UDim2.new(0.92, 0, 0, 140)
SavedSongsScroll.Position = UDim2.new(0.04, 0, 0.52, 0)
SavedSongsScroll.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
SavedSongsScroll.BorderSizePixel = 0
SavedSongsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SavedSongsScroll.ScrollBarThickness = 4
SavedSongsScroll.Parent = MainFrame

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 6)
ScrollCorner.Parent = SavedSongsScroll

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Padding = UDim.new(0, 4)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = SavedSongsScroll

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0.93, 0)
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

-- Sound Setup (Looped = true Enabled permanently)
local currentSound = Instance.new("Sound")
currentSound.Name = "TimebombCustomSound"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = workspace

local isAutoActive = false
local isNoclipActive = false
local savedSongsList = {}

-- Function to play song
local function playSongById(id)
    if id then
        currentSound.SoundId = "rbxassetid://" .. tostring(id)
        currentSound:Play()
        StatusLabel.Text = "Status: Playing ID " .. tostring(id) .. " 🎵"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
    end
end

-- Refresh Saved Songs List UI
local function refreshSavedSongsUI()
    for _, child in pairs(SavedSongsScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local ySize = 0
    for index, songData in ipairs(savedSongsList) do
        ySize = ySize + 32
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Size = UDim2.new(0.98, 0, 0, 28)
        ItemFrame.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        ItemFrame.Parent = SavedSongsScroll
        
        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 4)
        ItemCorner.Parent = ItemFrame
        
        local SongText = Instance.new("TextLabel")
        SongText.Size = UDim2.new(0.65, 0, 1, 0)
        SongText.Position = UDim2.new(0.03, 0, 0, 0)
        SongText.Text = songData.Name .. " (" .. songData.Id .. ")"
        SongText.TextColor3 = Color3.fromRGB(220, 220, 230)
        SongText.BackgroundTransparency = 1
        SongText.Font = Enum.Font.Gotham
        SongText.TextSize = 9
        SongText.TextXAlignment = Enum.TextXAlignment.Left
        SongText.Parent = ItemFrame
        
        local PlayItemBtn = Instance.new("TextButton")
        PlayItemBtn.Size = UDim2.new(0.13, 0, 0.8, 0)
        PlayItemBtn.Position = UDim2.new(0.69, 0, 0.1, 0)
        PlayItemBtn.Text = "▶️"
        PlayItemBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
        PlayItemBtn.TextSize = 9
        PlayItemBtn.Parent = ItemFrame
        
        local ItemPlayCorner = Instance.new("UICorner")
        ItemPlayCorner.CornerRadius = UDim.new(0, 4)
        ItemPlayCorner.Parent = PlayItemBtn
        
        local DelItemBtn = Instance.new("TextButton")
        DelItemBtn.Size = UDim2.new(0.13, 0, 0.8, 0)
        DelItemBtn.Position = UDim2.new(0.84, 0, 0.1, 0)
        DelItemBtn.Text = "🗑️"
        DelItemBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        DelItemBtn.TextSize = 9
        DelItemBtn.Parent = ItemFrame
        
        local ItemDelCorner = Instance.new("UICorner")
        ItemDelCorner.CornerRadius = UDim.new(0, 4)
        ItemDelCorner.Parent = DelItemBtn
        
        PlayItemBtn.MouseButton1Click:Connect(function()
            playSongById(songData.Id)
        end)
        
        DelItemBtn.MouseButton1Click:Connect(function()
            table.remove(savedSongsList, index)
            refreshSavedSongsUI()
        end)
    end
    SavedSongsScroll.CanvasSize = UDim2.new(0, 0, 0, ySize)
end

-- Play Direct Input
PlayMusicBtn.MouseButton1Click:Connect(function()
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then
        playSongById(soundId)
    else
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "ID غير صحيح!"
    end
end)

-- Save Input Song
SaveMusicBtn.MouseButton1Click:Connect(function()
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then
        table.insert(savedSongsList, {Name = "Song " .. tostring(#savedSongsList + 1), Id = soundId})
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "تم الحفظ!"
        refreshSavedSongsUI()
    end
end)

-- Stop Music
StopMusicBtn.MouseButton1Click:Connect(function()
    currentSound:Stop()
    StatusLabel.Text = "Status: Music Stopped ⏹️"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
end)

-- GUI Toggle
ToggleCircle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Close GUI
CloseBtn.MouseButton1Click:Connect(function()
    isAutoActive = false
    isNoclipActive = false
    currentSound:Destroy()
    
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
    ScreenGui:Destroy()
end)

-- Auto Pass Toggle
AutoBtn.MouseButton1Click:Connect(function()
    isAutoActive = not isAutoActive
    if isAutoActive then
        AutoBtn.Text = "Auto Play: ON"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    else
        AutoBtn.Text = "Auto Play: OFF"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    end
end)

-- Noclip Toggle
NoclipBtn.MouseButton1Click:Connect(function()
    isNoclipActive = not isNoclipActive
    if isNoclipActive then
        NoclipBtn.Text = "Noclip: ON 👻"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 210)
    else
        NoclipBtn.Text = "Noclip: OFF 👻"
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
        
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end)

-- Bomb Check
local function holdsBomb()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    
    local inChar = myChar:FindFirstChild("Bomb") or myChar:FindFirstChildWhichIsA("Tool")
    if inChar and string.find(string.lower(inChar.Name), "bomb") then return true end
    
    local inBackpack = LocalPlayer.Backpack:FindFirstChild("Bomb") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if inBackpack and string.find(string.lower(inBackpack.Name), "bomb") then return true end
    
    return false
end

-- Target Check
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

-- Main Stepped Loop
RunService.Stepped:Connect(function()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or not myChar:FindFirstChild("HumanoidRootPart") then return end
    
    -- Noclip Execution
    if isNoclipActive then
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    -- Auto Pass Execution
    if isAutoActive and holdsBomb() then
        local targetPlayer = getArenaTarget()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            myChar.Humanoid:MoveTo(targetPlayer.Character.HumanoidRootPart.Position)
        end
    end
end)
