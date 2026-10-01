-- ================================================================
-- Slax Hub | Timebomb Duels — Full Build
-- Nyx Edition | AutoPlay + Noclip + Bloxstrap Boost + Cosmetics + Music
-- ================================================================

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local SoundService= game:GetService("SoundService")
local Lighting    = game:GetService("Lighting")
local Workspace   = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ============ Cleanup ============
if LocalPlayer.PlayerGui:FindFirstChild("SlaxHubPremium") then
    LocalPlayer.PlayerGui.SlaxHubPremium:Destroy()
end

-- ============ ScreenGui ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubPremium"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- ============ Toggle Button ============
local ToggleButton = Instance.new("ImageButton")
ToggleButton.Size = UDim2.new(0, 55, 0, 55)
ToggleButton.Position = UDim2.new(0.02, 0, 0.2, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ToggleButton.BorderSizePixel = 0
ToggleButton.Active = true
ToggleButton.Draggable = true
ToggleButton.ScaleType = Enum.ScaleType.Crop
ToggleButton.Image = "rbxthumb://type=Asset&id=124643845022233&w=420&h=420"
ToggleButton.Parent = ScreenGui

Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 10)
local SquareStroke = Instance.new("UIStroke")
SquareStroke.Color = Color3.fromRGB(255, 30, 30)
SquareStroke.Thickness = 2
SquareStroke.Parent = ToggleButton

-- ============ Main Window ============
local MainFrame = Instance.new("ImageLabel")
MainFrame.Size = UDim2.new(0, 310, 0, 520)
MainFrame.Position = UDim2.new(0.2, 0, 0.1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Image = "rbxthumb://type=Asset&id=108512464651627&w=420&h=420"
MainFrame.ScaleType = Enum.ScaleType.Crop
MainFrame.ImageTransparency = 0.15
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 40, 40)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
Overlay.BackgroundTransparency = 0.35
Overlay.BorderSizePixel = 0
Overlay.Parent = MainFrame
Instance.new("UICorner", Overlay).CornerRadius = UDim.new(0, 10)

-- ============ Header ============
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
CloseBtn.Text = "X"
CloseBtn.TextSize = 9
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

-- ============ Scroll Container ============
local ScrollContainer = Instance.new("ScrollingFrame")
ScrollContainer.Size = UDim2.new(0.92, 0, 0.88, 0)
ScrollContainer.Position = UDim2.new(0.04, 0, 0.09, 0)
ScrollContainer.BackgroundTransparency = 1
ScrollContainer.BorderSizePixel = 0
ScrollContainer.ScrollBarThickness = 3
ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 600)
ScrollContainer.Parent = MainFrame

local MainLayout = Instance.new("UIListLayout")
MainLayout.Padding = UDim.new(0, 8)
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.Parent = ScrollContainer

-- ============ Helper: make button ============
local function makeButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.Text = text
    btn.BackgroundColor3 = color or Color3.fromRGB(40, 45, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = ScrollContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- ============ 1) Auto Play ============
local AutoBtn = makeButton("Auto Play: OFF", Color3.fromRGB(220, 53, 69))

-- ============ 2) Noclip ============
local NoclipBtn = makeButton("Noclip: OFF")

-- ============ 3) Bloxstrap Boost ============
local BloxstrapBtn = makeButton("Bloxstrap Boost: OFF")

-- ============ 4) Fake Korblox ============
local KorbloxBtn = makeButton("Fake Korblox: OFF")

-- ============ 5) Fake Headless ============
local HeadlessBtn = makeButton("Fake Headless: OFF")

-- ============ 6) Music Controls ============
local MusicControlsFrame = Instance.new("Frame")
MusicControlsFrame.Size = UDim2.new(1, 0, 0, 32)
MusicControlsFrame.BackgroundTransparency = 1
MusicControlsFrame.Parent = ScrollContainer

local MusicBox = Instance.new("TextBox")
MusicBox.Size = UDim2.new(0.52, 0, 1, 0)
MusicBox.PlaceholderText = "🎵 حط ID الاغنية هنا"
MusicBox.Text = ""
MusicBox.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
MusicBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicBox.PlaceholderColor3 = Color3.fromRGB(140, 150, 170)
MusicBox.Font = Enum.Font.Gotham
MusicBox.TextSize = 9
MusicBox.Parent = MusicControlsFrame
Instance.new("UICorner", MusicBox).CornerRadius = UDim.new(0, 6)

local PlayMusicBtn = Instance.new("TextButton")
PlayMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
PlayMusicBtn.Position = UDim2.new(0.55, 0, 0, 0)
PlayMusicBtn.Text = "▶️"
PlayMusicBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
PlayMusicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayMusicBtn.TextSize = 10
PlayMusicBtn.Font = Enum.Font.GothamBold
PlayMusicBtn.Parent = MusicControlsFrame
Instance.new("UICorner", PlayMusicBtn).CornerRadius = UDim.new(0, 6)

local StopMusicBtn = Instance.new("TextButton")
StopMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
StopMusicBtn.Position = UDim2.new(0.70, 0, 0, 0)
StopMusicBtn.Text = "⏹️"
StopMusicBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
StopMusicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopMusicBtn.TextSize = 10
StopMusicBtn.Font = Enum.Font.GothamBold
StopMusicBtn.Parent = MusicControlsFrame
Instance.new("UICorner", StopMusicBtn).CornerRadius = UDim.new(0, 6)

local SaveMusicBtn = Instance.new("TextButton")
SaveMusicBtn.Size = UDim2.new(0.14, 0, 1, 0)
SaveMusicBtn.Position = UDim2.new(0.85, 0, 0, 0)
SaveMusicBtn.Text = "💾"
SaveMusicBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
SaveMusicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveMusicBtn.TextSize = 10
SaveMusicBtn.Font = Enum.Font.GothamBold
SaveMusicBtn.Parent = MusicControlsFrame
Instance.new("UICorner", SaveMusicBtn).CornerRadius = UDim.new(0, 6)

-- ============ 7) Saved Songs ============
local SavedSongsScroll = Instance.new("Frame")
SavedSongsScroll.Size = UDim2.new(1, 0, 0, 140)
SavedSongsScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
SavedSongsScroll.BackgroundTransparency = 0.2
SavedSongsScroll.Parent = ScrollContainer
Instance.new("UICorner", SavedSongsScroll).CornerRadius = UDim.new(0, 6)

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, 0, 1, 0)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.Parent = SavedSongsScroll

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Padding = UDim.new(0, 4)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = ScrollList

-- ============ 8) Status ============
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Text = "Status: Ready 🎧"
StatusLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 9
StatusLabel.Parent = ScrollContainer

-- ============ 9) Credits ============
local CreditsLabel = Instance.new("TextLabel")
CreditsLabel.Size = UDim2.new(1, 0, 0, 20)
CreditsLabel.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
CreditsLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
CreditsLabel.BackgroundTransparency = 1
CreditsLabel.Font = Enum.Font.Gotham
CreditsLabel.TextSize = 8
CreditsLabel.Parent = ScrollContainer

-- ================================================================
-- CORE STATE
-- ================================================================
local isAutoActive      = false
local isNoclipActive    = false
local isBloxstrapActive = false
local isKorbloxActive   = false
local isHeadlessActive  = false

-- ================================================================
-- MUSIC SYSTEM
-- ================================================================
local currentSound = Instance.new("Sound")
currentSound.Name = "SlaxLocalSound"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = SoundService

local savedSongsList = {
    {Name = "Song 1 🎶", Id = 102710215948261, Loud = false},
    {Name = "Song 2 🎶", Id = 86503267790406,  Loud = false},
    {Name = "Song 3 🔊", Id = 111018848542448, Loud = true},
}

local function playSongById(id)
    if id then
        currentSound.SoundId = "rbxassetid://" .. tostring(id)
        currentSound:Play()
        StatusLabel.Text = "Status: Playing ID " .. tostring(id) .. " ▶️"
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
        Instance.new("UICorner", ItemFrame).CornerRadius = UDim.new(0, 4)

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
            WarnBadge.Text = "LOUD ⚠️"
            WarnBadge.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
            WarnBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
            WarnBadge.Font = Enum.Font.GothamBold
            WarnBadge.TextSize = 7
            WarnBadge.Parent = ItemFrame
            Instance.new("UICorner", WarnBadge).CornerRadius = UDim.new(0, 4)
        end

        local PlayItemBtn = Instance.new("TextButton")
        PlayItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        PlayItemBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
        PlayItemBtn.Text = "▶️"
        PlayItemBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
        PlayItemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        PlayItemBtn.TextSize = 7
        PlayItemBtn.Font = Enum.Font.GothamBold
        PlayItemBtn.Parent = ItemFrame
        Instance.new("UICorner", PlayItemBtn).CornerRadius = UDim.new(0, 4)

        local StopItemBtn = Instance.new("TextButton")
        StopItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        StopItemBtn.Position = UDim2.new(0.74, 0, 0.1, 0)
        StopItemBtn.Text = "⏹️"
        StopItemBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        StopItemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        StopItemBtn.TextSize = 7
        StopItemBtn.Font = Enum.Font.GothamBold
        StopItemBtn.Parent = ItemFrame
        Instance.new("UICorner", StopItemBtn).CornerRadius = UDim.new(0, 4)

        local DelItemBtn = Instance.new("TextButton")
        DelItemBtn.Size = UDim2.new(0.11, 0, 0.8, 0)
        DelItemBtn.Position = UDim2.new(0.86, 0, 0.1, 0)
        DelItemBtn.Text = "🗑️"
        DelItemBtn.BackgroundColor3 = Color3.fromRGB(80, 85, 100)
        DelItemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DelItemBtn.TextSize = 7
        DelItemBtn.Font = Enum.Font.GothamBold
        DelItemBtn.Parent = ItemFrame
        Instance.new("UICorner", DelItemBtn).CornerRadius = UDim.new(0, 4)

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
    if soundId then playSongById(soundId)
    else MusicBox.Text = ""; MusicBox.PlaceholderText = "ID غير صحيح! ❌" end
end)

StopMusicBtn.MouseButton1Click:Connect(stopSong)

SaveMusicBtn.MouseButton1Click:Connect(function()
    if #savedSongsList >= 5 then
        StatusLabel.Text = "وصلت الحد الأقصى (5 أغاني) ⚠️"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        return
    end
    local soundId = tonumber(MusicBox.Text:match("%d+"))
    if soundId then
        table.insert(savedSongsList, {
            Name = "Song " .. tostring(#savedSongsList + 1) .. " 🎶",
            Id = soundId, Loud = false
        })
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "تم الحفظ بنجاح! ✅"
        refreshSavedSongsUI()
    end
end)

-- ================================================================
-- COSMETICS — Korblox & Headless
-- ================================================================
local originalProps = {}

local function saveProp(inst, prop)
    if not originalProps[inst] then originalProps[inst] = {} end
    if originalProps[inst][prop] == nil then
        originalProps[inst][prop] = inst[prop]
    end
end

local function restoreAll()
    for inst, props in pairs(originalProps) do
        if inst and inst.Parent then
            for prop, val in pairs(props) do
                pcall(function() inst[prop] = val end)
            end
        end
    end
    originalProps = {}
end

-- -------- Fake Korblox --------
local function applyKorblox(state)
    local char = LocalPlayer.Character
    if not char then return end

    local names = { "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }

    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if state then
                saveProp(part, "Transparency")
                saveProp(part, "LocalTransparencyModifier")
                saveProp(part, "Size")
                saveProp(part, "CanCollide")
                part.Transparency = 1
                part.LocalTransparencyModifier = 1
                part.Size = Vector3.new(0.01, 0.01, 0.01)
                part.CanCollide = false
            else
                if originalProps[part] then
                    part.Transparency = originalProps[part].Transparency or 0
                    part.LocalTransparencyModifier = originalProps[part].LocalTransparencyModifier or 0
                    part.Size = originalProps[part].Size or Vector3.new(1, 2, 1)
                    part.CanCollide = originalProps[part].CanCollide ~= false
                end
            end
        end
    end

    -- اخفاء accessories المرتبطة بالساق اليمنى
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Accoutrement") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                for _, name in ipairs(names) do
                    if handle:FindFirstChild(name .. "RigAttachment") then
                        if state then
                            saveProp(handle, "LocalTransparencyModifier")
                            handle.LocalTransparencyModifier = 1
                        elseif originalProps[handle] then
                            handle.LocalTransparencyModifier = originalProps[handle].LocalTransparencyModifier or 0
                        end
                    end
                end
            end
        end
    end
end

-- -------- Fake Headless --------
local function applyHeadless(state)
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if state then
        saveProp(head, "Transparency")
        saveProp(head, "LocalTransparencyModifier")
        head.Transparency = 1
        head.LocalTransparencyModifier = 1
    else
        if originalProps[head] then
            head.Transparency = originalProps[head].Transparency or 0
            head.LocalTransparencyModifier = originalProps[head].LocalTransparencyModifier or 0
        else
            head.Transparency = 0
            head.LocalTransparencyModifier = 0
        end
    end

    for _, child in ipairs(head:GetChildren()) do
        if child:IsA("Decal") or child:IsA("Texture") then
            if state then
                saveProp(child, "Transparency")
                child.Transparency = 1
            elseif originalProps[child] then
                child.Transparency = originalProps[child].Transparency or 0
            end
        end
        if child:IsA("SpecialMesh") then
            if state then
                saveProp(child, "Scale")
                child.Scale = Vector3.new(0.01, 0.01, 0.01)
            elseif originalProps[child] then
                child.Scale = originalProps[child].Scale or Vector3.new(1, 1, 1)
            end
        end
    end

    -- Accessories على الراس
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Accoutrement") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                local isOnHead = false
                for _, att in ipairs(handle:GetChildren()) do
                    if att:IsA("Attachment") and att.Name:find("Head") then
                        isOnHead = true
                        break
                    end
                end
                if isOnHead then
                    if state then
                        saveProp(handle, "LocalTransparencyModifier")
                        handle.LocalTransparencyModifier = 1
                    elseif originalProps[handle] then
                        handle.LocalTransparencyModifier = originalProps[handle].LocalTransparencyModifier or 0
                    end
                end
            end
        end
    end
end

-- refresh بعد respawn
local function refreshCosmetics()
    if isKorbloxActive  then applyKorblox(true)  end
    if isHeadlessActive then applyHeadless(true) end
end

-- ================================================================
-- UI EVENTS
-- ================================================================
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

CloseBtn.MouseButton1Click:Connect(function()
    isAutoActive = false
    isNoclipActive = false
    isBloxstrapActive = false
    isKorbloxActive = false
    isHeadlessActive = false
    currentSound:Destroy()
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
    ScreenGui:Destroy()
end)

-- ---- Auto Play ----
AutoBtn.MouseButton1Click:Connect(function()
    isAutoActive = not isAutoActive
    AutoBtn.Text = isAutoActive and "Auto Play: ON" or "Auto Play: OFF"
    AutoBtn.BackgroundColor3 = isAutoActive and Color3.fromRGB(40, 167, 69)
                                           or Color3.fromRGB(220, 53, 69)
end)

-- ---- Noclip ----
NoclipBtn.MouseButton1Click:Connect(function()
    isNoclipActive = not isNoclipActive
    NoclipBtn.Text = isNoclipActive and "Noclip: ON" or "Noclip: OFF"
    NoclipBtn.BackgroundColor3 = isNoclipActive and Color3.fromRGB(140, 50, 210)
                                             or Color3.fromRGB(40, 45, 60)
    -- نرجع CanCollide لو طفناه
    if not isNoclipActive and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end)

-- ---- Bloxstrap Boost ----
BloxstrapBtn.MouseButton1Click:Connect(function()
    isBloxstrapActive = not isBloxstrapActive
    BloxstrapBtn.Text = isBloxstrapActive and "Bloxstrap Boost: ON" or "Bloxstrap Boost: OFF"
    BloxstrapBtn.BackgroundColor3 = isBloxstrapActive and Color3.fromRGB(0, 150, 255)
                                                 or Color3.fromRGB(40, 45, 60)

    if isBloxstrapActive then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.Brightness = 2
            Lighting.FogEnd = 100000
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Sky") or v:IsA("Atmosphere") then
                    v.Enabled = false
                end
            end
        end)
        StatusLabel.Text = "Status: Bloxstrap Boost Enabled"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end)
        StatusLabel.Text = "Status: Boost Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

-- ---- Fake Korblox ----
KorbloxBtn.MouseButton1Click:Connect(function()
    isKorbloxActive = not isKorbloxActive
    KorbloxBtn.Text = isKorbloxActive and "Fake Korblox: ON" or "Fake Korblox: OFF"
    KorbloxBtn.BackgroundColor3 = isKorbloxActive and Color3.fromRGB(255, 140, 0)
                                              or Color3.fromRGB(40, 45, 60)
    applyKorblox(isKorbloxActive)
end)

-- ---- Fake Headless ----
HeadlessBtn.MouseButton1Click:Connect(function()
    isHeadlessActive = not isHeadlessActive
    HeadlessBtn.Text = isHeadlessActive and "Fake Headless: ON" or "Fake Headless: OFF"
    HeadlessBtn.BackgroundColor3 = isHeadlessActive and Color3.fromRGB(150, 0, 255)
                                               or Color3.fromRGB(40, 45, 60)
    applyHeadless(isHeadlessActive)
end)

-- ================================================================
-- CORE LOGIC — Bomb detection + AutoPlay
-- ================================================================
local function holdsBomb()
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    -- فحص 1: في الكاركتر
    for _, obj in ipairs(myChar:GetChildren()) do
        local n = obj.Name:lower()
        if obj:IsA("Tool") and (n:find("bomb") or n:find("c4") or n:find("tnt") or n:find("device")) then
            return true
        end
    end
    -- فحص 2: في الباكباك
    for _, obj in ipairs(LocalPlayer.Backpack:GetChildren()) do
        local n = obj.Name:lower()
        if obj:IsA("Tool") and (n:find("bomb") or n:find("c4") or n:find("tnt") or n:find("device")) then
            return true
        end
    end
    -- فحص 3: Attributes
    for _, attr in ipairs(LocalPlayer:GetAttributes()) do
        local a = attr:lower()
        if (a:find("bomb") or a:find("carrier") or a:find("has"))
           and LocalPlayer:GetAttribute(attr) == true then
            return true
        end
    end
    -- فحص 4: Tags
    if LocalPlayer:HasTag("HasBomb") or LocalPlayer:HasTag("Bomb") then return true end
    if myChar:HasTag("HasBomb") or myChar:HasTag("Bomb") then return true end
    return false
end

local function getNearestTarget()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local nearest, shortestDist = nil, math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
           and player.Character
           and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (myPos - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < 150 and dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- ================================================================
-- MAIN LOOP
-- ================================================================
RunService.Stepped:Connect(function()
    local myChar = LocalPlayer.Character
    if not myChar
       or not myChar:FindFirstChild("Humanoid")
       or not myChar:FindFirstChild("HumanoidRootPart") then return end

    -- ---- Noclip ----
    if isNoclipActive then
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- ---- AutoPlay ----
    if isAutoActive and holdsBomb() then
        local target = getNearestTarget()
        if target
           and target.Character
           and target.Character:FindFirstChild("HumanoidRootPart") then
            myChar.Humanoid:MoveTo(target.Character.HumanoidRootPart.Position)
        end
    end
end)

-- ================================================================
-- RESPAWN HANDLER
-- ================================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    refreshCosmetics()
end)

-- ================================================================
-- INIT
-- ================================================================
print("[Nyx] Slax Hub Full Build loaded ❤️")
