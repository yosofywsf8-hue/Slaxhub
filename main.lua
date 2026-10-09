-- ============================================================
-- THE LOST FRONT HUB v4 — Rayfield UI
-- File: tlf_hub_v4.lua
-- ============================================================
-- يشتغل على:
--   - PC و الجوال (Rayfield تدعم الجوال)
--   - Xeno, Delta, Solara, Wave, Arceus
-- ⚠ خطر حظر مرتفع — استخدم على حساب alt
-- ============================================================

-- ============================================================
-- 1. LOAD RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

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
    sa_hit_part     = "Head",
    sa_target_mode  = "closest",
    sa_prediction   = 0.05,
    sa_max_dist     = 500,
}

local ESP_OBJECTS = {}
local RADAR_DOTS  = {}
local RADAR_FRAME = nil
local FOV_CIRCLE  = nil
local CURRENT_TARGET = nil

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
-- 5. ESP
-- ============================================================
local HAS_DRAWING = (Drawing ~= nil) and (Drawing.new ~= nil)

local ESP_COLORS = {
    enemy = Color3.fromRGB(255, 80, 90),
    team  = Color3.fromRGB(80, 180, 240),
    on    = Color3.fromRGB(80, 200, 130),
    warn  = Color3.fromRGB(240, 180, 70),
}

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
    box_stroke.Color = ESP_COLORS.enemy
    box_stroke.Thickness = 2
    box_stroke.Parent = box

    -- Corner brackets
    local corners = {}
    local bracket_specs = {
        {UDim2.new(0, 0, 0, 0), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(1, -12, 0, 0), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(0, 0, 1, -2), UDim2.new(0, 12, 0, 2)},
        {UDim2.new(1, -12, 1, -2), UDim2.new(0, 12, 0, 2)},
    }
    for i, spec in ipairs(bracket_specs) do
        local b = Instance.new("Frame")
        b.Size = spec[2]
        b.Position = spec[1]
        b.BackgroundColor3 = ESP_COLORS.enemy
        b.BorderSizePixel = 0
        b.Parent = gui
        corners[i] = b
    end

    -- Head dot
    local head_dot = Instance.new("Frame")
    head_dot.Size = UDim2.new(0, 6, 0, 6)
    head_dot.Position = UDim2.new(0.5, -3, 0, -10)
    head_dot.BackgroundColor3 = ESP_COLORS.enemy
    head_dot.BorderSizePixel = 0
    head_dot.Parent = gui

    local dot_corner = Instance.new("UICorner")
    dot_corner.CornerRadius = UDim.new(1, 0)
    dot_corner.Parent = head_dot

    -- Arrow
    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(0.5, -8, 0, -28)
    arrow.Text = "▼"
    arrow.TextColor3 = ESP_COLORS.enemy
    arrow.TextSize = 16
    arrow.Font = Enum.Font.GothamBold
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
    arrow.Parent = gui

    -- Name
    local name_lbl = Instance.new("TextLabel")
    name_lbl.BackgroundTransparency = 1
    name_lbl.Text = player.Name
    name_lbl.TextColor3 = Color3.new(1, 1, 1)
    name_lbl.TextSize = 13
    name_lbl.Font = Enum.Font.GothamBold
    name_lbl.TextStrokeTransparency = 0
    name_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    name_lbl.Size = UDim2.new(1, 0, 0, 15)
    name_lbl.Position = UDim2.new(0, 0, 0, -44)
    name_lbl.Parent = gui

    -- Level
    local level_lbl = Instance.new("TextLabel")
    level_lbl.BackgroundTransparency = 1
    level_lbl.Text = ""
    level_lbl.TextColor3 = ESP_COLORS.warn
    level_lbl.TextSize = 11
    level_lbl.Font = Enum.Font.Gotham
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
    dist_lbl.Font = Enum.Font.GothamBold
    dist_lbl.TextStrokeTransparency = 0
    dist_lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    dist_lbl.Size = UDim2.new(1, 0, 0, 14)
    dist_lbl.Position = UDim2.new(0, 0, 1, 3)
    dist_lbl.Parent = gui

    -- HP bar
    local hp_bg = Instance.new("Frame")
    hp_bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    hp_bg.BorderSizePixel = 0
    hp_bg.Size = UDim2.new(0, 4, 1, 0)
    hp_bg.Position = UDim2.new(-1, -8, 0, 0)
    hp_bg.Parent = gui

    local hp_bg_corner = Instance.new("UICorner")
    hp_bg_corner.CornerRadius = UDim.new(1, 0)
    hp_bg_corner.Parent = hp_bg

    local hp_fill = Instance.new("Frame")
    hp_fill.BackgroundColor3 = ESP_COLORS.on
    hp_fill.BorderSizePixel = 0
    hp_fill.Size = UDim2.new(1, 0, 1, 0)
    hp_fill.Position = UDim2.new(0, 0, 0, 0)
    hp_fill.Parent = hp_bg

    local hp_fill_corner = Instance.new("UICorner")
    hp_fill_corner.CornerRadius = UDim.new(1, 0)
    hp_fill_corner.Parent = hp_fill

    -- Tracer
    local tracer = nil
    if HAS_DRAWING then
        tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = ESP_COLORS.enemy
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

    local color = ESP_COLORS.enemy
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
            refs.hp_fill.BackgroundColor3 = ESP_COLORS.on
        elseif pct > 0.3 then
            refs.hp_fill.BackgroundColor3 = ESP_COLORS.warn
        else
            refs.hp_fill.BackgroundColor3 = ESP_COLORS.enemy
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
    center_dot.BackgroundColor3 = ESP_COLORS.on
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
        if player ~= LocalPlayer and is_alive(player) then
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
                dot.BackgroundColor3 = is_enemy(player)
                    and ESP_COLORS.enemy or ESP_COLORS.team
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

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
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

local function hook_fire_args(args)
    if not CURRENT_TARGET or not STATE.sa_enabled then return args end

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
-- 8. RAYFIELD UI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "The Lost Front Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by ALPHA XK",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TLF_Hub",
        FileName = "config",
    },
    KeySystem = false,
})

-- ============================================================
-- TAB: ESP
-- ============================================================
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("ESP Main")

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
    Name = "Corner Outline",
    CurrentValue = true,
    Flag = "esp_outline",
    Callback = function(v) STATE.esp_outline = v end,
})

ESPTab:CreateToggle({
    Name = "Arrow",
    CurrentValue = true,
    Flag = "esp_arrow",
    Callback = function(v) STATE.esp_arrow = v end,
})

ESPTab:CreateToggle({
    Name = "Head Dot",
    CurrentValue = true,
    Flag = "esp_head_dot",
    Callback = function(v) STATE.esp_box = STATE.esp_box end,
})

ESPTab:CreateSection("Info")

ESPTab:CreateToggle({
    Name = "Name",
    CurrentValue = true,
    Flag = "esp_name",
    Callback = function(v) STATE.esp_name = v end,
})

ESPTab:CreateToggle({
    Name = "Level / Class",
    CurrentValue = true,
    Flag = "esp_level",
    Callback = function(v) STATE.esp_level = v end,
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
    Name = "Tracer",
    CurrentValue = false,
    Flag = "esp_tracer",
    Callback = function(v) STATE.esp_tracer = v end,
})

ESPTab:CreateSection("Filters")

ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Flag = "esp_team_check",
    Callback = function(v) STATE.esp_team_check = v end,
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

-- ============================================================
-- TAB: Radar
-- ============================================================
local RadarTab = Window:CreateTab("Radar", 4483362458)

RadarTab:CreateSection("Radar")

RadarTab:CreateToggle({
    Name = "Enable Radar",
    CurrentValue = false,
    Flag = "radar_enabled",
    Callback = function(v)
        STATE.radar_enabled = v
        if v then create_radar() end
    end,
})

-- ============================================================
-- TAB: Silent Aim
-- ============================================================
local SATab = Window:CreateTab("Silent Aim", 4483362458)

SATab:CreateSection("Main")

SATab:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = false,
    Flag = "sa_enabled",
    Callback = function(v) STATE.sa_enabled = v end,
})

SATab:CreateToggle({
    Name = "Auto Fire",
    CurrentValue = false,
    Flag = "sa_auto_fire",
    Callback = function(v) STATE.sa_auto_fire = v end,
})

SATab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Flag = "sa_team_check",
    Callback = function(v) STATE.sa_team_check = v end,
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

SATab:CreateSection("تحذير")

SATab:CreateLabel("⚠ خطر حظر مرتفع — استخدم على حساب alt")
SATab:CreateLabel("The Lost Front عندها anti-cheat قوي")
SATab:CreateLabel("Remotes المكتشفة: " .. #fire_remotes)

-- ============================================================
-- TAB: Settings
-- ============================================================
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Info")

SettingsTab:CreateLabel("TLF Hub v4")
SettingsTab:CreateLabel("by ALPHA XK")
SettingsTab:CreateLabel("GameId: 102871156420149")

SettingsTab:CreateSection("Actions")

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        Rayfield:Destroy()
        for _, refs in pairs(ESP_OBJECTS) do
            if refs.gui and refs.gui.Parent then refs.gui:Destroy() end
            if refs.tracer and refs.tracer.Remove then
                pcall(function() refs.tracer:Remove() end)
            end
        end
        if RADAR_FRAME and RADAR_FRAME.Parent then
            RADAR_FRAME.Parent:Destroy()
        end
        if FOV_CIRCLE then
            pcall(function() FOV_CIRCLE:Remove() end)
        end
    end,
})

-- ============================================================
-- 9. RENDER LOOP
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
-- 10. EXPORTS
-- ============================================================
getgenv().__TLF_HUB = {
    STATE = STATE,
    get_target = function() return CURRENT_TARGET end,
    set_hit_part = function(part) STATE.sa_hit_part = part end,
    set_fov = function(v) STATE.sa_fov = v end,
    set_target_mode = function(m) STATE.sa_target_mode = m end,
    fire_remotes = fire_remotes,
}

-- ============================================================
-- 11. LOADING DONE
-- ============================================================
Rayfield:LoadConfiguration()

print("[TLF HUB v4 Rayfield] جاهز — ABSOLUTE KODE، يا ريدز")
print("[TLF HUB v4 Rayfield] Remotes محتملة:", #fire_remotes)
print("[TLF HUB v4 Rayfield] ⚠ Silent Aim — خطر حظر")
