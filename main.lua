-- ================================================================
-- Slax Hub | Timebomb Duels — Full Build v3
-- Nyx Edition | AutoPlay + Noclip + FFlag Boost + Cosmetics + Music
-- + Parry/Dodge + Auto-Swing + Infinite Jump + ESP + HUD + Anti-AFK
-- ================================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting     = game:GetService("Lighting")
local Workspace    = game:GetService("Workspace")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local LocalPlayer  = Players.LocalPlayer

-- ============ Cleanup ============
for _, name in ipairs({"SlaxHubPremium", "SlaxHubToggle", "SlaxHubHUD", "SlaxHubESP"}) do
    local old = LocalPlayer.PlayerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ================================================================
-- WIND-STYLE UI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHubPremium"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ---- Toggle Button ----
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
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 14)
local SquareStroke = Instance.new("UIStroke")
SquareStroke.Color = Color3.fromRGB(255, 30, 30)
SquareStroke.Thickness = 2
SquareStroke.Parent = ToggleButton

-- ---- Main Window ----
local MainFrame = Instance.new("ImageLabel")
MainFrame.Size = UDim2.new(0, 340, 0, 560)
MainFrame.Position = UDim2.new(0.2, 0, 0.05, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Image = "rbxthumb://type=Asset&id=108512464651627&w=420&h=420"
MainFrame.ScaleType = Enum.ScaleType.Crop
MainFrame.ImageTransparency = 0.25
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 40, 40)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

local BlurOverlay = Instance.new("Frame")
BlurOverlay.Size = UDim2.new(1, 0, 1, 0)
BlurOverlay.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
BlurOverlay.BackgroundTransparency = 0.3
BlurOverlay.BorderSizePixel = 0
BlurOverlay.Parent = MainFrame
Instance.new("UICorner", BlurOverlay).CornerRadius = UDim.new(0, 14)

-- ---- Header ----
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
Header.BackgroundTransparency = 0.2
Header.BorderSizePixel = 0
Header.Parent = MainFrame
local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header
local HeaderHide = Instance.new("Frame")
HeaderHide.Size = UDim2.new(1, 0, 0.5, 0)
HeaderHide.Position = UDim2.new(0, 0, 0.5, 0)
HeaderHide.BackgroundColor3 = Header.BackgroundColor3
HeaderHide.BackgroundTransparency = Header.BackgroundTransparency
HeaderHide.BorderSizePixel = 0
HeaderHide.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.04, 0, 0, 0)
Title.Text = "Slax Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0.7, 0, 1, 0)
SubTitle.Position = UDim2.new(0.04, 0, 0, 14)
SubTitle.Text = "Timebomb Duels · Nyx Edition"
SubTitle.TextColor3 = Color3.fromRGB(180, 180, 200)
SubTitle.BackgroundTransparency = 1
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 9
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -12)
CloseBtn.Text = "✕"
CloseBtn.TextSize = 12
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- ---- Tabs ----
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Parent = TabBar

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 4)
TabPadding.PaddingTop = UDim.new(0, 4)
TabPadding.Parent = TabBar

local Pages = {}
local TabButtons = {}

local function makeTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 68, 0, 22)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
    btn.BackgroundTransparency = 0.3
    btn.TextColor3 = Color3.fromRGB(180, 180, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -16, 1, -88)
    page.Position = UDim2.new(0, 8, 0, 84)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    page.CanvasSize = UDim2.new(0, 0, 0, 400)
    page.Visible = false
    page.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    TabButtons[order] = btn
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
            b.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    return page
end

local function makeSection(parent, title)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 22)
    section.BackgroundTransparency = 1
    section.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.Text = title
    label.TextColor3 = Color3.fromRGB(255, 100, 100)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section
    return section
end

local function makeButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
    btn.BackgroundTransparency = 0.15
    btn.TextColor3 = Color3.fromRGB(230, 230, 240)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 65, 80)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = btn
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return btn
end

-- ================================================================
-- STATE + HELPERS
-- ================================================================
local state = {
    AutoPlay = false,
    Noclip = false,
    Bloxstrap = false,
    Korblox = false,
    Headless = false,
    Parry = false,
    AutoSwing = false,
    InfiniteJump = false,
    ESP = false,
    HUD = false,
    AntiAFK = false,
}

local originalProps = {}

local function saveProp(inst, prop)
    if not originalProps[inst] then originalProps[inst] = {} end
    if originalProps[inst][prop] == nil then
        originalProps[inst][prop] = inst[prop]
    end
end

local function getChar() return LocalPlayer.Character end
local function getHRP(plr)
    plr = plr or LocalPlayer
    if plr.Character then return plr.Character:FindFirstChild("HumanoidRootPart") end
end
local function getHum(plr)
    plr = plr or LocalPlayer
    if plr.Character then return plr.Character:FindFirstChildOfClass("Humanoid") end
end

local function hasBomb()
    local char = getChar()
    if not char then return false end
    for _, obj in ipairs(char:GetChildren()) do
        local n = obj.Name:lower()
        if obj:IsA("Tool") and (n:find("bomb") or n:find("c4") or n:find("tnt") or n:find("device")) then
            return true
        end
    end
    for _, obj in ipairs(LocalPlayer.Backpack:GetChildren()) do
        local n = obj.Name:lower()
        if obj:IsA("Tool") and (n:find("bomb") or n:find("c4") or n:find("tnt") or n:find("device")) then
            return true
        end
    end
    for _, attr in ipairs(LocalPlayer:GetAttributes()) do
        local a = attr:lower()
        if (a:find("bomb") or a:find("carrier") or a:find("has"))
           and LocalPlayer:GetAttribute(attr) == true then
            return true
        end
    end
    if LocalPlayer:HasTag("HasBomb") or LocalPlayer:HasTag("Bomb") then return true end
    if char:HasTag("HasBomb") or char:HasTag("Bomb") then return true end
    return false
end

local function getNearestTarget(maxDist)
    maxDist = maxDist or 150
    local myHRP = getHRP()
    if not myHRP then return nil, nil end
    local nearest, shortestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hum, hrp = getHum(plr), getHRP(plr)
            if hum and hrp and hum.Health > 0 then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < maxDist and d < shortestDist then
                    shortestDist = d
                    nearest = plr
                end
            end
        end
    end
    return nearest, shortestDist
end

local function jitter(v)
    return v + Vector3.new(
        (math.random() - 0.5) * 0.05, 0,
        (math.random() - 0.5) * 0.05
    )
end

-- ================================================================
-- COSMETICS
-- ================================================================
local function applyKorblox(on)
    local char = getChar()
    if not char then return end
    local candidates = {"Right Leg", "RightLeg", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
    local found = {}
    for _, name in ipairs(candidates) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then table.insert(found, part) end
    end
    if #found == 0 then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("BasePart") then
                for _, att in ipairs(obj:GetChildren()) do
                    if att:IsA("Attachment")
                       and (att.Name:find("RightHip") or att.Name:find("Right Leg")) then
                        table.insert(found, obj)
                        break
                    end
                end
            end
        end
    end
    for _, part in ipairs(found) do
        if on then
            saveProp(part, "Transparency")
            saveProp(part, "LocalTransparencyModifier")
            saveProp(part, "CanCollide")
            part.Transparency = 1
            part.LocalTransparencyModifier = 1
            part.CanCollide = false
        else
            if originalProps[part] then
                for prop, val in pairs(originalProps[part]) do
                    pcall(function() part[prop] = val end)
                end
            end
        end
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                if on then
                    saveProp(child, "Transparency")
                    child.Transparency = 1
                elseif originalProps[child] then
                    child.Transparency = originalProps[child].Transparency or 0
                end
            end
        end
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Accoutrement") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                for _, att in ipairs(handle:GetChildren()) do
                    if att:IsA("Attachment")
                       and (att.Name:find("RightHip") or att.Name:find("Right Leg")) then
                        if on then
                            saveProp(handle, "Transparency")
                            saveProp(handle, "LocalTransparencyModifier")
                            handle.Transparency = 1
                            handle.LocalTransparencyModifier = 1
                        elseif originalProps[handle] then
                            for prop, val in pairs(originalProps[handle]) do
                                pcall(function() handle[prop] = val end)
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end

local function applyHeadless(on)
    local char = getChar()
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if on then
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
            if on then
                saveProp(child, "Transparency")
                child.Transparency = 1
            elseif originalProps[child] then
                child.Transparency = originalProps[child].Transparency or 0
            end
        end
        if child:IsA("SpecialMesh") then
            if on then
                saveProp(child, "Scale")
                child.Scale = Vector3.new(0.01, 0.01, 0.01)
            elseif originalProps[child] then
                child.Scale = originalProps[child].Scale or Vector3.new(1, 1, 1)
            end
        end
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Accoutrement") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                for _, att in ipairs(handle:GetChildren()) do
                    if att:IsA("Attachment") and att.Name:find("Head") then
                        if on then
                            saveProp(handle, "Transparency")
                            saveProp(handle, "LocalTransparencyModifier")
                            handle.Transparency = 1
                            handle.LocalTransparencyModifier = 1
                        elseif originalProps[handle] then
                            for prop, val in pairs(originalProps[handle]) do
                                pcall(function() handle[prop] = val end)
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end

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
    end
end

local function stopSong()
    currentSound:Stop()
end

-- ================================================================
-- BLOXSTRAP FFLAG BOOST
-- ================================================================
local originalLighting = {
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
}
local originalQuality = nil
pcall(function() originalQuality = settings().Rendering.QualityLevel end)
local disabledEffects = {}

local function enableBoost()
    local fflags = {
        ["DFIntTaskSchedulerTargetFps"] = 240,
        ["DFIntTextureQualityOverride"] = 0,
        ["FIntRenderShadowIntensity"] = 0,
        ["FIntFRMMinGrassDistance"] = 0,
        ["FIntFRMMaxGrassDistance"] = 0,
        ["FIntFRMMinTerrainDistance"] = 0,
        ["FIntFRMMaxTerrainDistance"] = 0,
        ["FFlagDisablePostFx"] = "True",
        ["FFlagDisableBloom"] = "True",
        ["FFlagDisableDOF"] = "True",
        ["FFlagDisableSunRays"] = "True",
        ["FFlagDisableAtmosphere"] = "True",
        ["FFlagDisableMSAA"] = "True",
        ["FFlagDisableFXAA"] = "True",
        ["FFlagRenderFastClear"] = "True",
        ["FFlagOptimizeMotionBlur"] = "True",
    }
    for flag, value in pairs(fflags) do
        pcall(function() sethiddenproperty(game, flag, value) end)
        pcall(function() setfflag(flag, tostring(value)) end)
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Brightness = 2
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    end)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("PostEffect") and v.Enabled then
            disabledEffects[v] = true
            v.Enabled = false
        end
        if v:IsA("Sky") or v:IsA("Atmosphere") then
            pcall(function() v.Parent = nil end)
        end
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        if Workspace.StreamingEnabled then
            Workspace.StreamingTargetRadius = 256
        end
    end)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Fire")
           or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            pcall(function() obj.Enabled = false end)
        end
        if obj:IsA("Trail") or obj:IsA("Beam") then
            pcall(function() obj.Enabled = false end)
        end
        if obj:IsA("BasePart") then
            pcall(function() obj.CastShadow = false end)
        end
    end
    pcall(function() RunService:SetPhysicsThrottleEnabled(true) end)
end

local function disableBoost()
    pcall(function()
        for prop, val in pairs(originalLighting) do
            Lighting[prop] = val
        end
    end)
    if originalQuality then
        pcall(function() settings().Rendering.QualityLevel = originalQuality end)
    end
    for effect, _ in pairs(disabledEffects) do
        if effect and effect.Parent then
            pcall(function() effect.Enabled = true end)
        end
    end
    disabledEffects = {}
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CastShadow = true end)
        end
    end
    pcall(function() RunService:SetPhysicsThrottleEnabled(false) end)
end

-- ================================================================
-- ESP
-- ================================================================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "SlaxHubESP"
ESPFolder.Parent = Workspace

local function createESP(plr)
    if not plr.Character then return end
    local box = Instance.new("Highlight")
    box.Name = "SlaxESP_" .. plr.Name
    box.Adornee = plr.Character
    box.FillColor = Color3.fromRGB(255, 40, 40)
    box.OutlineColor = Color3.fromRGB(255, 255, 255)
    box.FillTransparency = 0.6
    box.OutlineTransparency = 0.2
    box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    box.Parent = ESPFolder

    local tag = Instance.new("BillboardGui")
    tag.Name = "SlaxTag_" .. plr.Name
    tag.Size = UDim2.new(0, 100, 0, 22)
    tag.StudsOffset = Vector3.new(0, 3, 0)
    tag.AlwaysOnTop = true
    tag.Adornee = plr.Character
    tag.Parent = ESPFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = plr.Name
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.3
    label.Parent = tag
end

local function refreshESP()
    for _, obj in ipairs(ESPFolder:GetChildren()) do obj:Destroy() end
    if state.ESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") then
                createESP(plr)
            end
        end
    end
end

-- ================================================================
-- HUD
-- ================================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "SlaxHubHUD"
hudGui.ResetOnSpawn = false
hudGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.new(0, 180, 0, 90)
hudFrame.Position = UDim2.new(1, -195, 0, 20)
hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
hudFrame.BackgroundTransparency = 0.3
hudFrame.BorderSizePixel = 0
hudFrame.Visible = false
hudFrame.Parent = hudGui
Instance.new("UICorner", hudFrame).CornerRadius = UDim.new(0, 10)
local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(255, 60, 60)
hudStroke.Thickness = 1
hudStroke.Transparency = 0.4
hudStroke.Parent = hudFrame

local hudLayout = Instance.new("UIListLayout")
hudLayout.Padding = UDim.new(0, 2)
hudLayout.Parent = hudFrame
local hudPad = Instance.new("UIPadding")
hudPad.PaddingTop = UDim.new(0, 6)
hudPad.PaddingLeft = UDim.new(0, 10)
hudPad.Parent = hudFrame

local function makeHudLine(txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 14)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(220, 220, 230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = hudFrame
    return l
end

local fpsLine  = makeHudLine("FPS: --")
local pingLine = makeHudLine("Ping: --")
local bombLine = makeHudLine("Bomb: --")
local timeLine = makeHudLine("Time: --")

-- ================================================================
-- BUILD UI PAGES
-- ================================================================
local mainPage   = makeTab("Main", 1)
local combatPage = makeTab("Combat", 2)
local visualPage = makeTab("Visual", 3)
local musicPage  = makeTab("Music", 4)
local miscPage   = makeTab("Misc", 5)

-- ========== MAIN ==========
makeSection(mainPage, "AutoPlay")
state.AutoPlayBtn = makeButton(mainPage, "Auto Play: OFF", function()
    state.AutoPlay = not state.AutoPlay
    state.AutoPlayBtn.Text = state.AutoPlay and "Auto Play: ON" or "Auto Play: OFF"
    state.AutoPlayBtn.BackgroundColor3 = state.AutoPlay and Color3.fromRGB(40, 167, 69)
                                                     or Color3.fromRGB(30, 34, 44)
end)

makeSection(mainPage, "Movement")
state.NoclipBtn = makeButton(mainPage, "Noclip: OFF", function()
    state.Noclip = not state.Noclip
    state.NoclipBtn.Text = state.Noclip and "Noclip: ON" or "Noclip: OFF"
    state.NoclipBtn.BackgroundColor3 = state.Noclip and Color3.fromRGB(140, 50, 210)
                                                 or Color3.fromRGB(30, 34, 44)
end)

state.InfJumpBtn = makeButton(mainPage, "Infinite Jump: OFF", function()
    state.InfiniteJump = not state.InfiniteJump
    state.InfJumpBtn.Text = state.InfiniteJump and "Infinite Jump: ON" or "Infinite Jump: OFF"
    state.InfJumpBtn.BackgroundColor3 = state.InfiniteJump and Color3.fromRGB(0, 150, 255)
                                                         or Color3.fromRGB(30, 34, 44)
end)

makeSection(mainPage, "Boost")
state.BoostBtn = makeButton(mainPage, "Bloxstrap Boost: OFF", function()
    state.Bloxstrap = not state.Bloxstrap
    state.BoostBtn.Text = state.Bloxstrap and "Bloxstrap Boost: ON" or "Bloxstrap Boost: OFF"
    state.BoostBtn.BackgroundColor3 = state.Bloxstrap and Color3.fromRGB(0, 150, 255)
                                                     or Color3.fromRGB(30, 34, 44)
    if state.Bloxstrap then enableBoost() else disableBoost() end
end)

-- ========== COMBAT ==========
makeSection(combatPage, "Defense")
state.ParryBtn = makeButton(combatPage, "Auto Parry: OFF", function()
    state.Parry = not state.Parry
    state.ParryBtn.Text = state.Parry and "Auto Parry: ON" or "Auto Parry: OFF"
    state.ParryBtn.BackgroundColor3 = state.Parry and Color3.fromRGB(40, 167, 69)
                                                 or Color3.fromRGB(30, 34, 44)
end)

makeSection(combatPage, "Offense")
state.SwingBtn = makeButton(combatPage, "Auto Swing: OFF", function()
    state.AutoSwing = not state.AutoSwing
    state.SwingBtn.Text = state.AutoSwing and "Auto Swing: ON" or "Auto Swing: OFF"
    state.SwingBtn.BackgroundColor3 = state.AutoSwing and Color3.fromRGB(220, 53, 69)
                                                    or Color3.fromRGB(30, 34, 44)
end)

-- ========== VISUAL ==========
makeSection(visualPage, "ESP")
state.ESPBtn = makeButton(visualPage, "Player ESP: OFF", function()
    state.ESP = not state.ESP
    state.ESPBtn.Text = state.ESP and "Player ESP: ON" or "Player ESP: OFF"
    state.ESPBtn.BackgroundColor3 = state.ESP and Color3.fromRGB(255, 140, 0)
                                            or Color3.fromRGB(30, 34, 44)
    refreshESP()
end)

makeSection(visualPage, "HUD")
state.HUDBtn = makeButton(visualPage, "HUD: OFF", function()
    state.HUD = not state.HUD
    state.HUDBtn.Text = state.HUD and "HUD: ON" or "HUD: OFF"
    state.HUDBtn.BackgroundColor3 = state.HUD and Color3.fromRGB(40, 167, 69)
                                             or Color3.fromRGB(30, 34, 44)
    hudFrame.Visible = state.HUD
end)

makeSection(visualPage, "Cosmetics")
state.KorbloxBtn = makeButton(visualPage, "Fake Korblox: OFF", function()
    state.Korblox = not state.Korblox
    state.KorbloxBtn.Text = state.Korblox and "Fake Korblox: ON" or "Fake Korblox: OFF"
    state.KorbloxBtn.BackgroundColor3 = state.Korblox and Color3.fromRGB(255, 140, 0)
                                                      or Color3.fromRGB(30, 34, 44)
    applyKorblox(state.Korblox)
end)

state.HeadlessBtn = makeButton(visualPage, "Fake Headless: OFF", function()
    state.Headless = not state.Headless
    state.HeadlessBtn.Text = state.Headless and "Fake Headless: ON" or "Fake Headless: OFF"
    state.HeadlessBtn.BackgroundColor3 = state.Headless and Color3.fromRGB(150, 0, 255)
                                                      or Color3.fromRGB(30, 34, 44)
    applyHeadless(state.Headless)
end)

-- ========== MUSIC ==========
makeSection(musicPage, "Now Playing")
local musicStatusLbl = Instance.new("TextLabel")
musicStatusLbl.Size = UDim2.new(1, 0, 0, 18)
musicStatusLbl.Text = "Status: Ready 🎧"
musicStatusLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
musicStatusLbl.BackgroundTransparency = 1
musicStatusLbl.Font = Enum.Font.Gotham
musicStatusLbl.TextSize = 10
musicStatusLbl.Parent = musicPage

makeSection(musicPage, "Play by ID")
local idRow = Instance.new("Frame")
idRow.Size = UDim2.new(1, 0, 0, 32)
idRow.BackgroundTransparency = 1
idRow.Parent = musicPage

local MusicBox = Instance.new("TextBox")
MusicBox.Size = UDim2.new(0.6, 0, 1, 0)
MusicBox.PlaceholderText = "🎵 حط ID هنا"
MusicBox.Text = ""
MusicBox.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
MusicBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MusicBox.PlaceholderColor3 = Color3.fromRGB(140, 150, 170)
MusicBox.Font = Enum.Font.Gotham
MusicBox.TextSize = 9
MusicBox.Parent = idRow
Instance.new("UICorner", MusicBox).CornerRadius = UDim.new(0, 6)

local PlayMusicBtn = Instance.new("TextButton")
PlayMusicBtn.Size = UDim2.new(0.18, 0, 1, 0)
PlayMusicBtn.Position = UDim2.new(0.62, 0, 0, 0)
PlayMusicBtn.Text = "▶️"
PlayMusicBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
PlayMusicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayMusicBtn.Font = Enum.Font.GothamBold
PlayMusicBtn.TextSize = 10
PlayMusicBtn.Parent = idRow
Instance.new("UICorner", PlayMusicBtn).CornerRadius = UDim.new(0, 6)

local StopMusicBtn = Instance.new("TextButton")
StopMusicBtn.Size = UDim2.new(0.18, 0, 1, 0)
StopMusicBtn.Position = UDim2.new(0.82, 0, 0, 0)
StopMusicBtn.Text = "⏹️"
StopMusicBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
StopMusicBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopMusicBtn.Font = Enum.Font.GothamBold
StopMusicBtn.TextSize = 10
StopMusicBtn.Parent = idRow
Instance.new("UICorner", StopMusicBtn).CornerRadius = UDim.new(0, 6)

PlayMusicBtn.MouseButton1Click:Connect(function()
    local id = tonumber(MusicBox.Text:match("%d+"))
    if id then
        playSongById(id)
        musicStatusLbl.Text = "Status: Playing " .. id .. " ▶️"
        musicStatusLbl.TextColor3 = Color3.fromRGB(0, 180, 255)
    else
        MusicBox.Text = ""
        MusicBox.PlaceholderText = "ID غير صحيح! ❌"
    end
end)

StopMusicBtn.MouseButton1Click:Connect(function()
    stopSong()
    musicStatusLbl.Text = "Status: Stopped ⏹️"
    musicStatusLbl.TextColor3 = Color3.fromRGB(200, 50, 50)
end)

makeSection(musicPage, "Quick Songs")
for i, song in ipairs(savedSongsList) do
    makeButton(musicPage, song.Name, function()
        playSongById(song.Id)
        musicStatusLbl.Text = "Status: Playing " .. song.Id .. " ▶️"
        musicStatusLbl.TextColor3 = Color3.fromRGB(0, 180, 255)
    end)
end

-- ========== MISC ==========
makeSection(miscPage, "Credits")
local credits = Instance.new("TextLabel")
credits.Size = UDim2.new(1, 0, 0, 20)
credits.Text = "Made by aki | TT: 1x.ud | DC: oa2a"
credits.TextColor3 = Color3.fromRGB(180, 190, 210)
credits.BackgroundTransparency = 1
credits.Font = Enum.Font.Gotham
credits.TextSize = 9
credits.Parent = miscPage

-- ================================================================
-- UI EVENTS
-- ================================================================
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

CloseBtn.MouseButton1Click:Connect(function()
    state.AutoPlay = false
    state.Noclip = false
    state.Bloxstrap = false
    state.Korblox = false
    state.Headless = false
    state.Parry = false
    state.AutoSwing = false
    state.InfiniteJump = false
    state.ESP = false
    state.HUD = false
    currentSound:Destroy()
    for _, obj in ipairs(ESPFolder:GetChildren()) do obj:Destroy() end
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
    ScreenGui:Destroy()
    hudGui:Destroy()
end)

-- ================================================================
-- INFINITE JUMP
-- ================================================================
UIS.JumpRequest:Connect(function()
    if state.InfiniteJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ================================================================
-- CHARACTER RESPAWN
-- ================================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if state.Korblox then applyKorblox(true) end
    if state.Headless then applyHeadless(true) end
end)

-- ================================================================
-- MAIN LOOP
-- ================================================================
local lastJump = 0
local lastParry = 0
local lastSwing = 0
local lastIdle = 0
local fpsCount = 0
local lastFPSUpdate = tick()

RunService.Heartbeat:Connect(function(dt)
    local char = getChar()
    if not char then return end
    local hrp = getHRP()
    local hum = getHum()
    if not hrp or not hum then return end

    -- Noclip
    if state.Noclip then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    -- AutoPlay
    if state.AutoPlay and hasBomb() then
        local tgt = getNearestTarget()
        if tgt then
            local thrp = getHRP(tgt)
            if thrp then
                local dir = (jitter(thrp.Position) - hrp.Position)
                if dir.Magnitude > 0.05 then
                    dir = dir.Unit
                    local wp = hrp.Position + dir * 8
                    hum:MoveTo(Vector3.new(wp.X, hrp.Position.Y, wp.Z))
                    hrp.CFrame = CFrame.lookAt(hrp.Position, thrp.Position)
                end
            end
        end
    end

    -- Auto Parry
    if state.Parry then
        local tgt, d = getNearestTarget(12)
        if tgt and d and d < 12 then
            local thrp = getHRP(tgt)
            if thrp and thrp.AssemblyLinearVelocity.Magnitude > 3 then
                if tick() - lastParry > 0.3 then
                    lastParry = tick()
                    pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                        task.wait(0.03)
                        vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                    end)
                end
            end
        end
    end

    -- Auto Swing
    if state.AutoSwing then
        local tgt, d = getNearestTarget(15)
        if tgt and d and d < 15 then
            if tick() - lastSwing > 0.4 then
                lastSwing = tick()
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.03)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
            end
        end
    end

    -- HUD
    if state.HUD then
        fpsCount = fpsCount + 1
        if tick() - lastFPSUpdate >= 1 then
            fpsLine.Text = "FPS: " .. fpsCount
            fpsCount = 0
            lastFPSUpdate = tick()
        end
        local ok, ping = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        pingLine.Text = "Ping: " .. (ok and math.floor(ping) or "--") .. " ms"
        bombLine.Text = "Bomb: " .. (hasBomb() and "YES ❤️" or "no")
        local t = math.floor(tick())
        timeLine.Text = "Time: " .. string.format("%02d:%02d", math.floor(t/60) % 60, t % 60)
    end

    -- Anti-AFK
    if tick() - lastIdle > 60 then
        lastIdle = tick()
        pcall(function()
            local VU = game:GetService("VirtualUser")
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end
end)

print("[Nyx] Slax Hub Full Build loaded ❤️")
print("  - 5 tabs: Main, Combat, Visual, Music, Misc")
print("  - Toggle: الأيقونة الحمراء على يسار الشاشة")
