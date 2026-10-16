-- ============================================================
-- Oxy UI Clone — مطابق للصورة
-- Standalone, Delta-compatible, no external libraries
-- ============================================================

if _G._oxy_clone then
    pcall(function() _G._oxy_clone:Destroy() end)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- ============================================================
-- COLORS — من الصورة
-- ============================================================
local C = {
    bg          = Color3.fromRGB(13, 13, 13),      -- خلفية الـ window
    sidebar     = Color3.fromRGB(18, 18, 18),      -- خلفية الـ sidebar
    tab_active  = Color3.fromRGB(35, 35, 35),      -- تاب نشط
    tab_hover   = Color3.fromRGB(28, 28, 28),
    border      = Color3.fromRGB(50, 50, 50),
    border_act  = Color3.fromRGB(90, 130, 200),    -- أزرق التاب النشط
    text        = Color3.fromRGB(255, 255, 255),
    text_dim    = Color3.fromRGB(180, 180, 180),
    text_mute   = Color3.fromRGB(130, 130, 130),
    track       = Color3.fromRGB(60, 60, 60),
    fill        = Color3.fromRGB(255, 255, 255),
    toggle_off  = Color3.fromRGB(70, 70, 70),
    toggle_on   = Color3.fromRGB(255, 255, 255),
    elem        = Color3.fromRGB(28, 28, 28),
    elem_hover  = Color3.fromRGB(38, 38, 38),
}

local FONT      = Enum.Font.Gotham
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
        Color = c or C.border,
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
-- SECTION — عنوان bold فوق، وعناصر تحته
-- ============================================================
local Section = {}
Section.__index = Section

function Section.new(parent, name)
    local root = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        Font = FONT_BOLD,
        Text = name,
        TextColor3 = C.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local content = new("Frame", {
        Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = root,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = content,
    })

    return setmetatable({ _root = root, _content = content, _order = 0 }, Section)
end

function Section:_add(inst)
    self._order = self._order + 1
    inst.LayoutOrder = self._order
    inst.Parent = self._content
    return inst
end

function Section:Toggle(text, default, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
    }))

    local state = default == true

    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = C.text_dim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local pill = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 36, 0, 18),
        BackgroundColor3 = state and C.toggle_on or C.toggle_off,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = root,
    })
    corner(pill, 9)

    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = state and C.bg or C.text,
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(dot, 6)

    local function render()
        TS:Create(pill, TS_INFO, { BackgroundColor3 = state and C.toggle_on or C.toggle_off }):Play()
        TS:Create(dot, TS_INFO, {
            Position = state and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = state and C.bg or C.text,
        }):Play()
    end

    pill.MouseButton1Click:Connect(function()
        state = not state
        render()
        task.spawn(callback or function() end, state)
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
        Size = UDim2.new(1, 0, 0, 42),
    }))

    local state = default or minV

    new("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = C.text_dim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local vLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 40, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = tostring(state),
        TextColor3 = C.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = root,
    })

    local track = new("Frame", {
        Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = C.track,
        BorderSizePixel = 0,
        Parent = root,
    })
    corner(track, 2)

    local fill = new("Frame", {
        Size = UDim2.new((state - minV) / (maxV - minV), 0, 1, 0),
        BackgroundColor3 = C.fill,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 2)

    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((state - minV) / (maxV - minV), 0, 0.5, 0),
        Size = UDim2.new(0, 11, 0, 11),
        BackgroundColor3 = C.fill,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 6)

    local dragging = false
    local function setFromInput(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * relX + 0.5)
        state = val
        fill.Size = UDim2.new(relX, 0, 1, 0)
        knob.Position = UDim2.new(relX, 0, 0.5, 0)
        vLabel.Text = tostring(val)
        task.spawn(callback or function() end, val)
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
        Size = UDim2.new(1, 0, 0, 28),
    }))

    new("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = C.text_dim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 110, 0, 22),
        BackgroundColor3 = C.elem,
        BorderSizePixel = 0,
        Font = FONT,
        Text = tostring(state) .. "  v",
        TextColor3 = C.text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        AutoButtonColor = false,
        Parent = root,
    })
    corner(btn, 3)
    stroke(btn, C.border, 1)

    local popup, catcher = nil, nil

    local function closePopup()
        if popup then popup:Destroy(); popup = nil end
        if catcher then catcher:Destroy(); catcher = nil end
    end

    local function openPopup()
        if popup then return end
        local guiRoot = btn:FindFirstAncestorOfClass("ScreenGui")
        if not guiRoot then return end

        catcher = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 998,
            Parent = guiRoot,
        })
        catcher.MouseButton1Click:Connect(closePopup)

        local h = math.min(#options * 22 + 8, 180)
        popup = new("Frame", {
            Position = UDim2.new(0, btn.AbsolutePosition.X,
                0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 2),
            Size = UDim2.new(0, btn.AbsoluteSize.X, 0, h),
            BackgroundColor3 = C.bg,
            BorderSizePixel = 0,
            ZIndex = 999,
            Parent = guiRoot,
        })
        corner(popup, 3)
        stroke(popup, C.border, 1)

        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 999,
            Parent = popup,
        })
        pad(scroll, 3)
        new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

        for i, opt in ipairs(options) do
            local ob = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = (tostring(opt) == tostring(state)) and C.elem_hover or C.elem,
                BorderSizePixel = 0,
                Font = FONT,
                Text = tostring(opt),
                TextColor3 = C.text,
                TextSize = 11,
                AutoButtonColor = false,
                LayoutOrder = i,
                ZIndex = 999,
                Parent = scroll,
            })
            corner(ob, 2)
            ob.MouseButton1Click:Connect(function()
                state = opt
                btn.Text = tostring(opt) .. "  v"
                closePopup()
                task.spawn(callback or function() end, opt)
            end)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if popup then closePopup() else openPopup() end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then state = v; btn.Text = tostring(v) .. "  v" end
            return state
        end,
    }
end

function Section:Button(text, callback)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
    }))

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = C.elem,
        BorderSizePixel = 0,
        Font = FONT,
        Text = text,
        TextColor3 = C.text,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = root,
    })
    corner(btn, 3)
    local s = stroke(btn, C.border, 1)

    btn.MouseButton1Click:Connect(function()
        task.spawn(callback or function() end)
    end)
    btn.MouseEnter:Connect(function()
        TS:Create(btn, TS_INFO, { BackgroundColor3 = C.elem_hover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TS:Create(btn, TS_INFO, { BackgroundColor3 = C.elem }):Play()
    end)

    return btn
end

function Section:Label(text)
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
    }))
    new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = C.text_mute,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })
end

function Section:Textbox(text, placeholder, default, multiline, callback)
    local h = multiline and 140 or 50
    local root = self:_add(new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, h),
    }))

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = C.text_dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local box = new("TextBox", {
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, multiline and 112 or 26),
        BackgroundColor3 = Color3.fromRGB(13, 13, 13),
        BorderSizePixel = 0,
        Font = FONT_MONO,
        Text = tostring(default or ""),
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = multiline and 12 or 14,
        ClearTextOnFocus = false,
        MultiLine = multiline,
        TextWrapped = multiline,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        Parent = root,
    })
    corner(box, 3)
    local bxs = stroke(box, Color3.fromRGB(50, 50, 50), 1)
    pad(box, 8, 8, multiline and 6 or 0, multiline and 6 or 0)

    box.Focused:Connect(function()
        TS:Create(bxs, TS_INFO, { Color = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    box.FocusLost:Connect(function()
        TS:Create(bxs, TweenInfo.new(0.1), { Color = Color3.fromRGB(50, 50, 50) }):Play()
        task.spawn(callback or function() end, box.Text)
    end)

    return {
        Get = function() return box.Text end,
        Set = function(_, v, fire)
            box.Text = tostring(v or "")
            if fire then task.spawn(callback or function() end, box.Text) end
        end,
    }
end

-- ============================================================
-- TAB — صفحة داخل المحتوى
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
        Size = UDim2.new(0.5, -6, 1, 0),
        Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })

    local right = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })

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
        sec._root.LayoutOrder = self._ro
    else
        self._lo = self._lo + 1
        sec._root.LayoutOrder = self._lo
    end
    return sec
end

-- ============================================================
-- WINDOW — الملف الرئيسي
-- ============================================================
local Window = {}
Window.__index = Window

function Window.new(title, subtitle)
    local sg = new("ScreenGui", {
        Name = "oxy",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 50,
        Parent = getParent(),
    })

    local main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 560, 0, 420),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        Parent = sg,
    })
    corner(main, 8)
    stroke(main, Color3.fromRGB(30, 30, 30), 1)

    -- === Header ===
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        Parent = main,
    })

    new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        Text = title,
        TextColor3 = C.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local close = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 22, 0, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = FONT_BOLD,
        Text = "✕",
        TextColor3 = C.text,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = header,
    })

    close.MouseButton1Click:Connect(function()
        sg.Enabled = false
    end)

    -- === Sidebar ===
    local sidebar = new("Frame", {
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(0, 140, 1, -38),
        BackgroundColor3 = C.sidebar,
        BorderSizePixel = 0,
        Parent = main,
    })
    corner(sidebar, 8)
    new("Frame", { -- square off right corners
        Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.new(0, 8, 1, 0),
        BackgroundColor3 = C.sidebar,
        BorderSizePixel = 0,
        Parent = sidebar,
    })

    local tabList = new("Frame", {
        Position = UDim2.new(0, 0, 0, 10),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = sidebar,
    })
    pad(tabList, 8, 8, 0, 0)
    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })

    -- === Content ===
    local content = new("Frame", {
        Position = UDim2.new(0, 148, 0, 38),
        Size = UDim2.new(1, -148, 1, -38),
        BackgroundTransparency = 1,
        Parent = main,
    })
    pad(content, 4, 16, 14, 14)

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
        _tabList = tabList,
        _content = content,
        _tabs = {},
        _tabBtns = {},
        _active = nil,
        _order = 0,
    }, Window)
end

function Window:Tab(name, icon)
    self._order = self._order + 1

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = C.tab_hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = FONT,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = self._order,
        Parent = self._tabList,
    })
    corner(btn, 6)

    -- Icon frame (placeholder for rbxassetid)
    local iconFrame = new("Frame", {
        Position = UDim2.new(0, 10, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        Parent = btn,
    })
    if icon and icon ~= "" then
        new("ImageLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = icon,
            ImageColor3 = C.text_dim,
            Parent = iconFrame,
        })
    end

    local label = new("TextLabel", {
        Position = UDim2.new(0, 34, 0, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = name,
        TextColor3 = C.text_dim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })

    local tab = Tab.new(self._content, name)
    self._tabs[name] = tab
    self._tabBtns[name] = { btn = btn, label = label, iconFrame = iconFrame }

    local win = self
    btn.MouseButton1Click:Connect(function()
        if win._active == name then return end
        win._active = name
        for n, t in pairs(win._tabs) do
            t._page.Visible = (n == name)
        end
        for n, b in pairs(win._tabBtns) do
            local isActive = n == name
            TS:Create(b.btn, TS_INFO, {
                BackgroundTransparency = isActive and 0 or 1,
                BackgroundColor3 = C.tab_active,
            }):Play()
            TS:Create(b.label, TS_INFO, {
                TextColor3 = isActive and C.text or C.text_dim,
            }):Play()
        end
    end)

    if not self._active then
        self._active = name
        tab._page.Visible = true
        btn.BackgroundTransparency = 0
        btn.BackgroundColor3 = C.tab_active
        label.TextColor3 = C.text
    end

    return tab
end

-- ============================================================
-- INIT
-- ============================================================
local oxy = Window.new("oxy", "oxy")

local combat = oxy:Tab("combat", "rbxassetid://10734951847")
local visual = oxy:Tab("visual", "rbxassetid://10723346959")
local misc   = oxy:Tab("misc", "rbxassetid://10709797985")
local fflags = oxy:Tab("fflags", "rbxassetid://10723364435")

-- === combat ===
local parry = combat:Section("parry", "left")
parry:Toggle("auto parry", false, function(v) end)
parry:Slider("accuracy", 1, 100, 75, function(v) end)
parry:Toggle("random target", false, function(v) end)

local curve = combat:Section("curve", "right")
curve:Dropdown("curve method", {"camera", "dot", "backwards", "slow", "random"}, "camera", function(v) end)

local hotkeys = combat:Section("hotkeys", "right")
hotkeys:Toggle("hotkey curve", false, function(v) end)
hotkeys:Toggle("hotkey notify", false, function(v) end)
hotkeys:Toggle("triggerbot button", false, function(v) end)
hotkeys:Toggle("manual spam button", false, function(v) end)

local spam = combat:Section("spam", "left")
spam:Toggle("auto spam", false, function(v) end)
spam:Slider("threshold", 1, 3, 1, function(v) end)
spam:Toggle("manual notify", false, function(v) end)

-- === visual ===
local vis = visual:Section("visual", "left")
vis:Toggle("ability esp", false, function(v) end)

-- === misc ===
local ms = misc:Section("misc", "left")
ms:Toggle("unlock all", false, function(v) end)
ms:Toggle("ball stats", false, function(v) end)

-- === fflags ===
local prof = fflags:Section("profile", "left")
prof:Textbox("profile name", "default", "default", false, function(v) end)
prof:Dropdown("saved profiles", {"default"}, "default", function(v) end)
prof:Button("save profile", function() end)
prof:Button("load profile", function() end)
prof:Toggle("auto load", false, function(v) end)

local json = fflags:Section("fflags json", "right")
json:Textbox("fflags json", '{"DFIntTaskSchedulerTargetFps":"240"}', "", true, function(v) end)
json:Label('format: {"FFlagName":"value"}')
json:Button("apply fflags", function() end)

_G._oxy_clone = sg

print("[oxy] UI clone loaded")
