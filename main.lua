-- ============================================================
-- THE LOST FRONT — ESP + Radar + Triggerbot
-- File: tlf_hub.lua
-- المصدر: مبني على معايير Roblox FPS shooter
--         مقارن مع سكربت Swill Way المعروف
-- اللعبة: The Lost Front (Type Productions)
--         GameId: 102871156420149
-- ملاحظة: في anti-cheat — استخدام بحذر
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ============================================================
-- 1. STATE
-- ============================================================
local STATE = {
    esp_enabled        = false,
    esp_box            = true,
    esp_name           = true,
    esp_health         = true,
    esp_distance       = true,
    esp_skeleton       = false,
    esp_tracer         = false,
    esp_team_check     = true,
    radar_enabled      = false,
    triggerbot         = false,
    triggerbot_delay   = 0.08,
    fov                = 120,
    max_distance       = 1500,
}

local ESP_OBJECTS = {}   -- [player] = { drawing objects }
local ESP_GUI     = nil
local RADAR_GUI   = nil
local RADAR_FRAME = nil

-- ============================================================
-- 2. THEME
-- ============================================================
local THEME = {
    bg         = Color3.fromRGB(11, 12, 16),
    card       = Color3.fromRGB(18, 20, 26),
    card_hover = Color3.fromRGB(26, 28, 36),
    stroke     = Color3.fromRGB(48, 52, 66),
    stroke_lit = Color3.fromRGB(90, 100, 130),
    text       = Color3.fromRGB(245, 245, 250),
    text_dim   = Color3.fromRGB(140, 145, 165),
    text_faint = Color3.fromRGB(90, 95, 115),
    on         = Color3.fromRGB(80, 200, 130),
    accent     = Color3.fromRGB(120, 140, 250),
    enemy      = Color3.fromRGB(240, 70, 80),
    team       = Color3.fromRGB(80, 180, 240),
    warn       = Color3.fromRGB(240, 180, 70),
    font       = Font.new("rbxasset://fonts/families/GothamSSm.json",
                          Enum.FontWeight.Medium, Enum.FontStyle.Normal),
    font_bold  = Font.new("rbxasset://fonts/families/GothamSSm.json",
                          Enum.FontWeight.Bold, Enum.FontStyle.Normal),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.3
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function tween(o, d, props)
    return TweenService:Create(
        o, TweenInfo.new(d or 0.2, Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out), props)
end

-- ============================================================
-- 3. HELPERS
-- ============================================================
local function get_character(player)
    return player and player.Character
end

local function get_root(player)
    local char = get_character(player)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char.PrimaryPart
end

local function get_head(player)
    local char = get_character(player)
    return char and char:FindFirstChild("Head")
end

local function get_humanoid(player)
    local char = get_character(player)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function is_alive(player)
    local hum = get_humanoid(player)
    return hum and hum.Health > 0
end

-- فحص الفريق — يعتمد على اللعبة. في The Lost Front:
-- ألوان الفريق من TeamColor أو Attributes.
local function is_enemy(player)
    if player == LocalPlayer then return false end
    if not STATE.esp_team_check then return true end

    -- محاولة 1: Player.Team
    if player.Team and LocalPlayer.Team then
        return player.Team ~= LocalPlayer.Team
    end

    -- محاولة 2: TeamColor attribute على الـ character
    local char = get_character(player)
    local my_char = LocalPlayer.Character
    if char and my_char then
        local their = char:GetAttribute("Team")
            or char:GetAttribute("TeamColor")
            or char:GetAttribute("team")
        local mine = my_char:GetAttribute("Team")
            or my_char:GetAttribute("TeamColor")
            or my_char:GetAttribute("team")
        if their and mine then
            return their ~= mine
        end
    end

    -- fallback: افترض عدو
    return true
end

-- ============================================================
-- 4. ESP — Box + Name + Health + Distance
-- ============================================================
local function create_esp_for(player)
    if ESP_OBJECTS[player] then
        return ESP_OBJECTS[player]
    end

    local gui = Instance.new("BillboardGui")
    gui.Name = "TLF_ESP"
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Size = UDim2.new(0, 100, 0, 100)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.MaxDistance = STATE.max_distance
    gui.Adornee = nil
    gui.Enabled = false
    gui.Parent = CoreGui

    -- Box
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Size = UDim2.new(1, 0, 1, 0)
    box.Parent = gui
    local box_stroke = Instance.new("UIStroke")
    box_stroke.Color = THEME.enemy
    box_stroke.Thickness = 1.5
    box_stroke.Parent = box

    -- Name
    local name_lbl = Instance.new("TextLabel")
    name_lbl.Name = "NameLbl"
    name_lbl.BackgroundTransparency = 1
    name_lbl.Text = player.Name
    name_lbl.TextColor3 = Color3.new(1, 1, 1)
    name_lbl.TextSize = 14
    name_lbl.FontFace = THEME.font_bold
    name_lbl.TextStrokeTransparency = 0
    name_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    name_lbl.Size = UDim2.new(1, 0, 0, 16)
    name_lbl.Position = UDim2.new(0, 0, 0, -18)
    name_lbl.Parent = gui

    -- Distance
    local dist_lbl = Instance.new("TextLabel")
    dist_lbl.Name = "DistLbl"
    dist_lbl.BackgroundTransparency = 1
    dist_lbl.Text = ""
    dist_lbl.TextColor3 = THEME.text_dim
    dist_lbl.TextSize = 12
    dist_lbl.FontFace = THEME.font
    dist_lbl.TextStrokeTransparency = 0
    dist_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    dist_lbl.Size = UDim2.new(1, 0, 0, 14)
    dist_lbl.Position = UDim2.new(0, 0, 1, 2)
    dist_lbl.Parent = gui

    -- Health bar (خلفية)
    local hp_bg = Instance.new("Frame")
    hp_bg.Name = "HP_BG"
    hp_bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    hp_bg.BorderSizePixel = 0
    hp_bg.Size = UDim2.new(0, 3, 1, 0)
    hp_bg.Position = UDim2.new(-1, -6, 0, 0)
    hp_bg.Parent = gui
    corner(hp_bg, 1)
    stroke(hp_bg, Color3.new(0, 0, 0), 1, 0.2)

    local hp_fill = Instance.new("Frame")
    hp_fill.Name = "HP_Fill"
    hp_fill.BackgroundColor3 = THEME.on
    hp_fill.BorderSizePixel = 0
    hp_fill.Size = UDim2.new(1, 0, 1, 0)
    hp_fill.Position = UDim2.new(0, 0, 0, 0)
    hp_fill.Parent = hp_bg
    corner(hp_fill, 1)

    local refs = {
        gui = gui,
        box = box,
        box_stroke = box_stroke,
        name_lbl = name_lbl,
        dist_lbl = dist_lbl,
        hp_bg = hp_bg,
        hp_fill = hp_fill,
        connection = nil,
    }
    ESP_OBJECTS[player] = refs
    return refs
end

local function remove_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end
    if refs.connection then
        pcall(function() refs.connection:Disconnect() end)
    end
    if refs.gui and refs.gui.Parent then
        refs.gui:Destroy()
    end
    ESP_OBJECTS[player] = nil
end

local function update_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end

    if not STATE.esp_enabled then
        refs.gui.Enabled = false
        return
    end

    if not is_alive(player) or not is_enemy(player) then
        refs.gui.Enabled = false
        return
    end

    local char = get_character(player)
    local hrp  = get_root(player)
    local head = get_head(player)
    if not char or not hrp or not head then
        refs.gui.Enabled = false
        return
    end

    local my_root = get_root(LocalPlayer)
    if not my_root then
        refs.gui.Enabled = false
        return
    end

    local distance = (hrp.Position - my_root.Position).Magnitude
    if distance > STATE.max_distance then
        refs.gui.Enabled = false
        return
    end

    -- Adornee
    refs.gui.Adornee = hrp
    refs.gui.Enabled = true

    -- Box sizing (يتماشى مع حجم الـ character)
    local size = char:GetExtentsSize()
    local height = size.Y
    local width = size.X

    -- نحول العالم إلى شاشة لحجم الـ box
    local screen_pos, on_screen = Camera:WorldToViewportPoint(hrp.Position)
    if not on_screen then
        refs.gui.Enabled = false
        return
    end

    -- نستخدم حجم ثابت مبني على المسافة
    local box_size_px = math.clamp(2000 / distance, 20, 300)
    refs.gui.Size = UDim2.new(0, box_size_px, 0, box_size_px * (height / width))

    -- Box color حسب الفريق
    refs.box_stroke.Color = THEME.enemy

    -- Box visibility
    refs.box.Visible = STATE.esp_box
    refs.box_stroke.Enabled = STATE.esp_box

    -- Name
    refs.name_lbl.Visible = STATE.esp_name
    refs.name_lbl.Text = player.Name
        .. (player.DisplayName ~= player.Name
            and " (@" .. player.DisplayName .. ")" or "")

    -- Distance
    refs.dist_lbl.Visible = STATE.esp_distance
    refs.dist_lbl.Text = math.floor(distance) .. "m"

    -- Health
    local hum = get_humanoid(player)
    refs.hp_bg.Visible = STATE.esp_health
    if hum then
        local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        refs.hp_fill.Size = UDim2.new(1, 0, pct, 0)
        refs.hp_fill.Position = UDim2.new(0, 0, 1 - pct, 0)

        if pct > 0.6 then
            refs.hp_fill.BackgroundColor3 = THEME.on
        elseif pct > 0.3 then
            refs.hp_fill.BackgroundColor3 = THEME.warn
        else
            refs.hp_fill.BackgroundColor3 = THEME.enemy
        end
    end
end

local function refresh_esp()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if STATE.esp_enabled then
                create_esp_for(player)
                update_esp_for(player)
            else
                remove_esp_for(player)
            end
        end
    end
end

-- ============================================================
-- 5. RADAR — خريطة مصغرة
-- ============================================================
local function create_radar()
    if RADAR_GUI then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "TLF_Radar"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 180)
    frame.Position = UDim2.new(1, -200, 0, 100)
    frame.BackgroundColor3 = THEME.bg
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 12)
    stroke(frame, THEME.stroke_lit, 1.5, 0.4)

    -- عنوان
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "RADAR"
    title.TextColor3 = THEME.text_dim
    title.FontFace = THEME.font_bold
    title.TextSize = 10
    title.Parent = frame

    RADAR_GUI = gui
    RADAR_FRAME = frame
end

local RADAR_DOTS = {}

local function update_radar()
    if not STATE.radar_enabled then
        for _, dot in pairs(RADAR_DOTS) do
            dot.Visible = false
        end
        return
    end

    if not RADAR_FRAME then
        create_radar()
    end
    RADAR_FRAME.Visible = true

    local my_root = get_root(LocalPlayer)
    if not my_root then return end

    local center = Vector2.new(
        RADAR_FRAME.AbsolutePosition.X + RADAR_FRAME.AbsoluteSize.X / 2,
        RADAR_FRAME.AbsolutePosition.Y + RADAR_FRAME.AbsoluteSize.Y / 2
    )
    local radius = RADAR_FRAME.AbsoluteSize.X / 2
    local scale = radius / 500  -- 500 studs = نصف قطر الرادار

    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and is_alive(player) then
            local dot = RADAR_DOTS[player]
            if not dot then
                dot = Instance.new("Frame")
                dot.Name = player.Name
                dot.Size = UDim2.new(0, 6, 0, 6)
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.BackgroundColor3 = is_enemy(player) and THEME.enemy or THEME.team
                dot.BorderSizePixel = 0
                dot.Parent = RADAR_FRAME
                corner(dot, 3)
                RADAR_DOTS[player] = dot
            end

            local prp = get_root(player)
            if prp then
                local rel = prp.Position - my_root.Position
                local dist_2d = Vector2.new(rel.X, rel.Z) * scale
                local mag = dist_2d.Magnitude
                if mag > radius - 4 then
                    dist_2d = dist_2d.Unit * (radius - 4)
                end
                dot.Position = UDim2.new(
                    0.5, dist_2d.X,
                    0.5, dist_2d.Y
                )
                dot.BackgroundColor3 = is_enemy(player)
                    and THEME.enemy or THEME.team
                dot.Visible = true
                seen[player] = true
            end
        end
    end

    for player, dot in pairs(RADAR_DOTS) do
        if not seen[player] then
            dot.Visible = false
        end
    end
end

-- ============================================================
-- 6. TRIGGERBOT
-- ============================================================
local trigger_last = 0

local function triggerbot_loop()
    if not STATE.triggerbot then return end

    local now = tick()
    if now - trigger_last < STATE.triggerbot_delay then return end

    local my_root = get_root(LocalPlayer)
    if not my_root then return end

    -- نحاول نحصل على منظور الكاميرا
    local cam_pos = Camera.CFrame.Position
    local cam_dir = Camera.CFrame.LookVector

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and is_alive(player) and is_enemy(player) then
            local head = get_head(player)
            if head then
                local to_head = (head.Position - cam_pos)
                local dist = to_head.Magnitude
                if dist < 500 then
                    local angle = cam_dir:Dot(to_head.Unit)
                    local fov_threshold = math.cos(math.rad(STATE.fov / 2))
                    if angle > fov_threshold then
                        -- نضرب
                        if mouse1click then
                            mouse1click()
                            trigger_last = now
                        elseif VirtualInputManager then
                            -- fallback
                        end
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================
-- 7. UI
-- ============================================================
local parent_gui = CoreGui
if gethui then
    local ok, h = pcall(gethui)
    if ok and h then parent_gui = h end
end

local screen = Instance.new("ScreenGui")
screen.Name = "TLF_Hub"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 999
screen.Parent = parent_gui

-- زر التعليق
local toggle_btn = Instance.new("TextButton")
toggle_btn.Size = UDim2.new(0, 56, 0, 56)
toggle_btn.Position = UDim2.new(0, 20, 0.5, -28)
toggle_btn.BackgroundColor3 = THEME.card
toggle_btn.BackgroundTransparency = 0.05
toggle_btn.BorderSizePixel = 0
toggle_btn.Text = "TLF"
toggle_btn.TextColor3 = THEME.text
toggle_btn.FontFace = THEME.font_bold
toggle_btn.TextSize = 14
toggle_btn.AutoButtonColor = false
toggle_btn.Active = true
toggle_btn.Parent = screen
corner(toggle_btn, 14)
stroke(toggle_btn, THEME.stroke_lit, 1.5, 0.5)

-- اللوحة
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 320, 0, 440)
panel.Position = UDim2.new(0, 20, 0.5, -220)
panel.BackgroundColor3 = THEME.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = true
panel.Parent = screen
corner(panel, 16)
stroke(panel, THEME.stroke_lit, 1.5, 0.4)

-- الهيدر
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundTransparency = 1
header.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "The Lost Front"
title.TextColor3 = THEME.text
title.FontFace = THEME.font_bold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Parent = header

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 32, 0, 32)
close_btn.Position = UDim2.new(1, -44, 0, 10)
close_btn.BackgroundColor3 = THEME.card
close_btn.BorderSizePixel = 0
close_btn.Text = "×"
close_btn.TextColor3 = THEME.text_dim
close_btn.FontFace = THEME.font_bold
close_btn.TextSize = 20
close_btn.AutoButtonColor = false
close_btn.Active = true
close_btn.Parent = header
corner(close_btn, 8)
stroke(close_btn)

-- Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(1, -40, 0, 1)
div.Position = UDim2.new(0, 20, 0, 52)
div.BackgroundColor3 = THEME.stroke
div.BorderSizePixel = 0
div.Parent = panel

-- محتوى
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -32, 1, -68)
content.Position = UDim2.new(0, 16, 0, 60)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = THEME.stroke_lit
content.ScrollBarImageTransparency = 0.5
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Active = true
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = content

-- Section label
local function make_section(text, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = content

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "—  " .. text .. "  —"
    lbl.TextColor3 = THEME.text_faint
    lbl.FontFace = THEME.font
    lbl.TextSize = 11
    lbl.Parent = row
end

-- Toggle button
local function make_toggle(label, order, key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = THEME.card
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = true
    btn.LayoutOrder = order
    btn.Parent = content
    corner(btn, 8)
    local st = stroke(btn)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.text
    lbl.FontFace = THEME.font
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = btn

    local stt = Instance.new("TextLabel")
    stt.Size = UDim2.new(0, 46, 1, 0)
    stt.Position = UDim2.new(1, -50, 0, 0)
    stt.BackgroundTransparency = 1
    stt.Text = "واقف"
    stt.TextColor3 = THEME.text_dim
    stt.FontFace = THEME.font_bold
    stt.TextSize = 11
    stt.TextXAlignment = Enum.TextXAlignment.Right
    stt.TextYAlignment = Enum.TextYAlignment.Center
    stt.Parent = btn

    local function refresh()
        local on = STATE[key] == true
        btn.BackgroundColor3 = on and THEME.on or THEME.card
        st.Color = on and THEME.on or THEME.stroke
        stt.Text = on and "شغال" or "واقف"
        stt.TextColor3 = on and THEME.bg or THEME.text_dim
    end

    btn.MouseButton1Click:Connect(function()
        STATE[key] = not (STATE[key] == true)
        refresh()
        if key == "esp_enabled" then
            refresh_esp()
        end
    end)

    refresh()
    task.spawn(function()
        while btn.Parent do
            task.wait(0.5)
            refresh()
        end
    end)
end

make_section("ESP", 1)
make_toggle("ESP", 2, "esp_enabled")
make_toggle("Box", 3, "esp_box")
make_toggle("Name", 4, "esp_name")
make_toggle("Health", 5, "esp_health")
make_toggle("Distance", 6, "esp_distance")
make_toggle("Team Check", 7, "esp_team_check")

make_section("Radar", 10)
make_toggle("Radar", 11, "radar_enabled")

make_section("Combat", 20)
make_toggle("Triggerbot", 21, "triggerbot")

-- ============================================================
-- 8. LOOPS
-- ============================================================
RunService.RenderStepped:Connect(function()
    pcall(function()
        if STATE.esp_enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    update_esp_for(player)
                end
            end
        end

        if STATE.radar_enabled then
            update_radar()
        end

        if STATE.triggerbot then
            triggerbot_loop()
        end
    end)
end)

-- Player events
Players.PlayerAdded:Connect(function(player)
    if STATE.esp_enabled then
        task.defer(function()
            player.CharacterAdded:Wait()
            create_esp_for(player)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    remove_esp_for(player)
    if RADAR_DOTS[player] then
        RADAR_DOTS[player]:Destroy()
        RADAR_DOTS[player] = nil
    end
end)

-- ============================================================
-- 9. DRAG + OPEN/CLOSE
-- ============================================================
local dragging, drag_start, panel_start = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        drag_start = input.Position
        panel_start = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local d = input.Position - drag_start
    panel.Position = UDim2.new(
        panel_start.X.Scale, panel_start.X.Offset + d.X,
        panel_start.Y.Scale, panel_start.Y.Offset + d.Y
    )
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local is_open = false
local function set_open(state)
    is_open = state
    if state then
        panel.Visible = true
        panel.Size = UDim2.new(0, 320, 0, 60)
        tween(panel, 0.25, { Size = UDim2.new(0, 320, 0, 440) }):Play()
    else
        tween(panel, 0.2, { Size = UDim2.new(0, 320, 0, 52) }):Play()
        task.delay(0.2, function()
            if not is_open then panel.Visible = false end
        end)
    end
end

toggle_btn.MouseButton1Click:Connect(function() set_open(not is_open) end)
close_btn.MouseButton1Click:Connect(function() set_open(false) end)

-- ============================================================
-- 10. EXPORTS
-- ============================================================
getgenv().__TLF_HUB = {
    STATE = STATE,
    toggle_esp = function()
        STATE.esp_enabled = not STATE.esp_enabled
        refresh_esp()
    end,
    toggle_radar = function()
        STATE.radar_enabled = not STATE.radar_enabled
        if STATE.radar_enabled then create_radar() end
    end,
    toggle_triggerbot = function()
        STATE.triggerbot = not STATE.triggerbot
    end,
    set_fov = function(v) STATE.fov = tonumber(v) or 120 end,
    set_max_distance = function(v) STATE.max_distance = tonumber(v) or 1500 end,
}

print("[TLF HUB] جاهز — ABSOLUTE KODE، يا ريدز")
print("[TLF HUB] اضغط TLF لفتح اللوحة")
