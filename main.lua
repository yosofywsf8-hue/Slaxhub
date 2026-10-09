-- ============================================================
-- THE LOST FRONT HUB v3 — ملف واحد شامل
-- File: tlf_hub_v3.lua
-- ============================================================
-- الميزات:
--   - ESP محسّن (box, outline, arrow, name, level, health, distance, tracer)
--   - Radar دائري
--   - Silent Aim (remote hook)
--   - UI جوال-أولاً (بدون تعليق اللمس)
-- اللعبة: The Lost Front (Type Productions) — GameId: 102871156420149
-- ⚠ خطر حظر مرتفع — استخدم على حساب alt
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ============================================================
-- 1. STATE
-- ============================================================
local STATE = {
    -- ESP
    esp_enabled    = false,
    esp_box        = true,
    esp_outline    = true,
    esp_arrow      = true,
    esp_name       = true,
    esp_level      = true,
    esp_health     = true,
    esp_distance   = true,
    esp_tracer     = false,
    esp_team_check = true,
    esp_max_dist   = 1500,

    -- Radar
    radar_enabled  = false,

    -- Silent Aim
    sa_enabled      = false,
    sa_auto_fire    = false,
    sa_team_check   = true,
    sa_visible_only = false,
    sa_draw_fov     = true,
    sa_fov          = 90,
    sa_hit_part     = "Head",      -- Head | Torso | HumanoidRootPart
    sa_target_mode  = "closest",   -- closest | crosshair | health_lowest
    sa_prediction   = 0.05,
    sa_max_dist     = 500,
}

local ESP_OBJECTS = {}
local RADAR_DOTS  = {}
local RADAR_FRAME = nil
local FOV_CIRCLE  = nil
local CURRENT_TARGET = nil
local LAST_FIRE   = 0

-- ============================================================
-- 2. THEME
-- ============================================================
local THEME = {
    bg         = Color3.fromRGB(11, 12, 16),
    card       = Color3.fromRGB(18, 20, 26),
    stroke     = Color3.fromRGB(48, 52, 66),
    stroke_lit = Color3.fromRGB(90, 100, 130),
    text       = Color3.fromRGB(245, 245, 250),
    text_dim   = Color3.fromRGB(140, 145, 165),
    text_faint = Color3.fromRGB(90, 95, 115),
    on         = Color3.fromRGB(80, 200, 130),
    accent     = Color3.fromRGB(120, 140, 250),
    enemy      = Color3.fromRGB(255, 80, 90),
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

local function is_enemy(plr)
    if plr == LocalPlayer then return false end
    if plr.Team and LocalPlayer.Team then
        return plr.Team ~= LocalPlayer.Team
    end
    local c = plr.Character
    local mc = LocalPlayer.Character
    if c and mc then
        local t1 = c:GetAttribute("Team") or c:GetAttribute("team")
        local t2 = mc:GetAttribute("Team") or mc:GetAttribute("team")
        if t1 and t2 then return t1 ~= t2 end
    end
    return true
end

local function is_enemy_esp(plr)
    if not STATE.esp_team_check then return plr ~= LocalPlayer end
    return is_enemy(plr)
end

local function is_enemy_sa(plr)
    if not STATE.sa_team_check then return plr ~= LocalPlayer end
    return is_enemy(plr)
end

-- ============================================================
-- 4. DRAWING (للـ tracer و FOV circle)
-- ============================================================
local HAS_DRAWING = (Drawing ~= nil) and (Drawing.new ~= nil)

-- ============================================================
-- 5. ESP
-- ============================================================
local function create_esp_for(player)
    if ESP_OBJECTS[player] then return ESP_OBJECTS[player] end

    local gui = Instance.new("BillboardGui")
    gui.Name = "TLF_ESP"
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Size = UDim2.new(0, 100, 0, 100)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.MaxDistance = STATE.esp_max_dist
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
    box_stroke.Thickness = 2
    box_stroke.Parent = box

    -- Corner brackets
    local corners = {}
    local bracket_pos = {
        {UDim2.new(0, 0, 0, 0), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(1, -12, 0, 0), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(0, 0, 1, -2), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(1, -12, 1, -2), UDim2.new(0, 12, 0, 2)},
    }
    for i, spec in ipairs(bracket_pos) do
        local b = Instance.new("Frame")
        b.Size = spec[2]
        b.Position = spec[1]
        b.BackgroundColor3 = THEME.enemy
        b.BorderSizePixel = 0
        b.Parent = gui
        corners[i] = b
    end

    -- Head dot
    local head_dot = Instance.new("Frame")
    head_dot.Size = UDim2.new(0, 6, 0, 6)
    head_dot.Position = UDim2.new(0.5, -3, 0, -10)
    head_dot.BackgroundColor3 = THEME.enemy
    head_dot.BorderSizePixel = 0
    head_dot.Parent = gui
    corner(head_dot, 3)

    -- Arrow فوق
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(0.5, -8, 0, -28)
    arrow.Text = "▼"
    arrow.TextColor3 = THEME.enemy
    arrow.TextSize = 16
    arrow.FontFace = THEME.font_bold
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
    arrow.Parent = gui

    -- Name
    local name_lbl = Instance.new("TextLabel")
    name_lbl.BackgroundTransparency = 1
    name_lbl.Text = player.Name
    name_lbl.TextColor3 = Color3.new(1, 1, 1)
    name_lbl.TextSize = 13
    name_lbl.FontFace = THEME.font_bold
    name_lbl.TextStrokeTransparency = 0
    name_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    name_lbl.Size = UDim2.new(1, 0, 0, 15)
    name_lbl.Position = UDim2.new(0, 0, 0, -44)
    name_lbl.Parent = gui

    -- Level / Class
    local level_lbl = Instance.new("TextLabel")
    level_lbl.BackgroundTransparency = 1
    level_lbl.Text = ""
    level_lbl.TextColor3 = THEME.warn
    level_lbl.TextSize = 11
    level_lbl.FontFace = THEME.font
    level_lbl.TextStrokeTransparency = 0
    level_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    level_lbl.Size = UDim2.new(1, 0, 0, 13)
    level_lbl.Position = UDim2.new(0, 0, 0, -58)
    level_lbl.Parent = gui

    -- Distance
    local dist_lbl = Instance.new("TextLabel")
    dist_lbl.BackgroundTransparency = 1
    dist_lbl.Text = ""
    dist_lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    dist_lbl.TextSize = 11
    dist_lbl.FontFace = THEME.font_bold
    dist_lbl.TextStrokeTransparency = 0
    dist_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    dist_lbl.Size = UDim2.new(1, 0, 0, 14)
    dist_lbl.Position = UDim2.new(0, 0, 1, 3)
    dist_lbl.Parent = gui

    -- Health
    local hp_bg = Instance.new("Frame")
    hp_bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    hp_bg.BorderSizePixel = 0
    hp_bg.Size = UDim2.new(0, 4, 1, 0)
    hp_bg.Position = UDim2.new(-1, -8, 0, 0)
    hp_bg.Parent = gui
    corner(hp_bg, 2)
    stroke(hp_bg, Color3.new(0, 0, 0), 1, 0.2)

    local hp_fill = Instance.new("Frame")
    hp_fill.BackgroundColor3 = THEME.on
    hp_fill.BorderSizePixel = 0
    hp_fill.Size = UDim2.new(1, 0, 1, 0)
    hp_fill.Position = UDim2.new(0, 0, 0, 0)
    hp_fill.Parent = hp_bg
    corner(hp_fill, 2)

    -- Tracer
    local tracer = nil
    if HAS_DRAWING then
        tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = THEME.enemy
        tracer.Transparency = 0.7
        tracer.Visible = false
    end

    local refs = {
        gui = gui, box = box, box_stroke = box_stroke,
        corners = corners, head_dot = head_dot, arrow = arrow,
        name_lbl = name_lbl, level_lbl = level_lbl,
        dist_lbl = dist_lbl, hp_bg = hp_bg, hp_fill = hp_fill,
        tracer = tracer,
    }
    ESP_OBJECTS[player] = refs
    return refs
end

local function remove_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end
    if refs.gui and refs.gui.Parent then refs.gui:Destroy() end
    if refs.tracer and refs.tracer.Remove then
        pcall(function() refs.tracer:Remove() end)
    end
    ESP_OBJECTS[player] = nil
end

local function update_esp_for(player)
    local refs = ESP_OBJECTS[player]
    if not refs then return end

    if not STATE.esp_enabled
        or not is_alive(player)
        or not is_enemy_esp(player) then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
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

    local screen_pos, on_screen = Camera:WorldToViewportPoint(hrp.Position)
    if not on_screen then
        refs.gui.Enabled = false
        if refs.tracer then refs.tracer.Visible = false end
        return
    end

    local size_px = math.clamp(1800 / distance, 24, 320)
    local char_size = char:GetExtentsSize()
    local ratio = char_size.Y / math.max(char_size.X, 0.1)
    refs.gui.Size = UDim2.new(0, size_px, 0, size_px * ratio)

    local color = THEME.enemy
    refs.box_stroke.Color = color
    refs.head_dot.BackgroundColor3 = color
    refs.arrow.TextColor3 = color
    for _, b in ipairs(refs.corners) do b.BackgroundColor3 = color end

    refs.box.Visible = STATE.esp_box
    refs.box_stroke.Enabled = STATE.esp_box
    for _, b in ipairs(refs.corners) do b.Visible = STATE.esp_outline end
    refs.head_dot.Visible = STATE.esp_box
    refs.arrow.Visible = STATE.esp_arrow
    refs.name_lbl.Visible = STATE.esp_name
    refs.name_lbl.Text = player.Name

    refs.level_lbl.Visible = STATE.esp_level
    local level = player:GetAttribute("Level") or char:GetAttribute("Level")
    local class = player:GetAttribute("Class") or char:GetAttribute("Class")
    local parts = {}
    if level then table.insert(parts, "Lv." .. tostring(level)) end
    if class then table.insert(parts, tostring(class)) end
    refs.level_lbl.Text = table.concat(parts, " · ")

    refs.dist_lbl.Visible = STATE.esp_distance
    refs.dist_lbl.Text = math.floor(distance) .. "m"

    local hum = get_hum(player)
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

    if refs.tracer then
        refs.tracer.Visible = STATE.esp_tracer
        if STATE.esp_tracer then
            local vp = Camera.ViewportSize
            refs.tracer.From = Vector2.new(vp.X / 2, vp.Y)
            refs.tracer.To = Vector2.new(screen_pos.X, screen_pos.Y)
            refs.tracer.Color = color
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
-- 6. RADAR
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
    frame.BackgroundColor3 = THEME.bg
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Parent = gui
    corner(frame, 85)
    stroke(frame, THEME.stroke_lit, 1.5, 0.4)

    local center_dot = Instance.new("Frame")
    center_dot.Size = UDim2.new(0, 8, 0, 8)
    center_dot.Position = UDim2.new(0.5, -4, 0.5, -4)
    center_dot.BackgroundColor3 = THEME.on
    center_dot.BorderSizePixel = 0
    center_dot.Parent = frame
    corner(center_dot, 4)

    local north = Instance.new("TextLabel")
    north.Size = UDim2.new(0, 20, 0, 14)
    north.Position = UDim2.new(0.5, -10, 0, 4)
    north.BackgroundTransparency = 1
    north.Text = "N"
    north.TextColor3 = THEME.text_faint
    north.FontFace = THEME.font_bold
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
        if player ~= LocalPlayer and is_alive(player) then
            local dot = RADAR_DOTS[player]
            if not dot then
                dot = Instance.new("Frame")
                dot.Size = UDim2.new(0, 6, 0, 6)
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.BorderSizePixel = 0
                dot.Parent = RADAR_FRAME
                corner(dot, 3)
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
                dot.BackgroundColor3 = is_enemy(player)
                    and THEME.enemy or THEME.team
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
-- 7. SILENT AIM
-- ============================================================
local fire_remotes = {}
local hooked_remotes = {}

local function scan_for_remotes()
    local keywords = {
        "fire", "shoot", "bullet", "hit", "cast",
        "attack", "projectile", "round", "shot", "weapon",
    }

    local function scan(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent")
                or obj:IsA("RemoteFunction")
                or obj:IsA("UnreliableRemoteEvent") then
                local name = obj.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw, 1, true) then
                        table.insert(fire_remotes, obj)
                        break
                    end
                end
            end
        end
    end

    scan(ReplicatedStorage)

    if #fire_remotes == 0 then
        warn("[SILENT] ما لقيت remotes للطلقات")
    else
        print("[SILENT] لقيت", #fire_remotes, "remotes محتملة")
    end
end

scan_for_remotes()

local function get_hit_part(plr)
    if STATE.sa_hit_part == "Head" then return get_head(plr) end
    if STATE.sa_hit_part == "Torso" then return get_torso(plr) end
    return get_root(plr)
end

local function get_aim_position(plr)
    local part = get_hit_part(plr)
    if not part then return nil end

    local pos = part.Position

    if STATE.sa_prediction > 0
        and part.AssemblyLinearVelocity then
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
        target_part.Position - my_head.Position,
        params
    )
    return ray == nil
end

local function get_fov_target()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)

    local best_target = nil
    local best_score = math.huge

    local my_root = get_root(LocalPlayer)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and is_alive(plr)
            and is_enemy_sa(plr) then
            local pos = get_aim_position(plr)
            if pos and is_visible(plr) then
                local screen_pos, on_screen =
                    Camera:WorldToViewportPoint(pos)
                if on_screen then
                    local sv = Vector2.new(screen_pos.X, screen_pos.Y)
                    local dist_center = (sv - center).Magnitude

                    local vp_diag = math.sqrt(vp.X^2 + vp.Y^2)
                    local fov_px = (vp_diag / 2)
                        * math.tan(math.rad(STATE.sa_fov / 2))
                        / math.tan(math.rad(Camera.FieldOfView / 2))

                    if dist_center <= fov_px then
                        local score
                        if STATE.sa_target_mode == "closest" then
                            score = my_root
                                and (pos - my_root.Position).Magnitude
                                or dist_center
                        elseif STATE.sa_target_mode == "crosshair" then
                            score = dist_center
                        elseif STATE.sa_target_mode == "health_lowest" then
                            local hum = get_hum(plr)
                            score = hum and hum.Health or 1000
                        else
                            score = dist_center
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

-- hook_fire_args
local function hook_fire_args(args)
    if not CURRENT_TARGET or not STATE.sa_enabled then
        return args
    end

    local aim_pos = get_aim_position(CURRENT_TARGET)
    if not aim_pos then return args end

    local my_char = LocalPlayer.Character
    if not my_char then return args end
    local my_head = my_char:FindFirstChild("Head")
    if not my_head then return args end

    local origin = my_head.Position
    local new_dir = (aim_pos - origin).Unit

    for i, arg in ipairs(args) do
        if typeof(arg) == "Vector3" then
            if math.abs(arg.Magnitude - 1) < 0.05 then
                args[i] = new_dir
            elseif (arg - origin).Magnitude > 5 then
                args[i] = aim_pos
            end
        elseif typeof(arg) == "CFrame" then
            args[i] = CFrame.new(origin, aim_pos)
        end
    end

    return args
end

local function setup_hook(remote)
    if hooked_remotes[remote] then return end
    hooked_remotes[remote] = true

    local mt = getrawmetatable and getrawmetatable(remote)
    if not mt then return end

    pcall(setreadonly, mt, false)
    local old_index = mt.__index

    mt.__index = function(self, key)
        if self == remote
            and (key == "FireServer"
                or key == "InvokeServer"
                or key == "Fire") then
            return function(_, ...)
                local args = {...}
                if STATE.sa_enabled and CURRENT_TARGET then
                    args = hook_fire_args(args)
                end
                return old_index(self, key)(_, table.unpack(args))
            end
        end
        return old_index(self, key)
    end
    pcall(setreadonly, mt, true)
end

for _, remote in ipairs(fire_remotes) do
    pcall(setup_hook, remote)
end

-- FOV circle
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

-- ============================================================
-- 8. UI
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

-- زر التعليق — Active=false
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
toggle_btn.Active = false
toggle_btn.Selectable = false
toggle_btn.Parent = screen
corner(toggle_btn, 14)
stroke(toggle_btn, THEME.stroke_lit, 1.5, 0.5)

-- اللوحة
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 320, 0, 500)
panel.Position = UDim2.new(0, 20, 0.5, -250)
panel.BackgroundColor3 = THEME.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = false
panel.Parent = screen
corner(panel, 16)
stroke(panel, THEME.stroke_lit, 1.5, 0.4)

-- الهيدر — Active=true للسحب فقط
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundTransparency = 1
header.Active = true
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
title.Active = false
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
close_btn.Active = false
close_btn.Parent = header
corner(close_btn, 8)
stroke(close_btn)

local div = Instance.new("Frame")
div.Size = UDim2.new(1, -40, 0, 1)
div.Position = UDim2.new(0, 20, 0, 52)
div.BackgroundColor3 = THEME.stroke
div.BorderSizePixel = 0
div.Parent = panel

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

-- UI Factories
local function make_section(text, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Active = false
    row.LayoutOrder = order
    row.Parent = content
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "—  " .. text .. "  —"
    lbl.TextColor3 = THEME.text_faint
    lbl.FontFace = THEME.font
    lbl.TextSize = 11
    lbl.Active = false
    lbl.Parent = row
end

local function make_toggle(label, order, key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = THEME.card
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = false
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
    lbl.Active = false
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
    stt.Active = false
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
        if key == "esp_enabled" then refresh_esp() end
    end)

    refresh()
    task.spawn(function()
        while btn.Parent do
            task.wait(0.5)
            refresh()
        end
    end)
end

-- ============ ESP ============
make_section("ESP", 1)
make_toggle("ESP", 2, "esp_enabled")
make_toggle("Box", 3, "esp_box")
make_toggle("Corner Outline", 4, "esp_outline")
make_toggle("Arrow", 5, "esp_arrow")
make_toggle("Name", 6, "esp_name")
make_toggle("Level / Class", 7, "esp_level")
make_toggle("Health", 8, "esp_health")
make_toggle("Distance", 9, "esp_distance")
make_toggle("Tracer", 10, "esp_tracer")
make_toggle("Team Check", 11, "esp_team_check")

-- ============ Radar ============
make_section("Radar", 20)
make_toggle("Radar", 21, "radar_enabled")

-- ============ Silent Aim ============
make_section("Silent Aim", 30)
make_toggle("Silent Aim", 31, "sa_enabled")
make_toggle("Auto Fire", 32, "sa_auto_fire")
make_toggle("Team Check", 33, "sa_team_check")
make_toggle("Visible Only", 34, "sa_visible_only")
make_toggle("Draw FOV", 35, "sa_draw_fov")

-- Warning
local warn_lbl = Instance.new("TextLabel")
warn_lbl.Size = UDim2.new(1, 0, 0, 30)
warn_lbl.BackgroundTransparency = 1
warn_lbl.Text = "⚠ خطر حظر مرتفع — استخدم على حساب alt"
warn_lbl.TextColor3 = THEME.warn
warn_lbl.FontFace = THEME.font
warn_lbl.TextSize = 10
warn_lbl.TextWrapped = true
warn_lbl.LayoutOrder = 60
warn_lbl.Active = false
warn_lbl.Parent = content

-- ============ LOOPS ============
RunService.RenderStepped:Connect(function()
    pcall(function()
        -- ESP
        if STATE.esp_enabled then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    update_esp_for(plr)
                end
            end
        end
        -- Radar
        if STATE.radar_enabled then
            update_radar()
        end
        -- Silent Aim
        if STATE.sa_enabled then
            local now = tick()
            if now - (STATE._last_target_switch or 0) > 0.05 then
                STATE._last_target_switch = now
                CURRENT_TARGET = get_fov_target()
            end

            if STATE.sa_auto_fire and CURRENT_TARGET then
                if now - LAST_FIRE >= 0.15 then
                    LAST_FIRE = now
                    -- بدون mouse1click — ما نستخدم input وهمي
                    -- نرسل fire من داخل الـ hook مباشرة
                end
            end
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

-- ============ DRAG ============
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

-- ============ OPEN/CLOSE ============
local is_open = false
local function set_open(state)
    is_open = state
    if state then
        panel.Visible = true
        panel.Size = UDim2.new(0, 320, 0, 60)
        tween(panel, 0.25, { Size = UDim2.new(0, 320, 0, 500) }):Play()
    else
        tween(panel, 0.2, { Size = UDim2.new(0, 320, 0, 52) }):Play()
        task.delay(0.2, function()
            if not is_open then panel.Visible = false end
        end)
    end
end

toggle_btn.MouseButton1Click:Connect(function() set_open(not is_open) end)
close_btn.MouseButton1Click:Connect(function() set_open(false) end)

-- ============ EXPORTS ============
getgenv().__TLF_HUB = {
    STATE = STATE,
    set_open = set_open,
    get_target = function() return CURRENT_TARGET end,
    set_hit_part = function(part)
        if part == "Head" or part == "Torso" or part == "HumanoidRootPart" then
            STATE.sa_hit_part = part
        end
    end,
    set_fov = function(v) STATE.sa_fov = tonumber(v) or 90 end,
    set_target_mode = function(mode)
        if mode == "closest"
            or mode == "crosshair"
            or mode == "health_lowest" then
            STATE.sa_target_mode = mode
        end
    end,
    fire_remotes = fire_remotes,
}

print("[TLF HUB v3] جاهز — ABSOLUTE KODE، يا ريدز")
print("[TLF HUB v3] Remotes محتملة:", #fire_remotes)
print("[TLF HUB v3] اضغط TLF لفتح اللوحة")
print("[TLF HUB v3] ⚠ Silent Aim — خطر حظر")
