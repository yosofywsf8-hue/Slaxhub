-- ============================================================
-- AZURE (partial dari file Redz) + TAB PARRY
-- Paste utuh. Execute.
-- ============================================================

local _PARRY_PATCH = { keyTable=nil, transformFn=nil, parryHash=nil, parryRemote=nil, ready=false }

task.spawn(function()
    local ok, err = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local Controllers = RS:WaitForChild("Controllers", 15)
        if not Controllers then return end
        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 16) == "SwordsController" then SC = child break end
        end
        if not SC then warn("[PARRY PATCH] SwordsController not found") return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then warn("[PARRY PATCH] PRY not found") return end
        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then warn("[PARRY PATCH] no getupvalues") return end
        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then warn("[PARRY PATCH] ups<8") return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
    end)
    if not ok then warn("[PARRY PATCH] init error:", tostring(err)) end
end)

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))

local _reverted = {}
local _original = {}

function _is_valid(args)
    return #args == 8 and type(args[2])=="string" and type(args[3])=="string" and type(args[4])=="number"
        and typeof(args[5])=="CFrame" and type(args[6])=="table" and type(args[7])=="table" and type(args[8])=="boolean"
end

function _hook(remote)
    if not _reverted[remote] then
        if not _original[getrawmetatable(remote)] then
            _original[getrawmetatable(remote)] = true
            local _meta = getrawmetatable(remote)
            setreadonly(_meta, false)
            local _old = _meta.__index
            _meta.__index = function(self, key)
                if (key == 'FireServer' and self:IsA('RemoteEvent')) or
                   (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                    return function(_, ...)
                        local _arguments = {...}
                        if _is_valid(_arguments) then
                            if not _reverted[self] then
                                _reverted[self] = _arguments
                                _PARRY_PATCH.ready = true
                                _PARRY_PATCH.parryRemote = self
                            end
                        end
                        return _old(self, key)(_, unpack(_arguments))
                    end
                end
                return _old(self, key)
            end
            setreadonly(_meta, true)
        end
    end
end

for _iterator, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

function _PARRY_PATCH.fire(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local keyIndex = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
    if not currentKey then return false end
    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false end
    end
    local serverTime = workspace:GetServerTimeNow() * 100
    local timeStr = tostring(math.floor(serverTime))
    local tc = {}
    for i = 1, #timeStr do
        local ki = (i - 1) % #transformed + 1
        local kb = string.byte(transformed, ki)
        local tb = (string.byte(timeStr, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)
    return pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token, 0.5,
            curveCFrame, screenPositions, mouseLocation, false
        )
    end)
end

getgenv().GG = { Language = { CheckboxEnabled="Enabled", CheckboxDisabled="Disabled" } }
local SelectedLanguage = GG.Language

function convertStringToTable(inputString)
    local result = {}
    for value in string.gmatch(inputString, "([^,]+)") do
        table.insert(result, value:match("^%s*(.-)%s*$"))
    end
    return result
end
function convertTableToString(t) return table.concat(t, ", ") end

local UserInputService = cloneref(game:GetService('UserInputService'))
local ContentProvider  = cloneref(game:GetService('ContentProvider'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local TextService      = cloneref(game:GetService('TextService'))
local RunService       = cloneref(game:GetService('RunService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Players          = cloneref(game:GetService('Players'))
local CoreGui          = cloneref(game:GetService('CoreGui'))
local Debris           = cloneref(game:GetService('Debris'))

local Connections = setmetatable({
    disconnect = function(self, connection)
        if not self[connection] then return end
        self[connection]:Disconnect()
        self[connection] = nil
    end,
    disconnect_all = function(self)
        for _, value in pairs(self) do
            if typeof(value) == 'function' then continue end
            value:Disconnect()
        end
    end
}, {__index=function(t,k) return rawget(t,k) end})

local Util = setmetatable({
    map = function(self, value, in_min, in_max, out_min, out_max)
        return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
    end,
    viewport_point_to_world = function(self, location, distance)
        local ray = workspace.CurrentCamera:ScreenPointToRay(location.X, location.Y)
        return ray.Origin + ray.Direction * distance
    end,
    get_offset = function(self)
        return self:map(workspace.CurrentCamera.ViewportSize.Y, 0, 2560, 8, 56)
    end
}, {__index=function(t,k) return rawget(t,k) end})

-- ============================================================
-- AcrylicBlur (partial — cukup buat jalan)
-- ============================================================
local AcrylicBlur = {}
AcrylicBlur.__index = AcrylicBlur
function AcrylicBlur.new(object)
    local self = setmetatable({_object=object,_folder=nil,_frame=nil,_root=nil}, AcrylicBlur)
    pcall(function()
        local folder = Instance.new('Folder')
        folder.Name = 'AcrylicBlur'
        folder.Parent = workspace.CurrentCamera
        self._folder = folder
        local dof = Lighting:FindFirstChild('AcrylicBlur') or Instance.new('DepthOfFieldEffect')
        dof.FarIntensity = 0; dof.FocusDistance = 0.05; dof.InFocusRadius = 0.1; dof.NearIntensity = 1
        dof.Name = 'AcrylicBlur'; dof.Parent = Lighting
        local part = Instance.new('Part')
        part.Name='Root'; part.Color=Color3.new(0,0,0); part.Material=Enum.Material.Glass
        part.Size=Vector3.new(1,1,0); part.Anchored=true; part.CanCollide=false
        part.CanQuery=false; part.Locked=true; part.CastShadow=false
        part.Transparency=0.98; part.Parent=folder
        local mesh = Instance.new('SpecialMesh'); mesh.MeshType=Enum.MeshType.Brick
        mesh.Offset = Vector3.new(0,0,-0.000001); mesh.Parent = part
        self._root = part
    end)
    return self
end

-- ============================================================
-- Config (dengan fallback kalau executor nggak support writefile)
-- ============================================================
local HAS_FS = type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
local Config = setmetatable({
    save = function(self, file_name, config)
        if not HAS_FS then return end
        pcall(function()
            if type(makefolder)=="function" and type(isfolder)=="function" and not isfolder("Azure") then
                makefolder("Azure")
            end
            writefile('Azure/'..file_name..'.json', HttpService:JSONEncode(config))
        end)
    end,
    load = function(self, file_name, config)
        if not HAS_FS then return {_flags={},_keybinds={},_library={}} end
        local ok, result = pcall(function()
            if not isfile('Azure/'..file_name..'.json') then
                self:save(file_name, config); return
            end
            local flags = readfile('Azure/'..file_name..'.json')
            if not flags then self:save(file_name, config); return end
            return HttpService:JSONDecode(flags)
        end)
        if not ok or not result then
            result = {_flags={},_keybinds={},_library={}}
        end
        return result
    end
}, {__index=function(t,k) return rawget(t,k) end})

local Library = {
    _config = Config:load(tostring(game.GameId)),
    _choosing_keybind = false,
    _device = nil,
    _ui_open = true,
    _ui_scale = 1,
    _ui_loaded = false,
    _ui = nil,
    _dragging = false,
    _drag_start = nil,
    _container_position = nil,
}
Library.__index = Library

function Library:create_notification_root()
    if self._notification_root then return self._notification_root end
    local function corner(p, r)
        local c = Instance.new('UICorner'); c.CornerRadius = r or UDim.new(0,12); c.Parent = p; return c
    end
    local function stroke(p, col, tr, tk)
        local s = Instance.new('UIStroke'); s.Color = col or Color3.fromRGB(52,55,66)
        s.Transparency = tr or 0.4; s.Thickness = tk or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
    end
    local function tween(o, dur, props, style, dir)
        return TweenService:Create(o, TweenInfo.new(dur, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    end
    local old = CoreGui:FindFirstChild('AzureNotificationRoot')
    if old then old:Destroy() end
    local root = Instance.new('ScreenGui')
    root.Name='AzureNotificationRoot'; root.ResetOnSpawn=false
    root.IgnoreGuiInset=true; root.Parent = CoreGui
    local holder = Instance.new('Frame')
    holder.Name='ToastHolder'; holder.AnchorPoint=Vector2.new(0.5,0)
    holder.Position=UDim2.new(0.5,0,0,14); holder.Size=UDim2.new(0.82,0,1,-28)
    holder.BackgroundTransparency=1; holder.Parent = root
    local sc = Instance.new('UISizeConstraint'); sc.MaxSize=Vector2.new(390, math.huge); sc.Parent=holder
    local ll = Instance.new('UIListLayout')
    ll.FillDirection=Enum.FillDirection.Vertical
    ll.HorizontalAlignment=Enum.HorizontalAlignment.Center
    ll.VerticalAlignment=Enum.VerticalAlignment.Top
    ll.Padding=UDim.new(0,8); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Parent=holder
    self._notification_root = root
    self._notification_holder = holder
    self._notification_active = {}
    self._notification_helpers = {
        corner=corner, stroke=stroke, tween=tween,
        theme = {
            bg=Color3.fromRGB(17,18,23), bgSoft=Color3.fromRGB(26,28,35),
            stroke=Color3.fromRGB(52,55,66), strokeLit=Color3.fromRGB(78,82,98),
            text=Color3.fromRGB(238,240,246), textDim=Color3.fromRGB(152,157,170),
            textFaint=Color3.fromRGB(104,109,124), success=Color3.fromRGB(88,198,140),
            info=Color3.fromRGB(98,160,226), warning=Color3.fromRGB(226,178,90),
            error=Color3.fromRGB(224,104,112), accent=Color3.fromRGB(98,160,226),
            font=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Regular,Enum.FontStyle.Normal),
            fontMed=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.Medium,Enum.FontStyle.Normal),
            fontBold=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),
            radius=UDim.new(0,12),
        },
        icons = {
            success='rbxassetid://7733715400', info='rbxassetid://7734053495',
            warning='rbxassetid://7734019099', error='rbxassetid://7733658133',
        }
    }
    return root
end

function Library:notify(settings)
    settings = settings or {}
    local root = self:create_notification_root()
    local helper = self._notification_helpers
    if not root or not helper then return end
    local theme = helper.theme
    local icons = helper.icons
    local function variant_color(v)
        if v=='success' then return theme.success
        elseif v=='warning' then return theme.warning
        elseif v=='error' then return theme.error end
        return theme.info
    end
    local function detect_variant(d)
        local t = string.lower(tostring(d.title or '')..' '..tostring(d.text or ''))
        if t:find('error') or t:find('fail') then return 'error'
        elseif t:find('warn') or t:find('ping') then return 'warning'
        elseif t:find('off') or t:find('disable') then return 'info'
        elseif t:find('on') or t:find('enable') then return 'success' end
        return 'info'
    end
    local variant = settings.type and string.lower(settings.type) or detect_variant(settings)
    local color = variant_color(variant)
    local duration = tonumber(settings.duration) or 2.5
    local title = settings.title and tostring(settings.title) or nil
    local body = settings.text and tostring(settings.text) ~= '' and tostring(settings.text) or nil
    local one_line = not (title and body)
    local label = one_line and (body or title or 'Notification') or nil
    if #self._notification_active >= 3 and self._notification_active[1] then
        self._notification_active[1].dismiss()
    end
    local card = Instance.new('Frame')
    card.Name='Toast'; card.Size=UDim2.new(1,0,0,one_line and 44 or 58)
    card.BackgroundColor3=Color3.fromRGB(18,20,28)
    card.BackgroundTransparency=0.02; card.BorderSizePixel=0
    card.Position=UDim2.new(0,0,0,-10); card.Parent=self._notification_holder
    helper.corner(card); helper.stroke(card, Color3.fromRGB(70,75,90), 0.25)
    local chip = Instance.new('Frame', card)
    chip.Size=UDim2.new(0,26,0,26)
    chip.Position = one_line and UDim2.new(0,18,0.5,-13) or UDim2.new(0,18,0,12)
    chip.BackgroundColor3=color; chip.BackgroundTransparency=0.88
    chip.BorderSizePixel=0; helper.corner(chip, UDim.new(1,0))
    local icon = Instance.new('ImageLabel', chip)
    icon.BackgroundTransparency=1; icon.AnchorPoint=Vector2.new(0.5,0.5)
    icon.Position=UDim2.fromScale(0.5,0.5); icon.Size=UDim2.new(0,15,0,15)
    icon.Image=icons[variant] or icons.info; icon.ImageColor3=color
    if one_line then
        local m = Instance.new('TextLabel', card)
        m.BackgroundTransparency=1; m.Position=UDim2.new(0,54,0,0)
        m.Size=UDim2.new(1,-72,1,-2); m.Text=label
        m.TextColor3=theme.text; m.FontFace=theme.fontMed; m.TextSize=13
        m.TextXAlignment=Enum.TextXAlignment.Left
        m.TextYAlignment=Enum.TextYAlignment.Center
        m.TextTruncate=Enum.TextTruncate.AtEnd
    else
        local tl = Instance.new('TextLabel', card)
        tl.BackgroundTransparency=1; tl.Position=UDim2.new(0,54,0,10)
        tl.Size=UDim2.new(1,-72,0,16); tl.Text=title
        tl.TextColor3=theme.text; tl.FontFace=theme.fontBold; tl.TextSize=13
        tl.TextXAlignment=Enum.TextXAlignment.Left
        local bl = Instance.new('TextLabel', card)
        bl.BackgroundTransparency=1; bl.Position=UDim2.new(0,54,0,29)
        bl.Size=UDim2.new(1,-68,0,15); bl.Text=body
        bl.TextColor3=theme.textDim; bl.FontFace=theme.font; bl.TextSize=11
        bl.TextXAlignment=Enum.TextXAlignment.Left
    end
    local pbg = Instance.new('Frame', card)
    pbg.AnchorPoint=Vector2.new(0,1); pbg.Position=UDim2.new(0,14,1,-5)
    pbg.Size=UDim2.new(1,-28,0,2); pbg.BackgroundColor3=Color3.fromRGB(38,42,52)
    pbg.BackgroundTransparency=0.35; pbg.BorderSizePixel=0
    helper.corner(pbg, UDim.new(1,0))
    local prog = Instance.new('Frame', pbg)
    prog.Size=UDim2.fromScale(1,1); prog.BackgroundColor3=color
    prog.BorderSizePixel=0; helper.corner(prog, UDim.new(1,0))
    card.BackgroundTransparency=1
    helper.tween(card, 0.32, {BackgroundTransparency=0.02}):Play()
    helper.tween(prog, duration, {Size=UDim2.new(0,0,1,0)}, Enum.EasingStyle.Linear):Play()
    local entry = {dismissed=false}
    function entry.dismiss()
        if entry.dismissed then return end
        entry.dismissed = true
        for i, cur in ipairs(self._notification_active) do
            if cur == entry then table.remove(self._notification_active, i) break end
        end
        local ti = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        TweenService:Create(card, ti, {BackgroundTransparency=1, Position=UDim2.new(0,0,0,-10)}):Play()
        for _, o in ipairs(card:GetDescendants()) do
            if o:IsA('TextLabel') then TweenService:Create(o, ti, {TextTransparency=1}):Play()
            elseif o:IsA('ImageLabel') then TweenService:Create(o, ti, {ImageTransparency=1}):Play()
            elseif o:IsA('Frame') then TweenService:Create(o, ti, {BackgroundTransparency=1}):Play() end
        end
        task.delay(0.3, function() if card then pcall(function() card:Destroy() end) end end)
    end
    card.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            entry.dismiss()
        end
    end)
    table.insert(self._notification_active, entry)
    task.delay(duration, function() entry.dismiss() end)
end

function Library.SendNotification(settings)
    if _G.PremiumUI_Notify then return _G.PremiumUI_Notify(settings) end
    if Library and Library.notify then return Library:notify(settings) end
end

function Library.new()
    local self = setmetatable({_loaded=false, _tab=0}, Library)
    self:create_notification_root()
    self:create_ui()
    return self
end

function Library:get_screen_scale()
    self._ui_scale = workspace.CurrentCamera.ViewportSize.X / 1400
end

function Library:get_device()
    if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        self._device='PC'
    elseif UserInputService.TouchEnabled then self._device='Mobile'
    elseif UserInputService.GamepadEnabled then self._device='Console'
    else self._device='Unknown' end
end

function Library:removed(action) self._ui.AncestryChanged:Once(action) end

function Library:flag_type(flag, flag_type)
    if not Library._config._flags[flag] then return end
    return typeof(Library._config._flags[flag]) == flag_type
end

function Library:remove_table_value(t, v)
    for i, x in pairs(t) do if x == v then table.remove(t, i) end end
end

function Library:create_ui()
    local old = CoreGui:FindFirstChild('Azure')
    if old then Debris:AddItem(old, 0) end
    local AzureUI = Instance.new('ScreenGui')
    AzureUI.ResetOnSpawn=false; AzureUI.Name='Azure'
    AzureUI.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    AzureUI.Parent = CoreGui

    local Container = Instance.new('Frame')
    Container.ClipsDescendants=true
    Container.AnchorPoint=Vector2.new(0.5,0.5)
    Container.Name='Container'
    Container.BackgroundTransparency=0
    Container.BackgroundColor3=Color3.fromRGB(30,30,35)
    Container.Position=UDim2.new(0.5,0,0.5,0)
    Container.Size=UDim2.new(0,0,0,0)
    Container.Active=true; Container.BorderSizePixel=0
    Container.ZIndex=2; Container.Parent=AzureUI

    local ContainerGradient = Instance.new('UIGradient')
    ContainerGradient.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.10,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.12,Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}
    ContainerGradient.Rotation=90; ContainerGradient.Parent=Container

    local SideBar = Instance.new('Frame')
    SideBar.Name='GradientSide'; SideBar.Parent=Container
    SideBar.Size=UDim2.new(0,10,1,0); SideBar.Position=UDim2.new(0,0,0,0)
    SideBar.BackgroundTransparency=1
    local SideGradient = Instance.new('UIGradient')
    SideGradient.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(30,30,34)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(55,110,190)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(110,80,200))}
    SideGradient.Rotation=90; SideGradient.Parent=SideBar

    local UICorner = Instance.new('UICorner')
    UICorner.CornerRadius=UDim.new(0,12); UICorner.Parent=Container
    local UIStroke = Instance.new('UIStroke')
    UIStroke.Color=Color3.fromRGB(78,92,122); UIStroke.Thickness=1
    UIStroke.Transparency=0.28; UIStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    UIStroke.Parent=Container

    local Handler = Instance.new('Frame')
    Handler.BackgroundTransparency=1; Handler.Name='Handler'
    Handler.Size=UDim2.new(0,750,0,530); Handler.BorderSizePixel=0
    Handler.Parent=Container

    local Tabs = Instance.new('ScrollingFrame')
    Tabs.ScrollBarImageTransparency=1; Tabs.ScrollBarThickness=0
    Tabs.Name='Tabs'; Tabs.Size=UDim2.new(0,140,0,445)
    Tabs.Selectable=false; Tabs.AutomaticCanvasSize=Enum.AutomaticSize.XY
    Tabs.BackgroundTransparency=1; Tabs.Position=UDim2.new(0.026,0,0.111,10)
    Tabs.CanvasSize=UDim2.new(0,0,0.5,0); Tabs.Parent=Handler
    local UIListLayout = Instance.new('UIListLayout')
    UIListLayout.Padding=UDim.new(0,4); UIListLayout.SortOrder=Enum.SortOrder.LayoutOrder
    UIListLayout.Parent=Tabs

    local Divider = Instance.new('Frame')
    Divider.Name='Divider'; Divider.BackgroundTransparency=0.5
    Divider.Position=UDim2.new(0.225,0,0,68)
    Divider.Size=UDim2.new(0,1,0,440); Divider.BorderSizePixel=0
    Divider.BackgroundColor3=Color3.fromRGB(255,255,255); Divider.Parent=Handler
    local DividerGradient = Instance.new('UIGradient')
    DividerGradient.Transparency=NumberSequence.new{
        NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.12,0.4),
        NumberSequenceKeypoint.new(0.88,0.4), NumberSequenceKeypoint.new(1,1)}
    DividerGradient.Rotation=90; DividerGradient.Parent=Divider

    local Sections = Instance.new('Folder')
    Sections.Name='Sections'; Sections.Parent=Handler

    local UIScale = Instance.new('UIScale'); UIScale.Parent=Container

    self._ui = AzureUI

    -- drag
    local function on_drag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._drag_start = input.Position
            self._container_position = Container.Position
            Connections['c_ended'] = input.Changed:Connect(function()
                if input.UserInputState ~= Enum.UserInputState.End then return end
                Connections:disconnect('c_ended')
                self._dragging = false
            end)
        end
    end
    local function drag(input)
        if not self._dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - self._drag_start
            TweenService:Create(Container, TweenInfo.new(0.2), {Position = UDim2.new(
                self._container_position.X.Scale, self._container_position.X.Offset + delta.X,
                self._container_position.Y.Scale, self._container_position.Y.Offset + delta.Y
            )}):Play()
        end
    end
    Connections['c_began'] = Container.InputBegan:Connect(on_drag)
    Connections['input_changed'] = UserInputService.InputChanged:Connect(drag)

    function self:change_visiblity(state)
        if state then
            TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(750,530)}):Play()
        else
            TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(104.5,52)}):Play()
        end
    end

    function self:load()
        self:get_device()
        if self._device == 'Mobile' or self._device == 'Unknown' then
            self:get_screen_scale()
            UIScale.Scale = self._ui_scale
            Connections['ui_scale'] = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
                self:get_screen_scale(); UIScale.Scale = self._ui_scale
            end)
        end
        TweenService:Create(Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size=UDim2.fromOffset(750,530)}):Play()
        pcall(function() AcrylicBlur.new(Container) end)
        self._ui_loaded = true
    end

    function self:update_tabs(tab)
        for _, obj in ipairs(Tabs:GetChildren()) do
            if obj.Name ~= 'Tab' then continue end
            if obj == tab then
                if obj.BackgroundTransparency ~= 0.85 then
                    TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundTransparency=0.85, BackgroundColor3=Color3.fromRGB(220,220,220)}):Play()
                    TweenService:Create(obj.TextLabel, TweenInfo.new(0.3), {TextTransparency=0.3}):Play()
                end
            else
                if obj.BackgroundTransparency ~= 1 then
                    TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
                    TweenService:Create(obj.TextLabel, TweenInfo.new(0.3), {TextTransparency=0.6}):Play()
                end
            end
        end
    end

    function self:update_sections(l, r)
        for _, obj in ipairs(Sections:GetChildren()) do
            obj.Visible = (obj == l or obj == r)
        end
    end

    function self:create_tab(title)
        local TabManager = {}
        local first_tab = not Tabs:FindFirstChild('Tab')

        local Tab = Instance.new('TextButton')
        Tab.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        Tab.Text=''; Tab.AutoButtonColor=false; Tab.BackgroundTransparency=1
        Tab.Name='Tab'; Tab.Size=UDim2.new(0,129,0,38); Tab.BorderSizePixel=0
        Tab.BackgroundColor3=Color3.fromRGB(22,22,22); Tab.Parent=Tabs
        Tab.LayoutOrder = self._tab
        local TC = Instance.new('UICorner'); TC.CornerRadius=UDim.new(0,8); TC.Parent=Tab

        local TextLabel = Instance.new('TextLabel')
        TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        TextLabel.TextColor3=Color3.fromRGB(255,255,255); TextLabel.TextTransparency=0.7
        TextLabel.Text=title; TextLabel.Size=UDim2.new(0,100,0,16)
        TextLabel.AnchorPoint=Vector2.new(0,0.5); TextLabel.Position=UDim2.new(0.24,0,0.5,0)
        TextLabel.BackgroundTransparency=1; TextLabel.TextXAlignment=Enum.TextXAlignment.Left
        TextLabel.TextSize=13; TextLabel.Parent=Tab

        local LeftSection = Instance.new('ScrollingFrame')
        LeftSection.Name='LeftSection'; LeftSection.AutomaticCanvasSize=Enum.AutomaticSize.XY
        LeftSection.ScrollBarThickness=0; LeftSection.Size=UDim2.new(0,243,0,445)
        LeftSection.Selectable=false; LeftSection.AnchorPoint=Vector2.new(0,0.5)
        LeftSection.ScrollBarImageTransparency=1; LeftSection.BackgroundTransparency=1
        LeftSection.Position=UDim2.new(0.259,0,0.5,25); LeftSection.BorderSizePixel=0
        LeftSection.CanvasSize=UDim2.new(0,0,0.5,0); LeftSection.Visible=false
        LeftSection.Parent=Sections
        local LLL = Instance.new('UIListLayout')
        LLL.Padding=UDim.new(0,18); LLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
        LLL.SortOrder=Enum.SortOrder.LayoutOrder; LLL.Parent=LeftSection
        local LLP = Instance.new('UIPadding')
        LLP.PaddingTop=UDim.new(0,1); LLP.Parent=LeftSection

        local RightSection = Instance.new('ScrollingFrame')
        RightSection.Name='RightSection'; RightSection.AutomaticCanvasSize=Enum.AutomaticSize.XY
        RightSection.ScrollBarThickness=0; RightSection.Size=UDim2.new(0,243,0,445)
        RightSection.Selectable=false; RightSection.AnchorPoint=Vector2.new(0,0.5)
        RightSection.ScrollBarImageTransparency=1; RightSection.BackgroundTransparency=1
        RightSection.Position=UDim2.new(0.629,0,0.5,25); RightSection.BorderSizePixel=0
        RightSection.CanvasSize=UDim2.new(0,0,0.5,0); RightSection.Visible=false
        RightSection.Parent=Sections
        local RLL = Instance.new('UIListLayout')
        RLL.Padding=UDim.new(0,18); RLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
        RLL.SortOrder=Enum.SortOrder.LayoutOrder; RLL.Parent=RightSection
        local RLP = Instance.new('UIPadding')
        RLP.PaddingTop=UDim.new(0,1); RLP.Parent=RightSection

        self._tab = self._tab + 1
        if first_tab then
            self:update_tabs(Tab); self:update_sections(LeftSection, RightSection)
        end
        Tab.MouseButton1Click:Connect(function()
            self:update_tabs(Tab); self:update_sections(LeftSection, RightSection)
        end)

        function TabManager:create_module(settings)
            local ModuleManager = {_state=false, _size=0, _multiplier=0, options={}}
            if settings.section == 'right' then settings.section = RightSection
            else settings.section = LeftSection end

            local Module = Instance.new('Frame')
            Module.ClipsDescendants=true; Module.BackgroundTransparency=0.02
            Module.Name='Module'; Module.Size=UDim2.new(0,241,0,93)
            Module.BorderSizePixel=0; Module.BackgroundColor3=Color3.fromRGB(16,17,22)
            Module.Parent=settings.section
            local MC = Instance.new('UICorner'); MC.CornerRadius=UDim.new(0,8); MC.Parent=Module
            local MS = Instance.new('UIStroke'); MS.Color=Color3.fromRGB(255,255,255)
            MS.Transparency=0.72; MS.Thickness=1; MS.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
            MS.Parent=Module

            local Header = Instance.new('TextButton')
            Header.Text=''; Header.AutoButtonColor=false; Header.BackgroundTransparency=1
            Header.Name='Header'; Header.Size=UDim2.new(0,241,0,93); Header.BorderSizePixel=0
            Header.Parent=Module

            local MN = Instance.new('TextLabel')
            MN.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
            MN.TextColor3=Color3.fromRGB(255,255,255); MN.TextTransparency=0.2
            MN.Text=settings.title or "Module"; MN.Size=UDim2.new(0,205,0,13)
            MN.AnchorPoint=Vector2.new(0,0.5); MN.Position=UDim2.new(0.073,0,0.24,0)
            MN.BackgroundTransparency=1; MN.TextXAlignment=Enum.TextXAlignment.Left
            MN.TextSize=13; MN.Parent=Header

            local Desc = Instance.new('TextLabel')
            Desc.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
            Desc.TextColor3=Color3.fromRGB(255,255,255); Desc.TextTransparency=0.7
            Desc.Text=settings.description or ""; Desc.Size=UDim2.new(0,205,0,13)
            Desc.AnchorPoint=Vector2.new(0,0.5); Desc.Position=UDim2.new(0.073,0,0.42,0)
            Desc.BackgroundTransparency=1; Desc.TextXAlignment=Enum.TextXAlignment.Left
            Desc.TextSize=10; Desc.Parent=Header

            local Toggle = Instance.new('Frame')
            Toggle.Name='Toggle'; Toggle.BackgroundTransparency=0.7
            Toggle.Position=UDim2.new(0.82,0,0.757,0); Toggle.Size=UDim2.new(0,25,0,12)
            Toggle.BorderSizePixel=0; Toggle.BackgroundColor3=Color3.fromRGB(44,44,52)
            Toggle.Parent=Header
            local TGC = Instance.new('UICorner'); TGC.CornerRadius=UDim.new(1,0); TGC.Parent=Toggle
            local Circle = Instance.new('Frame')
            Circle.AnchorPoint=Vector2.new(0,0.5); Circle.BackgroundTransparency=0.2
            Circle.Position=UDim2.new(0,0,0.5,0); Circle.Name='Circle'
            Circle.Size=UDim2.new(0,12,0,12); Circle.BorderSizePixel=0
            Circle.BackgroundColor3=Color3.fromRGB(120,120,132); Circle.Parent=Toggle
            local CC = Instance.new('UICorner'); CC.CornerRadius=UDim.new(1,0); CC.Parent=Circle

            local Options = Instance.new('Frame')
            Options.Name='Options'; Options.BackgroundTransparency=1
            Options.Position=UDim2.new(0,0,1,0); Options.Size=UDim2.new(0,241,0,8)
            Options.BorderSizePixel=0; Options.Parent=Module
            local OP = Instance.new('UIPadding'); OP.PaddingTop=UDim.new(0,8); OP.Parent=Options
            local OLL = Instance.new('UIListLayout')
            OLL.Padding=UDim.new(0,5); OLL.HorizontalAlignment=Enum.HorizontalAlignment.Center
            OLL.SortOrder=Enum.SortOrder.LayoutOrder; OLL.Parent=Options

            function ModuleManager:change_state(state)
                self._state = state
                if state then
                    TweenService:Create(Module, TweenInfo.new(0.3), {Size=UDim2.fromOffset(241, 93+self._size+self._multiplier)}):Play()
                    TweenService:Create(Toggle, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(205,205,220)}):Play()
                    TweenService:Create(Circle, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(245,245,250), Position=UDim2.fromScale(0.53,0.5)}):Play()
                else
                    TweenService:Create(Module, TweenInfo.new(0.3), {Size=UDim2.fromOffset(241, 93)}):Play()
                    TweenService:Create(Toggle, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(44,44,52)}):Play()
                    TweenService:Create(Circle, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(120,120,132), Position=UDim2.fromScale(0,0.5)}):Play()
                end
                if settings.flag then
                    Library._config._flags[settings.flag] = state
                    Config:save(tostring(game.GameId), Library._config)
                end
                if settings.callback then settings.callback(state) end
            end

            Header.MouseButton1Click:Connect(function()
                ModuleManager:change_state(not ModuleManager._state)
            end)

            function ModuleManager:create_checkbox(s)
                local CBM = {_state=false}
                if self._size == 0 then self._size = 11 end
                self._size = self._size + 20
                Options.Size = UDim2.fromOffset(241, self._size)
                if self._state then Module.Size = UDim2.fromOffset(241, 93+self._size) end

                local CB = Instance.new('TextButton')
                CB.Text=''; CB.AutoButtonColor=false; CB.BackgroundTransparency=1
                CB.Size=UDim2.new(0,207,0,15); CB.BorderSizePixel=0; CB.Parent=Options
                local Title = Instance.new('TextLabel')
                Title.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                Title.TextColor3=Color3.fromRGB(255,255,255); Title.TextTransparency=0.2
                Title.Text=s.title or "Checkbox"; Title.Size=UDim2.new(0,142,0,13)
                Title.AnchorPoint=Vector2.new(0,0.5); Title.Position=UDim2.new(0,0,0.5,0)
                Title.BackgroundTransparency=1; Title.TextXAlignment=Enum.TextXAlignment.Left
                Title.TextSize=11; Title.Parent=CB
                local Box = Instance.new('Frame')
                Box.AnchorPoint=Vector2.new(1,0.5); Box.BackgroundTransparency=0.9
                Box.Position=UDim2.new(1,0,0.5,0); Box.Size=UDim2.new(0,15,0,15)
                Box.BorderSizePixel=0; Box.BackgroundColor3=Color3.fromRGB(245,245,250)
                Box.Parent=CB
                local BC = Instance.new('UICorner'); BC.CornerRadius=UDim.new(0,7); BC.Parent=Box
                local Fill = Instance.new('Frame')
                Fill.AnchorPoint=Vector2.new(0.5,0.5); Fill.BackgroundTransparency=0.2
                Fill.Position=UDim2.new(0.5,0,0.5,0); Fill.Size=UDim2.fromOffset(0,0)
                Fill.BorderSizePixel=0; Fill.BackgroundColor3=Color3.fromRGB(245,245,250)
                Fill.Parent=Box
                local FC = Instance.new('UICorner'); FC.CornerRadius=UDim.new(0,6); FC.Parent=Fill

                function CBM:change_state(state)
                    self._state = state
                    TweenService:Create(Box, TweenInfo.new(0.3), {BackgroundTransparency=state and 0.7 or 0.9}):Play()
                    TweenService:Create(Fill, TweenInfo.new(0.3), {Size=state and UDim2.fromOffset(9,9) or UDim2.fromOffset(0,0)}):Play()
                    if s.flag then Library._config._flags[s.flag] = state end
                    if s.callback then s.callback(state) end
                end
                CB.MouseButton1Click:Connect(function() CBM:change_state(not CBM._state) end)
                return CBM
            end

            function ModuleManager:create_slider(s)
                local SM = {}
                if self._size == 0 then self._size = 11 end
                self._size = self._size + 27
                Options.Size = UDim2.fromOffset(241, self._size)
                if self._state then Module.Size = UDim2.fromOffset(241, 93+self._size) end

                local SL = Instance.new('TextButton')
                SL.Text=''; SL.AutoButtonColor=false; SL.BackgroundTransparency=1
                SL.Size=UDim2.new(0,207,0,22); SL.BorderSizePixel=0; SL.Parent=Options
                local TL = Instance.new('TextLabel')
                TL.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                TL.TextColor3=Color3.fromRGB(255,255,255); TL.TextTransparency=0.2
                TL.Text=s.title or "Slider"; TL.Size=UDim2.new(0,153,0,13)
                TL.Position=UDim2.new(0,0,0.05,0); TL.BackgroundTransparency=1
                TL.TextXAlignment=Enum.TextXAlignment.Left; TL.TextSize=11; TL.Parent=SL
                local Drag = Instance.new('Frame')
                Drag.AnchorPoint=Vector2.new(0.5,1); Drag.BackgroundTransparency=0.7
                Drag.Position=UDim2.new(0.5,0,0.95,0); Drag.Size=UDim2.new(0,207,0,4)
                Drag.BorderSizePixel=0; Drag.BackgroundColor3=Color3.fromRGB(34,34,40)
                Drag.Parent=SL
                local DC = Instance.new('UICorner'); DC.CornerRadius=UDim.new(1,0); DC.Parent=Drag
                local Fill = Instance.new('Frame')
                Fill.AnchorPoint=Vector2.new(0,0.5); Fill.BackgroundTransparency=0.15
                Fill.Position=UDim2.new(0,0,0.5,0); Fill.Size=UDim2.new(0,0,0,4)
                Fill.BorderSizePixel=0; Fill.BackgroundColor3=Color3.fromRGB(255,255,255)
                Fill.Parent=Drag
                local FC = Instance.new('UICorner'); FC.CornerRadius=UDim.new(0,3); FC.Parent=Fill
                local Value = Instance.new('TextLabel')
                Value.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                Value.TextColor3=Color3.fromRGB(255,255,255); Value.TextTransparency=0.2
                Value.Text=tostring(s.value or 0); Value.Size=UDim2.new(0,42,0,13)
                Value.AnchorPoint=Vector2.new(1,0); Value.Position=UDim2.new(1,0,0,0)
                Value.BackgroundTransparency=1; Value.TextXAlignment=Enum.TextXAlignment.Right
                Value.TextSize=10; Value.Parent=SL

                function SM:set(v)
                    local min, max = s.minimum_value or 0, s.maximum_value or 100
                    local pct = math.clamp((v - min) / (max - min), 0, 1)
                    local w = Drag.AbsoluteSize.X > 0 and Drag.AbsoluteSize.X or 207
                    Fill.Size = UDim2.fromOffset(w * pct, 4)
                    if s.round_number then v = math.floor(v) else v = math.floor(v*10)/10 end
                    Value.Text = tostring(v)
                    if s.flag then Library._config._flags[s.flag] = v end
                    if s.callback then s.callback(v) end
                end

                local dragging = false
                local function upd(input)
                    local abs = Drag.AbsolutePosition.X
                    local size = Drag.AbsoluteSize.X > 0 and Drag.AbsoluteSize.X or 207
                    local x = math.clamp((input.Position.X - abs) / size, 0, 1)
                    local min, max = s.minimum_value or 0, s.maximum_value or 100
                    SM:set(min + (max - min) * x)
                end
                Drag.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        upd(i)
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if not dragging then return end
                    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                        upd(i)
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                SM:set(s.value or 0)
                return SM
            end

            function ModuleManager:create_dropdown(s)
                local DM = {_state=false}
                if self._size == 0 then self._size = 11 end
                self._size = self._size + 44
                Options.Size = UDim2.fromOffset(241, self._size)
                if self._state then Module.Size = UDim2.fromOffset(241, 93+self._size) end

                local DD = Instance.new('TextButton')
                DD.Text=''; DD.AutoButtonColor=false; DD.BackgroundTransparency=1
                DD.Size=UDim2.new(0,207,0,39); DD.BorderSizePixel=0; DD.Parent=Options
                local TL = Instance.new('TextLabel')
                TL.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                TL.TextColor3=Color3.fromRGB(255,255,255); TL.TextTransparency=0.2
                TL.Text=s.title or "Dropdown"; TL.Size=UDim2.new(0,207,0,13)
                TL.BackgroundTransparency=1; TL.TextXAlignment=Enum.TextXAlignment.Left
                TL.TextSize=11; TL.Parent=DD
                local Box = Instance.new('Frame')
                Box.ClipsDescendants=true; Box.AnchorPoint=Vector2.new(0.5,0)
                Box.BackgroundTransparency=0.9; Box.Position=UDim2.new(0.5,0,1.2,0)
                Box.Size=UDim2.new(0,207,0,22); Box.BorderSizePixel=0
                Box.BackgroundColor3=Color3.fromRGB(245,245,250); Box.Parent=TL
                local BC = Instance.new('UICorner'); BC.CornerRadius=UDim.new(0,4); BC.Parent=Box
                local Header = Instance.new('Frame')
                Header.AnchorPoint=Vector2.new(0.5,0); Header.BackgroundTransparency=1
                Header.Position=UDim2.new(0.5,0,0,0); Header.Size=UDim2.new(0,207,0,22)
                Header.Parent=Box
                local Current = Instance.new('TextLabel')
                Current.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                Current.TextColor3=Color3.fromRGB(255,255,255); Current.TextTransparency=0.2
                Current.Text = s.options[1] or "None"
                Current.Name='CurrentOption'; Current.Size=UDim2.new(0,161,0,13)
                Current.AnchorPoint=Vector2.new(0,0.5); Current.Position=UDim2.new(0.05,0,0.5,0)
                Current.BackgroundTransparency=1; Current.TextXAlignment=Enum.TextXAlignment.Left
                Current.TextSize=10; Current.Parent=Header
                local Opts = Instance.new('ScrollingFrame')
                Opts.ScrollBarThickness=0; Opts.Name='Options'
                Opts.Size=UDim2.new(0,207,0,0); Opts.BackgroundTransparency=1
                Opts.Position=UDim2.new(0,0,1,0); Opts.CanvasSize=UDim2.new(0,0,0.5,0)
                Opts.AutomaticCanvasSize=Enum.AutomaticSize.XY; Opts.Parent=Box
                local OLL = Instance.new('UIListLayout')
                OLL.SortOrder=Enum.SortOrder.LayoutOrder; OLL.Parent=Opts
                local OPD = Instance.new('UIPadding')
                OPD.PaddingTop=UDim.new(0,-1); OPD.PaddingLeft=UDim.new(0,10); OPD.Parent=Opts

                local current_size = 3
                for i, opt in ipairs(s.options) do
                    if i > (s.maximum_options or 10) then break end
                    local OB = Instance.new('TextButton')
                    OB.FontFace=Font.new('rbxasset://fonts/families/GothamSSm.json',Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
                    OB.TextTransparency=0.6; OB.AnchorPoint=Vector2.new(0,0.5)
                    OB.TextSize=10; OB.Size=UDim2.new(0,186,0,16)
                    OB.TextColor3=Color3.fromRGB(255,255,255); OB.Text=opt
                    OB.AutoButtonColor=false; OB.Name='Option'
                    OB.BackgroundTransparency=1; OB.TextXAlignment=Enum.TextXAlignment.Left
                    OB.Position=UDim2.new(0.05,0,0.342,0); OB.BorderSizePixel=0
                    OB.Parent=Opts

                    OB.MouseButton1Click:Connect(function()
                        Current.Text = opt
                        for _, other in ipairs(Opts:GetChildren()) do
                            if other.Name == "Option" then
                                other.TextTransparency = (other.Text == opt) and 0.2 or 0.6
                            end
                        end
                        if s.flag then Library._config._flags[s.flag] = opt end
                        if s.callback then s.callback(opt) end
                    end)
                    current_size = current_size + 16
                end
                Opts.Size = UDim2.fromOffset(207, current_size)

                DD.MouseButton1Click:Connect(function()
                    DM._state = not DM._state
                    if DM._state then
                        TweenService:Create(DD, TweenInfo.new(0.3), {Size=UDim2.fromOffset(207, 39 + current_size)}):Play()
                        TweenService:Create(Box, TweenInfo.new(0.3), {Size=UDim2.fromOffset(207, 22 + current_size)}):Play()
                    else
                        TweenService:Create(DD, TweenInfo.new(0.3), {Size=UDim2.fromOffset(207, 39)}):Play()
                        TweenService:Create(Box, TweenInfo.new(0.3), {Size=UDim2.fromOffset(207, 22)}):Play()
                    end
                end)
                return DM
            end

            return ModuleManager
        end

        return TabManager
    end

    return self
end

-- ============================================================
-- CREATE LIBRARY + LOAD
-- ============================================================
local library = Library.new()
pcall(function() library:load() end)

-- ============================================================
-- TAB PARRY (yang lu minta) — nempel di UI Azure
-- ============================================================
local Stats_P  = cloneref(game:GetService("Stats"))
local RunSvc_P = cloneref(game:GetService("RunService"))
local WSP      = cloneref(game:GetService("Workspace"))
local Plrs_P   = cloneref(game:GetService("Players"))
local UIS_P    = cloneref(game:GetService("UserInputService"))

_G.ParryAccuracy  = _G.ParryAccuracy  or 50
_G.ParryDivisor   = _G.ParryDivisor   or 1.0
_G.ParryCooldown  = _G.ParryCooldown  or 0.4
_G.ParryCurveMode = _G.ParryCurveMode or 1
_G.ManualSpamCPS  = _G.ManualSpamCPS  or 20
_G.parried        = false
_G.parries        = 0

local function _buildCurve()
    local cam = WSP.CurrentCamera
    local root = Plrs_P.LocalPlayer.Character and Plrs_P.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return cam.CFrame end
    local m = _G.ParryCurveMode
    if m == 1 then return cam.CFrame end
    if m == 7 then return CFrame.new(root.Position, root.Position - cam.CFrame.RightVector*10000) end
    if m == 8 then return CFrame.new(root.Position, root.Position + cam.CFrame.RightVector*10000) end
    return cam.CFrame
end

local function _execParry()
    if not _PARRY_PATCH or not _PARRY_PATCH.ready then return false end
    local cam = WSP.CurrentCamera
    local LP  = Plrs_P.LocalPlayer
    if not LP.Character then return false end
    local sp = {}
    local alive = WSP:FindFirstChild("Alive")
    if alive then
        for _, e in ipairs(alive:GetChildren()) do
            if e.PrimaryPart then
                local ok, s = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok then sp[e.Name] = s end
            end
        end
    end
    local ml = {cam.ViewportSize.X/2, cam.ViewportSize.Y/2}
    if not UIS_P.TouchEnabled then
        local ok, m = pcall(function() return UIS_P:GetMouseLocation() end)
        if ok and m then ml = {m.X, m.Y} end
    end
    return _PARRY_PATCH.fire(_buildCurve(), sp, ml)
end

local ParryTab = library:create_tab("Parry")

local parry_main = ParryTab:create_module({
    title = "Auto Parry",
    description = "Auto parry incoming ball",
    flag = "AutoParryModule",
    section = "left",
    callback = function(state)
        _G.AutoParryEnabled = state
        if state then
         
