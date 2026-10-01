-- ============================================================
-- BLADE BALL — AUTO-PARRY FULL FINAL
-- Single-file. Self-diagnostic. Multi-fallback. UI lengkap.
-- Alur: lu parry manual N kali → script belajar → autoparry ON.
-- ============================================================

-- ============================================================
-- BOOT — deteksi capability executor
-- ============================================================
local CAP = {
    hookmetamethod    = type(hookmetamethod) == "function",
    getrawmetatable   = type(getrawmetatable) == "function",
    getnamecallmethod = type(getnamecallmethod) == "function",
    newcclosure       = type(newcclosure) == "function",
    identifyexecutor  = type(identifyexecutor) == "function",
    setreadonly       = type(setreadonly) == "function",
}

local EXEC_NAME, EXEC_VER = "unknown", ""
if CAP.identifyexecutor then
    local ok, n, v = pcall(identifyexecutor)
    if ok then EXEC_NAME, EXEC_VER = tostring(n), tostring(v or "") end
end

local function dbg(...)
    print("[AP-FINAL]", ...)
end

dbg("=== BOOT ===")
dbg("executor:", EXEC_NAME, EXEC_VER)
dbg("capabilities:", "hook=", CAP.hookmetamethod,
    "rawmt=", CAP.getrawmetatable,
    "ncc=", CAP.newcclosure)

-- ============================================================
-- SERVICES
-- ============================================================
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP  = Char:WaitForChild("HumanoidRootPart", 5)

Char.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart", 5)
end)

dbg("localplayer:", LP.Name, "| char:", Char and Char.Name)

-- ============================================================
-- SAFE UI PARENT
-- ============================================================
local uiParent
pcall(function() uiParent = CoreGui end)
if not uiParent then
    uiParent = LP:WaitForChild("PlayerGui")
end
dbg("ui parent:", uiParent:GetFullName())

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    enabled     = false,
    teachTarget = 5,
    parryWindow = 0.18,
    cooldown    = 0.15,
    maxDist     = 60,
    minSpeed    = 40,
    leadFactor  = 1.0,
    debug       = true,
}

local Learn = { samples = {}, done = false, active = false }
local Stats = { currentTTI = math.huge, parries = 0, lastFire = 0 }

-- ============================================================
-- REMOTE DISCOVERY (with verbose logging)
-- ============================================================
local parryRemote = nil
local remoteList = {}

local function scanRemotes()
    parryRemote = nil
    remoteList = {}
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            table.insert(remoteList, v)
        end
    end
    dbg("remotes found:", #remoteList)

    -- priority 1: nama mengandung parry/block/deflect
    for _, v in ipairs(remoteList) do
        local n = v.Name:lower()
        if n:find("parry") or n:find("block") or n:find("deflect") then
            parryRemote = v
            dbg("parry remote matched:", v:GetFullName())
            return
        end
    end
    -- priority 2: nama generik
    for _, v in ipairs(remoteList) do
        local n = v.Name:lower()
        if n == "remote" or n == "remoteevent" or n == "main" or n == "mainremote" then
            parryRemote = v
            dbg("fallback remote:", v:GetFullName())
            return
        end
    end
    dbg("no parry remote — click mode akan dipakai")
end
scanRemotes()

-- ============================================================
-- HOOK INSTALL (guarded)
-- ============================================================
local hookInstalled = false

local function recordManualSample(source)
    if not Learn.active or CFG.enabled then return end
    local tti = Stats.currentTTI
    if not tti or tti == math.huge or tti <= 0 then return end
    table.insert(Learn.samples, tti)
    if CFG.debug then
        dbg(string.format("sample #%d [%s] tti=%.3f", #Learn.samples, source, tti))
    end
    if #Learn.samples >= CFG.teachTarget then
        Learn.done   = true
        Learn.active = false
        CFG.enabled  = true
        local sum = 0
        for _, v in ipairs(Learn.samples) do sum = sum + v end
        CFG.parryWindow = sum / #Learn.samples
        dbg(string.format("LEARNED. window=%.3f from %d samples",
            CFG.parryWindow, #Learn.samples))
    end
end

if parryRemote and CAP.getrawmetatable and CAP.newcclosure then
    local ok, err = pcall(function()
        local mt = getrawmetatable(parryRemote)
        if not mt then error("no metatable") end
        local oldIdx = mt.__index
        mt.__index = newcclosure(function(t, k)
            if k == "FireServer" then
                return newcclosure(function(_, ...)
                    recordManualSample("hook")
                    return oldIdx(t, k)(t, ...)
                end)
            end
            return oldIdx(t, k)
        end)
    end)
    if ok then
        hookInstalled = true
        dbg("hook installed on:", parryRemote:GetFullName())
    else
        dbg("hook install failed:", tostring(err))
    end
end

-- ============================================================
-- CLICK FALLBACK (kalau hook gagal)
-- ============================================================
local clickMode = not hookInstalled
if clickMode then
    dbg("CLICK MODE ACTIVE — klik kiri akan direkam saat belajar")
    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not Learn.active or CFG.enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            recordManualSample("click")
        end
    end)
end

-- ============================================================
-- BALL TRACKING (multi-path discovery)
-- ============================================================
local ballContainer = nil
local function refreshBallContainer()
    ballContainer = WS:FindFirstChild("Balls")
        or WS:FindFirstChild("Ball")
        or WS:FindFirstChild("BallsFolder")
    if not ballContainer then
        for _, v in ipairs(WS:GetChildren()) do
            if v.Name:lower():find("ball") then
                ballContainer = v
                break
            end
        end
    end
end
refreshBallContainer()
dbg("ball container:", ballContainer and ballContainer:GetFullName() or "N/A")

local function getBalls()
    if not ballContainer or not ballContainer.Parent then
        refreshBallContainer()
    end
    return ballContainer and ballContainer:GetChildren() or {}
end

local function timeToImpact(ballPos, ballVel, myPos)
    local toMe = myPos - ballPos
    local dist = toMe.Magnitude
    if dist > CFG.maxDist then return math.huge end
    local speed = ballVel.Magnitude
    if speed < CFG.minSpeed then return math.huge end
    local closing = ballVel:Dot(toMe.Unit)
    if closing <= 0 then return math.huge end
    return (dist / closing) * CFG.leadFactor
end

RunService.RenderStepped:Connect(function()
    if not HRP or not HRP.Parent then return end
    local myPos = HRP.Position
    local best = math.huge
    for _, ball in ipairs(getBalls()) do
        if ball:IsA("BasePart") then
            local t = timeToImpact(ball.Position, ball.AssemblyLinearVelocity, myPos)
            if t < best then best = t end
        end
    end
    Stats.currentTTI = best
end)

-- ============================================================
-- FIRE PARRY
-- ============================================================
local function fireParry()
    if clickMode then
        local ok = pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
        if ok then Stats.parries = Stats.parries + 1 end
    else
        if not parryRemote then scanRemotes() end
        if parryRemote then
            local ok = pcall(function() parryRemote:FireServer() end)
            if ok then Stats.parries = Stats.parries + 1 end
        end
    end
    Stats.lastFire = tick()
end

RunService.RenderStepped:Connect(function()
    if not CFG.enabled then return end
    local now = tick()
    if now - Stats.lastFire < CFG.cooldown then return end
    if Stats.currentTTI <= CFG.parryWindow then
        fireParry()
    end
end)

-- ============================================================
-- UI BUILD
-- ============================================================
local function make(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local COL = {
    bg      = Color3.fromRGB(14, 14, 18),
    panel   = Color3.fromRGB(22, 22, 28),
    panel2  = Color3.fromRGB(30, 30, 38),
    stroke  = Color3.fromRGB(60, 60, 72),
    accent  = Color3.fromRGB(255, 80, 80),
    green   = Color3.fromRGB(70, 210, 120),
    red     = Color3.fromRGB(210, 70, 70),
    text    = Color3.fromRGB(230, 230, 235),
    dim     = Color3.fromRGB(160, 160, 175),
    code    = Color3.fromRGB(200, 200, 210),
}

local gui = make("ScreenGui", {
    Name = "BladeBallAutoParry",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
}, {})
gui.Parent = uiParent

local main = make("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 340, 0, 470),
    Position = UDim2.new(0.05, 0, 0.2, 0),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, {})
main.Parent = gui
make("UICorner", {CornerRadius = UDim.new(0, 12)}, {}).Parent = main
make("UIStroke", {Color = COL.stroke, Thickness = 1}, {}).Parent = main

-- HEADER
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, {})
header.Parent = main
make("UICorner", {CornerRadius = UDim.new(0, 12)}, {}).Parent = header
make("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, {}).Parent = header

make("Frame", {
    Size = UDim2.new(0, 4, 1, -16),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundColor3 = COL.accent,
    BorderSizePixel = 0,
}, {}).Parent = header

make("TextLabel", {
    Size = UDim2.new(1, -140, 1, 0),
    Position = UDim2.new(0, 22, 0, 0),
    BackgroundTransparency = 1,
    Text = "AUTO-PARRY SUITE",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = header

local modeBadge = make("TextLabel", {
    Size = UDim2.new(0, 64, 0, 20),
    Position = UDim2.new(1, -96, 0, 12),
    BackgroundColor3 = clickMode and COL.red or COL.green,
    Text = clickMode and "CLICK" or "HOOK",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    BorderSizePixel = 0,
}, {})
modeBadge.Parent = header
make("UICorner", {CornerRadius = UDim.new(0, 4)}, {}).Parent = modeBadge

local closeBtn = make("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0, 10),
    BackgroundColor3 = COL.panel2,
    Text = "X",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
closeBtn.Parent = header
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- CONTENT
local content = make("Frame", {
    Size = UDim2.new(1, -20, 1, -60),
    Position = UDim2.new(0, 10, 0, 54),
    BackgroundTransparency = 1,
}, {})
content.Parent = main
make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, {}).Parent = content

-- STATUS
local statusPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 1,
}, {})
statusPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = statusPanel

local statusDot = make("Frame", {
    Size = UDim2.new(0, 10, 0, 10),
    Position = UDim2.new(0, 14, 0, 14),
    BackgroundColor3 = COL.dim,
    BorderSizePixel = 0,
}, {})
statusDot.Parent = statusPanel
make("UICorner", {CornerRadius = UDim.new(1, 0)}, {}).Parent = statusDot

local statusTitle = make("TextLabel", {
    Size = UDim2.new(1, -40, 0, 18),
    Position = UDim2.new(0, 32, 0, 8),
    BackgroundTransparency = 1,
    Text = "IDLE",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {})
statusTitle.Parent = statusPanel

local statusSub = make("TextLabel", {
    Size = UDim2.new(1, -40, 0, 14),
    Position = UDim2.new(0, 32, 0, 26),
    BackgroundTransparency = 1,
    Text = "Pencet MULAI BELAJAR buat rekam parry manual.",
    TextColor3 = COL.dim,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {})
statusSub.Parent = statusPanel

-- TTI METER
local ttiPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 2,
}, {})
ttiPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = ttiPanel

make("TextLabel", {
    Size = UDim2.new(0, 60, 0, 12),
    Position = UDim2.new(0, 14, 0, 6),
    BackgroundTransparency = 1,
    Text = "TIME-TO-IMPACT",
    TextColor3 = COL.dim,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = ttiPanel

local ttiValue = make("TextLabel", {
    Size = UDim2.new(0, 80, 0, 12),
    Position = UDim2.new(1, -94, 0, 6),
    BackgroundTransparency = 1,
    Text = "--",
    TextColor3 = COL.code,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
}, {})
ttiValue.Parent = ttiPanel

local ttiTrack = make("Frame", {
    Size = UDim2.new(1, -28, 0, 6),
    Position = UDim2.new(0, 14, 0, 26),
    BackgroundColor3 = COL.panel2,
    BorderSizePixel = 0,
}, {})
ttiTrack.Parent = ttiPanel
make("UICorner", {CornerRadius = UDim.new(0, 3)}, {}).Parent = ttiTrack

local ttiFill = make("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = COL.accent,
    BorderSizePixel = 0,
}, {})
ttiFill.Parent = ttiTrack
make("UICorner", {CornerRadius = UDim.new(0, 3)}, {}).Parent = ttiFill

-- TEACH TARGET
local teachPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 3,
}, {})
teachPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = teachPanel

make("TextLabel", {
    Size = UDim2.new(1, -28, 0, 16),
    Position = UDim2.new(0, 14, 0, 4),
    BackgroundTransparency = 1,
    Text = "Parry manual yang dibutuhin",
    TextColor3 = COL.text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = teachPanel

local countLabel = make("TextLabel", {
    Size = UDim2.new(0, 60, 0, 28),
    Position = UDim2.new(0, 14, 0, 22),
    BackgroundColor3 = COL.panel2,
    Text = tostring(CFG.teachTarget),
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, {})
countLabel.Parent = teachPanel
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = countLabel

local minusBtn = make("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(0, 82, 0, 22),
    BackgroundColor3 = COL.panel2,
    Text = "-",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
minusBtn.Parent = teachPanel
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = minusBtn

local plusBtn = make("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(0, 118, 0, 22),
    BackgroundColor3 = COL.panel2,
    Text = "+",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
plusBtn.Parent = teachPanel
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = plusBtn

minusBtn.MouseButton1Click:Connect(function()
    if CFG.enabled or Learn.active then return end
    CFG.teachTarget = math.max(1, CFG.teachTarget - 1)
    countLabel.Text = tostring(CFG.teachTarget)
end)
plusBtn.MouseButton1Click:Connect(function()
    if CFG.enabled or Learn.active then return end
    CFG.teachTarget = math.min(50, CFG.teachTarget + 1)
    countLabel.Text = tostring(CFG.teachTarget)
end)

-- START BUTTON
local startBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = COL.green,
    Text = "MULAI BELAJAR",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    LayoutOrder = 4,
}, {})
startBtn.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = startBtn

-- INFO PANEL
local infoPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 5,
}, {})
infoPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = infoPanel

local function mkInfoRow(label, y)
    make("TextLabel", {
        Size = UDim2.new(0, 90, 0, 16),
        Position = UDim2.new(0, 14, 0, y),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = COL.dim,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {}).Parent = infoPanel
    local v = make("TextLabel", {
        Size = UDim2.new(1, -120, 0, 16),
        Position = UDim2.new(0, 110, 0, y),
        BackgroundTransparency = 1,
        Text = "-",
        TextColor3 = COL.code,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, {})
    v.Parent = infoPanel
    return v
end

local progressVal = mkInfoRow("Progress", 10)
local windowVal   = mkInfoRow("Window",   32)
local parriesVal  = mkInfoRow("Parries",  54)
local remoteVal   = mkInfoRow("Remote",   76)

-- LOG
local logPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 6,
}, {})
logPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = logPanel

local logLabel = make("TextLabel", {
    Size = UDim2.new(1, -20, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "ready | " .. EXEC_NAME,
    TextColor3 = COL.dim,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {})
logLabel.Parent = logPanel

-- START LOGIC
startBtn.MouseButton1Click:Connect(function()
    if Learn.active then
        Learn.active = false
        Learn.samples = {}
        CFG.enabled = false
        startBtn.Text = "MULAI BELAJAR"
        startBtn.BackgroundColor3 = COL.green
        logLabel.Text = "cancelled"
        dbg("teach cancelled by user")
        return
    end
    if CFG.enabled then
        CFG.enabled = false
        Learn.done = false
        Learn.samples = {}
        startBtn.Text = "MULAI BELAJAR"
        startBtn.BackgroundColor3 = COL.green
        logLabel.Text = "autoparry off"
        dbg("autoparry disabled by user")
        return
    end
    Learn.samples = {}
    Learn.done    = false
    Learn.active  = true
    CFG.enabled   = false
    startBtn.Text = "BATAL BELAJAR"
    startBtn.BackgroundColor3 = COL.red
    logLabel.Text = string.format("recording | target %d | mode %s",
        CFG.teachTarget, clickMode and "click" or "hook")
    dbg("teach started | target:", CFG.teachTarget, "| mode:",
        clickMode and "click" or "hook")
end)

-- UI UPDATER
task.spawn(function()
    while gui.Parent do
        if Learn.active then
            statusDot.BackgroundColor3 = COL.accent
            statusTitle.Text = "RECORDING"
            statusSub.Text = string.format("Parry manual sekarang. %d / %d",
                #Learn.samples, CFG.teachTarget)
        elseif CFG.enabled then
            statusDot.BackgroundColor3 = COL.green
            statusTitle.Text = "AUTO-PARRY ON"
            statusSub.Text = "Timing udah ke-record, autoparry aktif."
        else
            statusDot.BackgroundColor3 = COL.dim
            statusTitle.Text = "IDLE"
            statusSub.Text = "Pencet MULAI BELAJAR buat rekam parry manual."
        end

        local tti = Stats.currentTTI
        if tti == math.huge then
            ttiValue.Text = "--"
            ttiFill.Size = UDim2.new(0, 0, 1, 0)
        else
            ttiValue.Text = string.format("%.3fs", tti)
            local ratio = math.clamp(tti / 0.5, 0, 1)
            ttiFill.Size = UDim2.new(ratio, 0, 1, 0)
            if CFG.enabled and tti <= CFG.parryWindow then
                ttiFill.BackgroundColor3 = COL.green
            else
                ttiFill.BackgroundColor3 = COL.accent
            end
        end

        progressVal.Text = string.format("%d / %d", #Learn.samples, CFG.teachTarget)
        windowVal.Text   = CFG.enabled and string.format("%.3fs", CFG.parryWindow) or "-"
        parriesVal.Text  = tostring(Stats.parries)
        remoteVal.Text   = parryRemote and parryRemote.Name or "N/A"

        task.wait(0.05)
    end
end)

-- MINIMIZE
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        content.Visible = not content.Visible
        main.Size = content.Visible and UDim2.new(0, 340, 0, 470) or UDim2.new(0, 340, 0, 44)
    end
end)

dbg("=== LOADED ===")
dbg("mode:", clickMode and "CLICK" or "HOOK")
dbg("remote:", parryRemote and parryRemote:GetFullName() or "N/A")
dbg("ball container:", ballContainer and ballContainer:GetFullName() or "N/A")
dbg("ui parent:", uiParent:GetFullName())
