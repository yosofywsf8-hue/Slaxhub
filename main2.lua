--[[
    ═══════════════════════════════════════════════════════════
    OXY CUSTOM UI (Private Style)
    Features: AutoParry, AutoSpam, Triggerbot, ESP, Unlock All
    ═══════════════════════════════════════════════════════════
]]

if _G.OxyCustomLoaded then return end
_G.OxyCustomLoaded = true

local cloneref = cloneref or function(x) return x end
local Players  = cloneref(game:GetService("Players"))
local Run      = cloneref(game:GetService("RunService"))
local UIS      = cloneref(game:GetService("UserInputService"))
local Stats    = cloneref(game:GetService("Stats"))
local RS       = cloneref(game:GetService("ReplicatedStorage"))
local WS       = cloneref(game:GetService("Workspace"))
local Http     = cloneref(game:GetService("HttpService"))
local TweenSrv = cloneref(game:GetService("TweenService"))
local Debris   = cloneref(game:GetService("Debris"))

local LP       = Players.LocalPlayer
local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
local preSim   = Run.PreSimulation
local postSim  = Run.PostSimulation
local heartbeat= Run.Heartbeat

--=============================================================
-- [1] CONFIG
--=============================================================
local DIR, PATH = "oxy", "oxy/config.json"
local defaults = {
    accuracy = 100, spam_threshold = 3, curve_method = "camera",
    manual_spam_key = "E", auto_parry = false, auto_spam = false,
    triggerbot = false, random_target = false, ability_esp = false,
    manual_notify = false, unlock_all = false, ball_debug = false
}
local Config = {}
for k, v in pairs(defaults) do Config[k] = v end

local storageOK = type(readfile) == "function" and type(writefile) == "function"
local function saveConfig()
    if not storageOK then return end
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(DIR) then pcall(makefolder, DIR) end
    end
    pcall(function() writefile(PATH, Http:JSONEncode(Config)) end)
end
local function loadConfig()
    if not storageOK or type(isfile) ~= "function" then return end
    if isfile(PATH) then
        pcall(function()
            local d = Http:JSONDecode(readfile(PATH))
            for k in pairs(defaults) do if d[k] ~= nil then Config[k] = d[k] end end
        end)
    end
end
loadConfig()

task.spawn(function()
    while _G.OxyCustomLoaded do
        task.wait(2)
        saveConfig()
    end
end)

--=============================================================
-- [2] BALL STATE + TARGET
--=============================================================
local Balls   = WS:WaitForChild("Balls")
local Alive   = WS:WaitForChild("Alive")
local Runtime = WS:WaitForChild("Runtime")
local ballState = { positions = {}, state = { AerodynamicTime = tick(), LastWarping = tick(), LerpRadians = 0, Curving = tick() } }

do
    local Pk = RS:FindFirstChild("Packages")
    local idx = Pk and Pk:FindFirstChild("_Index")
    local net = idx and idx:FindFirstChild("sleitnick_net@0.1.0")
    net = net and net:FindFirstChild("net")
    if net then
        for _, r in ipairs(net:GetChildren()) do
            if r:IsA("UnreliableRemoteEvent") and r.Name ~= "URE/ReplicateBallPosition" then
                r.OnClientEvent:Connect(function(ball, pos)
                    if ball and ball.Parent == Balls and ball:GetAttribute("realBall") then
                        ballState.positions[ball] = pos
                    end
                end)
                break
            end
        end
    end
end

function ballState.get()
    for _, b in ipairs(Balls:GetChildren()) do
        if b:GetAttribute("realBall") then return b end
    end
end
function ballState.position(b)
    b = b or ballState.get()
    if b then return ballState.positions[b] or b.Position end
    return Vector3.zero
end
function ballState.all()
    local t = {}
    for _, b in ipairs(Balls:GetChildren()) do
        if b:GetAttribute("realBall") then table.insert(t, b) end
    end
    return t
end

local targetMgr = { current = nil, visited = {} }
function targetMgr.closest()
    local list = {}
    for _, p in ipairs(Alive:GetChildren()) do
        if p.Name ~= LP.Name and p.PrimaryPart then table.insert(list, p) end
    end
    if #list == 0 then return nil end
    if Config.random_target then
        local pick = list[math.random(1, #list)]
        targetMgr.current = pick
        return pick
    end
    local cam = WS.CurrentCamera
    local m = UIS:GetMouseLocation()
    local dir = cam:ScreenPointToRay(m.X, m.Y).Direction
    local best, bestDot = nil, -math.huge
    for _, p in ipairs(list) do
        local d = p.PrimaryPart.Position - cam.CFrame.Position
        if d.Magnitude > 0 then
            local dot = dir:Dot(d.Unit)
            if dot > bestDot then bestDot = dot; best = p end
        end
    end
    targetMgr.current = best or list[1]
    return targetMgr.current
end

--=============================================================
-- [3] CORE FEATURES (Parry, Spam, Triggerbot)
--=============================================================
local Parry = { count = 0 }
function Parry.fire()
    -- ⚠️ هنا تربط الريموت الحقيقي (التوكن سبوف)
    -- لاحظ: أنت قلت إن الميزات شغالة، فقط تبي UI، فخليت هذه الدالة جاهزة للربط.
    if Parry.count > 7 then return end
    Parry.count = Parry.count + 1
    task.delay(0.5, function() if Parry.count > 0 then Parry.count = Parry.count - 1 end end)
    -- مثال: remotes.Parry:FireServer(...)
end

local parryState = { debounce = false, until_at = 0, accuracy = 1.5 }
local function parryCheck()
    local char = LP.Character
    local root = char and char.PrimaryPart
    if not root then return end
    local now = tick()
    if parryState.debounce or now < parryState.until_at then return end
    local pos = root.Position
    local tol = math.clamp(dataPing:GetValue() / 100, 5, 17)
    for _, b in ipairs(ballState.all()) do
        local z = b:FindFirstChild("zoomies")
        if z then
            local tgt = b:GetAttribute("target")
            local mag = z.VectorVelocity.Magnitude
            local dist = (pos - ballState.position(b)).Magnitude
            local calcA = (2.4 + math.min(math.max(mag - 9.5, 0), 650) * 0.002) * parryState.accuracy
            if tgt == LP.Name and dist <= tol + math.max(mag / calcA, 9.5) then
                Parry.fire()
                parryState.debounce = true
                parryState.until_at = now + 1
            end
        end
    end
end

local autoParryConn
local function setAutoParry(on)
    Config.auto_parry = on
    if on then
        if autoParryConn then autoParryConn:Disconnect() end
        autoParryConn = postSim:Connect(parryCheck)
    elseif autoParryConn then
        autoParryConn:Disconnect(); autoParryConn = nil
    end
end

local autoSpamConn
local function autoSpamCheck()
    local b = ballState.get()
    if not b or not b:FindFirstChild("zoomies") then return end
    local target = targetMgr.closest()
    if not target or not target.PrimaryPart then return end
    local char = LP.Character
    if not char or not char.PrimaryPart then return end
    local dist = (char.PrimaryPart.Position - ballState.position(b)).Magnitude
    if dist <= 15 and tick() - parryState.until_at > 0 then
        Parry.fire()
        parryState.until_at = tick() + 0.1
    end
end
local function setAutoSpam(on)
    Config.auto_spam = on
    if on then
        if autoSpamConn then autoSpamConn:Disconnect() end
        autoSpamConn = preSim:Connect(autoSpamCheck)
    elseif autoSpamConn then
        autoSpamConn:Disconnect(); autoSpamConn = nil
    end
end

local triggerConn
local function setTrigger(on)
    Config.triggerbot = on
    if on then
        if triggerConn then triggerConn:Disconnect() end
        triggerConn = preSim:Connect(function()
            local b = ballState.get()
            if b and b:GetAttribute("target") == LP.Name then Parry.fire() end
        end)
    elseif triggerConn then
        triggerConn:Disconnect(); triggerConn = nil
    end
end

local manualConn
local function setManual(on)
    if manualConn then manualConn:Disconnect(); manualConn = nil end
    if on then
        local last = 0
        manualConn = preSim:Connect(function()
            if tick() - last < 0.001 then return end
            last = tick()
            Parry.fire()
        end)
    end
end

--=============================================================
-- [4] ABILITY ESP
--=============================================================
local esp = { labels = {} }
local function createEsp(player)
    task.spawn(function()
        local char = player.Character
        while not char or not char.Parent do task.wait(0.2); char = player.Character end
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        local bb = Instance.new("BillboardGui")
        bb.Adornee = head; bb.Size = UDim2.fromOffset(200, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = head
        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255); lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        esp.labels[player] = lbl
        local function update()
            local ab = player:GetAttribute("EquippedAbility")
            lbl.Text = ab and (player.DisplayName .. " [" .. ab .. "]") or player.DisplayName
            lbl.Visible = Config.ability_esp
        end
        update()
        player:GetAttributeChangedSignal("EquippedAbility"):Connect(update)
        local conn
        conn = heartbeat:Connect(function()
            if not char or not char.Parent then
                conn:Disconnect(); bb:Destroy(); esp.labels[player] = nil; return
            end
            lbl.Visible = Config.ability_esp
        end)
    end)
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then p.CharacterAdded:Connect(function() createEsp(p) end); createEsp(p) end
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() createEsp(p) end) end)

--=============================================================
-- [5] CUSTOM UI (NO FLUENT) - PRIVATE STYLE
--=============================================================
local function create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local ScreenGui = create("ScreenGui", {
    Name = "OxyCustomUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 100,
    Parent = LP:WaitForChild("PlayerGui")
})

local MainFrame = create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.fromOffset(500, 350),
    Position = UDim2.new(0.5, -250, 0.5, -175),
    BackgroundColor3 = Color3.fromRGB(15, 15, 18),
    BorderSizePixel = 0,
    ClipsDescendants = true
})
create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = MainFrame })
create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Parent = MainFrame })

-- Header
local Header = create("Frame", {
    Parent = MainFrame, Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0
})
create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Header })
create("Frame", {
    Parent = Header, Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0
})
create("TextLabel", {
    Parent = Header, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(15, 0),
    BackgroundTransparency = 1, Text = "OXY PRIVATE", Font = Enum.Font.GothamBold,
    TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left
})

-- Close Button
local CloseBtn = create("TextButton", {
    Parent = Header, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -35, 0, 5),
    BackgroundColor3 = Color3.fromRGB(30, 30, 35), Text = "X", Font = Enum.Font.GothamBold,
    TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0
})
create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = CloseBtn })
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Sidebar
local Sidebar = create("Frame", {
    Parent = MainFrame, Size = UDim2.fromOffset(120, 310), Position = UDim2.fromOffset(0, 40),
    BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0
})
local ContentArea = create("Frame", {
    Parent = MainFrame, Size = UDim2.new(1, -120, 1, -40), Position = UDim2.fromOffset(120, 40),
    BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0
})

local Tabs = {}
local function createTab(name)
    local btn = create("TextButton", {
        Parent = Sidebar, Size = UDim2.new(1, -20, 0, 35), Position = UDim2.fromOffset(10, 10 + (#Tabs * 40)),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25), Text = name, Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = Color3.fromRGB(180, 180, 190), BorderSizePixel = 0
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
    local frame = create("ScrollingFrame", {
        Parent = ContentArea, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        ScrollBarThickness = 2, Visible = (#Tabs == 0)
    })
    table.insert(Tabs, {btn = btn, frame = frame})
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            t.frame.Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        frame.Visible = true
    end)
    return frame
end

local CombatTab = createTab("Combat")
local VisualTab = createTab("Visual")
local MiscTab   = createTab("Misc")

-- Helper to add elements
local function addToggle(parent, text, default, callback)
    local f = create("Frame", { Parent = parent, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, #parent:GetChildren() * 35), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = f })
    create("TextLabel", { Parent = f, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Left })
    local t = create("TextButton", { Parent = f, Size = UDim2.fromOffset(30, 16), Position = UDim2.new(1, -40, 0.5, -8), BackgroundColor3 = default and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(40, 40, 45), Text = "", BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = t })
    t.MouseButton1Click:Connect(function()
        default = not default
        t.BackgroundColor3 = default and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(40, 40, 45)
        callback(default)
    end)
end

local function addSlider(parent, text, min, max, default, callback)
    local f = create("Frame", { Parent = parent, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, #parent:GetChildren() * 35), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = f })
    create("TextLabel", { Parent = f, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(10, 5), BackgroundTransparency = 1, Text = text .. ": " .. default, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Left })
    local bar = create("Frame", { Parent = f, Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30), BackgroundColor3 = Color3.fromRGB(40, 40, 45), BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
    local fill = create("Frame", { Parent = bar, Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = Color3.fromRGB(50, 100, 200), BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    
    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(x, 0, 1, 0)
            local val = math.floor(min + (max - min) * x + 0.5)
            f:FindFirstChildOfClass("TextLabel").Text = text .. ": " .. val
            callback(val)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(x, 0, 1, 0)
            local val = math.floor(min + (max - min) * x + 0.5)
            f:FindFirstChildOfClass("TextLabel").Text = text .. ": " .. val
            callback(val)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- Add Elements to Combat Tab
addToggle(CombatTab, "Auto Parry", Config.auto_parry, setAutoParry)
addSlider(CombatTab, "Accuracy", 1, 100, Config.accuracy, function(v)
    Config.accuracy = v; parryState.accuracy = (v - 1) * 0.01515
end)
addToggle(CombatTab, "Auto Spam", Config.auto_spam, setAutoSpam)
addSlider(CombatTab, "Threshold", 1, 3, Config.spam_threshold, function(v) Config.spam_threshold = v end)
addToggle(CombatTab, "Triggerbot", Config.triggerbot, setTrigger)
addToggle(CombatTab, "Random Target", Config.random_target, function(v) Config.random_target = v end)

-- Add Elements to Visual Tab
addToggle(VisualTab, "Ability ESP", Config.ability_esp, function(v)
    Config.ability_esp = v
    for p, lbl in pairs(esp.labels) do
        if lbl and lbl.Parent then
            local ab = p:GetAttribute("EquippedAbility")
            lbl.Text = ab and (p.DisplayName .. " [" .. ab .. "]") or p.DisplayName
            lbl.Visible = v
        end
    end
end)

-- Add Elements to Misc Tab
addToggle(MiscTab, "Manual Notify", Config.manual_notify, function(v) Config.manual_notify = v end)

-- Draggable
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
