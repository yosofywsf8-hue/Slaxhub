if not LPH_OBFUSCATED then
	LPH_ENCFUNC = function(callback)
		return callback
	end
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
	LPH_NO_UPVALUES = function(...)
		return ...
	end
	LPH_JIT_MAX = function(...)
		return ...
	end
	LPH_JIT = function(...)
		return ...
	end
end

local _cloneref = cloneref

local user_input_service = _cloneref(game:GetService('UserInputService'))
local tween_service = _cloneref(game:GetService('TweenService'))
local text_service = _cloneref(game:GetService('TextService'))
local http_service = _cloneref(game:GetService('HttpService'))
local core_gui = _cloneref(game:GetService('CoreGui'))
local debris = _cloneref(game:GetService('Debris'))

local _new_instance = Instance.new
local _new_tween_info = TweenInfo.new
local _new_udim = UDim.new
local _new_udim2 = UDim2.new
local _udim2_from_offset = UDim2.fromOffset
local _new_vector2 = Vector2.new

local _clamp = math.clamp
local _floor = math.floor
local _max = math.max
local _min = math.min

local _clear = table.clear
local _find = table.find
local _freeze = table.freeze
local _insert = table.insert
local _pack = table.pack
local _unpack = table.unpack

local _defer = task.defer
local _delay = task.delay
local _create_tween = tween_service.Create

local _pairs = pairs
local _pcall = pcall
local _tostring = tostring
local _type = type

local create_runtime_lua_key = function(left, right)
	return left .. right .. _tostring(game.GameId):sub(1, 0)
end

local lua_bridge_decryption_key =
	create_runtime_lua_key('ba372df66d4c9d0c2d193367a39ae77a', '56a173213cd71b164be6d19bf8c640d2')
local lua_export_decryption_key =
	create_runtime_lua_key('dc6ca3570f8d9a75a7558f26165b9274', '9565c346b9e4f19d8f7ac2a46ada1ac8')
local lua_sandbox_decryption_key =
	create_runtime_lua_key('aa1143ae1640d00049535f95a227d34d', '986d65cb6c300e7e11d97cfb990fd492')
local lua_loader_decryption_key =
	create_runtime_lua_key('e83f53ad24607d2fd2350345fd2d8265', 'c695310635c212e78fb389573ebf33a0')
local lua_register_decryption_key =
	create_runtime_lua_key('03bd60e589693d30b9f98cde0ac9bc77', '2ccde9534705153de1bf27f8b58c0db4')

local library = {
	_config = {},
	_flags = {},

	_current = nil,
}
library.__index = library

type tab_typeof = {
	_btn: TextButton,
	_left: ScrollingFrame,
	_right: ScrollingFrame,
	_active: boolean,
	_enabled: boolean,
	_title: string,
	_category: string?,
	_manager: any,
}

type runtime_default = {
	_tab: number,
	_tabs: { tab_typeof },
	_tab_registry: { [string]: { any } },
	_categories: { any },
	_category_registry: { [string]: { any } },
	_active_tab: tab_typeof?,
	_layout_order: number,
	_category_order: number,
	_manager_loaded: boolean,
	_type: string?,
	_config: { [string]: any },
	_flags: { [string]: any },
	_active_dropdowns: { any },
	_keybind_entries: { any },
	_keybind_list_visible: boolean,
	_is_mobile: boolean,
	_ui_scale: number,
	_label_text_size: number,
	_small_text_size: number,
	_ui_open: boolean,
	_dragging: boolean,
	_drag_start: Vector2?,
	_container_position: UDim2?,
	_ui: ScreenGui?,
	_container: Frame?,
	_sidebar: Frame?,
	_pin: Frame?,
	_tabs_container: ScrollingFrame?,
	_main_content: Frame?,
	_sections: Folder?,
	_topbar: Frame?,
	_ui_scale_object: UIScale?,
	_keybind_scale: UIScale?,
	_keybind_list_content: Frame?,
	_keybind_list_frame: Frame?,
	_notification_holder: Frame?,
	_notification_scale: UIScale?,
	_notification_order: number,
	_apply_scale: (() -> ())?,
	_lua_manager: any?,
}

type _runtime = typeof(setmetatable({} :: runtime_default, library))
type runtime_typeof = _runtime | typeof(library)

local interface_parent = (gethui and gethui()) or core_gui
local old_interface = interface_parent:FindFirstChild('_angeli')

if old_interface then
	debris:AddItem(old_interface, 0)
end

local create_new = LPH_NO_VIRTUALIZE(function(class_name, properties)
	local instance = _new_instance(class_name)

	for property, value in properties do
		if property ~= 'Parent' then
			instance[property] = value
		end
	end

	instance.Parent = properties.Parent

	return instance
end)

local create_round = LPH_NO_VIRTUALIZE(function(instance, radius)
	return create_new('UICorner', {
		CornerRadius = _new_udim(0, radius),
		Parent = instance,
	})
end)

local create_pill = LPH_NO_VIRTUALIZE(function(instance)
	return create_new('UICorner', {
		CornerRadius = _new_udim(1, 0),
		Parent = instance,
	})
end)

local create_outline = LPH_NO_VIRTUALIZE(function(instance, refresh)
	local stroke = create_new('UIStroke', {
		Color = Color3.fromRGB(35, 35, 35),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = instance,
	})

	if refresh then
		instance:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			stroke.Enabled = false
			stroke.Enabled = true
		end)
	end

	return stroke
end)

local create_vertical_list = LPH_NO_VIRTUALIZE(function(instance, gap)
	return create_new('UIListLayout', {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = _new_udim(0, gap or 0),
		Parent = instance,
	})
end)

local create_padding = LPH_NO_VIRTUALIZE(function(instance, top, bottom, left, right)
	return create_new('UIPadding', {
		PaddingTop = _new_udim(0, top),
		PaddingBottom = _new_udim(0, bottom),
		PaddingLeft = _new_udim(0, left),
		PaddingRight = _new_udim(0, right),
		Parent = instance,
	})
end)

local create_label = LPH_NO_VIRTUALIZE(function(properties)
	properties.BackgroundTransparency = 1
	properties.FontFace =
		Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
	properties.TextColor3 = properties.TextColor3 or Color3.fromRGB(180, 180, 180)
	properties.BorderSizePixel = 0

	return create_new('TextLabel', properties)
end)

local create_divider = LPH_NO_VIRTUALIZE(function(parent, position, size)
	return create_new('Frame', {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		Position = position,
		Size = size,
		BorderSizePixel = 0,
		Parent = parent,
	})
end)

local normalize_name = LPH_NO_VIRTUALIZE(function(value)
	local normalized = string.lower(_tostring(value or ''))
	normalized = string.gsub(normalized, '^%s+', '')

	return string.gsub(normalized, '%s+$', '')
end)

local shallow_copy = LPH_NO_VIRTUALIZE(function(source)
	local copy = {}

	for index, value in source or {} do
		copy[index] = value
	end

	return copy
end)

local read_only = LPH_JIT_MAX(function(source)
	return _freeze(shallow_copy(source))
end)

local round_number = LPH_NO_VIRTUALIZE(function(number, decimals)
	local multiplier = 10 ^ (decimals or 0)

	return _floor(number * multiplier + 0.5 - (number < 0 and 1 or 0)) / multiplier
end)

local lua_internal_callbacks = {}
local lua_internal_exports = {}
local protect_lua_value

local dispatch_lua_internal = LPH_ENCFUNC(function(handle, ...)
	local callback = lua_internal_callbacks[handle]

	if _type(callback) ~= 'function' then
		error('internal function is no longer available', 2)
	end

	local results = _pack(callback(...))

	for index = 1, results.n do
		results[index] = protect_lua_value(results[index])
	end

	return _unpack(results, 1, results.n)
end, 'ba372df66d4c9d0c2d193367a39ae77a56a173213cd71b164be6d19bf8c640d2', lua_bridge_decryption_key)

protect_lua_value = LPH_ENCFUNC(function(value, visited)
	local value_type = _type(value)

	if value_type == 'function' then
		local handle = {}
		lua_internal_callbacks[handle] = value

		return LPH_NO_UPVALUES(function(...)
			return dispatch_lua_internal(handle, ...)
		end)
	end

	if value_type ~= 'table' then
		return value
	end

	visited = visited or {}

	if visited[value] then
		return visited[value]
	end

	local copy = {}
	visited[value] = copy

	for index, child in value do
		copy[protect_lua_value(index, visited)] = protect_lua_value(child, visited)
	end

	_freeze(copy)

	return copy
end, 'dc6ca3570f8d9a75a7558f26165b92749565c346b9e4f19d8f7ac2a46ada1ac8', lua_export_decryption_key)

if not isfolder('Angeli') then
	makefolder('Angeli')
end

if not isfolder('Angeli/configs') then
	makefolder('Angeli/configs')
end

if not isfolder('Angeli/assets') then
	makefolder('Angeli/assets')
end

if not isfolder('Angeli/luas') then
	makefolder('Angeli/luas')
end

function library._save(self: runtime_typeof)
	if not isfile(`Angeli/configs/{game.GameId}.json`) then
		writefile(`Angeli/configs/{game.GameId}.json`, http_service:JSONEncode({}))
	end

	for index, value in _pairs(self._flags) do
		self._config[index] = _type(value) == 'table' and http_service:JSONDecode(http_service:JSONEncode(value))
			or value
	end

	_pcall(function()
		writefile(`Angeli/configs/{game.GameId}.json`, http_service:JSONEncode(self._config))
	end)
end

function library.load(self: runtime_typeof)
	if not isfile(`Angeli/configs/{game.GameId}.json`) then
		self:_save()
	end

	local success, result = _pcall(function()
		return http_service:JSONDecode(readfile(`Angeli/configs/{game.GameId}.json`))
	end)

	if success and result then
		for index, value in _pairs(result) do
			self._flags[index] = value
			self._config[index] = value
		end
	end

	return self._flags
end

library:load()

function library.close_all_dropdowns(self: _runtime)
	for _, dropdown in self._active_dropdowns do
		if dropdown._state then
			dropdown:unfold()
		end
	end
end

library._new = function(runtime_type: string?): _runtime
	local is_mobile = user_input_service.TouchEnabled
		or not (user_input_service.KeyboardEnabled and user_input_service.MouseEnabled)
	local self = setmetatable({
		_tab = 0,
		_tabs = {},
		_tab_registry = {},
		_categories = {},
		_category_registry = {},
		_active_tab = nil,
		_layout_order = 0,
		_category_order = 0,
		_manager_loaded = false,
		_type = runtime_type,
		_config = library._config,
		_flags = library._flags,
		_active_dropdowns = {},
		_keybind_entries = {},
		_keybind_list_visible = false,
		_is_mobile = is_mobile,
		_ui_scale = 1,
		_label_text_size = is_mobile and 15 or 14,
		_small_text_size = is_mobile and 11 or 10,
		_ui_open = true,
		_dragging = false,
		_drag_start = nil,
		_container_position = nil,
		_ui = nil,
		_container = nil,
		_sidebar = nil,
		_pin = nil,
		_tabs_container = nil,
		_main_content = nil,
		_sections = nil,
		_topbar = nil,
		_ui_scale_object = nil,
		_keybind_scale = nil,
		_keybind_list_content = nil,
		_keybind_list_frame = nil,
		_notification_holder = nil,
		_notification_scale = nil,
		_notification_order = 0,
		_apply_scale = nil,
		_lua_manager = nil,
	}, library) :: _runtime

	library._current = self

	self:_init()
	self:_init_keybind_list()

	if self._apply_scale then
		self._apply_scale()
	end

	return self
end

function library._init(self: _runtime)
	set_thread_identity(6)

	local _main = create_new('ScreenGui', {
		Name = '_angeli',
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = interface_parent,
	})

	if syn and syn.protect_gui then
		syn.protect_gui(_main)
	end

	self._ui = _main

	local container = create_new('Frame', {
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(0.5, 0, 0.5, 0),
		Size = _new_udim2(0, 0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = _main,
	})

	create_round(container, 8)
	create_outline(container)

	_create_tween(tween_service, container, _new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = _udim2_from_offset(600, 400),
	}):Play()

	local ui_scale = create_new('UIScale', {
		Parent = container,
	})

	self._ui_scale_object = ui_scale

	local notification_holder = create_new('Frame', {
		Name = '_notifications',
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0.5, 1),
		Position = _new_udim2(0.5, 0, 0.5, 178),
		Size = _new_udim2(0, 560, 0, 180),
		BorderSizePixel = 0,
		ZIndex = 199,
		Parent = _main,
	})

	create_new('UIListLayout', {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = _new_udim(0, 6),
		Parent = notification_holder,
	})

	local notification_scale = create_new('UIScale', {
		Scale = self._ui_scale,
		Parent = notification_holder,
	})

	self._notification_holder = notification_holder
	self._notification_scale = notification_scale

	local apply_scale = LPH_NO_VIRTUALIZE(function()
		if self._is_mobile then
			local viewport_size = workspace.CurrentCamera.ViewportSize

			if self._ui and self._ui.AbsoluteSize.Y > 0 then
				viewport_size = self._ui.AbsoluteSize
			end

			local screen_scale = (viewport_size.X / 1400) * 1.4375
			self._ui_scale = _clamp(
				_min(screen_scale, (viewport_size.X * 0.95) / 600, (viewport_size.Y * 0.95) / 400),
				0.503125,
				1.4375
			)
		else
			self._ui_scale = 1
		end

		local scale = self._ui_scale

		ui_scale.Scale = scale

		if self._keybind_scale then
			self._keybind_scale.Scale = scale
		end

		if self._notification_holder and self._notification_scale then
			self._notification_holder.Position = _new_udim2(0.5, 0, 0.5, 178 * scale)
			self._notification_scale.Scale = scale
		end

		_defer(function()
			if self._active_tab and self._pin then
				local button = self._active_tab._btn
				local pin_y = (button.AbsolutePosition.Y - self._sidebar.AbsolutePosition.Y + button.AbsoluteSize.Y / 2)
						/ self._ui_scale
					- 8
				self._pin.Position = _new_udim2(0, 10, 0, pin_y)
			end
		end)
	end)

	self._apply_scale = apply_scale

	apply_scale()

	workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
		_defer(apply_scale)
	end)

	local _toggle_gui = create_new('ScreenGui', {
		Name = '_angeli_toggle',
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = _main,
	})

	local mobile_toggle = create_new('TextButton', {
		BackgroundColor3 = Color3.fromRGB(22, 22, 22),
		AnchorPoint = _new_vector2(0.5, 0),
		Position = _new_udim2(0.5, 0, 0, 12),
		Size = _new_udim2(0, 40, 0, 40),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = self._is_mobile,
		ZIndex = 100,
		Parent = _toggle_gui,
	})

	create_round(mobile_toggle, 8)
	create_outline(mobile_toggle)

	create_new('ImageLabel', {
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0.5, 0.5),
		Position = _new_udim2(0.5, 0, 0.5, 0),
		Size = _new_udim2(0, 20, 0, 20),
		Image = 'rbxassetid://10709812159',
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 101,
		Parent = mobile_toggle,
	})

	local sidebar = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(0, 160, 1, 0),
		Parent = container,
	})

	create_divider(sidebar, _new_udim2(1, -1, 0, 48), _new_udim2(0, 1, 1, -48))

	local logo_area = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 0, 48),
		Parent = sidebar,
	})

	create_label({
		Position = _new_udim2(0, (10 + 10), 0, 0),
		Size = _new_udim2(1, -((10 + 10) + 10), 1, 0),
		Text = 'Angeli',
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = self._is_mobile and 18 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = logo_area,
	})

	create_divider(logo_area, _new_udim2(0, 0, 1, -1), _new_udim2(1, 0, 0, 1))

	local pin = create_new('Frame', {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 10, 0, 0),
		Size = _new_udim2(0, 4, 0, 16),
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = sidebar,
	})

	create_pill(pin)

	local tabs_container = create_new('ScrollingFrame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 0, 0, 48),
		Size = _new_udim2(1, 0, 1, -48),
		CanvasSize = _new_udim2(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	tabs_container.ScrollBarThickness = 0
	tabs_container.ScrollBarImageTransparency = 1
	tabs_container.VerticalScrollBarInset = Enum.ScrollBarInset.None
	tabs_container.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	tabs_container.ClipsDescendants = true
	create_padding(tabs_container, 6, 16, 10, 10)
	create_vertical_list(tabs_container, 6)

	tabs_container:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
		if self._active_tab then
			local button = self._active_tab._btn
			local pin_y = (button.AbsolutePosition.Y - self._sidebar.AbsolutePosition.Y + button.AbsoluteSize.Y / 2)
					/ self._ui_scale
				- 8
			pin.Position = _new_udim2(0, 10, 0, pin_y)
		end
	end)

	local main_content = create_new('Frame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 160, 0, 0),
		Size = _new_udim2(0, (600 - 160), 1, 0),
		Parent = container,
	})

	local topbar = create_new('Frame', {
		BackgroundTransparency = 1,
		Size = _new_udim2(1, 0, 0, 48),
		ZIndex = 5,
		Parent = main_content,
	})

	local topbar_divider = create_divider(topbar, _new_udim2(0, 0, 1, -1), _new_udim2(1, 0, 0, 1))
	topbar_divider.ZIndex = 6

	local get_custom_asset = getcustomasset or getsynasset

	if get_custom_asset and self._type == '_limited' then
		_pcall(function()
			local cached = isfile('Angeli/assets/succubus.png') and readfile('Angeli/assets/succubus.png') or nil

			if not cached or cached:sub(2, 4) ~= 'PNG' then
				local content =
					game:HttpGet('https://raw.githubusercontent.com/retilin/Angeli/refs/heads/main/assets/succubus.png')

				if content and content:sub(2, 4) == 'PNG' then
					writefile('Angeli/assets/succubus.png', content)
				end
			end
		end)

		local logo_loaded, logo_asset = _pcall(function()
			return get_custom_asset('Angeli/assets/succubus.png')
		end)

		if logo_loaded and logo_asset and logo_asset ~= '' then
			create_new('ImageLabel', {
				BackgroundTransparency = 1,
				AnchorPoint = _new_vector2(1, 0.5),
				Position = _new_udim2(1, -16, 0.5, 0),
				Size = _new_udim2(0, 34, 0, 34),
				Image = logo_asset,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 6,
				Parent = topbar,
			})
		end
	end

	local sections_viewport = create_new('Frame', {
		BackgroundTransparency = 1,
		Position = _new_udim2(0, 0, 0, 48),
		Size = _new_udim2(1, 0, 1, -48),
		ClipsDescendants = true,
		Parent = main_content,
	})

	local sections = create_new('Folder', {
		Parent = sections_viewport,
	})

	local input_ended_connection = nil

	local on_drag = LPH_JIT_MAX(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._dragging = true

			self._drag_start = input.Position
			self._container_position = container.Position

			self:close_all_dropdowns()

			if input_ended_connection then
				input_ended_connection:Disconnect()
				input_ended_connection = nil
			end

			input_ended_connection = input.Changed:Connect(function()
				if input.UserInputState ~= Enum.UserInputState.End then
					return
				end

				if input_ended_connection then
					input_ended_connection:Disconnect()
					input_ended_connection = nil
				end

				self._dragging = false
			end)
		end
	end)

	local drag = LPH_JIT_MAX(function(input)
		if not self._dragging then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local scale = self._ui_scale
			local delta = (input.Position - self._drag_start) / scale

			_create_tween(tween_service, container, _new_tween_info(0.2), {
				Position = (_new_udim2(
					self._container_position.X.Scale,
					self._container_position.X.Offset + delta.X,
					self._container_position.Y.Scale,
					self._container_position.Y.Offset + delta.Y
				)),
			}):Play()
		end
	end)

	container.InputBegan:Connect(on_drag)
	user_input_service.InputChanged:Connect(drag)

	function self:change_visibility(state)
		if state then
			container.Visible = true

			_create_tween(
				tween_service,
				container,
				_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{
					Size = _udim2_from_offset(600, 400),
				}
			):Play()
		else
			self:close_all_dropdowns()

			_create_tween(
				tween_service,
				container,
				_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{
					Size = _new_udim2(0, 0, 0, 0),
				}
			):Play()

			_delay(0.5, function()
				if not self._ui_open then
					container.Visible = false
				end
			end)
		end
	end

	user_input_service.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		local minimize_flag = self._flags.minimize
		local minimize_key = Enum.KeyCode.Insert

		if minimize_flag then
			local success, result = _pcall(function()
				return Enum.KeyCode[minimize_flag]
			end)

			if success then
				minimize_key = result
			end
		end

		if input.KeyCode == minimize_key then
			self._ui_open = not self._ui_open

			self:change_visibility(self._ui_open)
		end
	end)

	mobile_toggle.MouseButton1Click:Connect(function()
		self._ui_open = not self._ui_open

		self:change_visibility(self._ui_open)
	end)

	self._container = container
	self._sidebar = sidebar
	self._pin = pin

	self._tabs_container = tabs_container
	self._main_content = main_content
	self._sections = sections
	self._topbar = topbar
end

function library.update_tabs(self: _runtime, tab: tab_typeof)
	for _, tab_data in self._tabs do
		local btn = tab_data._btn

		local tab_icon = btn:FindFirstChildWhichIsA('ImageLabel')
		local tab_label = btn:FindFirstChildWhichIsA('TextLabel')

		if tab_data == tab then
			tab_data._active = true

			_create_tween(tween_service, btn, _new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()

			if tab_label then
				_create_tween(
					tween_service,
					tab_label,
					_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						TextColor3 = Color3.fromRGB(255, 255, 255),
					}
				):Play()
			end

			if tab_icon then
				_create_tween(
					tween_service,
					tab_icon,
					_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						ImageColor3 = Color3.fromRGB(255, 255, 255),
					}
				):Play()
			end

			local target_y = (btn.AbsolutePosition.Y - self._sidebar.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2)
					/ self._ui_scale
				- 8

			if self._pin.BackgroundTransparency == 1 then
				self._pin.Position = _new_udim2(0, 10, 0, target_y)
				self._pin.BackgroundTransparency = 0
			else
				_create_tween(
					tween_service,
					self._pin,
					_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						Position = _new_udim2(0, 10, 0, target_y),
					}
				):Play()
			end

			continue
		end

		if tab_data._active then
			tab_data._active = false

			_create_tween(tween_service, btn, _new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()

			if tab_label then
				_create_tween(
					tween_service,
					tab_label,
					_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						TextColor3 = Color3.fromRGB(180, 180, 180),
					}
				):Play()
			end

			if tab_icon then
				_create_tween(
					tween_service,
					tab_icon,
					_new_tween_info(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{
						ImageColor3 = Color3.fromRGB(180, 180, 180),
					}
				):Play()
			end
		end
	end
end

function library.update_sections(self: _runtime, left_section: ScrollingFrame, right_section: ScrollingFrame)
	for _, object in self._sections:GetChildren() do
		if object == left_section or object == right_section then
			object.Visible = true

			continue
		end

		object.Visible = false
	end
end

local function resolve_runtime(self: runtime_typeof): _runtime?
	if self ~= library and _type(self) == 'table' and self._tabs then
		return self :: _runtime
	end

	return library._current
end

function library._find_category(self: runtime_typeof, name: string)
	local runtime = resolve_runtime(self)

	if not runtime then
		return nil
	end

	local matches = runtime._category_registry[normalize_name(name)]

	return matches and matches[1] or nil
end

function library._find_tab(self: runtime_typeof, name: string, category_name: string?)
	local runtime = resolve_runtime(self)

	if not runtime then
		return nil
	end

	local matches = runtime._tab_registry[normalize_name(name)]

	if not matches then
		return nil
	end

	if category_name then
		local normalized_category = normalize_name(category_name)

		for _, tab_manager in matches do
			if normalize_name(tab_manager._category) == normalized_category then
				return tab_manager
			end
		end

		return nil
	end

	return matches[1]
end

function library._find_group(self: runtime_typeof, tab_manager: any, name: string, side: string?)
	if not tab_manager then
		return nil
	end

	local matches = tab_manager._group_registry[normalize_name(name)]

	if not matches then
		return nil
	end

	if side then
		for _, group_manager in matches do
			if group_manager._side == normalize_name(side) then
				return group_manager
			end
		end

		return nil
	end

	if #matches == 1 then
		return matches[1]
	end

	return nil
end

function library.create_category(self: _runtime, name: string)
	local runtime = self

	self._category_order = (self._category_order or 0) + 1
	self._layout_order = 0

	local category_index = self._category_order
	local base_order = category_index * 1000

	local category = create_label({
		Name = name,
		LayoutOrder = base_order,
		Size = _new_udim2(1, 0, 0, category_index == 1 and 19 or 26),
		Text = name:upper(),
		TextSize = runtime._small_text_size + 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 0.2,
		Parent = self._tabs_container,
	})

	create_padding(category, 0, 4, 10, 0)

	local category_manager = {
		_label = category,
		_name = name,

		_base_order = base_order,
		_tab_count = 0,
	}

	function category_manager:create_tab(title, icon)
		self._tab_count += 1

		return runtime:create_tab(title, icon, self._base_order + self._tab_count, self._name)
	end

	_insert(self._categories, category_manager)

	local category_name = normalize_name(name)
	self._category_registry[category_name] = self._category_registry[category_name] or {}
	_insert(self._category_registry[category_name], category_manager)

	return category_manager
end

function library.create_tab(self: _runtime, title: string, icon: string?, layout_order: number?, category_name: string?)
	local tab_manager = {
		_title = title,
		_category = category_name,
		_groups = {},
		_group_registry = {},
	}
	local runtime = self

	icon = icon or 'rbxassetid://10709812159'

	if icon == 'rbxassetid://10709798164' then
		icon = 'rbxassetid://10709812159'
	end

	if not layout_order then
		self._layout_order += 1
		layout_order = self._category_order * 1000 + self._layout_order
	end

	local first_tab = #self._tabs == 0

	local tab_button = create_new('TextButton', {
		Name = title,
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 1,
		LayoutOrder = layout_order,
		Size = _new_udim2(1, 0, 0, 32),
		Text = '',
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Parent = self._tabs_container,
	})

	create_round(tab_button, 6)

	create_new('ImageLabel', {
		BackgroundTransparency = 1,
		AnchorPoint = _new_vector2(0, 0.5),
		Position = _new_udim2(0, 10, 0.5, 0),
		Size = _new_udim2(0, 16, 0, 16),
		Image = icon,
		ImageColor3 = Color3.fromRGB(180, 180, 180),
		Parent = tab_button,
	})

	create_label({
		Position = _new_udim2(0, (10 + 16 + 8), 0, 0),
		Size = _new_udim2(1, -((10 + 16 + 8) + 10), 1, 0),
		Text = title,
		TextSize = runtime._label_text_size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = tab_button,
	})

	local function create_section(column_x)
		local section = create_new('ScrollingFrame', {
			BackgroundTransparency = 1,
			Position = _new_udim2(0, column_x - 2, 0, 0),
			Size = _new_udim2(0, ((600 - 160 - 16 * 2 - 12) / 2) + 4, 1, 0),
			CanvasSize = _new_udim2(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0,
			Visible = false,
			Parent = self._sections,
		})

		section.ScrollBarThickness = 0
		section.ScrollBarImageTransparency = 1
		section.VerticalScrollBarInset = Enum.ScrollBarInset.None
		section.HorizontalScrollBarInset = Enum.ScrollBarInset.None
		section.ClipsDescendants = true
		create_padding(section, 16, 16, 2, 2)
		create_vertical_list(section, 12)

		return section
	end

	local left_section = create_section(16)
	local right_section = create_section(16 + ((600 - 160 - 16 * 2 - 12) / 2) + 12)

	local tab_data = {
		_btn = tab_button,
		_left = left_section,
		_right = right_section,

		_active = false,
		_enabled = true,
		_title = title,
		_category = category_name,
		_manager = tab_manager,
	}

	tab_manager._data = tab_data

	_insert(self._tabs, tab_data)

	self._tab += 1

	if first_tab then
		self:update_tabs(tab_data)
		self:update_sections(left_section, right_section)

		self._active_tab = tab_data
	end

	tab_button.MouseButton1Click:Connect(function()
		if not tab_data._enabled then
			return
		end

		self._active_tab = tab_data

		self:update_tabs(tab_data)
		self:update_sections(left_section, right_section)
	end)

	function tab_manager:set_enabled(state)
		local enabled = state == true

		tab_data._enabled = enabled
		tab_button.Active = enabled
		tab_button.Selectable = enabled

		local tab_icon = tab_button:FindFirstChildWhichIsA('ImageLabel')
		local tab_label = tab_button:FindFirstChildWhichIsA('TextLabel')

		if tab_icon then
			tab_icon.ImageTransparency = enabled and 0 or 0.65
		end

		if tab_label then
			tab_label.TextTransparency = enabled and 0 or 0.65
		end

		if not enabled and runtime._active_tab == tab_data then
			for _, candidate in runtime._tabs do
				if candidate ~= tab_data and candidate._enabled then
					runtime._active_tab = candidate
					runtime:update_tabs(candidate)
					runtime:update_sections(candidate._left, candidate._right)

					break
				end
			end
		end
	end

	function tab_manager:is_enabled()
		return tab_data._enabled
	end

	function tab_manager:create_group(title, side)
		local group_values = {}

		if _type(title) == 'table' then
			group_values = title
		else
			group_values.title = title
			group_values.side = side
		end

		group_values.title = group_values.title or 'group'
		group_values.side = (group_values.side == 'right') and 'right' or 'left'

		local group_manager = {
			_size = 0,
			_order = 0,
			_title = group_values.title,
			_side = group_values.side,
			_tab = tab_manager,
		}

		local function next_row_order()
			group_manager._order += 1

			return group_manager._order
		end

		local group_frame = create_new('Frame', {
			BackgroundColor3 = Color3.fromRGB(22, 22, 22),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = _new_udim2(1, 0, 0, 0),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = (group_values.side == 'left' and left_section or right_section),
		})

		group_manager._frame = group_frame

		create_round(group_frame, 8)
		create_outline(group_frame, true)
		create_padding(group_frame, 12, 12, 12, 12)
		create_vertical_list(group_frame, 8)

		create_label({
			LayoutOrder = 0,
			Size = _new_udim2(1, 0, 0, 12),
			Text = _tostring(group_values.title):upper(),
			TextSize = runtime._small_text_size + 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.2,
			Parent = group_frame,
		})

		function group_manager:create_toggle(flag, _values)
			if _type(flag) == 'table' then
				_values = flag
				flag = _values.flag
			end

			local state = _values.default or _values.Default or false

			local toggle_frame = create_new('Frame', {
				BackgroundTransparency = 1,
				LayoutOrder = next_row_order(),
				Size = _new_udim2(1, 0, 0, 24),
				Parent = group_frame,
			})

			local toggle_label = create_label({
				Size = _new_udim2(1, -(30 + 10), 1, 0),
				Text = _values.title,
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = toggle_frame,
			})

			local switch_background = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				AnchorPoint = _new_vector2(1, 0.5),
				Position = _new_udim2(1, 0, 0.5, 0),
				Size = _new_udim2(0, 30, 0, 18),
				BorderSizePixel = 0,
				Parent = toggle_frame,
			})

			create_pill(switch_background)

			local knob_inset = (18 - 12) / 2
			local knob_off = _new_udim2(0, knob_inset, 0.5, 0)
			local knob_on = _new_udim2(0, 30 - 12 - knob_inset, 0.5, 0)

			local switch_knob = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(180, 180, 180),
				AnchorPoint = _new_vector2(0, 0.5),
				Position = knob_off,
				Size = _new_udim2(0, 12, 0, 12),
				BorderSizePixel = 0,
				Parent = switch_background,
			})

			create_pill(switch_knob)

			local toggle_tween_info = _new_tween_info(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			local toggle_tweens = {}

			local cancel_toggle_tweens = LPH_NO_VIRTUALIZE(function()
				for _, tween in toggle_tweens do
					tween:Cancel()
				end

				_clear(toggle_tweens)
			end)

			local play_toggle_tween = LPH_NO_VIRTUALIZE(function(instance, properties)
				local tween = _create_tween(tween_service, instance, toggle_tween_info, properties)
				_insert(toggle_tweens, tween)

				tween:Play()
			end)

			local apply_toggle = LPH_JIT_MAX(function(animate)
				local bg_color = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 40, 40)
				local knob_color = state and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(180, 180, 180)
				local knob_pos = state and knob_on or knob_off
				local label_color = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)

				cancel_toggle_tweens()

				if animate then
					play_toggle_tween(switch_background, { BackgroundColor3 = bg_color })
					play_toggle_tween(switch_knob, { Position = knob_pos, BackgroundColor3 = knob_color })
					play_toggle_tween(toggle_label, { TextColor3 = label_color })
				else
					switch_background.BackgroundColor3 = bg_color
					switch_knob.Position = knob_pos

					switch_knob.BackgroundColor3 = knob_color
					toggle_label.TextColor3 = label_color
				end
			end)

			local set_toggle = LPH_JIT_MAX(function(value, animate)
				state = value

				apply_toggle(animate)

				runtime._flags[flag] = state
				runtime:_save()

				if _values.callback then
					_values.callback(state)
				end

				if _values.is_keybind then
					runtime:update_keybind_list()
				end
			end)

			local click_button = create_new('TextButton', {
				BackgroundTransparency = 1,
				Size = _new_udim2(1, 0, 1, 0),
				Text = '',
				Parent = toggle_frame,
			})

			if _values.is_keybind and not runtime._is_mobile then
				local bind_text_size = runtime._label_text_size
				local bind_right = 30 + 4

				toggle_label.Size = _new_udim2(1, -(bind_right + 24 + 8), 1, 0)

				local bind_button = create_new('TextButton', {
					BackgroundColor3 = Color3.fromRGB(40, 40, 40),
					AnchorPoint = _new_vector2(1, 0.5),
					Position = _new_udim2(1, -bind_right, 0.5, 0),
					Size = _new_udim2(0, 24, 0, 22),
					Text = '',
					AutoButtonColor = false,
					BorderSizePixel = 0,
					ZIndex = 2,
					Parent = toggle_frame,
				})

				create_round(bind_button, 6)

				local bind_icon = create_new('ImageLabel', {
					BackgroundTransparency = 1,
					AnchorPoint = _new_vector2(0.5, 0.5),
					Position = _new_udim2(0.5, 0, 0.5, 0),
					Size = _new_udim2(0, 14, 0, 14),
					Image = 'rbxassetid://10709818996',
					ImageColor3 = Color3.fromRGB(180, 180, 180),
					Parent = bind_button,
				})

				local bind_text = create_label({
					Size = _new_udim2(1, 0, 1, 0),
					Text = '',
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = bind_text_size,
					Visible = false,
					Parent = bind_button,
				})

				local fit_bind_button = LPH_NO_VIRTUALIZE(function(key_name)
					local text_width = text_service:GetTextSize(
						key_name,
						bind_text_size,
						Enum.Font.GothamSemibold,
						_new_vector2(1000, 22)
					).X
					local bind_width = _max(24, text_width + 12)

					bind_button.Size = _new_udim2(0, bind_width, 0, 22)
					toggle_label.Size = _new_udim2(1, -(bind_right + bind_width + 8), 1, 0)
				end)

				local bind_flag = `{flag}_key`

				local key = nil
				local picking = false

				if runtime._flags[bind_flag] ~= nil then
					local success, result = _pcall(function()
						return Enum.KeyCode[runtime._flags[bind_flag]]
					end)

					if success then
						key = result

						bind_icon.Visible = false
						bind_text.Visible = true
						bind_text.Text = key.Name

						fit_bind_button(key.Name)
					end
				end

				bind_button.MouseButton1Click:Connect(function()
					picking = true
					bind_icon.Visible = false
					bind_text.Visible = true
					bind_text.Text = '...'
					bind_button.Size = _new_udim2(0, 24, 0, 22)
					toggle_label.Size = _new_udim2(1, -(bind_right + 24 + 8), 1, 0)

					_create_tween(tween_service, bind_button, _new_tween_info(0.2), {
						BackgroundColor3 = Color3.fromRGB(45, 45, 45),
					}):Play()
				end)

				user_input_service.InputBegan:Connect(function(input, processed)
					if picking then
						if input.UserInputType == Enum.UserInputType.Keyboard then
							key = input.KeyCode

							bind_text.Text = key.Name
							picking = false

							fit_bind_button(key.Name)

							_create_tween(tween_service, bind_button, _new_tween_info(0.2), {
								BackgroundColor3 = Color3.fromRGB(40, 40, 40),
							}):Play()

							runtime._flags[bind_flag] = key.Name
							runtime:_save()

							for _, entry in runtime._keybind_entries do
								if entry.flag == flag then
									entry.key_name = key.Name

									break
								end
							end

							runtime:update_keybind_list()
						end
					elseif not processed and key and input.KeyCode == key then
						set_toggle(not state, true)
					end
				end)
			end

			if runtime._flags[flag] ~= nil then
				state = runtime._flags[flag]
			end

			apply_toggle(false)

			if _values.is_keybind and not runtime._is_mobile then
				local bind_flag = `{flag}_key`
				local initial_key_name = nil

				if runtime._flags[bind_flag] ~= nil then
					local success, result = _pcall(function()
						return Enum.KeyCode[runtime._flags[bind_flag]]
					end)

					if success then
						initial_key_name = result.Name
					end
				end

				_insert(runtime._keybind_entries, {
					flag = flag,
					title = _values.title,
					key_name = initial_key_name,
				})

				runtime:update_keybind_list()
			end

			click_button.MouseButton1Click:Connect(function()
				set_toggle(not state, true)
			end)
		end

		function group_manager:create_slider(flag, _values)
			if _type(flag) == 'table' then
				_values = flag
				flag = _values.flag
			end

			local default = _values.default

			if runtime._flags[flag] ~= nil then
				default = runtime._flags[flag]
			end

			local value = default

			local slider_frame = create_new('Frame', {
				BackgroundTransparency = 1,
				LayoutOrder = next_row_order(),
				Size = _new_udim2(1, 0, 0, 30),
				Parent = group_frame,
			})

			create_label({
				Size = _new_udim2(1, -56, 0, 16),
				Text = _values.title,
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = slider_frame,
			})

			local value_label = create_label({
				AnchorPoint = _new_vector2(1, 0),
				Position = _new_udim2(1, 0, 0, 0),
				Size = _new_udim2(0, 48, 0, 16),
				Text = _tostring(default),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = slider_frame,
			})

			local track_button = create_new('TextButton', {
				BackgroundTransparency = 1,
				Position = _new_udim2(0, 0, 0, 16),
				Size = _new_udim2(1, 0, 1, -16),
				Text = '',
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Parent = slider_frame,
			})

			local track_background = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				AnchorPoint = _new_vector2(0, 0.5),
				Position = _new_udim2(0, 0, 0.5, 0),
				Size = _new_udim2(1, 0, 0, 6),
				BorderSizePixel = 0,
				Parent = track_button,
			})

			create_pill(track_background)

			local track_fill = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Size = _new_udim2(
					(_clamp((value - _values.minimum) / (_values.maximum - _values.minimum), 0, 1)),
					0,
					1,
					0
				),
				BorderSizePixel = 0,
				Parent = track_background,
			})

			create_pill(track_fill)

			local knob = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				AnchorPoint = _new_vector2(0.5, 0.5),
				Position = _new_udim2(1, 0, 0.5, 0),
				Size = _new_udim2(0, 12, 0, 12),
				BorderSizePixel = 0,
				Parent = track_fill,
			})

			create_pill(knob)

			local slider_dragging = false

			local update_slider = LPH_JIT_MAX(function(input)
				local position = _clamp(
					(input.Position.X - track_background.AbsolutePosition.X) / track_background.AbsoluteSize.X,
					0,
					1
				)
				local raw_value = _values.minimum + ((_values.maximum - _values.minimum) * position)

				value = round_number(raw_value, _values.rounding and 1 or 0)

				value_label.Text = _tostring(value)

				_create_tween(tween_service, track_fill, _new_tween_info(0.1), {
					Size = _new_udim2(position, 0, 1, 0),
				}):Play()

				runtime._flags[flag] = value
				runtime:_save()

				if _values.callback then
					_values.callback(value)
				end
			end)

			track_button.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					slider_dragging = true

					update_slider(input)
				end
			end)

			user_input_service.InputEnded:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					slider_dragging = false
				end
			end)

			user_input_service.InputChanged:Connect(function(input)
				if
					slider_dragging
					and (
						input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch
					)
				then
					update_slider(input)
				end
			end)
		end

		function group_manager:create_button(flag, _values)
			if _type(flag) == 'table' then
				_values = flag
			end

			local button = create_new('TextButton', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				LayoutOrder = next_row_order(),
				Size = _new_udim2(1, 0, 0, 26),
				FontFace = Font.new(
					'rbxasset://fonts/families/GothamSSm.json',
					Enum.FontWeight.SemiBold,
					Enum.FontStyle.Normal
				),
				Text = _values.title,
				TextColor3 = Color3.fromRGB(180, 180, 180),
				TextSize = runtime._label_text_size,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Parent = group_frame,
			})

			create_round(button, 6)

			button.MouseButton1Click:Connect(function()
				button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)

				_create_tween(tween_service, button, _new_tween_info(0.2), {
					BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				}):Play()

				_values.callback()
			end)
		end

		function group_manager:create_textbox(flag, _values)
			if _type(flag) == 'table' then
				_values = flag
				flag = _values.flag
			end

			_values = _values or {}

			local box_height = _max(24, tonumber(_values.height) or 56)
			local raw_value = _tostring(_values.default or '')
			local textbox_frame = create_new('Frame', {
				BackgroundTransparency = 1,
				LayoutOrder = next_row_order(),
				Size = _new_udim2(1, 0, 0, box_height + 20),
				Visible = _values.visible ~= false,
				Parent = group_frame,
			})

			create_label({
				Size = _new_udim2(1, 0, 0, 16),
				Text = _values.title or 'Text',
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = textbox_frame,
			})

			local textbox = create_new('TextBox', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				Position = _new_udim2(0, 0, 0, 20),
				Size = _new_udim2(1, 0, 0, box_height),
				ClearTextOnFocus = false,
				MultiLine = _values.multi_line ~= false,
				PlaceholderText = _values.placeholder or '',
				PlaceholderColor3 = Color3.fromRGB(180, 180, 180),
				Text = raw_value,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = _values.compact and runtime._label_text_size or runtime._small_text_size,
				TextTransparency = 0.1,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = _values.compact and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
				FontFace = Font.new(
					'rbxasset://fonts/families/GothamSSm.json',
					Enum.FontWeight.SemiBold,
					Enum.FontStyle.Normal
				),
				BorderSizePixel = 0,
				Parent = textbox_frame,
			})

			create_round(textbox, 6)
			create_padding(textbox, 0, 0, 10, 10)

			local changing_text = false
			local rendered_value = raw_value

			local render_value = LPH_NO_VIRTUALIZE(function()
				local displayed_value = raw_value

				if _values.display then
					local display_success, transformed = _pcall(_values.display, raw_value)

					if display_success and transformed ~= nil then
						displayed_value = _tostring(transformed)
					end
				end

				rendered_value = displayed_value
				changing_text = true
				textbox.Text = displayed_value
				changing_text = false
			end)

			textbox:GetPropertyChangedSignal('Text'):Connect(function()
				if changing_text or textbox.Text == rendered_value then
					return
				end

				raw_value = textbox.Text
				render_value()
			end)

			render_value()

			textbox.FocusLost:Connect(function(enter_pressed)
				if flag then
					runtime._flags[flag] = raw_value
					runtime:_save()
				end

				if _values.callback then
					_values.callback(raw_value, enter_pressed)
				end
			end)

			local textbox_manager = {}

			function textbox_manager:get_value()
				return raw_value
			end

			function textbox_manager:get_display_value()
				return textbox.Text
			end

			function textbox_manager:set_value(value)
				raw_value = _tostring(value or '')
				render_value()
			end

			function textbox_manager:clear()
				self:set_value('')
			end

			function textbox_manager:focus()
				textbox:CaptureFocus()
			end

			function textbox_manager:set_visible(state)
				textbox_frame.Visible = state == true
			end

			function textbox_manager:is_visible()
				return textbox_frame.Visible
			end

			return textbox_manager
		end

		function group_manager:create_dropdown(flag, _values)
			if _type(flag) == 'table' then
				_values = flag
				flag = _values.flag
			end

			_values = _values or {}
			_values.options = _values.options or {}

			local is_multi = _values.multi_dropdown or _values.multi or false
			local hide_selected_option = _values.hide_selected_option == true and not is_multi
			local dropdown_manager = {
				_state = false,
				_locked_open = false,
				_size = 0,
				_content_height = 0,
				_options = {},
				_option_buttons = {},
				_selected = {},
			}

			local default = _values.default or (is_multi and {} or _values.options[1])

			if flag and runtime._flags[flag] ~= nil then
				default = runtime._flags[flag]
			end

			if is_multi and _type(default) == 'table' then
				for _index, value in _pairs(default) do
					if _type(_index) == 'string' and value == true then
						dropdown_manager._selected[_index] = true
					elseif _type(value) == 'string' then
						dropdown_manager._selected[value] = true
					end
				end
			end

			local dropdown_frame = create_new('Frame', {
				BackgroundTransparency = 1,
				LayoutOrder = next_row_order(),
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = _new_udim2(1, 0, 0, 0),
				ClipsDescendants = true,
				Parent = group_frame,
			})

			create_vertical_list(dropdown_frame, 4)

			create_label({
				LayoutOrder = 0,
				Size = _new_udim2(1, 0, 0, 16),
				Text = _values.title,
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = dropdown_frame,
			})

			local select_box = create_new('Frame', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = _new_udim2(1, 0, 0, 0),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = dropdown_frame,
			})

			create_round(select_box, 6)
			create_vertical_list(select_box)

			local header = create_new('Frame', {
				BackgroundTransparency = 1,
				LayoutOrder = 0,
				Size = _new_udim2(1, 0, 0, 24),
				Parent = select_box,
			})

			local selected_text = create_label({
				Position = _new_udim2(0, 10, 0, 0),
				Size = _new_udim2(1, _values.hide_icon and -20 or -32, 1, 0),
				Text = '',
				TextSize = runtime._label_text_size,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = header,
			})

			create_new('UIGradient', {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.7, 0),
					NumberSequenceKeypoint.new(0.9, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = selected_text,
			})

			if not _values.hide_icon then
				create_new('ImageLabel', {
					BackgroundTransparency = 1,
					AnchorPoint = _new_vector2(1, 0.5),
					Position = _new_udim2(1, -10, 0.5, 0),
					Size = _new_udim2(0, 12, 0, 12),
					Image = 'rbxassetid://10734899821',
					ImageColor3 = Color3.fromRGB(180, 180, 180),
					Parent = header,
				})
			end

			local options_list = create_new('ScrollingFrame', {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = _new_udim2(1, 0, 0, 0),
				CanvasSize = _new_udim2(0, 0, 0, 0),
				Automa
