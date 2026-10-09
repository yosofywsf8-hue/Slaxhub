-- ============================================================
-- THE LOST FRONT HUB v6 — ESP Pro
-- File: tlf_hub_v6.lua
-- ============================================================
-- الجديد:
--   - ESP بتصميم Pro (double box, gradient, clean labels)
--   - فلترة أعداء محسّنة (4 طرق)
--   - Skeleton (خطوط العظام)
--   - Weapon info (اختياري)
-- ============================================================

-- ============================================================
-- 1. LOAD RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"
))()
getgenv().Rayfield = Rayfield

-- ============================================================
-- 2. DEPENDENCIES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ============================================================
-- 3. STATE
-- ============================================================
local STATE = {
    -- ESP
    esp_enabled       = false,
    esp_box           = true,
    esp_double_box    = true,
    esp_skeleton      = false,
    esp_name          = true,
    esp_health        = true,
    esp_distance      = true,
    esp_weapon        = false,
    esp_head_dot      = true,
    esp_arrow         = true,
    esp_chams         = false,
    esp_max_dist      = 1500,

    -- فلترة الأعداء
    filter_team       = true,
    filter_teamcolor  = true,
    filter_attribute  = true,
    filter_character  = true,

    -- Radar
    radar_enabled     = false,

    -- Silent Aim
    sa_enabled        = false,
    sa_team_check     = true,
    sa_visible_only   = false,
    sa_draw_fov       = true,
    sa_debug          = false,
    sa_fov            = 90,
    sa_hit_part       = "Head",
    sa_target_mode    = "closest",
    sa_prediction     = 0.05,
}

local ESP_OBJECTS = {}
local RADAR_DOTS  = {}
local RADAR_FRAME = nil
local FOV_CIRCLE  = nil
local CURRENT_TARGET = nil
local HOOKED = {}
local HOOK_METHOD = nil

-- ============================================================
-- 4. HELPERS
-- ============================================================
local function get_root(plr)
    local c = plr and plr.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
end

local function get_head(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChild("Head")
end

local function get_torso(plr)
    local c = plr and plr.Character
    if not c then return nil end
    return c:FindFirstChild("UpperTorso")
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("LowerTorso")
end

local function get_hum(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function is_alive(plr)
    local h = get_hum(plr)
    return h and h.Health > 0
end

-- ============================================================
-- 5. فلترة الأعداء — 4 طرق
-- ============================================================
local function is_enemy(plr)
    if plr == LocalPlayer then return false end

    -- طريقة 1: Team object
    if STATE.filter_team
        and plr.Team and LocalPlayer.Team then
        return plr.Team ~= LocalPlayer.Team
    end

    -- طريقة 2: TeamColor
    if STATE.filter_teamcolor
        and plr.TeamColor and LocalPlayer.TeamColor then
        return plr.TeamColor ~= LocalPlayer.TeamColor
    end

    -- طريقة 3: Character attributes
    if STATE.filter_attribute then
        local c = plr.Character
        local mc = LocalPlayer.Character
        if c and mc then
            local t1 = c:GetAttribute("Team")
                or c:GetAttribute("team")
                or c:GetAttribute("TeamName")
                or c:GetAttribute("Faction")
            local t2 = mc:GetAttribute("Team")
                or mc:GetAttribute("team")
                or mc:GetAttribute("TeamName")
                or mc:GetAttribute("Faction")
            if t1 and t2 then
                return tostring(t1) ~= tostring(t2)
            end
        end
    end

    -- طريقة 4: Player attributes
    if STATE.filter_character then
        local t1 = plr:GetAttribute("Team")
            or plr:GetAttribute("team")
            or plr:GetAttribute("Faction")
        local t2 = LocalPlayer:GetAttribute("Team")
            or LocalPlayer:GetAttribute("team")
            or LocalPlayer:GetAttribute("Faction")
        if t1 and t2 then
            return tostring(t1) ~= tostring(t2)
        end
    end

    -- Fallback: اعتبره عدو
    return true
end

local function is_enemy_sa(plr)
    if not STATE.sa_team_check then return plr ~= LocalPlayer end
    return is_enemy(plr)
end

-- ============================================================
-- 6. ESP — تصميم Pro
-- ============================================================
local HAS_DRAWING = (Drawing ~= nil) and (Drawing.new ~= nil)

local COLORS = {
    enemy       = Color3.fromRGB(255, 65, 75),
    enemy_dark  = Color3.fromRGB(140, 30, 40),
    enemy_glow  = Color3.fromRGB(255, 130, 140),
    hp_high     = Color3.fromRGB(90, 220, 130),
    hp_mid      = Color3.fromRGB(240, 190, 80),
    hp_low      = Color3.fromRGB(255, 70, 80),
    text_main   = Color3.fromRGB(255, 255, 255),
    text_dim    = Color3.fromRGB(210, 210, 220),
    text_shadow = Color3.fromRGB(0, 0, 0),
    bg_dark     = Color3.fromRGB(15, 15, 20),
}

local function create_esp_for(player)
    if ESP_OBJECTS[player] then return ESP_OBJECTS[player] end

    -- ═══════════════════════════════════════
    -- BillboardGui الأساسي
    -- ═══════════════════════════════════════
    local gui = Instance.new("BillboardGui")
    gui.Name = "TLF_ESP_Pro"
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Size = UDim2.new(0, 100, 0, 100)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.MaxDistance = STATE.esp_max_dist
    gui.Adornee = nil
    gui.Enabled = false
    gui.Parent = CoreGui

    -- ═══════════════════════════════════════
    -- Box 1 (رئيسي)
    -- ═══════════════════════════════════════
    local box_outer = Instance.new("Frame")
    box_outer.Name = "BoxOuter"
    box_outer.BackgroundTransparency = 1
    box_outer.BorderSizePixel = 0
    box_outer.Size = UDim2.new(1, 0, 1, 0)
    box_outer.Parent = gui

    local stroke_outer = Instance.new("UIStroke")
    stroke_outer.Color = COLORS.enemy
    stroke_outer.Thickness = 1.5
    stroke_outer.Transparency = 0
    stroke_outer.Parent = box_outer

    -- ═══════════════════════════════════════
    -- Box 2 (داخلي — double box)
    -- ═══════════════════════════════════════
    local box_inner = Instance.new("Frame")
    box_inner.Name = "BoxInner"
    box_inner.BackgroundTransparency = 1
    box_inner.BorderSizePixel = 0
    box_inner.Size = UDim2.new(1, -4, 1, -4)
    box_inner.Position = UDim2.new(0, 2, 0, 2)
    box_inner.Parent = gui

    local stroke_inner = Instance.new("UIStroke")
    stroke_inner.Color = COLORS.enemy
    stroke_inner.Thickness = 1
    stroke_inner.Transparency = 0.4
    stroke_inner.Parent = box_inner

    -- ═══════════════════════════════════════
    -- Gradient Top Bar (خط علوي بتدرج)
    -- ═══════════════════════════════════════
    local top_bar = Instance.new("Frame")
    top_bar.Name = "TopBar"
    top_bar.BackgroundColor3 = COLORS.enemy
    top_bar.BorderSizePixel = 0
    top_bar.Size = UDim2.new(1, 0, 0, 2)
    top_bar.Position = UDim2.new(0, 0, 0, -3)
    top_bar.Parent = gui

    local top_gradient = Instance.new("UIGradient")
    top_gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.enemy_dark),
        ColorSequenceKeypoint.new(0.5, COLORS.enemy_glow),
        ColorSequenceKeypoint.new(1, COLORS.enemy_dark),
    })
    top_gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    top_gradient.Parent = top_bar

    -- ═══════════════════════════════════════
    -- Corner Brackets — شكل أقواس في الأركان
    -- ═══════════════════════════════════════
    local brackets = {}
    local bracket_layout = {
        -- [posX, posY, sizeX, sizeY, anchorX, anchorY]
        -- Top-left horizontal
        {0, 0, 10, 2, 0, 0, "HL"},
        -- Top-left vertical
        {0, 0, 2, 10, 0, 0, "VL"},
        -- Top-right horizontal
        {1, 0, 10, 2, 1, 0, "HR"},
        -- Top-right vertical
        {1, 0, 2, 10, 1, 0, "VR"},
        -- Bottom-left horizontal
        {0, 1, 10, 2, 0, 1, "HL"},
        -- Bottom-left vertical
        {0, 1, 2, 10, 0, 1, "VL"},
        -- Bottom-right horizontal
        {1, 1, 10, 2, 1, 1, "HR"},
        -- Bottom-right vertical
        {1, 1, 2, 10, 1, 1, "VR"},
    }

    for i, spec in ipairs(bracket_layout) do
        local br = Instance.new("Frame")
        br.Name = "Bracket" .. i
        br.BackgroundColor3 = COLORS.enemy
        br.BorderSizePixel = 0

        local anchorX = spec[5]
        local anchorY = spec[6]
        local kind = spec[7]

        br.AnchorPoint = Vector2.new(anchorX, anchorY)

        if kind == "HL" then
            br.Size = UDim2.new(0, 10, 0, 2)
        elseif kind == "VL" then
            br.Size = UDim2.new(0, 2, 0, 10)
        elseif kind == "HR" then
            br.Size = UDim2.new(0, 10, 0, 2)
        elseif kind == "VR" then
            br.Size = UDim2.new(0, 2, 0, 10)
        end

        -- Position — offset from corners
        local offX = 0
        local offY = 0
        if anchorX == 1 then offX = -1 end
        if anchorY == 1 then offY = -1 end

        br.Position = UDim2.new(anchorX, offX, anchorY, offY)
        br.Parent = gui
        brackets[i] = br
    end

    -- ═══════════════════════════════════════
    -- Head Dot
    -- ═══════════════════════════════════════
    local head_dot = Instance.new("Frame")
    head_dot.Name = "HeadDot"
    head_dot.Size = UDim2.new(0, 5, 0, 5)
    head_dot.AnchorPoint = Vector2.new(0.5, 0.5)
    head_dot.Position = UDim2.new(0.5, 0, 0, -8)
    head_dot.BackgroundColor3 = COLORS.enemy_glow
    head_dot.BorderSizePixel = 0
    head_dot.Parent = gui

    local hd_corner = Instance.new("UICorner")
    hd_corner.CornerRadius = UDim.new(1, 0)
    hd_corner.Parent = head_dot

    -- ═══════════════════════════════════════
    -- Arrow (سهم فوق الرأس)
    -- ═══════════════════════════════════════
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 20, 0, 20)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(0.5, 0, 0, -26)
    arrow.Text = "▼"
    arrow.TextColor3 = COLORS.enemy_glow
    arrow.TextSize = 18
    arrow.Font = Enum.Font.GothamBold
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3 = COLORS.text_shadow
    arrow.Parent = gui

    -- ═══════════════════════════════════════
    -- Name
    -- ═══════════════════════════════════════
    local name_lbl = Instance.new("TextLabel")
    name_lbl.Name = "NameLabel"
    name_lbl.BackgroundTransparency = 1
    name_lbl.Text = player.Name
    name_lbl.TextColor3 = COLORS.text_main
    name_lbl.TextSize = 13
    name_lbl.Font = Enum.Font.GothamBold
    name_lbl.TextStrokeTransparency = 0
    name_lbl.TextStrokeColor3 = COLORS.text_shadow
    name_lbl.Size = UDim2.new(1, 40, 0, 15)
    name_lbl.AnchorPoint = Vector2.new(0.5, 1)
    name_lbl.Position = UDim2.new(0.5, 0, 0, -42)
    name_lbl.Parent = gui

    -- ═══════════════════════════════════════
    -- Distance
    -- ═══════════════════════════════════════
    local dist_lbl = Instance.new("TextLabel")
    dist_lbl.Name = "DistLabel"
    dist_lbl.BackgroundTransparency = 1
    dist_lbl.Text = ""
    dist_lbl.TextColor3 = COLORS.text_dim
    dist_lbl.TextSize = 11
    dist_lbl.Font = Enum.Font.GothamSemibold
    dist_lbl.TextStrokeTransparency = 0
    dist_lbl.TextStrokeColor3 = COLORS.text_shadow
    dist_lbl.Size = UDim2.new(1, 40, 0, 13)
    dist_lbl.AnchorPoint = Vector2.new(0.5, 0)
    dist_lbl.Position = UDim2.new(0.5, 0, 1, 3)
    dist_lbl.Parent = gui

    -- ═══════════════════════════════════════
    -- Weapon (اختياري)
    -- ═══════════════════════════════════════
    local weapon_lbl = Instance.new("TextLabel")
    weapon_lbl.Name = "WeaponLabel"
    weapon_lbl.BackgroundTransparency = 1
    weapon_lbl.Text = ""
    weapon_lbl.TextColor3 = COLORS.text_dim
    weapon_lbl.TextSize = 10
    weapon_lbl.Font = Enum.Font.Gotham
    weapon_lbl.TextStrokeTransparency = 0
    weapon_lbl.TextStrokeColor3 = COLORS.text_shadow
    weapon_lbl.Size = UDim2.new(1, 40, 0, 12)
    weapon_lbl.AnchorPoint = Vector2.new(0.5, 0)
    weapon_lbl.Position = UDim2.new(0.5, 0, 1, 16)
    weapon_lbl.Parent = gui

    -- ═══════════════════════════════════════
    -- Health Bar — يسار البوكس
    -- ═══════════════════════════════════════
    local hp_container = Instance.new("Frame")
    hp_container.Name = "HPContainer"
    hp_container.BackgroundColor3 = COLORS.bg_dark
    hp_container.BackgroundTransparency = 0.2
    hp_container.BorderSizePixel = 0
    hp_container.Size = UDim2.new(0, 3, 1, 0)
    hp_container.Position = UDim2.new(0, -8, 0, 0)
    hp_container.Parent = gui

    local hp_container_corner = Instance.new("UICorner")
    hp_container_corner.CornerRadius = UDim.new(1, 0)
    hp_container_corner.Parent = hp_container

    local hp_stroke = Instance.new("UIStroke")
    hp_stroke.Color = COLORS.text_shadow
    hp_stroke.Thickness = 1
    hp_stroke.Transparency = 0.3
    hp_stroke.Parent = hp_container

    local hp_fill = Instance.new("Frame")
    hp_fill.Name = "HPFill"
    hp_fill.BackgroundColor3 = COLORS.hp_high
    hp_fill.BorderSizePixel = 0
    hp_fill.Size = UDim2.new(1, 0, 1, 0)
    hp_fill.Position = UDim2.new(0, 0, 0, 0)
    hp_fill.Parent = hp_container

    local hp_fill_corner = Instance.new("UICorner")
    hp_fill_corner.CornerRadius = UDim.new(1, 0)
    hp_fill_corner.Parent = hp_fill

    local hp_gradient = Instance.new("UIGradient")
    hp_gradient.Rotation = 90
    hp_gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
    })
    hp_gradient.Parent = hp_fill

    -- ═══════════════════════════════════════
    -- Tracer (خط من أسفل الشاشة)
    -- ═══════════════════════════════════════
    local tracer = nil
    if HAS_DRAWING then
        tracer = Drawing.new("Line")
        tracer.Thickness = 1.2
        tracer.Color = COLORS.enemy
        tracer.Transparency = 0.5
        tracer.Visible = false
    end

    -- ═══════════════════════════════════════
    -- Skeleton lines (Drawing)
    -- ═══════════════════════════════════════
    local skeleton_lines = {}
    if HAS_DRAWING then
        local skeleton_pairs = {
            "Head-Head",
            "Head-UpperTorso",
            "UpperTorso-LowerTorso",
            "UpperTorso-LeftUpperArm",
            "LeftUpperArm-LeftLowerArm",
            "LeftLowerArm-LeftHand",
            "UpperTorso-RightUpperArm",
            "RightUpperArm-RightLowerArm",
            "RightLowerArm-RightHand",
            "LowerTorso-LeftUpperLeg",
            "LeftUpperLeg-LeftLowerLeg",
            "LeftLowerLeg-LeftFoot",
            "LowerTorso-RightUpperLeg",
            "RightUpperLeg-RightLowerLeg",
            "RightLowerLeg-RightFoot",
        }
        for i, pair_name in ipairs(skeleton_pairs) do
            local line = Drawing.new("Line")
            line.Thickness = 1.2
            line.Color = COLORS.enemy
            line.Transparency = 0.7
            line.Visible = false
            skeleton_lines[i] = { line = line, pair = pair_name }
        end
    end

    local refs = {
        gui = gui,
        box_outer = box_outer,
        stroke_outer = stroke_outer,
        box_inner = box_inner,
        stroke_inner = stroke_inner,
        top_bar = top_bar,
        top_gradient = top_gradient,
        brackets = brackets,
        head_dot = head_dot,
        arrow = arrow,
        name_lbl = name_lbl,
        dist_lbl = dist_lbl,
        weapon_lbl = weapon_lbl,
        hp_container = hp_container,
        hp_fill = hp_fill,
        tracer = tracer,
        skeleton_lines = skeleton_lines,
    }
    ESP_OBJECTS[player] = refs
    return refs
end

local function remove_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end
    if refs.gui and refs.gui.Parent then
        refs.gui:Destroy()
    end
    if refs.tracer and refs.tracer.Remove then
        pcall(function() refs.tracer:Remove() end)
    end
    if refs.skeleton_lines then
        for _, sk in ipairs(refs.skeleton_lines) do
            if sk.line and sk.line.Remove then
                pcall(function() sk.line:Remove() end)
            end
        end
    end
    ESP_OBJECTS[player] = nil
end

-- Skeleton update
local SKELETON_PAIRS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function update_skeleton(refs, char)
    if not refs.skeleton_lines then return end
    if not STATE.esp_skeleton then
        for _, sk in ipairs(refs.skeleton_lines) do
            if sk.line then sk.line.Visible = false end
        end
        return
    end

    for i, sk in ipairs(refs.skeleton_lines) do
        local partA_name = SKELETON_PAIRS[i][1]
        local partB_name = SKELETON_PAIRS[i][2]
        local partA = char:FindFirstChild(partA_name)
        local partB = char:FindFirstChild(partB_name)

        if partA and partB then
            local posA, onA = Camera:WorldToViewportPoint(partA.Position)
            local posB, onB = Camera:WorldToViewportPoint(partB.Position)

            if onA and onB then
                sk.line.From = Vector2.new(posA.X, posA.Y)
                sk.line.To = Vector2.new(posB.X, posB.Y)
                sk.line.Visible = true
            else
                sk.line.Visible = false
            end
        else
            sk.line.Visible = false
        end
    end
end

local function update_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end

    -- ═══════════════════════════════════════
    -- فلترة أعداء
    -- ═══════════════════════════════════════
    if not STATE.esp_enabled
        or not is_alive(player)
        or not is_enemy(player) then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        if refs.skeleton_lines then
            for _, sk in ipairs(refs.skeleton_lines) do
                sk.line.Visible = false
            end
        end
        return
    end

    local char = player.Character
    local hrp  = get_root(player)
    if not char or not hrp then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        return
    end

    local my_root = get_root(LocalPlayer)
    if not my_root then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        return
    end

    local distance = (hrp.Position - my_root.Position).Magnitude
    if distance > STATE.esp_max_dist then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        return
    end

    refs.gui.Adornee = hrp
    refs.gui.Enabled = true

    -- ═══════════════════════════════════════
    -- حجم الـ gui حسب المسافة
    -- ═══════════════════════════════════════
    local screen_pos, on_screen = Camera:WorldToViewportPoint(hrp.Position)
    if not on_screen then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        return
    end

    -- حجم حجم الشخصية على الشاشة
    local char_size = char:GetExtentsSize()
    local height = char_size.Y
    local width = char_size.X

    local size_px = math.clamp(1800 / distance, 28, 340)
    local ratio = height / math.max(width, 0.1)
    refs.gui.Size = UDim2.new(0, size_px, 0, size_px * ratio)

    -- ═══════════════════════════════════════
    -- تطبيق الألوان والرؤية
    -- ═══════════════════════════════════════
    local color = COLORS.enemy

    refs.stroke_outer.Color = color
    refs.stroke_inner.Color = color
    refs.top_bar.BackgroundColor3 = color
    refs.head_dot.BackgroundColor3 = COLORS.enemy_glow
    refs.arrow.TextColor3 = COLORS.enemy_glow
    for _, b in ipairs(refs.brackets) do
        b.BackgroundColor3 = color
    end
    if refs.tracer then refs.tracer.Color = color end

    -- Box visibility
    refs.box_outer.Visible = STATE.esp_box
    refs.stroke_outer.Enabled = STATE.esp_box
    refs.box_inner.Visible = STATE.esp_box and STATE.esp_double_box
    refs.stroke_inner.Enabled = STATE.esp_box and STATE.esp_double_box
    refs.top_bar.Visible = STATE.esp_box

    for _, b in ipairs(refs.brackets) do
        b.Visible = STATE.esp_box
    end

    refs.head_dot.Visible = STATE.esp_head_dot
    refs.arrow.Visible = STATE.esp_arrow

    -- Name
    refs.name_lbl.Visible = STATE.esp_name
    refs.name_lbl.Text = player.Name

    -- Distance
    refs.dist_lbl.Visible = STATE.esp_distance
    refs.dist_lbl.Text = math.floor(distance) .. "m"

    -- Weapon (اختياري)
    refs.weapon_lbl.Visible = STATE.esp_weapon
    if STATE.esp_weapon then
        local weapon = char:GetAttribute("EquippedWeapon")
            or char:GetAttribute("Weapon")
            or char:GetAttribute("CurrentWeapon")
            or player:GetAttribute("EquippedWeapon")
        refs.weapon_lbl.Text = weapon and tostring(weapon) or "—"
    end

    -- ═══════════════════════════════════════
    -- Health
    -- ═══════════════════════════════════════
    local hum = get_hum(player)
    refs.hp_container.Visible = STATE.esp_health
    if hum then
        local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        refs.hp_fill.Size = UDim2.new(1, 0, pct, 0)
        refs.hp_fill.Position = UDim2.new(0, 0, 1 - pct, 0)

        if pct > 0.6 then
            refs.hp_fill.BackgroundColor3 = COLORS.hp_high
        elseif pct > 0.3 then
            refs.hp_fill.BackgroundColor3 = COLORS.hp_mid
        else
            refs.hp_fill.BackgroundColor3 = COLORS.hp_low
        end
    end

    -- ═══════════════════════════════════════
    -- Tracer
    -- ═══════════════════════════════════════
    if refs.tracer then
        refs.tracer.Visible = STATE.esp_tracer and STATE.esp_enabled
        if STATE.esp_tracer then
            local vp = Camera.ViewportSize
            refs.tracer.From = Vector2.new(vp.X / 2, vp.Y)
            refs.tracer.To = Vector2.new(screen_pos.X, screen_pos.Y)
        end
    end

    -- ═══════════════════════════════════════
    -- Skeleton
    -- ═══════════════════════════════════════
    update_skeleton(refs, char)
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
-- 7. RADAR
-- ============================================================
local function create_radar()
    if RADAR_FRAME then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "TLF_Radar"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 170, 0, 170)
    frame.Position = UDim2.new(1, -190, 0, 90)
    frame.BackgroundColor3 = Color3.fromRGB(11, 12, 16)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Parent = gui

    local f_corner = Instance.new("UICorner")
    f_corner.CornerRadius = UDim.new(1, 0)
    f_corner.Parent = frame

    local f_stroke = Instance.new("UIStroke")
    f_stroke.Color = Color3.fromRGB(90, 100, 130)
    f_stroke.Thickness = 1.5
    f_stroke.Transparency = 0.4
    f_stroke.Parent = frame

    local center_dot = Instance.new("Frame")
    center_dot.Size = UDim2.new(0, 8, 0, 8)
    center_dot.Position = UDim2.new(0.5, -4, 0.5, -4)
    center_dot.BackgroundColor3 = COLORS.hp_high
    center_dot.BorderSizePixel = 0
    center_dot.Parent = frame

    local dot_corner = Instance.new("UICorner")
    dot_corner.CornerRadius = UDim.new(1, 0)
    dot_corner.Parent = center_dot

    local north = Instance.new("TextLabel")
    north.Size = UDim2.new(0, 20, 0, 14)
    north.Position = UDim2.new(0.5, -10, 0, 4)
    north.BackgroundTransparency = 1
    north.Text = "N"
    north.TextColor3 = Color3.fromRGB(90, 95, 115)
    north.Font = Enum.Font.GothamBold
    north.TextSize = 10
    north.Active = false
    north.Parent = frame

    RADAR_FRAME = frame
end

local function update_radar()
    if not STATE.radar_enabled then
        for _, dot in pairs(RADAR_DOTS) do dot.Visible = false end
        return
    end
    if not RADAR_FRAME then create_radar() end

    local my_root = get_root(LocalPlayer)
    if not my_root then return end

    local radius = RADAR_FRAME.AbsoluteSize.X / 2
    local scale = radius / 500

    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and is_alive(player)
            and is_enemy(player) then
            local dot = RADAR_DOTS[player]
            if not dot then
                dot = Instance.new("Frame")
                dot.Size = UDim2.new(0, 6, 0, 6)
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.BorderSizePixel = 0
                dot.Parent = RADAR_FRAME

                local dot_corner = Instance.new("UICorner")
                dot_corner.CornerRadius = UDim.new(1, 0)
                dot_corner.Parent = dot

                RADAR_DOTS[player] = dot
            end
            local prp = get_root(player)
            if prp then
                local rel = prp.Position - my_root.Position
                local v2 = Vector2.new(rel.X, rel.Z) * scale
                local mag = v2.Magnitude
                if mag > radius - 6 then
                    v2 = v2.Unit * (radius - 6)
                end
                dot.Position = UDim2.new(0.5, v2.X, 0.5, v2.Y)
                dot.BackgroundColor3 = COLORS.enemy
                dot.Visible = true
                seen[player] = true
            end
        end
    end
    for player, dot in pairs(RADAR_DOTS) do
        if not seen[player] then dot.Visible = false end
    end
end

-- ============================================================
-- 8. SILENT AIM
-- ============================================================
local function get_hit_part(plr)
    if STATE.sa_hit_part == "Head" then return get_head(plr) end
    if STATE.sa_hit_part == "Torso" then return get_torso(plr) end
    return get_root(plr)
end

local function get_aim_position(plr)
    local part = get_hit_part(plr)
    if not part then return nil end
    local pos = part.Position
    if STATE.sa_prediction > 0 and part.AssemblyLinearVelocity then
        pos = pos + part.AssemblyLinearVelocity * STATE.sa_prediction
    end
    if STATE.sa_hit_part == "Head" then
        pos = pos + Vector3.new(0, part.Size.Y * 0.5, 0)
    end
    return pos
end

local function is_visible(plr)
    if not STATE.sa_visible_only then return true end
    local my_char = LocalPlayer.Character
    if not my_char then return false end
    local my_head = my_char:FindFirstChild("Head")
    if not my_head then return false end
    local target_part = get_hit_part(plr)
    if not target_part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { my_char, target_part.Parent }
    local ray = Workspace:Raycast(
        my_head.Position,
        target_part.Position - my_head.Position, params)
    return ray == nil
end

local function get_fov_target()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best_target, best_score = nil, math.huge
    local my_root = get_root(LocalPlayer)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and is_alive(plr)
            and is_enemy_sa(plr) then
            local pos = get_aim_position(plr)
            if pos and is_visible(plr) then
                local sp, on_screen = Camera:WorldToViewportPoint(pos)
                if on_screen then
                    local sv = Vector2.new(sp.X, sp.Y)
                    local dc = (sv - center).Magnitude
                    local vpd = math.sqrt(vp.X^2 + vp.Y^2)
                    local fov_px = (vpd / 2)
                        * math.tan(math.rad(STATE.sa_fov / 2))
                        / math.tan(math.rad(Camera.FieldOfView / 2))
                    if dc <= fov_px then
                        local score
                        if STATE.sa_target_mode == "closest" then
                            score = my_root
                                and (pos - my_root.Position).Magnitude or dc
                        elseif STATE.sa_target_mode == "crosshair" then
                            score = dc
                        elseif STATE.sa_target_mode == "health_lowest" then
                            local hum = get_hum(plr)
                            score = hum and hum.Health or 1000
                        else
                            score = dc
                        end
                        if score < best_score then
                            best_score = score
                            best_target = plr
                        end
                    end
                end
            end
        end
    end
    return best_target
end

local function rewrite_args(args)
    if not CURRENT_TARGET then return args end
    local aim_pos = get_aim_position(CURRENT_TARGET)
    if not aim_pos then return args end
    local my_char = LocalPlayer.Character
    if not my_char then return args end
    local my_head = my_char:FindFirstChild("Head")
    if not my_head then return args end

    local origin = my_head.Position
    local new_dir = (aim_pos - origin).Unit

    for i, arg in ipairs(args) do
        local t = typeof(arg)
        if t == "Vector3" then
            if math.abs(arg.Magnitude - 1) < 0.1 then
                args[i] = new_dir
            elseif (arg - origin).Magnitude > 5 then
                args[i] = aim_pos
            end
        elseif t == "CFrame" then
            args[i] = CFrame.new(origin, aim_pos)
        elseif t == "table" then
            for k, v in pairs(arg) do
                if typeof(v) == "Vector3" then
                    if math.abs(v.Magnitude - 1) < 0.1 then
                        arg[k] = new_dir
                    elseif (v - origin).Magnitude > 5 then
                        arg[k] = aim_pos
                    end
                elseif typeof(v) == "CFrame" then
                    arg[k] = CFrame.new(origin, aim_pos)
                end
            end
        end
    end
    return args
end

local function try_hook_hookmetamethod()
    if type(hookmetamethod) ~= "function" then return false end
    if not getrawmetatable then return false end
    local ok = pcall(function()
        local original
        original = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer"
                or method == "InvokeServer"
                or method == "Fire" then
                if STATE.sa_enabled and CURRENT_TARGET then
                    local args = {...}
                    args = rewrite_args(args)
                    return original(self, table.unpack(args))
                end
            end
            return original(self, ...)
        end)
    end)
    return ok
end

local function try_hook_metatable()
    if type(getrawmetatable) ~= "function" then return false end
    if type(setreadonly) ~= "function" then return false end
    local count = 0
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent")
            or obj:IsA("RemoteFunction")
            or obj:IsA("UnreliableRemoteEvent") then
            pcall(function()
                local mt = getrawmetatable(obj)
                if not mt or HOOKED[obj] then return end
                setreadonly(mt, false)
                local old = mt.__index
                mt.__index = function(self, key)
                    if self == obj
                        and (key == "FireServer"
                            or key == "InvokeServer"
                            or key == "Fire") then
                        return function(_, ...)
                            local args = {...}
                            if STATE.sa_enabled and CURRENT_TARGET then
                                args = rewrite_args(args)
                            end
                            return old(self, key)(_, table.unpack(args))
                        end
                    end
                    return old(self, key)
                end
                setreadonly(mt, true)
                HOOKED[obj] = true
                count = count + 1
            end)
        end
    end
    return count > 0
end

local function install_hook()
    if try_hook_hookmetamethod() then
        HOOK_METHOD = "hookmetamethod"
        return true
    end
    if try_hook_metatable() then
        HOOK_METHOD = "getrawmetatable"
        return true
    end
    HOOK_METHOD = nil
    return false
end

local function update_fov_circle()
    if not HAS_DRAWING then return end
    if STATE.sa_draw_fov and STATE.sa_enabled then
        if not FOV_CIRCLE then
            FOV_CIRCLE = Drawing.new("Circle")
            FOV_CIRCLE.Thickness = 1.5
            FOV_CIRCLE.Color = Color3.fromRGB(255, 200, 80)
            FOV_CIRCLE.Transparency = 0.7
            FOV_CIRCLE.Filled = false
            FOV_CIRCLE.NumSides = 60
        end
        local vp = Camera.ViewportSize
        FOV_CIRCLE.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        FOV_CIRCLE.Radius = (vp.X / 2)
            * math.tan(math.rad(STATE.sa_fov / 2))
            / math.tan(math.rad(Camera.FieldOfView / 2))
        FOV_CIRCLE.Visible = true
    elseif FOV_CIRCLE then
        FOV_CIRCLE.Visible = false
    end
end

task.spawn(function()
    task.wait(1)
    if install_hook() then
        print("[SA] Hook installed:", HOOK_METHOD)
    end
end)

-- ============================================================
-- 9. RAYFIELD UI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "TLF Hub Pro",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by ALPHA XK",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TLF_Hub",
        FileName = "config",
    },
    KeySystem = false,
})

-- TAB: ESP
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("Main")

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "esp_enabled",
    Callback = function(v)
        STATE.esp_enabled = v
        refresh_esp()
    end,
})

ESPTab:CreateToggle({
    Name = "Box",
    CurrentValue = true,
    Flag = "esp_box",
    Callback = function(v) STATE.esp_box = v end,
})

ESPTab:CreateToggle({
    Name = "Double Box",
    CurrentValue = true,
    Flag = "esp_double_box",
    Callback = function(v) STATE.esp_double_box = v end,
})

ESPTab:CreateToggle({
    Name = "Head Dot",
    CurrentValue = true,
    Flag = "esp_head_dot",
    Callback = function(v) STATE.esp_head_dot = v end,
})

ESPTab:CreateToggle({
    Name = "Arrow",
    CurrentValue = true,
    Flag = "esp_arrow",
    Callback = function(v) STATE.esp_arrow = v end,
})

ESPTab:CreateSection("Info")

ESPTab:CreateToggle({
    Name = "Name",
    CurrentValue = true,
    Flag = "esp_name",
    Callback = function(v) STATE.esp_name = v end,
})

ESPTab:CreateToggle({
    Name = "Health",
    CurrentValue = true,
    Flag = "esp_health",
    Callback = function(v) STATE.esp_health = v end,
})

ESPTab:CreateToggle({
    Name = "Distance",
    CurrentValue = true,
    Flag = "esp_distance",
    Callback = function(v) STATE.esp_distance = v end,
})

ESPTab:CreateToggle({
    Name = "Weapon",
    CurrentValue = false,
    Flag = "esp_weapon",
    Callback = function(v) STATE.esp_weapon = v end,
})

ESPTab:CreateSection("Advanced")

ESPTab:CreateToggle({
    Name = "Skeleton",
    CurrentValue = false,
    Flag = "esp_skeleton",
    Callback = function(v) STATE.esp_skeleton = v end,
})

ESPTab:CreateToggle({
    Name = "Tracer",
    CurrentValue = false,
    Flag = "esp_tracer",
    Callback = function(v) STATE.esp_tracer = v end,
})

ESPTab:CreateSlider({
    Name = "Max Distance",
    Range = {100, 5000},
    Increment = 100,
    Suffix = "m",
    CurrentValue = 1500,
    Flag = "esp_max_dist",
    Callback = function(v) STATE.esp_max_dist = v end,
})

-- TAB: Enemy Filter
local FilterTab = Window:CreateTab("Enemy Filter", 4483362458)

FilterTab:CreateSection("Detection Methods")

FilterTab:CreateToggle({
    Name = "Team Object",
    CurrentValue = true,
    Flag = "filter_team",
    Callback = function(v) STATE.filter_team = v end,
})

FilterTab:CreateToggle({
    Name = "TeamColor",
    CurrentValue = true,
    Flag = "filter_teamcolor",
    Callback = function(v) STATE.filter_teamcolor = v end,
})

FilterTab:CreateToggle({
    Name = "Character Attribute",
    CurrentValue = true,
    Flag = "filter_attribute",
    Callback = function(v) STATE.filter_attribute = v end,
})

FilterTab:CreateToggle({
    Name = "Player Attribute",
    CurrentValue = true,
    Flag = "filter_character",
    Callback = function(v) STATE.filter_character = v end,
})

FilterTab:CreateSection("Note")

FilterTab:CreateLabel("إذا كان ESP يعرض فريقي،")
FilterTab:CreateLabel("شغّل كل الفلاتر أعلاه.")

-- TAB: Radar
local RadarTab = Window:CreateTab("Radar", 4483362458)

RadarTab:CreateToggle({
    Name = "Enable Radar",
    CurrentValue = false,
    Flag = "radar_enabled",
    Callback = function(v)
        STATE.radar_enabled = v
        if v then create_radar() end
    end,
})

-- TAB: Silent Aim
local SATab = Window:CreateTab("Silent Aim", 4483362458)

SATab:CreateSection("Main")

SATab:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = false,
    Flag = "sa_enabled",
    Callback = function(v) STATE.sa_enabled = v end,
})

SATab:CreateToggle({
    Name = "Visible Only",
    CurrentValue = false,
    Flag = "sa_visible_only",
    Callback = function(v) STATE.sa_visible_only = v end,
})

SATab:CreateToggle({
    Name = "Draw FOV",
    CurrentValue = true,
    Flag = "sa_draw_fov",
    Callback = function(v) STATE.sa_draw_fov = v end,
})

SATab:CreateSection("Targeting")

SATab:CreateSlider({
    Name = "FOV",
    Range = {10, 360},
    Increment = 5,
    Suffix = "°",
    CurrentValue = 90,
    Flag = "sa_fov",
    Callback = function(v) STATE.sa_fov = v end,
})

SATab:CreateSlider({
    Name = "Prediction",
    Range = {0, 0.3},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.05,
    Flag = "sa_prediction",
    Callback = function(v) STATE.sa_prediction = v end,
})

SATab:CreateDropdown({
    Name = "Hit Part",
    Options = {"Head", "Torso", "HumanoidRootPart"},
    CurrentOption = {"Head"},
    Flag = "sa_hit_part",
    Callback = function(opt)
        if type(opt) == "table" then opt = opt[1] end
        STATE.sa_hit_part = opt
    end,
})

SATab:CreateDropdown({
    Name = "Target Mode",
    Options = {"closest", "crosshair", "health_lowest"},
    CurrentOption = {"closest"},
    Flag = "sa_target_mode",
    Callback = function(opt)
        if type(opt) == "table" then opt = opt[1] end
        STATE.sa_target_mode = opt
    end,
})

SATab:CreateSection("Debug")

SATab:CreateButton({
    Name = "Re-install Hook",
    Callback = function()
        HOOKED = {}
        install_hook()
        Rayfield:Notify({
            Title = "Hook",
            Content = "Method: " .. tostring(HOOK_METHOD),
            Duration = 3,
        })
    end,
})

-- TAB: Settings
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Info")

SettingsTab:CreateLabel("TLF Hub v6")
SettingsTab:CreateLabel("by ALPHA XK")
SettingsTab:CreateLabel("GameId: 102871156420149")

SettingsTab:CreateSection("Actions")

SettingsTab:CreateButton({
    Name = "Destroy All",
    Callback = function()
        for _, refs in pairs(ESP_OBJECTS) do
            if refs.gui and refs.gui.Parent then refs.gui:Destroy() end
            if refs.tracer and refs.tracer.Remove then
                pcall(function() refs.tracer:Remove() end)
            end
            if refs.skeleton_lines then
                for _, sk in ipairs(refs.skeleton_lines) do
                    if sk.line and sk.line.Remove then
                        pcall(function() sk.line:Remove() end)
                    end
                end
            end
        end
        if RADAR_FRAME and RADAR_FRAME.Parent then
            RADAR_FRAME.Parent:Destroy()
        end
        if FOV_CIRCLE then
            pcall(function() FOV_CIRCLE:Remove() end)
        end
        Rayfield:Destroy()
    end,
})

-- ============================================================
-- 10. RENDER LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    pcall(function()
        if STATE.esp_enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    if not ESP_OBJECTS[plr] then
                        create_esp_for(plr)
                    end
                    update_esp_for(plr)
                end
            end
        end

        if STATE.radar_enabled then
            update_radar()
        end

        if STATE.sa_enabled then
            CURRENT_TARGET = get_fov_target()
        else
            CURRENT_TARGET = nil
        end

        update_fov_circle()
    end)
end)

Players.PlayerAdded:Connect(function(plr)
    if STATE.esp_enabled then
        task.defer(function()
            plr.CharacterAdded:Wait()
            create_esp_for(plr)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    remove_esp_for(plr)
    if RADAR_DOTS[plr] then
        RADAR_DOTS[plr]:Destroy()
        RADAR_DOTS[plr] = nil
    end
end)

-- ============================================================
-- 11. EXPORTS
-- ============================================================
getgenv().__TLF_HUB = {
    STATE = STATE,
    get_target = function() return CURRENT_TARGET end,
    get_hook_method = function() return HOOK_METHOD end,
    reinstall_hook = function()
        HOOKED = {}
        return install_hook()
    end,
}

-- ============================================================
-- 12. LOADING DONE
-- ============================================================
Rayfield:LoadConfiguration()

print("[TLF HUB v6] جاهز — ABSOLUTE KODE، يا ريدز")
print("[TLF HUB v6] Hook:", tostring(HOOK_METHOD))
print("[TLF HUB v6] ⚠ خطر حظر")
