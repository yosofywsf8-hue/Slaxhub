--[[
================================================================================
    BB-Pro MAX : Blade Ball AutoParry
    (c) ALPHA XK — standalone, zero-dependency, full fallback
    Usage:
      1. Inject ke Blade Ball.
      2. Parry manual SEKALI (klik kanan / bind parry lo).
      3. HUD tampil, loop jalan.
      4. Stop: _G.BB_PRO_RUNNING = false
    Compatible: executor dengan minimal `getrawmetatable` + `setreadonly`.
                Kalau `getgc`/`debug.getupvalues` nggak ada, pakai fallback
                token mode (arg capture replay).
================================================================================
]]

-- ============================================================
-- 0. SAFE GLOBALS (semua dengan fallback)
-- ============================================================
local cloneref = cloneref or function(o) return o end
local typeof   = typeof   or function(v) return type(v) end
local getnamecallmethod = getnamecallmethod or function() return nil end

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
    warn("[BB-Pro MAX] services missing")
    return
end

-- ============================================================
-- 1. CAPABILITY REPORT
-- ============================================================
local CAP = {
    getgc             = type(getgc) == "function",
    debug_info        = type(debug) == "table" and type(debug.info) == "function",
    debug_getupvalues = type(debug) == "table" and type(debug.getupvalues) == "function",
    getrawmetatable   = type(getrawmetatable) == "function",
    setreadonly       = type(setreadonly) == "function",
    hookmetamethod    = type(hookmetamethod) == "function",
    bit32             = type(bit32) == "table",
    gethui            = type(gethui) == "function",
    is_syn            = type(syn) == "table",
    is_krnl           = type(KRNL_LOADED) ~= "nil" or type(krnl) == "table",
}

local diag_lines = {}
local function diag(s)
    table.insert(diag_lines, s)
    print("[BB-Pro MAX] " .. s)
    -- keep last 12 lines
    while #diag_lines > 12 do table.remove(diag_lines, 1) end
end

diag("executor caps:")
for k, v in pairs(CAP) do
    diag(("  %-20s %s"):format(k, v and "OK" or "--"))
end

if not (CAP.getrawmetatable and CAP.setreadonly) then
    diag("FATAL: executor kurang getrawmetatable/setreadonly")
    warn("[BB-Pro MAX] stop — executor lo nggak bisa hook remote")
    return
end

-- ============================================================
-- 2. TOKEN DISCOVERY (3 strategi)
-- ============================================================
local _tokenFn = nil
local _tokenMode = "none"    -- "regen" | "replay" | "none"

-- Strategi A: scan getgc for source 'PRY' + upvalue function verified
local function strategy_gc_pry()
    if not (CAP.getgc and CAP.debug_info and CAP.debug_getupvalues) then
        return nil
    end
    for _, f in ipairs(getgc(true)) do
        if type(f) ~= "function" then continue end
        local ok, src = pcall(debug.info, f, "s")
        if not ok or type(src) ~= "string" or not src:find("PRY", 1, true) then
            continue
        end
        for _, up in ipairs(debug.getupvalues(f)) do
            if type(up) == "function" then
                local ok2, test = pcall(up, "test_uid", "TIME")
                if ok2 and type(test) == "string" and #test > 0 then
                    return up
                end
            end
        end
    end
    return nil
end

-- Strategi B: scan getgc for upvalue function dengan signature (string,string)->string
--             tanpa perlu 'PRY' string match (kalau Blade Ball ganti source name)
local function strategy_gc_generic()
    if not (CAP.getgc and CAP.debug_getupvalues) then return nil end
    for _, f in ipairs(getgc(true)) do
        if type(f) ~= "function" then continue end
        local ok_iv, ups = pcall(debug.getupvalues, f)
        if not ok_iv or not ups then continue end
        for _, up in ipairs(ups) do
            if type(up) == "function" then
                local ok2, r1 = pcall(up, "x", "TIME")
                local ok3, r2 = pcall(up, "y", "TIME")
                if ok2 and ok3
                and type(r1) == "string" and type(r2) == "string"
                and #r1 > 0 and #r2 > 0
                and r1 ~= r2 then
                    return up
                end
            end
        end
    end
    return nil
end

-- Strategi C: replay mode — nggak butuh token fn, pakai args yang di-capture
--             (token dari parry manual terakhir, di-reuse; kurang stealth, tapi jalan)
local function strategy_replay()
    return nil   -- placeholder: aktif kalau A dan B gagal
end

_tokenFn = strategy_gc_pry() or strategy_gc_generic()

if _tokenFn then
    _tokenMode = "regen"
    diag("token: regen mode (fn verified)")
else
    _tokenMode = "replay"
    diag("token: replay mode (no fn — pakai args capture apa adanya)")
end

-- ============================================================
-- 3. TOKENIZE (regen mode)
-- ============================================================
local function tokenize(uid)
    if _tokenMode ~= "regen" or not _tokenFn then return nil end
    local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local ok, key = pcall(_tokenFn, uid, "TIME")
    if not ok or type(key) ~= "string" or #key == 0 then return nil end
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)))
    end
    return table.concat(out)
end

-- ============================================================
-- 4. HOOK (multi-strategy)
-- ============================================================
local _cap = { args = nil, remote = nil, t = 0 }
local _hooked_mts = {}
local _old_indexes = {}
local _namecall_methods = { FireServer = true, InvokeServer = true }

local function is_valid_args(a)
    return type(a) == "table"
        and #a == 8
        and type(a[2]) == "string"
        and type(a[3]) == "string"
        and type(a[4]) == "number"
        and typeof(a[5]) == "CFrame"
        and type(a[6]) == "table"
        and type(a[7]) == "table"
        and type(a[8]) == "boolean"
end

local function capture(self, a)
    if not _cap.args and is_valid_args(a) then
        _cap.args = a
        _cap.remote = self
        _cap.t = tick()
        diag("captured on " .. self:GetFullName())
    end
end

-- Strategi A: __index
local function attach_index(remote)
    local ok, mt = pcall(getrawmetatable, remote)
    if not ok or not mt or _hooked_mts[mt] then return false end
    _hooked_mts[mt] = true
    local ok2 = pcall(setreadonly, mt, false)
    if not ok2 then return false end

    _old_indexes[mt] = mt.__index

    local ok3 = pcall(function()
        mt.__index = function(self, key)
            if (key == "FireServer" and self:IsA("RemoteEvent"))
            or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
                return function(_, ...)
                    local a = { ... }
                    capture(self, a)
                    return _old_indexes[mt](self, key)(_, ...)
                end
            end
            return _old_indexes[mt](self, key)
        end
    end)

    pcall(setreadonly, mt, true)
    return ok3
end

-- Strategi B: hookmetamethod (kalau ada)
local function attach_hookmeta(remote)
    if not CAP.hookmetamethod then return false end
    local ok, mt = pcall(getrawmetatable, remote)
    if not ok or not mt or _hooked_mts["hm_" .. tostring(mt)] then return false end
    _hooked_mts["hm_" .. tostring(mt)] = true

    pcall(function()
        local old = hookmetamethod(remote, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method and _namecall_methods[method] then
                local a = { ... }
                capture(self, a)
            end
            return old(self, ...)
        end)
    end)
    return true
end

local function scan_and_hook()
    local n = 0
    for _, obj in ipairs(RS:GetDescendants()) do
        if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then continue end
        n = n + 1
        if not attach_index(obj) then
            attach_hookmeta(obj)
        end
    end
    return n
end

local remote_count = scan_and_hook()
diag("remotes scanned: " .. remote_count)

-- ============================================================
-- 5. HUD (multi-parent fallback)
-- ============================================================
local HUD = { label = nil, gui = nil }

local function build_hud()
    local sg = Instance.new("ScreenGui")
    sg.Name = "BBProMAX_" .. tostring(math.random(1e6))
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parents = {}
    if CAP.gethui then pcall(function() table.insert(parents, gethui()) end) end
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    if LP then
        pcall(function()
            local pg = LP:FindFirstChildOfClass("PlayerGui")
                       or LP:WaitForChild("PlayerGui", 3)
            if pg then table.insert(parents, pg) end
        end)
    end

    for _, p in ipairs(parents) do
        if p then
            local ok = pcall(function() sg.Parent = p end)
            if ok and sg.Parent then break end
        end
    end

    if not sg.Parent then
        warn("[BB-Pro MAX] HUD parent fail — script tetap jalan")
        return
    end

    local box = Instance.new("TextLabel", sg)
    box.Size = UDim2.new(0, 380, 0, 130)
    box.Position = UDim2.new(0, 20, 0, 20)
    box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    box.BackgroundTransparency = 0.12
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(220, 220, 220)
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Text = "BB-Pro MAX\nbooting..."
    box.ZIndex = 10

    local c = Instance.new("UICorner", box)
    c.CornerRadius = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 8)

    HUD.label = box
    HUD.gui = sg
end

build_hud()

local function set_hud(s)
    if HUD.label then pcall(function() HUD.label.Text = s end) end
end

-- ============================================================
-- 6. MAIN LOOP
-- ============================================================
local stats = { sent = 0, rej = 0, start = tick(), tps_events = {} }
local last_fire = 0
local FIRE_COOLDOWN = 0.12
local rescan_timer = 0

local function fire_once()
    local uid = _cap.args[2]
    local tok

    if _tokenMode == "regen" then
        tok = tokenize(uid)
        if not tok then return false, "token fail" end
    else
        -- replay mode: pakai token asli yang ada di _cap.args[3]
        -- (nggak regen — server mungkin reject setelah token expire, tapi tetap jalan)
        tok = _cap.args[3]
    end

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
    return ok
end

_G.BB_PRO_RUNNING = true
diag("loop started — parry manual sekali")

while _G.BB_PRO_RUNNING do
    local now = tick()

    -- periodic rescan (kalau remote baru muncul)
    if now - rescan_timer > 5 then
        rescan_timer = now
        if not _cap.args then
            scan_and_hook()
        end
    end

    -- fire
    if _cap.args and _cap.remote and _cap.remote.Parent then
        if now - last_fire >= FIRE_COOLDOWN then
            local ok, err = fire_once()
            last_fire = now
            stats.sent = stats.sent + 1
            if not ok then stats.rej = stats.rej + 1 end
            table.insert(stats.tps_events, now)
        end
    end

    -- prune tps
    do
        local cutoff = now - 1
        local kept = {}
        for _, t in ipairs(stats.tps_events) do
            if t >= cutoff then table.insert(kept, t) end
        end
        stats.tps_events = kept
    end

    -- HUD
    local status
    if not _cap.args then
        status = "WAIT: parry manual sekali"
    elseif not _cap.remote.Parent then
        status = "WAIT: remote detached"
    else
        status = "RUN"
    end
    local token_info = (_tokenMode == "regen")
        and ("regen (fn " .. tostring(_tokenFn and "ok" or "?") .. ")")
        or  "replay"
    set_hud(table.concat({
        "BB-Pro MAX",
        "status    : " .. status,
        "token     : " .. token_info,
        "remotes   : " .. tostring(remote_count),
        ("sent/rej  : %d/%d"):format(stats.sent, stats.rej),
        ("rate      : %d/s"):format(#stats.tps_events),
        ("uptime    : %ds"):format(math.floor(now - stats.start)),
        "last diag : " .. (diag_lines[#diag_lines] or "-"),
    }, "\n"))

    task.wait(0.05)
end

set_hud("BB-Pro MAX — stopped")
diag(("stopped. sent=%d rej=%d"):format(stats.sent, stats.rej))
