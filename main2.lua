--[[
    BLADE BALL — SILENT AUTOPARRY
    zero hooks. zero remote calls. zero detection vectors.
    
    method: find the game's parry button → fire its signal
    the game itself handles tokens, remotes, anti-cheat. 
    we just "click" the button programmatically.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// detect executor features
local has_firesignal = typeof(firesignal) == 'function'
local has_getconnections = typeof(getconnections) == 'function'
local has_gethui = typeof(gethui) == 'function'
local has_mouse1click = typeof(mouse1click) == 'function'
local has_gethuiParent = typeof(gethuiParent) == 'function'

--// ================================================================
-- STATE
-- ================================================================

local State = {
    enabled = false,
    spam = false,
    parry_count = 0,
    last_fire = 0,
    min_gap = 0.07,

    -- parry button
    parry_button = nil,
    button_found = false,

    -- method
    method = "none",

    -- ball
    ball = nil,

    -- settings
    distance = 18,
    tti_threshold = 0.45,

    -- ui
    hidden = false,
}

--// ================================================================
-- FIND THE PARRY BUTTON
-- Blade Ball has a parry button on screen (especially mobile)
-- we scan PlayerGui for it by looking at size, position, and connections
-- ================================================================

local function scan_for_parry_button()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local candidates = {}

    local function scan_gui(container, depth)
        if depth > 6 then return end -- don't go too deep

        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("GuiButton") then
                -- check for parry-related text nearby
                local text = ""

                -- the button itself might have text
                if obj:IsA("TextButton") then
                    text = obj.Text or ""
                end

                -- or a child label
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("TextLabel") then
                        text = text .. " " .. (child.Text or "")
                    end
                end

                -- check the parent's siblings for labels
                if obj.Parent and not obj.Parent:IsA("ScreenGui") then
                    for _, sibling in ipairs(obj.Parent:GetChildren()) do
                        if sibling:IsA("TextLabel") then
                            text = text .. " " .. (sibling.Text or "")
                        end
                    end
                end

                local lower = string.lower(text)

                -- match parry-related text
                if lower:find("parry") or lower:find("deflect")
                    or lower:find("block") or lower:find("swing")
                    or lower:find("hit") or lower:find("tap")
                    or lower:find("click") or lower:find("slash") then

                    table.insert(candidates, {
                        button = obj,
                        text = text,
                        depth = depth,
                        connections = 0,
                    })
                end
            end

            -- recurse into frames
            if obj:IsA("Frame") or obj:IsA("ScreenGui")
                or obj:IsA("ScrollingFrame") or obj:IsA("CanvasGroup") then
                scan_gui(obj, depth + 1)
            end

            -- some games wrap buttons in Billboards or other containers
            if obj:IsA("Folder") then
                scan_gui(obj, depth + 1)
            end
        end
    end

    scan_gui(playerGui, 0)

    -- if we found named candidates, pick the best one
    if #candidates > 0 then
        -- prefer buttons with firesignal connections
        if has_getconnections then
            for _, candidate in ipairs(candidates) do
                local connections = getconnections(candidate.button.MouseButton1Click)
                if #connections > 0 then
                    candidate.connections = #connections
                end
                -- also check Activated for mobile
                local activated = getconnections(candidate.button.Activated)
                if #activated > 0 then
                    candidate.connections += #activated
                end
            end
        end

        -- sort by connections (most connected = most likely the real button)
        table.sort(candidates, function(a, b)
            return a.connections > b.connections
        end)

        return candidates[1].button
    end

    -- fallback: look for large centered buttons that are always visible
    -- blade ball's parry button is typically large, center-bottom or center-screen
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("GuiButton") then
                    local pos = obj.Position
                    local size = obj.Size

                    -- large button in center-ish area
                    local center_x = pos.X.Scale + size.X.Scale / 2
                    local center_y = pos.Y.Scale + size.Y.Scale / 2

                    local is_center = center_x > 0.25 and center_x < 0.75
                        and center_y > 0.3 and center_y < 0.9

                    local is_big = size.X.Scale > 0.1 or size.X.Offset > 80
                    local is_big_y = size.Y.Scale > 0.08 or size.Y.Offset > 60

                    if is_center and is_big and is_big_y then
                        -- check it has connections (is actually functional)
                        if has_getconnections then
                            local clicks = getconnections(obj.MouseButton1Click)
                            local activated = getconnections(obj.Activated)
                            if #clicks > 0 or #activated > 0 then
                                return obj
                            end
                        else
                            return obj
                        end
                    end
                end
            end
        end
    end

    return nil
end

--// ================================================================
-- FIRE THE PARRY BUTTON
-- this is the bypass — we trigger the game's own button
-- the game's own code handles everything (tokens, remotes, validation)
-- ================================================================

local function press_parry_button()
    local button = State.parry_button
    if not button or not button.Parent then return false end

    -- METHOD 1: firesignal on the button's events
    if has_firesignal then
        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
        pcall(function()
            firesignal(button.Activated)
        end)
        State.method = "signal"
        State.parry_count += 1
        return true
    end

    -- METHOD 2: getconnections — call the connected functions directly
    if has_getconnections then
        local fired = false

        for _, conn in ipairs(getconnections(button.MouseButton1Click)) do
            if conn.Function then
                pcall(function()
                    conn:Fire()
                end)
                fired = true
            end
        end

        for _, conn in ipairs(getconnections(button.Activated)) do
            if conn.Function then
                pcall(function()
                    conn:Fire()
                end)
                fired = true
            end
        end

        if fired then
            State.method = "connections"
            State.parry_count += 1
            return true
        end
    end

    -- METHOD 3: virtual click via VirtualInputManager at button position
    -- less safe but works when signals aren't available
    local vim_ok, vim = pcall(function()
        return game:GetService("VirtualInputManager")
    end)

    if vim_ok and vim then
        local abs_pos = button.AbsolutePosition
        local abs_size = button.AbsoluteSize

        local click_x = abs_pos.X + abs_size.X / 2
        local click_y = abs_pos.Y + abs_size.Y / 2

        -- only use if button is actually on screen
        if click_x > 0 and click_y > 0 and click_x < Camera.ViewportSize.X
            and click_y < Camera.ViewportSize.Y then

            vim:SendMouseButtonEvent(click_x, click_y, 0, true, game, 0)
            task.wait(0.02)
            vim:SendMouseButtonEvent(click_x, click_y, 0, false, game, 0)

            State.method = "vim"
            State.parry_count += 1
            return true
        end
    end

    -- METHOD 4: mouse1click at button position
    if has_mouse1click then
        local abs_pos = button.AbsolutePosition
        local abs_size = button.AbsoluteSize

        -- move mouse to button center and click
        if mousemoverel then
            -- this requires knowing current mouse pos, complex
            -- skip for now
        end
    end

    return false
end

--// ================================================================
-- BALL FINDER — property-based
-- ================================================================

local function is_ball_part(part)
    if not part:IsA("BasePart") then return false end
    if part:IsA("Terrain") then return false end
    if part.Anchored then return false end
    if part:IsA("SpawnLocation") then return false end

    -- skip player character parts
    local model = part:FindFirstAncestorOfClass("Model")
    if model and Players:GetPlayerFromCharacter(model) then
        return false
    end

    local vel = part.AssemblyLinearVelocity or Vector3.zero
    if vel.Magnitude < 25 then return false end

    -- blade ball is small
    if part.Size.X > 20 or part.Size.Y > 20 or part.Size.Z > 20 then
        return false
    end

    return true
end

local ball_cache = nil
local ball_cache_time = 0

local function find_ball()
    -- cached
    if ball_cache and ball_cache.Parent then
        local vel = ball_cache.AssemblyLinearVelocity or Vector3.zero
        if vel.Magnitude > 5 then
            State.ball = ball_cache
            return ball_cache
        end
        -- stale cache
        if os.clock() - ball_cache_time > 3 then
            ball_cache = nil
        else
            return ball_cache
        end
    end

    -- direct name search (fast)
    for _, name in ipairs({"Ball", "ball", "BALL", "Projectile", "projectile"}) do
        local b = Workspace:FindFirstChild(name)
        if b and b:IsA("BasePart") then
            ball_cache = b
            ball_cache_time = os.clock()
            State.ball = b
            return b
        end
    end

    -- folder search
    for _, folderName in ipairs({"Game", "Map", "Elements", "Arena", "Active", "Balls"}) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("BasePart") and is_ball_part(child) then
                    ball_cache = child
                    ball_cache_time = os.clock()
                    State.ball = child
                    return child
                end
            end
        end
    end

    -- deep property scan
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and is_ball_part(obj) then
            ball_cache = obj
            ball_cache_time = os.clock()
            State.ball = obj
            return obj
        end

        if not obj:IsA("Terrain") then
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BasePart") and is_ball_part(child) then
                    ball_cache = child
                    ball_cache_time = os.clock()
                    State.ball = child
                    return child
                end
            end
        end
    end

    State.ball = nil
    return nil
end

--// ================================================================
-- BALL APPROACH DETECTION
-- ================================================================

local function get_ball_info()
    local ball = find_ball()
    if not ball then return nil end

    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local ball_pos = ball.Position
    local ball_vel = ball.AssemblyLinearVelocity or Vector3.zero
    local my_pos = root.Position

    local dist = (ball_pos - my_pos).Magnitude

    if ball_vel.Magnitude < 1 then
        return { dist = dist, approaching = false, tti = math.huge }
    end

    local to_me = (my_pos - ball_pos).Unit
    local direction = ball_vel.Unit
    local dot = direction:Dot(to_me)

    -- generous threshold because blade ball curves
    local approaching = dot > 0.35

    local closing = ball_vel:Dot(to_me)
    local tti = math.huge
    if closing > 0.5 then
        tti = dist / closing
    end

    return {
        dist = dist,
        approaching = approaching,
        tti = tti,
        speed = ball_vel.Magnitude,
        dot = dot,
    }
end

--// ================================================================
-- UI — parented to gethui() or CoreGui (not PlayerGui)
-- this avoids GUI detection
-- ================================================================

-- determine safe parent
local function get_ui_parent()
    if has_gethui then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end

    -- try gethuiParent (some executors)
    if has_gethuiParent then
        local ok, result = pcall(gethuiParent)
        if ok and result then return result end
    end

    -- CoreGui fallback
    local ok, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok then return coreGui end

    -- last resort: PlayerGui with random name
    return LocalPlayer:WaitForChild("PlayerGui")
end

local uiParent = get_ui_parent()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GameUI_" .. tostring(math.random(1000, 9999))
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = uiParent

--// main panel
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 230, 0, 350)
Main.Position = UDim2.new(0.5, -115, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(70, 60, 160)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.3
MainStroke.Parent = Main

--// drag support
do
    local dragging = false
    local dragInput, dragStart, startPos

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--// header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Header.BorderSizePixel = 0
Header.Parent = Main

Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(120, 100, 255)
Title.Text = "BLADE BALL AP v5"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

--// content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -50)
Content.Position = UDim2.new(0, 8, 0, 44)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 5)
Layout.Parent = Content

--// helpers (touch + mouse)
local function make_toggle(text, default, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = default
        and Color3.fromRGB(45, 35, 110)
        or Color3.fromRGB(25, 25, 35)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Parent = Content

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(220, 220, 240)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 40, 0, 20)
    indicator.Position = UDim2.new(1, -50, 0.5, -10)
    indicator.BackgroundColor3 = default
        and Color3.fromRGB(90, 255, 130)
        or Color3.fromRGB(70, 70, 80)
    indicator.BorderSizePixel = 0
    indicator.Parent = btn

    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 10)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = default
        and UDim2.new(1, -19, 0.5, -8)
        or UDim2.new(0, 2, 0.5, -8)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = indicator

    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 8)

    local state = default

    local function toggle()
        state = not state
        btn.BackgroundColor3 = state
            and Color3.fromRGB(45, 35, 110)
            or Color3.fromRGB(25, 25, 35)
        indicator.BackgroundColor3 = state
            and Color3.fromRGB(90, 255, 130)
            or Color3.fromRGB(70, 70, 80)
        dot.Position = state
            and UDim2.new(1, -19, 0.5, -8)
            or UDim2.new(0, 2, 0.5, -8)
        if callback then callback(state) end
    end

    btn.TouchTap:Connect(toggle)
    btn.MouseButton1Click:Connect(function()
        if not UserInputService.TouchEnabled then
            toggle()
        end
    end)

    return {
        set = function(v)
            if state ~= v then toggle() end
        end,
        get = function() return state end,
    }
end

local function make_slider(text, min, max, default, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 58)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(180, 180, 200)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 45, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 4)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 11
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

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 60, 190)
    fill.BorderSizePixel = 0
    fill.Parent = track

    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 13)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new((default - min) / (max - min), -11, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(190, 180, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track

    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 11)

    local value = default
    local dragging = false

    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
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
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return { get = function() return value end }
end

local function make_info(text, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = Content

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return label
end

--// ================================================================
-- BUILD UI
-- ================================================================

local status_bar = make_info("⏳ searching for parry button...", 0)

local toggle_auto = make_toggle("AUTO PARRY", false, 1, function(v)
    State.enabled = v
end)

local toggle_spam = make_toggle("SPAM MODE", false, 2, function(v)
    State.spam = v
end)

local slider_dist = make_slider("Distance", 8, 30, 18, 3, function(v)
    State.distance = v
end)

local slider_timing = make_slider("Timing (ms)", 100, 600, 400, 4, function(v)
    State.tti_threshold = v / 1000
end)

local slider_cooldown = make_slider("Cooldown (ms)", 40, 500, 80, 5, function(v)
    State.min_gap = v / 1000
end)

local stats_bar = make_info("Parries: 0 | Method: --", 6)

--// floating toggle button
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(1, -55, 0.3, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 200)
FloatBtn.Text = "⚡"
FloatBtn.TextSize = 20
FloatBtn.Font = Enum.Font.GothamBold
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
FloatBtn.MouseButton1Click:Connect(function()
    if not UserInputService.TouchEnabled then
        toggle_ui()
    end
end)

--// keyboard shortcut (pc)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H then
        toggle_auto.set(not State.enabled)
    end
end)

--// ================================================================
-- BUTTON SCANNER — keep looking for the parry button
-- ================================================================

task.spawn(function()
    while true do
        if not State.button_found or (State.parry_button and not State.parry_button.Parent) then
            State.button_found = false
            State.parry_button = nil

            local btn = scan_for_parry_button()
            if btn then
                State.parry_button = btn
                State.button_found = true
                status_bar.Text = "✓ parry button: " .. btn.Name
                print("[BB] Found parry button: " .. btn:GetFullName())
            else
                status_bar.Text = "⏳ searching... (join a match)"
            end
        end

        task.wait(2)
    end
end)

--// ================================================================
-- MAIN LOOP
-- ================================================================

RunService.Heartbeat:Connect(function()
    if not State.enabled and not State.spam then
        stats_bar.Text = string.format("Parries: %d | Method: %s | Btn: %s",
            State.parry_count, State.method,
            State.button_found and "✓" or "✗")
        return
    end

    if not State.button_found then
        stats_bar.Text = "Parries: 0 | Waiting for button..."
        return
    end

    local info = get_ball_info()
    if not info then
        stats_bar.Text = string.format("Parries: %d | Ball: not found",
            State.parry_count)
        return
    end

    -- rate limit
    local now = os.clock()
    if now - State.last_fire < State.min_gap then return end

    -- SPAM MODE
    if State.spam then
        if info.dist <= State.distance then
            if press_parry_button() then
                State.last_fire = now
            end
        end
        stats_bar.Text = string.format("Parries: %d | Method: %s | Ball: %d ⚡",
            State.parry_count, State.method, math.floor(info.dist))
        return
    end

    -- PRECISION MODE
    if State.enabled then
        if info.approaching and info.dist <= State.distance then
            if info.tti <= State.tti_threshold then
                if press_parry_button() then
                    State.last_fire = now
                end
            end
        end
    end

    stats_bar.Text = string.format("Parries: %d | Method: %s | Ball: %d %s",
        State.parry_count, State.method, math.floor(info.dist),
        info.approaching and "→" or "←")
end)

--// ================================================================
-- INIT
-- ================================================================

print("[BB] === Silent Autoparry v5 ===")
print("[BB] Executor features:")
print("[BB]   firesignal: " .. tostring(has_firesignal))
print("[BB]   getconnections: " .. tostring(has_getconnections))
print("[BB]   gethui: " .. tostring(has_gethui))
print("[BB]   mouse1click: " .. tostring(has_mouse1click))
print("[BB] UI parent: " .. uiParent.Name)
print("[BB] No hooks installed. No remotes touched.")
print("[BB] The game's own button will be triggered.")
print("[BB] Waiting for parry button detection...")
