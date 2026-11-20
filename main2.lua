-- blade ball | ap + hook system + mobile ui
-- executor: synapse x / fluxus / krnl / wave

-- ───── services ─────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")
local StarterGui     = game:GetService("StarterGui")

local lp   = Players.LocalPlayer
local gui  = lp:WaitForChild("PlayerGui")
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

-- ───── config ─────
local cfg = {
    enabled       = true,
    prediction    = 0.08,
    minDist       = 60,
    parryBuffer   = 0.12,
    cooldown      = 1.2,
    hookLog       = true,
}

-- ───── hook system ─────
local HookSystem = {}
HookSystem.__index = HookSystem

HookSystem.hooks      = {}   -- { [eventName] = { pre={}, post={} } }
HookSystem.log        = {}   -- ring buffer, max 50
HookSystem.logMax     = 50
HookSystem.blocked    = {}   -- { [eventName] = bool }

function HookSystem:register(name)
    if not self.hooks[name] then
        self.hooks[name]  = { pre = {}, post = {} }
        self.blocked[name] = false
    end
end

function HookSystem:addPre(name, fn)
    self:register(name)
    table.insert(self.hooks[name].pre, fn)
end

function HookSystem:addPost(name, fn)
    self:register(name)
    table.insert(self.hooks[name].post, fn)
end

function HookSystem:block(name, state)
    self:register(name)
    self.blocked[name] = state
end

-- returns false if blocked
function HookSystem:fire(name, payload)
    self:register(name)
    for _, fn in ipairs(self.hooks[name].pre) do
        local ok, err = pcall(fn, payload)
        if not ok then warn("[hook pre]", err) end
    end
    if self.blocked[name] then
        self:_log(name, payload, true)
        return false
    end
    self:_log(name, payload, false)
    for _, fn in ipairs(self.hooks[name].post) do
        local ok, err = pcall(fn, payload)
        if not ok then warn("[hook post]", err) end
    end
    return true
end

function HookSystem:_log(name, payload, blocked)
    local entry = {
        time    = tick(),
        name    = name,
        payload = payload,
        blocked = blocked,
    }
    table.insert(self.log, entry)
    if #self.log > self.logMax then table.remove(self.log, 1) end
end

function HookSystem:getLog(n)
    n = n or 10
    local out = {}
    local start = math.max(1, #self.log - n + 1)
    for i = start, #self.log do
        table.insert(out, self.log[i])
    end
    return out
end

setmetatable(HookSystem, { __index = HookSystem })

-- register built-in hooks
HookSystem:register("parry.fire")
HookSystem:register("ball.detected")
HookSystem:register("ap.toggle")

-- example pre-hook: log every parry attempt
HookSystem:addPre("parry.fire", function(p)
    if cfg.hookLog then
        -- visible in hook log panel
    end
end)

-- ───── remote finder ─────
local parryRemote
local function findRemote()
    local function scan(parent)
        for _, v in ipairs(parent:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n = v.Name:lower()
                if n:find("parry") or n:find("block") or n:find("shield") then
                    return v
                end
            end
        end
    end
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
           or ReplicatedStorage:FindFirstChild("Events")
    if folder then
        parryRemote = scan(folder) or scan(ReplicatedStorage)
    else
        parryRemote = scan(ReplicatedStorage)
    end
    return parryRemote
end
findRemote()
if not parryRemote then
    task.delay(3, function()
        findRemote()
    end)
end

-- ───── ball finder ─────
local function findBall()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n == "ball" or n == "bladeball" or n == "orb" then
                return v
            end
        end
    end
end

-- ───── ap core ─────
local lastParry   = 0
local parryCount  = 0
local blockCount  = 0

local conn = RunService.Heartbeat:Connect(function()
    if not cfg.enabled then return end
    if not parryRemote  then return end
    char = lp.Character
    if not char then return end
    hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = findBall()
    if not ball then return end

    HookSystem:fire("ball.detected", { ball = ball })

    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    local myPos   = hrp.Position
    local predicted = ballPos + ballVel * cfg.prediction
    local dist      = (ballPos - myPos).Magnitude
    local predDist  = (predicted - myPos).Magnitude

    if dist > cfg.minDist and predDist > cfg.minDist then return end

    local toMe   = (myPos - ballPos).Unit
    local velNorm = ballVel.Magnitude > 0 and ballVel.Unit or Vector3.zero
    local dot    = toMe:Dot(velNorm)
    if dot < 0.35 then return end

    local speed     = ballVel.Magnitude
    local timeToHit = speed > 0 and (predDist / speed) or 999

    local now = tick()
    if timeToHit <= cfg.parryBuffer and (now - lastParry) >= cfg.cooldown then
        local payload = {
            dist      = dist,
            timeToHit = timeToHit,
            dot       = dot,
            timestamp = now,
        }
        local allowed = HookSystem:fire("parry.fire", payload)
        if allowed then
            lastParry  = now
            parryCount = parryCount + 1
            parryRemote:FireServer()
        else
            blockCount = blockCount + 1
        end
    end
end)

lp.CharacterAdded:Connect(function(c)
    char = c
    hrp  = c:WaitForChild("HumanoidRootPart")
end)

-- ───── UI ─────
-- destroy old gui
if gui:FindFirstChild("BBAP_UI") then
    gui:FindFirstChild("BBAP_UI"):Destroy()
end

local screenGui   = Instance.new("ScreenGui")
screenGui.Name    = "BBAP_UI"
screenGui.ResetOnSpawn     = false
screenGui.IgnoreGuiInset   = true
screenGui.DisplayOrder     = 999
screenGui.Parent           = gui

-- ── palette ──
local C = {
    bg       = Color3.fromRGB(14, 14, 18),
    panel    = Color3.fromRGB(22, 22, 28),
    border   = Color3.fromRGB(50, 50, 65),
    accent   = Color3.fromRGB(120, 90, 255),
    accentD  = Color3.fromRGB(80, 55, 190),
    green    = Color3.fromRGB(80, 220, 130),
    red      = Color3.fromRGB(230, 80,  80),
    amber    = Color3.fromRGB(240, 170, 60),
    text     = Color3.fromRGB(230, 230, 240),
    muted    = Color3.fromRGB(130, 130, 150),
    white    = Color3.fromRGB(255, 255, 255),
}

local function new(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function uiCorner(r, p)
    new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end
local function uiPad(l, r, t, b, p)
    new("UIPadding", {
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
    }, p)
end
local function uiList(dir, sp, p)
    new("UIListLayout", {
        FillDirection     = dir or Enum.FillDirection.Vertical,
        SortOrder         = Enum.SortOrder.LayoutOrder,
        Padding           = UDim.new(0, sp or 6),
    }, p)
end

-- ── root frame (anchored bottom-left, mobile friendly) ──
local root = new("Frame", {
    Name            = "Root",
    Size            = UDim2.new(0, 300, 0, 0),
    Position        = UDim2.new(0, 12, 1, -12),
    AnchorPoint     = Vector2.new(0, 1),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    AutomaticSize   = Enum.AutomaticSize.Y,
    ClipsDescendants = true,
}, screenGui)
uiCorner(14, root)
new("UIStroke", {
    Color      = C.border,
    Thickness  = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, root)
uiPad(0, 0, 0, 0, root)

local rootLayout = new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0, 0),
}, root)

-- ── header ──
local header = new("Frame", {
    Name             = "Header",
    Size             = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = C.panel,
    BorderSizePixel  = 0,
    LayoutOrder      = 0,
}, root)
uiCorner(14, header)

local accent_bar = new("Frame", {
    Size             = UDim2.new(0, 4, 1, -16),
    Position         = UDim2.new(0, 10, 0.5, 0),
    AnchorPoint      = Vector2.new(0, 0.5),
    BackgroundColor3 = C.accent,
    BorderSizePixel  = 0,
}, header)
uiCorner(4, accent_bar)

new("TextLabel", {
    Size             = UDim2.new(1, -60, 1, 0),
    Position         = UDim2.new(0, 22, 0, 0),
    BackgroundTransparency = 1,
    Text             = "BladeBall AP",
    TextColor3       = C.text,
    TextSize         = 15,
    Font             = Enum.Font.GothamBold,
    TextXAlignment   = Enum.TextXAlignment.Left,
}, header)

-- minimize button
local minBtn = new("TextButton", {
    Size             = UDim2.new(0, 36, 0, 36),
    Position         = UDim2.new(1, -42, 0.5, 0),
    AnchorPoint      = Vector2.new(0, 0.5),
    BackgroundColor3 = C.border,
    Text             = "−",
    TextColor3       = C.text,
    TextSize         = 20,
    Font             = Enum.Font.GothamBold,
    BorderSizePixel  = 0,
}, header)
uiCorner(8, minBtn)

-- ── body (collapsible) ──
local body = new("Frame", {
    Name             = "Body",
    Size             = UDim2.new(1, 0, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
    Visible          = true,
}, root)
uiList(Enum.FillDirection.Vertical, 0, body)
uiPad(10, 10, 8, 10, body)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    minBtn.Text  = minimized and "+" or "−"
end)

-- ─── helper: section label ───
local function sectionLabel(txt, order, parent)
    local lbl = new("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text                   = txt:upper(),
        TextColor3             = C.muted,
        TextSize               = 10,
        Font                   = Enum.Font.GothamBold,
        TextXAlignment         = Enum.TextXAlignment.Left,
        LayoutOrder            = order,
    }, parent)
    uiPad(4, 0, 6, 2, lbl)
    return lbl
end

-- ─── helper: toggle row ───
local function makeToggle(label, state, order, parent, onChange)
    local row = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = C.panel,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
    }, parent)
    uiCorner(10, row)
    uiPad(12, 12, 0, 0, row)

    new("TextLabel", {
        Size                   = UDim2.new(0.65, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = label,
        TextColor3             = C.text,
        TextSize               = 13,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Left,
    }, row)

    local track = new("Frame", {
        Size             = UDim2.new(0, 46, 0, 24),
        Position         = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint      = Vector2.new(1, 0.5),
        BackgroundColor3 = state and C.accent or C.border,
        BorderSizePixel  = 0,
    }, row)
    uiCorner(12, track)

    local thumb = new("Frame", {
        Size        = UDim2.new(0, 18, 0, 18),
        Position    = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.white,
        BorderSizePixel  = 0,
    }, track)
    uiCorner(9, thumb)

    local on = state
    local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            on = not on
            TweenService:Create(track, ti, {
                BackgroundColor3 = on and C.accent or C.border
            }):Play()
            TweenService:Create(thumb, ti, {
                Position = on and UDim2.new(1, -21, 0.5, 0)
                               or UDim2.new(0, 3, 0.5, 0)
            }):Play()
            if onChange then onChange(on) end
        end
    end)

    return row, function() return on end
end

-- ─── helper: slider row ───
local function makeSlider(label, min, max, val, decimals, order, parent, onChange)
    local row = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = C.panel,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
    }, parent)
    uiCorner(10, row)
    uiPad(12, 12, 6, 6, row)

    local topRow = new("Frame", {
        Size                   = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
    }, row)

    new("TextLabel", {
        Size                   = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = label,
        TextColor3             = C.text,
        TextSize               = 12,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Left,
    }, topRow)

    local valLbl = new("TextLabel", {
        Size                   = UDim2.new(0.3, 0, 1, 0),
        Position               = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text                   = tostring(math.floor(val * 10^decimals + 0.5) / 10^decimals),
        TextColor3             = C.accent,
        TextSize               = 12,
        Font                   = Enum.Font.GothamBold,
        TextXAlignment         = Enum.TextXAlignment.Right,
    }, topRow)

    local track = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 6),
        Position         = UDim2.new(0, 0, 1, 2),
        AnchorPoint      = Vector2.new(0, 0),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0,
    }, row)
    uiCorner(3, track)

    local fill = new("Frame", {
        Size             = UDim2.new((val - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel  = 0,
    }, track)
    uiCorner(3, fill)

    local thumb = new("Frame", {
        Size        = UDim2.new(0, 18, 0, 18),
        Position    = UDim2.new((val - min) / (max - min), -9, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.white,
        BorderSizePixel  = 0,
    }, track)
    uiCorner(9, thumb)
    new("UIStroke", { Color = C.accent, Thickness = 2 }, thumb)

    local dragging = false
    thumb.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end

        local pos = inp.UserInputType == Enum.UserInputType.Touch
            and inp.Position
            or inp.Position

        local abs   = track.AbsolutePosition
        local size  = track.AbsoluteSize
        local t     = math.clamp((pos.X - abs.X) / size.X, 0, 1)
        local newVal = min + t * (max - min)
        local rounded = math.floor(newVal * 10^decimals + 0.5) / 10^decimals

        fill.Size     = UDim2.new(t, 0, 1, 0)
        thumb.Position = UDim2.new(t, -9, 0.5, 0)
        valLbl.Text   = tostring(rounded)
        if onChange then onChange(rounded) end
    end)

    return row
end

-- ─── status card ───
sectionLabel("status", 10, body)

local statCard = new("Frame", {
    Size             = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = C.panel,
    BorderSizePixel  = 0,
    LayoutOrder      = 11,
}, body)
uiCorner(10, statCard)
uiPad(12, 12, 0, 0, statCard)
uiList(Enum.FillDirection.Horizontal, 0, statCard)

local function statItem(label, color, order, parent)
    local col = new("Frame", {
        Size                   = UDim2.new(0.33, 0, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder            = order,
    }, parent)
    local n = new("TextLabel", {
        Size                   = UDim2.new(1, 0, 0.55, 0),
        Position               = UDim2.new(0, 0, 0.1, 0),
        BackgroundTransparency = 1,
        Text                   = "0",
        TextColor3             = color,
        TextSize               = 18,
        Font                   = Enum.Font.GothamBold,
        TextXAlignment         = Enum.TextXAlignment.Center,
    }, col)
    new("TextLabel", {
        Size                   = UDim2.new(1, 0, 0.35, 0),
        Position               = UDim2.new(0, 0, 0.62, 0),
        BackgroundTransparency = 1,
        Text                   = label,
        TextColor3             = C.muted,
        TextSize               = 10,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Center,
    }, col)
    return n
end

local lblParry = statItem("PARRIES",  C.green,  1, statCard)
local lblBlock = statItem("BLOCKED",  C.red,    2, statCard)
local lblRemote = statItem("REMOTE", C.amber,   3, statCard)

-- ─── toggles section ───
sectionLabel("controls", 20, body)

local _, getEnabled = makeToggle("Auto Parry", cfg.enabled, 21, body, function(v)
    cfg.enabled = v
    HookSystem:fire("ap.toggle", { state = v })
end)

local _, getHookLog = makeToggle("Hook Logging", cfg.hookLog, 22, body, function(v)
    cfg.hookLog = v
end)

local _, getBlockToggle = makeToggle("Block Parry (test)", false, 23, body, function(v)
    HookSystem:block("parry.fire", v)
end)

-- ─── sliders ───
sectionLabel("tuning", 30, body)

makeSlider("Prediction (s)", 0.02, 0.25, cfg.prediction, 2, 31, body, function(v)
    cfg.prediction = v
end)

makeSlider("Parry Buffer (s)", 0.05, 0.30, cfg.parryBuffer, 2, 32, body, function(v)
    cfg.parryBuffer = v
end)

makeSlider("Max Distance", 20, 120, cfg.minDist, 0, 33, body, function(v)
    cfg.minDist = v
end)

-- ─── hook log panel ───
sectionLabel("hook log", 40, body)

local logFrame = new("ScrollingFrame", {
    Size                  = UDim2.new(1, 0, 0, 90),
    BackgroundColor3      = C.panel,
    BorderSizePixel       = 0,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize   = Enum.AutomaticCanvasSize.Y,
    ScrollBarThickness    = 2,
    ScrollBarImageColor3  = C.accent,
    ScrollingDirection    = Enum.ScrollingDirection.Y,
    LayoutOrder           = 41,
}, body)
uiCorner(10, logFrame)
uiPad(8, 8, 6, 6, logFrame)
uiList(Enum.FillDirection.Vertical, 2, logFrame)

local logLines = {}
local function pushLog(txt, color)
    if #logLines >= 12 then
        logLines[1]:Destroy()
        table.remove(logLines, 1)
    end
    local lbl = new("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text                   = txt,
        TextColor3             = color or C.muted,
        TextSize               = 10,
        Font                   = Enum.Font.Code,
        TextXAlignment         = Enum.TextXAlignment.Left,
    }, logFrame)
    table.insert(logLines, lbl)
    logFrame.CanvasPosition = Vector2.new(0, 9999)
end

-- hook pre-listener for log
HookSystem:addPre("parry.fire", function(p)
    if cfg.hookLog then
        pushLog(
            string.format("[parry] dist=%.1f tti=%.3f", p.dist, p.timeToHit),
            C.green
        )
    end
end)
HookSystem:addPre("ap.toggle", function(p)
    pushLog("[ap] state=" .. tostring(p.state), C.amber)
end)

-- ─── drag (header drag for repositioning) ───
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = inp.Position
        startPos  = root.Position
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = inp.Position - dragStart
    root.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end)

-- ─── stat updater ───
task.spawn(function()
    while task.wait(0.5) do
        lblParry.Text  = tostring(parryCount)
        lblBlock.Text  = tostring(blockCount)
        lblRemote.Text = parryRemote and "✓" or "✗"
    end
end)

-- ─── keybind (F) ───
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        cfg.enabled = not cfg.enabled
        HookSystem:fire("ap.toggle", { state = cfg.enabled })
    end
end)

pushLog("[system] loaded — ready", C.accent)
print("[BB-AP] loaded | F = toggle")
