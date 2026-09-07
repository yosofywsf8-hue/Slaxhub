-- Slax Hub - Orion Library Edition
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

-- Create Main Window
local Window = OrionLib:MakeWindow({
    Name = "Slax Hub | Timebomb Duels",
    HidePremium = true,
    SaveConfig = false,
    ConfigFolder = "SlaxHubConfig",
    IntroEnabled = true,
    IntroText = "Slax Hub Loaded!"
})

-- Apply Custom Image Background
task.spawn(function()
    local gui = LocalPlayer.PlayerGui:WaitForChild("Orion", 5)
    if gui and gui:FindFirstChild("Main") then
        local mainFrame = gui.Main
        local bgImage = Instance.new("ImageLabel")
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.Image = "rbxassetid://108512464651627"
        bgImage.ScaleType = Enum.ScaleType.Crop
        bgImage.ImageTransparency = 0.35
        bgImage.ZIndex = 0
        bgImage.Parent = mainFrame
    end
end)

-- Global State Variables
local isAutoActive = false
local isNoclipActive = false

-- Local Sound Setup
local currentSound = Instance.new("Sound")
currentSound.Name = "SlaxLocalSound"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = SoundService

local savedSongsList = {
    {Name = "Song 1", Id = 102710215948261, Loud = false},
    {Name = "Song 2", Id = 86503267790406, Loud = false},
    {Name = "Song 3", Id = 111018848542448, Loud = true}
}

local currentInputId = ""

---------------------------------------------------------
-- TAB 1: MAIN AUTOMATION
---------------------------------------------------------
local MainTab = Window:MakeTab({
    Name = "⚡ Main Features",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MainTab:AddToggle({
    Name = "Auto Play (Bomb Chase)",
    Default = false,
    Callback = function(Value)
        isAutoActive = Value
    end    
})

MainTab:AddToggle({
    Name = "Noclip 👻",
    Default = false,
    Callback = function(Value)
        isNoclipActive = Value
        if not Value and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end    
})

MainTab:AddParagraph("Credits", "Made by aki | TT: 1x.ud | DC: oa2a")

---------------------------------------------------------
-- TAB 2: MUSIC PLAYER SYSTEM
---------------------------------------------------------
local MusicTab = Window:MakeTab({
    Name = "🎵 Music Player",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MusicTab:AddTextbox({
    Name = "Song ID",
    Default = "",
    TextDisappear = false,
    Callback = function(Value)
        currentInputId = Value
    end
})

MusicTab:AddButton({
    Name = "▶️ Play Entered Song",
    Callback = function()
        local soundId = tonumber(currentInputId:match("%d+"))
        if soundId then
            currentSound.SoundId = "rbxassetid://" .. tostring(soundId)
            currentSound:Play()
            OrionLib:MakeNotification({Name = "Music Player", Content = "Playing ID: " .. soundId, Time = 3})
        else
            OrionLib:MakeNotification({Name = "Error", Content = "ID غير صحيح!", Time = 3})
        end
    end
})

MusicTab:AddButton({
    Name = "⏹️ Stop Music",
    Callback = function()
        currentSound:Stop()
        OrionLib:MakeNotification({Name = "Music Player", Content = "Stopped!", Time = 2})
    end
})

MusicTab:AddButton({
    Name = "💾 Save Current Song",
    Callback = function()
        if #savedSongsList >= 5 then
            OrionLib:MakeNotification({Name = "Warning", Content = "⚠️ وصلت الحد الأقصى! (5 أغاني فقط)", Time = 4})
            return
        end
        local soundId = tonumber(currentInputId:match("%d+"))
        if soundId then
            table.insert(savedSongsList, {Name = "Song " .. tostring(#savedSongsList + 1), Id = soundId, Loud = false})
            OrionLib:MakeNotification({Name = "Success", Content = "تم حفظ الأغنية بنجاح!", Time = 3})
        end
    end
})

local SongsSection = MusicTab:AddSection({ Name = "📁 Saved Songs List (Max 5)" })

for _, song in ipairs(savedSongsList) do
    local title = song.Name .. (song.Loud and " [⚠️عالية]" or "")
    SongsSection:AddButton({
        Name = title,
        Callback = function()
            currentSound.SoundId = "rbxassetid://" .. tostring(song.Id)
            currentSound:Play()
            OrionLib:MakeNotification({Name = "Playing", Content = "Now playing: " .. song.Name, Time = 3})
        end
    })
end

---------------------------------------------------------
-- CORE UTILITY LOOPS
---------------------------------------------------------
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

OrionLib:Init()
