--[[
    Oxy Premium (Rebuild)
    Style: Private / Allusive-like
    Requires: Fluent (or replace with your loader)
]]

--=============================================================
-- [0] ENVIRONMENT GUARD
--=============================================================
if _G.OxyPremiumLoaded then return end
_G.OxyPremiumLoaded = true

local cloneref = cloneref or function(x) return x end
local Players  = cloneref(game:GetService("Players"))
local Run      = cloneref(game:GetService("RunService"))
local UIS      = cloneref(game:GetService("UserInputService"))
local Stats    = cloneref(game:GetService("Stats"))
local RS       = cloneref(game:GetService("ReplicatedStorage"))
local WS       = cloneref(game:GetService("Workspace"))
local Tween    = cloneref(game:GetService("TweenService"))
local Http     = cloneref(game:GetService("HttpService"))

local LP       = Players.LocalPlayer
local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
local preSim   = Run.PreSimulation
local postSim  = Run.PostSimulation

--=============================================================
-- [1] CONFIG STORAGE
--=============================================================
local CONFIG_DIR = "oxy_premium"
local CONFIG_PATH = CONFIG_DIR .. "/config.json"

local defaults = {
    accuracy            = 100,
    spam_threshold      = 3,
    curve_method        = "camera",
    curve_keybind       = false,
    manual_spam_key     = "E",
    auto_parry          = false,
    auto_spam           = false,
    triggerbot          = false,
    random_target       = false,
    ability_esp         = false,
    manual_notify       = false,
    mobile_trigger_btn  = false,
    mobile_manual_btn   = false,
    unlock_all          = false,
    fflag_profile       = "default",
    fflag_json          = "",
}

local Config = {}
for k, v in pairs(defaults) do Config[k] = v end

local function ensureFolder()
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(CONFIG_DIR) then pcall(makefolder, CONFIG_DIR) end
    end
end

local function saveConfig()
    if type(writefile) ~= "function" then return end
    ensureFolder()
    pcall(function()
        writefile(CONFIG_PATH, Http:JSONEncode(Config))
    end)
end

local function loadConfig()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    if not isfile(CONFIG_PATH) then return end
    pcall(function()
        local data = Http:JSONDecode(readfile(CONFIG_PATH))
        for k in pairs(defaults) do
            if data[k] ~= nil then Config[k] = data[k] end
        end
    end)
end
loadConfig()

-- autosave loop
task.spawn(function()
    while _G.OxyPremiumLoaded do
        task.wait(1)
        saveConfig()
    end
end)

--=============================================================
-- [2] PRIVATE UI — SPLASH + KEY SYSTEM + MAIN WINDOW
--=============================================================
local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()

-- -------- Splash Screen (private-style) --------
local function showSplash()
    local gui = Instance.new("ScreenGui")
    gui.Name = "OxySplash"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = LP:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 400, 0, 60)
    title.Position = UDim2.new(0.5, -200, 0.5, -30)
    title.BackgroundTransparency = 1
    title.Text = "OXY  •  PREMIUM"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 38
    title.TextColor3 = Color3.fromRGB(230, 230, 235)
    title.TextTransparency = 1
    title.Parent = bg

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(0, 400, 0, 24)
    sub.Position = UDim2.new(0.5, -200, 0.5, 30)
    sub.BackgroundTransparency = 1
    sub.Text = "loading private modules..."
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 14
    sub.TextColor3 = Color3.fromRGB(120, 120, 130)
    sub.TextTransparency = 1
    sub.Parent = bg

    Tween:Create(title, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
    Tween:Create(sub,   TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.2),
        { TextTransparency = 0 }):Play()

    task.wait(2)
    Tween:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
    Tween:Create(title, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
    Tween:Create(sub,   TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
    task.wait(0.5)
    gui:Destroy()
end
showSplash()

-- -------- Key System (هيكل جاهز، حط endpoint حقيقي) --------
local KEY_API = "https://your-server.example/api/validate" -- <<< عدّلها
local SAVED_KEY_FILE = CONFIG_DIR .. "/key.txt"

local function validateKey(key)
    if not key or #key < 6 then return false, "key too short" end
    -- بدون سيرفر: قبول أي مفتاح بصيغة OXY-XXXX
    if key:match("^OXY%-%w+$") then return true end
    -- مع سيرفر حقيقي:
    --[[
    local ok, res = pcall(function()
        return Http:JSONDecode(game:HttpGet(KEY_API .. "?key=" .. Http:UrlEncode(key)))
    end)
    if ok and res.valid then return true end
    return false, "invalid key"
    ]]
    return false, "invalid key format (OXY-XXXXX)"
end

local function promptKey()
    local gui = Instance.new("ScreenGui")
    gui.Name = "OxyKey"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    gui.Parent = LP:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(360, 200)
    frame.Position = UDim2.new(0.5, -180, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(45, 45, 55)
    stroke.Thickness = 1

    local t = Instance.new("TextLabel", frame)
    t.Size = UDim2.new(1, 0, 0, 40)
    t.Position = UDim2.fromOffset(0, 15)
    t.BackgroundTransparency = 1
    t.Text = "ENTER KEY"
    t.Font = Enum.Font.GothamBold
    t.TextSize = 18
    t.TextColor3 = Color3.fromRGB(230, 230, 235)

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(1, -40, 0, 36)
    box.Position = UDim2.fromOffset(20, 70)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "OXY-XXXXX"
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(230, 230, 235)
    box.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -40, 0, 36)
    btn.Position = UDim2.fromOffset(20, 120)
    btn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
    btn.BorderSizePixel = 0
    btn.Text = "VERIFY"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -40, 0, 20)
    status.Position = UDim2.fromOffset(20, 165)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(220, 80, 80)

    btn.MouseButton1Click:Connect(function()
        local ok, err = validateKey(box.Text)
        if ok then
            if type(writefile) == "function" then
                ensureFolder()
                pcall(writefile, SAVED_KEY_FILE, box.Text)
            end
            status.TextColor3 = Color3.fromRGB(80, 220, 120)
            status.Text = "verified"
            task.wait(0.6)
            gui:Destroy()
            _G.OxyPremiumKeyVerified = true
        else
            status.TextColor3 = Color3.fromRGB(220, 80, 80)
            status.Text = err or "invalid"
        end
    end)

    -- محاولة قراءة مفتاح محفوظ
    if type(readfile) == "function" and type(isfile) == "function" and isfile(SAVED_KEY_FILE) then
        pcall(function()
            local saved = readfile(SAVED_KEY_FILE)
            box.Text = saved
            local ok = validateKey(saved)
            if ok then
                task.wait(0.2)
                gui:Destroy()
                _G.OxyPremiumKeyVerified = true
            end
        end)
    end

    gui.Parent = LP:WaitForChild("PlayerGui")
end

promptKey()
repeat task.wait(0.1) until _G.OxyPremiumKeyVerified
