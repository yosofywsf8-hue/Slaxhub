-- ============================================================
-- Nana UI — Delta Compatible Framework
-- Window + Tabs + Sections + Buttons + Toggles + Sliders
-- + Dropdowns + Keybinds + Textboxes + Notifications
-- ============================================================

if _G._nana then
    pcall(function() _G._nana:Destroy() end)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer

local COLORS = {
    bg          = Color3.fromRGB(12, 12, 12),
    panel       = Color3.fromRGB(18, 18, 18),
    section     = Color3.fromRGB(22, 22, 22),
    element     = Color3.fromRGB(28, 28, 28),
    element_hov = Color3.fromRGB(36, 36, 36),
    border      = Color3.fromRGB(45, 45, 45),
    border_act  = Color3.fromRGB(255, 255, 255),
    text        = Color3.fromRGB(240, 240, 240),
    text_dim    = Color3.fromRGB(150, 150, 150),
    text_mute   = Color3.fromRGB(100, 100, 100),
    accent      = Color3.fromRGB(255, 255, 255),
    success     = Color3.fromRGB(80, 220, 120),
    danger      = Color3.fromRGB(230, 70, 70),
}

local FONT      = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MONO = Enum.Font.Code
local TS_INFO   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ============================================================
-- UTILS
-- ============================================================
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 4), Parent = parent })
end

local function stroke(parent, c, t)
    return new("UIStroke", {
        Color = c or COLORS.border,
        Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function pad(parent, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0),
        PaddingBottom = UDim.new(0, b or l or 0),
        Parent = parent,
    })
end

local function getParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
local NotifyGui = nil
local queue = {}
local MAX_N = 6

local function notify(title, content, duration, color)
    duration = duration or 4
    color = color or COLORS.border_act

    if not NotifyGui or not NotifyGui.Parent then
        NotifyGui = new("ScreenGui", {
            Name = "nana_notify",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 100,
            Parent = getParent(),
        })
    end

    local card = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 400, 0, 20),
        Size = UDim2.new(0, 280, 0, 60),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = NotifyGui,
    })
    corner(card, 6)
    stroke(card, COLORS.border, 1)

    new("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = card,
    })

    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        Text = title,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 30),
        Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = content,
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    table.insert(queue, 1, card)
    if #queue > MAX_N then
        local old = table.remove(queue, MAX_N + 1)
        if old and old.Parent then old:Destroy() end
    end

    local y = 20
    for _, c in ipairs(queue) do
        local target = UDim2.new(1, -20, 0, y)
        TS:Create(c, TS_INFO, { Position = target }):Play()
        y = y + 68
    end

    task.delay(duration, function()
        if not card or not card.Parent then return end
        local out = UDim2.new(1, 400, 0, card.Position.Y.Offset)
        local t = TS:Create(card, TS_INFO, { Position = out })
        t:Play()
        t.Completed:Wait()
        for i, c in ipairs(queue) do
            if c == card then table.remove(queue, i) break end
        end
        card:Destroy()
        local yy = 20
        for _, c in ipairs(queue) do
            TS:Create(c, TS_INFO, { Position = UDim2.new(1, -20, 0, yy) }):Play()
            yy = yy + 68
        end
    end)
end

-- ============================================================
-- SECTION
-- ============================================================
local Section = {}
Section.__index = Section

function Section.new(parent, name)
    local frame = new("Frame", {
        Name = "Section_" .. name,
        BackgroundColor3 = COLORS.section,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })
    corner(frame, 6)
    stroke(frame, COLORS.border, 1)
    pad(frame, 8, 8, 8, 8)

    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = frame,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = FONT_BOLD,
        Text = string.upper(name),
        TextColor3 = COLORS.text_dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = -1,
        Parent = frame,
    })

    return setmetatable({ _frame = frame, _order = 0 }, Section)
end

function Section:_add(inst)
    self._order = self._order + 1
    inst.LayoutOrder = self._order
    inst.Parent = self._frame
    return inst
end

function Section:Button(text, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
    }))

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = root,
    })
    corner(btn, 4)
    local s = stroke(btn, COLORS.border, 1)

    btn.MouseEnter:Connect(function()
        TS:Create(btn, TS_INFO, { BackgroundColor3 = COLORS.element_hov }):Play()
        TS:Create(s, TS_INFO, { Color = COLORS.border_act }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TS:Create(btn, TS_INFO, { BackgroundColor3 = COLORS.element }):Play()
        TS:Create(s, TS_INFO, { Color = COLORS.border }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        task.spawn(callback or function() end)
    end)

    return {
        SetText = function(_, t) btn.Text = t end,
        SetVisible = function(_, v) root.Visible = v end,
    }
end

function Section:Toggle(text, default, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
    }))

    local state = default == true

    new("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local pill = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 40, 0, 20),
        BackgroundColor3 = state and COLORS.accent or COLORS.element,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = root,
    })
    corner(pill, 10)
    local ps = stroke(pill, state and COLORS.border_act or COLORS.border, 1)

    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = state and COLORS.bg or COLORS.text_dim,
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(dot, 7)

    local function render()
        TS:Create(pill, TS_INFO, { BackgroundColor3 = state and COLORS.accent or COLORS.element }):Play()
        TS:Create(ps, TS_INFO, { Color = state and COLORS.border_act or COLORS.border }):Play()
        TS:Create(dot, TS_INFO, {
            Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = state and COLORS.bg or COLORS.text_dim,
        }):Play()
    end

    pill.MouseButton1Click:Connect(function()
        state = not state
        render()
        task.spawn(callback, state)
    end)

    return {
        Value = function(_, v)
            if v ~= nil then state = v == true; render() end
            return state
        end,
    }
end

function Section:Slider(text, minV, maxV, default, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 46),
    }))

    local state = default or minV

    new("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local vLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.3, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT_MONO,
        Text = tostring(state),
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = root,
    })

    local track = new("Frame", {
        Position = UDim2.new(0, 0, 0, 28),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Parent = root,
    })
    corner(track, 4)

    local fill = new("Frame", {
        Size = UDim2.new((state - minV) / (maxV - minV), 0, 1, 0),
        BackgroundColor3 = COLORS.accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 4)

    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((state - minV) / (maxV - minV), 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = COLORS.text,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 7)

    local dragging = false
    local function setFromInput(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * relX + 0.5)
        state = val
        fill.Size = UDim2.new(relX, 0, 1, 0)
        knob.Position = UDim2.new(relX, 0, 0.5, 0)
        vLabel.Text = tostring(val)
        task.spawn(callback, val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInput(input)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then
                state = math.clamp(v, minV, maxV)
                local relX = (state - minV) / (maxV - minV)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                knob.Position = UDim2.new(relX, 0, 0.5, 0)
                vLabel.Text = tostring(state)
            end
            return state
        end,
    }
end

function Section:Dropdown(text, options, default, callback)
    options = options or {}
    local state = default or options[1]

    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 50),
    }))

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local btn = new("TextButton", {
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT,
        Text = "  " .. tostring(state),
        TextColor3 = COLORS.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = root,
    })
    corner(btn, 4)
    local bs = stroke(btn, COLORS.border, 1)

    new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        Text = "v",
        TextColor3 = COLORS.text_dim,
        TextSize = 11,
        Parent = btn,
    })

    local popup, catcher = nil, nil

    local function closePopup()
        if popup then popup:Destroy(); popup = nil end
        if catcher then catcher:Destroy(); catcher = nil end
        TS:Create(bs, TS_INFO, { Color = COLORS.border }):Play()
    end

    local function openPopup()
        if popup then return end
        TS:Create(bs, TS_INFO, { Color = COLORS.border_act }):Play()

        local rootGui = btn:FindFirstAncestorOfClass("ScreenGui")
        if not rootGui then return end

        catcher = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 998,
            Parent = rootGui,
        })
        catcher.MouseButton1Click:Connect(closePopup)

        local h = math.min(#options * 26 + 8, 200)
        popup = new("Frame", {
            Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4),
            Size = UDim2.new(0, btn.AbsoluteSize.X, 0, h),
            BackgroundColor3 = COLORS.panel,
            BorderSizePixel = 0,
            ZIndex = 999,
            Parent = rootGui,
        })
        corner(popup, 4)
        stroke(popup, COLORS.border, 1)

        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 999,
            Parent = popup,
        })
        pad(scroll, 4)
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

        for i, opt in ipairs(options) do
            local isCur = tostring(opt) == tostring(state)
            local ob = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = isCur and COLORS.element_hov or COLORS.element,
                BorderSizePixel = 0,
                Font = FONT,
                Text = "  " .. tostring(opt),
                TextColor3 = COLORS.text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 999,
                Parent = scroll,
            })
            corner(ob, 3)
            ob.MouseEnter:Connect(function()
                TS:Create(ob, TS_INFO, { BackgroundColor3 = COLORS.element_hov }):Play()
            end)
            ob.MouseLeave:Connect(function()
                TS:Create(ob, TS_INFO, { BackgroundColor3 = isCur and COLORS.element_hov or COLORS.element }):Play()
            end)
            ob.MouseButton1Click:Connect(function()
                state = opt
                btn.Text = "  " .. tostring(opt)
                closePopup()
                task.spawn(callback, opt)
            end)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if popup then closePopup() else openPopup() end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then state = v; btn.Text = "  " .. tostring(v) end
            return state
        end,
        Refresh = function(_, newOpts)
            if newOpts then options = newOpts end
            if popup then closePopup() end
        end,
    }
end

function Section:Keybind(text, default, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
    }))

    local state = default or Enum.KeyCode.Unknown
    local listening = false

    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 80, 0, 24),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT_MONO,
        Text = state.Name,
        TextColor3 = COLORS.text,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = root,
    })
    corner(btn, 4)
    local bs = stroke(btn, COLORS.border, 1)

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        TS:Create(bs, TS_INFO, { Color = COLORS.border_act }):Play()
    end)

    UIS.InputBegan:Connect(function(input, gp)
        if not listening then return end
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            state = input.KeyCode
            btn.Text = state.Name
            listening = false
            TS:Create(bs, TS_INFO, { Color = COLORS.border }):Play()
            task.spawn(callback, state)
        end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then state = v; btn.Text = v.Name end
            return state
        end,
    }
end

function Section:Textbox(text, placeholder, default, multiline, callback)
    local h = multiline and 146 or 56
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, h),
    }))

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local box = new("TextBox", {
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, multiline and 118 or 28),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT_MONO,
        Text = tostring(default or ""),
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = COLORS.text_mute,
        TextColor3 = COLORS.text,
        TextSize = multiline and 12 or 13,
        ClearTextOnFocus = false,
        MultiLine = multiline,
        TextWrapped = multiline,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        Parent = root,
    })
    corner(box, 4)
    local bxs = stroke(box, COLORS.border, 1)
    pad(box, 8, 8, multiline and 6 or 0, multiline and 6 or 0)

    box.Focused:Connect(function()
        TS:Create(bxs, TS_INFO, { Color = COLORS.border_act }):Play()
    end)
    box.FocusLost:Connect(function()
        TS:Create(bxs, TS_INFO, { Color = COLORS.border }):Play()
        task.spawn(callback, box.Text)
    end)

    return {
        Get = function() return box.Text end,
        Set = function(_, v, fire)
            box.Text = tostring(v or "")
            if fire then task.spawn(callback, box.Text) end
        end,
    }
end

function Section:Label(text)
    self:_add(new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text_dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }))
end

-- ============================================================
-- TAB
-- ============================================================
local Tab = {}
Tab.__index = Tab

function Tab.new(parent, name)
    local page = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        Parent = parent,
    })

    local left = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -5, 1, 0),
        Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })

    local right = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 5, 0, 0),
        Size = UDim2.new(0.5, -5, 1, 0),
        Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })

    return setmetatable({
        _page = page,
        _left = left,
        _right = right,
        _lo = 0,
        _ro = 0,
    }, Tab)
end

function Tab:Section(name, side)
    side = side or "left"
    local holder = side == "right" and self._right or self._left
    local sec = Section.new(holder, name)
    if side == "right" then
        self._ro = self._ro + 1
        sec._frame.LayoutOrder = self._ro
    else
        self._lo = self._lo + 1
        sec._frame.LayoutOrder = self._lo
    end
    return sec
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = {}
Window.__index = Window

function Window.new(name, subtitle)
    local sg = new("ScreenGui", {
        Name = "Nana",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 50,
        Parent = getParent(),
    })

    local main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 620, 0, 460),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        Parent = sg,
    })
    corner(main, 8)
    stroke(main, COLORS.border, 1)

    -- Header
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    corner(header, 8)
    new("Frame", {
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = header,
    })

    new("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        Text = name,
        TextColor3 = COLORS.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    if subtitle and subtitle ~= "" then
        new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -50, 0.5, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = FONT,
            Text = subtitle,
            TextColor3 = COLORS.text_mute,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = header,
        })
    end

    local close = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT_BOLD,
        Text = "x",
        TextColor3 = COLORS.text_dim,
        TextSize = 14,
        AutoButtonColor = false,
        Parent = header,
    })
    corner(close, 4)
    close.MouseButton1Click:Connect(function() sg.Enabled = false end)
    close.MouseEnter:Connect(function()
        TS:Create(close, TS_INFO, { BackgroundColor3 = COLORS.danger, TextColor3 = COLORS.text }):Play()
    end)
    close.MouseLeave:Connect(function()
        TS:Create(close, TS_INFO, { BackgroundColor3 = COLORS.element, TextColor3 = COLORS.text_dim }):Play()
    end)

    -- Tab bar
    local tabBar = new("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        Parent = main,
    })
    pad(tabBar, 10, 10, 4, 4)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabBar,
    })

    -- Content
    local content = new("Frame", {
        Position = UDim2.new(0, 0, 0, 74),
        Size = UDim2.new(1, 0, 1, -74),
        BackgroundTransparency = 1,
        Parent = main,
    })
    pad(content, 10, 10, 10, 10)

    -- Drag
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return setmetatable({
        _sg = sg,
        _main = main,
        _tabBar = tabBar,
        _content = content,
        _tabs = {},
        _tabBtns = {},
        _active = nil,
        _order = 0,
    }, Window)
end

function Window:Tab(name)
    self._order = self._order + 1

    local btn = new("TextButton", {
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        Font = FONT,
        Text = string.upper(name),
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = self._order,
        Parent = self._tabBar,
    })
    corner(btn, 4)

    local tab = Tab.new(self._content, name)
    self._tabs[name] = tab
    self._tabBtns[name] = btn

    local win = self
    btn.MouseButton1Click:Connect(function()
        if win._active == name then return end
        win._active = name
        for n, t in pairs(win._tabs) do
            t._page.Visible = (n == name)
        end
        for n, b in pairs(win._tabBtns) do
            TS:Create(b, TS_INFO, {
                BackgroundColor3 = (n == name) and COLORS.element or COLORS.bg,
                TextColor3 = (n == name) and COLORS.text or COLORS.text_dim,
            }):Play()
        end
    end)

    if not self._active then
        self._active = name
        tab._page.Visible = true
        TS:Create(btn, TS_INFO, {
            BackgroundColor3 = COLORS.element,
            TextColor3 = COLORS.text,
        }):Play()
    end

    return tab
end

-- ============================================================
-- PUBLIC API
-- ============================================================
local NanaUI = {}
NanaUI.__index = NanaUI

function NanaUI.new(name, subtitle)
    return Window.new(name or "Nana", subtitle or "")
end

function NanaUI.Notify(title, content, duration)
    notify(title, content, duration, COLORS.border_act)
end

NanaUI.Colors = COLORS

-- ============================================================
-- AUTO-INIT
-- ============================================================
local win = NanaUI.new("Nana", "v1.0")

local combat = win:Tab("combat")
local visual = win:Tab("visual")
local misc   = win:Tab("misc")
local fflags = win:Tab("fflags")

-- sample sections (احذفها لو تبي فاضي)
local parry = combat:Section("parry", "left")
parry:Toggle("auto parry", false, function(v)
    print("[Nana] auto parry:", v)
end)
parry:Slider("accuracy", 1, 100, 100, function(v)
    print("[Nana] accuracy:", v)
end)

local curve = combat:Section("curve", "right")
curve:Dropdown("method", {"camera", "dot", "backwards", "slow", "random"}, "camera", function(v)
    print("[Nana] curve:", v)
end)

local hk = combat:Section("hotkeys", "left")
hk:Keybind("triggerbot", Enum.KeyCode.T, function(k)
    print("[Nana] triggerbot key:", k.Name)
end)

local vis = visual:Section("visual", "left")
vis:Toggle("ability esp", false, function(v)
    print("[Nana] esp:", v)
end)

local profile = fflags:Section("profile", "left")
profile:Textbox("profile name", "default", "default", false, function(v)
    print("[Nana] profile:", v)
end)
profile:Button("save profile", function()
    NanaUI.Notify("Nana", "profile saved", 3)
end)

local json = fflags:Section("fflags json", "right")
json:Textbox("json", '{"FFlag":"1"}', "", true, function(v)
    print("[Nana] json updated")
end)
json:Button("apply fflags", function()
    NanaUI.Notify("Nana", "fflags applied", 3)
end)

NanaUI.Notify("Nana", "loaded successfully", 4)

_G._nana = win._sg

print("[Nana] UI loaded — Nana is live")
