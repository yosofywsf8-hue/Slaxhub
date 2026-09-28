--[[
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║             FAREX PULL HUB v2.0.0                        ║
    ║                                                          ║
    ║     Blade Ball All-in-One Script                         ║
    ║     Features: 20+                                        ║
    ║     Platform: PC / Mobile / Console                      ║
    ║                                                          ║
    ║     Build: v2 | Codename: SHADOW                         ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════
--  [0] فحص الـ executor
-- ═══════════════════════════════════════════════════════════

local _REQUIRED = {
    "cloneref", "getgenv", "hookmetamethod", "newcclosure",
    "getconnections", "getupvalues", "setupvalue",
    "getthreadidentity", "setthreadidentity",
}

local missing = {}
for _, fn in ipairs(_REQUIRED) do
    local ok = pcall(function() return _G[fn] end)
    if not ok or not _G[fn] then table.insert(missing, fn) end
end

if #missing > 0 then
    error("[Farexpull] Missing executor functions: " .. table.concat(missing, ", "))
end

-- ═══════════════════════════════════════════════════════════
--  [1] الخدمات
-- ═══════════════════════════════════════════════════════════

local _services = {}
local _svc_names = {
    "Players", "RunService", "UserInputService", "ReplicatedStorage",
    "Workspace", "TweenService", "HttpService", "Stats",
    "VirtualInputManager", "Debris", "CoreGui", "Lighting",
    "TextService", "ContentProvider", "TeleportService",
}
for _, name in ipairs(_svc_names) do
    local ok, svc = pcall(function() return cloneref(game:GetService(name)) end)
    if ok and svc then _services[name] = svc end
end

local Players = _services.Players
local RunService = _services.RunService
local UserInputService = _services.UserInputService
local ReplicatedStorage = _services.ReplicatedStorage
local Workspace = _services.Workspace
local TweenService = _services.TweenService
local HttpService = _services.HttpService
local Stats = _services.Stats
local VirtualInputManager = _services.VirtualInputManager
local Debris = _services.Debris
local CoreGui = _services.CoreGui
local Lighting = _services.Lighting
local TeleportService = _services.TeleportService

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════
--  [2] الحالة العامة
-- ═══════════════════════════════════════════════════════════

local STATE = {
    version = "2.0.0",
    build = "v2",
    device = nil,
    features = {},
    connections = {},
    flags = {},
    keybinds = {},
}

local function detect_device()
    if STATE.device then return STATE.device end
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        STATE.device = "Mobile"
    elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
        STATE.device = "Console"
    else
        STATE.device = "PC"
    end
    return STATE.device
end

local function is_mobile() return detect_device() == "Mobile" end
local function is_pc() return detect_device() == "PC" end

local function register_conn(name, conn)
    if STATE.connections[name] then
        pcall(function() STATE.connections[name]:Disconnect() end)
    end
    STATE.connections[name] = conn
    return conn
end

-- ═══════════════════════════════════════════════════════════
--  [3] Obfuscation
-- ═══════════════════════════════════════════════════════════

local _obf_counter = 0
local _chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function rand_name(prefix)
    _obf_counter = _obf_counter + 1
    local out = {}
    for i = 1, 8 do
        local idx = math.random(1, #_chars)
        out[i] = _chars:sub(idx, idx)
    end
    return (prefix or "") .. table.concat(out) .. tostring(_obf_counter)
end

local function rand_hex(n)
    n = n or 16
    local out = {}
    for i = 1, n do
        out[i] = string.format("%02x", math.random(0, 255))
    end
    return table.concat(out)
end

local function xor_crypt(data, key)
    local out = {}
    local key_len = #key
    for i = 1, #data do
        local d = data:byte(i)
        local k = key:byte(((i - 1) % key_len) + 1)
        out[i] = string.char(bit32 and bit32.bxor(d, k) or ((d + k) % 256))
    end
    return table.concat(out)
end

-- ═══════════════════════════════════════════════════════════
--  [4] Input Module
-- ═══════════════════════════════════════════════════════════

local Input = {}

function Input.send_parry_keypress()
    if is_mobile() then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    else
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end
end

local _mobile_buttons = {}

function Input.spawn_mobile_button(opts)
    if not is_mobile() then return nil end
    opts = opts or {}
    local name = opts.name or "FarexpullBtn"
    local text = opts.text or "BTN"
    local position = opts.position or UDim2.new(0, 20, 0.5, 0)
    local color = opts.color or Color3.fromRGB(99, 102, 241)
    local callback = opts.callback or function() end

    if _mobile_buttons[name] then
        pcall(function() _mobile_buttons[name]:Destroy() end)
        _mobile_buttons[name] = nil
    end

    local gui = CoreGui:FindFirstChild("FarexpullMobile")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "FarexpullMobile"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = CoreGui
    end

    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = position
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.3
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(235, 235, 245)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = 0.2
    stroke.Thickness = 2
    stroke.Parent = btn

    local touch_start = 0
    local moved = false

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touch_start = tick()
            moved = false
            btn.BackgroundTransparency = 0.15
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and tick() - touch_start > 0.15 then
            moved = true
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        btn.BackgroundTransparency = 0.3
        if not moved then pcall(callback) end
    end)

    _mobile_buttons[name] = btn
    return btn
end

function Input.remove_all_mobile_buttons()
    for name, btn in pairs(_mobile_buttons) do
        pcall(function() btn:Destroy() end)
    end
    _mobile_buttons = {}
    local gui = CoreGui:FindFirstChild("FarexpullMobile")
    if gui then gui:Destroy() end
end

-- ═══════════════════════════════════════════════════════════
--  [5] Remote Module
-- ═══════════════════════════════════════════════════════════

local Remote = {}

local _remote_config = {
    max_rate = 30,
    jitter = 0.2,
    discovery_retries = 5,
    discovery_interval = 0.5,
    enable_event_data_variance = true,
    enable_camera_move = true,
    prefer_remote = true,
}

local _remote_state = {
    parry_remote = nil,
    parry_kind = nil,
    controllers = nil,
    discovery_done = false,
    last_fire = 0,
    rate_violations = 0,
    total_fires = 0,
    successful_fires = 0,
    failed_fires = 0,
    fallbacks_used = 0,
}

local function find_controllers()
    if _remote_state.controllers and _remote_state.controllers.Parent then
        return _remote_state.controllers
    end
    local c = ReplicatedStorage:FindFirstChild("Controllers")
    if c then _remote_state.controllers = c; return c end
    return nil
end

local function find_pry_remote()
    local controllers = find_controllers()
    if not controllers then return nil end
    for _, child in ipairs(controllers:GetChildren()) do
        if child.Name:find("SwordsController", 1, true) == 1 then
            local pry = child:FindFirstChild("PRY")
            if pry then
                if pry:IsA("RemoteEvent") then return pry, "event"
                elseif pry:IsA("RemoteFunction") then return pry, "function" end
            end
        end
    end
    return nil, nil
end

function Remote.discover()
    if _remote_state.discovery_done then
        return _remote_state.parry_remote, _remote_state.parry_kind
    end
    for attempt = 1, _remote_config.discovery_retries do
        local pry, kind = find_pry_remote()
        if pry then
            _remote_state.parry_remote = pry
            _remote_state.parry_kind = kind
            _remote_state.discovery_done = true
            print("[Farexpull] Remote found: " .. pry:GetFullName())
            return pry, kind
        end
        task.wait(_remote_config.discovery_interval)
    end
    warn("[Farexpull] PRY remote not found")
    return nil, nil
end

function Remote.start_background_discovery()
    if _remote_state.discovery_conn then return end
    _remote_state.discovery_conn = task.spawn(function()
        while not _remote_state.discovery_done do
            local pry = find_pry_remote()
            if pry then
                _remote_state.parry_remote = pry
                _remote_state.parry_kind = "event"
                _remote_state.discovery_done = true
                return
            end
            task.wait(1)
        end
    end)
end

local function can_fire()
    local now = tick()
    local interval = 1 / _remote_config.max_rate
    local j = _remote_config.jitter
    local min_i = interval * (1 - j)
    local max_i = interval * (1 + j)
    local threshold = min_i + math.random() * (max_i - min_i)
    if now - _remote_state.last_fire >= threshold then
        _remote_state.last_fire = now
        return true
    end
    _remote_state.rate_violations = _remote_state.rate_violations + 1
    return false
end

local function get_event_data()
    if not _remote_config.enable_event_data_variance then return {} end
    local data = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ok, sp = pcall(function() return Camera:WorldToScreenPoint(hrp.Position) end)
                if ok then data[player.Name] = sp end
            end
        end
    end
    return data
end

local function get_mouse_vec()
    if is_mobile() then
        local vp = Camera.ViewportSize
        return {vp.X / 2, vp.Y / 2}
    end
    local ok, pos = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and pos then return {pos.X, pos.Y} end
    return {0, 0}
end

local function generate_curve_cframe(mode)
    mode = mode or 2
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return Camera.CFrame end
    local target_pos = nil
    local mouse_pos = get_mouse_vec()
    local ray = Camera:ScreenPointToRay(mouse_pos[1], mouse_pos[2])
    local look_cf = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    local best_dot = -math.huge
    local best_char = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local their_hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if their_hrp then
                local dot = look_cf.LookVector:Dot((their_hrp.Position - Camera.CFrame.Position).Unit)
                if dot > best_dot then best_dot = dot; best_char = their_hrp end
            end
        end
    end
    if best_char then target_pos = best_char.Position
    else target_pos = hrp.Position + Camera.CFrame.LookVector * 100 end
    if mode == 2 then
        local rv = Camera.CFrame.RightVector
        local up = Vector3.new(0, 1, 0)
        local forward = -(target_pos - hrp.Position).Unit
        local sign = math.random(0, 1) == 0 and -1 or 1
        local offsets = {
            forward * math.random(7000, 12000) + rv * (sign * math.random(2000, 5000)) + up * math.random(3000, 6000),
            forward * math.random(8000, 15000) + rv * (sign * math.random(1500, 4000)) + up * math.random(2000, 5000),
            rv * (sign * math.random(8000, 15000)) + forward * math.random(2000, 5000) + up * math.random(2000, 5000),
        }
        return CFrame.new(hrp.Position, target_pos + offsets[math.random(1, #offsets)])
    end
    if mode == 3 then return CFrame.new(hrp.Position, target_pos + Vector3.new(0, 5, 0)) end
    if mode == 4 then return CFrame.new(Camera.CFrame.Position, hrp.Position + (hrp.Position - target_pos).Unit * 10000 + Vector3.new(0, 1000, 0)) end
    if mode == 5 then return CFrame.new(hrp.Position, target_pos + Vector3.new(0, -9e18, 0)) end
    if mode == 6 then return CFrame.new(hrp.Position, target_pos + Vector3.new(0, 9e18, 0)) end
    if mode == 7 then
        local dist = (hrp.Position - target_pos).Magnitude
        local y = math.clamp((dist - 60) * 0.2, -25, 5)
        return CFrame.new(hrp.Position, target_pos + Vector3.new(0, y, 0))
    end
    return Camera.CFrame
end

function Remote.fire_parry(opts)
    opts = opts or {}
    if not can_fire() then return false, "rate_limited" end
    if not _remote_state.parry_remote then
        Remote.discover()
        if not _remote_state.parry_remote then
            _remote_state.failed_fires = _remote_state.failed_fires + 1
            return false, "no_remote"
        end
    end
    local curve_mode = opts.curve_mode or 2
    local cf = nil
    if _remote_config.enable_camera_move then
        cf = generate_curve_cframe(curve_mode)
    end
    local event_data = get_event_data()
    local mouse_vec = get_mouse_vec()
    local ok = false
    if _remote_state.parry_kind == "event" then
        ok = pcall(function()
            _remote_state.parry_remote:FireServer(0.5, cf, event_data, mouse_vec, false)
        end)
    else
        ok = pcall(function()
            _remote_state.parry_remote:FireServer(0.5, cf, event_data, mouse_vec, false)
        end)
    end
    _remote_state.total_fires = _remote_state.total_fires + 1
    if ok then
        _remote_state.successful_fires = _remote_state.successful_fires + 1
        return true
    else
        _remote_state.failed_fires = _remote_state.failed_fires + 1
        if _remote_config.prefer_remote then
            _remote_state.fallbacks_used = _remote_state.fallbacks_used + 1
            Input.send_parry_keypress()
            return true, "fallback"
        end
        return false
    end
end

function Remote.get_stats()
    return {
        total = _remote_state.total_fires,
        successful = _remote_state.successful_fires,
        failed = _remote_state.failed_fires,
        fallbacks = _remote_state.fallbacks_used,
        has_remote = _remote_state.parry_remote ~= nil,
    }
end

Remote.start_background_discovery()

-- ═══════════════════════════════════════════════════════════
--  [6] Config Module
-- ═══════════════════════════════════════════════════════════

local Config = {}

local _config_folder = nil
local _config_key = "fxpull_v2_2024"
local _config_queue = {}
local _config_thread = nil
local _current_profile = nil

local function ensure_config_folder()
    if _config_folder then return _config_folder end
    local seed = tostring(LocalPlayer.UserId)
    local hash = 0
    for i = 1, #seed do
        hash = (hash * 31 + seed:byte(i)) % 100000000
    end
    _config_folder = "fx_" .. string.format("%08x", hash)
    if not isfolder(_config_folder) then
        pcall(makefolder, _config_folder)
    end
    return _config_folder
end

local function config_path(name)
    return ensure_config_folder() .. "/" .. name
end

local function process_config_queue()
    while #_config_queue > 0 do
        local job = table.remove(_config_queue, 1)
        if job then
            local data = HttpService:JSONEncode(job.data)
            local encrypted = xor_crypt(data, _config_key)
            pcall(function() writefile(job.path, encrypted) end)
        end
    end
    _config_thread = nil
end

local function queue_config_write(name, data)
    table.insert(_config_queue, {
        path = config_path(name),
        data = data,
    })
    if not _config_thread then
        _config_thread = task.delay(0.15, process_config_queue)
    end
end

local function read_config(name)
    local path = config_path(name)
    if not isfile(path) then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return nil end
    local decrypted = xor_crypt(raw, _config_key)
    local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, decrypted)
    if not ok2 then return nil end
    return parsed
end

function Config.save(name, data)
    name = (name or _current_profile or "default"):gsub("[^%w_%-]", "_"):sub(1, 32)
    if not data then
        data = { flags = STATE.flags, keybinds = STATE.keybinds, version = 2 }
    end
    data._meta = { version = 2, saved_at = os.time() }
    queue_config_write(name .. ".cfg", data)
    _current_profile = name
    return true, name
end

function Config.load(name)
    name = (name or _current_profile or "default"):gsub("[^%w_%-]", "_"):sub(1, 32)
    local data = read_config(name .. ".cfg")
    if not data then return false, "not found" end
    if data.flags then
        for k, v in pairs(data.flags) do STATE.flags[k] = v end
    end
    if data.keybinds then
        for k, v in pairs(data.keybinds) do STATE.keybinds[k] = v end
    end
    _current_profile = name
    return true
end

function Config.set_autoload(name)
    if not name then
        local p = config_path("auto.dat")
        if isfile(p) then pcall(delfile, p) end
        return false
    end
    queue_config_write("auto.dat", { profile = name })
    return true
end

function Config.get_autoload()
    local data = read_config("auto.dat")
    return data and data.profile or nil
end

function Config.run_autoload()
    local name = Config.get_autoload()
    if name then Config.load(name); return name end
    return nil
end

function Config.list_profiles()
    local folder = ensure_config_folder()
    local ok, files = pcall(listfiles, folder)
    if not ok then return {} end
    local profiles = {}
    for _, file in ipairs(files) do
        local name = file:match("/([^/]+)%.cfg$")
        if name then table.insert(profiles, name) end
    end
    table.sort(profiles)
    return profiles
end

function Config.delete(name)
    name = name:gsub("[^%w_%-]", "_"):sub(1, 32)
    local p = config_path(name .. ".cfg")
    if isfile(p) then pcall(delfile, p) end
    return true
end

function Config.get_current() return _current_profile end

ensure_config_folder()

-- ═══════════════════════════════════════════════════════════
--  [7] Anti-Cheat Scanner
-- ═══════════════════════════════════════════════════════════

local AntiCheat = {}

local _ac_patterns = {
    "kraken", "shield", "honeypot", "trap", "report",
    "ban", "kick", "detect", "flag", "monitor",
    "anticheat", "ac_", "_ac", "guard", "secure",
    "verify", "validate", "suspicious", "exploit",
    "telemetry", "analytics", "trace", "audit",
}
local _ac_safe = { "Farexpull", "sp_", "fx_" }
local _ac_findings = {}
local _ac_disconnected = {}
local _ac_conn = nil

local function is_suspicious(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    for _, p in ipairs(_ac_safe) do
        if lower:find(p:lower(), 1, true) then return false end
    end
    for _, p in ipairs(_ac_patterns) do
        if lower:find(p, 1, true) then return true end
    end
    return false
end

local function analyze_conn(conn)
    if not conn or not conn.Function then return nil end
    local info
    pcall(function() info = debug.getinfo(conn.Function) end)
    if not info then return nil end
    if is_suspicious(info.name) or is_suspicious(info.short_src) then
        return { name = info.name, src = info.short_src, line = info.linedefined }
    end
    return nil
end

local function scan_remote(remote)
    if not remote or not getconnections then return end
    local events = {}
    pcall(function()
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            events = getconnections(remote.OnClientEvent)
        elseif remote:IsA("RemoteFunction") then
            events = getconnections(remote.OnClientInvoke)
        end
    end)
    for _, conn in ipairs(events) do
        local finding = analyze_conn(conn)
        if finding then
            finding.remote = remote:GetFullName()
            table.insert(_ac_findings, finding)
            warn("[Farexpull] Anti-cheat: " .. tostring(finding.name) .. " on " .. finding.remote)
            pcall(function()
                conn:Disconnect()
                table.insert(_ac_disconnected, finding)
            end)
        end
    end
end

function AntiCheat.scan()
    if not getconnections then return 0 end
    local count = 0
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            scan_remote(obj)
            count = count + 1
        end
    end
    return count
end

function AntiCheat.start()
    if _ac_conn then return end
    _ac_conn = task.spawn(function()
        while true do
            pcall(AntiCheat.scan)
            task.wait(5)
        end
    end)
    print("[Farexpull] Anti-cheat scanner started")
end

function AntiCheat.stop()
    if _ac_conn then
        pcall(function() task.cancel(_ac_conn) end)
        _ac_conn = nil
    end
end

function AntiCheat.report()
    print(string.format("[Farexpull] AC report: %d findings, %d disconnected",
        #_ac_findings, #_ac_disconnected))
end

-- ═══════════════════════════════════════════════════════════
--  [8] Parry Module
-- ═══════════════════════════════════════════════════════════

local Parry = {}

local _parry_config = {
    enabled = false,
    accuracy = 75,
    randomize_accuracy = false,
    random_accuracy_min = 25,
    random_accuracy_max = 85,
    parry_mode = "Hybrid",
    curve_mode = 2,
    triggerbot = false,
    kill_pre_click = false,
    kill_pre_click_range = 30,
    parry_hold = 0.4,
    cooldown = 2,
    ping_ttl = 0.12,
}

local _parry_state = {
    hb_conn = nil,
    parried = false,
    parried_at = 0,
    ping = 50,
    ping_at = 0,
    failed_at = 0,
    last_attr = nil,
    cooldown_conn = nil,
    ball_tracking = {},
    curve_time = 0,
    original_accuracy = nil,
    stats = { parries = 0, hits = 0, misses = 0 },
    grab_track = nil,
}

local function get_ping()
    local now = tick()
    if now - _parry_state.ping_at < _parry_config.ping_ttl then
        return _parry_state.ping
    end
    local ok, p = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(p) == "number" then
        _parry_state.ping = p
        _parry_state.ping_at = now
    end
    return _parry_state.ping
end

local function get_parry_distance(vel)
    local acc = _parry_config.accuracy
    local acc_mult = 0.5 + (math.clamp(acc, 1, 100) - 1) * 0.010101
    local ping = get_ping()
    local ping_factor = math.clamp(ping / 100, 5, 17)
    local base = vel / ((2.4 + math.min(math.max(vel - 9.5, 0), 650) * 0.002) * acc_mult)
    return ping_factor + math.max(base, 9.5)
end

local function get_balls()
    local result = {}
    for _, folder_name in ipairs({"Balls", "TrainingBalls"}) do
        local folder = Workspace:FindFirstChild(folder_name)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("BasePart") then
                    table.insert(result, child)
                end
            end
        end
    end
    return result
end

local function get_ball_velocity(ball)
    local zoomies = ball:FindFirstChild("zoomies")
    if zoomies and zoomies:IsA("VectorForce") then
        return zoomies.VectorVelocity
    end
    return ball.AssemblyLinearVelocity
end

local function play_grab_animation()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local ok, anim_folder = pcall(function()
        local collection = ReplicatedStorage.Shared.SwordAPI.Collection
        return collection.Default
    end)
    if not ok or not anim_folder then return end

    local grab = anim_folder:FindFirstChild("GrabParry")
        or anim_folder:FindFirstChild("Grab")
        or anim_folder:FindFirstChild("Parry")
    if not grab then return end

    if _parry_state.grab_track then
        pcall(function() _parry_state.grab_track:Stop() end)
    end

    local track = animator:LoadAnimation(grab)
    track.Priority = Enum.AnimationPriority.Action4
    track:Play(0, 1, 1)
    _parry_state.grab_track = track
end

function Parry.execute()
    local mode = _parry_config.parry_mode
    task.spawn(play_grab_animation)

    if mode == "Keypress" then
        Input.send_parry_keypress()
        return true
    end

    if mode == "Remote" then
        local ok = Remote.fire_parry({curve_mode = _parry_config.curve_mode})
        if not ok then Input.send_parry_keypress() end
        return ok
    end

    if math.random() < 0.5 then
        local ok = Remote.fire_parry({curve_mode = _parry_config.curve_mode})
        if not ok then Input.send_parry_keypress() end
        return ok
    else
        Input.send_parry_keypress()
        return true
    end
end

local function auto_parry_loop()
    if not _parry_config.enabled then return end

    -- Reset parried
    if _parry_state.parried and (tick() - _parry_state.parried_at) > 1.5 then
        _parry_state.parried = false
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local self_pos = hrp.Position

    for _, ball in ipairs(get_balls()) do
        local target = ball:GetAttribute("target")
        if target ~= LocalPlayer.Name then continue end

        if _parry_state.parried then continue end
        if ball:FindFirstChild("ComboCounter") then continue end

        local vel = get_ball_velocity(ball)
        local speed = vel.Magnitude
        local distance = (ball.Position - self_pos).Magnitude

        local parry_dist = get_parry_distance(speed)
        if distance > parry_dist then continue end

        if _parry_config.randomize_accuracy then
            if not _parry_state.original_accuracy then
                _parry_state.original_accuracy = _parry_config.accuracy
            end
        end

        Parry.execute()

        _parry_state.parried = true
        _parry_state.parried_at = tick()
        _parry_state.stats.parries = _parry_state.stats.parries + 1

        task.delay(_parry_config.parry_hold, function()
            if _parry_state.parried and (tick() - _parry_state.parried_at) >= _parry_config.parry_hold then
                _parry_state.parried = false
            end
        end)

        break
    end
end

function Parry.start()
    if _parry_config.enabled then return end
    _parry_config.enabled = true
    _parry_state.hb_conn = RunService.Heartbeat:Connect(auto_parry_loop)
    print("[Farexpull] Parry started")
end

function Parry.stop()
    if not _parry_config.enabled then return end
    _parry_config.enabled = false
    if _parry_state.hb_conn then
        _parry_state.hb_conn:Disconnect()
        _parry_state.hb_conn = nil
    end
end

function Parry.set_accuracy(a) _parry_config.accuracy = math.clamp(a, 1, 100) end
function Parry.set_mode(m) if m == "Remote" or m == "Keypress" or m == "Hybrid" then _parry_config.parry_mode = m end end
function Parry.set_curve(m) _parry_config.curve_mode = math.clamp(m, 1, 7) end
function Parry.get_stats() return _parry_state.stats end

-- ═══════════════════════════════════════════════════════════
--  [9] Spam Module
-- ═══════════════════════════════════════════════════════════

local Spam = {}

local _spam_config = {
    manual_rate = 30,
    manual_mode = "Remote",
    auto_rate = 20,
    auto_mode = "Hybrid",
    auto_threshold = 1.5,
    auto_burst = 0.5,
    jitter = 0.15,
}

local _spam_state = {
    manual_active = false,
    auto_active = false,
    manual_conn = nil,
    auto_conn = nil,
    last_spam = 0,
    burst_until = 0,
    mode_index = 0,
    spam_count = 0,
}

local function apply_jitter(interval)
    local j = _spam_config.jitter
    return interval * (1 - j) + math.random() * (interval * 2 * j)
end

local function pick_mode(base_mode)
    if base_mode ~= "Hybrid" then return base_mode end
    _spam_state.mode_index = (_spam_state.mode_index + 1) % 2
    return _spam_state.mode_index == 0 and "Remote" or "Keypress"
end

local function execute_spam(base_mode)
    local mode = pick_mode(base_mode)
    task.spawn(play_grab_animation)

    if mode == "Remote" then
        local ok = Remote.fire_parry({curve_mode = 2})
        if not ok then Input.send_parry_keypress() end
    else
        Input.send_parry_keypress()
    end
    _spam_state.spam_count = _spam_state.spam_count + 1
end

local function manual_loop()
    if not _spam_state.manual_active then return end
    local now = tick()
    local interval = 1 / _spam_config.manual_rate
    if now >= _spam_state.last_spam + apply_jitter(interval) then
        execute_spam(_spam_config.manual_mode)
        _spam_state.last_spam = now
    end
end

local function auto_loop()
    if not _spam_state.auto_active then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local self_pos = hrp.Position

    local now = tick()
    if now < _spam_state.burst_until then
        local interval = 1 / _spam_config.auto_rate
        if now >= _spam_state.last_spam + apply_jitter(interval) then
            execute_spam(_spam_config.auto_mode)
            _spam_state.last_spam = now
        end
        return
    end

    for _, ball in ipairs(get_balls()) do
        if ball:GetAttribute("target") == LocalPlayer.Name then
            local dist = (ball.Position - self_pos).Magnitude
            if dist <= _spam_config.auto_threshold then
                _spam_state.burst_until = now + _spam_config.auto_burst
                _spam_state.last_spam = 0
                break
            end
        end
    end
end

function Spam.start_manual()
    if _spam_state.manual_active then return end
    _spam_state.manual_active = true
    _spam_state.last_spam = 0
    _spam_state.manual_conn = RunService.Heartbeat:Connect(manual_loop)
end

function Spam.stop_manual()
    _spam_state.manual_active = false
    if _spam_state.manual_conn then
        _spam_state.manual_conn:Disconnect()
        _spam_state.manual_conn = nil
    end
end

function Spam.start_auto()
    if _spam_state.auto_active then return end
    _spam_state.auto_active = true
    _spam_state.auto_conn = RunService.Heartbeat:Connect(auto_loop)
end

function Spam.stop_auto()
    _spam_state.auto_active = false
    if _spam_state.auto_conn then
        _spam_state.auto_conn:Disconnect()
        _spam_state.auto_conn = nil
    end
end

function Spam.stop()
    Spam.stop_manual()
    Spam.stop_auto()
end

function Spam.set_manual_rate(r) _spam_config.manual_rate = math.clamp(r, 1, 100) end
function Spam.set_auto_rate(r) _spam_config.auto_rate = math.clamp(r, 1, 100) end
function Spam.set_auto_threshold(t) _spam_config.auto_threshold = math.clamp(t, 0.5, 10) end

-- ═══════════════════════════════════════════════════════════
--  [10] Immortal Module
-- ═══════════════════════════════════════════════════════════

local Immortal = {}

local _imm_config = {
    radius = 25,
    height = 30,
    visualizer = false,
    visualizer_color = Color3.fromRGB(255, 0, 0),
    velocity_override = true,
    head_override = true,
}

local _imm_state = {
    enabled = false,
    hb_conn = nil,
    char_conn = nil,
    character = nil,
    hrp = nil,
    head = nil,
    alive = nil,
    original_cframe = nil,
    original_velocity = nil,
    vis_folder = nil,
    original_hook = nil,
    hook_installed = false,
}

local _empty_cframe = CFrame.new()

local function imm_update_cache()
    local char = LocalPlayer.Character
    if char == _imm_state.character then return end
    _imm_state.character = char
    if char then
        _imm_state.hrp = char:FindFirstChild("HumanoidRootPart")
        _imm_state.head = char:FindFirstChild("Head")
        _imm_state.alive = Workspace:FindFirstChild("Alive")
    else
        _imm_state.hrp = nil
        _imm_state.head = nil
    end
end

local function imm_is_in_alive()
    return _imm_state.alive and _imm_state.character and _imm_state.character.Parent == _imm_state.alive
end

local function imm_get_random_position()
    if not _imm_state.hrp then return _empty_cframe end
    local base = _imm_state.hrp.Position
    local angle = math.rad(math.random(0, 360))
    local radius = _imm_config.radius
    local height_offset = (math.random() < 0.5) and 0 or _imm_config.height
    local x = base.X + math.cos(angle) * radius
    local y = base.Y - _imm_state.hrp.Size.Y * 0.5 + 5 + height_offset
    local z = base.Z + math.sin(angle) * radius
    return CFrame.new(x, y, z)
end

local function imm_create_vis_folder()
    if _imm_state.vis_folder then _imm_state.vis_folder:Destroy() end
    local f = Instance.new("Folder")
    f.Name = "Farexpull_Vis"
    f.Parent = Workspace
    _imm_state.vis_folder = f
end

local function imm_spawn_vis(cframe)
    if not _imm_config.visualizer or not _imm_state.vis_folder then return end
    local p = Instance.new("Part")
    p.Size = Vector3.new(2, 0.5, 2)
    p.CFrame = cframe
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Material = Enum.Material.Neon
    p.Color = _imm_config.visualizer_color
    p.Transparency = 0.5
    p.Parent = _imm_state.vis_folder
    Debris:AddItem(p, 0.1)
end

local function imm_clear_vis()
    if _imm_state.vis_folder then
        _imm_state.vis_folder:Destroy()
        _imm_state.vis_folder = nil
    end
end

local function imm_perform_desync()
    imm_update_cache()
    if not _imm_state.enabled then return end
    if not _imm_state.hrp then return end
    if not imm_is_in_alive() then return end

    local hrp = _imm_state.hrp
    _imm_state.original_cframe = hrp.CFrame
    _imm_state.original_velocity = hrp.AssemblyLinearVelocity

    local fake = imm_get_random_position()
    hrp.CFrame = fake
    if _imm_config.velocity_override then
        hrp.AssemblyLinearVelocity = Vector3.new(1, 1, 1)
    end

    if _imm_config.visualizer then imm_spawn_vis(fake) end

    RunService.RenderStepped:Wait()

    hrp.CFrame = _imm_state.original_cframe
    hrp.AssemblyLinearVelocity = _imm_state.original_velocity
end

local function imm_install_hook()
    if _imm_state.hook_installed then return end
    if type(hookmetamethod) ~= "function" then return end

    local function hooked_index(self, key)
        if not _imm_state.enabled then
            return _imm_state.original_hook(self, key)
        end
        if checkcaller and checkcaller() then
            return _imm_state.original_hook(self, key)
        end
        if key == "CFrame" then
            if self == _imm_state.hrp then
                return _imm_state.original_cframe or _empty_cframe
            end
            if _imm_config.head_override and self == _imm_state.head and _imm_state.original_cframe then
                local offset = Vector3.new(0, _imm_state.hrp.Size.Y * 0.5 + 0.5, 0)
                return _imm_state.original_cframe + offset
            end
        end
        if key == "AssemblyLinearVelocity" and _imm_config.velocity_override then
            if self == _imm_state.hrp then return Vector3.new(1, 1, 1) end
        end
        return _imm_state.original_hook(self, key)
    end

    local ok = pcall(function()
        _imm_state.original_hook = hookmetamethod(game, "__index", newcclosure(hooked_index))
    end)
    if ok then _imm_state.hook_installed = true end
end

local function imm_uninstall_hook()
    if not _imm_state.hook_installed then return end
    pcall(function()
        if _imm_state.original_hook then
            hookmetamethod(game, "__index", _imm_state.original_hook)
        end
    end)
    _imm_state.hook_installed = false
    _imm_state.original_hook = nil
end

function Immortal.start()
    if _imm_state.enabled then return end
    _imm_state.enabled = true
    imm_install_hook()
    if _imm_config.visualizer then imm_create_vis_folder() end
    _imm_state.hb_conn = RunService.Heartbeat:Connect(imm_perform_desync)
    _imm_state.char_conn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        _imm_state.character = nil
        imm_update_cache()
    end)
    print("[Farexpull] Immortal started")
end

function Immortal.stop()
    if not _imm_state.enabled then return end
    _imm_state.enabled = false
    if _imm_state.hb_conn then _imm_state.hb_conn:Disconnect(); _imm_state.hb_conn = nil end
    if _imm_state.char_conn then _imm_state.char_conn:Disconnect(); _imm_state.char_conn = nil end
    imm_uninstall_hook()
    imm_clear_vis()
end

function Immortal.set_radius(r) _imm_config.radius = math.clamp(r, 0, 100) end
function Immortal.set_height(h) _imm_config.height = math.clamp(h, 0, 100) end
function Immortal.set_visualizer(v) _imm_config.visualizer = v and true or false
    if _imm_state.enabled then
        if v then imm_create_vis_folder() else imm_clear_vis() end
    end
end

-- ═══════════════════════════════════════════════════════════
--  [11] Anti-Phantom Module
-- ═══════════════════════════════════════════════════════════

local AntiPhantom = {}

local _ap_config = {
    phantom = false,
    phantom_blatant = false,
    phantom_type = "Spam",
    flash = false,
    flash_blatant = false,
    flash_type = "Spam",
    detect_window = 1.25,
    teleport_distance = 32,
    spam_interval = 0.05,
}

local _ap_state = {
    target = nil,
    data = nil,
    last_spam = 0,
    conns = {},
}

local function ap_reset()
    _ap_state.target = nil
    _ap_state.data = nil
end

local function ap_trigger(name, target)
    if name == "Phantom" and not _ap_config.phantom then return end
    if name == "Flash" and not _ap_config.flash then return end
    if type(target) ~= "Instance" or not target:IsA("Model") then return end

    _ap_state.target = target
    _ap_state.data = {
        name = name,
        blatant = name == "Phantom" and _ap_config.phantom_blatant or _ap_config.flash_blatant,
        type = name == "Phantom" and _ap_config.phantom_type or _ap_config.flash_type,
        expires = tick() + _ap_config.detect_window,
    }
end

local function ap_update()
    local data = _ap_state.data
    local target = _ap_state.target
    if not data then return end
    if tick() >= data.expires then ap_reset(); return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local t_hrp = target:FindFirstChild("HumanoidRootPart")
    if not hrp or not t_hrp then ap_reset(); return end

    local delta = hrp.Position - t_hrp.Position
    local dist = delta.Magnitude

    if data.blatant and dist < _ap_config.teleport_distance then
        local dir = dist > 0.1 and delta.Unit or -t_hrp.CFrame.LookVector
        hrp.CFrame = hrp.CFrame + dir * (_ap_config.teleport_distance - dist)
        ap_reset()
        return
    end

    if data.type == "Spam" then
        local now = tick()
        if now - _ap_state.last_spam >= _ap_config.spam_interval then
            _ap_state.last_spam = now
            pcall(Remote.fire_parry, {curve_mode = 2})
        end
    elseif data.type == "Ability" then
        local now = tick()
        if now - _ap_state.last_spam >= 0.3 then
            _ap_state.last_spam = now
            pcall(function()
                local r = ReplicatedStorage:FindFirstChild("Remotes")
                if r and r:FindFirstChild("AbilityButtonPress") then
                    r.AbilityButtonPress:Fire()
                end
            end)
        end
    end
end

function AntiPhantom.start()
    if _ap_state.conns.hb then return end
    _ap_state.conns.hb = RunService.PreSimulation:Connect(function()
        pcall(ap_update)
    end)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local activate = remotes:FindFirstChild("ActivateAbility")
        if activate then
            _ap_state.conns.phantom = activate.OnClientEvent:Connect(function(player, data)
                if player:GetAttribute("Ability") == "Phantom" then
                    ap_trigger("Phantom", player)
                end
            end)
        end
        local flash = remotes:FindFirstChild("PlrFlashCountered")
        if flash then
            _ap_state.conns.flash = flash.OnClientEvent:Connect(function(player)
                ap_trigger("Flash", player)
            end)
        end
    end
end

function AntiPhantom.stop()
    for _, c in pairs(_ap_state.conns) do
        pcall(function() c:Disconnect() end)
    end
    _ap_state.conns = {}
    ap_reset()
end

function AntiPhantom.set_phantom(e, b, t)
    _ap_config.phantom = e and true or false
    if b ~= nil then _ap_config.phantom_blatant = b end
    if t then _ap_config.phantom_type = t end
end

function AntiPhantom.set_flash(e, b, t)
    _ap_config.flash = e and true or false
    if b ~= nil then _ap_config.flash_blatant = b end
    if t then _ap_config.flash_type = t end
end

-- ═══════════════════════════════════════════════════════════
--  [12] Preclick Module
-- ═══════════════════════════════════════════════════════════

local Preclick = {}

local _pc_config = {
    enabled = false,
    for_all = false,
    delay_ms = 135,
    use_remote = true,
    queue_max = 8,
}

local _pc_state = {
    queue = {},
    hb_conn = nil,
    ping = 50,
    ping_at = 0,
    fired = 0,
}

local function pc_get_ping()
    local now = tick()
    if now - _pc_state.ping_at < 0.1 then return _pc_state.ping end
    local ok, val = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(val) == "number" then
        _pc_state.ping = val
        _pc_state.ping_at = now
    end
    return _pc_state.ping
end

local function pc_fire()
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end
    if char.Parent ~= Workspace:FindFirstChild("Alive") then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if _pc_config.use_remote then
        Remote.fire_parry({curve_mode = 2})
    else
        Input.send_parry_keypress()
    end
    _pc_state.fired = _pc_state.fired + 1
end

local function pc_process()
    local now = tick()
    for i = #_pc_state.queue, 1, -1 do
        local job = _pc_state.queue[i]
        if now >= job.fire_at then
            pcall(pc_fire)
            table.remove(_pc_state.queue, i)
        end
    end
end

local function pc_trigger(ball)
    if not _pc_config.enabled then return end
    local char = LocalPlayer.Character
    if not char or char.Parent ~= Workspace:FindFirstChild("Alive") then return end
    if not _pc_config.for_all then
        if ball:GetAttribute("target") ~= LocalPlayer.Name then return end
    end
    local speed = get_ball_velocity(ball).Magnitude
    local hrp = char.PrimaryPart
    local dist = (ball.Position - hrp.Position).Magnitude
    if speed < 1 then return end
    local time_to_arrive = dist / speed
    if time_to_arrive > 2 or time_to_arrive < 0.02 then return end
    local delay = _pc_config.delay_ms / 1000
    local fire_in = time_to_arrive - delay
    if fire_in <= 0 then
        pcall(pc_fire)
        return
    end
    if #_pc_state.queue >= _pc_config.queue_max then
        table.remove(_pc_state.queue, 1)
    end
    table.insert(_pc_state.queue, { fire_at = tick() + fire_in })
end

function Preclick.start()
    if _pc_state.hb_conn then return end
    _pc_config.enabled = true
    _pc_state.hb_conn = RunService.Heartbeat:Connect(function()
        pcall(pc_process)
        for _, ball in ipairs(get_balls()) do
            pcall(pc_trigger, ball)
        end
    end)
end

function Preclick.stop()
    _pc_config.enabled = false
    if _pc_state.hb_conn then
        _pc_state.hb_conn:Disconnect()
        _pc_state.hb_conn = nil
    end
    _pc_state.queue = {}
end

function Preclick.set_delay(ms) _pc_config.delay_ms = math.clamp(ms, 10, 500) end
function Preclick.set_for_all(v) _pc_config.for_all = v and true or false end

-- ═══════════════════════════════════════════════════════════
--  [13] ESP Module
-- ═══════════════════════════════════════════════════════════

local ESP = {}

local _esp_state = {
    active = false,
    labels = {},
    conn = nil,
    icon_size = 34,
    text_size = 13,
    show_names = false,
}

local function esp_create_label(player, character)
    if not character then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Farexpull_ESP"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 230, 0, _esp_state.icon_size + 64)
    billboard.StudsOffset = Vector3.new(0, 4.15, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 500
    billboard.Parent = head

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = billboard

    local name_label = Instance.new("TextLabel")
    name_label.Size = UDim2.new(1, -18, 0, 16)
    name_label.Position = UDim2.new(0, 9, 0, _esp_state.icon_size + 20)
    name_label.BackgroundTransparency = 1
    name_label.TextColor3 = Color3.fromRGB(225, 225, 230)
    name_label.TextStrokeColor3 = Color3.new(0, 0, 0)
    name_label.TextStrokeTransparency = 0.1
    name_label.TextSize = _esp_state.text_size - 1
    name_label.Font = Enum.Font.GothamMedium
    name_label.Text = player.DisplayName
    name_label.Visible = _esp_state.show_names
    name_label.Parent = container

    _esp_state.labels[player] = {
        billboard = billboard,
        name_label = name_label,
        character = character,
    }
end

local function esp_destroy_label(player)
    local label = _esp_state.labels[player]
    if label and label.billboard then
        pcall(function() label.billboard:Destroy() end)
    end
    _esp_state.labels[player] = nil
end

local function esp_refresh()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and not _esp_state.labels[player] then
                pcall(esp_create_label, player, char)
            elseif not char then
                esp_destroy_label(player)
            end
        end
    end
end

function ESP.start()
    if _esp_state.active then return end
    _esp_state.active = true
    esp_refresh()
    _esp_state.conn = RunService.Heartbeat:Connect(function()
        if tick() % 1 < 0.02 then esp_refresh() end
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            p.CharacterAdded:Connect(function(c)
                task.wait(0.5)
                if _esp_state.active then pcall(esp_create_label, p, c) end
            end)
        end
    end
end

function ESP.stop()
    _esp_state.active = false
    if _esp_state.conn then
        _esp_state.conn:Disconnect()
        _esp_state.conn = nil
    end
    for p in pairs(_esp_state.labels) do
        esp_destroy_label(p)
    end
end

function ESP.set_show_names(v)
    _esp_state.show_names = v and true or false
    for _, label in pairs(_esp_state.labels) do
        if label.name_label then
            label.name_label.Visible = _esp_state.show_names
        end
    end
end

-- ═══════════════════════════════════════════════════════════
--  [14] UI — بسيط
-- ═══════════════════════════════════════════════════════════

local UI = {}

local _ui_state = { gui = nil, open = true, main = nil }

local function create_ui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FarexpullHub"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    local parent_ok = pcall(function()
        if gethui then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
    if not parent_ok then
    pcall(function() gui.Parent = CoreGui end)
    end
    
-- Title bar (بداية)
    local title_bar = Instance.new("Frame")
    title_bar.Name = "TitleBar"
    title_bar.Size = UDim2.new(1, 0, 0, 40)
    title_bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    title_bar.BorderSizePixel = 0
    title_bar.Parent = gui

    local tb_corner = Instance.new("UICorner")
    tb_corner.CornerRadius = UDim.new(0, 10)
    tb_corner.Parent = title_bar

    local title_label = Instance.new("TextLabel")
    title_label.Size = UDim2.new(0, 200, 0, 30)
    title_label.Position = UDim2.new(0, 15, 0, 5)
    title_label.BackgroundTransparency = 1
    title_label.Text = "FAREXPULL"
    title_label.TextColor3 = Color3.fromRGB(99, 102, 241)
    title_label.TextSize = 18
    title_label.Font = Enum.Font.GothamBlack
    title_label.TextXAlignment = Enum.TextXAlignment.Left
    title_label.Parent = title_bar

    -- Body
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -40)
    body.Position = UDim2.new(0, 0, 0, 40)
    body.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    body.BorderSizePixel = 0
    body.Parent = gui

    -- Content area
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -20, 1, -20)
    content.Position = UDim2.new(0, 10, 0, 10)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(99, 102, 241)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Parent = body

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    -- Helper: toggle
    local function add_toggle(parent, label, get_cb, set_cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = parent

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = btn

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 36, 0, 18)
        indicator.Position = UDim2.new(1, -48, 0.5, -9)
        indicator.BackgroundColor3 = get_cb() and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(40, 40, 55)
        indicator.BorderSizePixel = 0
        indicator.Parent = btn

        local ic = Instance.new("UICorner")
        ic.CornerRadius = UDim.new(1, 0)
        ic.Parent = indicator

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 14, 0, 14)
        dot.Position = get_cb() and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BorderSizePixel = 0
        dot.Parent = indicator

        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot

        local function refresh()
            local on = get_cb()
            indicator.BackgroundColor3 = on and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(40, 40, 55)
            dot.Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end

        btn.MouseButton1Click:Connect(function()
            set_cb(not get_cb())
            refresh()
        end)

        return refresh
    end

    -- Toggles
    add_toggle(content, "Auto Parry",
        function() return _parry_config.enabled end,
        function(v) if v then Parry.start() else Parry.stop() end end
    )
    add_toggle(content, "Triggerbot",
        function() return _parry_config.triggerbot end,
        function(v) _parry_config.triggerbot = v end
    )
    add_toggle(content, "Manual Spam",
        function() return _spam_state.manual_active end,
        function(v) if v then Spam.start_manual() else Spam.stop_manual() end end
    )
    add_toggle(content, "Auto Spam",
        function() return _spam_state.auto_active end,
        function(v) if v then Spam.start_auto() else Spam.stop_auto() end end
    )
    add_toggle(content, "Auto Preclick",
        function() return _pc_config.enabled end,
        function(v) if v then Preclick.start() else Preclick.stop() end end
    )
    add_toggle(content, "Immortality",
        function() return _imm_state.enabled end,
        function(v) if v then Immortal.start() else Immortal.stop() end end
    )
    add_toggle(content, "Anti Phantom",
        function() return _ap_config.phantom end,
        function(v) AntiPhantom.set_phantom(v) end
    )
    add_toggle(content, "Anti Flash Counter",
        function() return _ap_config.flash end,
        function(v) AntiPhantom.set_flash(v) end
    )
    add_toggle(content, "Ability ESP",
        function() return _esp_state.active end,
        function(v) if v then ESP.start() else ESP.stop() end end
    )
    add_toggle(content, "Show Names",
        function() return _esp_state.show_names end,
        function(v) ESP.set_show_names(v) end
    )
    add_toggle(content, "Anti-Cheat Scanner",
        function() return _ac_conn ~= nil end,
        function(v) if v then AntiCheat.start() else AntiCheat.stop() end end
    )

    _ui_state.gui = gui
    _ui_state.open = true

    print("[Farexpull] UI created successfully")
end

create_ui()

-- Keybind RC / RightAlt
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightAlt then
        if _ui_state.gui then
            _ui_state.open = not _ui_state.open
            _ui_state.gui.Enabled = _ui_state.open
        end
    end
end)

-- Startup
AntiCheat.start()
pcall(Remote.discover)
pcall(Config.run_autoload)

print("[Farexpull] Hub v2 loaded successfully | Device: " .. detect_device())

getgenv().FarexpullShutdown = function()
    pcall(function() Parry.stop() end)
    pcall(function() Spam.stop() end)
    pcall(function() Immortal.stop() end)
    pcall(function() AntiPhantom.stop() end)
    pcall(function() Preclick.stop() end)
    pcall(function() ESP.stop() end)
    pcall(function() AntiCheat.stop() end)
    pcall(function() Input.remove_all_mobile_buttons() end)
    if _ui_state.gui then
        pcall(function() _ui_state.gui:Destroy() end)
    end
    for name, conn in pairs(STATE.connections) do
        pcall(function() conn:Disconnect() end)
    end
    STATE.connections = {}
    print("[Farexpull] Shutdown complete")
end
