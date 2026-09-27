--[[
================================================================================
    BB-Pro + WindUI : Blade Ball AutoParry Pro
    (c) ALPHA XK  — single-file build with WindUI
    Requires: executor level 7+ (getgc, cloneref, getrawmetatable, setreadonly,
              debug.info, debug.getupvalues, bit32, workspace:GetServerTimeNow,
              game:HttpGet or request)
    WindUI  : https://github.com/Footagesus/WindUI
    Stop    : _G.BB_PRO_RUNNING = false
================================================================================
]]

-- ============================================================
-- 0. GLOBALS + SAFE LOADERS
-- ============================================================
local cloneref = cloneref or function(o) return o end

local RS      = cloneref(game:GetService("ReplicatedStorage"))
local WS      = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local RunSvc  = cloneref(game:GetService("RunService"))
local CG      = cloneref(game:GetService("CoreGui"))
local LP      = Players.LocalPlayer

local _WINDUITY_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

-- ============================================================
-- 1. LOAD WINDUITY
-- ============================================================
local WindUI
do
    local ok, res = pcall(function()
        if _G.BB_WINDUITY_OVERRIDE then return _G.BB_WINDUITY_OVERRIDE end
        return loadstring(game:HttpGet(_WINDUITY_URL))()
    end)
    if not ok or not res then
        warn("[BB-Pro] WindUI load fail: " .. tostring(res) ..
             " — pakai executor dengan HttpGet, atau set _G.BB_WINDUITY_OVERRIDE")
        return
    end
    WindUI = res
    print("[BB-Pro] WindUI loaded, version: " .. tostring(WindUI.Version or "?"))
end

-- ============================================================
-- 2. LICENSE
-- ============================================================
local License = {}
function License.check(user_key)
    if user_key == nil or user_key == "TRIAL" then
        return true, os.time() + 7 * 86400
    end
    return true, os.time() + 7 * 86400
end

-- ============================================================
-- 3. STATE
-- ============================================================
local state = {
    enabled     = true,
    smart       = true,
    force       = false,
    anti_kick   = true,
    debug       = false,
    lead        = 0.12,
    parry_radius= 32,
    max_rate    = 22,
}

-- ============================================================
-- 4. TOKEN
-- ============================================================
local Token = {}
local _tokenFn

local function _discover_token_fn()
    for _, f in ipairs(getgc(true)) do
        if type(f) ~= "function" then continue end
        local ok, src = pcall(debug.info, f, "s")
        if not ok or type(src) ~= "string" or not src:find("PRY", 1, true) then
            continue
        end
        for _, up in ipairs(debug.getupvalues(f)) do
            if type(up) == "function" then
                return up
            end
        end
    end
    return nil
end

function Token.init()
    _tokenFn = _discover_token_fn()
    return _tokenFn ~= nil
end

function Token.redetect()
    _tokenFn = nil
    return Token.init()
end

function Token.tokenize(uid, server_time_now)
    if not _tokenFn then
        if not Token.redetect() then return nil end
    end
    local t   = tostring(math.floor(server_time_now * 100))
    local key = _tokenFn(uid, "TIME")
    if type(key) ~= "string" or #key == 0 then return nil end
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)
        ))
    end
    return table.concat(out)
end

-- ============================================================
-- 5. HOOK
-- ============================================================
local Hook = {}
local _captured = { args = nil, remote = nil, t = 0 }
local _hooked_mts = {}
local _old_indexes = {}

local function _is_valid_args(args)
    return #args == 8
        and type(args[2]) == "string"
        and type(args[3]) == "string"
        and type(args[4]) == "number"
        and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table"
        and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _attach(remote)
    local ok, mt = pcall(getrawmetatable, remote)
    if not ok or not mt or _hooked_mts[mt] then return end
    _hooked_mts[mt] = true
    setreadonly(mt, false)
    _old_indexes[mt] = mt.__index
    mt.__index = function(self, key)
        if (key == "FireServer"   and self:IsA("RemoteEvent"))
        or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return function(_, ...)
                local a = { ... }
                if not _captured.args and _is_valid_args(a) then
                    _captured.args   = a
                    _captured.remote = self
                    _captured.t      = tick()
                end
                return _old_indexes[mt](self, key)(_, ...)
            end
        end
        return _old_indexes[mt](self, key)
    end
    setreadonly(mt, true)
end

function Hook.scan(replicated_storage)
    for _, obj in ipairs(replicated_storage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            _attach(obj)
        end
    end
end

function Hook.get()    return _captured end
function Hook.reset()  _captured = { args = nil, remote = nil, t = 0 } end

-- ============================================================
-- 6. PREDICT
-- ============================================================
local Predict = {}
Predict.__index = Predict

function Predict.new(ws)
    return setmetatable({ ws = ws }, Predict)
end

local function _get_hrp(lp)
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function _find_balls(ws)
    local out = {}
    for _, d in ipairs(ws:GetDescendants()) do
        if d:IsA("BasePart")
        and d.Name:find("Ball")
        and d.AssemblyLinearVelocity.Magnitude > 5 then
            table.insert(out, d)
        end
    end
    return out
end

function Predict:eta(ball, hrp, r)
    local rel = hrp.Position - ball.Position
    local v   = ball.AssemblyLinearVelocity
    local a   = v:Dot(v)
    if a < 1e-4 then return math.huge end
    local b   = 2 * rel:Dot(v)
    local c   = rel:Dot(rel) - r * r
    local disc = b * b - 4 * a * c
    if disc < 0 then return math.huge end
    local sq = math.sqrt(disc)
    local t1 = (-b - sq) / (2 * a)
    local t2 = (-b + sq) / (2 * a)
    if t1 >= 0 then return t1 end
    if t2 >= 0 then return t2 end
    return math.huge
end

function Predict:nearest_impact(lp, r)
    local hrp = _get_hrp(lp)
    if not hrp then return nil end
    local best, best_t = nil, math.huge
    for _, b in ipairs(_find_balls(self.ws)) do
        local t = self:eta(b, hrp, r)
        if t < best_t then best_t, best = t, b end
    end
    if not best then return nil end
    return {
        ball = best,
        eta = best_t,
        distance = (best.Position - hrp.Position).Magnitude,
    }
end

-- ============================================================
-- 7. ACCURACY
-- ============================================================
local Acc = {}
Acc.__index = Acc

function Acc.new(window)
    return setmetatable({
        window = window or 30,
        events = {},
        tp = 0, fp = 0, fn = 0,
    }, Acc)
end

function Acc:record(kind, now)
    now = now or tick()
    table.insert(self.events, { t = now, kind = kind })
    if     kind == "tp" then self.tp = self.tp + 1
    elseif kind == "fp" then self.fp = self.fp + 1
    elseif kind == "fn" then self.fn = self.fn + 1 end
    local cutoff = now - self.window
    local kept = {}
    for _, e in ipairs(self.events) do
        if e.t >= cutoff then table.insert(kept, e) end
    end
    self.events = kept
end

function Acc:snapshot()
    local tp, fp, fn = 0, 0, 0
    for _, e in ipairs(self.events) do
        if     e.kind == "tp" then tp = tp + 1
        elseif e.kind == "fp" then fp = fp + 1
        elseif e.kind == "fn" then fn = fn + 1 end
    end
    local precision = (tp + fp > 0) and (tp / (tp + fp)) or 1.0
    local recall    = (tp + fn > 0) and (tp / (tp + fn)) or 1.0
    local f1        = (precision + recall > 0) and (2 * precision * recall / (precision + recall)) or 0.0
    return {
        tp = tp, fp = fp, fn = fn,
        precision = precision, recall = recall, f1 = f1,
        hit_rate = recall,
    }
end

-- ============================================================
-- 8. TUNE
-- ============================================================
local Tune = {}
Tune.__index = Tune

function Tune.new(acc, opts)
    opts = opts or {}
    return setmetatable({
        acc = acc,
        lead = opts.lead or 0.12,
        step = 0.01,
        min_lead = 0.05,
        max_lead = 0.25,
        last_eval = 0,
        eval_window = 15,
    }, Tune)
end

function Tune:tick(now)
    now = now or tick()
    if now - self.last_eval < self.eval_window then return end
    self.last_eval = now
    local s = self.acc:snapshot()
    if s.recall < 0.90 and s.fn > 0 then
        self.lead = math.min(self.lead + self.step, self.max_lead)
    end
    if s.precision < 0.85 and s.fp > 3 then
        self.lead = math.max(self.lead - self.step, self.min_lead)
    end
end

-- ============================================================
-- 9. RATE LIMITER
-- ============================================================
local RL = {}
RL.__index = RL

function RL.new(max_per_sec, window)
    return setmetatable({
        max = max_per_sec or 22,
        window = window or 1.0,
        events = {},
        consecutive_rejects = 0,
        backoff_until = 0,
    }, RL)
end

function RL:allow(now)
    now = now or tick()
    if now < self.backoff_until then return false, "backoff" end
    local cutoff = now - self.window
    local kept = {}
    for _, t in ipairs(self.events) do
        if t >= cutoff then table.insert(kept, t) end
    end
    self.events = kept
    if #self.events >= self.max then return false, "ratelimit" end
    table.insert(self.events, now)
    return true
end

function RL:report(ok)
    if ok then
        self.consecutive_rejects = 0
    else
        self.consecutive_rejects = self.consecutive_rejects + 1
        if self.consecutive_rejects >= 3 then
            local backoff = math.min(2 ^ self.consecutive_rejects, 30)
            self.backoff_until = tick() + backoff
        end
    end
end

-- ============================================================
-- 10. BOOT CORE
-- ============================================================
local ok, exp = License.check(_G.BB_KEY or "TRIAL")
if not ok then
    warn("[BB-Pro] license fail: " .. tostring(exp))
    return
end

if not Token.init() then
    warn("[BB-Pro] token fn not found — re-inject atau update script")
    return
end
print("[BB-Pro] token fn discovered")

Hook.scan(RS)
print("[BB-Pro] remotes hooked")

local predict = Predict.new(WS)
local acc     = Acc.new(30)
local tune    = Tune.new(acc, { lead = state.lead })
local rl      = RL.new(state.max_rate, 1.0)

-- ============================================================
-- 11. WINDUITY INTERFACE
-- ============================================================
local Window = WindUI:CreateWindow({
    Title       = "BB-Pro",
    Icon        = "solar:shield-check-bold",
    Author      = "ALPHA XK",
    Folder      = "BB-Pro",
    Size        = UDim2.fromOffset(520, 380),
    Transparent = true,
    Theme       = "Dark",
    User        = {
        Enabled = true,
        Anonymous = true,
    },
    KeySystem   = false,
})

-- ============================================================
-- 12. HUD (Topbar)
-- ============================================================
local hud_text = Window.Topbar and Window.Topbar.AddLabel
    and Window.Topbar:AddLabel("Accuracy: --")
    or nil

local hud_ref = { label = hud_text }
task.spawn(function()
    while _G.BB_PRO_RUNNING do
        local s = acc:snapshot()
        local txt = string.format(
            "hit %.0f%% · prec %.0f%% · F1 %.2f · TP/FP/FN %d/%d/%d · lead %.3f",
            s.hit_rate * 100, s.precision * 100, s.f1,
            s.tp, s.fp, s.fn, tune.lead)
        if hud_ref.label then
            pcall(function() hud_ref.label:Set(txt) end)
        end
        task.wait(0.75)
    end
end)

-- ============================================================
-- 13. TAB: AUTO PARRY
-- ============================================================
local TabMain = Window:Tab({
    Title = "AutoParry",
    Icon  = "solar:crosshair-bold",
})

local SecGeneral = TabMain:Section({
    Title = "General",
    TextXAlignment = "Left",
})

SecGeneral:Toggle({
    Title       = "Enable AutoParry",
    Desc        = "Master switch. Turn off to pause loop.",
    Value       = true,
    Callback    = function(v) state.enabled = v end,
})

SecGeneral:Toggle({
    Title       = "Smart Timing",
    Desc        = "Fire hanya kalau ETA masuk window. Hemat request.",
    Value       = true,
    Callback    = function(v) state.smart = v end,
})

SecGeneral:Toggle({
    Title       = "Force (Rage)",
    Desc        = "Spam tiap frame, abaikan prediction. Risiko kick naik.",
    Value       = false,
    Callback    = function(v) state.force = v end,
})

SecGeneral:Toggle({
    Title       = "Anti-Kick",
    Desc        = "Rolling window + exponential backoff saat reject.",
    Value       = true,
    Callback    = function(v)
        state.anti_kick = v
        rl.max = v and state.max_rate or 60
    end,
})

SecGeneral:Toggle({
    Title       = "Debug Log",
    Desc        = "Print per-event ke console.",
    Value       = false,
    Callback    = function(v) state.debug = v end,
})

-- ============================================================
-- 14. TAB: TUNING
-- ============================================================
local TabTune = Window:Tab({
    Title = "Tuning",
    Icon  = "solar:tuning-2-bold",
})

local SecTune = TabTune:Section({
    Title = "Prediction",
    TextXAlignment = "Left",
})

local sliderLead, sliderRadius, sliderRate

sliderLead = SecTune:Slider({
    Title       = "Lead Time (s)",
    Desc        = "Fire N detik sebelum ETA. Auto-tune kalau OFF.",
    Value       = { Min = 0.05, Max = 0.25, Default = 0.12 },
    Rounding    = 3,
    Callback    = function(v)
        state.lead = v
        tune.lead  = v
    end,
})

sliderRadius = SecTune:Slider({
    Title       = "Parry Radius (studs)",
    Desc        = "Radius deteksi bola masuk window.",
    Value       = { Min = 15, Max = 60, Default = 32 },
    Rounding    = 1,
    Callback    = function(v)
        state.parry_radius = v
    end,
})

sliderRate = SecTune:Slider({
    Title       = "Max Rate (req/s)",
    Desc        = "Rate limiter ceiling. Anti-kick pakai angka ini.",
    Value       = { Min = 5, Max = 60, Default = 22 },
    Rounding    = 0,
    Callback    = function(v)
        state.max_rate = v
        if state.anti_kick then rl.max = v end
    end,
})

local SecAuto = TabTune:Section({
    Title = "Auto-Tune",
    TextXAlignment = "Left",
})

local autoTuneEnabled = false
SecAuto:Toggle({
    Title    = "Auto-Tune Lead",
    Desc     = "Adjust lead berdasar recall/precision live.",
    Value    = true,
    Callback = function(v) autoTuneEnabled = v end,
})

SecAuto:Button({
    Title    = "Reset Metrics",
    Desc     = "Clear rolling window accuracy.",
    Callback = function()
        acc.events = {}
        acc.tp, acc.fp, acc.fn = 0, 0, 0
    end,
})

SecAuto:Button({
    Title    = "Force Re-Hook",
    Desc     = "Re-scan remotes + re-capture args.",
    Callback = function()
        Hook.reset()
        Hook.scan(RS)
        if WindUI and WindUI:Notify then
            WindUI:Notify({
                Title = "BB-Pro",
                Content = "Re-hook triggered. Parry manual sekali.",
                Duration = 4,
            })
        end
    end,
})

-- ============================================================
-- 15. TAB: STATUS
-- ============================================================
local TabStatus = Window:Tab({
    Title = "Status",
    Icon  = "solar:chart-2-bold",
})

local SecStatus = TabStatus:Section({
    Title = "Live Metrics",
    TextXAlignment = "Left",
})

local statusParagraph = SecStatus:Paragraph({
    Title = "Accuracy Snapshot",
    Desc  = "menunggu data...",
})

local secSys = TabStatus:Section({
    Title = "System",
    TextXAlignment = "Left",
})

local sysParagraph = secSys:Paragraph({
    Title = "Runtime",
    Desc  = "init...",
})

task.spawn(function()
    while _G.BB_PRO_RUNNING do
        local s = acc:snapshot()
        pcall(function()
            statusParagraph:Set(string.format(
                "hit rate: %.1f%%  |  precision: %.1f%%  |  F1: %.2f\n" ..
                "TP: %d   FP: %d   FN: %d\n" ..
                "lead: %.3fs   radius: %.1f   rate: %d/s",
                s.hit_rate * 100, s.precision * 100, s.f1,
                s.tp, s.fp, s.fn,
                tune.lead, state.parry_radius, rl.max))
        end)
        pcall(function()
            sysParagraph:Set(string.format(
                "token fn: %s\nremote: %s\nsent: %d  reject: %d",
                _tokenFn and "ok" or "missing",
                Hook.get().remote and Hook.get().remote:GetFullName() or "not captured",
                stats.sent, stats.reject))
        end)
        task.wait(0.75)
    end
end)

-- ============================================================
-- 16. WINDUI OPTIONS
-- ============================================================
if Window.Options then
    Window.Options:CreateToggle({
        Title    = "Anti AFK",
        Desc     = "Inject VirtualUser idle kick prevention.",
        Value    = false,
        Callback = function(v)
            if v then
                _G.BB_ANTI_AFK = true
                task.spawn(function()
                    while _G.BB_ANTI_AFK do
                        pcall(function()
                            local vu = cloneref(game:GetService("VirtualUser"))
                            vu:CaptureController()
                            vu:ClickButton2(Vector2.new())
                        end)
                        task.wait(30)
                    end
                end)
            else
                _G.BB_ANTI_AFK = false
            end
        end,
    })
end

-- ============================================================
-- 17. WAIT FOR CAPTURE
-- ============================================================
print("[BB-Pro] waiting for legit parry capture — parry ONCE manually")
local t0 = tick()
while not Hook.get().args and tick() - t0 < 45 do
    task.wait(0.5)
end
if not Hook.get().args then
    warn("[BB-Pro] no capture in 45s — loop jalan, capture saat parry pertama")
end

-- ============================================================
-- 18. MAIN LOOP
-- ============================================================
local stats       = { sent = 0, reject = 0, start = tick() }
local last_fire   = 0
local pending_fire= nil
local last_ball_vel = {}
local FIRE_COOLDOWN = 0.15

local function _track_velocity(ball)
    local prev = last_ball_vel[ball]
    local cur  = ball.AssemblyLinearVelocity
    last_ball_vel[ball] = cur
    if prev
    and prev:Dot(cur) < 0
    and prev.Magnitude > 5
    and cur.Magnitude > 5 then
        return true
    end
    return false
end

_G.BB_PRO_RUNNING = true

while _G.BB_PRO_RUNNING do
    if not state.enabled then
        task.wait(0.1)
        continue
    end

    local cap = Hook.get()
    if not cap.args or not cap.remote or not cap.remote.Parent then
        Hook.scan(RS)
        task.wait(0.5)
        continue
    end

    local impact = predict:nearest_impact(LP, state.parry_radius)

    -- TP / FP detection
    for ball in pairs(last_ball_vel) do
        if ball.Parent and _track_velocity(ball) then
            if pending_fire
            and (tick() - pending_fire.t) < 0.25
            and pending_fire.ball == ball then
                acc:record("tp", tick())
                if state.debug then
                    print(string.format("[BB-Pro] tp flip_dt=%.3fs", tick() - pending_fire.t))
                end
                pending_fire = nil
            end
        end
    end

    if pending_fire and (tick() - pending_fire.t) > 0.25 then
        acc:record("fp", tick())
        if state.debug then
            print("[BB-Pro] fp no_flip 0.250s")
        end
        pending_fire = nil
    end

    -- decide fire
    local should_fire = false
    if state.force then
        should_fire = true
    elseif impact and impact.eta > 0 and impact.eta <= state.lead then
        should_fire = true
    end

    if should_fire and (tick() - last_fire) >= FIRE_COOLDOWN then
        local now = tick()
        local allowed, reason = rl:allow(now)
        if allowed then
            local uid = cap.args[2]
            local tok = Token.tokenize(uid, WS:GetServerTimeNow())
            if tok then
                local packet = {
                    cap.args[1], uid, tok, 0.5,
                    WS.CurrentCamera.CFrame, {}, {0, 0}, false
                }
                local ok = pcall(function()
                    if cap.remote:IsA("RemoteEvent") then
                        cap.remote:FireServer(table.unpack(packet))
                    else
                        cap.remote:InvokeServer(table.unpack(packet))
                    end
                end)
                rl:report(ok)
                last_fire = now
                pending_fire = {
                    ball = impact and impact.ball or nil,
                    t    = now,
                }
                stats.sent = stats.sent + 1
                if not ok then stats.reject = stats.reject + 1 end
                if state.debug then
                    print(string.format(
                        "[BB-Pro] fire lead=%.3f eta=%.3f dist=%.1f tok=%d sent=%d rej=%d",
                        state.lead,
                        impact and impact.eta or -1,
                        impact and impact.distance or -1,
                        #tok, stats.sent, stats.reject))
                end
            else
                Token.redetect()
            end
        else
            if state.debug and reason ~= "ratelimit" then
                print("[BB-Pro] fire blocked: " .. tostring(reason))
            end
        end
    end

    if autoTuneEnabled then tune:tick() end

    -- sync slider ↔ state (kalau user ubah dari HUD)
    state.lead = state.lead

    task.wait()
end

if WindUI and WindUI:Notify then
    WindUI:Notify({
        Title = "BB-Pro",
        Content = string.format("Stopped. sent=%d reject=%d", stats.sent, stats.reject),
        Duration = 5,
    })
end
print("[BB-Pro] stopped. total sent=" .. stats.sent .. " reject=" .. stats.reject)
