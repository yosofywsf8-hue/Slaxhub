-- ============================================================
-- AZURE-STYLE AUTO-PARRY (Standalone, Mobile-Friendly)
-- UI mirip Azure. Isi: parry modules. No dependency.
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")
local Tween      = game:GetService("TweenService")
local CoreGui    = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local IS_MOBILE = UIS.TouchEnabled and not UIS.KeyboardEnabled

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

local function all_balls()
    local t = {}
    local B = WS:FindFirstChild("Balls")
    if not B then return t end
    for _, b in ipairs(B:GetChildren()) do
        if b:GetAttribute("realBall") then table.insert(t, b) end
    end
    return t
end

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    autoparry=false, accuracy=50, divisor=1.0, cooldown=0.4, curveMode=1,
    humanizer=false, hum_min=1, hum_max=50, hum_cur=50, hum_next=0,
    triggerbot=false, tb_busy=false,
    manual_spam=false, spam_cps=20, spam_acc=0,
    auto_spam=false, auto_spam_thresh=1.5,
    det_inf=false, det_death=false, det_time=false, det_slash=false,
    fps_overlay=false, staff_detect=false, notify=true,
    parried=false, parries=0, lastFire=0,
    inf_active=false, death_active=false, time_active=false, slash_active=false,
}

pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, d) CFG.death_active = d or false end)
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b) CFG.inf_active = b or false end)
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("_Index")
    net = net and net:FindFirstChild("sleitnick_net@0.1.0")
    net = net and net:FindFirstChild("net")
    if net then
        local t1 = net:FindFirstChild("RE/TimeHoleActivate")
        local t2 = net:FindFirstChild("RE/TimeHoleDeactivate")
        local s1 = net:FindFirstChild("RE/SlashesOfFuryActivate")
        local s2 = net:FindFirstChild("RE/SlashesOfFuryEnd")
        if t1 then t1.OnClientEvent:Connect(function(p)
            if p==LP or p==LP.Name or (p and p.Name==LP.Name) then CFG.time_active=true end
        end) end
        if t2 then t2.OnClientEvent:Connect(function() CFG.time_active=false end) end
        if s1 then s1.OnClientEvent:Connect(function(p)
            if p==LP or p==LP.Name or (p and p.Name==LP.Name) then CFG.slash_active=true end
        end) end
        if s2 then s2.OnClientEvent:Connect(function() CFG.slash_active=false end) end
    end
end)

-- Humanizer
task.spawn(function()
    while task.wait(0.2) do
        if CFG.humanizer then
            local now = os.clock()
            if now >= CFG.hum_next then
                local lo = math.min(CFG.hum_min, CFG.hum_max)
                local hi = math.max(CFG.hum_min, CFG.hum_max)
                CFG.hum_cur = math.random(lo, hi)
                CFG.hum_next = now + math.random(7, 14) / 10
            end
        end
    end
end)

-- FPS overlay
task.spawn(function()
    local fg, fl, pl
    local function ensure()
        if fg then return end
        fg = Instance.new("ScreenGui", CoreGui)
        fg.Name = "BBFPS"
        fg.ResetOnSpawn = false
        fg.IgnoreGuiInset = true
        local p = Instance.new("Frame", fg)
        p.Size = UDim2.new(0, 140, 0, 50)
        p.Position = UDim2.new(1, -150, 0, 20)
        p.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        p.BorderSizePixel = 0
        local c = Instance.new("UICorner", p)
        c.CornerRadius = UDim.new(0, 8)
        fl = Instance.new("TextLabel", p)
        fl.Size = UDim2.new(1, -10, 0, 20)
        fl.Position = UDim2.new(0, 5, 0, 5)
        fl.BackgroundTransparency = 1
        fl.TextColor3 = Color3.fromRGB(200, 220, 255)
        fl.Font = Enum.Font.Code
        fl.TextSize = 12
        fl.TextXAlignment = Enum.TextXAlignment.Left
        fl.Text = "FPS: --"
        pl = Instance.new("TextLabel", p)
        pl.Size = UDim2.new(1, -10, 0, 20)
        pl.Position = UDim2.new(0, 5, 0, 25)
        pl.BackgroundTransparency = 1
        pl.TextColor3 = Color3.fromRGB(200, 220, 255)
        pl.Font = Enum.Font.Code
        pl.TextSize = 12
        pl.TextXAlignment = Enum.TextXAlignment.Left
        pl.Text = "PING: --"
    end
    local f, e, fps = 0, 0, 0
    RunService.RenderStepped:Connect(function(dt)
        f = f + 1
        e = e + dt
        if e >= 0.5 then
            fps = math.round(f / e)
            f = 0
            e = 0
        end
        if CFG.fps_overlay then
            ensure()
            if fg then fg.Enabled = true end
            if fl then fl.Text = "FPS: " .. fps end
            if pl then
                local p = 0
                pcall(function() p = math.round(LP:GetNetworkPing() * 1000) end)
                pl.Text = "PING: " .. p
            end
        else
            if fg then fg.Enabled = false end
        end
    end)
end)

-- Staff
task.spawn(function()
    local GID, RANK = 12836673, 10
    local seen = {}
    while task.wait(2) do
        if CFG.staff_detect then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and not seen[p.UserId] then
                    local ok, r = pcall(function() return p:GetRankInGroup(GID) end)
                    if ok and type(r)=="number" and r >= RANK then
                        seen[p.UserId] = true
                        print("[BB] STAFF:", p.Name, "rank", r)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- CURVE + EXECUTE
-- ============================================================
local function build_curve()
    local cam = WS.CurrentCamera
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return cam.CFrame end
    local m = CFG.curveMode
    if m == 1 then return cam.CFrame end
    if m == 5 then
        local t = get_closest()
        local tp = t and t.PrimaryPart and t.PrimaryPart.Position or (root.Position + cam.CFrame.LookVector*100)
        return CFrame.new(root.Position, tp + Vector3.new(0, 9e18, 0))
    end
    if m == 6 then
        local t = get_closest()
        local tp = t and t.PrimaryPart and t.PrimaryPart.Position or (root.Position + cam.CFrame.LookVector*100)
        return CFrame.new(root.Position, tp + Vector3.new(0, -9e18, 0))
    end
    if m == 7 then return CFrame.new(root.Position, root.Position - cam.CFrame.RightVector*10000) end
    if m == 8 then return CFrame.new(root.Position, root.Position + cam.CFrame.RightVector*10000) end
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
    return fire_parry(build_curve(), sp, ml)
end

-- Autoparry loop
RunService.PreSimulation:Connect(function()
    if not CFG.autoparry or CFG.triggerbot or CFG.parried then return end
    if tick() - CFG.lastFire < CFG.cooldown then return end
    if not _PARRY_PATCH.ready then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    for _, b in ipairs(all_balls()) do
        local z = b:FindFirstChild("zoomies")
        if not z then continue end
        if b:GetAttribute("target") ~= LP.Name then continue end
        if CFG.det_inf and CFG.inf_active then continue end
        if CFG.det_death and CFG.death_active then continue end
        if CFG.det_time and CFG.time_active then continue end
        if CFG.det_slash and CFG.slash_active then continue end
        local sp = z.VectorVelocity.Magnitude
        local d = (LP.Character.PrimaryPart.Position - b.Position).Magnitude
        local ping = 0
        pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()/10 end)
        local pt = math.clamp(ping/10, 5, 17)
        local cs = math.min(math.max(sp-9.5, 0), 650)
        local sd = (2.4 + cs*0.002) * CFG.divisor
        local acc = pt + math.max(sp/sd, 9.5)
        acc = acc * ((CFG.humanizer and CFG.hum_cur or CFG.accuracy)/50)
        if d <= acc then
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

-- Triggerbot
RunService.Heartbeat:Connect(function()
    if not CFG.triggerbot or CFG.tb_busy then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    for _, b in ipairs(all_balls()) do
        if b:GetAttribute("target") == LP.Name then
            CFG.tb_busy = true
            execute_parry()
            task.delay(0.5, function() CFG.tb_busy = false end)
            break
        end
    end
end)

-- Manual spam
RunService.Heartbeat:Connect(function(dt)
    if not CFG.manual_spam then return end
    CFG.spam_acc = CFG.spam_acc + dt
    local cps = math.max(CFG.spam_cps, 1)
    if CFG.spam_acc < 1/cps then return end
    CFG.spam_acc = 0
    execute_parry()
end)

-- Auto spam
RunService.PreSimulation:Connect(function()
    if not CFG.auto_spam or CFG.slash_active then return end
    for _, b in ipairs(all_balls()) do
        if b:GetAttribute("target") ~= LP.Name then continue end
        local z = b:FindFirstChild("zoomies")
        if not z or z.VectorVelocity.Magnitude == 0 then continue end
        if LP:DistanceFromCharacter(b.Position) <= 15 and CFG.parries > CFG.auto_spam_thresh then
            execute_parry()
        end
        break
    end
end)

-- ============================================================
-- UI (Azure-style, mobile-friendly)
-- ============================================================
local function mk(c, p, ch)
    local o = Instance.new(c)
    for k, v in pairs(p or {}) do o[k] = v end
    for _, x in ipairs(ch or {}) do x.Parent = o end
    return o
end

local parentGui = nil
if type(gethui) == "function" then local ok, h = pcall(gethui) if ok and h then parentGui = h end end
if not parentGui then
    local ok = pcall(function() local t = Instance.new("Folder") t.Parent = CoreGui t:Destroy() end)
    parentGui = ok and CoreGui or LP:WaitForChild("PlayerGui")
end

local gui = mk("ScreenGui", { Name="AzureParry", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=999, ZIndexBehavior=Enum.ZIndexBehavior.Sibling }, {})
gui.Parent = parentGui

local W = IS_MOBILE and 360 or 500
local H = IS_MOBILE and 500 or 460

local Container = mk("Frame", {
    Size = UDim2.new(0, W, 0, H),
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

-- gradient side
local side = mk("Frame", {
    Size = UDim2.new(0, 6, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(55, 110, 190),
    BorderSizePixel = 0,
}, {})
side.Parent = Container
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, {}).Parent = side
local sideGrad = mk("UIGradient", { Rotation = 90 }, {})
sideGrad.Parent = side
sideGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30,30,34)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(55,110,190)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(110,80,200)),
}

-- header
local Header = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
}, {})
Header.Parent = Container

mk("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.new(0, 18, 0, 0),
    BackgroundTransparency = 1,
    Text = "AZURE | AUTO-PARRY",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = Header

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(1, -34, 0, 9),
    BackgroundColor3 = Color3.fromRGB(60, 60, 70),
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
closeBtn.Parent = Header
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, {}).Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- drag
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, Container.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - dragStart
        Container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- divider
mk("Frame", {
    Size = UDim2.new(1, -20, 0, 1),
    Position = UDim2.new(0, 10, 0, 44),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.85,
    BorderSizePixel = 0,
}, {}).Parent = Container

-- scroll content
local content = mk("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -100),
    Position = UDim2.new(0, 10, 0, 54),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(120, 160, 220),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {})
content.Parent = Container
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, {}).Parent = content

-- status bar
local status = mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 34),
    Position = UDim2.new(0, 10, 1, -42),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    Text = "ready: N | parries: 0",
    TextColor3 = Color3.fromRGB(180, 220, 180),
    Font = Enum.Font.Code,
    TextSize = 11,
    BorderSizePixel = 0,
}, {})
status.Parent = Container
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = status

task.spawn(function()
    while gui.Parent do
        status.Text = string.format("ready:%s parries:%d", _PARRY_PATCH.ready and "Y" or "N", CFG.parries)
        status.TextColor3 = _PARRY_PATCH.ready and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(220, 180, 80)
        task.wait(0.3)
    end
end)

-- ============================================================
-- WIDGETS
-- ============================================================
local order = 0
local function nextOrder() order = order + 1 return order end

local function addToggle(label, key, cb)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, {})
    row.Parent = content
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = row
    mk("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.8, Thickness = 1 }, {}).Parent = row

    mk("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 230),
        Font = Enum.Font.GothamSemiBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {}).Parent = row

    local tg = mk("Frame", {
        Size = UDim2.new(0, 28, 0, 14),
        Position = UDim2.new(1, -42, 0.5, -7),
        BackgroundColor3 = CFG[key] and Color3.fromRGB(205,205,220) or Color3.fromRGB(44,44,52),
        BorderSizePixel = 0,
    }, {})
    tg.Parent = row
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = tg

    local circle = mk("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = CFG[key] and UDim2.new(0, 15, 0, 1) or UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = CFG[key] and Color3.fromRGB(245,245,250) or Color3.fromRGB(120,120,132),
        BorderSizePixel = 0,
    }, {})
    circle.Parent = tg
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = circle

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, {})
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        Tween:Create(tg, TweenInfo.new(0.2), {
            BackgroundColor3 = CFG[key] and Color3.fromRGB(205,205,220) or Color3.fromRGB(44,44,52)
        }):Play()
        Tween:Create(circle, TweenInfo.new(0.2), {
            Position = CFG[key] and UDim2.new(0, 15, 0, 1) or UDim2.new(0, 1, 0, 1),
            BackgroundColor3 = CFG[key] and Color3.fromRGB(245,245,250) or Color3.fromRGB(120,120,132),
        }):Play()
        if cb then cb(CFG[key]) end
    end)
end

local function addSlider(label, key, min, max, step, cb)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, {})
    row.Parent = content
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = row
    mk("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.8, Thickness = 1 }, {}).Parent = row

    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -28, 0, 18),
        Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1,
        Text = string.format("%s: %.2f", label, CFG[key]),
        TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.GothamSemiBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {})
    lbl.Parent = row

    local track = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 6),
        Position = UDim2.new(0, 14, 0, 32),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        BorderSizePixel = 0,
    }, {})
    track.Parent = row
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = track

    local fill = mk("Frame", {
        Size = UDim2.new((CFG[key] - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(120, 170, 240),
        BorderSizePixel = 0,
    }, {})
    fill.Parent = track
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = fill

    local dragging_ = false
    local function upd(i)
        local x = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * x
        v = math.floor(v / step + 0.5) * step
        CFG[key] = v
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        lbl.Text = string.format("%s: %.2f", label, v)
        if cb then cb(v) end
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging_ = true
            upd(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging_ then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            upd(i)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging_ = false
        end
    end)
end

-- ============================================================
-- BUILD UI ELEMENTS
-- ============================================================
addToggle("Auto Parry",   "autoparry")
addToggle("Triggerbot",   "triggerbot")
addToggle("Manual Spam",  "manual_spam")
addToggle("Auto Spam",    "auto_spam")
addToggle("Humanizer",    "humanizer")
addToggle("Detect Infinity",  "det_inf")
addToggle("Detect Death Slash", "det_death")
addToggle("Detect Time Hole", "det_time")
addToggle("Detect Slashes",   "det_slash")
addToggle("FPS + Ping Overlay","fps_overlay")
addToggle("Staff Detection",  "staff_detect")

addSlider("Accuracy",   "accuracy",    1, 50, 1, nil)
addSlider("Divisor",    "divisor",     0.5, 2.0, 0.05, nil)
addSlider("Cooldown",   "cooldown",    0.1, 1.0, 0.05, nil)
addSlider("Spam CPS",   "spam_cps",    5, 100, 1, nil)

print("[AZURE-PARRY] loaded | executor:", type(identifyexecutor)=="function" and select(1, identifyexecutor()) or "?")
