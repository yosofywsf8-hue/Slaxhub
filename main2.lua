--[[
================================================================================
    BB-Pro Lite : Blade Ball AutoParry (single file, no WindUI)
    (c) ALPHA XK
    Compatible: executor level 5+ (getgc optional; debug.getupvalues required
                for token discovery — kalau nggak ada, script stop bersih
                dengan pesan jelas)
    Stop: _G.BB_PRO_RUNNING = false
    Usage:
      1. Inject ke Blade Ball.
      2. Parry manual SEKALI (klik kanan / bind parry lo).
      3. HUD update, loop fire.
================================================================================
]]

-- ============================================================
-- 0. SAFE GLOBALS (fallback chain)
-- ============================================================
local cloneref = cloneref or function(o) return o end
local typeof   = typeof   or function(v) return type(v) end

local function safe_service(name)
    local ok, s = pcall(game.GetService, game, name)
    if ok and s then return s end
    return game:FindService(name)
end

local RS      = cloneref(safe_service("ReplicatedStorage"))
local WS      = cloneref(safe_service("Workspace"))
local Players = cloneref(safe_service("Players"))
local LP      = Players and Players.LocalPlayer

if not (RS and WS and Players and LP) then
    warn("[BB-Pro Lite] services missing — inject di game Roblox, bukan luar")
    return
end

-- ============================================================
-- 1. CAPABILITY CHECK (stop bersih kalau kurang)
-- ============================================================
local caps = {
    getgc             = type(getgc) == "function",
    debug_info        = type(debug) == "table" and type(debug.info) == "function",
    debug_getupvalues = type(debug) == "table" and type(debug.getupvalues) == "function",
    getrawmetatable   = type(getrawmetatable) == "function",
    setreadonly       = type(setreadonly) == "function",
    bit32             = type(bit32) == "table",
}

for k, v in pairs(caps) do
    print(("[BB-Pro Lite] cap %-20s : %s"):format(k, v and "OK" or "MISSING"))
end

if not (caps.getgc and caps.debug_info and caps.debug_getupvalues) then
    warn("[BB-Pro Lite] executor kekurangan: getgc / debug.info / debug.getupvalues")
    warn("             ganti ke Wave, Fluxus, Solara terbaru, Synapse, Script-Ware")
    return
end

-- ============================================================
-- 2. TOKEN DISCOVERY
-- ============================================================
local _tokenFn

local function discover_token_fn()
    local candidates = {}
    for _, f in ipairs(getgc(true)) do
        if type(f) ~= "function" then continue end
        local ok, src = pcall(debug.info, f, "s")
        if not ok or type(src) ~= "string" or not src:find("PRY", 1, true) then
            continue
        end
        for _, up in ipairs(debug.getupvalues(f)) do
            if type(up) == "function" then
                -- verify: harus callable dengan (uid, "TIME") → string
                local ok2, test = pcall(up, "test", "TIME")
                if ok2 and type(test) == "string" and #test > 0 then
                    table.insert(candidates, up)
                end
            end
        end
    end
    return candidates[1]   -- ambil yang pertama verified
end

_tokenFn = discover_token_fn()
if not _tokenFn then
    warn("[BB-Pro Lite] token fn not found")
    warn("             cek: apa parry remote Blade Ball punya source 'PRY'?")
    return
end
print("[BB-Pro Lite] token fn verified")

local function tokenize(uid)
    local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local key = _tokenFn(uid, "TIME")
    if type(key) ~= "string" or #key == 0 then return nil end
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)))
    end
    return table.concat(out)
end

-- ============================================================
-- 3. REMOTE HOOK (__index + __namecall fallback)
-- ============================================================
local _cap = { args = nil, remote = nil, t = 0 }
local _hooked_mts = {}
local _old_indexes = {}

local function is_valid_args(a)
    if type(a) ~= "table" then return false end
    if #a ~= 8 then return false end
    if type(a[2]) ~= "string" then return false end
    if type(a[3]) ~= "string" then return false end
    if type(a[4]) ~= "number" then return false end
    if typeof(a[5]) ~= "CFrame" then return false end
    if type(a[6]) ~= "table" then return false end
    if type(a[7]) ~= "table" then return false end
    if type(a[8]) ~= "boolean" then return false end
    return true
end

local function attach(remote)
    local ok, mt = pcall(getrawmetatable, remote)
    if not ok or not mt or _hooked_mts[mt] then return end
    _hooked_mts[mt] = true

    local ok2 = pcall(setreadonly, mt, false)
    if not ok2 then return end   -- metatable protected, skip

    _old_indexes[mt] = mt.__index

    mt.__index = function(self, key)
        if (key == "FireServer" and self:IsA("RemoteEvent"))
        or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return function(_, ...)
                local a = { ... }
                if not _cap.args and is_valid_args(a) then
                    _cap.args   = a
                    _cap.remote = self
                    _cap.t      = tick()
                    print("[BB-Pro Lite] captured on " .. self:GetFullName())
                end
                return _old_indexes[mt](self, key)(_, ...)
            end
        end
        return _old_indexes[mt](self, key)
    end

    pcall(setreadonly, mt, true)
end

local function scan_remotes()
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            attach(obj)
        end
    end
end

scan_remotes()
print("[BB-Pro Lite] remotes hooked")

-- ============================================================
-- 4. HUD (CoreGui → PlayerGui → gethui fallback)
-- ============================================================
local function make_hud()
    local sg = Instance.new("ScreenGui")
    sg.Name = "BBProLite"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parents = {}
    pcall(function()
        if gethui then table.insert(parents, gethui()) end
    end)
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    if LP then
        local pg = LP:FindFirstChildOfClass("PlayerGui")
                    or LP:WaitForChild("PlayerGui", 3)
        if pg then table.insert(parents, pg) end
    end

    for _, p in ipairs(parents) do
        local ok = pcall(function() sg.Parent = p end)
        if ok and sg.Parent then break end
    end
    if not sg.Parent then
        warn("[BB-Pro Lite] HUD parent fail — script tetap jalan, cek console")
        return nil
    end

    local box = Instance.new("TextLabel", sg)
    box.Size = UDim2.new(0, 340, 0, 90)
    box.Position = UDim2.new(0, 20, 0, 20)
    box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    box.BackgroundTransparency = 0.12
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 13
    box.TextColor3 = Color3.fromRGB(220, 220, 220)
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Text = "BB-Pro Lite\ninit..."
    local c = Instance.new("UICorner", box)
    c.CornerRadius = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 8)

    return box
end

local hud = make_hud()

local function set_hud(text)
    if hud then pcall(function() hud.Text = text end) end
end

-- ============================================================
-- 5. WAIT CAPTURE (non-blocking — loop tetap mulai)
-- ============================================================
print("[BB-Pro Lite] parry manual SEKALI untuk capture args")

-- ============================================================
-- 6. MAIN LOOP
-- ============================================================
local stats = { sent = 0, rej = 0, start = tick(), tps = 0, tps_win = 0, tps_count = 0 }
local last_fire = 0
local FIRE_COOLDOWN = 0.12

-- rolling 1s window untuk tps display
local tps_events = {}

_G.BB_PRO_RUNNING = true

local function should_fire_now()
    -- simple fire policy: fire kalau ada remote + token
    -- (prediction layer opsional, di versi Lite kita spam cooldown-limited)
    return true
end

while _G.BB_PRO_RUNNING do
    -- re-scan kalau belum capture
    if not _cap.args then
        scan_remotes()
    end

    if _cap.args and _cap.remote and _cap.remote.Parent then
        local now = tick()
        if now - last_fire >= FIRE_COOLDOWN and should_fire_now() then
            local uid = _cap.args[2]
            local tok = tokenize(uid)
            if tok then
                local packet = {
                    _cap.args[1], uid, tok, 0.5,
                    WS.CurrentCamera.CFrame, {}, {0, 0}, false
                }
                local ok = pcall(function()
                    if _cap.remote:IsA("RemoteEvent") then
                        _cap.remote:FireServer(table.unpack(packet))
                    else
                        _cap.remote:InvokeServer(table.unpack(packet))
                    end
                end)
                last_fire = now
                stats.sent = stats.sent + 1
                if not ok then stats.rej = stats.rej + 1 end
                table.insert(tps_events, now)
            else
                -- token fn stale, redetect
                _tokenFn = discover_token_fn()
                if not _tokenFn then
                    warn("[BB-Pro Lite] token fn hilang — stop")
                    break
                end
            end
        end
    end

    -- prune tps
    do
        local cutoff = tick() - 1
        local kept = {}
        for _, t in ipairs(tps_events) do
            if t >= cutoff then table.insert(kept, t) end
        end
        tps_events = kept
        stats.tps = #tps_events
    end

    -- HUD
    if hud then
        local status = _cap.args and "running" or "waiting capture"
        set_hud(("[BB-Pro Lite] %s\nsent=%d  rej=%d  rate=%d/s\ntok_len=%d  uptime=%ds")
            :format(
                status,
                stats.sent, stats.rej, stats.tps,
                _cap.args and #_cap.args[2] or 0,
                math.floor(tick() - stats.start)))
    end

    task.wait(0.05)   -- 20Hz loop; FIRE_COOLDOWN 120ms → max ~8/s
end

set_hud("[BB-Pro Lite] stopped")
print(("[BB-Pro Lite] stopped. sent=%d reject=%d"):format(stats.sent, stats.rej))
