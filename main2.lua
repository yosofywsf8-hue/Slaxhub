--[[
    BLADE BALL — MOBILE AUTOPARRY
    Works on: Delta, Codex, Solara, Arceus X, Fluxus, Wave
    
    Bypass approach:
    → No GC scanning (unreliable across updates)
    → Pure __namecall capture + replay
    → Ball found by properties, not name
    → Touch-friendly UI
]]

--// services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// detect executor capabilities
local EXECUTOR = {
    has_hookmetamethod = typeof(hookmetamethod) == 'function',
    has_getgc = typeof(getgc) == 'function',
    has_getconnections = typeof(getconnections) == 'function',
    has_cloneref = typeof(cloneref) == 'function',
    has_firetouch = typeof(firetouchinterest) == 'function',
    has_fireclick = typeof(fireclickdetector) == 'function',
    has_mouse1click = typeof(mouse1click) == 'function',
    has_virtualinput = typeof(game:GetService('VirtualInputManager')) == 'userdata',
}

--// ================================================================
-- STATE
-- ================================================================

local State = {
    enabled = false,
    spam = false,
    parry_count = 0,
    last_fire = 0,
    min_gap = 0.06,

    -- captured data
    captured_remote = nil,
    captured_args = nil,
    captured = false,

    -- ball
    ball = nil,
    ball_found_time = 0,

    -- settings
    distance = 16,
    tti_threshold = 0.4,

    -- bypass method
    method = "none",
}

--// ================================================================
-- BALL FINDER — property-based, not name-based
-- ================================================================

local function is_ball(part)
    if not part:IsA('BasePart') then return false end
    if part:IsA('Terrain') then return false end

    -- skip character parts
    local model = part:FindFirstAncestorOfClass('Model')
    if model and Players:GetPlayerFromCharacter(model) then
        return false
    end

    local vel = part.AssemblyLinearVelocity or Vector3.zero

    -- blade ball is always fast
    if vel.Magnitude < 30 then return false end

    -- blade ball is typically small
    local size = part.Size
    if size.X > 15 or size.Y > 15 or size.Z > 15 then return false end

    -- not anchored
    if part.Anchored then return false end

    -- can't be a spawn location or map part
    if part:IsA('SpawnLocation') then return false end

    return true
end

local function find_ball()
    -- fast path: cached
    if State.ball and State.ball.Parent then
        local vel = State.ball.AssemblyLinearVelocity or Vector3.zero
        if vel.Magnitude > 5 then
            return State.ball
        end
        -- ball might have stopped (between rallies)
        -- keep it cached for 3 seconds
        if os.clock() - State.ball_found_time < 3 then
            return State.ball
        end
    end

    -- direct name check (fast)
    local names = {'Ball', 'ball', 'BALL', 'Projectile', 'projectile'}
    for _, name in ipairs(names) do
        local b = Workspace:FindFirstChild(name)
        if b and b:IsA('BasePart') then
            State.ball = b
            State.ball_found_time = os.clock()
            return b
        end
    end

    -- search deeper — folders
    local folders = {'Game', 'Map', 'Elements', 'Arena', 'Active'}
    for _, folderName in ipairs(folders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA('BasePart') and is_ball(child) then
                    State.ball = child
                    State.ball_found_time = os.clock()
                    return child
                end
            end
        end
    end

    -- property scan — everything in workspace
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA('BasePart') and is_ball(obj) then
            State.ball = obj
            State.ball_found_time = os.clock()
            return obj
        end

        -- check inside models/folders
        if obj:IsA('Model') or obj:IsA('Folder') then
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA('BasePart') and is_ball(child) then
                    State.ball = child
                    State.ball_found_time = os.clock()
                    return child
                end
            end
        end
    end

    return nil
end

--// ================================================================
-- PARRY CAPTURE — hook ALL remote calls, grab the parry one
-- ================================================================

local function hook_remotes()
    if State.captured then return end

    if EXECUTOR.has_hookmetamethod then
        local old
        old = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
            local method = getnamecallmethod()

            if method == 'FireServer' or method == 'InvokeServer' then
                if not State.captured and self:IsA('RemoteEvent') then
                    local args = {...}
                    local remote_name = string.lower(self.Name)

                    -- broad match: anything that could be the parry remote
                    local is_parry_remote = remote_name:find('parry')
                        or remote_name:find('deflect')
                        or remote_name:find('ability')
                        or remote_name:find('swing')
                        or remote_name:find('attack')
                        or remote_name:find('combat')
                        or remote_name:find('hit')
                        or remote_name:find('skill')
                        or remote_name:find('action')

                    -- also capture if it has typical parry arg patterns
                    if not is_parry_remote and #args >= 2 then
                        local has_cframe = false
                        local has_string = false
                        local has_number = false
                        for _, a in ipairs(args) do
                            local t = typeof(a)
                            if t == 'CFrame' then has_cframe = true end
                            if t == 'string' then has_string = true end
                            if t == 'number' then has_number = true end
                        end
                        -- parry packets typically have CFrame + string/number
                        if has_cframe and (has_string or has_number) then
                            is_parry_remote = true
                        end
                    end

                    if is_parry_remote then
                        State.captured_remote = self
                        State.captured_args = args
                        State.captured = true
                        print(string.format('[BB] Captured remote: %s | args: %d',
                            self.Name, #args))
                    end
                end
            end

            return old(self, ...)
        end))
    else
        -- fallback: manual metatable hook
        local meta = getrawmetatable(game)
        if meta then
            setreadonly(meta, false)
            local old_namecall = meta.__namecall

            meta.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if (method == 'FireServer' or method == 'InvokeServer')
                    and not State.captured
                    and self:IsA('RemoteEvent') then

                    local args = {...}
                    local remote_name = string.lower(self.Name)

                    if remote_name:find('parry') or remote_name:find('deflect')
                        or remote_name:find('ability') or remote_name:find('swing')
                        or remote_name:find('attack') or remote_name:find('combat')
                        or remote_name:find('hit') or remote_name:find('skill') then

                        State.captured_remote = self
                        State.captured_args = args
                        State.captured = true
                        print(string.format('[BB] Captured remote: %s', self.Name))
                    end
                end

                return old_namecall(self, ...)
            end)

            setreadonly(meta, true)
        end
    end
end

--// ================================================================
-- PARRY EXECUTION — multi-method with fallback
-- ================================================================

local function fire_parry()
    local now = os.clock()
    if now - State.last_fire < State.min_gap then return false end

    -- METHOD 1: replay captured packet
    if State.captured and State.captured_remote and State.captured_args then
        local packet = {}
        for i, arg in ipairs(State.captured_args) do
            if typeof(arg) == 'CFrame' then
                packet[i] = Camera.CFrame
            else
                packet[i] = arg
            end
        end

        if State.captured_remote:IsA('RemoteEvent') then
            State.captured_remote:FireServer(unpack(packet))
        else
            pcall(function()
                State.captured_remote:InvokeServer(unpack(packet))
            end)
        end

        State.parry_count += 1
        State.last_fire = now
        State.method = "replay"
        return true
    end

    -- METHOD 2: find remote by name and fire it
    if not State.captured_remote then
        local search_names = {'parry', 'Parry', 'Deflect', 'deflect',
            'Ability', 'ability', 'Swing', 'swing', 'Attack', 'attack'}

        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA('RemoteEvent') then
                for _, name in ipairs(search_names) do
                    if obj.Name:find(name) then
                        State.captured_remote = obj
                        break
                    end
                end
                if State.captured_remote then break end
            end
        end

        -- also check workspace
        if not State.captured_remote then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA('RemoteEvent') then
                    for _, name in ipairs(search_names) do
                        if obj.Name:find(name) then
                            State.captured_remote = obj
                            break
                        end
                    end
                    if State.captured_remote then break end
                end
            end
        end
    end

    if State.captured_remote then
        if State.captured_remote:IsA('RemoteEvent') then
            State.captured_remote:FireServer()
        else
            pcall(function()
                State.captured_remote:InvokeServer()
            end)
        end
        State.parry_count += 1
        State.last_fire = now
        State.method = "remote"
        return true
    end

    -- METHOD 3: simulate click input
    if EXECUTOR.has_virtualinput then
        local vim = game:GetService('VirtualInputManager')
        local mouse = LocalPlayer:GetMouse()

        vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0)

        State.parry_count += 1
        State.last_fire = now
        State.method = "input"
        return true
    end

    return false
end

--// ================================================================
-- BALL TRACKING — is it coming at us?
-- ================================================================

local function get_ball_info()
    local ball = find_ball()
    if not ball then return nil end

    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild('HumanoidRootPart')
    if not root then return nil end

    local ball_pos = ball.Position
    local ball_vel = ball.AssemblyLinearVelocity or Vector3.zero
    local my_pos = root.Position

    local dist = (ball_pos - my_pos).Magnitude

    if ball_vel.Magnitude < 1 then
        return { ball = ball, dist = dist, approaching = false, tti = math.huge }
    end

    local to_me = (my_pos - ball_pos).Unit
    local direction = ball_vel.Unit
    local dot = direction:Dot(to_me)

    local approaching = dot > 0.4  -- generous, blade ball curves a lot

    local closing_speed = ball_vel:Dot(to_me)
    local tti = math.huge
    if closing_speed > 1 then
        tti = dist / closing_speed
    end

    return {
        ball = ball,
        dist = dist,
        approaching = approaching,
        tti = tti,
        speed = ball_vel.Magnitude,
        dot = dot,
    }
end

--// ================================================================
-- MOBILE UI — touch-friendly, compact, draggable
-- ================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BBMobile"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--// main panel
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 240, 0, 340)
Main.Position = UDim2.new(0.5, -120, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 80, 200)
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = Main

--// drag support (touch + mouse)
do
    local dragging = false
    local drag_start, start_pos

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            drag_start = input.Position
            start_pos = Main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag_start
            Main.Position = UDim2.new(
                start_pos.X.Scale, start_pos.X.Offset + delta.X,
                start_pos.Y.Scale, start_pos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--// header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Header.BorderSizePixel = 0
Header.Parent = Main

Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextColor3 = Color3.fromRGB(130, 100, 255)
Title.Text = "⚡ BLADE BALL AUTOPARRY"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

--// content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -52)
Content.Position = UDim2.new(0, 8, 0, 42)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 6)
Layout.Parent = Content

--// toggle helper (big touch targets)
local function make_toggle(text, default, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.BackgroundColor3 = default
        and Color3.fromRGB(60, 40, 140)
        or Color3.fromRGB(30, 30, 40)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Parent = Content

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 44, 0, 20)
    indicator.Position = UDim2.new(1, -54, 0.5, -10)
    indicator.BackgroundColor3 = default
        and Color3.fromRGB(100, 255, 140)
        or Color3.fromRGB(80, 80, 90)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 10)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = default
        and UDim2.new(1, -20, 0.5, -8)
        or UDim2.new(0, 2, 0.5, -8)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = indicator

    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 8)

    local state = default

    btn.TouchTap:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state
                and Color3.fromRGB(60, 40, 140)
                or Color3.fromRGB(30, 30, 40)
        }):Play()
        TweenService:Create(indicator, TweenInfo.new(0.15), {
            BackgroundColor3 = state
                and Color3.fromRGB(100, 255, 140)
                or Color3.fromRGB(80, 80, 90)
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = state
                and UDim2.new(1, -20, 0.5, -8)
                or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if callback then callback(state) end
    end)

    btn.MouseButton1Click:Connect(function()
        -- also work on pc
        if UserInputService.TouchEnabled then return end
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state
                and Color3.fromRGB(60, 40, 140)
                or Color3.fromRGB(30, 30, 40)
        }):Play()
        TweenService:Create(indicator, TweenInfo.new(0.15), {
            BackgroundColor3 = state
                and Color3.fromRGB(100, 255, 140)
                or Color3.fromRGB(80, 80, 90)
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = state
                and UDim2.new(1, -20, 0.5, -8)
                or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if callback then callback(state) end
    end)

    return {
        set = function(v)
            state = v
            btn.BackgroundColor3 = state
                and Color3.fromRGB(60, 40, 140)
                or Color3.fromRGB(30, 30, 40)
            indicator.BackgroundColor3 = state
                and Color3.fromRGB(100, 255, 140)
                or Color3.fromRGB(80, 80, 90)
            dot.Position = state
                and UDim2.new(1, -20, 0.5, -8)
                or UDim2.new(0, 2, 0.5, -8)
            if callback then callback(state) end
        end,
        get = function() return state end,
    }
end

--// slider helper (touch-friendly track)
local function make_slider(text, min, max, default, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 56)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(180, 180, 200)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local value_label = Instance.new("TextLabel")
    value_label.Size = UDim2.new(0, 45, 0, 20)
    value_label.Position = UDim2.new(1, -52, 0, 4)
    value_label.BackgroundTransparency = 1
    value_label.Font = Enum.Font.GothamBold
    value_label.TextSize = 12
    value_label.TextColor3 = Color3.fromRGB(130, 100, 255)
    value_label.Text = tostring(default)
    value_label.TextXAlignment = Enum.TextXAlignment.Right
    value_label.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 24)
    track.Position = UDim2.new(0, 10, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    track.BorderSizePixel = 0
    track.Parent = frame

    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 12)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
    fill.BorderSizePixel = 0
    fill.Parent = track

    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new((default - min) / (max - min), -10, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(200, 190, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track

    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 10)

    local value = default
    local dragging = false

    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -10, 0.5, -10)
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
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
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
        get = function() return value end,
    }
end

--// info bar helper
local function make_info(text, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextColor3 = Color3.fromRGB(130, 130, 150)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return label
end

--// ================================================================
-- BUILD UI
-- ================================================================

local status_bar = make_info("⏳ PARRY ONCE TO CAPTURE", 0)

local toggle_auto = make_toggle("AUTO PARRY", false, 1, function(state)
    State.enabled = state
end)

local toggle_spam = make_toggle("SPAM MODE", false, 2, function(state)
    State.spam = state
end)

local slider_distance = make_slider("Distance (studs)", 8, 30, 16, 3, function(v)
    State.distance = v
end)

local slider_timing = make_slider("Timing (ms)", 100, 600, 350, 4, function(v)
    State.tti_threshold = v / 1000
end)

local slider_cooldown = make_slider("Cooldown (ms)", 30, 500, 80, 5, function(v)
    State.min_gap = v / 1000
end)

local stats_bar = make_info("Parries: 0 | Method: --", 6)
local hint_bar = make_info("Parry manually once, then turn ON", 7)

--// floating toggle button (always visible, tap to show/hide panel)
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 48, 0, 48)
FloatBtn.Position = UDim2.new(1, -60, 0.5, -24)
FloatBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
FloatBtn.Text = "⚡"
FloatBtn.TextSize = 22
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.Parent = ScreenGui
FloatBtn.ZIndex = 100

Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 24)

local ui_visible = true
FloatBtn.TouchTap:Connect(function()
    ui_visible = not ui_visible
    Main.Visible = ui_visible
end)

FloatBtn.MouseButton1Click:Connect(function()
    if UserInputService.TouchEnabled then return end
    ui_visible = not ui_visible
    Main.Visible = ui_visible
end)

--// ================================================================
-- MAIN LOOP
-- ================================================================

hook_remotes()

RunService.Heartbeat:Connect(function()
    -- update status
    if State.captured then
        status_bar.Text = "✓ Captured: " .. State.captured_remote.Name
    else
        -- try to find remote by name if not captured yet
        if not State.captured_remote then
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA('RemoteEvent') then
                    local n = string.lower(obj.Name)
                    if n:find('parry') or n:find('deflect')
                        or n:find('ability') or n:find('swing')
                        or n:find('attack') then
                        State.captured_remote = obj
                        print('[BB] Found remote by scan: ' .. obj.Name)
                        break
                    end
                end
            end
        end
        if State.captured_remote then
            status_bar.Text = "✓ Remote found: " .. State.captured_remote.Name
        else
            status_bar.Text = "⏳ PARRY ONCE TO CAPTURE"
        end
    end

    if not State.enabled and not State.spam then
        stats_bar.Text = string.format("Parries: %d | Method: %s",
            State.parry_count, State.method)
        return
    end

    -- get ball info
    local info = get_ball_info()

    if not info then
        stats_bar.Text = string.format("Parries: %d | Method: %s | Ball: ❌",
            State.parry_count, State.method)
        return
    end

    -- update stats
    local status_str = string.format("Parries: %d | Method: %s | Ball: %d studs %s",
        State.parry_count, State.method, math.floor(info.dist),
        info.approaching and "→" or "←")

    -- SPAM MODE: fire whenever ball is close
    if State.spam then
        if info.dist <= State.distance then
            fire_parry()
        end
        stats_bar.Text = status_str .. " | SPAM"
        return
    end

    -- PRECISION MODE: fire when ball approaching + within threshold
    if State.enabled then
        if info.approaching and info.dist <= State.distance then
            -- fire when time to impact is short enough
            if info.tti <= State.tti_threshold then
                fire_parry()
            end
        end
    end

    stats_bar.Text = status_str
end)

print("[BB] === Blade Ball Mobile Autoparry ===")
print("[BB] Executor: " .. (EXECUTOR.has_hookmetamethod and "full" or "limited"))
print("[BB] Instructions:")
print("[BB] 1. Join a match")
print("[BB] 2. Parry manually ONCE (tap/click)")
print("[BB] 3. Turn ON Auto Parry")
print("[BB] 4. That's it.")
