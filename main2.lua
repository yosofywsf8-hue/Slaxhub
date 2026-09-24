-- Slax Hub v31.0 - Ultra Simple Auto Parry (WORKING)
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(600, 450),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "Slax Hub",
    Icon = "sword",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 80, 255)),
    OnlyMobile = false,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- Services
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- State
local AutoParryEnabled = false
local ParryDistance = 25  -- studs - المسافة اللي يصد فيها

-- =========================================
-- Token
-- =========================================
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' and debug.info(f, 's'):find('PRY', 1, true) then
        for _, v in debug.getupvalues(f) do
            if type(v) == 'function' then
                _token = v
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(uid)
    if not _token then return "" end
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
end

-- =========================================
-- Hook
-- =========================================
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" 
        and type(args[4]) == "number" and typeof(args[5]) == "CFrame" 
        and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
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
                    local _args = {...}
                    if _is_valid(_args) and not _reverted[self] then
                        _reverted[self] = _args
                    end
                    return _old(self, key)(_, unpack(_args))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

local _parryRemote = nil
local _parryArgs = nil

local function GetParryRemote()
    if not _parryRemote or not _parryRemote.Parent then
        _parryRemote = nil
        _parryArgs = nil
        for r, a in pairs(_reverted) do
            _parryRemote = r
            _parryArgs = a
            break
        end
    end
    return _parryRemote, _parryArgs
end

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    local packet = {
        args[1], args[2], _tokenize(args[2]), 0.5,
        WS.CurrentCamera.CFrame, {}, {0, 0}, false
    }
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
end

-- =========================================
-- 🔥 SIMPLE & POWERFUL AUTO PARRY
-- =========================================
local lastParryTime = 0
local ballLocks = {}  -- table: {[ball] = unlockTime}

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

    -- Global cooldown - منع spam
    if (now - lastParryTime) < 0.08 then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end

    -- ابحث على أقرب كرة جاية
    local bestBall = nil
    local bestDistance = math.huge

    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 5 then continue end

        -- هل الكرة جاية نحوي؟
        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0 then continue end  -- رايحة بعيد

        local distance = (playerPos - ballPos).Magnitude

        -- 🎯 فحص المسافة
        if distance <= ParryDistance then
            if distance < bestDistance then
                bestDistance = distance
                bestBall = ball
            end
        end
    end

    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + 0.5  -- قفل 500ms
        FireParry()
    end
end)

-- =========================================
-- Stats UI
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "SlaxStatsUI_" .. math.random(1, 99999)
StatsGui.Parent = GetGuiParent()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 99999

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Parent = StatsGui
StatsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
StatsLabel.BackgroundTransparency = 0.3
StatsLabel.BorderSizePixel = 0
StatsLabel.Position = UDim2.new(0.72, 0, 0.02, 0)
StatsLabel.Size = UDim2.new(0, 240, 0, 40)
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.Text = "Slax Hub"
StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
StatsLabel.TextSize = 12

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsLabel

local StatsStroke = Instance.new("UIStroke")
StatsStroke.Parent = StatsLabel
StatsStroke.Color = Color3.fromRGB(80, 255, 160)
StatsStroke.Thickness = 1.2

local frames = 0
local lastTime = tick()

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if (tick() - lastTime) >= 1 then
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        StatsLabel.Text = string.format("FPS: %d | Ping: %d | Parry: %s",
            frames, ping, AutoParryEnabled and "ON" or "OFF")
        if AutoParryEnabled then
            StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
            StatsStroke.Color = Color3.fromRGB(80, 255, 160)
        else
            StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            StatsStroke.Color = Color3.fromRGB(150, 150, 150)
        end
        frames = 0
        lastTime = tick()
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "⚡ Auto Parry",
    Desc = "Simple & works - parries balls coming at you",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then ballLocks = {} end
    end
})

MainTab:Slider({
    Title = "Parry Distance (studs)",
    Desc = "Distance to trigger parry - 20-30 recommended",
    Value = {
        Min = 5,
        Max = 80,
        Default = 25,
    },
    Callback = function(Value)
        ParryDistance = Value
    end
})

SettingsTab:Button({
    Title = "Reset Locks",
    Callback = function()
        ballLocks = {}
    end
})

SettingsTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
        StatsGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v31.0",
    Content = "Simple Auto Parry - Just Works",
    Duration = 5
})
