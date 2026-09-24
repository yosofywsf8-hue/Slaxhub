-- ═══════════════════════════════════════════════════
--   SLAX HUB - FINAL EDITION
--   Most Powerful Auto Parry
--   Developed by yossef
-- ═══════════════════════════════════════════════════

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "Final Edition - Strongest Auto Parry",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

print("═══════════════════════════════════════")
print("  SLAX HUB - FINAL EDITION")
print("  Loading...")
print("═══════════════════════════════════════")

-- ═══════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════
local AutoParryEnabled = false
local ParryDistance = 30
local PingCompensation = 2.0
local SafetyBuffer = 10
local ParryCPS = 30          -- عدد الصدات في الثانية القصوى

-- ═══════════════════════════════════════════════════
-- TOKEN RETRIEVAL (Multiple Methods)
-- ═══════════════════════════════════════════════════
local _token = nil

-- Method 1: Search by function name
for _, f in getgc(true) do
    if type(f) == 'function' then
        local ok, name = pcall(function()
            return debug.info(f, 's')
        end)
        if ok and name and name:find('PRY', 1, true) then
            local ok2, ups = pcall(function()
                return debug.getupvalues(f)
            end)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if type(v) == 'function' then
                        _token = v
                        break
                    end
                end
            end
            if _token then break end
        end
    end
end

-- Method 2: Search more broadly
if not _token then
    for _, f in getgc(true) do
        if type(f) == 'function' then
            local ok, ups = pcall(function()
                return debug.getupvalues(f)
            end)
            if ok and ups then
                for _, v in pairs(ups) do
                    if type(v) == 'function' then
                        local ok2, name = pcall(function()
                            return debug.info(v, 's')
                        end)
                        if ok2 and name and name:find('PRY', 1, true) then
                            _token = v
                            break
                        end
                    end
                end
            end
            if _token then break end
        end
    end
end

if _token then
    print("✅ Token loaded successfully")
else
    print("❌ Token NOT FOUND - Auto Parry won't work")
end

local function _tokenize(uid)
    if not _token then return "" end
    local ok, result = pcall(function()
        local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
        local k = _token(uid, 'TIME')
        local chars = table.create(#t)
        for i = 1, #t do
            chars[i] = string.char(bit32.bxor(
                (string.byte(t, i) + i) % 256,
                string.byte(k, (i - 1) % #k + 1)
            ))
        end
        return table.concat(chars)
    end)
    if ok then return result end
    return ""
end

-- ═══════════════════════════════════════════════════
-- REMOTE HOOKING
-- ═══════════════════════════════════════════════════
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 
        and type(args[2]) == "string" 
        and type(args[3]) == "string" 
        and type(args[4]) == "number" 
        and typeof(args[5]) == "CFrame" 
        and type(args[6]) == "table" 
        and type(args[7]) == "table" 
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    local ok, err = pcall(function()
        if not _reverted[remote] and not _original[getrawmetatable(remote)] then
            _original[getrawmetatable(remote)] = true
            local _meta = getrawmetatable(remote)
            setreadonly(_meta, false)
            local _old = _meta.__index
            _meta.__index = function(self, key)
                if (key == 'FireServer' and self:IsA('RemoteEvent')) 
                    or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                    return function(_, ...)
                        local _args = {...}
                        if _is_valid(_args) and not _reverted[self] then
                            _reverted[self] = _args
                            print("[Slax] Hooked parry remote:", self.Name)
                        end
                        return _old(self, key)(_, unpack(_args))
                    end
                end
                return _old(self, key)
            end
            setreadonly(_meta, true)
        end
    end)
end

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

print("✅ Hooks set up")

-- ═══════════════════════════════════════════════════
-- FIRE PARRY
-- ═══════════════════════════════════════════════════
local _parryRemote = nil
local _parryArgs = nil

local function GetParryRemote()
    if not _parryRemote or not _parryRemote.Parent then
        _parryRemote = nil
        _parryArgs = nil
        for r, a in pairs(_reverted) do
            _parryRemote = r
            _parryArgs = a
            print("[Slax] Using remote:", r.Name)
            break
        end
    end
    return _parryRemote, _parryArgs
end

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return false end
    
    local ok = pcall(function()
        local packet = {
            args[1], args[2], _tokenize(args[2]), 0.5,
            WS.CurrentCamera.CFrame, {}, {0, 0}, false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end)
    return ok
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- ═══════════════════════════════════════════════════
-- MAIN AUTO PARRY LOOP
-- ═══════════════════════════════════════════════════
local lastParryTime = 0
local ballLocks = {}
local ParryCount = 0
local LastInfo = { distance = 0, speed = 0, trigger = 0 }

-- Cleanup
task.spawn(function()
    while task.wait(0.3) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then
                ballLocks[ball] = nil
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        return
    end
    
    local now = tick()
    if (now - lastParryTime) < (1 / ParryCPS) then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local playerPos = hrp.Position
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    local ping = GetPing()
    local bestBall = nil
    local bestDistance = math.huge
    local bestSpeed = 0
    local bestTrigger = 0
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end
        
        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 5 then continue end
        
        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0.15 then continue end
        
        local distance = (playerPos - ballPos).Magnitude
        
        -- 🎯 PING COMPENSATION
        -- المسافة اللي تمشيها الكرة خلال البينج
        local pingDistance = ping * speed * PingCompensation
        
        -- مسافة الصد الفعالة
        local triggerDistance = ParryDistance + pingDistance + SafetyBuffer
        
        -- 🚀 Speed Bonus - كرات سريعة تزيد المسافة
        if speed > 200 then
            triggerDistance = triggerDistance + 20
        elseif speed > 150 then
            triggerDistance = triggerDistance + 15
        elseif speed > 100 then
            triggerDistance = triggerDistance + 10
        end
        
        if distance <= triggerDistance then
            if distance < bestDistance then
                bestDistance = distance
                bestBall = ball
                bestSpeed = speed
                bestTrigger = triggerDistance
            end
        end
    end
    
    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + 0.4
        FireParry()
        ParryCount = ParryCount + 1
        LastInfo.distance = bestDistance
        LastInfo.speed = bestSpeed
        LastInfo.trigger = bestTrigger
    end
end)

print("✅ Auto Parry loop ready")

-- ═══════════════════════════════════════════════════
-- STATS DISPLAY
-- ═══════════════════════════════════════════════════
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() 
        return LocalPlayer:WaitForChild("PlayerGui", 5) 
    end)
    if ok2 and pg then return pg end
    return CoreGui
end

pcall(function()
    for _, gui in pairs(GetGuiParent():GetChildren()) do
        if gui.Name:find("SlaxStats") then
            gui:Destroy()
        end
    end
end)

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "SlaxStats_" .. math.random(1, 99999)
StatsGui.Parent = GetGuiParent()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 99999

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Parent = StatsGui
StatsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
StatsLabel.BackgroundTransparency = 0.2
StatsLabel.BorderSizePixel = 0
StatsLabel.Position = UDim2.new(0.65, 0, 0.02, 0)
StatsLabel.Size = UDim2.new(0, 280, 0, 80)
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.Text = "Slax Hub"
StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
StatsLabel.TextSize = 11
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsLabel

local StatsStroke = Instance.new("UIStroke")
StatsStroke.Parent = StatsLabel
StatsStroke.Color = Color3.fromRGB(80, 255, 160)
StatsStroke.Thickness = 1.2

local frames = 0
local lastFpsTime = tick()

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if (tick() - lastFpsTime) >= 1 then
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        StatsLabel.Text = string.format(
            "⚡ SLAX HUB FINAL\nFPS: %d | Ping: %d ms\n🎯 Parries: %d\n📍 dist: %d | spd: %d | trig: %d",
            frames, ping, ParryCount,
            math.floor(LastInfo.distance),
            math.floor(LastInfo.speed),
            math.floor(LastInfo.trigger)
        )
        if AutoParryEnabled then
            StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
            StatsStroke.Color = Color3.fromRGB(80, 255, 160)
        else
            StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            StatsStroke.Color = Color3.fromRGB(150, 150, 150)
        end
        frames = 0
        lastFpsTime = tick()
    end
end)

-- ═══════════════════════════════════════════════════
-- UI CONTROLS
-- ═══════════════════════════════════════════════════
local ParryToggle = Tabs.Main:AddToggle("AutoParry", {
    Title = "⚡ Auto Parry",
    Description = "Strongest parry - Ping adaptive",
    Default = false
})

ParryToggle:OnChanged(function(Value)
    AutoParryEnabled = Value
    if not Value then ballLocks = {} end
    Fluent:Notify({
        Title = "Auto Parry",
        Content = Value and "✅ ON" or "❌ OFF",
        Duration = 2
    })
end)

Tabs.Main:AddSlider("ParryDistance", {
    Title = "Parry Distance (studs)",
    Description = "Base trigger distance",
    Default = 30,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryDistance = Value
    end
})

Tabs.Main:AddSlider("PingComp", {
    Title = "Ping Compensation",
    Description = "Higher = Earlier parry (150 = default)",
    Default = 200,
    Min = 50,
    Max = 400,
    Rounding = 0,
    Callback = function(Value)
        PingCompensation = Value / 100
    end
})

Tabs.Main:AddSlider("SafetyBuffer", {
    Title = "Safety Buffer (studs)",
    Description = "Extra distance for safety",
    Default = 10,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        SafetyBuffer = Value
    end
})

Tabs.Main:AddSlider("ParryCPS", {
    Title = "Max Parry Rate (CPS)",
    Description = "Maximum parries per second",
    Default = 30,
    Min = 10,
    Max = 60,
    Rounding = 0,
    Callback = function(Value)
        ParryCPS = Value
    end
})

Tabs.Settings:Button({
    Title = "🔄 Reset Ball Locks",
    Description = "Clear stuck ball locks",
    Callback = function()
        ballLocks = {}
        Fluent:Notify({
            Title = "Slax Hub",
            Content = "Ball locks reset",
            Duration = 2
        })
    end
})

Tabs.Settings:Button({
    Title = "🗑️ Destroy UI",
    Callback = function()
        Window:Destroy()
        StatsGui:Destroy()
    end
})

InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub - Final Edition 👑",
    Content = "Strongest Auto Parry loaded",
    Duration = 6
})

print("═══════════════════════════════════════")
print("  ✅ SLAX HUB LOADED SUCCESSFULLY")
print("  Token: " .. (_token and "OK" or "FAILED"))
print("  Hooks: " .. tostring(#_reverted))
print("  Press RightCtrl to open UI")
print("═══════════════════════════════════════")
