local VERSION = "1.0.0"
local DEBUG_MODE = false
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local FOLDER_PATH = "Zenthra/Emotes"
local SETTINGS_FILE = FOLDER_PATH .. "/settings.json"
local EMOTES_FILE = FOLDER_PATH .. "/emotes.json"
local CUSTOM_ANIMS_FILE = FOLDER_PATH .. "/custom_animations.json"
local THEME_FILE = FOLDER_PATH .. "/themes.json"
local HUD_LAYOUT_FILE = FOLDER_PATH .. "/hud_layout.json"

makefolder("Zenthra")
makefolder(FOLDER_PATH)

local ThemeSystem = {}
ThemeSystem.Themes = {
	Default = {
		Name = "Default Dark",
		Primary = Color3.fromRGB(18, 18, 24),
		Secondary = Color3.fromRGB(28, 28, 38),
		Accent = Color3.fromRGB(99, 102, 241),
		AccentGlow = Color3.fromRGB(129, 140, 248),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(140, 140, 160),
		Icon = Color3.fromRGB(200, 200, 220),
		Success = Color3.fromRGB(52, 211, 153),
		Warning = Color3.fromRGB(251, 191, 36),
		Danger = Color3.fromRGB(248, 113, 113),
		WheelCenter = Color3.fromRGB(24, 24, 34),
		WheelSlice = Color3.fromRGB(32, 32, 46),
		WheelHover = Color3.fromRGB(48, 48, 68),
		WheelSelected = Color3.fromRGB(99, 102, 241),
		BackgroundTransparency = 0.15,
		CornerRadius = 12,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
	Cyberpunk = {
		Name = "Cyberpunk",
		Primary = Color3.fromRGB(10, 10, 18),
		Secondary = Color3.fromRGB(20, 20, 35),
		Accent = Color3.fromRGB(255, 0, 85),
		AccentGlow = Color3.fromRGB(255, 50, 120),
		Text = Color3.fromRGB(0, 255, 240),
		SubText = Color3.fromRGB(0, 160, 170),
		Icon = Color3.fromRGB(0, 230, 220),
		Success = Color3.fromRGB(0, 255, 128),
		Warning = Color3.fromRGB(255, 200, 0),
		Danger = Color3.fromRGB(255, 0, 60),
		WheelCenter = Color3.fromRGB(15, 15, 28),
		WheelSlice = Color3.fromRGB(25, 25, 45),
		WheelHover = Color3.fromRGB(45, 20, 60),
		WheelSelected = Color3.fromRGB(255, 0, 85),
		BackgroundTransparency = 0.1,
		CornerRadius = 4,
		Font = Enum.Font.Code,
		FontBold = Enum.Font.Code,
	},
	Midnight = {
		Name = "Midnight Purple",
		Primary = Color3.fromRGB(15, 12, 25),
		Secondary = Color3.fromRGB(25, 20, 40),
		Accent = Color3.fromRGB(147, 51, 234),
		AccentGlow = Color3.fromRGB(168, 85, 247),
		Text = Color3.fromRGB(243, 232, 255),
		SubText = Color3.fromRGB(168, 145, 200),
		Icon = Color3.fromRGB(216, 180, 254),
		Success = Color3.fromRGB(74, 222, 128),
		Warning = Color3.fromRGB(250, 204, 21),
		Danger = Color3.fromRGB(248, 113, 113),
		WheelCenter = Color3.fromRGB(20, 16, 33),
		WheelSlice = Color3.fromRGB(30, 24, 48),
		WheelHover = Color3.fromRGB(50, 38, 78),
		WheelSelected = Color3.fromRGB(147, 51, 234),
		BackgroundTransparency = 0.12,
		CornerRadius = 14,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
	Emerald = {
		Name = "Emerald City",
		Primary = Color3.fromRGB(10, 22, 18),
		Secondary = Color3.fromRGB(18, 36, 30),
		Accent = Color3.fromRGB(16, 185, 129),
		AccentGlow = Color3.fromRGB(52, 211, 153),
		Text = Color3.fromRGB(236, 253, 245),
		SubText = Color3.fromRGB(110, 175, 150),
		Icon = Color3.fromRGB(167, 243, 208),
		Success = Color3.fromRGB(52, 211, 153),
		Warning = Color3.fromRGB(251, 191, 36),
		Danger = Color3.fromRGB(248, 113, 113),
		WheelCenter = Color3.fromRGB(14, 28, 23),
		WheelSlice = Color3.fromRGB(22, 44, 36),
		WheelHover = Color3.fromRGB(32, 64, 52),
		WheelSelected = Color3.fromRGB(16, 185, 129),
		BackgroundTransparency = 0.15,
		CornerRadius = 10,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
	Sunset = {
		Name = "Sunset Warm",
		Primary = Color3.fromRGB(24, 16, 18),
		Secondary = Color3.fromRGB(38, 24, 28),
		Accent = Color3.fromRGB(249, 115, 22),
		AccentGlow = Color3.fromRGB(251, 146, 60),
		Text = Color3.fromRGB(255, 247, 237),
		SubText = Color3.fromRGB(195, 150, 140),
		Icon = Color3.fromRGB(253, 186, 116),
		Success = Color3.fromRGB(52, 211, 153),
		Warning = Color3.fromRGB(251, 191, 36),
		Danger = Color3.fromRGB(239, 68, 68),
		WheelCenter = Color3.fromRGB(30, 20, 22),
		WheelSlice = Color3.fromRGB(44, 28, 32),
		WheelHover = Color3.fromRGB(64, 38, 42),
		WheelSelected = Color3.fromRGB(249, 115, 22),
		BackgroundTransparency = 0.15,
		CornerRadius = 12,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
	CleanLight = {
		Name = "Clean Light",
		Primary = Color3.fromRGB(245, 245, 250),
		Secondary = Color3.fromRGB(230, 230, 238),
		Accent = Color3.fromRGB(79, 70, 229),
		AccentGlow = Color3.fromRGB(99, 102, 241),
		Text = Color3.fromRGB(30, 30, 45),
		SubText = Color3.fromRGB(100, 100, 120),
		Icon = Color3.fromRGB(60, 60, 80),
		Success = Color3.fromRGB(16, 185, 129),
		Warning = Color3.fromRGB(217, 119, 6),
		Danger = Color3.fromRGB(225, 29, 72),
		WheelCenter = Color3.fromRGB(238, 238, 244),
		WheelSlice = Color3.fromRGB(222, 222, 232),
		WheelHover = Color3.fromRGB(200, 200, 218),
		WheelSelected = Color3.fromRGB(79, 70, 229),
		BackgroundTransparency = 0.05,
		CornerRadius = 12,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
}

ThemeSystem.CurrentTheme = "Default"
ThemeSystem.CustomThemes = {}
ThemeSystem.Listeners = {}

function ThemeSystem.GetColor(key)
	local activeTheme = ThemeSystem.CustomThemes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes.Default
	return activeTheme[key] or ThemeSystem.Themes.Default[key]
end

function ThemeSystem.GetFont(bold)
	local activeTheme = ThemeSystem.CustomThemes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes.Default
	if bold then
		return activeTheme.FontBold or ThemeSystem.Themes.Default.FontBold
	end
	return activeTheme.Font or ThemeSystem.Themes.Default.Font
end

function ThemeSystem.GetRadius()
	local activeTheme = ThemeSystem.CustomThemes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes[ThemeSystem.CurrentTheme] or ThemeSystem.Themes.Default
	return UDim.new(0, activeTheme.CornerRadius or 12)
end

function ThemeSystem.RegisterListener(callback)
	table.insert(ThemeSystem.Listeners, callback)
end

function ThemeSystem.SetTheme(themeName)
	if ThemeSystem.Themes[themeName] or ThemeSystem.CustomThemes[themeName] then
		ThemeSystem.CurrentTheme = themeName
		for _, cb in ipairs(ThemeSystem.Listeners) do
			pcall(cb)
		end
		return true
	end
	return false
end

function ThemeSystem.AddCustomTheme(name, themeData)
	ThemeSystem.CustomThemes[name] = themeData
	ThemeSystem.SaveCustomThemes()
end

function ThemeSystem.SaveCustomThemes()
	local serializable = {}
	for name, theme in pairs(ThemeSystem.CustomThemes) do
		local t = {}
		for k, v in pairs(theme) do
			if typeof(v) == "Color3" then
				t[k] = { r = v.R, g = v.G, b = v.B, _type = "Color3" }
			elseif typeof(v) == "EnumItem" then
				t[k] = { name = v.Name, _type = "Enum" }
			else
				t[k] = v
			end
		end
		serializable[name] = t
	end
	writefile(THEME_FILE, HttpService:JSONEncode(serializable))
end

function ThemeSystem.LoadCustomThemes()
	if isfile(THEME_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(THEME_FILE))
		end)
		if success and type(result) == "table" then
			for name, theme in pairs(result) do
				local t = {}
				for k, v in pairs(theme) do
					if type(v) == "table" and v._type == "Color3" then
						t[k] = Color3.new(v.r, v.g, v.b)
					elseif type(v) == "table" and v._type == "Enum" then
						t[k] = Enum.Font[v.name] or Enum.Font.GothamMedium
					else
						t[k] = v
					end
				end
				ThemeSystem.CustomThemes[name] = t
			end
		end
	end
end

ThemeSystem.LoadCustomThemes()

local AnimationSystem = {}
AnimationSystem.PlayingTrack = nil
AnimationSystem.CurrentEmoteName = nil
AnimationSystem.OriginalAnims = {}
AnimationSystem.CustomAnims = {}
AnimationSystem.EmoteSpeed = 1.0
AnimationSystem.EmoteLoop = true
AnimationSystem.EmotesWalkEnabled = false
AnimationSystem.RandomMode = "Off"
AnimationSystem.FavoriteEmotes = {}

local DEFAULT_OFFSALE_EMOTES = {
	{ Name = "Stadium", Id = "rbxassetid://333798531", Icon = "rbxassetid://10714246237" },
	{ Name = "Tilt", Id = "rbxassetid://333798835", Icon = "rbxassetid://10714246237" },
	{ Name = "Shrug", Id = "rbxassetid://333799275", Icon = "rbxassetid://10714246237" },
	{ Name = "Point", Id = "rbxassetid://333799632", Icon = "rbxassetid://10714246237" },
	{ Name = "Salute", Id = "rbxassetid://333800004", Icon = "rbxassetid://10714246237" },
	{ Name = "Wave", Id = "rbxassetid://128777973", Icon = "rbxassetid://10714246237" },
	{ Name = "Cheer", Id = "rbxassetid://128777973", Icon = "rbxassetid://10714246237" },
	{ Name = "Laugh", Id = "rbxassetid://129423131", Icon = "rbxassetid://10714246237" },
	{ Name = "Dance1", Id = "rbxassetid://182435998", Icon = "rbxassetid://10714246237" },
	{ Name = "Dance2", Id = "rbxassetid://182436842", Icon = "rbxassetid://10714246237" },
	{ Name = "Dance3", Id = "rbxassetid://182436935", Icon = "rbxassetid://10714246237" },
}

function AnimationSystem.Init()
	AnimationSystem.LoadFavorites()
	AnimationSystem.LoadCustomAnimations()
end

function AnimationSystem.PlayEmote(animId, name)
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	AnimationSystem.StopEmote()

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local track = humanoid:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = AnimationSystem.EmoteLoop
	track:Play(0.1, 1, AnimationSystem.EmoteSpeed)

	AnimationSystem.PlayingTrack = track
	AnimationSystem.CurrentEmoteName = name or "Unknown"

	if not AnimationSystem.EmotesWalkEnabled then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
		end
	end
end

function AnimationSystem.StopEmote()
	if AnimationSystem.PlayingTrack then
		AnimationSystem.PlayingTrack:Stop(0.1)
		AnimationSystem.PlayingTrack:Destroy()
		AnimationSystem.PlayingTrack = nil
		AnimationSystem.CurrentEmoteName = nil
	end
end

function AnimationSystem.SetSpeed(speed)
	AnimationSystem.EmoteSpeed = math.clamp(speed, 0.1, 5.0)
	if AnimationSystem.PlayingTrack then
		AnimationSystem.PlayingTrack:AdjustSpeed(AnimationSystem.EmoteSpeed)
	end
end

function AnimationSystem.SetLoop(loop)
	AnimationSystem.EmoteLoop = loop
	if AnimationSystem.PlayingTrack then
		AnimationSystem.PlayingTrack.Looped = loop
	end
end

function AnimationSystem.SaveFavorites()
	writefile(EMOTES_FILE, HttpService:JSONEncode(AnimationSystem.FavoriteEmotes))
end

function AnimationSystem.LoadFavorites()
	if isfile(EMOTES_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONEncode(readfile(EMOTES_FILE))
		end)
		if success and type(result) == "table" then
			AnimationSystem.FavoriteEmotes = result
		end
	end
end

function AnimationSystem.ToggleFavorite(emoteData)
	for i, fav in ipairs(AnimationSystem.FavoriteEmotes) do
		if fav.Id == emoteData.Id then
			table.remove(AnimationSystem.FavoriteEmotes, i)
			AnimationSystem.SaveFavorites()
			return false
		end
	end
	table.insert(AnimationSystem.FavoriteEmotes, emoteData)
	AnimationSystem.SaveFavorites()
	return true
end

function AnimationSystem.IsFavorite(animId)
	for _, fav in ipairs(AnimationSystem.FavoriteEmotes) do
		if fav.Id == animId then
			return true
		end
	end
	return false
end

function AnimationSystem.SaveCustomAnimations()
	writefile(CUSTOM_ANIMS_FILE, HttpService:JSONEncode(AnimationSystem.CustomAnims))
end

function AnimationSystem.LoadCustomAnimations()
	if isfile(CUSTOM_ANIMS_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(CUSTOM_ANIMS_FILE))
		end)
		if success and type(result) == "table" then
			AnimationSystem.CustomAnims = result
		end
	end
end

function AnimationSystem.ApplyCustomAnimation(animType, animId)
	AnimationSystem.CustomAnims[animType] = animId
	AnimationSystem.SaveCustomAnimations()

	local char = LocalPlayer.Character
	if not char then return end
	local animate = char:FindFirstChild("Animate")
	if not animate then return end

	local targetFolder = animate:FindFirstChild(animType)
	if targetFolder then
		for _, child in ipairs(targetFolder:GetChildren()) do
			if child:IsA("Animation") then
				if not AnimationSystem.OriginalAnims[animType] then
					AnimationSystem.OriginalAnims[animType] = child.AnimationId
				end
				child.AnimationId = animId
			end
		end
	end
end

function AnimationSystem.ResetCustomAnimation(animType)
	if AnimationSystem.OriginalAnims[animType] then
		local char = LocalPlayer.Character
		if char then
			local animate = char:FindFirstChild("Animate")
			if animate then
				local targetFolder = animate:FindFirstChild(animType)
				if targetFolder then
					for _, child in ipairs(targetFolder:GetChildren()) do
						if child:IsA("Animation") then
							child.AnimationId = AnimationSystem.OriginalAnims[animType]
						end
					end
				end
			end
		end
		AnimationSystem.CustomAnims[animType] = nil
		AnimationSystem.SaveCustomAnimations()
	end
end

function AnimationSystem.ParseGifInfo(gifUrl)
	return {
		Url = gifUrl,
		Frames = 30,
		FPS = 15,
		GridX = 6,
		GridY = 5,
		FrameWidth = 100,
		FrameHeight = 100,
	}
end

function AnimationSystem.ParsePngInfo(pngUrl, gridX, gridY, totalFrames)
	return {
		Url = pngUrl,
		Frames = totalFrames or (gridX * gridY),
		FPS = 24,
		GridX = gridX or 4,
		GridY = gridY or 4,
	}
end

function AnimationSystem.CreateGifAnimator(imageLabel, gifInfo)
	local currentFrame = 0
	local connection = nil
	local timer = 0
	local frameDuration = 1 / (gifInfo.FPS or 15)

	local function updateFrame()
		local col = currentFrame % gifInfo.GridX
		local row = math.floor(currentFrame / gifInfo.GridX)

		imageLabel.ImageRectOffset = Vector2.new(col * gifInfo.FrameWidth, row * gifInfo.FrameHeight)
		imageLabel.ImageRectSize = Vector2.new(gifInfo.FrameWidth, gifInfo.FrameHeight)
	end

	imageLabel.Image = gifInfo.Url

	local animator = {}

	function animator:Start()
		if connection then connection:Disconnect() end
		timer = 0
		connection = RunService.RenderStepped:Connect(function(dt)
			timer = timer + dt
			if timer >= frameDuration then
				timer = timer - frameDuration
				currentFrame = (currentFrame + 1) % gifInfo.Frames
				updateFrame()
			end
		end)
	end

	function animator:Stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	return animator
end

local HUDSystem = {}
HUDSystem.Pages = {}
HUDSystem.CurrentPage = 1
HUDSystem.ItemsPerPage = 8
HUDSystem.LayoutConfig = {}
HUDSystem.IsEditingHUD = false

function HUDSystem.LoadLayout()
	if isfile(HUD_LAYOUT_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(HUD_LAYOUT_FILE))
		end)
		if success and type(result) == "table" then
			HUDSystem.LayoutConfig = result
		end
	end
end

function HUDSystem.SaveLayout()
	writefile(HUD_LAYOUT_FILE, HttpService:JSONEncode(HUDSystem.LayoutConfig))
end

HUDSystem.LoadLayout()

local UIBuilder = {}

function UIBuilder.CreateCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or ThemeSystem.GetRadius()
	corner.Parent = parent
	return corner
end

function UIBuilder.CreateStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or ThemeSystem.GetColor("Accent")
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UIBuilder.CreateGradient(parent, colorSequence, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	gradient.Rotation = rotation or 45
	gradient.Parent = parent
	return gradient
end

function UIBuilder.CreateButton(parent, props)
	local btn = Instance.new("TextButton")
	btn.Size = props.Size or UDim2.new(0, 100, 0, 36)
	btn.Position = props.Position or UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = props.BackgroundColor3 or ThemeSystem.GetColor("Secondary")
	btn.Text = props.Text or ""
	btn.TextColor3 = props.TextColor3 or ThemeSystem.GetColor("Text")
	btn.Font = props.Font or ThemeSystem.GetFont(false)
	btn.TextSize = props.TextSize or 14
	btn.AutoButtonColor = false
	btn.Parent = parent

	UIBuilder.CreateCorner(btn, props.CornerRadius)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = ThemeSystem.GetColor("Accent") }):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = props.BackgroundColor3 or ThemeSystem.GetColor("Secondary") }):Play()
	end)

	return btn
end

local MainGUI = {}

function MainGUI.Init()
	AnimationSystem.Init()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZenthraEmotesGUI"
	screenGui.ResetOnSpawn = false

	if syn and syn.protect_gui then
		syn.protect_gui(screenGui)
		screenGui.Parent = game:GetService("CoreGui")
	elseif gethui then
		screenGui.Parent = gethui()
	else
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	MainGUI.ScreenGui = screenGui
	MainGUI.BuildMainLayout()
end

function MainGUI.BuildMainLayout()
	local screenGui = MainGUI.ScreenGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainContainer"
	mainFrame.Size = UDim2.new(0, 720, 0, 480)
	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
	mainFrame.BackgroundColor3 = ThemeSystem.GetColor("Primary")
	mainFrame.BackgroundTransparency = ThemeSystem.GetColor("BackgroundTransparency") or 0.15
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	UIBuilder.CreateCorner(mainFrame)
	UIBuilder.CreateStroke(mainFrame, ThemeSystem.GetColor("Accent"), 1.5)

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
	topBar.Parent = mainFrame

	UIBuilder.CreateCorner(topBar)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 200, 1, 0)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.Text = "ZENTHRA v" .. VERSION
	title.TextColor3 = ThemeSystem.GetColor("Accent")
	title.Font = ThemeSystem.GetFont(true)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1
	title.Parent = topBar

	local navContainer = Instance.new("Frame")
	navContainer.Name = "NavContainer"
	navContainer.Size = UDim2.new(0, 360, 1, -12)
	navContainer.Position = UDim2.new(1, -370, 0, 6)
	navContainer.BackgroundTransparency = 1
	navContainer.Parent = topBar

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Padding = UDim.new(0, 8)
	navLayout.Parent = navContainer

	local tabs = { "Emotes", "Wheel", "Animations", "Themes", "Settings" }
	MainGUI.TabButtons = {}
	MainGUI.TabFrames = {}

	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -24, 1, -80)
	contentArea.Position = UDim2.new(0, 12, 0, 60)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainFrame

	for i, tabName in ipairs(tabs) do
		local tabBtn = UIBuilder.CreateButton(navContainer, {
			Size = UDim2.new(0, 64, 1, 0),
			Text = tabName,
			TextSize = 12,
			BackgroundColor3 = ThemeSystem.GetColor("Primary"),
		})
		MainGUI.TabButtons[tabName] = tabBtn

		local tabFrame = Instance.new("Frame")
		tabFrame.Name = tabName .. "Frame"
		tabFrame.Size = UDim2.new(1, 0, 1, 0)
		tabFrame.BackgroundTransparency = 1
		tabFrame.Visible = (i == 1)
		tabFrame.Parent = contentArea
		MainGUI.TabFrames[tabName] = tabFrame

		tabBtn.MouseButton1Click:Connect(function()
			for _, tf in pairs(MainGUI.TabFrames) do tf.Visible = false end
			for _, tb in pairs(MainGUI.TabButtons) do
				tb.BackgroundColor3 = ThemeSystem.GetColor("Primary")
			end
			tabFrame.Visible = true
			tabBtn.BackgroundColor3 = ThemeSystem.GetColor("Accent")
		end)
	end

	MainGUI.BuildEmotesTab(MainGUI.TabFrames["Emotes"])
	MainGUI.BuildWheelTab(MainGUI.TabFrames["Wheel"])
	MainGUI.BuildAnimationsTab(MainGUI.TabFrames["Animations"])
	MainGUI.BuildThemesTab(MainGUI.TabFrames["Themes"])
	MainGUI.BuildSettingsTab(MainGUI.TabFrames["Settings"])

	ThemeSystem.RegisterListener(function()
		mainFrame.BackgroundColor3 = ThemeSystem.GetColor("Primary")
		topBar.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
		title.TextColor3 = ThemeSystem.GetColor("Accent")
		title.Font = ThemeSystem.GetFont(true)
	end)
end

function MainGUI.BuildEmotesTab(parent)
	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -120, 0, 36)
	searchBox.Position = UDim2.new(0, 0, 0, 0)
	searchBox.PlaceholderText = "Search emotes..."
	searchBox.Text = ""
	searchBox.TextColor3 = ThemeSystem.GetColor("Text")
	searchBox.PlaceholderColor3 = ThemeSystem.GetColor("SubText")
	searchBox.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
	searchBox.Font = ThemeSystem.GetFont(false)
	searchBox.TextSize = 14
	searchBox.Parent = parent

	UIBuilder.CreateCorner(searchBox)

	local filterFavBtn = UIBuilder.CreateButton(parent, {
		Size = UDim2.new(0, 110, 0, 36),
		Position = UDim2.new(1, -110, 0, 0),
		Text = "Favorites Only",
		TextSize = 11,
	})

	local scrollGrid = Instance.new("ScrollingFrame")
	scrollGrid.Size = UDim2.new(1, 0, 1, -48)
	scrollGrid.Position = UDim2.new(0, 0, 0, 48)
	scrollGrid.BackgroundTransparency = 1
	scrollGrid.ScrollBarThickness = 4
	scrollGrid.ScrollBarImageColor3 = ThemeSystem.GetColor("Accent")
	scrollGrid.Parent = parent

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 128, 0, 128)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.Name
	gridLayout.Parent = scrollGrid

	local favoritesOnly = false

	local function populateEmotes(filterText)
		for _, child in ipairs(scrollGrid:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		for _, emote in ipairs(DEFAULT_OFFSALE_EMOTES) do
			local matchesSearch = filterText == "" or string.find(string.lower(emote.Name), string.lower(filterText))
			local isFav = AnimationSystem.IsFavorite(emote.Id)

			if matchesSearch and (not favoritesOnly or isFav) then
				local card = Instance.new("Frame")
				card.Name = emote.Name
				card.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
				card.Parent = scrollGrid

				UIBuilder.CreateCorner(card)

				local icon = Instance.new("ImageLabel")
				icon.Size = UDim2.new(1, -16, 1, -40)
				icon.Position = UDim2.new(0, 8, 0, 8)
				icon.Image = emote.Icon
				icon.BackgroundTransparency = 1
				icon.Parent = card

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, 0, 0, 24)
				nameLabel.Position = UDim2.new(0, 0, 1, -24)
				nameLabel.Text = emote.Name
				nameLabel.TextColor3 = ThemeSystem.GetColor("Text")
				nameLabel.Font = ThemeSystem.GetFont(false)
				nameLabel.TextSize = 12
				nameLabel.BackgroundTransparency = 1
				nameLabel.Parent = card

				local playBtn = Instance.new("TextButton")
				playBtn.Size = UDim2.new(1, 0, 1, 0)
				playBtn.BackgroundTransparency = 1
				playBtn.Text = ""
				playBtn.Parent = card

				playBtn.MouseButton1Click:Connect(function()
					AnimationSystem.PlayEmote(emote.Id, emote.Name)
				end)

				local favBtn = Instance.new("TextButton")
				favBtn.Size = UDim2.new(0, 24, 0, 24)
				favBtn.Position = UDim2.new(1, -28, 0, 4)
				favBtn.Text = isFav and "★" or "☆"
				favBtn.TextColor3 = isFav and Color3.fromRGB(255, 200, 0) or ThemeSystem.GetColor("SubText")
				favBtn.BackgroundTransparency = 1
				favBtn.Font = ThemeSystem.GetFont(true)
				favBtn.TextSize = 16
				favBtn.Parent = card

				favBtn.MouseButton1Click:Connect(function()
					local nowFav = AnimationSystem.ToggleFavorite(emote)
					favBtn.Text = nowFav and "★" or "☆"
					favBtn.TextColor3 = nowFav and Color3.fromRGB(255, 200, 0) or ThemeSystem.GetColor("SubText")
				end)
			end
		end

		scrollGrid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		populateEmotes(searchBox.Text)
	end)

	filterFavBtn.MouseButton1Click:Connect(function()
		favoritesOnly = not favoritesOnly
		filterFavBtn.BackgroundColor3 = favoritesOnly and ThemeSystem.GetColor("Accent") or ThemeSystem.GetColor("Secondary")
		populateEmotes(searchBox.Text)
	end)

	populateEmotes("")
end

function MainGUI.BuildWheelTab(parent)
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0, 40)
	infoLabel.Text = "Emote Wheel Customizer & Preview"
	infoLabel.TextColor3 = ThemeSystem.GetColor("Text")
	infoLabel.Font = ThemeSystem.GetFont(true)
	infoLabel.TextSize = 16
	infoLabel.BackgroundTransparency = 1
	infoLabel.Parent = parent

	local wheelFrame = Instance.new("Frame")
	wheelFrame.Size = UDim2.new(0, 280, 0, 280)
	wheelFrame.Position = UDim2.new(0.5, -140, 0.5, -120)
	wheelFrame.BackgroundColor3 = ThemeSystem.GetColor("WheelCenter")
	wheelFrame.Parent = parent

	UIBuilder.CreateCorner(wheelFrame, UDim.new(1, 0))
	UIBuilder.CreateStroke(wheelFrame, ThemeSystem.GetColor("Accent"), 2)

	local slicesCount = 8
	for i = 1, slicesCount do
		local angle = (i - 1) * (360 / slicesCount)
		local rad = math.rad(angle)
		local x = math.cos(rad) * 100
		local y = math.sin(rad) * 100

		local sliceBtn = Instance.new("TextButton")
		sliceBtn.Size = UDim2.new(0, 48, 0, 48)
		sliceBtn.Position = UDim2.new(0.5, x - 24, 0.5, y - 24)
		sliceBtn.BackgroundColor3 = ThemeSystem.GetColor("WheelSlice")
		sliceBtn.Text = tostring(i)
		sliceBtn.TextColor3 = ThemeSystem.GetColor("Text")
		sliceBtn.Font = ThemeSystem.GetFont(true)
		sliceBtn.TextSize = 14
		sliceBtn.Parent = wheelFrame

		UIBuilder.CreateCorner(sliceBtn, UDim.new(1, 0))

		sliceBtn.MouseEnter:Connect(function()
			sliceBtn.BackgroundColor3 = ThemeSystem.GetColor("WheelHover")
		end)
		sliceBtn.MouseLeave:Connect(function()
			sliceBtn.BackgroundColor3 = ThemeSystem.GetColor("WheelSlice")
		end)
	end
end

function MainGUI.BuildAnimationsTab(parent)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = parent

	local animTypes = { "walk", "run", "jump", "idle", "swim", "fall" }

	for _, animType in ipairs(animTypes) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
		row.Parent = parent

		UIBuilder.CreateCorner(row)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 100, 1, 0)
		label.Position = UDim2.new(0, 12, 0, 0)
		label.Text = string.upper(animType)
		label.TextColor3 = ThemeSystem.GetColor("Text")
		label.Font = ThemeSystem.GetFont(true)
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.BackgroundTransparency = 1
		label.Parent = row

		local input = Instance.new("TextBox")
		input.Size = UDim2.new(1, -260, 0, 28)
		input.Position = UDim2.new(0, 110, 0.5, -14)
		input.PlaceholderText = "rbxassetid://..."
		input.Text = AnimationSystem.CustomAnims[animType] or ""
		input.TextColor3 = ThemeSystem.GetColor("Text")
		input.BackgroundColor3 = ThemeSystem.GetColor("Primary")
		input.Font = ThemeSystem.GetFont(false)
		input.TextSize = 12
		input.Parent = row

		UIBuilder.CreateCorner(input)

		local applyBtn = UIBuilder.CreateButton(row, {
			Size = UDim2.new(0, 60, 0, 28),
			Position = UDim2.new(1, -140, 0.5, -14),
			Text = "Apply",
			TextSize = 11,
		})

		local resetBtn = UIBuilder.CreateButton(row, {
			Size = UDim2.new(0, 60, 0, 28),
			Position = UDim2.new(1, -72, 0.5, -14),
			Text = "Reset",
			TextSize = 11,
			BackgroundColor3 = ThemeSystem.GetColor("Danger"),
		})

		applyBtn.MouseButton1Click:Connect(function()
			if input.Text ~= "" then
				AnimationSystem.ApplyCustomAnimation(animType, input.Text)
			end
		end)

		resetBtn.MouseButton1Click:Connect(function()
			input.Text = ""
			AnimationSystem.ResetCustomAnimation(animType)
		end)
	end
end

function MainGUI.BuildThemesTab(parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -50)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 160, 0, 80)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.Parent = scroll

	local function refreshThemes()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		local allThemes = {}
		for k, v in pairs(ThemeSystem.Themes) do allThemes[k] = v end
		for k, v in pairs(ThemeSystem.CustomThemes) do allThemes[k] = v end

		for key, themeData in pairs(allThemes) do
			local card = Instance.new("Frame")
			card.BackgroundColor3 = themeData.Primary or ThemeSystem.GetColor("Secondary")
			card.Parent = scroll

			UIBuilder.CreateCorner(card)
			UIBuilder.CreateStroke(card, themeData.Accent or ThemeSystem.GetColor("Accent"), 1)

			local nameBtn = Instance.new("TextButton")
			nameBtn.Size = UDim2.new(1, 0, 1, 0)
			nameBtn.BackgroundTransparency = 1
			nameBtn.Text = themeData.Name or key
			nameBtn.TextColor3 = themeData.Text or Color3.new(1, 1, 1)
			nameBtn.Font = themeData.Font or Enum.Font.GothamMedium
			nameBtn.TextSize = 13
			nameBtn.Parent = card

			nameBtn.MouseButton1Click:Connect(function()
				ThemeSystem.SetTheme(key)
			end)
		end
	end

	refreshThemes()
end

function MainGUI.BuildSettingsTab(parent)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = parent

	local speedRow = Instance.new("Frame")
	speedRow.Size = UDim2.new(1, 0, 0, 44)
	speedRow.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
	speedRow.Parent = parent
	UIBuilder.CreateCorner(speedRow)

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(0, 140, 1, 0)
	speedLabel.Position = UDim2.new(0, 12, 0, 0)
	speedLabel.Text = "Emote Speed: 1.0x"
	speedLabel.TextColor3 = ThemeSystem.GetColor("Text")
	speedLabel.Font = ThemeSystem.GetFont(true)
	speedLabel.TextSize = 13
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.BackgroundTransparency = 1
	speedLabel.Parent = speedRow

	local speedSlider = Instance.new("TextBox")
	speedSlider.Size = UDim2.new(0, 80, 0, 28)
	speedSlider.Position = UDim2.new(1, -92, 0.5, -14)
	speedSlider.Text = "1.0"
	speedSlider.TextColor3 = ThemeSystem.GetColor("Text")
	speedSlider.BackgroundColor3 = ThemeSystem.GetColor("Primary")
	speedSlider.Font = ThemeSystem.GetFont(false)
	speedSlider.TextSize = 12
	speedSlider.Parent = speedRow
	UIBuilder.CreateCorner(speedSlider)

	speedSlider.FocusLost:Connect(function()
		local val = tonumber(speedSlider.Text)
		if val then
			AnimationSystem.SetSpeed(val)
			speedLabel.Text = string.format("Emote Speed: %.1fx", AnimationSystem.EmoteSpeed)
		end
	end)

	local walkRow = Instance.new("Frame")
	walkRow.Size = UDim2.new(1, 0, 0, 44)
	walkRow.BackgroundColor3 = ThemeSystem.GetColor("Secondary")
	walkRow.Parent = parent
	UIBuilder.CreateCorner(walkRow)

	local walkLabel = Instance.new("TextLabel")
	walkLabel.Size = UDim2.new(0, 200, 1, 0)
	walkLabel.Position = UDim2.new(0, 12, 0, 0)
	walkLabel.Text = "Allow Walking While Emoting"
	walkLabel.TextColor3 = ThemeSystem.GetColor("Text")
	walkLabel.Font = ThemeSystem.GetFont(true)
	walkLabel.TextSize = 13
	walkLabel.TextXAlignment = Enum.TextXAlignment.Left
	walkLabel.BackgroundTransparency = 1
	walkLabel.Parent = walkRow

	local walkToggle = UIBuilder.CreateButton(walkRow, {
		Size = UDim2.new(0, 80, 0, 28),
		Position = UDim2.new(1, -92, 0.5, -14),
		Text = "OFF",
		TextSize = 11,
	})

	walkToggle.MouseButton1Click:Connect(function()
		AnimationSystem.EmotesWalkEnabled = not AnimationSystem.EmotesWalkEnabled
		walkToggle.Text = AnimationSystem.EmotesWalkEnabled and "ON" or "OFF"
		walkToggle.BackgroundColor3 = AnimationSystem.EmotesWalkEnabled and ThemeSystem.GetColor("Success") or ThemeSystem.GetColor("Secondary")
	end)
end

MainGUI.Init()
