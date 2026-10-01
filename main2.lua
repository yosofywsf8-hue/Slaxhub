-- ============================================================
-- Blade Ball — TEACH AUTO-PARRY v3
-- Fokus UI: header clean, live TTI meter, mode badge, log panel.
-- Lu parry manual N kali → script belajar timing lu → autoparry ON.
-- Fallback CLICK mode kalau hook nggak support.
-- ============================================================

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")
local Tween      = game:GetService("TweenService")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP  = Char:WaitForChild("HumanoidRootPart")

Char.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- DEBUG
-- ============================================================
local DEBUG = true
local function dbg(...)
    if DEBUG then print("[TEACH]", ...) end
end
dbg("v3 start | hookmetamethod:", type(hookmetamethod) == "function",
    "| getrawmetatable:", type(getrawmetatable) == "function")

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
    hookOK      = false,
    clickMode   = false,
}

local Learn = { samples = {}, done = false, active = false }
local Stats = { currentTTI = math.huge, parries = 0 }

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local parryRemote = nil

local function scanRemotes()
    parryRemote = nil
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("parry") or n:find("block") or n:find("deflect") then
                parryRemote = v
                dbg("parry remote:", v:GetFullName())
                return
            end
        end
    end
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n == "remote" or n == "remoteevent" then
                parryRemote = v
                dbg("fallback remote:", v:GetFullName())
                return
            end
        end
    end
end
scanRemotes()

-- ============================================================
-- HOOK
-- ============================================================
local function installParryHook()
    if not parryRemote then return false end
    if type(hookmetamethod) ~= "function" or type(getrawmetatable) ~= "function" then
        return false
    end
    local ok, err = pcall(function()
        local mt = getrawmetatable(parryRemote)
        if not mt then error("no metatable") end
        if mt.__teach_hooked then return end
        local oldIdx = mt.__index
        mt.__index = newcclosure(function(t, k)
            if k == "FireServer" then
                return newcclosure(function(_, ...)
                    if Learn.active and not CFG.enabled then
                        local tti = Stats.currentTTI
                        if tti and tti < math.huge and tti > 0 then
                            table.insert(Learn.samples, tti)
                            if #Learn.samples >= CFG.teachTarget then
                                Learn.done   = true
                                Learn.active = false
                                CFG.enabled  = true
                                local sum = 0
                                for _, v in ipairs(Learn.samples) do sum = sum + v end
                                CFG.parryWindow = sum / #Learn.samples
                            end
                        end
                    end
                    return oldIdx(t, k)(t, ...)
                end)
            end
            return oldIdx(t, k)
        end)
        mt.__teach_hooked = true
    end)
    return ok
end

CFG.hookOK = installParryHook()
CFG.clickMode = not CFG.hookOK
dbg("hook mode:", CFG.hookOK and "HOOK" or "CLICK")

-- ============================================================
-- BALL TRACKING
-- ============================================================
local function getBalls()
    local c = WS:FindFirstChild("Balls") or WS:FindFirstChild("Ball")
    return c and c:GetChildren() or {}
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
    local best  = math.huge
    for _, ball in ipairs(getBalls()) do
        if ball:IsA("BasePart") then
            local t = timeToImpact(ball.Position, ball.AssemblyLinearVelocity, myPos)
            if t < best then best = t end
        end
    end
    Stats.currentTTI = best
end)

-- ============================================================
-- CLICK MODE FALLBACK
-- ============================================================
if CFG.clickMode then
    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not Learn.active or CFG.enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            local tti = Stats.currentTTI
            if tti and tti < math.huge and tti > 0 then
                table.insert(Learn.samples, tti)
                if #Learn.samples >= CFG.teachTarget then
                    Learn.done   = true
                    Learn.active = false
                    CFG.enabled  = true
                    local sum = 0
                    for _, v in ipairs(Learn.samples) do sum = sum + v end
                    CFG.parryWindow = sum / #Learn.samples
                end
            end
        end
    end)
end

-- ============================================================
-- AUTOPARRY TRIGGER
-- ============================================================
local lastParry = 0

local function fireParry()
    if CFG.clickMode then
        local VIM = game:GetService("VirtualInputManager")
        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    else
        if not parryRemote then scanRemotes() end
        if parryRemote then
            pcall(function() parryRemote:FireServer() end)
        end
    end
    Stats.parries = Stats.parries + 1
end

RunService.RenderStepped:Connect(function()
    if not CFG.enabled then return end
    local now = tick()
    if now - lastParry < CFG.cooldown then return end
    if Stats.currentTTI <= CFG.parryWindow then
        fireParry()
        lastParry = now
    end
end)

-- ============================================================
-- UI
-- ============================================================
local function make(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local gui = make("ScreenGui", {
    Name = "TeachAutoParryV3",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, {})
local ok = pcall(function() gui.Parent = CoreGui end)
if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end

-- PALETTE
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

local main = make("Frame", {
    Size = UDim2.new(0, 340, 0, 460),
    Position = UDim2.new(0.05, 0, 0.25, 0),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, {})
main.Parent = gui
make("UICorner", {CornerRadius = UDim.new(0, 12)}, {}).Parent = main
make("UIStroke", {Color = COL.stroke, Thickness = 1}, {}).Parent = main

-- ============ HEADER ============
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, {})
header.Parent = main
make("UICorner", {CornerRadius = UDim.new(0, 12)}, {}).Parent = header
-- cover bottom corner radius overlap
make("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, {}).Parent = header

-- accent bar
make("Frame", {
    Size = UDim2.new(0, 4, 1, -16),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundColor3 = COL.accent,
    BorderSizePixel = 0,
}, {}).Parent = header

make("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0),
    Position = UDim2.new(0, 22, 0, 0),
    BackgroundTransparency = 1,
    Text = "TEACH AUTO-PARRY",
    TextColor3 = COL.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = header

-- mode badge
local modeBadge = make("TextLabel", {
    Size = UDim2.new(0, 60, 0, 20),
    Position = UDim2.new(1, -94, 0, 12),
    BackgroundColor3 = CFG.clickMode and COL.red or COL.green,
    Text = CFG.clickMode and "CLICK" or "HOOK",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    BorderSizePixel = 0,
}, {})
modeBadge.Parent = header
make("UICorner", {CornerRadius = UDim.new(0, 4)}, {}).Parent = modeBadge

-- close btn
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

-- ============ CONTENT ============
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

-- ============ STATUS PANEL ============
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

-- ============ TTI METER ============
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
    Text = "TTI",
    TextColor3 = COL.dim,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = ttiPanel

local ttiValue = make("TextLabel", {
    Size = UDim2.new(1, -80, 0, 12),
    Position = UDim2.new(1, -80, 0, 6),
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

-- ============ TEACH TARGET ============
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

local function mkStepBtn(label, posX)
    local b = make("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, posX, 0, 22),
        BackgroundColor3 = COL.panel2,
        Text = label,
        TextColor3 = COL.text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, {})
    b.Parent = teachPanel
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = b
    return b
end

local minusBtn = mkStepBtn("-", 82)
local plusBtn  = mkStepBtn("+", 118)

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

-- ============ START BUTTON ============
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

-- ============ INFO / LEARNED ============
local infoPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
    LayoutOrder = 5,
}, {})
infoPanel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 8)}, {}).Parent = infoPanel

local function mkInfoRow(label, y)
    local k = make("TextLabel", {
        Size = UDim2.new(0, 80, 0, 16),
        Position = UDim2.new(0, 14, 0, y),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = COL.dim,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {})
    k.Parent = infoPanel
    local v = make("TextLabel", {
        Size = UDim2.new(1, -110, 0, 16),
        Position = UDim2.new(0, 100, 0, y),
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

-- ============ LOG ============
local logPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
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
    Text = "ready",
    TextColor3 = COL.dim,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {})
logLabel.Parent = logPanel

-- ============================================================
-- START BUTTON LOGIC
-- ============================================================
startBtn.MouseButton1Click:Connect(function()
    if Learn.active then
        Learn.active = false
        Learn.samples = {}
        CFG.enabled = false
        startBtn.Text = "MULAI BELAJAR"
        startBtn.BackgroundColor3 = COL.green
        logLabel.Text = "cancelled"
        return
    end
    if CFG.enabled then
        CFG.enabled = false
        Learn.done = false
        Learn.samples = {}
        startBtn.Text = "MULAI BELAJAR"
        startBtn.BackgroundColor3 = COL.green
        logLabel.Text = "autoparry off"
        return
    end
    Learn.samples = {}
    Learn.done    = false
    Learn.active  = true
    CFG.enabled   = false
    startBtn.Text = "BATAL BELAJAR"
    startBtn.BackgroundColor3 = COL.red
    logLabel.Text = string.format("recording | %d target | %s",
        CFG.teachTarget, CFG.clickMode and "click" or "hook")
end)

-- ============================================================
-- UI UPDATER
-- ============================================================
task.spawn(function()
    while gui.Parent do
        -- status
        if Learn.active then
            statusDot.BackgroundColor3 = COL.accent
            statusTitle.Text = "RECORDING"
            statusSub.Text = string.format("Parry manual sekarang. %d/%d",
                #Learn.samples, CFG.teachTarget)
        elseif CFG.enabled then
            statusDot.BackgroundColor3 = COL.green
            statusTitle.Text = "AUTO-PARRY ON"
            statusSub.Text = "Timing lu udah ke-record, aktif."
        else
            statusDot.BackgroundColor3 = COL.dim
            statusTitle.Text = "IDLE"
            statusSub.Text = "Pencet MULAI BELAJAR buat rekam parry manual."
        end

        -- tti meter
        local tti = Stats.currentTTI
        local maxTTI = 0.5
        if tti == math.huge then
            ttiValue.Text = "--"
            ttiFill.Size = UDim2.new(0, 0, 1, 0)
            ttiFill.BackgroundColor3 = COL.panel2
        else
            ttiValue.Text = string.format("%.3fs", tti)
            local ratio = math.clamp(tti / maxTTI, 0, 1)
            ttiFill.Size = UDim2.new(ratio, 0, 1, 0)
            if CFG.enabled and tti <= CFG.parryWindow then
                ttiFill.BackgroundColor3 = COL.green
            else
                ttiFill.BackgroundColor3 = COL.accent
            end
        end

        -- info rows
        progressVal.Text = string.format("%d / %d", #Learn.samples, CFG.teachTarget)
        windowVal.Text   = CFG.enabled and string.format("%.3fs", CFG.parryWindow) or "-"
        parriesVal.Text  = tostring(Stats.parries)
        remoteVal.Text   = parryRemote and parryRemote.Name or "N/A"

        task.wait(0.05)
    end
end)

-- right-click header minimize
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        content.Visible = not content.Visible
        main.Size = content.Visible and UDim2.new(0, 340, 0, 460) or UDim2.new(0, 340, 0, 44)
    end
end)

dbg("v3 loaded | mode:", CFG.clickMode and "CLICK" or "HOOK")
