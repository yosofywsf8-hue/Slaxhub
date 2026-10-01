-- ============================================================
-- Blade Ball — AZURE UI + AUTO-PARRY MODULES
-- Framework UI diadaptasi dari Azure (Library/Tab/Module)
-- Isi: AutoParry + Triggerbot + Spam + Detection + Misc
-- Semua fitur yang butuh dependency berat (Emote/Skin/Shop) dihapus.
-- ============================================================

-- ============================================================
-- BOOT
-- ============================================================
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")
local Tween      = game:GetService("TweenService")
local HttpService= game:GetService("HttpService")
local CoreGui    = game:GetService("CoreGui")
local TextService= game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")

local LP = Players.LocalPlayer
local IS_MOBILE = UIS.TouchEnabled and not UIS.KeyboardEnabled

local function cloneref(o) return o end

-- ============================================================
-- PARRY PATCH
-- ============================================================
local _PARRY_PATCH = { keyTable=nil, transformFn=nil, parryHash=nil, parryRemote=nil, ready=false }

task.spawn(function()
    pcall(function()
        local C = RS:WaitForChild("Controllers", 20)
        if not C then return end
        local SC
        for _, ch in ipairs(C:GetChildren()) do
            if ch.Name:sub(1,16) == "SwordsController" then SC = ch break end
        end
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 20)
        if not PRY then return end
        local PF = require(PRY)
        local guv = (type(debug)=="table" and debug.getupvalues) or getupvalues
        if not guv then return end
        local ups = guv(PF)
        if not ups or #ups < 8 then return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        print("[BB] patch loaded")
    end)
end)

local _reverted = {}
local function _valid(a)
    return #a==8 and type(a[2])=="string" and type(a[3])=="string" and type(a[4])=="number"
        and typeof(a[5])=="CFrame" and type(a[6])=="table" and type(a[7])=="table" and type(a[8])=="boolean"
end
local function _hook(r)
    if _reverted[r] then return end
    local mt = getrawmetatable(r)
    if not mt or mt.__bb then return end
    pcall(function()
        setreadonly(mt, false)
        local old = mt.__index
        mt.__index = function(self, k)
            if (k=="FireServer" and self:IsA("RemoteEvent")) or (k=="InvokeServer" and self:IsA("RemoteFunction")) then
                return function(_, ...)
                    local args = {...}
                    if _valid(args) and not _reverted[self] then
                        _reverted[self] = args
                        _PARRY_PATCH.ready = true
                        _PARRY_PATCH.parryRemote = self
                        print("[BB] remote matched:", self:GetFullName())
                    end
                    return old(self, k)(_, unpack(args))
                end
            end
            return old(self, k)
        end
        mt.__bb = true
        setreadonly(mt, true)
    end)
end
task.spawn(function()
    for _, r in ipairs(RS:GetDescendants()) do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then pcall(_hook, r) end
    end
end)

local function fire_parry(curveCF, sp, ml)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local ck = kt[2] and kt[2][kt[1]]
    if not ck then return false end
    local ok, tr = pcall(_PARRY_PATCH.transformFn, ck, "TIME")
    if not ok or not tr then ok, tr = pcall(_PARRY_PATCH.transformFn, ck) end
    if not ok or not tr then return false end
    local ts = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local tc = {}
    for i=1,#ts do
        local kb = string.byte(tr, (i-1) % #tr + 1)
        local tb = (string.byte(ts, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    return pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(_PARRY_PATCH.parryHash, ck, table.concat(tc), 0.5, curveCF, sp, ml, false)
    end)
end

-- ============================================================
-- HELPERS
-- ============================================================
local function get_ball()
    local B = WS:FindFirstChild("Balls")
    if not B then return nil end
    for _, b in ipairs(B:GetChildren()) do
        if b:GetAttribute("realBall") then b.CanCollide = false return b end
    end
    return nil
end

local function get_all_balls()
    local t = {}
    local B = WS:FindFirstChild("Balls")
    if not B then return t end
    for _, b in ipairs(B:GetChildren()) do
        if b:GetAttribute("realBall") then table.insert(t, b) end
    end
    return t
end

local Alive = WS:FindFirstChild("Alive")
local function get_closest()
    if not Alive or not LP.Character or not LP.Character.PrimaryPart then return nil end
    local best, bd = nil, math.huge
    for _, e in ipairs(Alive:GetChildren()) do
        if e ~= LP.Character and e.PrimaryPart then
            local d = LP:DistanceFromCharacter(e.PrimaryPart.Position)
            if d < bd then bd, best = d, e end
        end
    end
    return best
end

-- ============================================================
-- CONFIG GLOBAL
-- ============================================================
local CFG = {
    autoparry_enabled = false,
    accuracy = 50,
    divisor = 1.0,
    speedFactor = 0.002,
    baseDivisor = 2.4,
    cooldown = 0.4,
    curveMode = 1,
    curveNames = {"Camera","Random","Accelerated","Backwards","Slow","High","Left","Right"},
    humanizer_enabled = false,
    humanizer_min = 1,
    humanizer_max = 50,
    triggerbot_enabled = false,
    manual_spam_enabled = false,
    manual_spam_cps = 20,
    manual_spam_use_cps = false,
    auto_spam_enabled = false,
    auto_spam_threshold = 1.5,
    det_infinity = false,
    det_deathslash = false,
    det_timehole = false,
    det_slashes = false,
    det_phantom = false,
    det_dribble = false,
    cooldown_protection = false,
    auto_ability = false,
    fps_overlay = false,
    staff_detect = false,
    notify_enabled = true,
    -- state
    parried = false, parries = 0, lastFire = 0,
    current_accuracy = 50, humanizer_next = 0,
    infinity_active = false, deathslash_active = false, timehole_active = false, slashes_active = false,
    tb_parrying = false, spam_acc = 0,
}

pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, d) CFG.deathslash_active = d or false end)
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b) CFG.infinity_active = b or false end)
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("_Index")
    net = net and net:FindFirstChild("sleitnick_net@0.1.0")
    net = net and net:FindFirstChild("net")
    if net then
        local thOn = net:FindFirstChild("RE/TimeHoleActivate")
        local thOff = net:FindFirstChild("RE/TimeHoleDeactivate")
        local sfOn = net:FindFirstChild("RE/SlashesOfFuryActivate")
        local sfEnd = net:FindFirstChild("RE/SlashesOfFuryEnd")
        if thOn then thOn.OnClientEvent:Connect(function(p)
            if p == LP or p == LP.Name or (p and p.Name == LP.Name) then CFG.timehole_active = true end
        end) end
        if thOff then thOff.OnClientEvent:Connect(function() CFG.timehole_active = false end) end
        if sfOn then sfOn.OnClientEvent:Connect(function(p)
            if p == LP or p == LP.Name or (p and p.Name == LP.Name) then CFG.slashes_active = true end
        end) end
        if sfEnd then sfEnd.OnClientEvent:Connect(function() CFG.slashes_active = false end) end
    end
end)

-- Humanizer
task.spawn(function()
    while task.wait(0.2) do
        if CFG.humanizer_enabled then
            local now = os.clock()
            if now >= CFG.humanizer_next then
                local lo = math.min(CFG.humanizer_min, CFG.humanizer_max)
                local hi = math.max(CFG.humanizer_min, CFG.humanizer_max)
                CFG.current_accuracy = math.random(lo, hi)
                CFG.humanizer_next = now + math.random(7, 14) / 10
            end
        else
            CFG.current_accuracy = CFG.accuracy
        end
    end
end)

local function build_curve_cframe()
    local cam = WS.CurrentCamera
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return cam.CFrame end
    local mode = CFG.curveMode
    if mode == 1 then return cam.CFrame end
    if mode == 5 then
        local t = get_closest()
        local tp = t and t.PrimaryPart and t.PrimaryPart.Position or (root.Position + cam.CFrame.LookVector * 100)
        return CFrame.new(root.Position, tp + Vector3.new(0, 9e18, 0))
    end
    if mode == 6 then
        local t = get_closest()
        local tp = t and t.PrimaryPart and t.PrimaryPart.Position or (root.Position + cam.CFrame.LookVector * 100)
        return CFrame.new(root.Position, tp + Vector3.new(0, -9e18, 0))
    end
    if mode == 7 then return CFrame.new(root.Position, root.Position - cam.CFrame.RightVector * 10000) end
    if mode == 8 then return CFrame.new(root.Position, root.Position + cam.CFrame.RightVector * 10000) end
    return cam.CFrame
end

local function execute_parry()
    local cam = WS.CurrentCamera
    if not LP.Character then return false end
    local sp = {}
    if Alive then
        for _, e in ipairs(Alive:GetChildren()) do
            if e.PrimaryPart then
                local ok, s = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok then sp[e.Name] = s end
            end
        end
    end
    local ml = {cam.ViewportSize.X/2, cam.ViewportSize.Y/2}
    if not IS_MOBILE then
        local ok, m = pcall(function() return UIS:GetMouseLocation() end)
        if ok and m then ml = {m.X, m.Y} end
    end
    return fire_parry(build_curve_cframe(), sp, ml)
end

-- ============================================================
-- LOOPS
-- ============================================================
RunService.PreSimulation:Connect(function()
    if not CFG.autoparry_enabled then return end
    if CFG.triggerbot_enabled then return end
    if CFG.parried then return end
    if tick() - CFG.lastFire < CFG.cooldown then return end
    if not _PARRY_PATCH.ready then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    for _, ball in ipairs(get_all_balls()) do
        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        if ball:GetAttribute("target") ~= LP.Name then continue end
        if CFG.det_infinity and CFG.infinity_active then continue end
        if CFG.det_deathslash and CFG.deathslash_active then continue end
        if CFG.det_timehole and CFG.timehole_active then continue end
        if CFG.det_slashes and CFG.slashes_active then continue end
        local speed = z.VectorVelocity.Magnitude
        local dist = (LP.Character.PrimaryPart.Position - ball.Position).Magnitude
        local ping = 0
        pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10 end)
        local pt = math.clamp(ping/10, 5, 17)
        local cs = math.min(math.max(speed - 9.5, 0), 650)
        local sd = (CFG.baseDivisor + cs * CFG.speedFactor) * CFG.divisor
        local acc = pt + math.max(speed/sd, 9.5)
        acc = acc * ((CFG.humanizer_enabled and CFG.current_accuracy or CFG.accuracy) / 50)
        if dist <= acc then
            if execute_parry() then
                CFG.parried = true
                CFG.parries = CFG.parries + 1
                CFG.lastFire = tick()
                task.delay(CFG.cooldown, function() CFG.parried = false end)
            end
            break
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not CFG.triggerbot_enabled or CFG.tb_parrying then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    if LP.Character.PrimaryPart:FindFirstChild("SingularityCape") then return end
    for _, ball in ipairs(get_all_balls()) do
        if ball:GetAttribute("target") == LP.Name then
            CFG.tb_parrying = true
            execute_parry()
            task.delay(0.5, function() CFG.tb_parrying = false end)
            break
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not CFG.manual_spam_enabled then return end
    CFG.spam_acc = CFG.spam_acc + dt
    local cps = CFG.manual_spam_use_cps and CFG.manual_spam_cps or 100
    if cps < 1 then cps = 1 end
    if CFG.spam_acc < 1/cps then return end
    CFG.spam_acc = 0
    execute_parry()
end)

RunService.PreSimulation:Connect(function()
    if not CFG.auto_spam_enabled then return end
    if CFG.slashes_active then return end
    local ball = get_ball()
    if not ball then return end
    if ball:GetAttribute("target") ~= LP.Name then return end
    local z = ball:FindFirstChild("zoomies")
    if not z or z.VectorVelocity.Magnitude == 0 then return end
    local dist = LP:DistanceFromCharacter(ball.Position)
    if dist <= 15 and CFG.parries > CFG.auto_spam_threshold then
        execute_parry()
    end
end)

-- Staff detect
task.spawn(function()
    local GROUP_ID = 12836673
    local MIN_RANK = 10
    local detected = {}
    while task.wait(2) do
        if CFG.staff_detect then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and not detected[p.UserId] then
                    local ok, r = pcall(function() return p:GetRankInGroup(GROUP_ID) end)
                    if ok and type(r) == "number" and r >= MIN_RANK then
                        detected[p.UserId] = true
                        print("[BB] STAFF:", p.Name, "rank", r)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- AZURE UI FRAMEWORK (diadaptasi)
-- ============================================================
local function mk(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end

local par = nil
if type(gethui) == "function" then local ok, h = pcall(gethui) if ok and h then par = h end end
if not par then
    local ok = pcall(function() local t = Instance.new("Folder") t.Parent = CoreGui t:Destroy() end)
    par = ok and CoreGui or LP:WaitForChild("PlayerGui")
end

local gui = mk("ScreenGui", {
    Name = "Azure",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
}, {})
gui.Parent = par

-- Container Azure-style
local Container = mk("Frame", {
    Name = "Container",
    Size = IS_MOBILE and UDim2.new(0, 360, 0, 540) or UDim2.new(0, 750, 0, 530),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(28, 28, 34),
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
}, {})
Container.Parent = gui
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, {}).Parent = Container
mk("UIStroke", { Color = Color3.fromRGB(78, 92, 122), Thickness = 1, Transparency = 0.28 }, {}).Parent = Container

-- Gradient side
local side = mk("Frame", {
    Name = "GradientSide",
    Size = UDim2.new(0, 8, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(55, 110, 190),
    BorderSizePixel = 0,
}, {})
side.Parent = Container
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, {}).Parent = side

local Handler = mk("Frame", {
    Name = "Handler",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, {})
Handler.Parent = Container

-- Header
mk("TextLabel", {
    Size = UDim2.new(0, 200, 0, 24),
    Position = UDim2.new(0, 20, 0, 14),
    BackgroundTransparency = 1,
    Text = "RAYYY HUB",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = Handler

-- Divider vertical
local Divider = mk("Frame", {
    Position = UDim2.new(0, 0.225 * 750 / (IS_MOBILE and 360 or 750), 0, 68),
    Size = UDim2.new(0, 1, 1, -80),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
}, {})
Divider.Parent = Handler

-- Tabs (sidebar)
local Tabs = mk("ScrollingFrame", {
    Name = "Tabs",
    Size = UDim2.new(0, 140, 1, -80),
    Position = UDim2.new(0, 20, 0, 50),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {})
Tabs.Parent = Handler
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, {}).Parent = Tabs

-- Sections
local Sections = mk("Folder", { Name = "Sections" }, {})
Sections.Parent = Handler

-- ============================================================
-- AZURE-STYLE MODULE BUILDER
-- ============================================================
local function create_tab(title, order)
    local TabBtn = mk("TextButton", {
        Size = UDim2.new(0, 129, 0, 38),
        BackgroundColor3 = Color3.fromRGB(32, 32, 42),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, {})
    TabBtn.Parent = Tabs
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = TabBtn

    mk("TextLabel", {
        Name = "TextLabel",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0.5,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {}).Parent = TabBtn

    local LeftSection = mk("ScrollingFrame", {
        Name = "Left_" .. title,
        Size = UDim2.new(0, 243, 1, -80),
        Position = UDim2.new(0.28, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, {})
    LeftSection.Parent = Sections
    mk("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, {}).Parent = LeftSection

    local RightSection = mk("ScrollingFrame", {
        Name = "Right_" .. title,
        Size = UDim2.new(0, 243, 1, -80),
        Position = UDim2.new(0.64, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, {})
    RightSection.Parent = Sections
    mk("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, {}).Parent = RightSection

    local TabManager = { Left = LeftSection, Right = RightSection, Btn = TabBtn }

    TabBtn.MouseButton1Click:Connect(function()
        for _, obj in ipairs(Tabs:GetChildren()) do
            if obj:IsA("TextButton") then
                Tween:Create(obj, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            end
        end
        Tween:Create(TabBtn, TweenInfo.new(0.3), { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(220, 220, 220) }):Play()
        for _, s in ipairs(Sections:GetChildren()) do
            s.Visible = (s == LeftSection or s == RightSection)
        end
    end)

    return TabManager
end

local function create_module(section, settings)
    local Module = mk("Frame", {
        Name = settings.title or "Module",
        Size = UDim2.new(0, 241, 0, 93),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(16, 17, 22),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, {})
    Module.Parent = section
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = Module
    mk("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.72, Thickness = 1 }, {}).Parent = Module
    mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, {}).Parent = Module

    local Header = mk("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 93),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, {})
    Header.Parent = Module

    mk("TextLabel", {
        Size = UDim2.new(1, -30, 0, 14),
        Position = UDim2.new(0, 18, 0, 14),
        BackgroundTransparency = 1,
        Text = settings.title or "Module",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0.2,
        Font = Enum.Font.GothamSemiBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {}).Parent = Header

    mk("TextLabel", {
        Size = UDim2.new(1, -30, 0, 12),
        Position = UDim2.new(0, 18, 0, 32),
        BackgroundTransparency = 1,
        Text = settings.description or "",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextTransparency = 0.7,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {}).Parent = Header

    local Toggle = mk("Frame", {
        Name = "Toggle",
        Size = UDim2.new(0, 25, 0, 12),
        Position = UDim2.new(1, -35, 0, 66),
        BackgroundColor3 = Color3.fromRGB(44, 44, 52),
        BorderSizePixel = 0,
    }, {})
    Toggle.Parent = Header
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = Toggle

    local Circle = mk("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(120, 120, 132),
        BorderSizePixel = 0,
    }, {})
    Circle.Parent = Toggle
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = Circle

    local Options = mk("Frame", {
        Name = "Options",
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 0, 93),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {})
    Options.Parent = Module
    mk("UIPadding", { PaddingTop = UDim.new(0, 8) }, {}).Parent = Options
    mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, {}).Parent = Options

    local ModMgr = { state = false, size = 0, module = Module, options = Options }

    function ModMgr:set(state)
        self.state = state
        Tween:Create(Module, TweenInfo.new(0.3), { Size = UDim2.fromOffset(241, 93 + self.size) }):Play()
        Tween:Create(Toggle, TweenInfo.new(0.3), {
            BackgroundColor3 = state and Color3.fromRGB(205, 205, 220) or Color3.fromRGB(44, 44, 52),
        }):Play()
        Tween:Create(Circle, TweenInfo.new(0.3), {
            BackgroundColor3 = state and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(120, 120, 132),
            Position = state and UDim2.fromScale(0.53, 0.5) or UDim2.new(0, 0, 0.5, -6),
        }):Play()
        if settings.callback then settings.callback(state) end
    end

    Header.MouseButton1Click:Connect(function() ModMgr:set(not ModMgr.state) end)

    function ModMgr:checkbox(s)
        self.size = self.size + 20
        Options.Size = UDim2.fromOffset(241, self.size)
        if self.state then Module.Size = UDim2.fromOffset(241, 93 + self.size) end
        local cb = mk("TextButton", {
            Size = UDim2.new(0, 207, 0, 18),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, {})
        cb.Parent = Options
        mk("TextLabel", {
            Size = UDim2.new(0, 160, 1, 0),
            BackgroundTransparency = 1,
            Text = s.title or "",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextTransparency = 0.2,
            Font = Enum.Font.GothamSemiBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, {}).Parent = cb
        local box = mk("Frame", {
            Size = UDim2.new(0, 15, 0, 15),
            Position = UDim2.new(1, -15, 0.5, -7.5),
            BackgroundColor3 = Color3.fromRGB(245, 245, 250),
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
        }, {})
        box.Parent = cb
        mk("UICorner", { CornerRadius = UDim.new(0, 7) }, {}).Parent = box
        local fill = mk("Frame", {
            Size = UDim2.fromOffset(0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(245, 245, 250),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
        }, {})
        fill.Parent = box
        mk("UICorner", { CornerRadius = UDim.new(0, 6) }, {}).Parent = fill
        local st = { state = false }
        function st:set(v)
            self.state = v
            Tween:Create(fill, TweenInfo.new(0.3), { Size = v and UDim2.fromOffset(9, 9) or UDim2.fromOffset(0, 0) }):Play()
            Tween:Create(box, TweenInfo.new(0.3), { BackgroundTransparency = v and 0.7 or 0.9 }):Play()
            if s.callback then s.callback(v) end
        end
        cb.MouseButton1Click:Connect(function() st:set(not st.state) end)
        return st
    end

    function ModMgr:slider(s)
        self.size = self.size + 34
        Options.Size = UDim2.fromOffset(241, self.size)
        if self.state then Module.Size = UDim2.fromOffset(241, 93 + self.size) end
        local row = mk("Frame", {
            Size = UDim2.new(0, 207, 0, 22),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, {})
        row.Parent = Options
        local lbl = mk("TextLabel", {
            Size = UDim2.new(0, 153, 0, 13),
            BackgroundTransparency = 1,
            Text = s.title or "",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextTransparency = 0.2,
            Font = Enum.Font.GothamSemiBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, {})
        lbl.Parent = row
        local val = mk("TextLabel", {
            Size = UDim2.new(0, 42, 0, 13),
            Position = UDim2.new(1, -42, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(s.value),
            TextColor3 = Color3.fromRGB(255, 255, 255
