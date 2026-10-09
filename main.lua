-- ALPHA SYSTEM | Blade Ball — Auto Parry + Auto Spam + UI
-- مستخرج من الملف الأصلي

-- ══════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════

local Players            = cloneref(game:GetService('Players'))
local RunService         = cloneref(game:GetService('RunService'))
local UIS                = cloneref(game:GetService('UserInputService'))
local TweenService       = cloneref(game:GetService('TweenService'))
local workspace_s        = cloneref(game:GetService('Workspace'))
local ReplicatedStorage  = cloneref(game:GetService('ReplicatedStorage'))
local CoreGui            = cloneref(game:GetService('CoreGui'))
local Stats              = cloneref(game:GetService('Stats'))

local LocalPlayer = Players.LocalPlayer
local isMobile    = UIS.TouchEnabled and not UIS.MouseEnabled

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
        if not SC then warn("[PARRY] SwordsController not found") return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then warn("[PARRY] PRY not found") return end
        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then warn("[PARRY] missing getupvalues") return end
        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then warn("[PARRY] unexpected upvalue count") return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        _PARRY_PATCH.ready       = true
        print("[PARRY] PRY loaded")
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
                if _is_valid(_arguments) and not _reverted[self] then
                    _reverted[self]          = _arguments
                    _PARRY_PATCH.ready       = true
                    _PARRY_PATCH.parryRemote = self
                end
                return _old(self, key)(_, unpack(_arguments))
            end
        end
        return _old(self, key)
    end
    setreadonly(_meta, true)
end

for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
    if remote:IsA('RemoteEvent') or remote:IsA('RemoteFunction') then
        _hook(remote)
    end
end

_PARRY_PATCH.fire = function(curveCFrame, screenPositions, mouseLocation)
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
-- SYSTEM CORE (من الملف)
-- ══════════════════════════════════════════

local Alive = workspace_s:FindFirstChild("Alive") or workspace_s:WaitForChild("Alive", 10)

local System = {
    __properties = {
        __autoparry_enabled    = false,
        __manual_spam_enabled  = false,
        __auto_spam_enabled    = false,
        __parries              = 0,
        __spam_accumulator     = 0,
        __spam_rate            = 1000,
        __spam_threshold       = 1.5,
        __curve_mode           = 1,
        __connections          = {},
        __is_mobile            = isMobile,
        __slashesoffury_active = false,
    }
}

-- ─────────────────────────────────────────
-- BALL
-- ─────────────────────────────────────────

System.ball = {}

function System.ball.get()
    local balls = workspace_s:FindFirstChild('Balls')
    if not balls then return nil end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then
            ball.CanCollide = false
            return ball
        end
    end
    return nil
end

-- ─────────────────────────────────────────
-- PLAYER
-- ─────────────────────────────────────────

System.player = {}
local Closest_Entity = nil

function System.player.get_closest()
    local max_dist = math.huge
    local closest  = nil
    if not Alive then return nil end
    for _, entity in pairs(Alive:GetChildren()) do
        if entity ~= LocalPlayer.Character and entity.PrimaryPart then
            local dist = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
            if dist < max_dist then
                max_dist = dist
                closest  = entity
            end
        end
    end
    Closest_Entity = closest
    return closest
end

function System.player.get_closest_to_cursor()
    if not LocalPlayer.Character then return nil end
    local closest_player = nil
    local minimal_dot    = -math.huge
    local camera         = workspace_s.CurrentCamera
    if not Alive then return nil end
    local ok, mouse_location = pcall(function() return UIS:GetMouseLocation() end)
    if not ok then return nil end
    local ray = camera:ScreenPointToRay(mouse_location.X, mouse_location.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    for _, player in pairs(Alive:GetChildren()) do
        if player == LocalPlayer.Character then continue end
        if not player:FindFirstChild('HumanoidRootPart') then continue end
        local direction = (player.HumanoidRootPart.Position - camera.CFrame.Position).Unit
        local dot = pointer.LookVector:Dot(direction)
        if dot > minimal_dot then
            minimal_dot    = dot
            closest_player = player
        end
    end
    return closest_player
end

-- ─────────────────────────────────────────
-- CURVE
-- ─────────────────────────────────────────

System.curve = {}

function System.curve.get_cframe()
    local camera = workspace_s.CurrentCamera
    local root   = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    if not root then return camera.CFrame end
    local closest   = System.player.get_closest_to_cursor()
    local targetPart = closest and closest:FindFirstChild('HumanoidRootPart')
    local target_pos = targetPart and targetPart.Position or (root.Position + camera.CFrame.LookVector * 100)
    local funcs = {
        function() return camera.CFrame end,
        function()
            local direction = (target_pos - root.Position).Unit
            local offset, attempts = Vector3.new(), 0
            repeat
                offset = Vector3.new(math.random(-4000,4000),math.random(-4000,4000),math.random(-4000,4000))
                attempts += 1
            until direction:Dot((target_pos + offset - root.Position).Unit) < 0.95 or attempts > 10
            return CFrame.new(root.Position, target_pos + offset)
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0,5,0)) end,
        function()
            local dir = (root.Position - target_pos).Unit
            return CFrame.new(camera.CFrame.Position, root.Position + dir * 10000 + Vector3.new(0,1000,0))
        end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0,-9e18,0)) end,
        function() return CFrame.new(root.Position, target_pos + Vector3.new(0,9e18,0)) end,
        function() return CFrame.new(root.Position, root.Position + (-camera.CFrame.RightVector * 10000)) end,
        function() return CFrame.new(root.Position, root.Position + (camera.CFrame.RightVector * 10000)) end,
    }
    return funcs[System.__properties.__curve_mode]()
end

-- ─────────────────────────────────────────
-- PARRY EXECUTE
-- ─────────────────────────────────────────

System.parry = {}

function System.parry.execute()
    if System.__properties.__parries > 10000 then return end
    if not LocalPlayer.Character then return end
    if not _PARRY_PATCH.ready then return end
    local camera = workspace_s.CurrentCamera
    local screenPositions = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function()
                    return camera:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if ok then screenPositions[entity.Name] = sp end
            end
        end
    end
    local curveCF = System.curve.get_cframe()
    local mouseLocation
    if isMobile then
        local vp = camera.ViewportSize
        mouseLocation = {vp.X/2, vp.Y/2}
    else
        local ok, mouse = pcall(function() return UIS:GetMouseLocation() end)
        mouseLocation = ok and mouse and {mouse.X, mouse.Y} or {camera.ViewportSize.X/2, camera.ViewportSize.Y/2}
    end
    _PARRY_PATCH.fire(curveCF, screenPositions, mouseLocation)
    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then
            System.__properties.__parries -= 1
        end
    end)
end

-- ─────────────────────────────────────────
-- MANUAL SPAM (Heartbeat — يفاير بناءً على CPS)
-- ─────────────────────────────────────────

System.manual_spam = {}

getgenv().ManualSpamCPS        = getgenv().ManualSpamCPS        or 20
getgenv().ManualSpamCPSEnabled = getgenv().ManualSpamCPSEnabled or true

local function get_manual_interval()
    local cps = math.clamp(getgenv().ManualSpamCPS or 20, 1, isMobile and 60 or 2000)
    return 1 / cps
end

function System.manual_spam.loop(delta)
    if not System.__properties.__manual_spam_enabled then return end
    if not LocalPlayer.Character then return end
    if not Alive or LocalPlayer.Character.Parent ~= Alive then return end
    System.__properties.__spam_accumulator = (System.__properties.__spam_accumulator or 0) + delta
    local interval = get_manual_interval()
    if System.__properties.__spam_accumulator < interval then return end
    System.__properties.__spam_accumulator = 0
    System.parry.execute()
end

function System.manual_spam.start()
    local conns = System.__properties.__connections
    if conns.__manual_spam then conns.__manual_spam:Disconnect() end
    System.__properties.__manual_spam_enabled = true
    conns.__manual_spam = RunService.Heartbeat:Connect(System.manual_spam.loop)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    local conn = System.__properties.__connections.__manual_spam
    if conn then conn:Disconnect() System.__properties.__connections.__manual_spam = nil end
end

-- ─────────────────────────────────────────
-- AUTO SPAM (PreSimulation — ذكي، يقيّم المسافة والكرة)
-- ─────────────────────────────────────────

System.auto_spam = {}

getgenv().AutoSpamMode         = getgenv().AutoSpamMode or "Remote"
getgenv().AutoSpamAnimationFix = getgenv().AutoSpamAnimationFix or false

function System.auto_spam:get_ball_properties()
    local ball = System.ball.get()
    if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local vel     = ball.AssemblyLinearVelocity or Vector3.new()
    local dir_vec = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    local dist    = dir_vec.Magnitude
    local dir     = dist > 0 and dir_vec.Unit or Vector3.new()
    local dot     = (dist > 0 and vel.Magnitude > 0) and dir:Dot(vel.Unit) or 0
    return { Velocity = vel, Direction = dir, Distance = dist, Dot = dot }
end

function System.auto_spam:get_entity_properties()
    System.player.get_closest()
    if not Closest_Entity or not Closest_Entity.PrimaryPart then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local vel  = Closest_Entity.PrimaryPart.Velocity
    local dir  = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local dist = (LocalPlayer.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude
    return { Velocity = vel, Direction = dir, Distance = dist }
end

function System.auto_spam.spam_service(self)
    local ball   = System.ball.get()
    local entity = System.player.get_closest()
    if not ball or not entity or not entity.PrimaryPart then return 5 end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return 5 end
    local D   = 5
    local vel = ball.AssemblyLinearVelocity or Vector3.new()
    local n   = vel.Magnitude
    if n == 0 then return D end
    local to_ball = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if to_ball.Magnitude == 0 then return D end
    local r = to_ball.Unit
    local t = (n > 0) and r:Dot(vel.Unit) or 0
    local X = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
    -- ping-based threshold
    local ping = 50
    pcall(function()
        ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue()
    end)
    local ping_threshold = math.clamp(ping / 10, 1, 16)
    local B = ping_threshold * 0.7 + math.min(n / 1.2, 80)
    if X > B then return D end
    if (self.Entity_Properties and self.Entity_Properties.Distance or math.huge) > B then return D end
    if (self.Ball_Properties   and self.Ball_Properties.Distance   or math.huge) > B then return D end
    local U = math.clamp(-t, 0, 1)
    local q = math.clamp(U * (n / 40), 0, 4)
    D = B - q
    return D
end

function System.auto_spam.start()
    local conns = System.__properties.__connections
    if conns.__auto_spam then conns.__auto_spam:Disconnect() end
    System.__properties.__auto_spam_enabled = true
    conns.__auto_spam = RunService.PreSimulation:Connect(function()
        local ball = System.ball.get()
        if not ball then return end
        if System.__properties.__slashesoffury_active then return end
        local zoomies = ball:FindFirstChild('zoomies')
        if not zoomies then return end
        if zoomies.VectorVelocity.Magnitude == 0 then return end
        System.player.get_closest()
        if not Closest_Entity or not Closest_Entity.PrimaryPart then return end
        local ball_props   = System.auto_spam:get_ball_properties()
        local entity_props = System.auto_spam:get_entity_properties()
        if not ball_props or not entity_props then return end
        local accuracy = System.auto_spam.spam_service({
            Ball_Properties   = ball_props,
            Entity_Properties = entity_props,
        })
        local target_dist = LocalPlayer:DistanceFromCharacter(Closest_Entity.PrimaryPart.Position)
        local ball_dist   = LocalPlayer:DistanceFromCharacter(ball.Position)
        local ball_target = ball:GetAttribute('target')
        if not ball_target then return end
        if target_dist > accuracy or ball_dist > accuracy then return end
        local pulsed = LocalPlayer.Character and LocalPlayer.Character:GetAttribute('Pulsed')
        if pulsed then return end
        if ball_target == LocalPlayer.Name and target_dist > 30 and ball_dist > 30 then return end
        if ball_dist <= accuracy and System.__properties.__parries > System.__properties.__spam_threshold then
            System.parry.execute()
        end
    end)
end

function System.auto_spam.stop()
    System.__properties.__auto_spam_enabled = false
    local conn = System.__properties.__connections.__auto_spam
    if conn then conn:Disconnect() System.__properties.__connections.__auto_spam = nil end
end

-- ══════════════════════════════════════════
-- AUTO PARRY LOOP
-- ══════════════════════════════════════════

local autoParryEnabled = false
local lastAutoParry    = 0
local autoParryRange   = 13
local autoParryDelay   = 0.10
local autoParryCount   = 0

RunService.Heartbeat:Connect(function()
    if not autoParryEnabled then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local now = tick()
    if (now - lastAutoParry) < 0.1 then return end
    if not _PARRY_PATCH.ready then return end
    local ball = System.ball.get()
    if not ball then return end
    local dist = (ball.Position - root.Position).Magnitude
    if dist <= autoParryRange then
        lastAutoParry = now
        if autoParryDelay > 0 then task.wait(autoParryDelay) end
        System.parry.execute()
        autoParryCount += 1
    end
end)

-- ══════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════

local oldGui = CoreGui:FindFirstChild("AlphaSystemUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AlphaSystemUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = CoreGui

-- THEME
local T = {
    bg       = Color3.fromRGB(10,  10,  14),
    panel    = Color3.fromRGB(18,  18,  24),
    card     = Color3.fromRGB(24,  24,  32),
    border   = Color3.fromRGB(45,  45,  60),
    accent   = Color3.fromRGB(120, 80, 255),
    accentDm = Color3.fromRGB(70,  45, 160),
    green    = Color3.fromRGB(50,  220, 120),
    red      = Color3.fromRGB(220, 70,  80),
    orange   = Color3.fromRGB(255, 160, 60),
    text     = Color3.fromRGB(220, 220, 235),
    sub      = Color3.fromRGB(130, 130, 155),
    white    = Color3.fromRGB(255, 255, 255),
}

local ti_fast   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ti_medium = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function make(cls, props, parent)
    local obj = Instance.new(cls)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end
local function tween(obj, info, props) TweenService:Create(obj, info, props):Play() end
local function corner(r, p) make("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(t, c, p) make("UIStroke", {Thickness = t, Color = c, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p) end
local function pad(l, r, t, b, p)
    make("UIPadding", {
        PaddingLeft   = UDim.new(0, l), PaddingRight  = UDim.new(0, r),
        PaddingTop    = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
    }, p)
end

local W      = isMobile and 300 or 340
local H_base = isMobile and 480 or 530

-- WINDOW
local Window = make("Frame", {
    Size             = UDim2.new(0, W, 0, H_base),
    Position         = UDim2.new(0, 20, 0.5, -H_base/2),
    BackgroundColor3 = T.bg,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
}, ScreenGui)
corner(16, Window)
stroke(1, T.border, Window)

-- GLOW
make("ImageLabel", {
    Size = UDim2.new(1,80,1,80), Position = UDim2.new(0,-40,0,-40),
    BackgroundTransparency = 1, Image = "rbxassetid://5028857472",
    ImageColor3 = T.accent, ImageTransparency = 0.85, ZIndex = -1,
}, Window)

-- TITLE BAR
local TH = isMobile and 52 or 58
local TitleBar = make("Frame", {
    Size = UDim2.new(1,0,0,TH), BackgroundColor3 = T.panel, BorderSizePixel = 0,
}, Window)
corner(16, TitleBar)
make("Frame", {
    Size = UDim2.new(1,0,0,16), Position = UDim2.new(0,0,1,-16),
    BackgroundColor3 = T.panel, BorderSizePixel = 0,
}, TitleBar)
local Strip = make("Frame", {
    Size = UDim2.new(0,4,0,28), Position = UDim2.new(0,14,0.5,-14),
    BackgroundColor3 = T.accent, BorderSizePixel = 0,
}, TitleBar)
corner(4, Strip)
make("TextLabel", {
    Size = UDim2.new(1,-40,1,0), Position = UDim2.new(0,28,0,0),
    BackgroundTransparency = 1, Text = "ALPHA SYSTEM",
    TextColor3 = T.white, Font = Enum.Font.GothamBold,
    TextSize = isMobile and 15 or 17, TextXAlignment = Enum.TextXAlignment.Left,
}, TitleBar)
make("TextLabel", {
    Size = UDim2.new(0,90,1,0), Position = UDim2.new(1,-98,0,0),
    BackgroundTransparency = 1, Text = "Blade Ball",
    TextColor3 = T.sub, Font = Enum.Font.Gotham,
    TextSize = isMobile and 11 or 12, TextXAlignment = Enum.TextXAlignment.Right,
}, TitleBar)

-- CONTENT
local Content = make("ScrollingFrame", {
    Size = UDim2.new(1,0,1,-TH), Position = UDim2.new(0,0,0,TH),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = T.accentDm,
    CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, Window)
pad(14,14,14,14,Content)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10)}, Content)

-- ─────────────────────────────────────────
-- STATUS CARD
-- ─────────────────────────────────────────

local StatusCard = make("Frame", {
    Size = UDim2.new(1,0,0,isMobile and 70 or 78),
    BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = 1,
}, Content)
corner(12, StatusCard) stroke(1, T.border, StatusCard)

local StatusDot = make("Frame", {
    Size = UDim2.new(0,10,0,10), Position = UDim2.new(0,16,0.5,-5),
    BackgroundColor3 = T.red, BorderSizePixel = 0,
}, StatusCard)
corner(99, StatusDot)

local StatusLabel = make("TextLabel", {
    Size = UDim2.new(1,-40,0,22), Position = UDim2.new(0,34,0,12),
    BackgroundTransparency = 1, Text = "System  —  Idle",
    TextColor3 = T.text, Font = Enum.Font.GothamBold,
    TextSize = isMobile and 13 or 14, TextXAlignment = Enum.TextXAlignment.Left,
}, StatusCard)

local CountLabel = make("TextLabel", {
    Size = UDim2.new(1,-34,0,18), Position = UDim2.new(0,34,0,36),
    BackgroundTransparency = 1, Text = "Parries: 0",
    TextColor3 = T.sub, Font = Enum.Font.Gotham,
    TextSize = isMobile and 10 or 11, TextXAlignment = Enum.TextXAlignment.Left,
}, StatusCard)

local ReadyLabel = make("TextLabel", {
    Size = UDim2.new(0,85,0,18), Position = UDim2.new(1,-93,0,12),
    BackgroundTransparency = 1, Text = "● Waiting",
    TextColor3 = T.sub, Font = Enum.Font.Gotham,
    TextSize = isMobile and 10 or 11, TextXAlignment = Enum.TextXAlignment.Right,
}, StatusCard)

local function updateCount()
    CountLabel.Text = "Parries: " .. autoParryCount
end

-- ─────────────────────────────────────────
-- TOGGLE BUILDER
-- ─────────────────────────────────────────

local function makeToggle(parent, order, label_on, label_off, color_on, onEnable, onDisable)
    local Btn = make("TextButton", {
        Size = UDim2.new(1,0,0,isMobile and 48 or 54),
        BackgroundColor3 = T.accentDm, BorderSizePixel = 0,
        Text = label_off, TextColor3 = T.white,
        Font = Enum.Font.GothamBold, TextSize = isMobile and 13 or 14,
        LayoutOrder = order, AutoButtonColor = false,
    }, parent)
    corner(12, Btn)
    local active = false
    local function refresh()
        if active then
            tween(Btn, ti_fast, {BackgroundColor3 = color_on})
            Btn.Text = label_on
        else
            tween(Btn, ti_fast, {BackgroundColor3 = T.accentDm})
            Btn.Text = label_off
        end
    end
    Btn.MouseEnter:Connect(function()
        tween(Btn, ti_fast, {BackgroundColor3 = active and color_on or Color3.fromRGB(90,55,200)})
    end)
    Btn.MouseLeave:Connect(function()
        tween(Btn, ti_fast, {BackgroundColor3 = active and color_on or T.accentDm})
    end)
    Btn.MouseButton1Click:Connect(function()
        active = not active
        refresh()
        tween(Btn, TweenInfo.new(0.07), {BackgroundColor3 = T.white})
        task.wait(0.07)
        tween(Btn, ti_fast, {BackgroundColor3 = active and color_on or T.accentDm})
        if active then onEnable() else onDisable() end
    end)
    return Btn, function() return active end, function(v) active = v refresh() end
end

-- SECTION LABEL
local function sectionLbl(txt, order)
    make("TextLabel", {
        Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1,
        Text = txt, TextColor3 = T.sub, Font = Enum.Font.GothamBold,
        TextSize = isMobile and 10 or 11, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, Content)
end

-- ─────────────────────────────────────────
-- AUTO PARRY SECTION
-- ─────────────────────────────────────────

sectionLbl("AUTO PARRY", 2)

local autoParryBtn
autoParryBtn = make("TextButton", {
    Size = UDim2.new(1,0,0,isMobile and 48 or 54),
    BackgroundColor3 = T.accentDm, BorderSizePixel = 0,
    Text = "Enable Auto Parry", TextColor3 = T.white,
    Font = Enum.Font.GothamBold, TextSize = isMobile and 13 or 14,
    LayoutOrder = 3, AutoButtonColor = false,
}, Content)
corner(12, autoParryBtn)

local apActive = false
local function refreshAutoParry()
    if apActive then
        tween(autoParryBtn, ti_fast, {BackgroundColor3 = T.accent})
        autoParryBtn.Text    = "Disable Auto Parry"
        StatusLabel.Text     = "Auto Parry  —  ON"
        StatusLabel.TextColor3 = T.green
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.green})
    else
        tween(autoParryBtn, ti_fast, {BackgroundColor3 = T.accentDm})
        autoParryBtn.Text    = "Enable Auto Parry"
        StatusLabel.Text     = "System  —  Idle"
        StatusLabel.TextColor3 = T.text
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.red})
    end
end

autoParryBtn.MouseButton1Click:Connect(function()
    apActive       = not apActive
    autoParryEnabled = apActive
    refreshAutoParry()
    tween(autoParryBtn, TweenInfo.new(0.07), {BackgroundColor3 = T.white})
    task.wait(0.07)
    tween(autoParryBtn, ti_fast, {BackgroundColor3 = apActive and T.accent or T.accentDm})
end)

-- ─────────────────────────────────────────
-- SLIDER BUILDER
-- ─────────────────────────────────────────

local function makeSlider(parent, title, min, max, val, decimals, order, onChange)
    local Card = make("Frame", {
        Size = UDim2.new(1,0,0,isMobile and 66 or 74),
        BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order,
    }, parent)
    corner(12, Card) stroke(1, T.border, Card) pad(14,14,10,10,Card)

    make("TextLabel", {
        Size = UDim2.new(1,-60,0,20), BackgroundTransparency = 1,
        Text = title, TextColor3 = T.text, Font = Enum.Font.GothamBold,
        TextSize = isMobile and 11 or 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, Card)

    local ValLbl = make("TextLabel", {
        Size = UDim2.new(0,55,0,20), Position = UDim2.new(1,-55,0,0),
        BackgroundTransparency = 1, Text = tostring(val),
        TextColor3 = T.accent, Font = Enum.Font.GothamBold,
        TextSize = isMobile and 11 or 12, TextXAlignment = Enum.TextXAlignment.Right,
    }, Card)

    local Track = make("Frame", {
        Size = UDim2.new(1,0,0,6), Position = UDim2.new(0,0,0,isMobile and 36 or 40),
        BackgroundColor3 = T.border, BorderSizePixel = 0,
    }, Card)
    corner(99, Track)

    local Fill = make("Frame", {
        Size = UDim2.new((val-min)/(max-min),0,1,0),
        BackgroundColor3 = T.accent, BorderSizePixel = 0,
    }, Track)
    corner(99, Fill)

    local Knob = make("Frame", {
        Size = UDim2.new(0,18,0,18),
        Position = UDim2.new((val-min)/(max-min),-9,0.5,-9),
        BackgroundColor3 = T.white, BorderSizePixel = 0,
    }, Track)
    corner(99, Knob) stroke(2, T.accent, Knob)

    local dragging = false
    local curVal   = val

    local function setVal(ax)
        local rel = math.clamp((ax - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        curVal = min + (max - min) * rel
        if decimals == 0 then curVal = math.round(curVal) end
        local fmt = decimals > 0 and ("%." .. decimals .. "f") or "%d"
        ValLbl.Text = string.format(fmt, curVal)
        tween(Fill,  ti_fast, {Size     = UDim2.new(rel,0,1,0)})
        tween(Knob,  ti_fast, {Position = UDim2.new(rel,-9,0.5,-9)})
        onChange(curVal)
    end

    Track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true setVal(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            setVal(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeSlider(Content, "Parry Range (studs)", 5, 40, autoParryRange, 0, 4, function(v) autoParryRange = v end)
makeSlider(Content, "Reaction Delay (s)",  0, 0.5, autoParryDelay, 2, 5, function(v) autoParryDelay = v end)

-- ─────────────────────────────────────────
-- SPAM SECTION
-- ─────────────────────────────────────────

sectionLbl("SPAM", 6)

-- Manual Spam
local _, getMS, setMS = makeToggle(Content, 7,
    "Disable Manual Spam", "Enable Manual Spam",
    T.orange,
    function()
        StatusLabel.Text       = "Manual Spam  —  ON"
        StatusLabel.TextColor3 = T.orange
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.orange})
        System.manual_spam.start()
    end,
    function()
        System.manual_spam.stop()
        StatusLabel.Text       = "System  —  Idle"
        StatusLabel.TextColor3 = T.text
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.red})
    end
)

makeSlider(Content, "Spam CPS", 1, isMobile and 60 or 500, getgenv().ManualSpamCPS, 0, 8, function(v)
    getgenv().ManualSpamCPS = v
end)

-- Auto Spam
local _, getAS, setAS = makeToggle(Content, 9,
    "Disable Auto Spam", "Enable Auto Spam",
    Color3.fromRGB(220, 80, 180),
    function()
        StatusLabel.Text       = "Auto Spam  —  ON"
        StatusLabel.TextColor3 = Color3.fromRGB(220, 80, 180)
        tween(StatusDot, ti_fast, {BackgroundColor3 = Color3.fromRGB(220, 80, 180)})
        System.auto_spam.start()
    end,
    function()
        System.auto_spam.stop()
        StatusLabel.Text       = "System  —  Idle"
        StatusLabel.TextColor3 = T.text
        tween(StatusDot, ti_fast, {BackgroundColor3 = T.red})
    end
)

makeSlider(Content, "Spam Threshold", 0, 5, System.__properties.__spam_threshold, 1, 10, function(v)
    System.__properties.__spam_threshold = v
end)

-- ─────────────────────────────────────────
-- KEYBINDS CARD
-- ─────────────────────────────────────────

sectionLbl("KEYBINDS", 11)

local KeyCard = make("Frame", {
    Size = UDim2.new(1,0,0,isMobile and 70 or 80),
    BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = 12,
}, Content)
corner(12, KeyCard) stroke(1, T.border, KeyCard) pad(14,14,10,10,KeyCard)
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)}, KeyCard)

local function keyRow(key, desc, order)
    local Row = make("Frame", {
        Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, LayoutOrder = order,
    }, KeyCard)
    local Tag = make("TextLabel", {
        Size = UDim2.new(0,26,1,0), BackgroundColor3 = T.accentDm,
        Text = key, TextColor3 = T.white, Font = Enum.Font.GothamBold,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,
    }, Row)
    corner(6, Tag)
    make("TextLabel", {
        Size = UDim2.new(1,-34,1,0), Position = UDim2.new(0,34,0,0),
        BackgroundTransparency = 1, Text = desc,
        TextColor3 = T.sub, Font = Enum.Font.Gotham,
        TextSize = isMobile and 10 or 11, TextXAlignment = Enum.TextXAlignment.Left,
    }, Row)
end

keyRow("P",   "Toggle Auto Parry",  1)
keyRow("M",   "Toggle Manual Spam", 2)
keyRow("H",   "Hide / Show UI",     3)

-- ─────────────────────────────────────────
-- READY INDICATOR UPDATE
-- ─────────────────────────────────────────

RunService.Heartbeat:Connect(function()
    if _PARRY_PATCH.ready then
        ReadyLabel.Text       = "● Ready"
        ReadyLabel.TextColor3 = T.green
    else
        ReadyLabel.Text       = "● Waiting"
        ReadyLabel.TextColor3 = T.sub
    end
    updateCount()
end)

-- ─────────────────────────────────────────
-- DRAGGABLE
-- ─────────────────────────────────────────

local draggingWin, dragStart, startPos

TitleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = true dragStart = inp.Position startPos = Window.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if draggingWin and (
        inp.UserInputType == Enum.UserInputType.MouseMovement or
        inp.UserInputType == Enum.UserInputType.Touch
    ) then
        local d = inp.Position - dragStart
        Window.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = false
    end
end)

-- ─────────────────────────────────────────
-- HIDE / SHOW ANIMATION
-- ─────────────────────────────────────────

local visible = true
local function toggleUI()
    visible = not visible
    tween(Window, ti_medium, {
        Size = visible and UDim2.new(0,W,0,H_base) or UDim2.new(0,W,0,TH)
    })
end

-- ─────────────────────────────────────────
-- KEYBINDS
-- ─────────────────────────────────────────

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.P then
        apActive         = not apActive
        autoParryEnabled = apActive
        refreshAutoParry()
    end
    if inp.KeyCode == Enum.KeyCode.M then
        if System.__properties.__manual_spam_enabled then
            System.manual_spam.stop() setMS(false)
        else
            System.manual_spam.start() setMS(true)
        end
    end
    if inp.KeyCode == Enum.KeyCode.H then toggleUI() end
end)

-- ══════════════════════════════════════════
-- EXPORT
-- ══════════════════════════════════════════

getgenv().AlphaSystem = {
    Config      = {
        AutoParry  = function(v) autoParryEnabled = v apActive = v refreshAutoParry() end,
        ParryRange = function(v) autoParryRange = v end,
        Delay      = function(v) autoParryDelay = v end,
    },
    System      = System,
    ParryPatch  = _PARRY_PATCH,
    ToggleUI    = toggleUI,
}

print("[ALPHA SYSTEM] Loaded | P = Auto Parry | M = Manual Spam | H = Hide")
