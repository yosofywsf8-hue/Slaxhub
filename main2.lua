-- ============================================================
-- BLADE BALL — FULL AUTO-PARRY + DIAGNOSTIC
-- Kalau nggak jalan, cek console: [BB] prefix
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")
local CoreGui    = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local EXEC_NAME = "unknown"
if type(identifyexecutor) == "function" then
    local ok, n = pcall(identifyexecutor)
    if ok then EXEC_NAME = tostring(n) end
end

local function log(...) print("[BB]", ...) end
log("=== START ===")
log("executor:", EXEC_NAME)
log("getupvalues:", type(getupvalues), "| debug.getupvalues:", type(debug) == "table" and type(debug.getupvalues))
log("getrawmetatable:", type(getrawmetatable))
log("setreadonly:", type(setreadonly))

-- ============================================================
-- STEP 1: LOAD PRY UPVALUES
-- ============================================================
local _PARRY_PATCH = {
    keyTable = nil, transformFn = nil, parryHash = nil,
    parryRemote = nil, ready = false,
}

task.spawn(function()
    local ok, err = pcall(function()
        local Controllers = RS:WaitForChild("Controllers", 20)
        if not Controllers then error("Controllers folder not found") end

        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 16) == "SwordsController" then SC = child break end
        end
        if not SC then error("SwordsController not found") end
        log("SwordsController:", SC:GetFullName())

        local PRY = SC:WaitForChild("PRY", 20)
        if not PRY then error("PRY module not found") end
        log("PRY:", PRY:GetFullName())

        local Parry_Function = require(PRY)
        local getupvals = (type(debug) == "table" and debug.getupvalues) or getupvalues
        if not getupvals then error("no getupvalues on this executor") end

        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then error("upvalue count < 8, got: " .. tostring(ups and #ups)) end
        log("upvalues count:", #ups)

        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        log("keyTable:", typeof(_PARRY_PATCH.keyTable))
        log("transformFn:", typeof(_PARRY_PATCH.transformFn))
        log("parryHash:", tostring(_PARRY_PATCH.parryHash):sub(1, 20))
    end)
    if not ok then warn("[BB] patch init FAILED:", tostring(err)) end
end)

-- ============================================================
-- STEP 2: HOOK REMOTES untuk cari yang cocok
-- ============================================================
local _reverted = {}

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
    if _reverted[remote] then return end
    local mt = getrawmetatable(remote)
    if not mt or mt.__bb_hooked then return end
    local ok = pcall(function()
        setreadonly(mt, false)
        local _old = mt.__index
        mt.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent'))
                or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                        _PARRY_PATCH.ready = true
                        _PARRY_PATCH.parryRemote = self
                        log("REMOTE MATCH:", self:GetFullName())
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        mt.__bb_hooked = true
        setreadonly(mt, true)
    end)
end

task.spawn(function()
    for _, _remote in ipairs(RS:GetDescendants()) do
        if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
            pcall(_hook, _remote)
        end
    end
    log("hooked all remotes, waiting for match on first parry...")
end)

-- ============================================================
-- STEP 3: FIRE PARRY
-- ============================================================
local function fire_parry(curveCF, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false, "not ready" end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false, "no keyTable" end
    local keyIndex = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
    if not currentKey then return false, "no currentKey" end

    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false, "transform failed" end
    end

    local serverTime = WS:GetServerTimeNow() * 100
    local timeStr = tostring(math.floor(serverTime))
    local tc = {}
    for i = 1, #timeStr do
        local ki = (i - 1) % #transformed + 1
        local kb = string.byte(transformed, ki)
        local tb = (string.byte(timeStr, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)

    local ok = pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash,
            currentKey,
            token,
            0.5,
            curveCF,
            screenPositions,
            mouseLocation,
            false
        )
    end)
    return ok
end

-- ============================================================
-- STEP 4: BALL + CURVE
-- ============================================================
local function get_real_ball()
    local balls = WS:FindFirstChild('Balls')
    if not balls then return nil end
    for _, ball in ipairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then
            ball.CanCollide = false
            return ball
        end
    end
    return nil
end

-- ============================================================
-- STEP 5: AUTO-PARRY LOOP
-- ============================================================
local CFG = { enabled = false, accuracy = 1.0, divisor = 1.0, speedFactor = 0.002, baseDivisor = 2.4, cooldown = 0.4 }
local State = { parried = false, parries = 0, lastFire = 0, lastLog = 0 }

local function execute_parry()
    local cam = WS.CurrentCamera
    if not LP.Character then return false end

    local screenPositions = {}
    local alive = WS:FindFirstChild('Alive')
    if alive then
        for _, entity in ipairs(alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                if ok then screenPositions[entity.Name] = sp end
            end
        end
    end

    local ok, mouse = pcall(function() return UIS:GetMouseLocation() end)
    local mouseLocation
    if ok and mouse then mouseLocation = {mouse.X, mouse.Y}
    else
        local vp = cam.ViewportSize
        mouseLocation = {vp.X/2, vp.Y/2}
    end

    return fire_parry(cam.CFrame, screenPositions, mouseLocation)
end

RunService.PreSimulation:Connect(function()
    if not CFG.enabled then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end
    if not _PARRY_PATCH.ready then return end
    if State.parried then return end
    if tick() - State.lastFire < CFG.cooldown then return end

    local ball = get_real_ball()
    if not ball then return end
    local zoomies = ball:FindFirstChild('zoomies')
    if not zoomies then return end

    local target = ball:GetAttribute('target')
    if target ~= LP.Name then return end

    local speed = zoomies.VectorVelocity.Magnitude
    local distance = (LP.Character.PrimaryPart.Position - ball.Position).Magnitude

    local ping = 0
    pcall(function() ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10 end)
    local ping_threshold = math.clamp(ping / 10, 5, 17)
    local capped = math.min(math.max(speed - 9.5, 0), 650)
    local speed_div = (CFG.baseDivisor + capped * CFG.speedFactor) * CFG.divisor
    local accuracy = (ping_threshold + math.max(speed / speed_div, 9.5)) * CFG.accuracy

    -- log tiap 0.5 detik
    if tick() - State.lastLog > 0.5 then
        State.lastLog = tick()
        log(string.format("ball target=you | speed=%.1f dist=%.1f acc=%.1f", speed, distance, accuracy))
    end

    if distance <= accuracy then
        local ok, err = execute_parry()
        if ok then
            State.parried = true
            State.parries = State.parries + 1
            State.lastFire = tick()
            log("PARRY #" .. State.parries)
            task.delay(CFG.cooldown, function() State.parried = false end)
        else
            log("fire failed:", err)
        end
    end
end)

-- ============================================================
-- UI
-- ============================================================
local function make(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end

local gui = make("ScreenGui", { Name = "BBParry", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, {})
local okp = pcall(function() gui.Parent = CoreGui end)
if not okp then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = make("Frame", {
    Size = UDim2.new(0, 260, 0, 190),
    Position = UDim2.new(0.05, 0, 0.3, 0),
    BackgroundColor3 = Color3.fromRGB(16, 16, 20),
    BorderSizePixel = 0, Active = true, Draggable = true,
}, {})
main.Parent = gui
make("UICorner", { CornerRadius = UDim.new(0, 10) }, {}).Parent = main
make("UIStroke", { Color = Color3.fromRGB(60, 60, 70) }, {}).Parent = main

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(26, 26, 32),
    Text = "AUTO-PARRY",
    TextColor3 = Color3.fromRGB(255, 90, 90),
    Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0,
}, {}).Parent = main

local content = make("Frame", {
    Size = UDim2.new(1, -20, 1, -44),
    Position = UDim2.new(0, 10, 0, 38),
    BackgroundTransparency = 1,
}, {})
content.Parent = main
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, {}).Parent = content

local toggleBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(200, 80, 80),
    Text = "AUTO-PARRY: OFF",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, LayoutOrder = 1,
}, {})
toggleBtn.Parent = content
make("UICorner", { CornerRadius = UDim.new(0, 6) }, {}).Parent = toggleBtn

toggleBtn.MouseButton1Click:Connect(function()
    CFG.enabled = not CFG.enabled
    toggleBtn.Text = "AUTO-PARRY: " .. (CFG.enabled and "ON" or "OFF")
    toggleBtn.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
    log("toggle:", CFG.enabled)
end)

local function slider(label, key, min, max, step, order)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Color3.fromRGB(26, 26, 32),
        BorderSizePixel = 0, LayoutOrder = order,
    }, {})
    row.Parent = content
    make("UICorner", { CornerRadius = UDim.new(0, 6) }, {}).Parent = row

    local lbl = make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = string.format("%s: %.2f", label, CFG[key]),
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    }, {})
    lbl.Parent = row

    local track = make("Frame", {
        Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 28),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0,
    }, {})
    track.Parent = row
    make("UICorner", { CornerRadius = UDim.new(0, 3) }, {}).Parent = track

    local fill = make("Frame", {
        Size = UDim2.new((CFG[key] - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 90, 90), BorderSizePixel = 0,
    }, {})
    fill.Parent = track
    make("UICorner", { CornerRadius = UDim.new(0, 3) }, {}).Parent = fill

    local drag = false
    local function upd(i)
        local x = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * x
        v = math.floor(v / step + 0.5) * step
        CFG[key] = v
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        lbl.Text = string.format("%s: %.2f", label, v)
    end
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true upd(i) end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
end

slider("Accuracy", "accuracy", 0.5, 2.0, 0.05, 2)
slider("Divisor", "divisor", 0.5, 2.0, 0.05, 3)

local status = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    Text = "status: loading...",
    TextColor3 = Color3.fromRGB(180, 180, 200),
    Font = Enum.Font.Code, TextSize = 10, BorderSizePixel = 0, LayoutOrder = 4,
}, {})
status.Parent = content
make("UICorner", { CornerRadius = UDim.new(0, 6) }, {}).Parent = status

task.spawn(function()
    while gui.Parent do
        if _PARRY_PATCH.ready then
            status.Text = string.format("ready | parries: %d\nhash: %s", State.parries, tostring(_PARRY_PATCH.parryHash):sub(1, 16))
            status.TextColor3 = Color3.fromRGB(120, 220, 140)
        else
            status.Text = "loading upvalues..."
            status.TextColor3 = Color3.fromRGB(220, 180, 80)
        end
        task.wait(0.2)
    end
end)

log("=== LOADED ===")
log("executor:", EXEC_NAME)
log("check console kalau ada yang error")
