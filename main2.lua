-- ============================================================
-- Blade Ball — AUTO-PARRY FULL (MOBILE)
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")

local LP = Players.LocalPlayer
local IS_MOBILE = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- PARRY PATCH
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

-- HOOK
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

-- FIRE
local function fire_parry(curveCF, sp, ml)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local ki = kt[1]
    local ck = kt[2] and kt[2][ki]
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
    local token = table.concat(tc)
    return pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(_PARRY_PATCH.parryHash, ck, token, 0.5, curveCF, sp, ml, false)
    end)
end

-- BALL
local function get_ball()
    local B = WS:FindFirstChild("Balls")
    if not B then return nil end
    for _, b in ipairs(B:GetChildren()) do
        if b:GetAttribute("realBall") then b.CanCollide = false return b end
    end
    return nil
end

-- LOOP
local CFG = { enabled=false, accuracy=1.0, divisor=1.0, speedFactor=0.002, baseDivisor=2.4, cooldown=0.4 }
local St = { parried=false, parries=0, lastFire=0 }

local function execute()
    local cam = WS.CurrentCamera
    if not LP.Character then return false end
    local sp = {}
    local alive = WS:FindFirstChild("Alive")
    if alive then
        for _, e in ipairs(alive:GetChildren()) do
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
    return fire_parry(cam.CFrame, sp, ml)
end

RunService.PreSimulation:Connect(function()
    if not CFG.enabled or St.parried then return end
    if tick() - St.lastFire < CFG.cooldown then return end
    if not _PARRY_PATCH.ready then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    local ball = get_ball()
    if not ball then return end
    local z = ball:FindFirstChild("zoomies")
    if not z then return end
    if ball:GetAttribute("target") ~= LP.Name then return end
    local speed = z.VectorVelocity.Magnitude
    local dist = (LP.Character.PrimaryPart.Position - ball.Position).Magnitude
    local ping = 0
    pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10 end)
    local pt = math.clamp(ping/10, 5, 17)
    local cs = math.min(math.max(speed - 9.5, 0), 650)
    local sd = (CFG.baseDivisor + cs * CFG.speedFactor) * CFG.divisor
    local acc = (pt + math.max(speed/sd, 9.5)) * CFG.accuracy
    if dist <= acc then
        if execute() then
            St.parried = true
            St.parries = St.parries + 1
            St.lastFire = tick()
            task.delay(CFG.cooldown, function() St.parried = false end)
        end
    end
end)

-- ============================================================
-- UI MOBILE (touch-friendly, tombol gedhe)
-- ============================================================
local function mk(c, p, ch)
    local o = Instance.new(c)
    for k, v in pairs(p or {}) do o[k] = v end
    for _, x in ipairs(ch or {}) do x.Parent = o end
    return o
end

local par = nil
if type(gethui) == "function" then local ok, h = pcall(gethui) if ok and h then par = h end end
if not par then
    local cg = game:GetService("CoreGui")
    local ok = pcall(function() local t = Instance.new("Folder") t.Parent = cg t:Destroy() end)
    par = ok and cg or LP:WaitForChild("PlayerGui")
end

local gui = mk("ScreenGui", {
    Name = "BBParryMobile",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 9999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, {})
gui.Parent = par

-- Frame lebih compact buat HP, posisi kiri-atas biar nggak nutupin game
local main = mk("Frame", {
    Size = UDim2.new(0, 220, 0, 150),
    Position = UDim2.new(0, 20, 0, 80),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Active = true,
}, {})
main.Parent = gui
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, {}).Parent = main
mk("UIStroke", { Color = Color3.fromRGB(255, 90, 90), Thickness = 2 }, {}).Parent = main

-- Title bar (drag pakai touch)
local title = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(30, 30, 38),
    BorderSizePixel = 0,
}, {})
title.Parent = main
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, {}).Parent = title
mk("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Color3.fromRGB(30, 30, 38),
    BorderSizePixel = 0,
}, {}).Parent = title

local titleLbl = mk("TextLabel", {
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "AUTO-PARRY",
    TextColor3 = Color3.fromRGB(255, 90, 90),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {})
titleLbl.Parent = title

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -32, 0, 3),
    BackgroundColor3 = Color3.fromRGB(60, 40, 40),
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 200, 200),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
closeBtn.Parent = title
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- DRAG pakai touch
local dragging = false
local dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- TOGGLE gedhe
local tgl = mk("TextButton", {
    Size = UDim2.new(1, -20, 0, 46),
    Position = UDim2.new(0, 10, 0, 42),
    BackgroundColor3 = Color3.fromRGB(200, 80, 80),
    Text = "OFF",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
tgl.Parent = main
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, {}).Parent = tgl

tgl.MouseButton1Click:Connect(function()
    CFG.enabled = not CFG.enabled
    tgl.Text = CFG.enabled and "ON" or "OFF"
    tgl.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
end)

-- Status kecil
local stat = mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 96),
    BackgroundColor3 = Color3.fromRGB(24, 24, 30),
    Text = "loading...",
    TextColor3 = Color3.fromRGB(180, 220, 180),
    Font = Enum.Font.Code,
    TextSize = 10,
    BorderSizePixel = 0,
}, {})
stat.Parent = main
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, {}).Parent = stat

task.spawn(function()
    while gui.Parent do
        stat.Text = string.format("ready:%s parries:%d", _PARRY_PATCH.ready and "Y" or "N", St.parries)
        stat.TextColor3 = _PARRY_PATCH.ready and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(220, 180, 80)
        task.wait(0.3)
    end
end)

-- ============================================================
-- FLOATING QUICK-TOGGLE BUTTON (buat mobile, di samping layar)
-- ============================================================
local quick = mk("TextButton", {
    Size = UDim2.new(0, 60, 0, 60),
    Position = UDim2.new(1, -80, 0.5, -30),
    BackgroundColor3 = Color3.fromRGB(200, 80, 80),
    BackgroundTransparency = 0.15,
    Text = "AP",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
quick.Parent = gui
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, {}).Parent = quick
mk("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.5 }, {}).Parent = quick

-- Drag floating button
local qdrag = false
local qstart, qpos

quick.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        qdrag = true
        qstart = input.Position
        qpos = quick.Position
        quick.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end
end)

UIS.InputChanged:Connect(function(input)
    if not qdrag then return end
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - qstart
        quick.Position = UDim2.new(
            qpos.X.Scale, qpos.X.Offset + delta.X,
            qpos.Y.Scale, qpos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        qdrag = false
        quick.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
    end
end)

-- Quick toggle on tap (kalau bukan drag)
local tapTime = 0
quick.MouseButton1Click:Connect(function()
    CFG.enabled = not CFG.enabled
    tgl.Text = CFG.enabled and "ON" or "OFF"
    tgl.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
    quick.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
    quick.Text = CFG.enabled and "ON" or "AP"
end)

print("[BB] mobile loaded | executor:", type(identifyexecutor)=="function" and select(1, identifyexecutor()) or "?")
