--[[
    ═══════════════════════════════════════════════════════════
    OXY CUSTOM UI (Private Style) - Full Functional Build
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
local Debris   = cloneref(game:GetService("Debris"))

local LP       = Players.LocalPlayer
local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
local preSim   = Run.PreSimulation
local postSim  = Run.PostSimulation

local balls   = WS:WaitForChild("Balls")
local alive   = WS:WaitForChild("Alive")
local runtime = WS:WaitForChild("Runtime")
local remotes = RS:WaitForChild("Remotes")

--=============================================================
-- [1] CONFIG
--=============================================================
local Config = {
    auto_parry = false, accuracy = 100, auto_spam = false, spam_threshold = 3,
    triggerbot = false, manual_spam = false, random_target = false, ability_esp = false
}

--=============================================================
-- [2] TOKEN & EVENT CAPTURE (الجزء الأساسي للـ AutoParry)
--=============================================================
local eventCapture = { captured = {}, hooked = {}, originals = {}, token_fn = nil }
for _, primaryValue in getgc(true) do
    if type(primaryValue) ~= "function" or not debug.info(primaryValue, "s"):find("PRY", 1, true) then
        continue
    else
        for _, secondaryValue in debug.getupvalues(primaryValue) do
            if type(secondaryValue) == "function" then
                eventCapture.token_fn = secondaryValue
                break
            end
        end
        if not eventCapture.token_fn then continue end
    end
    break
end

function eventCapture.tokenize(inputValue)
    local secondaryValue = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local tertiaryValue = eventCapture.token_fn(inputValue, "TIME")
    local quaternaryValue = table.create(#secondaryValue)
    for i = 1, #secondaryValue do
        quaternaryValue[i] = string.char(bit32.bxor((string.byte(secondaryValue, i) + i) % 256, string.byte(tertiaryValue, (i - 1) % #tertiaryValue + 1)))
    end
    return table.concat(quaternaryValue)
end

function eventCapture.unhook()
    for k, primaryValue in eventCapture.originals, nil, nil do
        pcall(function()
            setreadonly(k, false); k.__index = primaryValue; setreadonly(k, true)
        end)
    end
    table.clear(eventCapture.hooked)
    table.clear(eventCapture.originals)
end

function eventCapture.valid_args(inputValue)
    return #inputValue == 8 and type(inputValue[2]) == "string" and type(inputValue[3]) == "string" and type(inputValue[4]) == "number" and typeof(inputValue[5]) == "CFrame" and type(inputValue[6]) == "table" and type(inputValue[7]) == "table" and type(inputValue[8]) == "boolean"
end

function eventCapture.hook(inputValue)
    if next(eventCapture.captured) ~= nil then return end
    local primaryValue = getrawmetatable(inputValue)
    if eventCapture.hooked[primaryValue] then return end
    eventCapture.hooked[primaryValue] = true
    setreadonly(primaryValue, false)
    local index = primaryValue.__index
    eventCapture.originals[primaryValue] = index
    primaryValue.__index = function(secondaryInput, tertiaryInput)
        if tertiaryInput == "FireServer" and secondaryInput:IsA("RemoteEvent") or tertiaryInput == "InvokeServer" and secondaryInput:IsA("RemoteFunction") then
            return function(quaternaryInput, ...)
                local temporaryList = {...}
                if eventCapture.valid_args(temporaryList) then
                    eventCapture.captured[secondaryInput] = temporaryList
                    eventCapture.unhook()
                end
                return index(secondaryInput, tertiaryInput)(quaternaryInput, unpack(temporaryList))
            end
        end
        return index(secondaryInput, tertiaryInput)
    end
    setreadonly(primaryValue, true)
end

for _, v in ipairs(RS:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then eventCapture.hook(v) end
end

--=============================================================
-- [3] BALL STATE + TARGET
--=============================================================
local ballState = { positions = {}, state = { AerodynamicTime = tick(), LastWarping = tick(), LerpRadians = 0, Curving = tick() } }

local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("_Index") and RS.Packages._Index:FindFirstChild("sleitnick_net@0.1.0") and RS.Packages._Index["sleitnick_net@0.1.0"]:FindFirstChild("net")
if net then
    for _, primaryValue in net:GetChildren() do
        if primaryValue:IsA("UnreliableRemoteEvent") and primaryValue.Name ~= "URE/ReplicateBallPosition" then
            primaryValue.OnClientEvent:Connect(function(b, pos)
                if b and b.Parent == balls and b:GetAttribute("realBall") then ballState.positions[b] = pos end
            end)
            break
        end
    end
end

function ballState.get()
    for _, b in ipairs(balls:GetChildren()) do if b:GetAttribute("realBall") then return b end end
end
function ballState.position(b)
    b = b or ballState.get()
    if b then return ballState.positions[b] or b.Position end
    return Vector3.zero
end
function ballState.get_all()
    local t = {}
    for _, b in ipairs(balls:GetChildren()) do if b:GetAttribute("realBall") then table.insert(t, b) end end
    return t
end

local inventoryUnlockManager = { current = nil, visited = {} }
function inventoryUnlockManager.by_mouse()
    local list = {}
    for _, p in ipairs(alive:GetChildren()) do if p.Name ~= LP.Name and p.PrimaryPart then table.insert(list, p) end end
    if #list == 0 then return nil end
    local cam = WS.CurrentCamera
    local dir = cam:ScreenPointToRay(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y).Direction
    local best, bestDot = nil, -math.huge
    for _, p in ipairs(list) do
        local d = p.PrimaryPart.Position - cam.CFrame.Position
        if d.Magnitude > 0 and cam.CFrame.LookVector:Dot(d.Unit) > 0 then
            local dot = dir:Dot(d.Unit)
            if dot > bestDot then bestDot = dot; best = p end
        end
    end
    inventoryUnlockManager.current = best or list[1]
    return inventoryUnlockManager.current
end
function inventoryUnlockManager.closest()
    if Config.random_target then
        local list = {}
        for _, p in ipairs(alive:GetChildren()) do if p.Name ~= LP.Name and p.PrimaryPart then table.insert(list, p) end end
        if #list > 0 then inventoryUnlockManager.current = list[math.random(1, #list)] end
        return inventoryUnlockManager.current
    end
    return inventoryUnlockManager.by_mouse()
end

--=============================================================
-- [4] PARRY FIRE (الربط الفعلي)
--=============================================================
local parryController = { count = 0, first_signal = nil }
function parryController.fire(manual)
    local cam = WS.CurrentCamera
    local cframe = cam.CFrame
    if inventoryUnlockManager.current and inventoryUnlockManager.current.PrimaryPart then
        cframe = CFrame.lookAt(LP.Character.PrimaryPart.Position, inventoryUnlockManager.current.PrimaryPart.Position + Vector3.new(0,1.75,0))
    end
    
    local targetPos = inventoryUnlockManager.current and inventoryUnlockManager.current.PrimaryPart and inventoryUnlockManager.current.PrimaryPart.Position
    local screenPos = targetPos and cam:WorldToViewportPoint(targetPos) or UIS:GetMouseLocation()
    local tempMap = {}
    for _, p in ipairs(alive:GetChildren()) do
        if p.PrimaryPart then
            local sp = cam:WorldToScreenPoint(p.PrimaryPart.Position)
            if sp and sp.Z > 0 then tempMap[p.Name] = sp end
        end
    end

    if next(eventCapture.captured) == nil then
        if not parryController.first_signal then
            parryController.first_signal = require(RS.Packages.Signal).new()
            parryController.first_signal:Connect(require(RS.Controllers["SwordsController \12"].PRY))
        end
        parryController.first_signal:Fire(0.5, cframe, tempMap, {screenPos.X, screenPos.Y}, false)
    else
        for k, v in eventCapture.captured, nil, nil do
            local args = {
                v[1], v[2], eventCapture.tokenize(v[2]), 0.5, cframe, tempMap, {screenPos.X, screenPos.Y}, false
            }
            if k:IsA("RemoteEvent") then k:FireServer(unpack(args))
            elseif k:IsA("RemoteFunction") then k:InvokeServer(unpack(args)) end
        end
    end
    
    if parryController.count > 7 then return false end
    parryController.count = parryController.count + 1
    task.delay(0.5, function() if parryController.count > 0 then parryController.count = parryController.count - 1 end end)
end

--=============================================================
-- [5] AUTOPARRY + AUTOSPAM + TRIGGERBOT
--=============================================================
local parryState = { debounce = false, until_at = 0, accuracy = 1.5 }

function parryState.check()
    local char = LP.Character and LP.Character.PrimaryPart
    if not char then return end
    local now = tick()
    if parryState.debounce or now < parryState.until_at then return end
    
    local pos = char.Position
    local tol = math.clamp(dataPing:GetValue() / 100, 5, 17)
    
    for _, b in ipairs(ballState.get_all()) do
        local z = b:FindFirstChild("zoomies")
        if z then
            local tgt = b:GetAttribute("target")
            local mag = z.VectorVelocity.Magnitude
            local dist = (pos - ballState.position(b)).Magnitude
            local calcA = (2.4 + math.min(math.max(mag - 9.5, 0), 650) * 0.002) * parryState.accuracy
            
            if tgt == LP.Name and dist <= tol + math.max(mag / calcA, 9.5) then
                parryController.fire()
                parryState.debounce = true
                parryState.until_at = now + 1
            end
        end
    end
end

local autoParryConn, autoSpamConn, triggerConn, manualConn

local function setAutoParry(on)
    Config.auto_parry = on
    if on then
        if autoParryConn then autoParryConn:Disconnect() end
        autoParryConn = postSim:Connect(parryState.check)
    elseif autoParryConn then autoParryConn:Disconnect(); autoParryConn = nil end
end

local spamController = { distance = 0, last_auto = 0 }

local function autoSpamCheck()
    local b = ballState.get()
    if not b or not b:FindFirstChild("zoomies") then return end
    inventoryUnlockManager.closest()
    if not inventoryUnlockManager.current then return end
    local now = tick()
    
    local char = LP.Character and LP.Character.PrimaryPart
    if not char then return end
    local ballDist = (char.Position - ballState.position(b)).Magnitude
    local tgt = b:GetAttribute("target")
    
    if ballDist <= 20 and tgt ~= LP.Name and now - spamController.last_auto >= 0.001 then
        spamController.last_auto = now
        parryController.fire(true)
    end
end

local function setAutoSpam(on)
    Config.auto_spam = on
    if on then
        if autoSpamConn then autoSpamConn:Disconnect() end
        autoSpamConn = preSim:Connect(autoSpamCheck)
    elseif autoSpamConn then autoSpamConn:Disconnect(); autoSpamConn = nil end
end

local function setTrigger(on)
    Config.triggerbot = on
    if on then
        if triggerConn then triggerConn:Disconnect() end
        triggerConn = preSim:Connect(function()
            local b = ballState.get()
            if b and b:GetAttribute("target") == LP.Name then parryController.fire() end
        end)
    elseif triggerConn then triggerConn:Disconnect(); triggerConn = nil end
end

local function setManual(on)
    Config.manual_spam = on
    if manualConn then manualConn:Disconnect(); manualConn = nil end
    if on then
        local last = 0
        manualConn = preSim:Connect(function()
            if tick() - last < 0.001 then return end
            last = tick()
            parryController.fire(true)
        end)
    end
end

--=============================================================
-- [6] ABILITY ESP
--=============================================================
local esp = { labels = {} }
local function createEsp(player)
    task.spawn(function()
        local char = player.Character
        while not char or not char.Parent do task.wait(0.2); char = player.Character end
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        local bb = Instance.new("BillboardGui")
        bb.Adornee = head; bb.Size = UDim2.fromOffset(200, 50); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = head
        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(255, 255, 255); lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.TextYAlignment = Enum.TextYAlignment.Center
        esp.labels[player] = lbl
        local function update()
            local ab = player:GetAttribute("EquippedAbility")
            lbl.Text = ab and (player.DisplayName .. " [" .. ab .. "]") or player.DisplayName
            lbl.Visible = Config.ability_esp
        end
        update()
        player:GetAttributeChangedSignal("EquippedAbility"):Connect(update)
        local conn
        conn = Run.Heartbeat:Connect(function()
            if not char or not char.Parent then conn:Disconnect(); bb:Destroy(); esp.labels[player] = nil; return end
            lbl.Visible = Config.ability_esp
        end)
    end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then p.CharacterAdded:Connect(function() createEsp(p) end); createEsp(p) end end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() createEsp(p) end) end)

--=============================================================
-- [7] CUSTOM UI
--=============================================================
local function create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local ScreenGui = create("ScreenGui", { Name = "OxyUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, Parent = LP:WaitForChild("PlayerGui") })
local MainFrame = create("Frame", { Parent = ScreenGui, Size = UDim2.fromOffset(500, 350), Position = UDim2.new(0.5, -250, 0.5, -175), BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0, ClipsDescendants = true })
create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = MainFrame })
create("UIStroke", { Color = Color3.fromRGB(45, 45, 55), Thickness = 1, Parent = MainFrame })

local Header = create("Frame", { Parent = MainFrame, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0 })
create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Header })
create("Frame", { Parent = Header, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0 })
create("TextLabel", { Parent = Header, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(15, 0), BackgroundTransparency = 1, Text = "OXY PRIVATE", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left })

local CloseBtn = create("TextButton", { Parent = Header, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -35, 0, 5), BackgroundColor3 = Color3.fromRGB(30, 30, 35), Text = "X", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0 })
create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = CloseBtn })
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Sidebar = create("Frame", { Parent = MainFrame, Size = UDim2.fromOffset(120, 310), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0 })
local ContentArea = create("Frame", { Parent = MainFrame, Size = UDim2.new(1, -120, 1, -40), Position = UDim2.fromOffset(120, 40), BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0 })

local Tabs = {}
local function createTab(name)
    local btn = create("TextButton", { Parent = Sidebar, Size = UDim2.new(1, -20, 0, 35), Position = UDim2.fromOffset(10, 10 + (#Tabs * 40)), BackgroundColor3 = Color3.fromRGB(20, 20, 25), Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(180, 180, 190), BorderSizePixel = 0 })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
    local frame = create("ScrollingFrame", { Parent = ContentArea, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2, Visible = (#Tabs == 0) })
    table.insert(Tabs, {btn = btn, frame = frame})
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do t.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); t.frame.Visible = false end
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35); frame.Visible = true
    end)
    return frame
end

local CombatTab, VisualTab, MiscTab = createTab("Combat"), createTab("Visual"), createTab("Misc")

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
    local lbl = create("TextLabel", { Parent = f, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(10, 5), BackgroundTransparency = 1, Text = text .. ": " .. default, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Left })
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
            lbl.Text = text .. ": " .. val
            callback(val)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(x, 0, 1, 0)
            local val = math.floor(min + (max - min) * x + 0.5)
            lbl.Text = text .. ": " .. val
            callback(val)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

addToggle(CombatTab, "Auto Parry", Config.auto_parry, setAutoParry)
addSlider(CombatTab, "Accuracy", 1, 100, Config.accuracy, function(v) Config.accuracy = v; parryState.accuracy = (v - 1) * 0.01515 end)
addToggle(CombatTab, "Auto Spam", Config.auto_spam, setAutoSpam)
addSlider(CombatTab, "Threshold", 1, 3, Config.spam_threshold, function(v) Config.spam_threshold = v end)
addToggle(CombatTab, "Triggerbot", Config.triggerbot, setTrigger)
addToggle(CombatTab, "Random Target", Config.random_target, function(v) Config.random_target = v end)

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

addToggle(MiscTab, "Manual Spam", Config.manual_spam, setManual)

-- Draggable
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
