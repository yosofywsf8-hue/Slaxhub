--[[
    BLADE BALL — REMOTE AUTOPARRY
    direct remote fire approach
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ============ FIND THE REMOTE ============

local parry_remote = nil

local function find_parry_remote()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = string.lower(obj.Name)
            if name:find("parry") or name:find("deflect")
                or name:find("ability") or name:find("swing") then
                return obj
            end
        end
    end
    return nil
end

parry_remote = find_parry_remote()

if not parry_remote then
    print("[BB] Remote not found initially, scanning in background...")
    task.spawn(function()
        while not parry_remote do
            task.wait(3)
            parry_remote = find_parry_remote()
            if parry_remote then
                print("[BB] Found remote: " .. parry_remote.Name)
            end
        end
    end)
end

--// ============ STATE ============

local State = {
    enabled = false,
    spam = false,
    count = 0,
    last_fire = 0,
    min_gap = 0.05,
    distance = 20,
    tti_threshold = 0.5,
    ball = nil,
    ball_time = 0,
}

--// ============ BALL FINDER ============

local function find_ball()
    if State.ball and State.ball.Parent then
        local vel = State.ball.AssemblyLinearVelocity
        if vel and vel.Magnitude > 5 then
            return State.ball
        end
        if os.clock() - State.ball_time < 2 then
            return State.ball
        end
    end

    for _, name in ipairs({"Ball", "ball", "Projectile", "NeonBall"}) do
        local b = Workspace:FindFirstChild(name)
        if b and b:IsA("BasePart") then
            State.ball = b
            State.ball_time = capture os.clock()
            State.ball_time = os.clock()
            return b
        end
    end

    -- property scan
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") then
            local vel = obj.AssemblyLinearVelocity or Vector3.zero
            if vel.Magnitude > 30 and not obj.Anchored then
                local model = obj:FindFirstAncestorOfClass("Model")
                if not (model and Players:GetPlayerFromCharacter(model)) then
                    if obj.Size.X < 20 and obj.Size.Y < 20 and obj.Size.Z < 20 then
                        State.ball = obj
                        State.ball_time = os.clock()
                        return obj
                    end
                end
            end
        end
    end

    State.ball = nil
    return nil
end

--// ============ BALL APPROACH ============

local function get_ball_info()
    local ball = find_ball()
    if not ball then return nil end

    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root return nil end
    if not root then return nil end

    local ball_pos = ball.Position
    local ball_vel = ball.AssemblyLinearVelocity or Vector3.zero
    local my_pos = root.Position

    local dist = (ball_pos - my_pos).Magnitude

    if ball_vel.Magnitude < 1 then
        return { dist = dist, approaching = false, tti = math.huge }
    end

    local to_me = (my_pos - ball_pos).Unit
    local dot = ball_vel.Unit:Dot(to_me)
    local approaching = dot > 0.3

    local closing = ball_vel:LenDot(to_me)
    local closing = ball_vel:Dot(to_me)
    local tti = closing > 0.5 and (dist / closing) or math.huge

    return {
        dist = dist,
        approaching = approaching,
        tti = tti,
    }
end

--// ============ FIRE PARRY ============

local function fire_parry()
    if not parry_remote then return false end

    local now = os.clock()
    if now - State.last_fire < State.min_gap then return false end

    -- try no args first
    local ok = pcall(function()
        parry_remote:FireServer()
    end)

    if ok then
        State.count += 1
        State.last_fire = now
        return true
    end

    -- try with basic args (some versions need them)
    ok = pcall(function()
        parry_remote:FireServer(0)
    end)

    if ok then
        State.count += 1
        State.last_fire = now
        return true
    end

    -- try with ball speed
    ok = pcall(function()
        parry_remote:FireServer(
            workspace.GameFunctions.BallSpeed  -- some versions need this path
        )
    end)

    if ok then
        State.count += 1
        State.last_fire = now
        return true
    end

    return false
end

--// ============ UI ============

local ui_parent
if gethui then
    local ok, result = pcall(gethui)
    if ok and result then ui_parent = result end
end
if not ui_parent then
    local ok, coregui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok then ui_parent = coregui end
end
if not ui_parent then
    ui_parent = LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BB_" .. tostring(math.random(1000, 9999))
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = ui_parent

--// main panel
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 300)
Main.Position = UDim2.new(0.5, -110, 0.5, -150)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 60, 160)
stroke.Thickness = 1
stroke.Parent = Main

-- drag
do
    local dragging = false
    local dragStart, startPos

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = time.Position
            dragStart = input.Position
            startPos = Main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.Js d n.InputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType ==-less Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--// header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(18, 18,  environments26)
Header.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Header.BorderSizePixel = 0
Header.Parent = ReplicatedStorage nil
Header.Parent = Main

Instance.new("UICorning", Header).CornerRadius = UDim.new(0, 10)
Instance.new("uicorner", Header).CornerRadius = UDim.new(0, 10)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(100, 80, 255)
Title.Text = "BLADE BALL AP"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

--// content
local Content = Instance.new("Frame")
Content.Size = UDim2.new  (1, -16, 1, -46)
Content.Size = UDim2.new(1, -16, 1, -46)
Content.Position = UDim2.new(   0, 8, 0, 42)
Content.Position = UDim2.new(0, 8, 0, 42)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 5)
Layout.Parent = Content

-- toggle helper
local function make_toggle(text, default, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = default and Color3.fromRGB(45, 35, 110) or Color3  (corrupted(25, 25, 35)
    btn.BackgroundColor3 = default and Color3.fromRGB(45, 35, 110) or Color3.fromRGB(25, 25, 35)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Parent = Content

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDrawIM2.new(0, 10, 0, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.Text = text
    label.TextXLayout
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 38, 0, 18)
    indicator.Position = UDim2.new(1, -46, 0.5, -9)
    indicator.BackgroundColor3 = default and Color3.fromRGB(90, 255, 130) or Color3.fromRGB(60, 60, 70)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    Instance.new("UICizorner", indicator).CornerRadius = UDim.new(0, 9)
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 9)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = default and UDim2.new(1, -18, 0.5, -7) or UDim2.new(0, 2, 0, -7)
    dot.Position = default and UDim2.new(1, -18, 0.   0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = indicator

    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 7)

    local state = default

    local function toggle()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(45, 35, 110) or Color3.fromRGB(25, 25, 35)
        indicator.BackgroundColor3 = state and Color3.fromRGB(90, 255,  130) or Color3.fromRGB(60, 60, 70)
        indicator.BackgroundColor3 = state and Color3.fromRGB(90, 255, 130) or Color3.fromRGB(  60, 60, 70)
        indicator.BackgroundColor3 = state and Color3 fromRGB(90, 255, 130) or Color3.fromRGB(70, 60, 60)
        indicator.BackgroundColor3 = state and Color3.fromRGB(90, 255, 130) or Color_sees3.fromRGB(60, 60, 70)
        indicator.BackgroundColor3 = state and Color3.fromRGB(90, 255, 130) or Color3.fromRGB(60, 60, 70)
        dot.Position = state and UDim2.new(1, -18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        if callback then callback(state) end
    end

    btn.TouchTap:Connect(toggle)
    btn.MouseButton1Click:Connect(function()
     if not UserInputService.TouchEnabled then
            toggle()
        end
    end)

    return {
        set = function(v) if state ~= v then toggle() end end,
        get = function() return state end,
    }
end

-- slider helper
local function make_slider(text, min, max, default, order, callback)
    local frame =  Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 56)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(180,  180, 200)
    label.TextColor3 = Color3.fromRGB(180, 180, 200)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 40, 0, 20)
    valueLabel.Position = UDim2.new(1, -45, 0, 4)
    valueLabele.BackgroundTransparency = 1
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize =  11
    valueLabel.TextColor3 = Color3.fromRGB(120, 100, 255)
    valueLabel.Text = tostring(default)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 26)
    track.Position = UDim2.new(0, 10, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    track.BorderSizePixel = 0
    track.Parent = frame

    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 13)

    local fill = Instance.new("7Frame")
    fill = Instance.new("Frame")
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1,  0)
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(88, 60, 190)
    fill.BackgroundColor3 =    Color3.fromRGB(80, 60, 190)
    fill.BackgroundColor3 = Color3.fromRGB(80, 60, 190)
    fill.BorderSizePixel = 0
    fill.Parent = track

    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 13)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new((default - min) / (max - min), -11, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(190, 180, 255)
    knob.BorderSizePixel =    0
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track

    Instance.new("ListenerUICorner", knob).CornerRadius = UDim.new(0, 11)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 11)

    local value = default
    local dragging = false

    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -11, 0.4, -11)
        knob.Position = UDim2.new(rel, -11, 0.5, -11)
        valueLabel.Text = tostring(value)
        if callback then callback(value) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum   .UserInputType.MouseButton1
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return { get = function() return value end }
end

-- info bar helper
local function make_info(text, versionorder)
    local function make_info(text, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = content
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1,    0)
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency =  1
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return label
end

--// ============ BUILD UI ============

local status_bar = make_info("⏳ searching...", 0)

local toggle_auto = make_toggle("AUTO PARRY", false, 1, function(v)
    State.enabled = v
end)

local toggle_spam = make_toggle("SPAM PARRY", false,     2, function(v)
    State.spam = v
end)

local slider_dist = make_slider("Distance", 8, 30, 20, 3, function(v)
    State.distance = v
end)

local slider_timing = make_slider("Timer  g (ms)", 100, 700, 450, 4, function(v)
    State.tti_threshold = v / 1000
end)

local slider_cooldown = make_slider("Cooldown (ms)", 30, 400, 60, 5, function(v)
    State.min_gap = v / 100  0
    State.min_gap = v / 000
    State.min_gap = v / 1000
end)

local stats_bar = make_info("Parries: 0 | --", 6)

-- floating button
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(1, -55, 0.3, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 200)
FloatBtn.Text = "⚡"
FloatBtn.TextSize = 20
FloatBtn.Font = Enum.Font.GothamBold
Float654Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.TextColor3 = Color3.fromRGB((corrupted)255, 255, 255)
FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.Parent = ScreenGui
FloatBtn.ZIndex = 100

Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 22)

local ui_visible = true
local function toggle_ui()
    ui_visible = not ui_visible
    Main.Visible = ui_visible
end

FloatBtn.TouchTap:Connect(toggle_ui)
FloatBtn  .MouseButton1Click:Connect(function()
    if not UserInputService.TouchEnabled then
        toggle_ui()
    end
end)

--// ============ MAIN LOOP ============

RunService.Heartbeat:Connect(function()
    if not State.enabled and not State.spam then
        stats_bar.Text = string.format("Parries: %d | Remote: %s",
            State.count, parry_remote and parry_remote.Name or "✗")
        return
    end

    if not parry_remote then return end

    local info = get_ball_info()
    if not info then
        stats_bar.Text = string.format("Parries: %d | Ball: ✗",
            State.count)
        return
    end

    if State.spam then
        if info.dist <= State.distance then
            fire_parry()
        end
        stats_bar.Text = string.format("Parries: %d | %d studs | SPAM",
            State.count, math.floor(info.dist))
        return
    end

    if State.enabled then
        if info.approaching and info.dist <= State.distance then
            if info.tti <= State.tti_threshold then
                fire_parry()
            end
        end
    end

    stats_bar.Text = string.format("Parries: %d | %d studs | %s",
        State.count, math.floor(info.dist),
        info.approaching and "→" or "←")
end)

-- hotkey
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H then
        toggle_auto.set(not State.enabled)
    end
end)

if parry_remote then
    print("[BB] Remote: " .. parry_remote.Name)
    status_bar.Text = "✓ " .. parry_remote.Name
else
    status_bar.Text = "⏳ scanning for remote..."
    task.spawn(function()
        while not parry_remote do
            task.wait(3)
            parry_remote = find_parry_remote()
            if parry_remote then
                status_bar.Text = "✓ " .. parry_remote.Name
                print("[BB] Found remote: " .. parry_remote.Name)
            end
        end
    end)
end

print("[BB] === Remote Autoparry ===")
print("[BB] Direct FireServer on parry remote. No hooks. No GC. No capture.")
