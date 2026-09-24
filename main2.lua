-- Blade Ball Script - Bypass & NovaUI Integration
-- Slax Hub - Developed by yossef

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))

local LocalPlayer = Players.LocalPlayer

-- =========================================
-- NovaUI Library Definition
-- =========================================
local Theme = {
	Background = Color3.fromRGB(18, 18, 24),
	Sidebar = Color3.fromRGB(24, 24, 32),
	Element = Color3.fromRGB(32, 32, 42),
	Hover = Color3.fromRGB(40, 40, 52),
	Accent = Color3.fromRGB(99, 102, 241),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(140, 140, 158),
	Stroke = Color3.fromRGB(48, 48, 62),
}

local Library = {}

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(c, t) return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function padding(p) return new("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }) end

local function makeDraggable(frame, handle)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local function label(parent, text, size, color, font, align)
	return new("TextLabel", {
		Parent = parent, BackgroundTransparency = 1, Text = text, TextSize = size or 14,
		TextColor3 = color or Theme.Text, Font = font or Enum.Font.GothamMedium,
		TextXAlignment = align or Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 1, 0),
	})
end

function Library:CreateWindow(config)
	config = config or {}
	local Window = {}
	local toggleKey = config.ToggleKey or Enum.KeyCode.LeftControl

	local gui = new("ScreenGui", {
		Name = "NovaUI_SlaxHub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = CoreGui,
	})

	local main = new("Frame", {
		Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Theme.Background, ClipsDescendants = true,
	}, { corner(12), stroke() })
	tween(main, { Size = config.Size or UDim2.fromOffset(580, 420) }, 0.45)

	local top = new("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	local title = label(top, config.Title or "Nova UI", 16, Theme.Text, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	local closeBtn = new("TextButton", {
		Parent = top, Text = "–", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -44, 0, 0),
	})
	new("Frame", { Parent = top, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0 })
	makeDraggable(main, top)

	local sidebar = new("ScrollingFrame", {
		Parent = main, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(0, 150, 1, -44),
		BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, { padding(10), new("UIListLayout", { Padding = UDim.new(0, 6) }) })

	local pages = new("Folder", { Parent = main })
	local function pageArea() return UDim2.new(1, -150, 1, -44) end

	local visible = true
	local function setVisible(v)
		visible = v
		main.Visible = v
	end
	closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == toggleKey then setVisible(not visible) end
	end)

	local notifHolder = new("Frame", {
		Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(280, 400), BackgroundTransparency = 1,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	function Window:Notify(opts)
		local card = new("Frame", {
			Parent = notifHolder, Size = UDim2.fromOffset(280, 60), BackgroundColor3 = Theme.Element,
			BackgroundTransparency = 1,
		}, { corner(10), stroke(Theme.Accent) })
		local t = label(card, opts.Title or "Notice", 14, Theme.Text, Enum.Font.GothamBold)
		t.Position = UDim2.fromOffset(12, 8); t.Size = UDim2.new(1, -24, 0, 18)
		local c = label(card, opts.Content or "", 12, Theme.SubText, Enum.Font.Gotham)
		c.Position = UDim2.fromOffset(12, 30); c.Size = UDim2.new(1, -24, 0, 22)
		tween(card, { BackgroundTransparency = 0 })
		task.delay(opts.Duration or 4, function()
			tween(card, { BackgroundTransparency = 1 }, 0.3)
			task.wait(0.3)
			card:Destroy()
		end)
	end

	local tabs, current = {}, nil

	function Window:AddTab(name)
		local Tab = {}

		local btn = new("TextButton", {
			Parent = sidebar, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
			Text = "   " .. name, TextSize = 14, Font = Enum.Font.GothamMedium, TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
		}, { corner(8) })
		local bar = new("Frame", {
			Parent = btn, Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
		}, { corner(2) })

		local page = new("ScrollingFrame", {
			Parent = pages, Position = UDim2.fromOffset(150, 44), Size = pageArea(), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
		}, { padding(12), new("UIListLayout", { Padding = UDim.new(0, 8) }) })

		local function select()
			for _, t in ipairs(tabs) do
				t.page.Visible = false
				tween(t.btn, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
				tween(t.bar, { Size = UDim2.fromOffset(3, 0) })
			end
			page.Visible = true
			tween(btn, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
			tween(bar, { Size = UDim2.fromOffset(3, 18) })
			current = Tab
		end
		btn.MouseButton1Click:Connect(select)
		table.insert(tabs, { btn = btn, bar = bar, page = page })
		if #tabs == 1 then select() end

		local function row(height)
			return new("Frame", { Parent = page, Size = UDim2.new(1, 0, 0, height or 42), BackgroundColor3 = Theme.Element }, { corner(8), stroke() })
		end

		function Tab:AddLabel(text)
			local r = row(34)
			local l = label(r, text, 13, Theme.SubText, Enum.Font.Gotham)
			l.Position = UDim2.fromOffset(14, 0); l.Size = UDim2.new(1, -28, 1, 0)
		end

		function Tab:AddButton(opts)
			local r = row()
			local b = new("TextButton", {
				Parent = r, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			})
			local l = label(r, opts.Title or "Button", 14)
			l.Position = UDim2.fromOffset(14, 0); l.Size = UDim2.new(1, -28, 1, 0)
			b.MouseEnter:Connect(function() tween(r, { BackgroundColor3 = Theme.Hover }) end)
			b.MouseLeave:Connect(function() tween(r, { BackgroundColor3 = Theme.Element }) end)
			b.MouseButton1Click:Connect(function()
				tween(r, { BackgroundColor3 = Theme.Accent }, 0.08)
				task.delay(0.1, function() tween(r, { BackgroundColor3 = Theme.Hover }) end)
				if opts.Callback then task.spawn(opts.Callback) end
			end)
		end

		function Tab:AddToggle(opts)
			local Toggle = { Value = opts.Default or false }
			local r = row()
			local l = label(r, opts.Title or "Toggle", 14)
			l.Position = UDim2.fromOffset(14, 0); l.Size = UDim2.new(1, -80, 1, 0)
			local pill = new("Frame", {
				Parent = r, Size = UDim2.fromOffset(42, 22), Position = UDim2.new(1, -56, 0.5, -11), BackgroundColor3 = Theme.Stroke,
			}, { corner(11) })
			local knob = new("Frame", {
				Parent = pill, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme.Text,
			}, { corner(8) })
			local hit = new("TextButton", { Parent = r, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" })

			local function setVal(v)
				Toggle.Value = v
				tween(pill, { BackgroundColor3 = v and Theme.Accent or Theme.Stroke })
				tween(knob, { Position = v and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
				if opts.Callback then task.spawn(opts.Callback, v) end
			end

			hit.MouseButton1Click:Connect(function() setVal(not Toggle.Value) end)
			if Toggle.Value then setVal(true) end
			return Toggle
		end

		function Tab:AddSlider(opts)
			local min, max, step = opts.Min or 0, opts.Max or 100, opts.Step or 1
			local Slider = { Value = opts.Default or min }
			local r = row(58)
			local l = label(r, opts.Title or "Slider", 14)
			l.Position = UDim2.fromOffset(14, 6); l.Size = UDim2.new(1, -80, 0, 22)
			local val = label(r, "", 13, Theme.SubText, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
			val.Position = UDim2.new(1, -64, 0, 6); val.Size = UDim2.fromOffset(50, 22)
			local track = new("Frame", {
				Parent = r, Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 1, -18), BackgroundColor3 = Theme.Stroke,
			}, { corner(3) })
			local fill = new("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent }, { corner(3) })

			function Slider:Set(v)
				v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
				Slider.Value = v
				val.Text = tostring(v)
				tween(fill, { Size = UDim2.new((v - min) / (max - min), 0, 1, 0) }, 0.08)
				if opts.Callback then task.spawn(opts.Callback, v) end
			end

			local dragging = false
			local function fromInput(input)
				local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				Slider:Set(min + (max - min) * rel)
			end
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					fromInput(input)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromInput(input)
				end
			end)
			Slider:Set(Slider.Value)
			return Slider
		end

		return Tab
	end

	return Window
end

-- =========================================
-- Script Logic & Remote Bypass
-- =========================================
local AutoParryEnabled = false
local ManualSpamUiEnabled = false
local ParryAccuracyValue = 80

local _token = nil
for _, Function in getgc(true) do
    if type(Function) == 'function' and debug.info(Function, 's'):find('PRY', 1, true) then
        for _, value in debug.getupvalues(Function) do
            if type(value) == 'function' then
                _token = value
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(_remote_uid)
    if not _token then return "" end
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)

    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)

        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent')) or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

local function FireParryBypass()
    for _remote, _origArgs in pairs(_reverted) do
        local _packet = {
            _origArgs[1],
            _origArgs[2],
            _tokenize(_origArgs[2]),
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
            false
        }
        
        if _remote:IsA('RemoteEvent') then
            _remote:FireServer(unpack(_packet))
        elseif _remote:IsA('RemoteFunction') then
            _remote:InvokeServer(unpack(_packet))
        end
    end
end

local function GetBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") and obj:GetAttribute("realBall") == true then
                return obj
            end
        end
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") then
                return obj
            end
        end
    end
    return nil
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- Double Parry Loop
task.spawn(function()
    local lastParryTime = 0

    while task.wait(0.001) do
        if AutoParryEnabled then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude
                    local velocity = ball.AssemblyLinearVelocity
                    local speed = velocity.Magnitude

                    local directionToPlayer = (playerPos - ballPos).Unit
                    local dotProduct = velocity:Dot(directionToPlayer)

                    local target = ball:GetAttribute("target")
                    local isTarget = (target == LocalPlayer.Name)

                    local timeToReach = (speed > 0) and (distance / speed) or 999

                    local convertedAccuracy = 0.12 + ((ParryAccuracyValue / 100) * 0.30)
                    local currentPing = GetPing()
                    local adjustedAccuracy = convertedAccuracy + (currentPing * 0.6)
                    local doubleCooldown = (speed > 80) and 0.05 or 0.15

                    if isTarget and dotProduct > 0 then
                        if timeToReach <= adjustedAccuracy then
                            if tick() - lastParryTime >= doubleCooldown then
                                lastParryTime = tick()
                                FireParryBypass()
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =========================================
-- Manual Spam UI Button Creation
-- =========================================
local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpamGui"
SpamGui.Parent = CoreGui
SpamGui.Enabled = false
SpamGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "ManualSpamBtn"
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
SpamBtn.BorderSizePixel = 0
SpamBtn.Position = UDim2.new(0.82, 0, 0.45, 0)
SpamBtn.Size = UDim2.new(0, 110, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "Spam"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 18
SpamBtn.AutoButtonColor = true

local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = SpamBtn
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 1.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local dragging, dragInput, dragStart, startPos
SpamBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = SpamBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

SpamBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        SpamBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function TriggerSpam()
    task.spawn(function()
        for i = 1, 6 do
            FireParryBypass()
            task.wait(0.008)
        end
    end)
end

SpamBtn.MouseButton1Click:Connect(function()
    TriggerSpam()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.E and ManualSpamUiEnabled then
        TriggerSpam()
    end
end)

-- =========================================
-- Initializing NovaUI Window & Tabs
-- =========================================
local Window = Library:CreateWindow({ Title = "Blade Ball  •  Slax Hub", ToggleKey = Enum.KeyCode.LeftControl })

local MainTab = Window:AddTab("Main Auto")
MainTab:AddLabel("الإعدادات الرئيسية للصد التلقائي")

MainTab:AddToggle({
    Title = "Auto Parry (Double Adaptive)",
    Default = false,
    Callback = function(v)
        AutoParryEnabled = v
    end
})

MainTab:AddToggle({
    Title = "Manual Spam Button",
    Default = false,
    Callback = function(v)
        ManualSpamUiEnabled = v
        SpamGui.Enabled = v
    end
})

MainTab:AddSlider({
    Title = "Parry Accuracy (100 = Early)",
    Min = 1,
    Max = 100,
    Default = 80,
    Step = 1,
    Callback = function(v)
        ParryAccuracyValue = v
    end
})

local SettingsTab = Window:AddTab("Settings")
SettingsTab:AddLabel("إخفاء / إظهار الواجهة: LeftControl")

Window:Notify({
    Title = "Slax Hub Loaded",
    Content = "تمت إضافة NovaUI بنجاح مع كافة المميزات!",
    Duration = 5
})
