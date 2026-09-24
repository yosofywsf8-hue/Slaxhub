	if not values then
		return nil, `{name} value is invalid: {values_error}`
	end

	local category_name = _tostring(definition.category or queued.category or 'Luas')
	local tab_title = _tostring(definition.tab or queued.tab or entry.name)

	local category = library:_find_category(category_name) or runtime:create_category(category_name)
	local tab = library:_find_tab(tab_title, category._name) or category:create_tab(tab_title)

	local group_title = _tostring(definition.group or queued.group or definition.section or queued.section or 'Main')
	local group_side = normalize_name(definition.side or queued.side)
	group_side = (group_side == 'right') and 'right' or 'left'

	local group = library:_find_group(tab, group_title, group_side) or tab:create_group(group_title, group_side)

	local flag = control_flag(entry, definition, index)
	values.flag = flag
	values.title = name

	return {
		_group = group,
		_method = method,
		_flag = flag,
		_title = name,
		_values = values,
	}
end)

local register_lua_environment = LPH_ENCFUNC(function(entry, sandbox, bridge)
	sandbox.register = function(definition)
		if _type(definition) ~= 'table' then
			error('register requires a table definition', 2)
		end

		_insert(entry.queued, {
			definition = protect_lua_value(definition),
			category = sandbox.lua_category,
			tab = sandbox.lua_tab,
			group = sandbox.lua_group or sandbox.lua_section,
			side = sandbox.lua_side,
		})
	end

	sandbox.add = sandbox.register

	bridge.register = sandbox.register
	bridge.add = sandbox.register
end, '03bd60e589693d30b9f98cde0ac9bc772ccde9534705153de1bf27f8b58c0db4', lua_register_decryption_key)

local create_lua_environment = LPH_ENCFUNC(function(manager, entry, chunk)
	local sandbox = {}
	local bridge = {}

	sandbox.lua_name = entry.name
	sandbox.lua_file = entry.file
	sandbox.lua_category = 'Luas'
	sandbox.lua_tab = entry.name
	sandbox.lua_group = 'Main'
	sandbox.lua_section = 'Main'
	sandbox.lua_side = 'left'

	bridge.name = entry.name
	bridge.file = entry.file
	bridge.flags = read_only(library._flags)
	bridge.config = read_only(library._config)

	register_lua_environment(entry, sandbox, bridge)

	local base_env = getfenv(chunk)
	local env = setmetatable({
		lua_name = entry.name,
		lua_file = entry.file,
		register = sandbox.register,
		add = sandbox.register,
		angeli = protect_lua_value(bridge),
		Angeli = protect_lua_value(bridge),
	}, {
		__index = base_env,
		__newindex = base_env,
	})

	setfenv(chunk, env)
end, 'aa1143ae1640d00049535f95a227d34d986d65cb6c300e7e11d97cfb990fd492', lua_sandbox_decryption_key)

local execute_lua_entry = LPH_ENCFUNC(function(manager, entry)
	entry.queued = {}

	local chunk, compile_error = compile_lua_source(entry.source, `=[Angeli] {entry.file}`)

	if not chunk then
		return false, `compile error in {entry.file}: {compile_error}`
	end

	create_lua_environment(manager, entry, chunk)

	local run_success, run_error = _pcall(chunk)

	if not run_success then
		return false, `runtime error in {entry.file}: {_tostring(run_error)}`
	end

	local runtime = manager._runtime
	local registered = {}

	for index, queued in entry.queued do
		local validated, validation_error = validate_lua_definition(runtime, entry, queued, index)

		if not validated then
			return false, validation_error
		end

		_insert(registered, validated)
	end

	entry.registered = registered

	for _, item in registered do
		item._group[item._method](item._group, item._flag, item._values)
	end

	entry.loaded = true
	manager._loaded_names[normalize_name(entry.name)] = true

	return true
end, 'e83f53ad24607d2fd2350345fd2d8265c695310635c212e78fb389573ebf33a0', lua_loader_decryption_key)

function library._init_lua_manager(self: _runtime, container_frame: Frame)
	if self._lua_manager then
		return self._lua_manager
	end

	local store = read_lua_store()
	local manager = {
		_runtime = self,
		_entries = {},
		_by_name = {},
		_by_file = {},
		_loaded_names = {},
		_auto_load_files = {},
		_selected = store.selected,
		_rebuilding_options = false,
		_migrated = store.migrated,
	}

	for _, file_name in store.loaded do
		manager._auto_load_files[normalize_name(file_name)] = true
	end

	self._lua_manager = manager

	local group_manager = {
		_frame = container_frame,
		_order = 0,
	}

	local function next_row_order()
		group_manager._order += 1

		return group_manager._order
	end

	local list_dropdown = nil
	local source_textbox = nil

	local update_action_buttons = LPH_NO_VIRTUALIZE(function() end)

	local selected_entry = LPH_NO_VIRTUALIZE(function()
		if not manager._selected then
			return nil
		end

		return manager._by_name[normalize_name(manager._selected)]
	end)

	local refresh_source_view = LPH_JIT(function()
		if not source_textbox then
			return
		end

		local entry = selected_entry()

		if entry then
			source_textbox:set_value(entry.source)
		else
			source_textbox:set_value('')
		end

		update_action_buttons()
	end)

	local update_dropdown_options = LPH_JIT(function()
		if not list_dropdown or manager._rebuilding_options then
			return
		end

		manager._rebuilding_options = true

		local names = {}

		for _, entry in manager._entries do
			_insert(names, entry.name)
		end

		if #names == 0 then
			names = { LUA_EMPTY_TEXT }
			manager._selected = nil
		elseif not manager._selected or not manager._by_name[normalize_name(manager._selected)] then
			manager._selected = names[1]
		end

		list_dropdown:set_options(names, manager._selected)
		manager._rebuilding_options = false

		refresh_source_view()
	end)

	local register_entry = LPH_NO_VIRTUALIZE(function(entry)
		_insert(manager._entries, entry)

		manager._by_name[normalize_name(entry.name)] = entry
		manager._by_file[normalize_name(entry.file)] = entry
	end)

	local function add_script(name, file_name, source, auto_save)
		if not valid_lua_file_name(file_name) then
			return nil, 'file name is invalid'
		end

		local source_content = normalize_import_source(source)

		if not source_content then
			return nil, 'Lua source code cannot be empty'
		end

		local declared_name = source_lua_name(source_content) or trim_lua_name(name)

		if declared_name == '' then
			declared_name = 'Lua'
		end

		local unique_name = unique_lua_name(manager, declared_name)
		local unique_file = valid_lua_file_name(file_name) and file_name or unique_lua_file(manager, unique_name)

		local write_success, write_error = _pcall(writefile, lua_source_path(unique_file), source_content)

		if not write_success then
			return nil, `could not write Lua file: {_tostring(write_error)}`
		end

		local entry = {
			name = unique_name,
			file = unique_file,
			source = source_content,
			loaded = false,
			queued = {},
			registered = {},
		}

		register_entry(entry)

		manager._selected = unique_name

		if auto_save then
			save_lua_store(manager)
		end

		update_dropdown_options()

		return entry
	end

	for _, stored in store.entries do
		local entry_file = stored.file
		local source = stored.source

		if not source and valid_lua_file_name(entry_file) and isfile(lua_source_path(entry_file)) then
			local read_success, content = _pcall(readfile, lua_source_path(entry_file))

			if read_success then
				source = content
			end
		end

		if _type(source) == 'string' and source ~= '' then
			local source_content = normalize_import_source(source)

			if source_content then
				local name = unique_lua_name(manager, stored.name or source_lua_name(source_content) or 'Lua')
				local file_name = valid_lua_file_name(entry_file) and entry_file or unique_lua_file(manager, name)

				if file_name ~= entry_file or not isfile(lua_source_path(file_name)) then
					_pcall(writefile, lua_source_path(file_name), source_content)
				end

				register_entry({
					name = name,
					file = file_name,
					source = source_content,
					loaded = false,
					queued = {},
					registered = {},
				})
			end
		end
	end

	if manager._migrated then
		save_lua_store(manager)
	end

	local function execute_entry(entry)
		if not entry then
			return false, 'select a script to execute'
		end

		if entry.loaded then
			return false, `{entry.name} is already loaded`
		end

		local success, message = execute_lua_entry(manager, entry)

		if success then
			lua_notice(`executed {entry.name}`)
		else
			lua_warning(message or `failed to execute {entry.name}`)
		end

		return success, message
	end

	list_dropdown = group_manager:create_dropdown({
		title = 'Select Lua',
		options = {},
		hide_selected_option = false,
		callback = function(value)
			if manager._rebuilding_options then
				return
			end

			if value == LUA_EMPTY_TEXT then
				manager._selected = nil
			else
				manager._selected = value
			end

			save_lua_store(manager)
			refresh_source_view()
		end,
	})

	local action_row = create_new('Frame', {
		BackgroundTransparency = 1,
		LayoutOrder = next_row_order(),
		Size = _new_udim2(1, 0, 0, 26),
		Parent = container_frame,
	})

	create_vertical_list(action_row)

	local function create_action_button(title, width, callback)
		local button = create_new('TextButton', {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			Size = _new_udim2(0, width, 1, 0),
			FontFace = Font.new(
				'rbxasset://fonts/families/GothamSSm.json',
				Enum.FontWeight.SemiBold,
				Enum.FontStyle.Normal
			),
			Text = title,
			TextColor3 = Color3.fromRGB(180, 180, 180),
			TextSize = self._label_text_size,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Parent = action_row,
		})

		create_round(button, 6)

		button.MouseButton1Click:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)

			_create_tween(tween_service, button, _new_tween_info(0.2), {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			}):Play()

			callback()
		end)

		return button
	end

	local execute_button = create_action_button('Load', 78, function()
		execute_entry(selected_entry())
	end)

	local auto_button = create_action_button('Auto Load: Off', 116, function()
		local entry = selected_entry()

		if not entry then
			return
		end

		local key = normalize_name(entry.file)
		local enabled = not manager._auto_load_files[key]

		if enabled then
			manager._auto_load_files[key] = true
		else
			manager._auto_load_files[key] = nil
		end

		save_lua_store(manager)
		update_action_buttons()
	end)

	local delete_button = create_action_button('Delete', 70, function()
		local entry = selected_entry()

		if not entry then
			return
		end

		local normalized_name = normalize_name(entry.name)
		local normalized_file = normalize_name(entry.file)

		manager._by_name[normalized_name] = nil
		manager._by_file[normalized_file] = nil
		manager._auto_load_files[normalized_file] = nil

		for index, candidate in manager._entries do
			if candidate == entry then
				table.remove(manager._entries, index)

				break
			end
		end

		_pcall(delfile, lua_source_path(entry.file))

		manager._selected = nil
		save_lua_store(manager)
		update_dropdown_options()
	end)

	local create_button = create_action_button('Create', 68, function()
		local raw_source = source_textbox and source_textbox:get_value() or ''
		local source_content = normalize_import_source(raw_source)

		if not source_content then
			lua_warning('paste Lua code into the editor before creating')

			return
		end

		local declared_name = source_lua_name(source_content) or 'Custom Lua'
		local new_file = lua_file_name(declared_name)
		local created_entry, create_error = add_script(declared_name, new_file, source_content, true)

		if created_entry then
			lua_notice(`created {created_entry.name}`)
		else
			lua_warning(create_error or 'failed to create Lua')
		end
	end)

	local row_layout = create_new('UIListLayout', {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = _new_udim(0, 6),
		Parent = action_row,
	})

	local function refit_action_row()
		local total_width = container_frame.AbsoluteSize.X

		if total_width <= 0 then
			return
		end

		local gap = 6
		local available = total_width - (gap * 3)

		execute_button.Size = _new_udim2(0, _floor(available * 0.22), 1, 0)
		auto_button.Size = _new_udim2(0, _floor(available * 0.38), 1, 0)
		delete_button.Size = _new_udim2(0, _floor(available * 0.20), 1, 0)
		create_button.Size = _new_udim2(0, total_width - execute_button.AbsoluteSize.X - auto_button.AbsoluteSize.X - delete_button.AbsoluteSize.X - (gap * 3), 1, 0)
	end

	container_frame:GetPropertyChangedSignal('AbsoluteSize'):Connect(refit_action_row)
	refit_action_row()

	update_action_buttons = LPH_NO_VIRTUALIZE(function()
		local entry = selected_entry()

		if not entry then
			auto_button.Text = 'Auto Load: Off'

			return
		end

		local auto_enabled = manager._auto_load_files[normalize_name(entry.file)] == true
		auto_button.Text = auto_enabled and 'Auto Load: On' or 'Auto Load: Off'
	end)

	source_textbox = group_manager:create_textbox(nil, {
		title = 'Lua Editor',
		height = 110,
		placeholder = '-- write or paste custom Lua scripts here\n-- local lua_name = "script_name"',
		multi_line = true,
		compact = false,
		callback = function(raw_source)
			local entry = selected_entry()

			if not entry then
				return
			end

			local source_content = normalize_import_source(raw_source)

			if not source_content then
				return
			end

			entry.source = source_content
			_pcall(writefile, lua_source_path(entry.file), source_content)
		end,
	})

	update_dropdown_options()

	for _, entry in manager._entries do
		if manager._auto_load_files[normalize_name(entry.file)] then
			execute_entry(entry)
		end
	end

	return manager
end

function library.create_lua_manager(self: _runtime, container_frame: Frame)
	return self:_init_lua_manager(container_frame)
end

function library.build_lua_tab(self: _runtime, tab_title: string?, category_name: string?)
	if self._manager_loaded then
		return self._lua_manager
	end

	tab_title = tab_title or 'Luas'
	category_name = category_name or 'Luas'

	local category = self:create_category(category_name)
	local tab = category:create_tab(tab_title, 'rbxassetid://10709818996')
	local group = tab:create_group('Manager', 'left')

	self._manager_loaded = true

	return self:_init_lua_manager(group._frame)
end

library.new = library._new

return library
