--[[
    BLADE BALL — PREMIUM AUTOPARRY
    multi-method bypass + prediction engine + full UI
    
    methods (auto-fallback chain):
        1. direct function call from GC heap (bypasses remote entirely)
        2. remote fire with forged token (GC-extracted generator)
        3. captured packet replay with fresh CFrame
        4. raw remote spam (brute force fallback)
]]

--// services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ================================================================
-- BYPASS ENGINE
-- ================================================================

local Bypass = {
    method = nil,        -- "function" | "token" | "replay" | "spam"
    internal_function = nil,  -- direct parry function from GC
    token_generator = nil,    -- token gen function from GC
    target_remote = nil,      -- parry remote instance
    captured_args = nil,      -- captured packet template
    remote_name = nil,
}

--// METHOD 1: find the actual parry function inside the GC heap
-- this is the cleanest bypass — call the game's own code directly
local function scan_gc_for_parry_function()
    local results = {}

    for _, obj in getgc(true) do
        if type(obj) ~= 'function' then continue end

        local source = debug.info(obj, 's') or ''
        local params = debug.info(obj, 'u') or 0

        -- look for the core parry handler
        if source:find('Parry', 1, true)
            or source:find('parry', 1, true)
            or source:find('PRY', 1, true)
            or source:find('Deflect', 1, true) then

            -- parry functions typically take 0-2 params
            if params <= 3 then
                table.insert(results, { fn = obj, source = source, params = params })
            end
        end
    end

    -- prefer functions from client-side game scripts
    for _, result in ipairs(results) do
        local src = result.source
        if src:find('Client') or src:find('client') or src:find('Controller')
            or src:find('controller') or src:find('Main') or src:find('main') then
            return result.fn, result.source
        end
    end

    -- fallback to any result
    if #results > 0 then
        return results[1].fn, results[1].source
    end

    return nil, nil
end

--// METHOD 2: find token generator from GC
local function scan_gc_for_token_generator()
    for _, obj in getgc(true) do
        if type(obj) ~= 'function' then continue end

        local source = debug.info(obj, 's') or ''
        if not (source:find('PRY', 1, true)
            or source:find('Parry', 1, true)
            or source:find('parry', 1, true)
            or source:find('Security', 1, true)
            or source:find('Token', 1, true)) then
            continue
        end

        -- scan upvalues for nested function that generates tokens
        local ok, upvalues = pcall(debug.getupvalues, obj)
        if not ok then continue end

        for _, upval in ipairs(upvalues) do
            if type(upval) == 'function' then
                local up_params = debug.info(upval, 'u') or 0
                -- token generators take (uid, salt) → string
                if up_params == 2 then
                    -- verify it returns a string when called safely
                    local test_ok, test_result = pcall(upval, "test", "TIME")
                    if test_ok and type(test_result) == 'string' and #test_result > 0 then
                        return upval
                    end
                end
            end
        end
    end

    return nil
end

--// METHOD 3: find the parry remote directly
local function find_parry_remote()
    -- direct name scan
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA('RemoteEvent') or obj:IsA('RemoteFunction') then
            local name = string.lower(obj.Name)
            if name:find('parry') or name:find('deflect')
                or name:find('ability') or name:find('attack')
                or name:find('swing') or name:find('hit') then
                return obj
            end
        end
    end

    -- check workspace too (some versions put remotes there)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA('RemoteEvent') or obj:IsA('RemoteFunction') then
            local name = string.lower(obj.Name)
            if name:find('parry') or name:find('deflect')
                or name:find('ability') or name:find('swing') then
                return obj
            end
        end
    end

    return nil
end

--// namecall hook to capture the actual parry packet
local captured = false
local capture_args = nil
local capture_remote = nil

local function is_parry_packet(args)
    -- flexible validation: 5-10 args, contains string + number + CFrame
    local has_string = false
    local has_number = false
    local has_cframe = false

    for _, arg in ipairs(args) do
        local t = typeof(arg)
        if t == 'string' then has_string = true end
        if t == 'number' then has_number = true end
        if t == 'CFrame' then has_cframe = true end
    end

    return #args >= 4 and has_string and has_number
end

-- install the hook
local old_namecall
old_namecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if (method == 'FireServer' or method == 'InvokeServer')
        and not captured
        and (self:IsA('RemoteEvent') or self:IsA('RemoteFunction')) then

        local args = {...}
        local remote_name = string.lower(self.Name)

        -- check if this remote is parry-related
        if remote_name:find('parry') or remote_name:find('deflect')
            or remote_name:find('ability') or remote_name:find('swing')
            or remote_name:find('attack') or remote_name:find('hit') then

            if is_parry_packet(args) then
                captured = true
                capture_args = args
                capture_remote = self
                Bypass.target_remote = self
                Bypass.captured_args = args
                Bypass.remote_name = self.Name
            end
        end
    end

    return old_namecall(self, ...)
end))

--// token forge (if we have the generator)
local function forge_token(uid)
    if not Bypass.token_generator then return nil end

    local ok, result = pcall(function()
        local time = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
        local key = Bypass.token_generator(uid, 'TIME')
        local out = table.create(#time)

        for i = 1, #time do
            out[i] = string.char(bit32.bxor(
                (string.byte(time, i) + i) % 256,
                string.byte(key, (i - 1) % #key + 1)
            ))
        end

        return table.concat(out)
    end)

    return ok and result or nil
end

--// ================================================================
-- BALL ENGINE — tracking + prediction
-- ================================================================

local Ball = {
    instance = nil,
    last_position = Vector3.zero,
    last_velocity = Vector3.zero,
    velocity_history = {},
    curve_detected = false,
    curve_rate = Vector3.zero,
}

local function find_ball()
    -- fast path: cached
    if Ball.instance and Ball.instance.Parent then
        return Ball.instance
    end

    -- direct names
    local names = {'Ball', 'ball', 'Projectile', 'NeonBall', 'Orb', 'Sword'}
    for _, name in ipairs(names) do
        local b = Workspace:FindFirstChild(name)
        if b and b:IsA('BasePart') then
            Ball.instance = b
            return b
        end
    end

    -- scan for fast-moving parts
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA('BasePart') then
            local vel = obj.AssemblyLinearVelocity or Vector3.zero
            if vel.Magnitude > 50 then
                local lower = string.lower(obj.Name)
                if lower:find('ball') or lower:find('proj') or lower:find('orb')
                    or lower:find('neon') or lower:find('sword') then
                    Ball.instance = obj
                    return obj
                end
            end
        end
    end

    -- last resort: any part with extreme velocity
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA('BasePart') and not obj:IsA('Terrain') then
            local vel = obj.AssemblyLinearVelocity or Vector3.zero
            if vel.Magnitude > 80 then
                Ball.instance = obj
                return obj
            end
        end
    end

    Ball.instance = nil
    return nil
end

local function update_ball_tracking()
    local ball = find_ball()
    if not ball then return end

    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity or Vector3.zero

    -- store velocity history for curve detection
    table.insert(Ball.velocity_history, {
        vel = vel,
        pos = pos,
        time = os.clock()
    })

    -- keep last 20 samples
    if #Ball.velocity_history > 20 then
        table.remove(Ball.velocity_history, 1)
    end

    -- detect curve (homing) behavior
    if #Ball.velocity_history >= 10 then
        local old = Ball.velocity_history[1]
        local new = Ball.velocity_history[#Ball.velocity_history]

        local vel_change = new.vel - old.vel
        local time_diff = new.time - old.time

        if time_diff > 0 and vel_change.Magnitude > 5 then
            Ball.curve_detected = true
            Ball.curve_rate = vel_change / time_diff
        else
            Ball.curve_detected = false
            Ball.curve_rate = Vector3.zero
        end
    end

    Ball.last_position = pos
    Ball.last_velocity = vel
end

--// predict where the ball will be at time t
local function predict_ball_position(t)
    local ball = Ball.instance
    if not ball then return nil end

    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity or Vector3.zero

    -- linear prediction
    local linear_pos = pos + vel * t

    -- if curve detected, apply quadratic correction
    if Ball.curve_detected then
        -- x(t) = x0 + v0*t + 0.5*a*t^2
        local curved_pos = pos + vel * t + Ball.curve_rate * 0.5 * t * t

        -- blend between linear and curved based on confidence
        local confidence = math.min(#Ball.velocity_history / 20, 1)
        return linear_pos:Lerp(curved_pos, confidence * 0.7)
    end

    return linear_pos
end

--// time until ball reaches us
local function time_to_impact()
    local char = LocalPlayer.Character
    if not char then return math.huge, false, 0 end
    local root = char:FindFirstChild('HumanoidRootPart')
    if not root then return math.huge, false, 0 end

    local ball = Ball.instance
    if not ball then return math.huge, false, 0 end

    local my_pos = root.Position
    local ball_pos = ball.Position
    local ball_vel = ball.AssemblyLinearVelocity or Vector3.zero

    if ball_vel.Magnitude < 5 then return math.huge, false, 0 end

    local to_me = (my_pos - ball_pos).Unit
    local direction = ball_vel.Unit
    local dot = direction:Dot(to_me)

    -- is it coming at us?
    local approaching = dot > 0.55

    -- distance
    local dist = (ball_pos - my_pos).Magnitude
    local speed = ball_vel.Magnitude

    -- linear TTI
    local closing = ball_vel:Dot(to_me)
    if closing < 1 then return math.huge, approaching, dist end

    local tti_linear = dist / closing

    -- curved TTI: simulate the ball forward
    if Ball.curve_detected then
        for t = 0.1, 2.0, 0.1 do
            local predicted = predict_ball_position(t)
            if predicted then
                local pred_dist = (predicted - my_pos).Magnitude
                if pred_dist < 4 then
                    return t, approaching, dist
                end
            end
        end
    end

    return tti_linear, approaching, dist
end

--// ================================================================
-- PARRY ENGINE
-- ================================================================

local Parry = {
    enabled = false,
    count = 0,
    last_fire = 0,
    min_gap = 0.05,
    spam_mode = false,
    spam_rate = 0.03,
    distance_mode = true,
    max_distance = 14,
    tti_threshold = 0.35,
    method_used = "none",
}

--// execute the parry using whatever method is available
local function execute_parry()
    local now = os.clock()
    if now - Parry.last_fire < Parry.min_gap then return false end

    -- METHOD 1: direct function call (best bypass)
    if Bypass.internal_function then
        local ok = pcall(Bypass.internal_function)
        if ok then
            Parry.count += 1
            Parry.last_fire = now
            Parry.method_used = "internal"
            return true
        end
    end

    -- METHOD 2: token-forged remote fire
    if Bypass.target_remote and Bypass.captured_args and Bypass.token_generator then
        local template = Bypass.captured_args
        local uid = nil

        -- find the string that serves as UID (typically args[2])
        for i, arg in ipairs(template) do
            if type(arg) == 'string' and #arg > 5 then
                uid = arg
                break
            end
        end

        if uid then
            local fresh_token = forge_token(uid)
            if fresh_token then
                local packet = {}
                for i, arg in ipairs(template) do
                    if typeof(arg) == 'CFrame' then
                        packet[i] = Camera.CFrame
                    elseif type(arg) == 'string' and arg == uid and i > 2 then
                        packet[i] = fresh_token
                    else
                        packet[i] = arg
                    end
                end

                if Bypass.target_remote:IsA('RemoteEvent') then
                    Bypass.target_remote:FireServer(unpack(packet))
                else
                    pcall(function()
                        Bypass.target_remote:InvokeServer(unpack(packet))
                    end)
                end

                Parry.count += 1
                Parry.last_fire = now
                Parry.method_used = "token"
                return true
            end
        end
    end

    -- METHOD 3: replay captured packet with updated CFrame
    if Bypass.target_remote and Bypass.captured_args then
        local template = Bypass.captured_args
        local packet = {}

        for i, arg in ipairs(template) do
            if typeof(arg) == 'CFrame' then
                packet[i] = Camera.CFrame
            else
                packet[i] = arg
            end
        end

        if Bypass.target_remote:IsA('RemoteEvent') then
            Bypass.target_remote:FireServer(unpack(packet))
        else
            pcall(function()
                Bypass.target_remote:InvokeServer(unpack(packet))
            end)
        end

        Parry.count += 1
        Parry.last_fire = now
        Parry.method_used = "replay"
        return true
    end

    -- METHOD 4: brute force remote (find and fire)
    if not Bypass.target_remote then
        Bypass.target_remote = find_parry_remote()
    end

    if Bypass.target_remote then
        if Bypass.target_remote:IsA('RemoteEvent') then
            Bypass.target_remote:FireServer()
        else
            pcall(function()
                Bypass.target_remote:InvokeServer()
            end)
        end
        Parry.count += 1
        Parry.last_fire = now
        Parry.method_used = "spam"
        return true
    end

    return false
end

--// ================================================================
-- INITIALIZATION
-- ================================================================

print("[BB] === initializing bypass engine ===")

-- scan for internal function
Bypass.internal_function = scan_gc_for_parry_function()
if Bypass.internal_function then
    print("[BB] ✓ internal parry function found in GC")
else
    print("[BB] ✗ internal function not found, trying token generator...")
    Bypass.token_generator = scan_gc_for_token_generator()
    if Bypass.token_generator then
        print("[BB] ✓ token generator found")
    else
        print("[BB] ✗ token generator not found, will use packet capture")
    end
end

-- scan for remote
Bypass.target_remote = find_parry_remote()
if Bypass.target_remote then
    print(string.format("[BB] ✓ parry remote found: %s (%s)",
        Bypass.target_remote.Name,
        Bypass.target_remote:IsA('RemoteEvent') and 'RemoteEvent' or 'RemoteFunction'))
else
    print("[BB] ✗ parry remote not found by name scan — waiting for capture...")
end

print("[BB] bypass engine ready")
print("[BB] parry manually once to capture the packet template")

--// ================================================================
-- PREMIUM UI
-- ================================================================

--// create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BBPremium"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--// main container
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 420)
Main.Position = UDim2.new(0.5, -160, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(80, 80, 120)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.5
MainStroke.Parent = Main

--// header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

-- header gradient
local HeaderGradient = Instance.new("UIGradient")
HeaderGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 25, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30)),
})
HeaderGradient.Rotation = 90
HeaderGradient.Parent = Header

-- title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(120, 100, 255)
Title.Text = "BLADE BALL — PREMIUM"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- version badge
local Version = Instance.new("TextLabel")
Version.Name = "Version"
Version.Size = UDim2.new(0, 50, 0, 20)
Version.Position = UDim2.new(1, -55, 0.5, -10)
Version.BackgroundTransparency = 1
Version.Font = Enum.Font.GothamBold
Version.TextSize = 10
Version.TextColor3 = Color3.fromRGB(100, 100, 140)
Version.Text = "v4.2"
Version.Parent = Header

--// content area
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -20, 1, -70)
Content.Position = UDim2.new(0, 10, 0, 55)
Content.BackgroundTransparency = 1
Content.Parent = Main

local ContentList = Instance.new("UIListLayout")
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Padding = UDim.new(0, 8)
ContentList.Parent = Content

--// helper: toggle button
local function create_toggle(parent, text, default, order, callback)
    local frame = Instance.new("Frame")
    frame.Name = text
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(200, 200, 220)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    -- toggle visual
    local toggle_bg = Instance.new("Frame")
    toggle_bg.Name = "ToggleBG"
    toggle_bg.Size = UDim2.new(0, 46, 0, 22)
    toggle_bg.Position = UDim2.new(1, -58, 0.5, -11)
    toggle_bg.BackgroundColor3 = default
        and Color3.fromRGB(90, 60, 200)
        or Color3.fromRGB(45, 45, 55)
    toggle_bg.BorderSizePixel = 0
    toggle_bg.Parent = frame

    local toggle_corner = Instance.new("UICorner")
    toggle_corner.CornerRadius = UDim.new(0, 11)
    toggle_corner.Parent = toggle_bg

    local toggle_knob = Instance.new("Frame")
    toggle_knob.Name = "Knob"
    toggle_knob.Size = UDim2.new(0, 18, 0, 18)
    toggle_knob.Position = default
        and UDim2.new(1, -21, 0.5, -9)
        or UDim2.new(0, 2, 0.5, -9)
    toggle_knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggle_knob.BorderSizePixel = 0
    toggle_knob.Parent = toggle_bg

    local knob_corner = Instance.new("UICorner")
    knob_corner.CornerRadius = UDim.new(0, 9)
    knob_corner.Parent = toggle_knob

    local state = default

    local function set_state(new_state)
        state = new_state

        TweenService:Create(toggle_bg, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = state
                and Color3.fromRGB(90, 60, 200)
                or Color3.fromRGB(45, 45, 55)
        }):Play()

        TweenService:Create(toggle_knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state
                and UDim2.new(1, -21, 0.5, -9)
                or UDim2.new(0, 2, 0.5, -9)
        }):Play()

        if callback then callback(state) end
    end

    toggle_bg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            set_state(not state)
        end
    end)

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            set_state(not state)
        end
    end)

    return {
        frame = frame,
        set = set_state,
        get = function() return state end,
        label = label,
    }
end

--// helper: slider
local function create_slider(parent, text, min, max, default, order, callback)
    local frame = Instance.new("Frame")
    frame.Name = text
    frame.Size = UDim2.new(1, 0, 0, 58)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(180, 180, 200)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local value_label = Instance.new("TextLabel")
    value_label.Size = UDim2.new(0, 50, 0, 20)
    value_label.Position = UDim2.new(1, -60, 0, 6)
    value_label.BackgroundTransparency = 1
    value_label.Font = Enum.Font.GothamBold
    value_label.TextSize = 12
    value_label.TextColor3 = Color3.fromRGB(120, 100, 255)
    value_label.Text = tostring(default)
    value_label.TextXAlignment = Enum.TextXAlignment.Right
    value_label.Parent = frame

    -- slider track
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    track.BorderSizePixel = 0
    track.Parent = frame

    local track_corner = Instance.new("UICorner")
    track_corner.CornerRadius = UDim.new(0, 3)
    track_corner.Parent = track

    -- slider fill
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fill_corner = Instance.new("UICorner")
    fill_corner.CornerRadius = UDim.new(0, 3)
    fill_corner.Parent = fill

    -- slider knob
    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(200, 190, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track

    local knob_corner = Instance.new("UICorner")
    knob_corner.CornerRadius = UDim.new(0, 7)
    knob_corner.Parent = knob

    local value = default
    local dragging = false

    local function update(input_pos)
        local relative = math.clamp(
            (input_pos - track.AbsolutePosition.X) / track.AbsoluteSize.X,
            0, 1
        )

        value = math.floor(min + (max - min) * relative + 0.5)

        fill.Size = UDim2.new(relative, 0, 1, 0)
        knob.Position = UDim2.new(relative, -7, 0.5, -7)
        value_label.Text = tostring(value)

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
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        frame = frame,
        get = function() return value end,
        set = function(v)
            value = v
            local rel = (v - min) / (max - min)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -7, 0.5, -7)
            value_label.Text = tostring(v)
        end,
    }
end

--// helper: info bar
local function create_info(parent, text, order)
    local frame = Instance.new("Frame")
    frame.Name = text
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return label
end

--// ================================================================
-- BUILD UI SECTIONS
-- ================================================================

--// status bar
local status_label = create_info(Content, "⚠ Waiting for packet capture...", 0)

--// main toggle
local auto_toggle = create_toggle(Content, "Auto Parry", false, 1, function(state)
    Parry.enabled = state
end)

--// spam toggle
local spam_toggle = create_toggle(Content, "Spam Parry (Brute Force)", false, 2, function(state)
    Parry.spam_mode = state
end)

--// curve prediction toggle
local curve_toggle = create_toggle(Content, "Curve Ball Prediction", true, 3, function(state)
    -- curve prediction is handled in the engine
    -- this toggle is read during prediction
    BALL_CURVE_ENABLED = state
end)
BALL_CURVE_ENABLED = true

--// distance slider
local dist_slider = create_slider(Content, "Parry Distance (studs)", 6, 25, 14, 4, function(value)
    Parry.max_distance = value
end)

--// timing slider
local timing_slider = create_slider(Content, "Timing Precision (ms)", 50, 500, 100, 5, function(value)
    Parry.tti_threshold = value / 1000
end)

--// cooldown slider
local cooldown_slider = create_slider(Content, "Parry Cooldown (ms)", 30, 300, 60, 6, function(value)
    Parry.min_gap = value / 1000
end)

--// stats bar
local stats_label = create_info(Content, "Parries: 0 | Method: -- | Ball: --", 7)

--// method indicator
local method_label = create_info(Content, "Bypass: initializing...", 8)

--// hotkey hint
local hotkey_label = create_info(Content, "[H] toggle | [RightShift] hide UI", 9)

--// ================================================================
-- MAIN ENGINE LOOP
-- ================================================================

local hidden = false

UserInputService.InputBegan:Connect(function(input, game_processed)
    if game_processed then return end

    if input.KeyCode == Enum.KeyCode.H then
        auto_toggle.set(not Parry.enabled)

    elseif input.KeyCode == Enum.KeyCode.RightShift then
        hidden = not hidden
        Main.Visible = not hidden
    end
end)

--// update bypass method indicator
task.spawn(function()
    while true do
        task.wait(0.5)

        local method = "none"
        if Bypass.internal_function then
            method = "internal ✓"
        elseif Bypass.token_generator then
            method = "token ✓"
        elseif captured then
            method = "replay ✓"
        elseif Bypass.target_remote then
            method = "remote ✓"
        end

        method_label.Text = "Bypass: " .. method

        if captured and status_label then
            status_label.Text = "✓ Packet captured — ready"
        elseif Bypass.target_remote then
            status_label.Text = "✓ Remote found — " .. Bypass.target_remote.Name
        elseif Bypass.internal_function then
            status_label.Text = "✓ Internal function active"
        else
            status_label.Text = "⚠ Parry manually once to capture"
        end
    end
end)

--// main loop
RunService.Heartbeat:Connect(function()
    if not Parry.enabled then return end

    -- update ball tracking every frame
    update_ball_tracking()

    local ball = Ball.instance
    if not ball then
        stats_label.Text = string.format("Parries: %d | Method: %s | Ball: not found",
            Parry.count, Parry.method_used)
        return
    end

    -- spam mode: just fire as fast as possible when ball is close
    if Parry.spam_mode then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild('HumanoidRootPart')
            if root then
                local dist = (ball.Position - root.Position).Magnitude
                if dist < Parry.max_distance then
                    -- fire at spam rate
                    local now = os.clock()
                    if now - Parry.last_fire >= Parry.spam_rate then
                        execute_parry()
                    end
                end
            end
        end
        return
    end

    -- precision mode: calculate exact timing
    local tti, approaching, dist = time_to_impact()

    if not approaching then
        stats_label.Text = string.format("Parries: %d | Method: %s | Ball: %d studs (away)",
            Parry.count, Parry.method_used, math.floor(dist))
        return
    end

    stats_label.Text = string.format("Parries: %d | Method: %s | Ball: %d studs | TTI: %.2fs | %s",
        Parry.count, Parry.method_used, math.floor(dist), tti,
        Ball.curve_detected and "CURVED" or "straight")

    -- parry when conditions are met
    if dist <= Parry.max_distance and tti <= Parry.tti_threshold then
        execute_parry()
    end
end)

print("[BB] === premium autoparry loaded ===")
print("[BB] press H to toggle | right-shift to hide UI")
print("[BB] parry manually once to enable token bypass")
