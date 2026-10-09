-- ALPHA SYSTEM | Blade Ball Auto Parry — Full UI + Core
-- Responsive: Mobile & PC | Dark Glass Theme

local Players           = cloneref(game:GetService('Players'))
local RunService        = cloneref(game:GetService('RunService'))
local UIS               = cloneref(game:GetService('UserInputService'))
local TweenService      = cloneref(game:GetService('TweenService'))
local workspace_s       = cloneref(game:GetService('Workspace'))
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local CoreGui           = cloneref(game:GetService('CoreGui'))

local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════
-- PARRY PATCH CORE
-- ══════════════════════════════════════════

local _PARRY_PATCH = {
    keyTable    = nil,
    transformFn = nil,
    parryHash   = nil,
    parryRemote = nil,
    ready       = false,
}

task.spawn(function()
    local ok, err = pcall(function()
        local RS          = game:GetService("ReplicatedStorage")
        local Controllers = RS:WaitForChild("Controllers", 15)
        if not Controllers then return end
        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 16) == "SwordsController" then SC = child break end
        end
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then return end
        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then return end
        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        _PARRY_PATCH.ready       = true
    end)
    if not ok then warn("[PARRY] init error:", tostring(err)) end
end)

local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8
        and type(args[2])   == "string"
        and type(args[3])   == "string"
        and type(args[4])   == "number"
        and typeof(args[5]) == "CFrame"
        and type(args[6])   == "table"
        and type(args[7])   == "table"
        and type(args[8])   == "boolean"
end

local function _hook(remote)
    if _reverted[remote] then return end
    if _original[getrawmetatable(remote)] then return end
    _original[getrawmetatable(remote)] = true
    local _meta = getrawmetatable(remote)
    setreadonly(_meta, false)
    local _old = _meta.__index
    _meta.__index = function(self, key)
        if (key == 'FireServer' and self:IsA('RemoteEvent')) or
           (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
            return function(_, ...)
                local _arguments = {...}
                if _is_valid(_arguments) then
                    if not _reverted[self] then
                        _reverted[self]          = _arguments
                        _PARRY_PATCH.ready       = true
                        _PARRY_PATCH.parryRemote = self
                    end
                end
                return _old(self, key)(_, unpack(_arguments))
            end
        end
        return _old(self, key)
    end
    setreadonly(_meta, true)
end

for _, remote in pairs(replicated_storage:GetDescendants()) do
    if remote:IsA('RemoteEvent') or remote:IsA('RemoteFunction') then
        _hook(remote)
    end
end

local function _PARRY_FIRE(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local keyIndex   = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
    if not currentKey then return false end
    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false end
    end
    local serverTime = workspace_s:GetServerTimeNow() * 100
    local timeStr    = tostring(math.floor(serverTime))
    local tc = {}
    for i = 1, #timeStr do
        local ki = (i - 1) % #transformed + 1
        local kb = string.byte(transformed, ki)
        local tb = (string.byte(timeStr, i) + i) % 256
        tc[i]    = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)
    local fok = pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token,
            0.5, curveCFrame, screenPositions, mouseLocation, false
        )
    end)
    return fok
end

-- ══════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════

local Config = {
    AutoParry  = false,
    ParryRange = 13,
    Delay      = 0.10,
    ParryCount = 0,
}

-- ══════════════════════════════════════════
-- UI BUILDER
-- ══════════════════════════════════════════

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- destroy old UI
local oldGui = CoreGui:FindFirstChild("AlphaParryUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "AlphaParryUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
ScreenGui.Parent          = CoreGui

-- ─────────────────────────────────────────
-- THEME
-- ─────────────────────────────────────────

local T = {
    bg        = Color3.fromRGB(10,  10,  14),
    panel     = Color3.fromRGB(18,  18,  24),
    card      = Color3.fromRGB(24,  24,  32),
    border    = Color3.fromRGB(45,  45,  60),
    accent    = Color3.fromRGB(120, 80, 255),   -- violet
    accentDim = Color3.fromRGB(70,  45, 160),
    green     = Color3.fromRGB(50,  220, 120),
    red       = Color3.fromRGB(220, 70,  80),
    text      = Color3.fromRGB(220, 220, 235),
    sub       = Color3.fromRGB(130, 130, 155),
    white     = Color3.fromRGB(255, 255, 255),
}

-- ─────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────

local function make(cls, props, parent)
    local obj = Instance.new(cls)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local ti_fast   = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ti_medium = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(r, p)
    make("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end
local function stroke(t, c, p)
    make("UIStroke", {Thickness = t, Color = c, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end
local function pad(l, r, t, b, p)
    make("UIPadding", {
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
    }, p)
end

-- ─────────────────────────────────────────
-- MAIN WINDOW
-- ─────────────────────────────────────────

local W = isMobile and 300 or 340
local H_base = isMobile and 380 or 420

local Window = make("Frame", {
    Size            = UDim2.new(0, W, 0, H_base),
    Position        = UDim2.new(0, 20, 0.5, -H_base/2),
    BackgroundColor3 = T.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)
corner(16, Window)
stroke(1, T.border, Window)

-- subtle glow behind window
local Glow = make("ImageLabel", {
    Size              = UDim2.new(1, 80, 1, 80),
    Position          = UDim2.new(0, -40, 0, -40),
    BackgroundTransparency = 1,
    Image             = "rbxassetid://5028857472",
    ImageColor3       = T.accent,
    ImageTransparency = 0.85,
    ZIndex            = -1,
}, Window)

-- ─────────────────────────────────────────
-- TITLE BAR
-- ─────────────────────────────────────────

local TitleBar = make("Frame", {
    Size             = UDim2.new(1, 0, 0, isMobile and 52 or 58),
    BackgroundColor3 = T.panel,
    BorderSizePixel  = 0,
}, Window)
corner(16, TitleBar)

-- bottom-flatten the top bar
make("Frame", {
    Size             = UDim2.new(1, 0, 0, 16),
    Position         = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = T.panel,
    BorderSizePixel  = 0,
}, TitleBar)

-- accent strip
local Strip = make("Frame", {
    Size             = UDim2.new(0, 4, 0, 28),
    Position         = UDim2.new(0, 14, 0.5, -14),
    BackgroundColor3 = T.accent,
    BorderSizePixel  = 0,
}, TitleBar)
corner(4, Strip)

make("TextLabel", {
    Size             = UDim2.new(1, -40, 1, 0),
    Position         = UDim2.new(0, 28, 0, 0),
    BackgroundTransparency = 1,
    Text             = "ALPHA SYSTEM",
    TextColor3       = T.white,
    Font             = Enum.Font.GothamBold,
    TextSize         = isMobile and 15 or 17,
    TextXAlignment   = Enum.TextXAlignment.Left,
}, TitleBar)

make("TextLabel", {
    Size             = UDim2.new(0, 80, 1, 0),
    Position         = UDim2.new(1, -88, 0, 0),
    BackgroundTransparency = 1,
    Text             = "Blade Ball",
    TextColor3       = T.sub,
    Font             = Enum.Font.Gotham,
    TextSize         = isMobile and 11 or 12,
    TextXAlignment   = Enum.TextXAlignment.Right,
}, TitleBar)

-- ─────────────────────────────────────────
-- SCROLL CONTENT
-- ─────────────────────────────────────────

local Content = make("ScrollingFrame", {
    Size                  = UDim2.new(1, 0, 1, -(isMobile and 52 or 58)),
    Position              = UDim2.new(0, 0, 0, isMobile and 52 or 58),
    BackgroundTransparency = 1,
    BorderSizePixel       = 0,
    ScrollBarThickness    = 3,
    ScrollBarImageColor3  = T.accentDim,
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    ScrollingDirection    = Enum.ScrollingDirection.Y,
}, Window)
pad(14, 14, 14, 14, Content)
make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 10),
}, Content)

-- ─────────────────────────────────────────
-- STATUS CARD
-- ─────────────────────────────────────────

local StatusCard = make("Frame", {
    Size             = UDim2.new(1, 0, 0, isMobile and 70 or 80),
    BackgroundColor3 = T.card,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
}, Content)
corner(12, StatusCard)
stroke(1, T.border, StatusCard)

local StatusDot = make("Frame", {
    Size             = UDim2.new(0, 10, 0, 10),
    Position         = UDim2.new(0, 16, 0.5, -5),
    BackgroundColor3 = T.red,
    BorderSizePixel  = 0,
}, StatusCard)
corner(99, StatusDot)

local StatusLabel = make("TextLabel", {
    Size             = UDim2.new(1, -40, 0, 22),
    Position         = UDim2.new(0, 34, 0, 14),
    BackgroundTransparency = 1,
    Text             = "Auto Parry  —  OFF",
    TextColor3       = T.text,
    Font             = Enum.Font.GothamBold,
    TextSize         = isMobile and 14 or 15,
    TextXAlignment   = Enum.TextXAlignment.Left,
}, StatusCard)

local CountLabel = make("TextLabel", {
    Size             = UDim2.new(1, -34, 0, 18),
    Position         = UDim2.new(0, 34, 0, 40),
    BackgroundTransparency = 1,
    Text             = "Parries: 0",
    TextColor3       = T.sub,
    Font             = Enum.Font.Gotham,
    TextSize         = isMobile and 11 or 12,
    TextXAlignment   = Enum.TextXAlignment.Left,
}, StatusCard)

local ReadyLabel = make("TextLabel", {
    Size             = UDim2.new(0, 80, 0, 18),
    Position         = UDim2.new(1, -90, 0, 14),
    BackgroundTransparency = 1,
    Text             = "● Waiting",
    TextColor3       = T.sub,
    Font             = Enum.Font.Gotham,
    TextSize         = isMobile and 11 or 12,
    TextXAlignment   = Enum.TextXAlignment.Right,
}, StatusCard)

-- ─────────────────────────────────────────
-- TOGGLE BUTTON
-- ─────────────────────────────────────────

local ToggleBtn = make("TextButton", {
    Size             = UDim2.new(1, 0, 0, isMobile and 50 or 56),
    BackgroundColor3 = T.accentDim,
    BorderSizePixel  = 0,
    Text             = "Enable Auto Parry",
    TextColor3       = T.white,
    Font             = Enum.Font.GothamBold,
    TextSize         = isMobile and 14 or 15,
    LayoutOrder      = 2,
    AutoButtonColor  = false,
}, Content)
corner(12, ToggleBtn)

local function updateToggleUI()
    if Config.AutoParry then
        tween(ToggleBtn, ti_fast, {BackgroundColor3 = T.accent})
        ToggleBtn.Text        = "Disable Auto Parry"
        StatusLabel.Text      = "Auto Parry  —  ON"
        StatusLabel.TextColor3 = T.green
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.green})
    else
        tween(ToggleBtn, ti_fast, {BackgroundColor3 = T.accentDim})
        ToggleBtn.Text        = "Enable Auto Parry"
        StatusLabel.Text      = "Auto Parry  —  OFF"
        StatusLabel.TextColor3 = T.text
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.red})
    end
end

ToggleBtn.MouseEnter:Connect(function()
    tween(ToggleBtn, ti_fast, {
        BackgroundColor3 = Config.AutoParry and T.accent or Color3.fromRGB(90, 55, 200)
    })
end)
ToggleBtn.MouseLeave:Connect(function()
    tween(ToggleBtn, ti_fast, {
        BackgroundColor3 = Config.AutoParry and T.accent or T.accentDim
    })
end)
ToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoParry = not Config.AutoParry
    updateToggleUI()
    -- click pulse
    tween(ToggleBtn, TweenInfo.new(0.08), {BackgroundColor3 = T.white})
    task.wait(0.08)
    tween(ToggleBtn, ti_fast, {BackgroundColor3 = Config.AutoParry and T.accent or T.accentDim})
end)

-- ─────────────────────────────────────────
-- SLIDER BUILDER
-- ─────────────────────────────────────────

local function makeSlider(parent, title, min, max, val, decimals, order, onChange)
    local Card = make("Frame", {
        Size             = UDim2.new(1, 0, 0, isMobile and 68 or 76),
        BackgroundColor3 = T.card,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
    }, parent)
    corner(12, Card)
    stroke(1, T.border, Card)
    pad(14, 14, 10, 10, Card)

    local TitleLbl = make("TextLabel", {
        Size             = UDim2.new(1, -60, 0, 20),
        BackgroundTransparency = 1,
        Text             = title,
        TextColor3       = T.text,
        Font             = Enum.Font.GothamBold,
        TextSize         = isMobile and 12 or 13,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, Card)

    local ValLbl = make("TextLabel", {
        Size             = UDim2.new(0, 55, 0, 20),
        Position         = UDim2.new(1, -55, 0, 0),
        BackgroundTransparency = 1,
        Text             = tostring(val),
        TextColor3       = T.accent,
        Font             = Enum.Font.GothamBold,
        TextSize         = isMobile and 12 or 13,
        TextXAlignment   = Enum.TextXAlignment.Right,
    }, Card)

    local Track = make("Frame", {
        Size             = UDim2.new(1, 0, 0, 6),
        Position         = UDim2.new(0, 0, 0, isMobile and 34 or 38),
        BackgroundColor3 = T.border,
        BorderSizePixel  = 0,
    }, Card)
    corner(99, Track)

    local Fill = make("Frame", {
        Size             = UDim2.new((val - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = T.accent,
        BorderSizePixel  = 0,
    }, Track)
    corner(99, Fill)

    local Knob = make("Frame", {
        Size             = UDim2.new(0, 18, 0, 18),
        Position         = UDim2.new((val - min) / (max - min), -9, 0.5, -9),
        BackgroundColor3 = T.white,
        BorderSizePixel  = 0,
    }, Track)
    corner(99, Knob)
    stroke(2, T.accent, Knob)

    local dragging = false
    local currentVal = val

    local function setVal(abs_x)
        local rel   = math.clamp((abs_x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        currentVal  = min + (max - min) * rel
        local fmt   = decimals > 0 and ("%." .. decimals .. "f") or "%d"
        if decimals == 0 then currentVal = math.round(currentVal) end
        ValLbl.Text = string.format(fmt, currentVal)
        tween(Fill,  ti_fast, {Size     = UDim2.new(rel, 0, 1, 0)})
        tween(Knob,  ti_fast, {Position = UDim2.new(rel, -9, 0.5, -9)})
        onChange(currentVal)
    end

    Track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setVal(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or
           inp.UserInputType == Enum.UserInputType.Touch then
            setVal(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or
           inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return Card
end

-- Range Slider
makeSlider(Content, "Parry Range (studs)", 5, 40, Config.ParryRange, 0, 3, function(v)
    Config.ParryRange = v
end)

-- Delay Slider
makeSlider(Content, "Reaction Delay (s)", 0, 0.5, Config.Delay, 2, 4, function(v)
    Config.Delay = v
end)

-- ─────────────────────────────────────────
-- SECTION LABEL
-- ─────────────────────────────────────────

local function sectionLabel(txt, order)
    local L = make("TextLabel", {
        Size             = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text             = txt,
        TextColor3       = T.sub,
        Font             = Enum.Font.GothamBold,
        TextSize         = isMobile and 10 or 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
        LayoutOrder      = order,
    }, Content)
    return L
end

sectionLabel("KEYBINDS", 5)

-- ─────────────────────────────────────────
-- KEYBIND INFO CARD
-- ─────────────────────────────────────────

local KeyCard = make("Frame", {
    Size             = UDim2.new(1, 0, 0, isMobile and 52 or 60),
    BackgroundColor3 = T.card,
    BorderSizePixel  = 0,
    LayoutOrder      = 6,
}, Content)
corner(12, KeyCard)
stroke(1, T.border, KeyCard)
pad(14, 14, 10, 10, KeyCard)

make("UIListLayout", {
    SortOrder       = Enum.SortOrder.LayoutOrder,
    Padding         = UDim.new(0, 6),
    FillDirection   = Enum.FillDirection.Vertical,
}, KeyCard)

local function keyRow(key, desc, order)
    local Row = make("Frame", {
        Size             = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder      = order,
    }, KeyCard)
    local Tag = make("TextLabel", {
        Size             = UDim2.new(0, 28, 1, 0),
        BackgroundColor3 = T.accentDim,
        Text             = key,
        TextColor3       = T.white,
        Font             = Enum.Font.GothamBold,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Center,
    }, Row)
    corner(6, Tag)
    make("TextLabel", {
        Size             = UDim2.new(1, -36, 1, 0),
        Position         = UDim2.new(0, 36, 0, 0),
        BackgroundTransparency = 1,
        Text             = desc,
        TextColor3       = T.sub,
        Font             = Enum.Font.Gotham,
        TextSize         = isMobile and 11 or 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, Row)
end

keyRow("P", "Toggle Auto Parry", 1)
keyRow("H", "Hide / Show UI", 2)

-- ─────────────────────────────────────────
-- DRAGGABLE WINDOW
-- ─────────────────────────────────────────

local draggingWin, dragStart, startPos

TitleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = true
        dragStart   = inp.Position
        startPos    = Window.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if draggingWin and (
        inp.UserInputType == Enum.UserInputType.MouseMovement or
        inp.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = inp.Position - dragStart
        Window.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = false
    end
end)

-- ─────────────────────────────────────────
-- OPEN / CLOSE ANIMATION
-- ─────────────────────────────────────────

local visible = true
local function toggleUI()
    visible = not visible
    tween(Window, ti_medium, {
        Size = visible
            and UDim2.new(0, W, 0, H_base)
            or  UDim2.new(0, W, 0, isMobile and 52 or 58),
    })
end

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.P then
        Config.AutoParry = not Config.AutoParry
        updateToggleUI()
    end
    if inp.KeyCode == Enum.KeyCode.H then
        toggleUI()
    end
end)

-- ══════════════════════════════════════════
-- MAIN PARRY LOOP
-- ══════════════════════════════════════════

local lastParry = 0

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getBalls()
    local balls = {}
    for _, obj in ipairs(workspace_s:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("blade") or n:find("ball") then
                table.insert(balls, obj)
            end
        end
    end
    return balls
end

-- ready indicator update
RunService.Heartbeat:Connect(function()
    -- update ready label
    if _PARRY_PATCH.ready then
        ReadyLabel.Text      = "● Ready"
        ReadyLabel.TextColor3 = T.green
    else
        ReadyLabel.Text      = "● Waiting"
        ReadyLabel.TextColor3 = T.sub
    end

    if not Config.AutoParry then return end
    local root = getRoot()
    if not root then return end
    local now = tick()
    if (now - lastParry) < 0.1 then return end
    if not _PARRY_PATCH.ready then return end

    for _, ball in ipairs(getBalls()) do
        if ball and ball.Parent then
            local dist = (ball.Position - root.Position).Magnitude
            if dist <= Config.ParryRange then
                lastParry = now
                if Config.Delay > 0 then task.wait(Config.Delay) end
                local cf  = root.CFrame
                local mid = workspace_s.CurrentCamera.ViewportSize / 2
                local fired = _PARRY_FIRE(cf, {}, Vector2.new(mid.X, mid.Y))
                if fired then
                    Config.ParryCount += 1
                    CountLabel.Text = "Parries: " .. Config.ParryCount
                    -- flash dot
                    tween(StatusDot, TweenInfo.new(0.05), {BackgroundColor3 = T.white})
                    task.delay(0.1, function()
                        tween(StatusDot, ti_fast, {BackgroundColor3 = T.green})
                    end)
                end
                break
            end
        end
    end
end)

-- ══════════════════════════════════════════
-- EXPORT
-- ══════════════════════════════════════════

getgenv().AlphaParry = {
    Config     = Config,
    ParryPatch = _PARRY_PATCH,
    Fire       = _PARRY_FIRE,
    ToggleUI   = toggleUI,
}

print("[ALPHA SYSTEM] UI loaded | P = parry toggle | H = hide")
