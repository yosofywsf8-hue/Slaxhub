--[[
    OXY UI — Standalone Shell
    Roblox UI framework, draggable, tabbed, sectioned.
    No external libraries. No combat logic. Pure interface.
    
    Usage:
        local ui = OxyUI.new("oxy")
        local combat = ui:Tab("combat", "rbxassetid://10734951847")
        local parry  = combat:Section("parry", "left")
        parry:Button("reset", function() print("hi") end)
        parry:Toggle("enabled", false, function(v) print(v) end)
        parry:Slider("accuracy", 1, 100, 50, function(v) print(v) end)
        parry:Dropdown("method", {"camera","dot"}, "camera", function(v) print(v) end)
        parry:Keybind("triggerbot", Enum.KeyCode.T, function(k) print(k) end)
    
    Warnings:
        * Draggable header uses UserInputService.InputChanged — throttle if >60hz input.
        * Dropdown popup closes on outside click via a full-screen invisible button; parent must be ScreenGui, not a Frame.
        * Notification queue caps at 6 visible — older ones drop silently.
--]]

local OxyUI = {}
OxyUI.__index = OxyUI

--================================================================
-- SERVICES
--================================================================
local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local CoreGui         = game:GetService("CoreGui")
local LocalPlayer     = Players.LocalPlayer

--================================================================
-- CONSTANTS
--================================================================
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

local FONT       = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_MONO  = Enum.Font.Code
local TS         = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--================================================================
-- UTIL
--================================================================
local function new(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or COLORS.border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0),
        PaddingBottom = UDim.new(0, b or l or 0),
        Parent = parent,
    })
end

local function findGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    if CoreGui then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

--================================================================
-- NOTIFICATION SYSTEM
--================================================================
local NotifyGui = nil
local notifyQueue = {}
local MAX_NOTIFS = 6

local function getNotifyGui()
    if NotifyGui and NotifyGui.Parent then return NotifyGui end
    NotifyGui = new("ScreenGui", {
        Name = "oxy_notify",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        Parent = findGuiParent(),
    })
    return NotifyGui
end

local function pushNotification(title, content, duration, color)
    local gui = getNotifyGui()
    duration = duration or 4
    color = color or COLORS.border_act

    local card = new("Frame", {
        Name = "Notify",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, -80), -- start off-screen top
        Size = UDim2.new(0, 280, 0, 0),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = gui,
    })
    corner(card, 6)
    stroke(card, COLORS.border, 1)

    local accentBar = new("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(accentBar, 6)

    local titleLabel = new("TextLabel", {
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

    local contentLabel = new("TextLabel", {
        Position = UDim2.new(0, 16, 0, 30),
        Size = UDim2.new(1, -28, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = content,
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    padding(card, 0, 0, 0, 10)

    -- push existing up
    table.insert(notifyQueue, 1, card)
    if #notifyQueue > MAX_NOTIFS then
        local old = table.remove(notifyQueue, #notifyQueue)
        if old then old:Destroy() end
    end

    -- layout
    local y = 20
    for i, c in ipairs(notifyQueue) do
        local h = c.AbsoluteSize.Y
        if h == 0 then h = 60 end
        c.Position = UDim2.new(1, -20, 0, y)
        y = y + h + 8
    end

    -- tween in
    card.Size = UDim2.new(0, 280, 0, 0)
    TweenService:Create(card, TS, {
        Position = UDim2.new(1, -20, 0, (y - card.AbsoluteSize.Y - 8) or 20),
        Size = UDim2.new(0, 280, 0, card.AbsoluteSize.Y),
    }):Play()

    task.delay(duration, function()
        if card and card.Parent then
            TweenService:Create(card, TS, {
                BackgroundTransparency = 1,
            }):Play()
            for _, d in ipairs(card:GetDescendants()) do
                if d:IsA("TextLabel") then
                    TweenService:Create(d, TS, { TextTransparency = 1 }):Play()
                elseif d:IsA("Frame") then
                    TweenService:Create(d, TS, { BackgroundTransparency = 1 }):Play()
                elseif d:IsA("UIStroke") then
                    TweenService:Create(d, TS, { Transparency = 1 }):Play()
                end
            end
            task.wait(0.2)
            card:Destroy()
            for i, c in ipairs(notifyQueue) do
                if c == card then table.remove(notifyQueue, i) break end
            end
        end
    end)
end

--================================================================
-- INPUT HELPERS
--================================================================
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local dragStart, startPos
    local dragInput

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--================================================================
-- BASE ELEMENT WRAPPER
--================================================================
local Element = {}
Element.__index = Element

function Element.new(parent, height)
    local root = new("Frame", {
        Name = "Element",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 32),
        Parent = parent,
    })
    return setmetatable({ _root = root, _parent = parent }, Element)
end

--================================================================
-- SECTION
--================================================================
local Section = {}
Section.__index = Section

function Section.new(parent, name, side)
    side = side or "left"
    local frame = new("Frame", {
        Name = "Section",
        BackgroundColor3 = COLORS.section,
        BorderSizePixel = 0,
        Size = UDim2.new(0.5, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })
    corner(frame, 6)
    stroke(frame, COLORS.border, 1)
    padding(frame, 8, 8, 8, 8)

    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = frame,
    })

    local title = new("TextLabel", {
        Name = "SectionTitle",
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

    local self = setmetatable({
        _frame = frame,
        _layout = layout,
        _side = side,
        _contentOrder = 0,
    }, Section)

    return self
end

function Section:_addChild(inst)
    self._contentOrder = self._contentOrder + 1
    inst.LayoutOrder = self._contentOrder
    inst.Parent = self._frame
    return inst
end

function Section:Button(text, callback)
    local el = Element.new(self._frame, 30)
    self:_addChild(el._root)

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = el._root,
    })
    corner(btn, 4)
    local s = stroke(btn, COLORS.border, 1)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TS, { BackgroundColor3 = COLORS.element_hov }):Play()
        TweenService:Create(s, TS, { Color = COLORS.border_act }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TS, { BackgroundColor3 = COLORS.element }):Play()
        TweenService:Create(s, TS, { Color = COLORS.border }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        task.spawn(callback or function() end)
    end)

    return {
        SetText = function(_, t) btn.Text = t end,
        SetVisible = function(_, v) el._root.Visible = v end,
    }
end

function Section:Toggle(text, default, callback)
    local el = Element.new(self._frame, 30)
    self:_addChild(el._root)

    local state = default == true

    local label = new("TextLabel", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = el._root,
    })

    local pill = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 40, 0, 20),
        BackgroundColor3 = state and COLORS.accent or COLORS.element,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = el._root,
    })
    corner(pill, 10)
    local pillStroke = stroke(pill, state and COLORS.border_act or COLORS.border, 1)

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
        TweenService:Create(pill, TS, {
            BackgroundColor3 = state and COLORS.accent or COLORS.element,
        }):Play()
        TweenService:Create(pillStroke, TS, {
            Color = state and COLORS.border_act or COLORS.border,
        }):Play()
        TweenService:Create(dot, TS, {
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
            if v ~= nil then
                state = v == true
                render()
            end
            return state
        end,
    }
end

function Section:Slider(text, minVal, maxVal, default, callback)
    local el = Element.new(self._frame, 46)
    self:_addChild(el._root)

    local state = default or minVal

    new("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = el._root,
    })

    local valueLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.3, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = FONT_MONO,
        Text = tostring(state),
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = el._root,
    })

    local track = new("Frame", {
        Position = UDim2.new(0, 0, 0, 28),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Parent = el._root,
    })
    corner(track, 4)

    local fill = new("Frame", {
        Size = UDim2.new((state - minVal) / (maxVal - minVal), 0, 1, 0),
        BackgroundColor3 = COLORS.accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 4)

    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((state - minVal) / (maxVal - minVal), 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = COLORS.text,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 7)

    local dragging = false
    local function setFromInput(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * relX + 0.5)
        state = val
        TweenService:Create(fill, TS, { Size = UDim2.new(relX, 0, 1, 0) }):Play()
        TweenService:Create(knob, TS, { Position = UDim2.new(relX, 0, 0.5, 0) }):Play()
        valueLabel.Text = tostring(val)
        task.spawn(callback, val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then
                state = math.clamp(v, minVal, maxVal)
                local relX = (state - minVal) / (maxVal - minVal)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                knob.Position = UDim2.new(relX, 0, 0.5, 0)
                valueLabel.Text = tostring(state)
            end
            return state
        end,
    }
end

function Section:Dropdown(text, options, default, callback)
    options = options or {}
    local state = default or options[1]

    local el = Element.new(self._frame, 46)
    self:_addChild(el._root)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = el._root,
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
        Parent = el._root,
    })
    corner(btn, 4)
    local btnStroke = stroke(btn, COLORS.border, 1)

    -- arrow
    new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        Text = "▾",
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        Parent = btn,
    })

    local popup = nil
    local listHolder = nil

    local function closePopup()
        if popup then
            popup:Destroy()
            popup = nil
        end
        TweenService:Create(btnStroke, TS, { Color = COLORS.border }):Play()
    end

    local function openPopup()
        if popup then return end
        TweenService:Create(btnStroke, TS, { Color = COLORS.border_act }):Play()

        local guiRoot = btn:FindFirstAncestorOfClass("ScreenGui")
        if not guiRoot then return end

        -- click-catcher
        popup = new("TextButton", {
            Name = "DropdownClose",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 998,
            Parent = guiRoot,
        })
        popup.MouseButton1Click:Connect(closePopup)

        local h = math.min(#options * 26 + 8, 180)
        listHolder = new("Frame", {
            Position = UDim2.new(0, btn.AbsolutePosition.X,
                0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4),
            Size = UDim2.new(0, btn.AbsoluteSize.X, 0, h),
            BackgroundColor3 = COLORS.panel,
            BorderSizePixel = 0,
            ZIndex = 999,
            Parent = guiRoot,
        })
        corner(listHolder, 4)
        stroke(listHolder, COLORS.border, 1)

        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 999,
            Parent = listHolder,
        })
        padding(scroll, 4)
        new("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = scroll,
        })

        for i, opt in ipairs(options) do
            local optBtn = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = (tostring(opt) == tostring(state)) and COLORS.element_hov or COLORS.element,
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
            corner(optBtn, 3)

            optBtn.MouseEnter:Connect(function()
                TweenService:Create(optBtn, TS, { BackgroundColor3 = COLORS.element_hov }):Play()
            end)
            optBtn.MouseLeave:Connect(function()
                local isCur = tostring(opt) == tostring(state)
                TweenService:Create(optBtn, TS, {
                    BackgroundColor3 = isCur and COLORS.element_hov or COLORS.element,
                }):Play()
            end)
            optBtn.MouseButton1Click:Connect(function()
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
            if v ~= nil then
                state = v
                btn.Text = "  " .. tostring(v)
            end
            return state
        end,
        Refresh = function(_, newOptions)
            options = newOptions or options
            if popup then closePopup() end
        end,
    }
end

function Section:Keybind(text, default, callback)
    local el = Element.new(self._frame, 30)
    self:_addChild(el._root)

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
        Parent = el._root,
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
        Parent = el._root,
    })
    corner(btn, 4)
    local btnStroke = stroke(btn, COLORS.border, 1)

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        TweenService:Create(btnStroke, TS, { Color = COLORS.border_act }):Play()
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not listening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            state = input.KeyCode
            btn.Text = state.Name
            listening = false
            TweenService:Create(btnStroke, TS, { Color = COLORS.border }):Play()
            task.spawn(callback, state)
        end
    end)

    return {
        Value = function(_, v)
            if v ~= nil then
                state = v
                btn.Text = v.Name
            end
            return state
        end,
    }
end

function Section:Textbox(text, placeholder, default, multiline, callback)
    local h = multiline and 142 or 52
    local el = Element.new(self._frame, h)
    self:_addChild(el._root)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = el._root,
    })

    local box = new("TextBox", {
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, multiline and 114 or 28),
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
        Parent = el._root,
    })
    corner(box, 4)
    local boxStroke = stroke(box, COLORS.border, 1)
    padding(box, 8, 8, multiline and 6 or 0, multiline and 6 or 0)

    box.Focused:Connect(function()
        TweenService:Create(boxStroke, TS, { Color = COLORS.border_act }):Play()
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TS, { Color = COLORS.border }):Play()
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
    local el = Element.new(self._frame, 18)
    self:_addChild(el._root)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT,
        Text = text,
        TextColor3 = COLORS.text_dim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = el._root,
    })
end

--================================================================
-- TAB
--================================================================
local Tab = {}
Tab.__index = Tab

function Tab.new(parent, name, icon)
    local page = new("Frame", {
        Name = "Page_" .. name,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        Parent = parent._content,
    })

    local leftHolder = new("Frame", {
        Name = "Left",
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 1, 0),
        Parent = page,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = leftHolder,
    })

    local rightHolder = new("Frame", {
        Name = "Right",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Parent = page,
    })
    padding(rightHolder, 10, 0, 0, 0)
    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = rightHolder,
    })

    local self = setmetatable({
        _page = page,
        _leftHolder = leftHolder,
        _rightHolder = rightHolder,
        _leftOrder = 0,
        _rightOrder = 0,
        _name = name,
    }, Tab)

    return self
end

function Tab:Section(name, side)
    side = side or "left"
    local holder = side == "right" and self._rightHolder or self._leftHolder
    local sec = Section.new(holder, name, side)

    if side == "right" then
        self._rightOrder = self._rightOrder + 1
        sec._frame.LayoutOrder = self._rightOrder
    else
        self._leftOrder = self._leftOrder + 1
        sec._frame.LayoutOrder = self._leftOrder
    end

    return sec
end

--================================================================
-- WINDOW
--================================================================
local Window = {}
Window.__index = Window

function Window.new(name, subtitle)
    local gui = new("ScreenGui", {
        Name = "oxy",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 50,
        Parent = findGuiParent(),
    })

    local main = new("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 620, 0, 460),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(main, 8)
    stroke(main, COLORS.border, 1)

    -- Header
    local header = new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    corner(header, 8)
    new("Frame", { -- square off bottom corners of header
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

    -- Close button
    local closeBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = COLORS.element,
        BorderSizePixel = 0,
        Font = FONT_BOLD,
        Text = "×",
        TextColor3 = COLORS.text_dim,
        TextSize = 14,
        AutoButtonColor = false,
        Parent = header,
    })
    corner(closeBtn, 4)
    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TS, { BackgroundColor3 = COLORS.danger, TextColor3 = COLORS.text }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TS, { BackgroundColor3 = COLORS.element, TextColor3 = COLORS.text_dim }):Play()
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
    padding(tabBar, 10, 10, 4, 4)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabBar,
    })

    -- Content
    local content = new("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 74),
        Size = UDim2.new(1, 0, 1, -74),
        BackgroundTransparency = 1,
        Parent = main,
    })
    padding(content, 10, 10, 10, 10)

    makeDraggable(main, header)

    local self = setmetatable({
        _gui = gui,
        _main = main,
        _header = header,
        _tabBar = tabBar,
        _content = content,
        _tabs = {},
        _activeTab = nil,
        _tabOrder = 0,
    }, Window)

    return self
end

function Window:Tab(name, icon)
    self._tabOrder = self._tabOrder + 1

    local btn = new("TextButton", {
        Name = "Tab_" .. name,
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        Font = FONT,
        Text = string.upper(name),
        TextColor3 = COLORS.text_dim,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = self._tabOrder,
        Parent = self._tabBar,
    })
    corner(btn, 4)

    local tabObj = Tab.new(self, name, icon)

    local function activate()
        if self._activeTab == name then return end
        self._activeTab = name
        for tn, t in pairs(self._tabs) do
            t.page.Visible = (tn == name)
        end
        for tn, b in pairs(self._tabButtons) do
            TweenService:Create(b, TS, {
                BackgroundColor3 = (tn == name) and COLORS.element or COLORS.bg,
                TextColor3 = (tn == name) and COLORS.text or COLORS.text_dim,
            }):Play()
        end
    end

    if not self._tabButtons then self._tabButtons = {} end
    self._tabButtons[name] = btn
    self._tabs[name] = { page = tabObj._page }

    btn.MouseButton1Click:Connect(activate)

    if not self._activeTab then
        activate()
    end

    return tabObj
end

--================================================================
-- PUBLIC API
--================================================================
function OxyUI.new(name, subtitle)
    return Window.new(name or "oxy", subtitle)
end

function OxyUI:Notify(title, content, duration)
    pushNotification(title, content, duration, COLORS.border_act)
end

-- expose for direct use
OxyUI.Notify = pushNotification
OxyUI.Colors = COLORS

return OxyUI
