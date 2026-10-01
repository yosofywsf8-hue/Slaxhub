-- ============================================================
-- Blade Ball — AUTO-PARRY (pakai _PARRY_PATCH upvalue pattern)
-- Sumber: SwordsController.PRY upvalues (keyTable, transformFn, parryHash)
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")

local LP = Players.LocalPlayer

-- ============================================================
-- PARRY PATCH — ambil upvalues dari SwordsController.PRY
-- ============================================================
local _PARRY_PATCH = {
    keyTable     = nil,
    transformFn  = nil,
    parryHash    = nil,
    parryRemote  = nil,
    ready        = false,
}

task.spawn(function()
    local ok, err = pcall(function()
        local Controllers = RS:WaitForChild("Controllers", 15)
        if not Controllers then return end

        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 16) == "SwordsController" then
                SC = child
                break
            end
        end
        if not SC then
            warn("[PARRY PATCH] SwordsController not found")
            return
        end

        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then
            warn("[PARRY PATCH] PRY module not found")
            return
        end

        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then
            warn("[PARRY PATCH] executor missing getupvalues")
            return
        end

        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then
            warn("[PARRY PATCH] unexpected upvalue count")
            return
        end

        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        print("[PARRY PATCH] upvalues loaded")
    end)
    if not ok then warn("[PARRY PATCH] init error:", tostring(err)) end
end)

-- ============================================================
-- HOOK remote — cari remote yang cocok signature parry
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
    if not mt or mt.__parry_patch_hooked then return end
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
                end
                return _old(self, key)(_, unpack(_arguments))
            end
        end
        return _old(self, key)
    end
    mt.__parry_patch_hooked = true
    setreadonly(mt, true)
end

for _, _remote in pairs(RS:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        pcall(_hook, _remote)
    end
end

-- ============================================================
-- FIRE — bangun token + kirim parry
-- ============================================================
local function fire_parry(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end

    local keyIndex = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
    if not currentKey then return false end

    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false end
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
            curveCFrame,
            screenPositions,
            mouseLocation,
            false
        )
    end)
    return ok
end

-- ============================================================
-- BALL TRACKING + CURVE
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

local function get_closest_to_cursor()
    local char = LP.Character
    if not char or not char:FindFirstChild('HumanoidRootPart') then return nil end
    local cam = WS.CurrentCamera
    local ok, mouse = pcall(function() return UIS:GetMouseLocation() end)
    if not ok then return nil end
    local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    local best, bestDot = nil, -math.huge
    local alive = WS:FindFirstChild('Alive')
    if not alive then return nil end
    for _, plr in ipairs(alive:GetChildren()) do
        if plr ~= char and plr:FindFirstChild('HumanoidRootPart') then
            local dir = (plr.HumanoidRootPart.Position - cam.CFrame.Position).Unit
            local dot = pointer.LookVector:Dot(dir)
            if dot > bestDot then bestDot, best = dot, plr end
        end
    end
    return best
end

local function build_curve_cframe()
    local cam = WS.CurrentCamera
    local char = LP.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root then return cam.CFrame end
    local target = get_closest_to_cursor()
    local targetPart = target and target:FindFirstChild('HumanoidRootPart')
    local targetPos = targetPart and targetPart.Position or (root.Position + cam.CFrame.LookVector * 100)
    -- curve mode Camera = pakai camera CFrame langsung
    return cam.CFrame
end

-- ============================================================
-- AUTO-PARRY LOOP
-- ============================================================
local CFG = {
    enabled     = false,
    accuracy    = 1.0,
    cooldown    = 0.15,
    divisor     = 1.0,
    speedFactor = 0.002,
    baseDivisor = 2.4,
}

local State = {
    parried = false,
    parries = 0,
    lastFire = 0,
}

local function execute_parry()
    local cam = WS.CurrentCamera
    local char = LP.Character
    if not char then return end

    local screenPositions = {}
    local alive = WS:FindFirstChild('Alive')
    if alive then
        for _, entity in ipairs(alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function()
                    return cam:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if ok then screenPositions[entity.Name] = sp end
            end
        end
    end

    local ok, mouse = pcall(function() return UIS:GetMouseLocation() end)
    local mouseLocation
    if ok and mouse then
        mouseLocation = {mouse.X, mouse.Y}
    else
        local vp = cam.ViewportSize
        mouseLocation = {vp.X / 2, vp.Y / 2}
    end

    local curveCF = build_curve_cframe()
    return fire_parry(curveCF, screenPositions, mouseLocation)
end

RunService.PreSimulation:Connect(function()
    if not CFG.enabled then return end
    if not LP.Character or not LP.Character.PrimaryPart then return end

    local ball = get_real_ball()
    if not ball then return end

    local zoomies = ball:FindFirstChild('zoomies')
    if not zoomies then return end

    if State.parried then return end

    local ball_target = ball:GetAttribute('target')
    if ball_target ~= LP.Name then return end

    local velocity = zoomies.VectorVelocity
    local speed = velocity.Magnitude
    local distance = (LP.Character.PrimaryPart.Position - ball.Position).Magnitude

    local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
    local ping_threshold = math.clamp(ping / 10, 5, 17)
    local capped_speed_diff = math.min(math.max(speed - 9.5, 0), 650)
    local speed_divisor = (CFG.baseDivisor + capped_speed_diff * CFG.speedFactor) * CFG.divisor
    local parry_accuracy = ping_threshold + math.max(speed / speed_divisor, 9.5)
    parry_accuracy = parry_accuracy * CFG.accuracy

    if distance <= parry_accuracy then
        if execute_parry() then
            State.parried = true
            State.parries = State.parries + 1
            State.lastFire = tick()
            task.delay(1, function() State.parried = false end)
        end
    end
end)

-- ============================================================
-- UI (simple, bersih)
-- ============================================================
local function make(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local gui = make("ScreenGui", {
    Name = "BBParryPatch",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, {})
local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okp then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = make("Frame", {
    Size = UDim2.new(0, 260, 0, 200),
    Position = UDim2.new(0.05, 0, 0.3, 0),
    BackgroundColor3 = Color3.fromRGB(16, 16, 20),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, {})
main.Parent = gui
make("UICorner", {CornerRadius = UDim.new(0, 10)}, {}).Parent = main
make("UIStroke", {Color = Color3.fromRGB(60, 60, 70)}, {}).Parent = main

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(26, 26, 32),
    Text = "PARRY PATCH",
    TextColor3 = Color3.fromRGB(255, 90, 90),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BorderSizePixel = 0,
}, {}).Parent = main

local content = make("Frame", {
    Size = UDim2.new(1, -20, 1, -44),
    Position = UDim2.new(0, 10, 0, 38),
    BackgroundTransparency = 1,
}, {})
content.Parent = main
make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, {}).Parent = content

-- Toggle button
local toggleBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(60, 200, 100),
    Text = "AUTO-PARRY: OFF",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BorderSizePixel = 0,
    LayoutOrder = 1,
}, {})
toggleBtn.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = toggleBtn

toggleBtn.MouseButton1Click:Connect(function()
    CFG.enabled = not CFG.enabled
    toggleBtn.Text = "AUTO-PARRY: " .. (CFG.enabled and "ON" or "OFF")
    toggleBtn.BackgroundColor3 = CFG.enabled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(200, 80, 80)
end)

-- Accuracy slider
local function sliderRow(label, key, min, max, step, order)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Color3.fromRGB(26, 26, 32),
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, {})
    row.Parent = content
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = row

    local lbl = make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = string.format("%s: %.2f", label, CFG[key]),
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, {})
    lbl.Parent = row

    local track = make("Frame", {
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 0, 28),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        BorderSizePixel = 0,
    }, {})
    track.Parent = row
    make("UICorner", {CornerRadius = UDim.new(0, 3)}, {}).Parent = track

    local pct = (CFG[key] - min) / (max - min)
    local fill = make("Frame", {
        Size = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 90, 90),
        BorderSizePixel = 0,
    }, {})
    fill.Parent = track
    make("UICorner", {CornerRadius = UDim.new(0, 3)}, {}).Parent = fill

    local dragging = false
    local function update(input)
        local abs = track.AbsolutePosition.X
        local size = track.AbsoluteSize.X
        local x = math.clamp((input.Position.X - abs) / size, 0, 1)
        local val = min + (max - min) * x
        val = math.floor(val / step + 0.5) * step
        CFG[key] = val
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        lbl.Text = string.format("%s: %.2f", label, val)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            update(i)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

sliderRow("Accuracy",    "accuracy",    0.5, 2.0, 0.05, 2)
sliderRow("Divisor",     "divisor",     0.5, 2.0, 0.05, 3)
sliderRow("Speed Factor","speedFactor", 0.0, 0.01, 0.0005, 4)

-- Status
local statusLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    Text = "status: loading...",
    TextColor3 = Color3.fromRGB(180, 180, 200),
    Font = Enum.Font.Code,
    TextSize = 10,
    BorderSizePixel = 0,
    LayoutOrder = 5,
}, {})
statusLabel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = statusLabel

task.spawn(function()
    while gui.Parent do
        if _PARRY_PATCH.ready then
            statusLabel.Text = string.format("ready | parries: %d | hash: %s",
                State.parries,
                tostring(_PARRY_PATCH.parryHash):sub(1, 12) .. "...")
            statusLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
        else
            statusLabel.Text = "loading upvalues..."
            statusLabel.TextColor3 = Color3.fromRGB(220, 180, 80)
        end
        task.wait(0.2)
    end
end)

print("[PARRY PATCH AUTO] loaded")
