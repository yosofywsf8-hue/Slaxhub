-- ═══════════════════════════════════════════════════════════
-- BLABLA Hub FINAL v9 — Blade Ball
-- SOF Multi-Target Parry (يضرب كل اللاعبين)
-- Auto Parry + Auto Spam + Manual + Triggerbot + SOF
-- Floating Buttons Premium + Detection + Target Switch
-- ═══════════════════════════════════════════════════════════

local cloneref = cloneref or function(o) return o end

local FONT_FAMILY_BUBBLE = "rbxasset://fonts/families/LuckiestGuy.json"
local FONT_FAMILY_ROUND  = "rbxasset://fonts/families/FredokaOne.json"
local FONT_FAMILY_SOFT   = "rbxasset://fonts/families/DenkOne.json"

local FONT = {
    black = Font.new(FONT_FAMILY_BUBBLE, Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
    bold  = Font.new(FONT_FAMILY_ROUND,  Enum.FontWeight.Bold,     Enum.FontStyle.Normal),
    semi  = Font.new(FONT_FAMILY_ROUND,  Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
    med   = Font.new(FONT_FAMILY_SOFT,   Enum.FontWeight.Medium,   Enum.FontStyle.Normal),
    reg   = Font.new(FONT_FAMILY_SOFT,   Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
}

local PALETTE = {
    bgDeep = Color3.fromRGB(18, 12, 32), bgMain = Color3.fromRGB(28, 20, 48),
    bgSoft = Color3.fromRGB(38, 28, 62), card = Color3.fromRGB(32, 24, 54),
    border = Color3.fromRGB(120, 80, 200), borderSoft = Color3.fromRGB(80, 55, 140),
    accent = Color3.fromRGB(180, 130, 255), accentHot = Color3.fromRGB(220, 180, 255),
    text = Color3.fromRGB(255, 255, 255), textDim = Color3.fromRGB(220, 210, 240),
    textFaint = Color3.fromRGB(160, 145, 200),
    success = Color3.fromRGB(120, 255, 170),
}

-- ═══════════════════════════════════════════════════════════
-- ANIMATION ENGINE
-- ═══════════════════════════════════════════════════════════
local Animation = {}
Animation.springOut = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Animation.smoothOut = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Animation.smoothIn  = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

function Animation.shimmer(g, d, w)
    d = d or 1.6; w = w or 3.5
    task.spawn(function()
        while g.Parent do
            g.Offset = Vector2.new(-1.2, 0); task.wait(w)
            TweenService:Create(g, TweenInfo.new(d, Enum.EasingStyle.Linear), { Offset = Vector2.new(1.2, 0) }):Play()
            task.wait(d + 0.3)
        end
    end)
end
function Animation.glowPulse(s, b, p, sp)
    task.spawn(function()
        local up = true
        while s.Parent do
            TweenService:Create(s, TweenInfo.new(sp or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = up and p or b }):Play()
            up = not up; task.wait(sp or 1.5)
        end
    end)
end
function Animation.stagger(items, base, per, fn)
    for i, item in ipairs(items) do
        task.delay((base or 0) + (per or 0.025) * i, function() pcall(fn, item, i) end)
    end
end
function Animation.parallaxTilt(card, maxAngle)
    maxAngle = maxAngle or 4
    local conn
    conn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if not card.Parent then conn:Disconnect() return end
        local m = UserInputService:GetMouseLocation(); local p = card.AbsolutePosition; local s = card.AbsoluteSize
        local cx = p.X + s.X/2; local cy = p.Y + s.Y/2
        if (m - Vector2.new(cx, cy)).Magnitude > s.X * 1.5 then
            TweenService:Create(card, Animation.smoothOut, { Rotation = 0 }):Play(); return
        end
        local rx = math.clamp(-(m.Y - cy)/s.Y * maxAngle, -maxAngle, maxAngle)
        local ry = math.clamp((m.X - cx)/s.X * maxAngle, -maxAngle, maxAngle)
        TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = rx * 0.6 + ry * 0.4 }):Play()
    end)
    return conn
end
function Animation.spawnParticles(parent)
    task.spawn(function()
        while parent.Parent do
            local p = Instance.new("Frame")
            p.Size = UDim2.fromOffset(math.random(2, 5), math.random(2, 5))
            p.Position = UDim2.new(math.random(), 0, 1.2, 0)
            p.BackgroundColor3 = PALETTE.accent
            p.BackgroundTransparency = math.random(50, 80) / 100
            p.BorderSizePixel = 0; p.ZIndex = 1; p.Parent = parent
            Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
            local dur = math.random(80, 150) / 10
            local drift = math.random(-50, 50) / 10
            TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
                Position = UDim2.new(p.Position.X.Scale + drift/100, 0, -0.2, 0),
                BackgroundTransparency = 1,
            }):Play()
            task.delay(dur + 0.5, function() if p and p.Parent then p:Destroy() end end)
            task.wait(math.random(4, 10) / 10)
        end
    end)
end
function Animation.glassHighlight(parent)
    local t = Instance.new("Frame")
    t.Name = "GlassTop"; t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.new(0.5, 0, 0, 0)
    t.Size = UDim2.new(1, -2, 0, 1); t.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    t.BackgroundTransparency = 0.75; t.BorderSizePixel = 0; t.ZIndex = parent.ZIndex + 1; t.Parent = parent
    local g = Instance.new("UIGradient"); g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
    }); g.Parent = t
end
function Animation.ripple(button, color)
    button.MouseButton1Down:Connect(function(x, y)
        local rx = (x - button.AbsolutePosition.X) / button.AbsoluteSize.X
        local ry = (y - button.AbsolutePosition.Y) / button.AbsoluteSize.Y
        local r = Instance.new("Frame"); r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.new(rx, 0, ry, 0); r.Size = UDim2.fromOffset(0, 0)
        r.BackgroundColor3 = color or PALETTE.accent; r.BackgroundTransparency = 0.5
        r.BorderSizePixel = 0; r.ZIndex = button.ZIndex + 5; r.Parent = button
        Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
        local m = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
        TweenService:Create(r, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(m, m), BackgroundTransparency = 1 }):Play()
        task.delay(0.7, function() if r and r.Parent then r:Destroy() end end)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- PARRY PATCH
-- ═══════════════════════════════════════════════════════════
local _PARRY_PATCH = { keyTable = nil, transformFn = nil, parryHash = nil, parryRemote = nil, ready = false }

task.spawn(function()
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local C = RS:WaitForChild("Controllers", 15); if not C then return end
        local SC
        for _, c in ipairs(C:GetChildren()) do if c.Name:sub(1,16) == "SwordsController" then SC = c; break end end
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 15); if not PRY then return end
        local PF = require(PRY)
        local gu = debug.getupvalues or getupvalues; if not gu then return end
        local ups = gu(PF); if not ups or #ups < 8 then return end
        _PARRY_PATCH.keyTable = ups[3]; _PARRY_PATCH.transformFn = ups[4]; _PARRY_PATCH.parryHash = ups[8]
    end)
end)

local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local workspace = cloneref(game:GetService("Workspace"))
local _reverted = {}; local _original = {}

local function _is_valid(a)
    return #a == 8 and type(a[2]) == "string" and type(a[3]) == "string" and type(a[4]) == "number"
        and typeof(a[5]) == "CFrame" and type(a[6]) == "table" and type(a[7]) == "table" and type(a[8]) == "boolean"
end
local function _hook(remote)
    if _reverted[remote] then return end
    local meta = getrawmetatable(remote); if not meta or _original[meta] then return end
    _original[meta] = true; setreadonly(meta, false)
    local old = meta.__index
    meta.__index = function(self, key)
        if (key == "FireServer" and self:IsA("RemoteEvent")) or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return function(_, ...)
                local _a = {...}
                if _is_valid(_a) and not _reverted[self] then
                    _reverted[self] = _a; _PARRY_PATCH.ready = true; _PARRY_PATCH.parryRemote = self
                end
                return old(self, key)(_, unpack(_a))
            end
        end
        return old(self, key)
    end
    setreadonly(meta, true)
end
for _, r in pairs(replicated_storage:GetDescendants()) do
    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then pcall(_hook, r) end
end

function _PARRY_PATCH.fire(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable; if not kt then return false end
    local ki = kt[1]; local ck = kt[2] and kt[2][ki]; if not ck then return false end
    local tok, tf = pcall(_PARRY_PATCH.transformFn, ck, "TIME")
    if not tok or not tf then tok, tf = pcall(_PARRY_PATCH.transformFn, ck); if not tok or not tf then return false end end
    local st = workspace:GetServerTimeNow() * 100
    local ts = tostring(math.floor(st)); local tc = {}
    for i = 1, #ts do
        local ii = (i - 1) % #tf + 1
        local kb = string.byte(tf, ii); local tb = (string.byte(ts, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)
    return pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(_PARRY_PATCH.parryHash, ck, token, 0.5, curveCFrame, screenPositions, mouseLocation, false)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- IMPORTS
-- ═══════════════════════════════════════════════════════════
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Stats = cloneref(game:GetService("Stats"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local Lighting = cloneref(game:GetService("Lighting"))
local SoundService = cloneref(game:GetService("SoundService"))
local Debris = cloneref(game:GetService("Debris"))
local HttpService = cloneref(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

local Alive = workspace:FindFirstChild("Alive") or workspace:WaitForChild("Alive")
local Runtime = workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime")

local Connections_Manager = getgenv().Connections_Manager or {}
getgenv().Connections_Manager = Connections_Manager

getgenv().AutoParryMode = getgenv().AutoParryMode or "Remote"

-- ═══════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════
local System = {
    __properties = {
        __autoparry_enabled = false, __auto_spam_enabled = false, __manual_spam_enabled = false,
        __curve_mode = 1, __accuracy = 50, __divisor_multiplier = 1.1, __parried = false,
        __training_parried = false, __parries = 0, __spam_threshold = 1.5,
        __spam_accumulator = 0, __spam_rate = 1000, __distance_multiplier = 2,
        __humanizer_enabled = false, __humanizer_min_accuracy = 1, __humanizer_max_accuracy = 50,
        __humanizer_last_update = 0, __humanizer_next_change = 0.8,
        __tornado_time = tick(), __connections = {}, __infinity_active = false,
        __deathslash_active = false, __timehole_active = false,
        __slashesoffury_active = false, __slashesoffury_count = 0,
        __no_render_enabled = false, __fps_boost_enabled = false,
    },
    __config = {
        __curve_names = {"Camera", "Random", "Accelerated", "Backwards", "Slow", "High", "Left", "Right"},
        __detections = { __infinity = true, __deathslash = true, __timehole = true, __slashesoffury = true },
    },
}

-- ═══════════════════════════════════════════════════════════
-- SOF TRACKER
-- ═══════════════════════════════════════════════════════════
local FuryTracker = {
    __catch = false, __active = false,
    __detection_enabled = true, __auto_parry_enabled = true,
    __parry_amount = 35, __parry_delay = 0.05,
    __parry_method = "Remote",
    __balls = {},
}

local function update_divisor()
    System.__properties.__divisor_multiplier = 0.7 + (System.__properties.__accuracy - 1) * 0.0035353535353535
end

local function update_randomized_accuracy()
    if not System.__properties.__humanizer_enabled then return end
    local p = System.__properties
    local now = os.clock()
    if now < p.__humanizer_last_update + p.__humanizer_next_change then return end
    p.__humanizer_last_update = now
    local ps = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping = tonumber(ps:match("%d+")) or 0
    local mn = math.clamp(p.__humanizer_min_accuracy, 1, 50)
    local mx = math.clamp(p.__humanizer_max_accuracy, 1, 50)
    if mn > mx then mn, mx = mx, mn end
    local cu = math.clamp(p.__accuracy, mn, mx)
    local sp = math.max(1, mx - mn)
    local pf = ping >= 90 and 0.75 or (ping <= 50 and 1.25 or 1)
    local rl = math.random(1, 100); local na
    if ping >= 90 then na = math.clamp(cu + math.random(-1,1), mn, mx)
    elseif rl <= 45 then na = math.clamp(cu + math.random(-2,2), mn, mx)
    elseif rl <= 80 then
        local dr = math.random(2, math.max(3, math.floor(sp * 0.2)))
        local di = math.random() < 0.5 and -dr or dr
        na = math.clamp(cu + di, mn, mx)
    else na = math.random(mn, mx) end
    p.__accuracy = na
    p.__humanizer_next_change = math.random(0.7, 1.4) / pf
    update_divisor()
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if System.__properties.__humanizer_enabled then pcall(update_randomized_accuracy) end
    end
end)

local maxParryCount = 36
local parryDelay = 0.05

-- ═══════════════════════════════════════════════════════════
-- BALL / PLAYER / CURVE
-- ═══════════════════════════════════════════════════════════
System.ball = {}
function System.ball.get()
    local b = workspace:FindFirstChild("Balls"); if not b then return nil end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; return ball end
    end
    return nil
end
function System.ball.get_all()
    local o = {}; local b = workspace:FindFirstChild("Balls"); if not b then return o end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; table.insert(o, ball) end
    end
    return o
end

System.player = {}
local Closest_Entity = nil
function System.player.get_closest()
    local md = math.huge; local cl = nil
    if not Alive then return nil end
    for _, e in pairs(Alive:GetChildren()) do
        if e ~= LocalPlayer.Character and e.PrimaryPart then
            local d = LocalPlayer:DistanceFromCharacter(e.PrimaryPart.Position)
            if d < md then md = d; cl = e end
        end
    end
    Closest_Entity = cl; return cl
end
function System.player.get_closest_to_cursor()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local c = workspace.CurrentCamera; if not Alive then return nil end
    local vp = c.ViewportSize
    local r = c:ScreenPointToRay(vp.X/2, vp.Y/2)
    local pt = CFrame.lookAt(r.Origin, r.Origin + r.Direction)
    local cl, mdot = nil, -math.huge
    for _, p in pairs(Alive:GetChildren()) do
        if p ~= LocalPlayer.Character and p:FindFirstChild("HumanoidRootPart") then
            local d = (p.HumanoidRootPart.Position - c.CFrame.Position).Unit
            local dot = pt.LookVector:Dot(d)
            if dot > mdot then mdot = dot; cl = p end
        end
    end
    return cl
end

System.curve = {}
function System.curve.get_cframe()
    local c = workspace.CurrentCamera
    local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not r then return c.CFrame end
    local tp
    local cl = System.player.get_closest_to_cursor()
    if cl and cl:FindFirstChild("HumanoidRootPart") then tp = cl.HumanoidRootPart end
    local tpos = tp and tp.Position or (r.Position + c.CFrame.LookVector * 100)
    local fns = {
        function() return c.CFrame end,
        function()
            local d = (tpos - r.Position).Unit; local ro, at = nil, 0
            repeat
                ro = Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000))
                local cd = (tpos + ro - r.Position).Unit; at += 1
            until d:Dot(cd) < 0.95 or at > 10
            return CFrame.new(r.Position, tpos + ro)
        end,
        function() return CFrame.new(r.Position, tpos + Vector3.new(0, 5, 0)) end,
        function()
            local d = (r.Position - tpos).Unit
            return CFrame.new(c.CFrame.Position, r.Position + d * 10000 + Vector3.new(0, 1000, 0))
        end,
        function() return CFrame.new(r.Position, tpos + Vector3.new(0, -9e18, 0)) end,
        function() return CFrame.new(r.Position, tpos + Vector3.new(0, 9e18, 0)) end,
        function() local l = -c.CFrame.RightVector * 10000; return CFrame.new(r.Position, r.Position + l) end,
        function() local rv = c.CFrame.RightVector * 10000; return CFrame.new(r.Position, r.Position + rv) end,
    }
    return fns[math.clamp(System.__properties.__curve_mode, 1, #fns)]()
end

System.parry = {}

local function fireKeypress()
    pcall(function()
        if keypress then keypress(0x46)
        elseif syn and syn.keypress then syn.keypress(0x46) end
    end)
end

-- ★ Animation playback — نفس Flyte (الـ server يحتاج animation)
local function playParryAnimation()
    pcall(function()
        local char = LocalPlayer.Character; if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local ani = hum:FindFirstChildOfClass("Animator"); if not ani then return end
        for _, tr in ipairs(ani:GetPlayingAnimationTracks()) do
            if tr:GetAttribute("GrabParry") or tr:GetAttribute("Parry") or tr.Name == "GrabParry" or tr.Name == "Grab" then
                tr:Stop(0.1)
            end
        end
        local sh = replicated_storage:FindFirstChild("Shared")
        local api = sh and sh:FindFirstChild("SwordAPI"); if not api then return end
        local ok, SwordAPI = pcall(require, api); if not ok or not SwordAPI then return end
        local sword = char:GetAttribute("CurrentlyEquippedSword") or LocalPlayer:GetAttribute("CurrentlyEquippedSword")
        if not sword then return end
        local sData = SwordAPI:GetAnimations(sword, {"Parry", "GrabParry"},
            char:GetAttribute("AnimationType") or "R15", char:GetAttribute("SwordType") or "Basic")
        if type(sData) ~= "table" then return end
        for _, a in ipairs(sData) do
            if typeof(a) == "Instance" and a:IsA("Animation") then
                local tr = ani:LoadAnimation(a)
                tr.Priority = Enum.AnimationPriority.Action4
                tr:Play(0.05, 1, 1)
            end
        end
    end)
end

-- ★ parry عادي — نفس الملف القديم
function System.parry.execute(targetEntity)
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    local mode = getgenv().AutoParryMode or "Remote"
    pcall(playParryAnimation)

    if mode == "Keypress" then
        fireKeypress()
        System.__properties.__parries += 1
        task.delay(0.5, function() if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end end)
        return
    end
    if not _PARRY_PATCH or not _PARRY_PATCH.ready then return end
    local cam = workspace.CurrentCamera; local vp = cam.ViewportSize
    local sps = {}
    if Alive then
        for _, e in pairs(Alive:GetChildren()) do
            if e.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok then sps[e.Name] = sp end
            end
        end
    end
    -- ★ لو targetEntity محدد → استخدم اتجاهه
    local curveCF
    if targetEntity and targetEntity.PrimaryPart then
        local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if r then
            curveCF = CFrame.new(r.Position, targetEntity.PrimaryPart.Position)
        end
    end
    curveCF = curveCF or System.curve.get_cframe() or cam.CFrame
    local mouseLocation = {vp.X / 2, vp.Y / 2}
    _PARRY_PATCH.fire(curveCF, sps, mouseLocation)
    System.__properties.__parries += 1
    task.delay(0.5, function() if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end end)
end

-- ★ Multi-target parry — يضرب كل اللاعبين اللي عندهم SOF
function System.parry.executeMulti(targets)
    if not targets or #targets == 0 then
        System.parry.execute()
        return
    end
    for _, target in ipairs(targets) do
        System.parry.execute(target)
        task.wait(0.012)
    end
end

local function linear_predict(a, b, t) return a + (b - a) * t end
System.detection = { __ball_properties = { __aerodynamic_time = tick(), __last_warping = tick(), __lerp_radians = 0, __curving = tick() } }
function System.detection.is_curved()
    local bp = System.detection.__ball_properties
    local b = System.ball.get(); if not b then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local z = b:FindFirstChild("zoomies"); if not z then return false end
    local v = z.VectorVelocity or Vector3.new(); local sp = v.Magnitude; if sp == 0 then return false end
    local bd = v.Unit; local dv = LocalPlayer.Character.PrimaryPart.Position - b.Position
    if dv.Magnitude == 0 then return false end
    local d = dv.Unit; local dot = d:Dot(bd)
    local sth = math.min(sp/100, 40); local dd = bd - v; local ds = 0
    if dd.Magnitude > 0 then ds = d:Dot(dd.Unit) end
    local dif = dot - ds; local dist = dv.Magnitude
    local p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local dt = 0.5 - (p/1000); local re = dist/sp - (p/1000); local bdt = 15 - math.min(dist/1000, 15) + sth
    local cl = math.clamp(dot, -1, 1); local ra = math.rad(math.asin(cl))
    bp.__lerp_radians = linear_predict(bp.__lerp_radians, ra, 0.8)
    if sp > 0 and re > p/10 then bdt = math.max(bdt - 15, 15) end
    if dist < bdt then return false end
    if dif < dt then return true end
    if bp.__lerp_radians < 0.018 then bp.__last_warping = tick() end
    if (tick() - bp.__last_warping) < (re/1.5) then return true end
    if (tick() - bp.__curving) < (re/1.5) then return true end
    return dot < dt
end

local RS = replicated_storage
RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, d) System.__properties.__deathslash_active = d or false end)
RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b) System.__properties.__infinity_active = b or false end)
local netFolder = RS.Packages._Index["sleitnick_net@0.1.0"].net
netFolder["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
    local p = ({...})[1]
    if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then System.__properties.__timehole_active = true end
end)
netFolder["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function() System.__properties.__timehole_active = false end)

-- ═══════════════════════════════════════════════════════════
-- SOF MULTI-TARGET
-- ═══════════════════════════════════════════════════════════

-- ★ نجمع كل الكرات النشطة
local function getActiveFuryBalls()
    local out = {}
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return out end
    for _, child in ipairs(pg:GetChildren()) do
        local combo = child:FindFirstChild("ComboCounter")
        if combo then
            local tl = combo:FindFirstChildOfClass("TextLabel")
            if tl then
                local n = tonumber(tl.Text)
                if n and n > 0 then
                    table.insert(out, { ball = child, count = n, label = tl })
                end
            end
        end
    end
    return out
end

-- ★ نجمع كل اللاعبين اللي عندهم SOF
local function getFuryTargets()
    local out = {}
    local af = workspace:FindFirstChild("Alive"); if not af then return out end
    for _, e in pairs(af:GetChildren()) do
        if e ~= LocalPlayer.Character and e.PrimaryPart then
            local abilities = e:FindFirstChild("Abilities")
            if abilities then
                local sof = abilities:FindFirstChild("Slashes of Fury")
                if sof and sof.Enabled then
                    table.insert(out, e)
                end
            end
        end
    end
    return out
end

-- ★ Loop رئيسي — multi-target
task.spawn(function()
    while true do
        task.wait(FuryTracker.__parry_delay or 0.05)
        if not FuryTracker.__detection_enabled then continue end
        if not FuryTracker.__auto_parry_enabled then continue end
        if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= Alive then continue end
        if not LocalPlayer.Character.PrimaryPart then continue end
        if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
        if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
        if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end

        -- ★ شوف كل الكرات النشطة
        local activeBalls = getActiveFuryBalls()
        if #activeBalls == 0 then
            FuryTracker.__active = false
            continue
        end

        -- ★ نجيب اللاعبين اللي عندهم SOF
        local targets = getFuryTargets()

        -- ★ ضرب parry لكل كرة نشطة
        FuryTracker.__active = true
        for _, ballData in ipairs(activeBalls) do
            local remaining = FuryTracker.__parry_amount - ballData.count
            if remaining <= 0 then continue end

            -- ★ لو عندنا targets محددين → multi parry
            if #targets > 0 then
                for _, target in ipairs(targets) do
                    System.parry.execute(target)
                    task.wait(0.012)
                end
            else
                -- ★ وإلا parry عادي
                System.parry.execute()
                task.wait(0.012)
            end
        end

        -- ★ reset بعد فترة
        task.delay(0.5, function()
            FuryTracker.__active = false
        end)
    end
end)

-- ★ events
netFolder["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    if not FuryTracker.__detection_enabled then return end
    FuryTracker.__catch = true
    System.__properties.__slashesoffury_active = true
    task.delay(3, function()
        FuryTracker.__catch = false
        System.__properties.__slashesoffury_active = false
    end)
end)
netFolder["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    FuryTracker.__catch = false
    System.__properties.__slashesoffury_active = false
end)
netFolder["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    if not FuryTracker.__detection_enabled then return end
    local p = ({...})[1]
    if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
        FuryTracker.__catch = true
        System.__properties.__slashesoffury_active = true
    end
end)

-- ═══════════════════════════════════════════════════════════
-- TRIGGERBOT
-- ═══════════════════════════════════════════════════════════
System.triggerbot = { __enabled = false, __is_parrying = false, __parries = 0, __max_parries = 10000, __parry_delay = 0.5 }
function System.triggerbot.trigger(ball)
    if System.triggerbot.__is_parrying or System.triggerbot.__parries > System.triggerbot.__max_parries then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then return end
    System.triggerbot.__is_parrying = true
    System.triggerbot.__parries = System.triggerbot.__parries + 1
    System.parry.execute()
    task.delay(System.triggerbot.__parry_delay, function()
        if System.triggerbot.__parries > 0 then System.triggerbot.__parries = System.triggerbot.__parries - 1 end
    end)
    local conn
    conn = ball:GetAttributeChangedSignal('target'):Once(function()
        System.triggerbot.__is_parrying = false
        if conn then conn:Disconnect() end
    end)
    task.spawn(function()
        local st = tick()
        repeat RunService.Heartbeat:Wait() until (tick() - st >= 1 or not System.triggerbot.__is_parrying)
        System.triggerbot.__is_parrying = false
    end)
end
function System.triggerbot.loop()
    if not System.triggerbot.__enabled then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then return end
    local balls = workspace:FindFirstChild('Balls'); if not balls then return end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:IsA('BasePart') and ball:GetAttribute('target') == LocalPlayer.Name then
            System.triggerbot.trigger(ball); break
        end
    end
end
function System.triggerbot.enable(e)
    System.triggerbot.__enabled = e
    if e then
        if not System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot = RunService.Heartbeat:Connect(System.triggerbot.loop)
        end
    else
        if System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot:Disconnect()
            System.__properties.__connections.__triggerbot = nil
        end
        System.triggerbot.__is_parrying = false
        System.triggerbot.__parries = 0
    end
end

-- ═══════════════════════════════════════════════════════════
-- AUTOPARRY
-- ═══════════════════════════════════════════════════════════
System.autoparry = {}
function System.autoparry.start()
    if System.__properties.__connections.__autoparry then System.__properties.__connections.__autoparry:Disconnect() end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        local tb = nil
        if workspace:FindFirstChild("TrainingBalls") then
            for _, I in pairs(workspace.TrainingBalls:GetChildren()) do
                if I:GetAttribute("realBall") then tb = I; break end
            end
        end
        for _, ball in pairs(balls) do
            if System.triggerbot and System.triggerbot.__enabled then return end
            if not ball then continue end
            local z = ball:FindFirstChild('zoomies'); if not z then continue end
            ball:GetAttributeChangedSignal('target'):Once(function() System.__properties.__parried = false end)
            if System.__properties.__parried then continue end
            local bt = ball:GetAttribute('target')
            local v = z.VectorVelocity
            local d = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            local p = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
            local pth = math.clamp(p / 10, 5, 17)
            local s = v.Magnitude
            local csd = math.min(math.max(s - 9.5, 0), 650)
            local sd = (2.4 + csd * 0.002) * System.__properties.__divisor_multiplier
            local pa = pth + math.max(s / sd, 9.5)
            local curved = System.detection.is_curved()
            if ball:FindFirstChild('AeroDynamicSlashVFX') then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            if Runtime:FindFirstChild('Tornado') then
                if (tick() - System.__properties.__tornado_time) < (Runtime.Tornado:GetAttribute('TornadoTime') or 1) + 0.314159 then continue end
            end
            if one_ball and one_ball:GetAttribute('target') == LocalPlayer.Name and curved then continue end
            if ball:FindFirstChild('ComboCounter') then continue end
            if LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            if bt == LocalPlayer.Name and d <= pa then
                if getgenv().CooldownProtection then
                    local hb = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Hotbar")
                    local bl = hb and hb:FindFirstChild("Block")
                    local cd = bl and bl:FindFirstChild("UIGradient")
                    if cd and cd.Offset.Y < 0.4 then System.__properties.__parried = true; continue end
                end
                if getgenv().AutoAbility then
                    local hb = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Hotbar")
                    local ab = hb and hb:FindFirstChild("Ability")
                    local abc = ab and ab:FindFirstChild("UIGradient")
                    if abc and abc.Offset.Y == 0.5 then
                        local ch = LocalPlayer.Character
                        local abl = ch and ch:FindFirstChild("Abilities")
                        if abl and (
                            (abl:FindFirstChild("Raging Deflection") and abl["Raging Deflection"].Enabled) or
                            (abl:FindFirstChild("Rapture") and abl["Rapture"].Enabled) or
                            (abl:FindFirstChild("Calming Deflection") and abl["Calming Deflection"].Enabled) or
                            (abl:FindFirstChild("Aerodynamic Slash") and abl["Aerodynamic Slash"].Enabled) or
                            (abl:FindFirstChild("Fracture") and abl["Fracture"].Enabled) or
                            (abl:FindFirstChild("Death Slash") and abl["Death Slash"].Enabled)
                        ) then
                            pcall(function() RS.Remotes.AbilityButtonPress:FireServer() end)
                        end
                    end
                end
                System.parry.execute()
                System.__properties.__parried = true
            end
            local lp = tick()
            repeat RunService.Stepped:Wait() until (tick() - lp) >= 1 or not System.__properties.__parried
            System.__properties.__parried = false
        end
        if tb then
            local z = tb:FindFirstChild('zoomies')
            if z then
                tb:GetAttributeChangedSignal('target'):Once(function() System.__properties.__training_parried = false end)
                if not System.__properties.__training_parried then
                    local bt = tb:GetAttribute('target')
                    local v = z.VectorVelocity
                    local d = LocalPlayer:DistanceFromCharacter(tb.Position)
                    local s = v.Magnitude
                    local p = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
                    local pth = math.clamp(p / 10, 5, 17)
                    local csd = math.min(math.max(s - 9.5, 0), 650)
                    local sd = (2.4 + csd * 0.002) * System.__properties.__divisor_multiplier
                    local pa = pth + math.max(s / sd, 9.5)
                    if bt == LocalPlayer.Name and d <= pa then
                        System.parry.execute()
                        System.__properties.__training_parried = true
                        local lp = tick()
                        repeat RunService.Stepped:Wait() until (tick() - lp) >= 1 or not System.__properties.__training_parried
                        System.__properties.__training_parried = false
                    end
                end
            end
        end
    end)
end
function System.autoparry.stop()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
        System.__properties.__connections.__autoparry = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- AUTO SPAM
-- ═══════════════════════════════════════════════════════════
System.auto_spam = {}
function System.auto_spam:get_entity_properties()
    System.player.get_closest()
    if not Closest_Entity or not Closest_Entity.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    return { Velocity = Closest_Entity.PrimaryPart.Velocity,
        Direction = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit,
        Distance = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude }
end
function System.auto_spam:get_ball_properties()
    local b = System.ball.get(); if not b then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local bv = b.AssemblyLinearVelocity or Vector3.new()
    local dv = LocalPlayer.Character.PrimaryPart.Position - b.Position
    local bd = dv.Magnitude; local bdir = Vector3.new(); local bdot = 0
    if bd > 0 then
        bdir = dv.Unit
        if bv.Magnitude > 0 then bdot = bdir:Dot(bv.Unit) end
    end
    return { Velocity = bv, Direction = bdir, Distance = bd, Dot = bdot }
end
function System.auto_spam.spam_service(self)
    local b = System.ball.get(); local e = System.player.get_closest()
    if not b or not e or not e.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local D = 15; local v = b.AssemblyLinearVelocity or Vector3.new(); local n = v.Magnitude
    if n == 0 then return D end
    local tb = (LocalPlayer.Character.PrimaryPart.Position - b.Position)
    if tb.Magnitude == 0 then return D end
    local r = tb.Unit; local t = 0
    if n > 0 and v.Magnitude > 0 then t = r:Dot(v.Unit) end
    local tp = e.PrimaryPart.Position; local X = LocalPlayer:DistanceFromCharacter(tp)
    local E = 1; local Fm = Vector3.new()
    local s, h = pcall(function() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end)
    if s and h and h.MoveDirection then Fm = h.MoveDirection end
    local N = (tp - LocalPlayer.Character.PrimaryPart.Position)
    if N.Magnitude > 0 then N = N.Unit else N = Vector3.new() end
    local lm = Vector3.new()
    if e then
        local eh = e:FindFirstChildOfClass("Humanoid")
        if eh and eh.MoveDirection then lm = eh.MoveDirection end
    end
    _G.Last_Close_Contact = _G.Last_Close_Contact or 0
    _G.In_Close_Contact = _G.In_Close_Contact or false
    local now = tick()
    if X <= 3 then _G.In_Close_Contact = true end
    if _G.In_Close_Contact and X > 3.3 then _G.In_Close_Contact = false; _G.Last_Close_Contact = now end
    local u = (not _G.In_Close_Contact) and (now - (_G.Last_Close_Contact or 0) >= 1.5)
    if u and (Fm.Magnitude > 0.2 and Fm:Dot(N) < -0.4) then E = 10 end
    if u and (lm.Magnitude > 0.2 and lm:Dot(-N) < -0.4) then E = 10 end
    local B = math.max(20, (self.Ping or 50) * 0.7 + math.min(n / (E * 1.2), 80))
    if (self.Entity_Properties and self.Entity_Properties.Distance or math.huge) > B then return D end
    if (self.Ball_Properties and self.Ball_Properties.Distance or math.huge) > B then return D end
    if X > B then return D end
    local U = math.clamp(-t, 0, 1); local q = math.clamp(U * (n / 40), 0, 4)
    D = B - q; return D
end
function System.auto_spam.start()
    if System.__properties.__connections.__auto_spam then System.__properties.__connections.__auto_spam:Disconnect() end
    local lt = nil; local ltd = math.huge
    System.__properties.__connections.__auto_spam = RunService.PreSimulation:Connect(function()
        if not System.__properties.__auto_spam_enabled then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
        if System.__config.__detections.__infinity and System.__properties.__infinity_active then lt = nil; return end
        if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then lt = nil; return end
        if System.__config.__detections.__timehole and System.__properties.__timehole_active then lt = nil; return end
        if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then lt = nil; return end
        local b = System.ball.get(); if not b then lt = nil; return end
        local z = b:FindFirstChild("zoomies"); if not z then return end
        if z.VectorVelocity.Magnitude == 0 then return end
        System.player.get_closest()
        if not Closest_Entity or not Closest_Entity.PrimaryPart then lt = nil; return end
        local mp = LocalPlayer.Character.PrimaryPart.Position
        local cd = (mp - Closest_Entity.PrimaryPart.Position).Magnitude
        local bt = b:GetAttribute("target")
        if not lt or not lt.Parent then lt = Closest_Entity; ltd = cd
        elseif lt ~= Closest_Entity then
            if cd < ltd * 0.65 then lt = Closest_Entity; ltd = cd end
        else ltd = cd end
        if lt and lt.PrimaryPart then
            local curd = (mp - lt.PrimaryPart.Position).Magnitude
            if curd > ltd * 1.5 then
                lt = Closest_Entity
                ltd = (mp - Closest_Entity.PrimaryPart.Position).Magnitude
            end
        end
        if not lt or not lt.PrimaryPart then return end
        Closest_Entity = lt
        local p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        local pth = math.clamp(p / 10, 1, 16)
        local bp = System.auto_spam:get_ball_properties()
        local ep = System.auto_spam:get_entity_properties()
        if not bp or not ep then return end
        local sa = System.auto_spam.spam_service({ Ball_Properties = bp, Entity_Properties = ep, Ping = pth })
        local td = LocalPlayer:DistanceFromCharacter(lt.PrimaryPart.Position)
        if z.VectorVelocity.Magnitude == 0 then return end
        local d = LocalPlayer:DistanceFromCharacter(b.Position)
        if not bt then return end
        local dm = System.__properties.__distance_multiplier or 1
        sa = sa * dm; sa = math.max(sa, 18)
        if td > sa or d > sa then return end
        local pu = LocalPlayer.Character:GetAttribute("Pulsed"); if pu then return end
        if bt == LocalPlayer.Name and td > 30 and d > 30 then return end
        if d <= sa and System.__properties.__parries > System.__properties.__spam_threshold then
            System.parry.execute()
        end
    end)
end
function System.auto_spam.stop()
    System.__properties.__auto_spam_enabled = false
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
        System.__properties.__connections.__auto_spam = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- MANUAL SPAM
-- ═══════════════════════════════════════════════════════════
System.manual_spam = {}
function System.manual_spam.loop(delta)
    if not System.__properties.__manual_spam_enabled then return end
    if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= Alive then return end
    if getgenv().spamui then return end
    if System.__config.__detections.__infinity and System.__properties.__infinity_active then return end
    if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then return end
    if System.__config.__detections.__timehole and System.__properties.__timehole_active then return end
    if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then return end
    System.__properties.__spam_accumulator = (System.__properties.__spam_accumulator or 0) + delta
    local i = 1 / math.max(1, System.__properties.__spam_rate or 100)
    if (System.__properties.__spam_accumulator or 0) < i then return end
    System.__properties.__spam_accumulator = 0
    System.parry.execute()
end
function System.manual_spam.start()
    if System.__properties.__connections.__manual_spam then System.__properties.__connections.__manual_spam:Disconnect() end
    System.__properties.__manual_spam_enabled = true
    System.__properties.__connections.__manual_spam = RunService.Heartbeat:Connect(System.manual_spam.loop)
end
function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
        System.__properties.__connections.__manual_spam = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- NO RENDER
-- ═══════════════════════════════════════════════════════════
function System.no_render_set(state)
    System.__properties.__no_render_enabled = state
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    local es = ps and ps:FindFirstChild("EffectScripts")
    local cf = es and es:FindFirstChild("ClientFX")
    if cf then cf.Disabled = state end
    if state then
        if not Connections_Manager["No Render"] then
            local rt = workspace:FindFirstChild("Runtime")
            if rt then Connections_Manager["No Render"] = rt.ChildAdded:Connect(function(v) Debris:AddItem(v, 0) end) end
        end
    else
        if Connections_Manager["No Render"] then
            Connections_Manager["No Render"]:Disconnect()
            Connections_Manager["No Render"] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- FPS BOOST
-- ═══════════════════════════════════════════════════════════
local ofe = Lighting.FogEnd; local ofs = Lighting.FogStart
local ppb = {}; local db = {}; local sb = {}; local sbk = nil; local lb = nil; local fb = nil; local fbl = nil; local fbe = false

local function adf(s) if s then Lighting.FogEnd = math.huge; Lighting.FogStart = math.huge else Lighting.FogEnd = ofe; Lighting.FogStart = ofs end end
local function adpp(s)
    if s then
        for _, v in pairs(Lighting:GetDescendants()) do pcall(function() if v.Enabled ~= nil then ppb[v] = v.Enabled; v.Enabled = false end end) end
        fb = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
        pcall(function() Lighting.FogEnd = math.huge; Lighting.FogStart = math.huge; Lighting.FogColor = Color3.new(0,0,0) end)
    else
        for v, e in pairs(ppb) do pcall(function() if v and v.Parent and v.Enabled ~= nil then v.Enabled = e end end) end
        ppb = {}
        if fb then pcall(function() Lighting.FogEnd = fb.FogEnd; Lighting.FogStart = fb.FogStart; Lighting.FogColor = fb.FogColor end); fb = nil end
    end
end
local function ard(s)
    if s then
        for _, v in pairs(workspace:GetDescendants()) do
            pcall(function() if v:IsA("Decal") or v:IsA("Texture") then db[v] = { Texture = v.Texture, Transparency = v.Transparency }; pcall(function() v.Texture = "" end); pcall(function() v.Transparency = 1 end) end end)
        end
    else
        for v, d in pairs(db) do pcall(function() if v and v.Parent then if d.Texture ~= nil then pcall(function() v.Texture = d.Texture end) end; if d.Transparency ~= nil then pcall(function() v.Transparency = d.Transparency end) end end end) end
        db = {}
    end
end
local function ico(obj)
    if not obj then return false end
    local lc = LocalPlayer and LocalPlayer.Character
    if lc and obj:IsDescendantOf(lc) then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and obj:IsDescendantOf(p.Character) then return true end
    end
    return false
end
function System.fps_boost_set(state)
    fbe = state; System.__properties.__fps_boost_enabled = state
    if fbl then fbl:Disconnect(); fbl = nil end
    if not state then
        adf(false); adpp(false); ard(false)
        if lb then
            Lighting.Brightness = lb.Brightness; Lighting.ExposureCompensation = lb.ExposureCompensation
            Lighting.GlobalShadows = lb.GlobalShadows; Lighting.OutdoorAmbient = lb.OutdoorAmbient
            Lighting.Ambient = lb.Ambient; Lighting.ColorShift_Bottom = lb.ColorShift_Bottom
            Lighting.ColorShift_Top = lb.ColorShift_Top; Lighting.ClockTime = lb.ClockTime
            Lighting.ShadowSoftness = lb.ShadowSoftness; lb = nil
        end
        for obj, v in pairs(sb) do
            pcall(function() if obj and obj.Parent then if v.Enabled ~= nil then obj.Enabled = v.Enabled end; if v.CastShadow ~= nil then obj.CastShadow = v.CastShadow end; if v.Material ~= nil then obj.Material = v.Material end end end)
        end
        sb = {}
        if SoundService and sbk ~= nil then SoundService.Volume = sbk; sbk = nil end
        return
    end
    adf(true); adpp(true); ard(true)
    lb = { Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation,
        GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient, ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top, ClockTime = Lighting.ClockTime, ShadowSoftness = Lighting.ShadowSoftness }
    Lighting.Brightness = 0.18; Lighting.ExposureCompensation = -1.2; Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(35,35,35); Lighting.Ambient = Color3.fromRGB(35,35,35)
    Lighting.ColorShift_Bottom = Color3.new(0,0,0); Lighting.ColorShift_Top = Color3.new(0,0,0)
    Lighting.ClockTime = 14; Lighting.ShadowSoftness = 0
    if SoundService and sbk == nil then sbk = SoundService.Volume; SoundService.Volume = 0.03 end
    fbl = RunService.Heartbeat:Connect(function()
        if not fbe then return end
        for _, obj in pairs(workspace:GetDescendants()) do
            pcall(function()
                if ico(obj) then return end
                if obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Highlight") or obj:IsA("SurfaceGui") or obj:IsA("BillboardGui")
                or obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion")
                or obj:IsA("Weld") or obj:IsA("UIStroke") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageLabel") then
                    local s = sb[obj]; if not s then sb[obj] = { Enabled = obj.Enabled } end
                    obj.Enabled = false
                elseif obj:IsA("Part") then
                    local s = sb[obj]; if not s then sb[obj] = { CastShadow = obj.CastShadow, Material = obj.Material } end
                    obj.CastShadow = false; obj.Material = Enum.Material.SmoothPlastic
                elseif obj:IsA("Atmosphere") then obj.Density = 0 end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- HOTKEYS
-- ═══════════════════════════════════════════════════════════
System.hotkeys = { __enabled = true, __conn = nil }
local HMAP = {
    [Enum.KeyCode.T] = function()
        System.__properties.__autoparry_enabled = not System.__properties.__autoparry_enabled
        if System.__properties.__autoparry_enabled then System.autoparry.start() else System.autoparry.stop() end
    end,
    [Enum.KeyCode.C] = function()
        System.__properties.__auto_spam_enabled = not System.__properties.__auto_spam_enabled
        if System.__properties.__auto_spam_enabled then System.auto_spam.start() else System.auto_spam.stop() end
    end,
    [Enum.KeyCode.E] = function()
        System.__properties.__manual_spam_enabled = not System.__properties.__manual_spam_enabled
        if System.__properties.__manual_spam_enabled then System.manual_spam.start() else System.manual_spam.stop() end
    end,
}
function System.hotkeys.start()
    if System.hotkeys.__conn then System.hotkeys.__conn:Disconnect(); System.hotkeys.__conn = nil end
    System.hotkeys.__conn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not System.hotkeys.__enabled then return end
        local fn = HMAP[input.KeyCode]; if fn then pcall(fn) end
    end)
end
System.hotkeys.start()

-- ═══════════════════════════════════════════════════════════
-- PREMIUM UI
-- ═══════════════════════════════════════════════════════════
local Config = setmetatable({
    save = function(self, fn, cfg)
        pcall(function()
            if not writefile then return end
            if isfolder and makefolder and not isfolder("BLABLA") then makefolder("BLABLA") end
            writefile("BLABLA/"..fn..".json", HttpService:JSONEncode(cfg))
        end)
    end,
    load = function(self, fn)
        local r
        pcall(function()
            if not isfile or not isfile("BLABLA/"..fn..".json") then return end
            r = HttpService:JSONDecode(readfile("BLABLA/"..fn..".json"))
        end)
        return r or { _flags = {}, _keybinds = {}, _library = {} }
    end,
}, {})

local Azure = {}
Azure.__index = Azure
Azure._config = Config:load(game.GameId)
Azure._tabCounter = 0
Azure._tabs = {}

function Azure.new()
    local self = setmetatable({}, Azure)
    self._tabs = {}
    local old = CoreGui:FindFirstChild("Azure"); if old then old:Destroy() end

    local SG = Instance.new("ScreenGui")
    SG.Name = "Azure"; SG.ResetOnSpawn = false; SG.IgnoreGuiInset = true
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SG.DisplayOrder = 1000; SG.Parent = CoreGui

    local bg = Instance.new("Frame", SG); bg.Name = "BackGlow"
    bg.AnchorPoint = Vector2.new(0.5,0.5); bg.Position = UDim2.new(0.5,0,0.5,0)
    bg.Size = UDim2.fromOffset(820,600); bg.BackgroundColor3 = PALETTE.accent
    bg.BackgroundTransparency = 0.92; bg.BorderSizePixel = 0; bg.ZIndex = 1
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,40)
    task.spawn(function()
        while bg.Parent do
            TweenService:Create(bg, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.85 }):Play()
            task.wait(3)
            TweenService:Create(bg, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.92 }):Play()
            task.wait(3)
        end
    end)

    local C = Instance.new("Frame", SG); C.Name = "Container"
    C.AnchorPoint = Vector2.new(0.5,0.5); C.Position = UDim2.new(0.5,0,0.5,0)
    C.Size = UDim2.fromOffset(0,0); C.BackgroundColor3 = PALETTE.bgMain
    C.BackgroundTransparency = 0.05; C.BorderSizePixel = 0; C.ClipsDescendants = true
    C.Active = true; C.ZIndex = 5
    Instance.new("UICorner", C).CornerRadius = UDim.new(0,16)

    local og = Instance.new("UIStroke", C)
    og.Color = PALETTE.accent; og.Thickness = 2; og.Transparency = 0.55
    og.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Animation.glowPulse(og, 0.55, 0.35, 2.5)

    local is = Instance.new("UIStroke", C)
    is.Color = Color3.fromRGB(255,255,255); is.Thickness = 1; is.Transparency = 0.85
    is.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local bgg = Instance.new("UIGradient", C)
    bgg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(48,32,88)),
        ColorSequenceKeypoint.new(0.30, Color3.fromRGB(38,24,68)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(28,18,52)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(20,12,38)),
    }; bgg.Rotation = 135

    Animation.glassHighlight(C)

    local Sh = Instance.new("Frame", C); Sh.Name = "Shimmer"
    Sh.AnchorPoint = Vector2.new(0.5,0.5); Sh.Position = UDim2.new(0.5,0,0.5,0)
    Sh.Size = UDim2.new(1,0,1,0); Sh.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Sh.BorderSizePixel = 0; Sh.ZIndex = 100; Sh.Active = false
    Instance.new("UICorner", Sh).CornerRadius = UDim.new(0,16)

    local shg = Instance.new("UIGradient", Sh)
    shg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200,150,255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150,200,255)),
    }
    shg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00,1), NumberSequenceKeypoint.new(0.40,1),
        NumberSequenceKeypoint.new(0.46,0.12), NumberSequenceKeypoint.new(0.50,0.04),
        NumberSequenceKeypoint.new(0.54,0.12), NumberSequenceKeypoint.new(0.60,1),
        NumberSequenceKeypoint.new(1.00,1),
    })
    shg.Rotation = 45; shg.Offset = Vector2.new(-1.2,0); shg.Parent = Sh
    Animation.shimmer(shg, 1.8, 3.5)

    local pl = Instance.new("Frame", C); pl.Name = "Particles"
    pl.BackgroundTransparency = 1; pl.Size = UDim2.new(1,0,1,0)
    pl.ClipsDescendants = true; pl.ZIndex = 3
    Animation.spawnParticles(pl)

    local H = Instance.new("Frame", C); H.Name = "Handler"
    H.BackgroundTransparency = 1; H.Size = UDim2.new(0,750,0,530); H.ZIndex = 10

    local tg = Instance.new("Frame", H)
    tg.AnchorPoint = Vector2.new(0,0.5); tg.Position = UDim2.new(0.05,0,0.05,0)
    tg.Size = UDim2.fromOffset(180,40); tg.BackgroundColor3 = PALETTE.accent
    tg.BackgroundTransparency = 0.88; tg.BorderSizePixel = 0; tg.ZIndex = 4
    Instance.new("UICorner", tg).CornerRadius = UDim.new(0,12)

    local T = Instance.new("TextLabel", H); T.FontFace = FONT.black
    T.Text = "BLABLA"; T.TextColor3 = Color3.fromRGB(255,255,255); T.BackgroundTransparency = 1
    T.Size = UDim2.new(0,200,0,30); T.AnchorPoint = Vector2.new(0,0.5)
    T.Position = UDim2.new(0.05,0,0.05,0); T.TextXAlignment = Enum.TextXAlignment.Left
    T.TextSize = 30; T.ZIndex = 6

    local tst = Instance.new("UIStroke", T)
    tst.Color = PALETTE.accent; tst.Thickness = 2; tst.Transparency = 0.35
    tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    Animation.glowPulse(tst, 0.35, 0.08, 1.8)

    local ST = Instance.new("TextLabel", H); ST.FontFace = FONT.semi
    ST.Text = "blade ball hub  ·  premium"; ST.TextColor3 = PALETTE.textFaint
    ST.BackgroundTransparency = 1; ST.Size = UDim2.new(0,200,0,14)
    ST.AnchorPoint = Vector2.new(0,0.5); ST.Position = UDim2.new(0.05,0,0.095,0)
    ST.TextXAlignment = Enum.TextXAlignment.Left; ST.TextSize = 11; ST.ZIndex = 6

    local TF = Instance.new("ScrollingFrame", H); TF.Name = "Tabs"
    TF.Size = UDim2.new(0,140,0,445); TF.Position = UDim2.new(0.026,0,0.111,10)
    TF.BackgroundTransparency = 1; TF.BorderSizePixel = 0; TF.ScrollBarThickness = 0
    TF.Selectable = true; TF.Active = true; TF.ZIndex = 11
    TF.AutomaticCanvasSize = Enum.AutomaticSize.XY; TF.CanvasSize = UDim2.new(0,0,0,0)
    local tl = Instance.new("UIListLayout", TF); tl.Padding = UDim.new(0,5); tl.SortOrder = Enum.SortOrder.LayoutOrder

    local SF = Instance.new("Frame", H); SF.BackgroundTransparency = 1
    SF.Position = UDim2.new(0.22,0,0,0); SF.Size = UDim2.new(0.78,0,1,0); SF.ZIndex = 6

    local US = Instance.new("UIScale", C)

    local d, ds, sp
    C.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = input.Position; sp = C.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then d = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not d then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local dd = input.Position - ds
            C.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dd.X, sp.Y.Scale, sp.Y.Offset + dd.Y)
        end
    end)

    self._container = C; self._handler = H; self._tabsFrame = TF; self._sections = SF; self._ui = SG

    local vpx = workspace.CurrentCamera.ViewportSize.X
    local bs = (UserInputService.TouchEnabled and (vpx / 1400) or 1)
    US.Scale = bs * 0.6; C.Rotation = -3
    task.spawn(function()
        task.wait(0.02)
        TweenService:Create(C, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(750,530), Rotation = 0 }):Play()
        TweenService:Create(US, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = bs }):Play()
    end)
    if not UserInputService.TouchEnabled then Animation.parallaxTilt(C, 2) end
    return self
end

function Azure:create_tab(title)
    local ti = self._tabCounter; self._tabCounter += 1

    local Tab = Instance.new("TextButton", self._tabsFrame)
    Tab.Name = "Tab"; Tab.FontFace = FONT.bold; Tab.Text = title
    Tab.TextColor3 = PALETTE.text; Tab.TextTransparency = 0.55; Tab.TextSize = 15
    Tab.AutoButtonColor = false; Tab.BackgroundTransparency = 1
    Tab.BackgroundColor3 = PALETTE.bgSoft; Tab.Size = UDim2.new(0,129,0,40)
    Tab.BorderSizePixel = 0; Tab.LayoutOrder = ti
    Tab.TextXAlignment = Enum.TextXAlignment.Left; Tab.ZIndex = 11; Tab.Active = true
    Instance.new("UICorner", Tab).CornerRadius = UDim.new(0,10)
    local tp = Instance.new("UIPadding", Tab); tp.PaddingLeft = UDim.new(0,34)

    local ts = Instance.new("UIScale", Tab); ts.Scale = 1

    local ab = Instance.new("Frame", Tab); ab.Name = "ActiveBar"
    ab.AnchorPoint = Vector2.new(0,0.5); ab.Position = UDim2.new(0,0,0.5,0)
    ab.Size = UDim2.new(0,4,0.65,0); ab.BackgroundColor3 = PALETTE.accentHot
    ab.BorderSizePixel = 0; ab.ZIndex = 12; ab.BackgroundTransparency = 1
    Instance.new("UICorner", ab).CornerRadius = UDim.new(1,0)

    local tg = Instance.new("Frame", Tab); tg.Name = "TabGlow"
    tg.AnchorPoint = Vector2.new(0.5,0.5); tg.Position = UDim2.new(0.5,0,0.5,0)
    tg.Size = UDim2.new(1,-8,1,-6); tg.BackgroundColor3 = PALETTE.accent
    tg.BackgroundTransparency = 1; tg.BorderSizePixel = 0; tg.ZIndex = 10
    Instance.new("UICorner", tg).CornerRadius = UDim.new(0,8)

    Tab.MouseEnter:Connect(function()
        TweenService:Create(ts, Animation.smoothOut, { Scale = 1.05 }):Play()
        if Tab.BackgroundTransparency == 1 then TweenService:Create(Tab, Animation.smoothOut, { BackgroundTransparency = 0.85 }):Play() end
    end)
    Tab.MouseLeave:Connect(function()
        TweenService:Create(ts, Animation.smoothOut, { Scale = 1 }):Play()
        if Tab.BackgroundTransparency ~= 0.7 then TweenService:Create(Tab, Animation.smoothOut, { BackgroundTransparency = 1 }):Play() end
    end)

    local LS = Instance.new("ScrollingFrame", self._sections)
    LS.Name = "LeftSection"; LS.Size = UDim2.new(0,243,0,445)
    LS.Position = UDim2.new(0.05,0,0.5,25); LS.AnchorPoint = Vector2.new(0,0.5)
    LS.BackgroundTransparency = 1; LS.BorderSizePixel = 0; LS.ScrollBarThickness = 0
    LS.AutomaticCanvasSize = Enum.AutomaticSize.XY; LS.CanvasSize = UDim2.new(0,0,0,0)
    LS.Visible = false; LS.ZIndex = 7
    local ll = Instance.new("UIListLayout", LS); ll.Padding = UDim.new(0,20)
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Center; ll.SortOrder = Enum.SortOrder.LayoutOrder

    local RS2 = Instance.new("ScrollingFrame", self._sections)
    RS2.Name = "RightSection"; RS2.Size = UDim2.new(0,243,0,445)
    RS2.Position = UDim2.new(0.52,0,0.5,25); RS2.AnchorPoint = Vector2.new(0,0.5)
    RS2.BackgroundTransparency = 1; RS2.BorderSizePixel = 0; RS2.ScrollBarThickness = 0
    RS2.AutomaticCanvasSize = Enum.AutomaticSize.XY; RS2.CanvasSize = UDim2.new(0,0,0,0)
    RS2.Visible = false; RS2.ZIndex = 7
    local rl = Instance.new("UIListLayout", RS2); rl.Padding = UDim.new(0,20)
    rl.HorizontalAlignment = Enum.HorizontalAlignment.Center; rl.SortOrder = Enum.SortOrder.LayoutOrder

    local rec = { Tab = Tab, Left = LS, Right = RS2, ActiveBar = ab, Glow = tg }
    table.insert(self._tabs, rec)

    local function activate()
        for _, r in pairs(self._tabs) do r.Left.Visible = false; r.Right.Visible = false end
        LS.Visible = true; RS2.Visible = true
        local function staggerIn(c)
            local ch = {}
            for _, x in ipairs(c:GetChildren()) do if x:IsA("Frame") and x.Name == "ModuleWrapper" then table.insert(ch, x) end end
            Animation.stagger(ch, 0, 0.05, function(mod)
                local sp = UDim2.new(mod.Position.X.Scale, mod.Position.X.Offset, mod.Position.Y.Scale, mod.Position.Y.Offset - 20)
                mod.Position = sp; mod.BackgroundTransparency = 1; mod.Rotation = -1.5
                TweenService:Create(mod, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Position = UDim2.new(mod.Position.X.Scale, mod.Position.X.Offset, mod.Position.Y.Scale, mod.Position.Y.Offset + 20),
                    BackgroundTransparency = 0.03, Rotation = 0 }):Play()
            end)
        end
        for _, r in pairs(self._tabs) do
            local isA = (r.Tab == Tab)
            TweenService:Create(r.Tab, Animation.smoothOut, { BackgroundTransparency = isA and 0.7 or 1, BackgroundColor3 = isA and PALETTE.borderSoft or PALETTE.bgSoft }):Play()
            TweenService:Create(r.Tab, Animation.smoothOut, { TextTransparency = isA and 0.05 or 0.55 }):Play()
            TweenService:Create(r.Tab, Animation.smoothOut, { TextSize = isA and 16 or 15 }):Play()
            if r.ActiveBar then TweenService:Create(r.ActiveBar, Animation.smoothOut, { BackgroundTransparency = isA and 0 or 1 }):Play() end
            if r.Glow then TweenService:Create(r.Glow, Animation.smoothOut, { BackgroundTransparency = isA and 0.85 or 1 }):Play() end
        end
        if LS.Visible then staggerIn(LS) end
        if RS2.Visible then staggerIn(RS2) end
    end

    if ti == 0 then activate() end
    Tab.MouseButton1Click:Connect(function() task.defer(activate) end)
    Tab.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then task.defer(activate) end
    end)

    local TM = {}

    function TM:create_module(settings)
        local section = (settings.section == "right") and RS2 or LS
        local wrapper = Instance.new("Frame", section)
        wrapper.Name = "ModuleWrapper"; wrapper.Size = UDim2.new(0,241,0,93)
        wrapper.Position = UDim2.new(0.004,0,0,-5); wrapper.BackgroundTransparency = 1; wrapper.ZIndex = 7

        local shadow = Instance.new("Frame", wrapper)
        shadow.AnchorPoint = Vector2.new(0.5,0.5); shadow.Position = UDim2.new(0.5,0,0.5,5)
        shadow.Size = UDim2.new(1,-4,1,-4); shadow.BackgroundColor3 = Color3.new(0,0,0)
        shadow.BackgroundTransparency = 0.75; shadow.BorderSizePixel = 0; shadow.ZIndex = 6
        Instance.new("UICorner", shadow).CornerRadius = UDim.new(0,12)

        local M = Instance.new("Frame", wrapper)
        M.Name = "Module"; M.Size = UDim2.new(1,0,1,0); M.BackgroundColor3 = PALETTE.card
        M.BackgroundTransparency = 0.03; M.BorderSizePixel = 0; M.ClipsDescendants = false
        M.AutomaticSize = Enum.AutomaticSize.Y; M.ZIndex = 7
        Instance.new("UICorner", M).CornerRadius = UDim.new(0,12)
        Animation.glassHighlight(M)

        local cg = Instance.new("UIGradient", M)
        cg.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(40,28,68)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(26,18,46)) }; cg.Rotation = 135

        local ms = Instance.new("UIStroke", M); ms.Color = PALETTE.border; ms.Transparency = 0.55
        ms.Thickness = 1.2; ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local ig = Instance.new("UIStroke", M); ig.Color = PALETTE.accentHot
        ig.Transparency = 0.92; ig.Thickness = 1; ig.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local msc = Instance.new("UIScale", M)
        M.MouseEnter:Connect(function()
            TweenService:Create(ms, Animation.smoothOut, { Transparency = 0.15, Thickness = 1.6, Color = PALETTE.accentHot }):Play()
            TweenService:Create(ig, Animation.smoothOut, { Transparency = 0.7 }):Play()
            TweenService:Create(msc, Animation.smoothOut, { Scale = 1.012 }):Play()
            TweenService:Create(shadow, Animation.smoothOut, { BackgroundTransparency = 0.6, Position = UDim2.new(0.5,0,0.5,6) }):Play()
        end)
        M.MouseLeave:Connect(function()
            TweenService:Create(ms, Animation.smoothOut, { Transparency = 0.55, Thickness = 1.2, Color = PALETTE.border }):Play()
            TweenService:Create(ig, Animation.smoothOut, { Transparency = 0.92 }):Play()
            TweenService:Create(msc, Animation.smoothOut, { Scale = 1 }):Play()
            TweenService:Create(shadow, Animation.smoothOut, { BackgroundTransparency = 0.75, Position = UDim2.new(0.5,0,0.5,5) }):Play()
        end)

        local H = Instance.new("TextButton", M); H.Name = "Header"; H.Text = ""
        H.AutoButtonColor = false; H.BackgroundTransparency = 1
        H.Size = UDim2.new(0,241,0,93); H.BorderSizePixel = 0; H.ZIndex = 9

        local idot = Instance.new("Frame", H)
        idot.AnchorPoint = Vector2.new(0,0.5); idot.Position = UDim2.new(0.055,0,0.27,0)
        idot.Size = UDim2.fromOffset(6,6); idot.BackgroundColor3 = PALETTE.accent
        idot.BorderSizePixel = 0; idot.ZIndex = 10
        Instance.new("UICorner", idot).CornerRadius = UDim.new(1,0)

        local MN = Instance.new("TextLabel", H); MN.FontFace = FONT.bold
        MN.Text = settings.title or "Module"; MN.TextColor3 = PALETTE.text
        MN.TextTransparency = 0.1; MN.BackgroundTransparency = 1
        MN.Size = UDim2.new(0,200,0,16); MN.AnchorPoint = Vector2.new(0,0.5)
        MN.Position = UDim2.new(0.088,0,0.24,0); MN.TextXAlignment = Enum.TextXAlignment.Left
        MN.TextSize = 15; MN.ZIndex = 10

        local D = Instance.new("TextLabel", H); D.FontFace = FONT.reg
        D.Text = settings.description or ""; D.TextColor3 = PALETTE.textFaint
        D.TextTransparency = 0.35; D.BackgroundTransparency = 1
        D.Size = UDim2.new(0,200,0,13); D.AnchorPoint = Vector2.new(0,0.5)
        D.Position = UDim2.new(0.088,0,0.44,0); D.TextXAlignment = Enum.TextXAlignment.Left
        D.TextSize = 10; D.ZIndex = 10

        local Tg = Instance.new("Frame", H); Tg.AnchorPoint = Vector2.new(1,0.5)
        Tg.BackgroundTransparency = 0.6; Tg.BackgroundColor3 = Color3.fromRGB(50,38,82)
        Tg.Size = UDim2.fromOffset(28,14); Tg.Position = UDim2.new(1,-18,0.757,0)
        Tg.BorderSizePixel = 0; Tg.ZIndex = 10
        Instance.new("UICorner", Tg).CornerRadius = UDim.new(1,0)

        local ts2 = Instance.new("UIStroke", Tg)
        ts2.Color = PALETTE.borderSoft; ts2.Thickness = 1; ts2.Transparency = 0.5
        ts2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local Ci = Instance.new("Frame", Tg); Ci.AnchorPoint = Vector2.new(0,0.5)
        Ci.Position = UDim2.new(0,1,0.5,0); Ci.BackgroundColor3 = Color3.fromRGB(130,110,175)
        Ci.BackgroundTransparency = 0.15; Ci.Size = UDim2.new(0,12,0,12)
        Ci.BorderSizePixel = 0; Ci.ZIndex = 11
        Instance.new("UICorner", Ci).CornerRadius = UDim.new(1,0)

        local O = Instance.new("Frame", M); O.Name = "Options"
        O.BackgroundTransparency = 1; O.Position = UDim2.new(0,0,0,93)
        O.Size = UDim2.new(0,241,0,8); O.ZIndex = 8; O.ClipsDescendants = false
        local op = Instance.new("UIPadding", O); op.PaddingTop = UDim.new(0,10)
        local ol = Instance.new("UIListLayout", O); ol.Padding = UDim.new(0,6)
        ol.HorizontalAlignment = Enum.HorizontalAlignment.Center; ol.SortOrder = Enum.SortOrder.LayoutOrder

        local MM = { _state = false, _size = 0, _multiplier = 0 }

        local function rs()
            local ch = (MM._size or 0) + (MM._multiplier or 0)
            local tt = 93 + ch
            M.Size = UDim2.fromOffset(241, tt)
            wrapper.Size = UDim2.fromOffset(241, tt)
            shadow.Size = UDim2.new(1,-4,1,-4)
            O.Size = UDim2.fromOffset(241, ch)
        end

        function MM:change_state(state)
            self._state = state
            if self._state then
                TweenService:Create(Tg, Animation.springOut, { BackgroundColor3 = PALETTE.accent }):Play()
                TweenService:Create(ts2, Animation.springOut, { Color = PALETTE.accentHot, Transparency = 0.15 }):Play()
                TweenService:Create(Ci, Animation.springOut, { BackgroundColor3 = Color3.fromRGB(255,255,255), Position = UDim2.new(1,-13,0.5,0) }):Play()
                TweenService:Create(ms, Animation.smoothOut, { Color = PALETTE.accentHot, Transparency = 0.25, Thickness = 1.6 }):Play()
                task.delay(0.6, function()
                    TweenService:Create(ms, Animation.smoothOut, { Color = PALETTE.border, Transparency = 0.55, Thickness = 1.2 }):Play()
                end)
            else
                TweenService:Create(Tg, Animation.smoothOut, { BackgroundColor3 = Color3.fromRGB(50,38,82) }):Play()
                TweenService:Create(ts2, Animation.smoothOut, { Color = PALETTE.borderSoft, Transparency = 0.5 }):Play()
                TweenService:Create(Ci, Animation.smoothOut, { BackgroundColor3 = Color3.fromRGB(130,110,175), Position = UDim2.new(0,1,0.5,0) }):Play()
            end
            rs()
            Azure._config._flags[settings.flag] = self._state
            Config:save(game.GameId, Azure._config)
            if settings.callback then pcall(settings.callback, self._state) end
        end

        if Azure._config._flags[settings.flag] then
            MM._state = true
            Tg.BackgroundColor3 = PALETTE.accent
            ts2.Color = PALETTE.accentHot; ts2.Transparency = 0.15
            Ci.BackgroundColor3 = Color3.fromRGB(255,255,255); Ci.Position = UDim2.new(1,-13,0.5,0)
            pcall(function() if settings.callback then settings.callback(true) end end)
        end

        H.MouseButton1Click:Connect(function() MM:change_state(not MM._state) end)

        function MM:create_checkbox(s)
            if self._size == 0 then self._size = 11 end
            self._size += 22; rs()
            local CM = { _state = false }
            local Cb = Instance.new("TextButton", O); Cb.Name = "Checkbox"; Cb.Text = ""
            Cb.AutoButtonColor = false; Cb.BackgroundTransparency = 1
            Cb.Size = UDim2.new(0,207,0,18); Cb.BorderSizePixel = 0; Cb.ZIndex = 9
            local TL = Instance.new("TextLabel", Cb); TL.FontFace = FONT.semi; TL.Text = s.title
            TL.TextColor3 = PALETTE.text; TL.TextTransparency = 0.15; TL.BackgroundTransparency = 1
            TL.Size = UDim2.new(0,142,0,15); TL.AnchorPoint = Vector2.new(0,0.5)
            TL.Position = UDim2.new(0,0,0.5,0); TL.TextXAlignment = Enum.TextXAlignment.Left
            TL.TextSize = 12; TL.ZIndex = 10
            local B = Instance.new("Frame", Cb); B.AnchorPoint = Vector2.new(1,0.5)
            B.Position = UDim2.new(1,-2,0.5,0); B.Size = UDim2.fromOffset(16,16)
            B.BackgroundColor3 = Color3.fromRGB(50,38,82); B.BackgroundTransparency = 0.6
            B.BorderSizePixel = 0; B.ZIndex = 10
            Instance.new("UICorner", B).CornerRadius = UDim.new(0,6)
            local bS = Instance.new("UIStroke", B); bS.Color = PALETTE.borderSoft; bS.Transparency = 0.4
            bS.Thickness = 1; bS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            local F = Instance.new("Frame", B); F.AnchorPoint = Vector2.new(0.5,0.5)
            F.Position = UDim2.new(0.5,0,0.5,0); F.Size = UDim2.fromOffset(0,0)
            F.BackgroundColor3 = PALETTE.accent; F.BackgroundTransparency = 0.15
            F.BorderSizePixel = 0; F.ZIndex = 11
            Instance.new("UICorner", F).CornerRadius = UDim.new(0,5)
            local CK = Instance.new("TextLabel", B); CK.FontFace = FONT.bold; CK.Text = "✓"
            CK.TextColor3 = Color3.new(1,1,1); CK.TextTransparency = 1; CK.BackgroundTransparency = 1
            CK.Size = UDim2.new(1,0,1,0); CK.TextSize = 12; CK.ZIndex = 12
            Cb.MouseEnter:Connect(function()
                TweenService:Create(TL, Animation.smoothOut, { TextTransparency = 0 }):Play()
                TweenService:Create(bS, Animation.smoothOut, { Color = PALETTE.accentHot, Transparency = 0.15 }):Play()
            end)
            Cb.MouseLeave:Connect(function()
                TweenService:Create(TL, Animation.smoothOut, { TextTransparency = 0.15 }):Play()
                if not CM._state then TweenService:Create(bS, Animation.smoothOut, { Color = PALETTE.borderSoft, Transparency = 0.4 }):Play() end
            end)
            function CM:change_state(st)
                self._state = st
                if st then
                    TweenService:Create(B, Animation.springOut, { BackgroundTransparency = 0.75 }):Play()
                    TweenService:Create(F, Animation.springOut, { Size = UDim2.fromOffset(10,10) }):Play()
                    TweenService:Create(CK, Animation.smoothOut, { TextTransparency = 0.3 }):Play()
                    TweenService:Create(bS, Animation.springOut, { Color = PALETTE.accentHot, Transparency = 0.1 }):Play()
                else
                    TweenService:Create(B, Animation.smoothOut, { BackgroundTransparency = 0.6 }):Play()
                    TweenService:Create(F, Animation.smoothOut, { Size = UDim2.fromOffset(0,0) }):Play()
                    TweenService:Create(CK, Animation.smoothOut, { TextTransparency = 1 }):Play()
                    TweenService:Create(bS, Animation.smoothOut, { Color = PALETTE.borderSoft, Transparency = 0.4 }):Play()
                end
                Azure._config._flags[s.flag] = self._state
                Config:save(game.GameId, Azure._config)
                if s.callback then pcall(s.callback, self._state) end
            end
            if Azure._config._flags[s.flag] ~= nil then CM:change_state(Azure._config._flags[s.flag]) end
            Cb.MouseButton1Click:Connect(function() CM:change_state(not CM._state) end)
            rs()
            return CM
        end

        function MM:create_slider(s)
            if self._size == 0 then self._size = 11 end
            self._size += 30; rs()
            local Sl = Instance.new("TextButton", O); Sl.Name = "Slider"; Sl.Text = ""
            Sl.AutoButtonColor = false; Sl.BackgroundTransparency = 1
            Sl.Size = UDim2.new(0,207,0,25); Sl.BorderSizePixel = 0; Sl.ZIndex = 9
            local TL = Instance.new("TextLabel", Sl); TL.FontFace = FONT.semi; TL.Text = s.title
            TL.TextColor3 = PALETTE.text; TL.TextTransparency = 0.15; TL.BackgroundTransparency = 1
            TL.Size = UDim2.new(0,153,0,15); TL.Position = UDim2.new(0,0,0,0)
            TL.TextXAlignment = Enum.TextXAlignment.Left; TL.TextSize = 12; TL.ZIndex = 10
            local V = Instance.new("TextLabel", Sl); V.Name = "Value"; V.FontFace = FONT.bold
            V.TextColor3 = PALETTE.accentHot; V.TextTransparency = 0.05; V.Text = "0"
            V.BackgroundTransparency = 1; V.Size = UDim2.new(0,42,0,15)
            V.AnchorPoint = Vector2.new(1,0); V.Position = UDim2.new(1,-2,0,0)
            V.TextXAlignment = Enum.TextXAlignment.Right; V.TextSize = 12; V.ZIndex = 10
            local Dr = Instance.new("Frame", Sl); Dr.AnchorPoint = Vector2.new(0.5,1)
            Dr.Position = UDim2.new(0.5,0,0.98,0); Dr.Size = UDim2.new(0,207,0,5)
            Dr.BackgroundColor3 = Color3.fromRGB(35,26,58); Dr.BackgroundTransparency = 0.5
            Dr.BorderSizePixel = 0; Dr.ZIndex = 10
            Instance.new("UICorner", Dr).CornerRadius = UDim.new(1,0)
            local F = Instance.new("Frame", Dr); F.AnchorPoint = Vector2.new(0,0.5)
            F.Position = UDim2.new(0,0,0.5,0); F.Size = UDim2.new(0,0,0,5)
            F.BackgroundColor3 = PALETTE.accent; F.BackgroundTransparency = 0.05
            F.BorderSizePixel = 0; F.ZIndex = 11
            Instance.new("UICorner", F).CornerRadius = UDim.new(1,0)
            local fg = Instance.new("UIGradient", F)
            fg.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, PALETTE.accent),
                ColorSequenceKeypoint.new(1, PALETTE.accentHot) }; fg.Parent = F
            local C2 = Instance.new("Frame", F); C2.AnchorPoint = Vector2.new(1,0.5)
            C2.Position = UDim2.new(1,0,0.5,0); C2.Size = UDim2.fromOffset(9,9)
            C2.BackgroundColor3 = Color3.fromRGB(255,255,255); C2.BorderSizePixel = 0; C2.ZIndex = 12
            Instance.new("UICorner", C2).CornerRadius = UDim.new(1,0)
            local SM = {}
            local mnv = s.minimum_value or 0
            local mxv = s.maximum_value or 100
            local cu = s.value or mnv
            function SM:set_value(v)
                cu = math.clamp(v, mnv, mxv)
                if s.round_number then cu = math.floor(cu + 0.5) else cu = math.floor(cu * 100 + 0.5) / 100 end
                local pct = (cu - mnv) / (mxv - mnv)
                V.Text = tostring(cu)
                TweenService:Create(F, Animation.smoothOut, { Size = UDim2.new(pct,0,0,5) }):Play()
                local sc = C2:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", C2)
                sc.Scale = 1.35
                TweenService:Create(sc, Animation.springOut, { Scale = 1 }):Play()
                Azure._config._flags[s.flag] = cu
                if s.callback then pcall(s.callback, cu) end
            end
            if Azure._config._flags[s.flag] then SM:set_value(Azure._config._flags[s.flag]) else SM:set_value(cu) end
            local dg = false
            local function ufi(input)
                local rel = math.clamp((input.Position.X - Dr.AbsolutePosition.X) / Dr.AbsoluteSize.X, 0, 1)
                SM:set_value(mnv + rel * (mxv - mnv))
            end
            Sl.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dg = true; ufi(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if not dg then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then ufi(input) end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if dg then dg = false; Config:save(game.GameId, Azure._config) end
                end
            end)
            rs()
            return SM
        end

        function MM:create_dropdown(s)
            if self._size == 0 then self._size = 11 end
            self._size += 46; rs()
            local DM = { _state = false, _size = 0 }
            local Dr = Instance.new("TextButton", O); Dr.Name = "Dropdown"; Dr.Text = ""
            Dr.AutoButtonColor = false; Dr.BackgroundTransparency = 1
            Dr.Size = UDim2.new(0,207,0,42); Dr.BorderSizePixel = 0; Dr.ZIndex = 9
            local TL = Instance.new("TextLabel", Dr); TL.FontFace = FONT.semi; TL.Text = s.title
            TL.TextColor3 = PALETTE.text; TL.TextTransparency = 0.15; TL.BackgroundTransparency = 1
            TL.Size = UDim2.new(0,207,0,15); TL.TextXAlignment = Enum.TextXAlignment.Left
            TL.TextSize = 12; TL.ZIndex = 10
            local B = Instance.new("Frame", TL); B.Name = "Box"; B.ClipsDescendants = true
            B.AnchorPoint = Vector2.new(0.5,0); B.Position = UDim2.new(0.5,0,1.15,0)
            B.Size = UDim2.new(0,207,0,24); B.BackgroundColor3 = Color3.fromRGB(32,24,52)
            B.BackgroundTransparency = 0.25; B.BorderSizePixel = 0; B.ZIndex = 11
            Instance.new("UICorner", B).CornerRadius = UDim.new(0,6)
            local bS = Instance.new("UIStroke", B); bS.Color = PALETTE.borderSoft
            bS.Transparency = 0.55; bS.Thickness = 1; bS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            local Ar = Instance.new("TextLabel", B); Ar.FontFace = FONT.bold; Ar.Text = "▾"
            Ar.TextColor3 = PALETTE.accentHot; Ar.TextTransparency = 0.15; Ar.BackgroundTransparency = 1
            Ar.AnchorPoint = Vector2.new(1,0.5); Ar.Position = UDim2.new(1,-6,0.5,0)
            Ar.Size = UDim2.fromOffset(12,12); Ar.TextSize = 11; Ar.ZIndex = 12
            local CO = Instance.new("TextLabel", B); CO.FontFace = FONT.bold
            CO.TextColor3 = PALETTE.text; CO.TextTransparency = 0.05; CO.BackgroundTransparency = 1
            CO.Size = UDim2.new(0,165,0,15); CO.AnchorPoint = Vector2.new(0,0.5)
            CO.Position = UDim2.new(0.04,0,0.5,0); CO.TextXAlignment = Enum.TextXAlignment.Left
            CO.TextSize = 12; CO.ZIndex = 12
            local OF = Instance.new("ScrollingFrame", B); OF.Name = "Options"
            OF.ScrollBarThickness = 0; OF.BackgroundTransparency = 1
            OF.Position = UDim2.new(0,0,1,0); OF.Size = UDim2.new(0,207,0,0)
            OF.CanvasSize = UDim2.new(0,0,0,0); OF.AutomaticCanvasSize = Enum.AutomaticSize.Y; OF.ZIndex = 12
            local oL = Instance.new("UIListLayout", OF); oL.SortOrder = Enum.SortOrder.LayoutOrder; oL.Padding = UDim.new(0,2)
            function DM:update(option)
                CO.Text = (typeof(option) == "string" and option) or option.Name
                Azure._config._flags[s.flag] = option
                Config:save(game.GameId, Azure._config)
                if s.callback then pcall(s.callback, option) end
            end
            if s.options and #s.options > 0 then
                DM._size = 5
                for index, value in ipairs(s.options) do
                    local Op = Instance.new("TextButton", OF); Op.Name = "Option"; Op.FontFace = FONT.med
                    Op.Text = (typeof(value) == "string" and value) or value.Name
                    Op.TextColor3 = PALETTE.textDim; Op.TextTransparency = 0.5; Op.TextSize = 11
                    Op.BackgroundTransparency = 1; Op.TextXAlignment = Enum.TextXAlignment.Left
                    Op.AutoButtonColor = false; Op.Size = UDim2.new(0,186,0,19); Op.ZIndex = 13
                    local oP = Instance.new("UIPadding", Op); oP.PaddingLeft = UDim.new(0,8)
                    Op.MouseEnter:Connect(function()
                        if Op.Text ~= CO.Text then
                            TweenService:Create(Op, Animation.smoothOut, { TextTransparency = 0.1, TextColor3 = PALETTE.accentHot }):Play()
                        end
                    end)
                    Op.MouseLeave:Connect(function()
                        if Op.Text ~= CO.Text then
                            TweenService:Create(Op, Animation.smoothOut, { TextTransparency = 0.5, TextColor3 = PALETTE.textDim }):Play()
                        end
                    end)
                    Op.MouseButton1Click:Connect(function()
                        DM:update(value)
                        for _, c in OF:GetChildren() do
                            if c.Name == "Option" then
                                c.TextTransparency = (c.Text == CO.Text) and 0.05 or 0.5
                                c.TextColor3 = (c.Text == CO.Text) and PALETTE.accentHot or PALETTE.textDim
                            end
                        end
                    end)
                    if index > (s.maximum_options or 10) then continue end
                    DM._size += 19
                end
                OF.Size = UDim2.fromOffset(207, DM._size)
            end
            if Azure._config._flags[s.flag] then DM:update(Azure._config._flags[s.flag])
            elseif s.options and s.options[1] then DM:update(s.options[1]) end
            Dr.MouseButton1Click:Connect(function()
                self._state = not self._state
                if self._state then
                    MM._multiplier += self._size
                    TweenService:Create(Dr, Animation.springOut, { Size = UDim2.fromOffset(207, 42 + self._size) }):Play()
                    TweenService:Create(B, Animation.springOut, { Size = UDim2.fromOffset(207, 24 + self._size) }):Play()
                    TweenService:Create(Ar, Animation.smoothOut, { Rotation = 180 }):Play()
                else
                    MM._multiplier -= self._size
                    TweenService:Create(Dr, Animation.smoothOut, { Size = UDim2.fromOffset(207, 42) }):Play()
                    TweenService:Create(B, Animation.smoothOut, { Size = UDim2.fromOffset(207, 24) }):Play()
                    TweenService:Create(Ar, Animation.smoothOut, { Rotation = 0 }):Play()
                end
                rs()
            end)
            rs()
            return DM
        end

        rs()
        return MM
    end

    return TM
end

-- ═══════════════════════════════════════════════════════════
-- TABS + MODULES
-- ═══════════════════════════════════════════════════════════
local AW = Azure.new()
local MainTab = AW:create_tab("Main")
local SpamTab = AW:create_tab("Spam")
local DetTab = AW:create_tab("Detection")
local VisualTab = AW:create_tab("Visual")

-- Auto Parry module
local apm = MainTab:create_module({
    title = "Auto Parry", description = "Auto Parry Settings",
    flag = "AutoParryModule", section = "left",
    callback = function(s) System.__properties.__autoparry_enabled = s; if s then System.autoparry.start() else System.autoparry.stop() end end,
})
apm:create_slider({ title = "Parry Accuracy", flag = "ParryAccuracy", maximum_value = 50, minimum_value = 1, value = 50, round_number = true,
    callback = function(v) if System and not System.__properties.__humanizer_enabled then System.__properties.__accuracy = v; update_divisor() end end })
apm:create_dropdown({ title = "Parry Mode", flag = "AutoParryMode", options = {"Remote", "Keypress"}, maximum_options = 10,
    callback = function(v) getgenv().AutoParryMode = v end })
apm:create_dropdown({ title = "Mode curve", flag = "ModeCurve", options = System.__config.__curve_names, maximum_options = 10,
    callback = function(v) for i, n in ipairs(System.__config.__curve_names) do if n == v then System.__properties.__curve_mode = i; break end end end })
apm:create_checkbox({ title = "Cooldown Protection", flag = "CooldownProtection",
    callback = function(v) getgenv().CooldownProtection = v end })
apm:create_checkbox({ title = "Auto Ability", flag = "AutoAbility",
    callback = function(v) getgenv().AutoAbility = v end })
apm:create_checkbox({ title = "Notify", flag = "AutoParryNotify",
    callback = function(v) getgenv().AutoParryNotify = v end })

-- Triggerbot
local tbm = MainTab:create_module({
    title = "Triggerbot", description = "Auto parry when ball targets you",
    flag = "TriggerbotModule", section = "right",
    callback = function(s) System.triggerbot.enable(s) end })
tbm:create_checkbox({ title = "Notify", flag = "TriggerbotNotify",
    callback = function(v) getgenv().TriggerbotNotify = v end })

-- Humanizer
local hm = MainTab:create_module({
    title = "Humanizer", description = "Choose a random parry accuracy range.",
    flag = "HumanizerModule", section = "right",
    callback = function(s)
        if System then System.__properties.__humanizer_enabled = s
            if s and update_randomized_accuracy then pcall(update_randomized_accuracy) end
        end
    end })
hm:create_range_slider({ title = "Humanizer Accuracy", flag = "HumanizerAccuracyRange",
    maximum_value = 50, minimum_value = 1, value = { min = 1, max = 50 }, round_number = true,
    callback = function(mn, mx)
        if System then System.__properties.__humanizer_min_accuracy = mn; System.__properties.__humanizer_max_accuracy = mx end
    end })

-- Manual Spam
local msm = SpamTab:create_module({
    title = "Manual Spam", description = "Spam parries continuously",
    flag = "ManualSpamModule", section = "left",
    callback = function(s)
        System.__properties.__manual_spam_enabled = s
        if s then System.manual_spam.start() else System.manual_spam.stop() end
    end })
msm:create_slider({ title = "CPS", flag = "ManualSpamCPS",
    maximum_value = 200, minimum_value = 1, value = 100, round_number = true,
    callback = function(v) System.__properties.__spam_rate = v end })

-- Auto Spam
local asm = SpamTab:create_module({
    title = "Auto Spam", description = "Automatically spam parries ball",
    flag = "AutoSpamModule", section = "right",
    callback = function(s)
        System.__properties.__auto_spam_enabled = s
        if s then System.auto_spam.start() else System.auto_spam.stop() end
    end })
asm:create_slider({ title = "Parry Threshold", flag = "ParryThreshold",
    maximum_value = 3, minimum_value = 1, value = 1, round_number = true,
    callback = function(v) System.__properties.__spam_threshold = v end })
asm:create_slider({ title = "Distance Multiplier", flag = "DistanceMultiplier",
    maximum_value = 5, minimum_value = 0.5, value = 2, round_number = false,
    callback = function(v) System.__properties.__distance_multiplier = v end })
asm:create_dropdown({ title = "Mode", flag = "AutoSpamMode",
    options = {"Remote", "Keypress"}, maximum_options = 10,
    callback = function(v) getgenv().AutoSpamMode = v end })
asm:create_checkbox({ title = "Animation Fix", flag = "AutoSpamAnimationFix",
    callback = function(v) getgenv().AutoSpamAnimationFix = v end })

-- Detection
local inf = DetTab:create_module({ title = "Infinity Ball", description = "skip parry",
    flag = "InfModule", section = "left",
    callback = function(s) System.__config.__detections.__infinity = s end })
inf:change_state(true)
local ds = DetTab:create_module({ title = "Death Slash", description = "skip parry",
    flag = "DSModule", section = "left",
    callback = function(s) System.__config.__detections.__deathslash = s end })
ds:change_state(true)
local th = DetTab:create_module({ title = "Time Hole", description = "skip parry",
    flag = "THModule", section = "right",
    callback = function(s) System.__config.__detections.__timehole = s end })
th:change_state(true)
local sf = DetTab:create_module({ title = "Slashes of Fury", description = "skip parry",
    flag = "SoFModule", section = "right",
    callback = function(s) System.__config.__detections.__slashesoffury = s end })
sf:change_state(true)

-- SOF Detection
local sdm = DetTab:create_module({
    title = "SOF Detection", description = "Track Slashes of Fury + Auto Parry (multi-target)",
    flag = "SOFDetectModule", section = "left",
    callback = function(s) FuryTracker.__detection_enabled = s end })
sdm:change_state(true)
sdm:create_checkbox({ title = "Auto Parry SOF", flag = "SOFAutoParry",
    callback = function(v) FuryTracker.__auto_parry_enabled = v end })
sdm:create_slider({ title = "Parry Amount", flag = "SOFParryAmount",
    maximum_value = 35, minimum_value = 1, value = 35, round_number = true,
    callback = function(v) FuryTracker.__parry_amount = v end })
sdm:create_slider({ title = "Parry Delay (s)", flag = "SOFParryDelay",
    maximum_value = 0.25, minimum_value = 0.02, value = 0.05, round_number = false,
    callback = function(v) FuryTracker.__parry_delay = v end })
sdm:create_dropdown({ title = "Parry Method", flag = "SOFParryMethod",
    options = {"Remote", "Keypress"}, maximum_options = 2,
    callback = function(v) FuryTracker.__parry_method = v end })

-- Visual
local nr = VisualTab:create_module({ title = "No Render", description = "disable effects",
    flag = "NRModule", section = "left",
    callback = function(s) System.no_render_set(s) end })
local fp = VisualTab:create_module({ title = "FPS Boost", description = "hide shadows + boost",
    flag = "FPSModule", section = "right",
    callback = function(s) System.fps_boost_set(s) end })

-- ═══════════════════════════════════════════════════════════
-- FLOATING BUTTONS
-- ═══════════════════════════════════════════════════════════
local function createFloatingButton(cfg)
    local gui = Instance.new("ScreenGui"); gui.Name = "BlablaFloating_" .. cfg.name
    gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = CoreGui

    local sh = Instance.new("Frame", gui)
    sh.AnchorPoint = Vector2.new(0.5,0.5)
    sh.Position = UDim2.new(cfg.position.X.Scale, cfg.position.X.Offset, cfg.position.Y.Scale, cfg.position.Y.Offset + 4)
    sh.Size = UDim2.fromOffset(150,52); sh.BackgroundColor3 = Color3.new(0,0,0)
    sh.BackgroundTransparency = 0.75; sh.BorderSizePixel = 0; sh.ZIndex = 1
    Instance.new("UICorner", sh).CornerRadius = UDim.new(0,12)

    local btn = Instance.new("TextButton", gui)
    btn.Name = "Button"; btn.AnchorPoint = Vector2.new(0.5,0.5)
    btn.Position = cfg.position; btn.Size = UDim2.fromOffset(150,52)
    btn.BackgroundColor3 = PALETTE.card; btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel = 0; btn.Text = ""; btn.AutoButtonColor = false
    btn.Active = true; btn.ZIndex = 2
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,12)

    local cg = Instance.new("UIGradient", btn)
    cg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40,28,68)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(26,18,46)) }; cg.Rotation = 135

    local s = Instance.new("UIStroke", btn); s.Color = PALETTE.accent
    s.Thickness = 1.5; s.Transparency = 0.5; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Animation.glowPulse(s, 0.5, 0.2, 2)
    Animation.glassHighlight(btn)

    local shim = Instance.new("Frame", btn)
    shim.AnchorPoint = Vector2.new(0.5,0.5); shim.Position = UDim2.new(0.5,0,0.5,0)
    shim.Size = UDim2.new(1,0,1,0); shim.BackgroundColor3 = Color3.fromRGB(255,255,255)
    shim.BorderSizePixel = 0; shim.ZIndex = 5; shim.Active = false
    Instance.new("UICorner", shim).CornerRadius = UDim.new(0,12)
    local shg = Instance.new("UIGradient", shim)
    shg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200,150,255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150,200,255)) }
    shg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00,1), NumberSequenceKeypoint.new(0.42,1),
        NumberSequenceKeypoint.new(0.48,0.12), NumberSequenceKeypoint.new(0.50,0.04),
        NumberSequenceKeypoint.new(0.52,0.12), NumberSequenceKeypoint.new(0.58,1),
        NumberSequenceKeypoint.new(1.00,1) })
    shg.Rotation = 45; shg.Offset = Vector2.new(-1.2,0); shg.Parent = shim
    Animation.shimmer(shg, 1.6, 3.0)

    local dot = Instance.new("Frame", btn); dot.Size = UDim2.fromOffset(10,10)
    dot.Position = UDim2.new(0,14,0.5,-5); dot.BackgroundColor3 = Color3.fromRGB(100,100,120)
    dot.BorderSizePixel = 0; dot.ZIndex = 6
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local ds = Instance.new("UIStroke", dot); ds.Color = PALETTE.accent
    ds.Thickness = 2; ds.Transparency = 0.7; ds.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local ic = Instance.new("TextLabel", btn); ic.BackgroundTransparency = 1
    ic.Size = UDim2.fromOffset(30,30); ic.Position = UDim2.new(0,32,0.5,-15)
    ic.FontFace = FONT.bold; ic.Text = cfg.icon or "F"
    ic.TextColor3 = Color3.fromRGB(255,255,255); ic.TextTransparency = 0.1
    ic.TextSize = 22; ic.TextXAlignment = Enum.TextXAlignment.Left; ic.ZIndex = 6

    local sl = Instance.new("TextLabel", btn); sl.BackgroundTransparency = 1
    sl.Position = UDim2.new(0,72,0.5,-9); sl.Size = UDim2.new(1,-80,0,14)
    sl.FontFace = FONT.semi; sl.Text = cfg.subLabel or "SPAM"
    sl.TextColor3 = PALETTE.text; sl.TextTransparency = 0.05
    sl.TextSize = 13; sl.TextXAlignment = Enum.TextXAlignment.Left; sl.ZIndex = 6

    local stt = Instance.new("TextLabel", btn); stt.BackgroundTransparency = 1
    stt.Position = UDim2.new(0,72,0.5,5); stt.Size = UDim2.new(1,-80,0,12)
    stt.FontFace = FONT.reg; stt.Text = "OFF"
    stt.TextColor3 = PALETTE.textFaint; stt.TextTransparency = 0.3
    stt.TextSize = 10; stt.TextXAlignment = Enum.TextXAlignment.Left; stt.ZIndex = 6

    Animation.ripple(btn, PALETTE.accentHot)

    local ds2 = nil; local sp2 = nil; local dm = false; local tst = 0
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tst = tick(); dm = false; ds2 = input.Position; sp2 = btn.Position
        end
    end)
    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if ds2 and sp2 then
                local delta = input.Position - ds2
                if delta.Magnitude > 5 then
                    dm = true
                    local np = UDim2.new(sp2.X.Scale, sp2.X.Offset + delta.X, sp2.Y.Scale, sp2.Y.Offset + delta.Y)
                    btn.Position = np
                    sh.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 4)
                end
            end
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not dm and tick() - tst < 0.3 then if cfg.onClick then cfg.onClick() end end
            ds2 = nil; sp2 = nil
        end
    end)

    task.spawn(function()
        local last = nil
        while btn.Parent do
            local cur = cfg.getState()
            if cur ~= last then
                last = cur
                if cur then
                    TweenService:Create(btn, Animation.springOut, { BackgroundColor3 = PALETTE.accent }):Play()
                    TweenService:Create(s, Animation.springOut, { Color = PALETTE.accentHot, Transparency = 0.15, Thickness = 2 }):Play()
                    TweenService:Create(dot, Animation.springOut, { BackgroundColor3 = Color3.fromRGB(255,255,255) }):Play()
                    TweenService:Create(ds, Animation.springOut, { Color = Color3.fromRGB(255,255,255), Transparency = 0.3 }):Play()
                    stt.Text = "ON"; stt.TextColor3 = Color3.fromRGB(255,255,255); stt.TextTransparency = 0.15
                    sl.TextColor3 = Color3.fromRGB(255,255,255)
                else
                    TweenService:Create(btn, Animation.smoothOut, { BackgroundColor3 = PALETTE.card }):Play()
                    TweenService:Create(s, Animation.smoothOut, { Color = PALETTE.accent, Transparency = 0.5, Thickness = 1.5 }):Play()
                    TweenService:Create(dot, Animation.smoothOut, { BackgroundColor3 = Color3.fromRGB(100,100,120) }):Play()
                    TweenService:Create(ds, Animation.smoothOut, { Color = PALETTE.accent, Transparency = 0.7 }):Play()
                    stt.Text = "OFF"; stt.TextColor3 = PALETTE.textFaint; stt.TextTransparency = 0.3
                    sl.TextColor3 = PALETTE.text
                end
            end
            task.wait(0.1)
        end
    end)
end

createFloatingButton({
    name = "ManualSpam", icon = "M", subLabel = "MANUAL SPAM",
    position = UDim2.new(0.85, 0, 0.35, 0),
    getState = function() return System.__properties.__manual_spam_enabled end,
    onClick = function()
        System.__properties.__manual_spam_enabled = not System.__properties.__manual_spam_enabled
        if System.__properties.__manual_spam_enabled then System.manual_spam.start() else System.manual_spam.stop() end
    end,
})

createFloatingButton({
    name = "Triggerbot", icon = "T", subLabel = "TRIGGERBOT",
    position = UDim2.new(0.85, 0, 0.35, 60),
    getState = function() return System.triggerbot.__enabled end,
    onClick = function() System.triggerbot.enable(not System.triggerbot.__enabled) end,
})

-- ═══════════════════════════════════════════════════════════
-- SOF INDICATOR
-- ═══════════════════════════════════════════════════════════
local function createSOFIndicator()
    local gui = Instance.new("ScreenGui"); gui.Name = "BlablaSOF"
    gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.DisplayOrder = 996; gui.Parent = CoreGui

    local fr = Instance.new("Frame", gui)
    fr.AnchorPoint = Vector2.new(0,0); fr.Position = UDim2.new(0,20,0,240)
    fr.Size = UDim2.fromOffset(240,34); fr.BackgroundColor3 = PALETTE.bgMain
    fr.BackgroundTransparency = 0.1; fr.BorderSizePixel = 0; fr.Visible = false
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0,10)

    local s = Instance.new("UIStroke", fr); s.Color = Color3.fromRGB(255,130,160)
    s.Thickness = 1.5; s.Transparency = 0.4; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local t = Instance.new("TextLabel", fr); t.BackgroundTransparency = 1
    t.Size = UDim2.new(1,-16,0,12); t.Position = UDim2.new(0,8,0,4)
    t.FontFace = FONT.semi; t.Text = "⚔ SLASHES OF FURY"
    t.TextColor3 = Color3.fromRGB(255,180,200); t.TextXAlignment = Enum.TextXAlignment.Left; t.TextSize = 9

    local b = Instance.new("TextLabel", fr); b.BackgroundTransparency = 1
    b.Size = UDim2.new(1,-16,0,14); b.Position = UDim2.new(0,8,0,16)
    b.FontFace = FONT.bold; b.Text = "—"; b.TextColor3 = PALETTE.text
    b.TextXAlignment = Enum.TextXAlignment.Left; b.TextSize = 12

    local dg, ds, sp
    fr.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dg = true; ds = input.Position; sp = fr.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dg = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dg then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - ds
            fr.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)

    task.spawn(function()
        local last = nil
        while fr.Parent do
            task.wait(0.15)
            local balls = getActiveFuryBalls()
            local targets = getFuryTargets()
            local bc = #balls
            local tc = #targets
            local maxU = 0
            for _, bb in ipairs(balls) do if bb.count > maxU then maxU = bb.count end end

            local txt
            if FuryTracker.__active then
                fr.Visible = true
                txt = "🔴 ACTIVE · " .. bc .. " balls · " .. tc .. " targets · " .. maxU .. "/" .. (FuryTracker.__parry_amount or 35)
                s.Color = Color3.fromRGB(255,80,80); s.Transparency = 0.15
            elseif bc > 0 then
                fr.Visible = true
                txt = "⚔ " .. bc .. " ball(s) · " .. maxU
                s.Color = Color3.fromRGB(255,130,160); s.Transparency = 0.4
            else
                fr.Visible = false; txt = nil
            end

            if txt and txt ~= last then
                last = txt; b.Text = txt
                local scl = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", b)
                scl.Scale = 1.2
                TweenService:Create(scl, Animation.springOut, { Scale = 1 }):Play()
            end
        end
    end)

    return fr
end

createSOFIndicator()

-- ═══════════════════════════════════════════════════════════
-- AUTO START
-- ═══════════════════════════════════════════════════════════
System.__properties.__autoparry_enabled = true
System.__properties.__auto_spam_enabled = true
System.autoparry.start()
System.auto_spam.start()
System.manual_spam.stop()
update_divisor()

task.defer(function()
    task.wait(0.3)
    apm:change_state(true)
    asm:change_state(true)
end)
