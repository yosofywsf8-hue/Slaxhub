-- Blade Ball Script - Bypass & Fluent UI (Auto Parry MAX)
-- Slax Hub v13.0 - Base by yossef | Physics Prediction + Reactive Window by ALPHA XK

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v13.0 (Auto Parry MAX)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Auto", Icon = "swords" }),
    Tune = Window:AddTab({ Title = "Tuning", Icon = "sliders" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local AutoParryEnabled = false
local ParryTiming      = 30      -- 1=late, 100=early
local MaxPerFrame      = 6
local BurstMode        = true    -- 2x fire per target
local AdaptiveMode     = true
local PingCompensate   = true

-- ═══════════════════════════════════════════
-- TUNABLES (advanced)
-- ═══════════════════════════════════════════
local MAX_PARRY_DISTANCE   = 200
local MAX_PARRY_ANGLE      = 90
local PREDICTION_TIME_MIN  = 0.03
local PREDICTION_TIME_MAX  = 0.35
local BALL_LOCK_DURATION   = 0.35
local REACTIVE_MARGIN      = 0.02
local CURVE_TRACK_FRAMES   = 2

-- ═══════════════════════════════════════════
-- TOKEN
-- ═══════════════════════════════════════════
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' then
        local ok, src = pcall(function() return debug.info(f, 's') end)
        if ok and src and tostring(src):find('PRY', 1, true) then
            local ok2, ups = pcall(function() return debug.getupvalues(f) end)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if type(v) == 'function' then
                        _token = v
                        break
                    end
                end
            end
            if _token then break end
        end
    end
end

local function _tokenize(uid)
    if not _token then return "" end
    local ok, res = pcall(function()
        local t = tostring(math.floor(workspace:GetServerTimeNow() * 100))
        local k = _token(uid, 'TIME')
        local chars = table.create(#t)
        for i = 1, #t do
            chars[i] = string.char(bit32.bxor(
                (string.byte(t, i) + i) % 256,
                string.byte(k, (i - 1) % #k + 1)
            ))
        end
        return table.concat(chars)
    end)
    return ok and res or ""
end

-- ═══════════════════════════════════════════
-- HOOK
-- ═══════════════════════════════════════════
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string"
        and type(args[3]) == "string"
        and type(args[4]) == "number"
        and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table"
        and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)
        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent'))
            or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                        print("[Slax Hub] Remote captured:", self.Name)
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, r in pairs(replicated_storage:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

print("[Slax Hub v13.0] Hooks installed — parry manual sekali")

-- ═══════════════════════════════════════════
-- FIRE (multi-remote, multi-burst)
-- ═══════════════════════════════════════════
local function FireParryBypass(burstCount)
    burstCount = burstCount or 1
    local fired = false
    for _remote, _origArgs in pairs(_reverted) do
        for _ = 1, burstCount do
            local _packet = {
                _origArgs[1],
                _origArgs[2],
                _tokenize(_origArgs[2]),
                0.5,
                workspace.CurrentCamera.CFrame,
                {},
                {0, 0},
                false
            }
            local ok = pcall(function()
                if _remote:IsA('RemoteEvent') then
                    _remote:FireServer(unpack(_packet))
                elseif _remote:IsA('RemoteFunction') then
                    _remote:InvokeServer(unpack(_packet))
                end
            end)
            if ok then fired = true end
        end
    end
    return fired
end

-- ═══════════════════════════════════════════
-- PING
-- ═══════════════════════════════════════════
local function GetPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    if not ok or not v then return 0.1 end
    return math.clamp(v, 0.02, 0.5)
end

-- ═══════════════════════════════════════════
-- 🧠 PHYSICS PREDICTION (linear + curve-aware)
-- ═══════════════════════════════════════════
-- untuk tiap bola, track 2 velocity terakhir untuk estimasi akselerasi (curve)
local ballHistory = {}   -- [ball] = {pos, vel, t}

local function GetPredictedPosition(ball, dt)
    local now = tick()
    local h = ballHistory[ball]

    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity

    if h then
        local dvel = (vel - h.vel) / math.max(now - h.t, 1e-3)
        -- kurangi noise: kalau akselerasi > threshold, masih pakai linear
        if dvel.Magnitude < 500 then
            return pos + vel * dt + 0.5 * dvel * dt * dt
        end
    end
    return pos + vel * dt
end

local function UpdateBallHistory(ball)
    local now = tick()
    ballHistory[ball] = {
        pos = ball.Position,
        vel = ball.AssemblyLinearVelocity,
        t = now,
    }
end

-- ═══════════════════════════════════════════
-- 📐 ANGLE + MULTI-SIGNAL TARGET
-- ═══════════════════════════════════════════
local function IsWithinAngle(playerPos, ballPos, ballVel)
    if ballVel.Magnitude < 0.1 then return true end
    local toPlayer = playerPos - ballPos
    if toPlayer.Magnitude < 0.1 then return true end
    local dot = ballVel.Unit:Dot(toPlayer.Unit)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MAX_PARRY_ANGLE
end

-- target detection: 3 sinyal
local function IsTargetingPlayer(ball, hrp)
    -- sinyal 1: attribute resmi
    local targetAttr = ball:GetAttribute("target")
    if targetAttr == LocalPlayer.Name then return true end

    -- sinyal 2: velocity toward player
    local vel = ball.AssemblyLinearVelocity
    local toPlayer = hrp.Position - ball.Position
    if vel.Magnitude > 3 and toPlayer.Magnitude > 0.1 then
        local approach = vel.Unit:Dot(toPlayer.Unit)
        if approach > 0.9 then
            -- cek jarak: kalau sangat dekat, kredibel target
            if toPlayer.Magnitude < MAX_PARRY_DISTANCE then
                return true
            end
        end
    end

    return false
end

-- ═══════════════════════════════════════════
-- ⚔️ AUTO PARRY LOOP v13.0 — MULTI-TARGET + REACTIVE
-- ═══════════════════════════════════════════
task.spawn(function()
    local lastFireTime = 0
    local ballLocks = {}

    local adaptive = {
        leadBonus   = 0.0,
        cooldownAdj = 1.0,
        attempts    = 0,
        success     = 0,
        reject      = 0,
        lastEval    = tick(),
    }

    while task.wait() do
        if not AutoParryEnabled then
            ballLocks = {}
            lastFireTime = 0
            adaptive.leadBonus = 0.0
            adaptive.cooldownAdj = 1.0
            adaptive.attempts = 0
            adaptive.success = 0
            adaptive.reject = 0
            continue
        end

        local now = tick()
        local ping = GetPing()

        -- ═══ adaptive eval tiap 5s ═══
        if AdaptiveMode and (now - adaptive.lastEval >= 5) then
            adaptive.lastEval = now
            local rate = (adaptive.attempts > 0)
                and (adaptive.success / adaptive.attempts)
                or 0.5
            if rate < 0.7 then
                adaptive.leadBonus = math.min(adaptive.leadBonus + 0.010, 0.08)
                adaptive.cooldownAdj = math.max(adaptive.cooldownAdj - 0.05, 0.7)
            elseif rate > 0.95 then
                adaptive.leadBonus = math.max(adaptive.leadBonus - 0.005, -0.02)
                adaptive.cooldownAdj = math.min(adaptive.cooldownAdj + 0.05, 1.5)
            end
            adaptive.attempts = 0
            adaptive.success = 0
            adaptive.reject = 0
        end

        -- ═══ cleanup ═══
        for ball, unlock in pairs(ballLocks) do
            if not ball.Parent or now >= unlock then
                ballLocks[ball] = nil
            end
        end
        for ball, _ in pairs(ballHistory) do
            if not ball.Parent then ballHistory[ball] = nil end
        end

        -- ═══ cooldown ═══
        local base_cd = 0.025
        local ping_cd = ping * 0.4
        local cooldown = (base_cd + ping_cd) * adaptive.cooldownAdj
        if (now - lastFireTime) < cooldown then continue end

        local char = LocalPlayer.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local playerPos = hrp.Position

        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- ═══ lead time (ping + adaptive + timing slider) ═══
        local slider_offset = ((ParryTiming - 50) / 100) * 0.20
        -- slider 0 → -0.10s (late), slider 100 → +0.10s (early)
        local ping_lead = PingCompensate and (ping * 0.9) or 0.0
        local lead = math.clamp(
            ping_lead + slider_offset + adaptive.leadBonus + REACTIVE_MARGIN,
            PREDICTION_TIME_MIN,
            PREDICTION_TIME_MAX
        )

        -- ═══ kumpulin kandidat ═══
        local candidates = {}

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] then continue end

            local vel = ball.AssemblyLinearVelocity
            local speed = vel.Magnitude
            if speed < 3 then continue end

            -- update history untuk prediksi curve
            UpdateBallHistory(ball)

            -- target check (multi-signal)
            if not IsTargetingPlayer(ball, hrp) then continue end

            -- prediksi posisi di masa depan (lead time)
            local predictedPos = GetPredictedPosition(ball, lead)
            local predictedDistance = (playerPos - predictedPos).Magnitude

            if predictedDistance > MAX_PARRY_DISTANCE then continue end
            if not IsWithinAngle(playerPos, predictedPos, vel) then continue end

            -- waktu bola menyentuh player (approx, ball dianggap sphere kecil)
            local effective_radius = 6   -- radius parry efektif
            local etc = (predictedDistance - effective_radius) / math.max(speed, 1)
            if etc < 0 then etc = 0 end

            -- reactive condition: fire kalau etc < lead (bukan ==)
            if etc <= lead then
                table.insert(candidates, {
                    ball = ball,
                    etc = etc,
                    dist = predictedDistance,
                    speed = speed,
                })
            end
        end

        -- ═══ fire semua kandidat (sorted urgent dulu) ═══
        if #candidates > 0 then
            table.sort(candidates, function(a, b) return a.etc < b.etc end)

            local fireN = math.min(#candidates, MaxPerFrame)
            lastFireTime = now

            for i = 1, fireN do
                local ball = candidates[i].ball
                ballLocks[ball] = now + BALL_LOCK_DURATION
            end

            local burst = BurstMode and 2 or 1
            local fired = FireParryBypass(burst)
            if fired then
                adaptive.attempts = adaptive.attempts + fireN

                for i = 1, fireN do
                    local ball = candidates[i].ball
                    task.spawn(function()
                        local checkStart = tick()
                        while tick() - checkStart < 0.35 do
                            task.wait(0.03)
                            if not ball.Parent then
                                adaptive.success = adaptive.success + 1
                                return
                            end
                            local v = ball.AssemblyLinearVelocity
                            if v.Magnitude > 1 then
                                local toPlayer = playerPos - ball.Position
                                if toPlayer.Magnitude > 0.1
                                and v.Unit:Dot(toPlayer.Unit) < 0.3 then
                                    adaptive.success = adaptive.success + 1
                                    return
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════

local Toggle = Tabs.Main:AddToggle("AutoParry", {
    Title = "⚔️ Auto Parry MAX",
    Default = false
})
Toggle:OnChanged(function(v) AutoParryEnabled = v end)

Tabs.Main:AddSlider("ParryTiming", {
    Title = "Parry Timing",
    Description = "1 = late | 50 = balanced | 100 = early",
    Default = 30,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v) ParryTiming = v end
})

Tabs.Main:AddSlider("MaxPerFrame", {
    Title = "Max Parry / Frame",
    Description = "4 = safe | 6 = aggressive | 8 = kick risk",
    Default = 6,
    Min = 1,
    Max = 8,
    Rounding = 0,
    Callback = function(v) MaxPerFrame = v end
})

Tabs.Tune:AddToggle("BurstMode", {
    Title = "Burst Fire",
    Desc = "2x fire per target — redundancy, lebih akurat",
    Default = true,
})
:OnChanged(function(v) BurstMode = v end)

Tabs.Tune:AddToggle("AdaptiveMode", {
    Title = "Adaptive Mode",
    Desc = "Auto-adjust lead + cooldown berdasar success rate",
    Default = true,
})
:OnChanged(function(v) AdaptiveMode = v end)

Tabs.Tune:AddToggle("PingCompensate", {
    Title = "Ping Compensate",
    Desc = "Fire lebih awal berdasar ping — kompensasi latency",
    Default = true,
})
:OnChanged(function(v) PingCompensate = v end)

Tabs.Tune:AddSlider("MaxDist", {
    Title = "Max Parry Distance",
    Description = "Radius deteksi bola (studs)",
    Default = 200,
    Min = 80,
    Max = 400,
    Rounding = 0,
    Callback = function(v) MAX_PARRY_DISTANCE = v end
})

Tabs.Tune:AddSlider("LockDur", {
    Title = "Ball Lock Duration",
    Description = "Berapa lama bola di-skip setelah fire (detik)",
    Default = 0.35,
    Min = 0.1,
    Max = 1.0,
    Rounding = 2,
    Callback = function(v) BALL_LOCK_DURATION = v end
})

-- ═══════════════════════════════════════════
-- Settings
-- ═══════════════════════════════════════════
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v13.0 👑",
    Content = "Auto Parry MAX — physics prediction + reactive window",
    Duration = 6
})
