-- Blade Ball Script - Auto Parry MAX v13.1
-- Base by yossef | Multi-Target Real + Anti-Double + Long Range by ALPHA XK

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v13.1 (Multi-Target MAX)",
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

local RS = cloneref(game:GetService('ReplicatedStorage'))
local WS = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local AutoParryEnabled = false
local ParryTiming      = 30
local MaxPerFrame      = 8          -- lebih tinggi = lebih banyak bola per frame
local BurstMode        = true
local AdaptiveMode     = true
local PingCompensate   = true

-- ═══════════════════════════════════════════
-- TUNABLES
-- ═══════════════════════════════════════════
local MAX_PARRY_DISTANCE   = 400          -- RANGE JAUH
local MAX_PARRY_ANGLE      = 110          -- SUDUT LEBAR
local PREDICTION_TIME_MIN  = 0.01
local PREDICTION_TIME_MAX  = 0.50
local BALL_LOCK_DURATION   = 0.80         -- ANTI-DOUBLE (naik dari 0.35)
local REACTIVE_MARGIN      = 0.03
local EFFECTIVE_RADIUS     = 12           -- radius parry efektif (naik dari 6)
local GLOBAL_COOLDOWN_MIN  = 0.015        -- cooldown global minimal

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
                    if type(v) == 'function' then _token = v; break end
                end
            end
            if _token then break end
        end
    end
end

local function _tokenize(uid)
    if not _token then return "" end
    local ok, res = pcall(function()
        local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
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

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

print("[Slax Hub v13.1] Hooks installed — parry manual sekali")

-- ═══════════════════════════════════════════
-- FIRE (per-target burst)
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
                WS.CurrentCamera.CFrame,
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
-- PREDICTION (linear, cukup buat blade ball)
-- ═══════════════════════════════════════════
local function GetPredictedPosition(ball, dt)
    return ball.Position + ball.AssemblyLinearVelocity * dt
end

-- ═══════════════════════════════════════════
-- ANGLE + TARGET
-- ═══════════════════════════════════════════
local function IsWithinAngle(playerPos, ballPos, ballVel)
    if ballVel.Magnitude < 0.1 then return true end
    local toPlayer = playerPos - ballPos
    if toPlayer.Magnitude < 0.1 then return true end
    local dot = ballVel.Unit:Dot(toPlayer.Unit)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MAX_PARRY_ANGLE
end

local function IsTargetingPlayer(ball, hrp)
    -- sinyal 1: attribute
    if ball:GetAttribute("target") == LocalPlayer.Name then return true end

    -- sinyal 2: velocity toward player + dekat
    local vel = ball.AssemblyLinearVelocity
    local toPlayer = hrp.Position - ball.Position
    if vel.Magnitude > 3 and toPlayer.Magnitude > 0.1 then
        local approach = vel.Unit:Dot(toPlayer.Unit)
        if approach > 0.85 and toPlayer.Magnitude < MAX_PARRY_DISTANCE then
            return true
        end
    end

    -- sinyal 3: sudah dalam radius parry meski tidak jelas target
    if toPlayer.Magnitude < EFFECTIVE_RADIUS * 3 then
        return true
    end

    return false
end

-- ═══════════════════════════════════════════
-- AUTO PARRY LOOP — MULTI-TARGET REAL + ANTI-DOUBLE
-- ═══════════════════════════════════════════
task.spawn(function()
    local lastFireTime = 0
    local ballLocks = {}        -- [ball] = unlockTime
    local ballLastFired = {}    -- [ball] = lastFireTime (anti-double)

    local adaptive = {
        leadBonus   = 0.0,
        cooldownAdj = 1.0,
        attempts    = 0,
        success     = 0,
        lastEval    = tick(),
    }

    while task.wait() do
        if not AutoParryEnabled then
            ballLocks = {}
            ballLastFired = {}
            lastFireTime = 0
            adaptive.leadBonus = 0.0
            adaptive.cooldownAdj = 1.0
            adaptive.attempts = 0
            adaptive.success = 0
            continue
        end

        local now = tick()
        local ping = GetPing()

        -- adaptive eval
        if AdaptiveMode and (now - adaptive.lastEval >= 5) then
            adaptive.lastEval = now
            local rate = (adaptive.attempts > 0)
                and (adaptive.success / adaptive.attempts) or 0.5
            if rate < 0.7 then
                adaptive.leadBonus = math.min(adaptive.leadBonus + 0.010, 0.08)
                adaptive.cooldownAdj = math.max(adaptive.cooldownAdj - 0.05, 0.7)
            elseif rate > 0.95 then
                adaptive.leadBonus = math.max(adaptive.leadBonus - 0.005, -0.02)
                adaptive.cooldownAdj = math.min(adaptive.cooldownAdj + 0.05, 1.5)
            end
            adaptive.attempts = 0
            adaptive.success = 0
        end

        -- cleanup locks + anti-double history
        for ball, unlock in pairs(ballLocks) do
            if not ball.Parent or now >= unlock then ballLocks[ball] = nil end
        end
        for ball, t in pairs(ballLastFired) do
            if not ball.Parent or (now - t) > 1.0 then ballLastFired[ball] = nil end
        end

        -- GLOBAL cooldown (minimal biar nggak flood)
        local cooldown = math.max(GLOBAL_COOLDOWN_MIN, ping * 0.3) * adaptive.cooldownAdj
        if (now - lastFireTime) < cooldown then continue end

        local char = LocalPlayer.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local playerPos = hrp.Position

        local ballsFolder = WS:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- lead time
        local slider_offset = ((ParryTiming - 50) / 100) * 0.20
        local ping_lead = PingCompensate and (ping * 0.9) or 0.0
        local lead = math.clamp(
            ping_lead + slider_offset + adaptive.leadBonus + REACTIVE_MARGIN,
            PREDICTION_TIME_MIN,
            PREDICTION_TIME_MAX
        )

        -- kumpulin SEMUA kandidat
        local candidates = {}

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end
            if ballLocks[ball] then continue end

            -- ANTI-DOUBLE: skip kalau baru di-fire dalam 0.8s
            local lastFired = ballLastFired[ball]
            if lastFired and (now - lastFired) < BALL_LOCK_DURATION then
                continue
            end

            local vel = ball.AssemblyLinearVelocity
            local speed = vel.Magnitude
            if speed < 3 then continue end

            if not IsTargetingPlayer(ball, hrp) then continue end

            local predictedPos = GetPredictedPosition(ball, lead)
            local predictedDistance = (playerPos - predictedPos).Magnitude

            if predictedDistance > MAX_PARRY_DISTANCE then continue end
            if not IsWithinAngle(playerPos, predictedPos, vel) then continue end

            local etc = (predictedDistance - EFFECTIVE_RADIUS) / math.max(speed, 1)
            if etc < 0 then etc = 0 end

            -- fire kalau etc <= lead (dan etc >= 0)
            if etc <= lead then
                table.insert(candidates, {
                    ball = ball,
                    etc = etc,
                    dist = predictedDistance,
                    speed = speed,
                })
            end
        end

        -- fire SEMUA kandidat (sorted urgent dulu)
        if #candidates > 0 then
            table.sort(candidates, function(a, b) return a.etc < b.etc end)

            local fireN = math.min(#candidates, MaxPerFrame)
            lastFireTime = now

            for i = 1, fireN do
                local ball = candidates[i].ball
                ballLocks[ball] = now + BALL_LOCK_DURATION
                ballLastFired[ball] = now
            end

            -- burst fire (2x per round kalau enabled)
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
    Description = "Banyak bola per frame — 8 = agresif",
    Default = 8,
    Min = 1,
    Max = 12,
    Rounding = 0,
    Callback = function(v) MaxPerFrame = v end
})

Tabs.Tune:AddToggle("BurstMode", {
    Title = "Burst Fire",
    Desc = "2x fire per round — redundancy",
    Default = true,
})
:OnChanged(function(v) BurstMode = v end)

Tabs.Tune:AddToggle("AdaptiveMode", {
    Title = "Adaptive Mode",
    Desc = "Auto-adjust lead + cooldown",
    Default = true,
})
:OnChanged(function(v) AdaptiveMode = v end)

Tabs.Tune:AddToggle("PingCompensate", {
    Title = "Ping Compensate",
    Desc = "Fire lebih awal berdasar ping",
    Default = true,
})
:OnChanged(function(v) PingCompensate = v end)

Tabs.Tune:AddSlider("MaxDist", {
    Title = "Max Parry Distance",
    Description = "Radius deteksi bola (studs)",
    Default = 400,
    Min = 100,
    Max = 800,
    Rounding = 0,
    Callback = function(v) MAX_PARRY_DISTANCE = v end
})

Tabs.Tune:AddSlider("LockDur", {
    Title = "Ball Lock Duration",
    Description = "Anti-double protection (detik)",
    Default = 0.8,
    Min = 0.3,
    Max = 2.0,
    Rounding = 2,
    Callback = function(v) BALL_LOCK_DURATION = v end
})

Tabs.Tune:AddSlider("Angle", {
    Title = "Max Parry Angle",
    Description = "Sudut maksimal deteksi bola (derajat)",
    Default = 110,
    Min = 60,
    Max = 180,
    Rounding = 0,
    Callback = function(v) MAX_PARRY_ANGLE = v end
})

InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v13.1 👑",
    Content = "Multi-Target MAX — long range + anti-double",
    Duration = 6
})
