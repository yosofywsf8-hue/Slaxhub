-- Slax Hub - Blade Ball Script (No Slash)
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
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- State
local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamEnabled = false
local ParryDistance = 25
local PingCompensation = 1.5
local SafetyBuffer = 8
local AutoSpamCPS = 350
local SpamRange = 60

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

print("[Slax Hub] Token: " .. (_token and "OK" or "FAILED"))

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

print("[Slax Hub] Hooks: " .. tostring(#_reverted))

-- =========================================
-- Fire Parry
-- =========================================
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

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- Auto Parry Loop
-- =========================================
local lastParryTime = 0
local ballLocks = {}
local ParryCount = 0
local LastInfo = { dist = 0, speed = 0, trigger = 0 }

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
    if (now - lastParryTime) < 0.05 then return end
    
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
        
        -- Ping Compensation
        local pingDist = ping * speed * PingCompensation
        local triggerDist = ParryDistance + pingDist + SafetyBuffer
        
        -- Speed bonus
        if speed > 200 then triggerDist = triggerDist + 20
        elseif speed > 150 then triggerDist = triggerDist + 15
        elseif speed > 100 then triggerDist = triggerDist + 10 end
        
        if distance <= triggerDist then
            if distance < bestDistance then
                bestDistance = distance
                bestBall = ball
                bestSpeed = speed
                bestTrigger = triggerDist
            end
        end
    end
    
    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + 0.5
        FireParry()
        ParryCount = ParryCount + 1
        LastInfo.dist = bestDistance
        LastInfo.speed = bestSpeed
        LastInfo.trigger = bestTrigger
    end
end)

print("[Slax Hub] Auto Parry ready")

-- =========================================
-- Auto Spam Loop
-- =========================================
local lastSpamTime = 0

RunService.Heartbeat:Connect(function()
    if not AutoSpamEnabled then return end
    local now = tick()
    
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local playerPos = hrp.Position
    local nearPlayer = false
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local p_hrp = c:FindFirstChild("HumanoidRootPart")
                if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SpamRange then
                    nearPlayer = true
                    break
                end
            end
        end
    end
    
    if not nearPlayer then return end
    if (now - lastSpamTime) < (1 / math.max(AutoSpamCPS, 1)) then return end
    lastSpamTime = now
    
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    
    local burst = math.max(1, math.floor(AutoSpamCPS / 60))
    for _ = 1, burst do
        local packet = {args[1], args[2], _tokenize(args[2]), 0.5, WS.CurrentCamera.CFrame, {}, {0, 0}, false}
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- Manual Spam Loop
-- =========================================
local lastManualSpamTime = 0

RunService.Heartbeat:Connect(function()
    if not ManualSpamEnabled then return end
    local now = tick()
    if (now - lastManualSpamTime) < 0.005 then return end
    lastManualSpamTime = now
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    for _ = 1, 10 do
        local packet = {args[1], args[2], _tokenize(args[2]), 0.5, WS.CurrentCamera.CFrame, {}, {0, 0}, false}
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- GetGuiParent
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

pcall(function()
    for _, gui in pairs(GetGuiParent():GetChildren()) do
        if gui.Name:find("Slax") then
            gui:Destroy()
        end
    end
end)

-- =========================================
-- Stats UI
-- =========================================
local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "SlaxStats_" .. math.random(1, 99999)
StatsGui.Parent = GetGuiParent()
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.DisplayOrder = 99999

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Parent = StatsGui
StatsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
StatsLabel.BackgroundTransparency = 0.25
StatsLabel.BorderSizePixel = 0
StatsLabel.Position = UDim2.new(0.65, 0, 0.02, 0)
StatsLabel.Size = UDim2.new(0, 260, 0, 70)
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
            "Slax Hub | FPS: %d | Ping: %d ms\nParry: %s | Parries: %d\n📍 dist: %d | spd: %d | trig: %d",
            frames, ping,
            AutoParryEnabled and "ON" or "OFF",
            ParryCount,
            math.floor(LastInfo.dist),
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

-- =========================================
-- Manual Spam Button (🎯 Old Style)
-- =========================================
local ManualGui = Instance.new("ScreenGui")
ManualGui.Name = "SlaxManual_" .. math.random(1, 99999)
ManualGui.Parent = GetGuiParent()
ManualGui.ResetOnSpawn = false
ManualGui.IgnoreGuiInset = true
ManualGui.DisplayOrder = 99998

local ManualBtn = Instance.new("TextButton")
ManualBtn.Parent = ManualGui
ManualBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
ManualBtn.BorderSizePixel = 0
ManualBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
ManualBtn.Size = UDim2.new(0, 140, 0, 45)
ManualBtn.Font = Enum.Font.GothamBold
ManualBtn.Text = "🎯 Trigger: OFF"
ManualBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ManualBtn.TextSize = 15
ManualBtn.AutoButtonColor = false
ManualBtn.Active = true

local ManualCorner = Instance.new("UICorner")
ManualCorner.CornerRadius = UDim.new(0, 8)
ManualCorner.Parent = ManualBtn

local ManualStroke = Instance.new("UIStroke")
ManualStroke.Parent = ManualBtn
ManualStroke.Color = Color3.fromRGB(255, 255, 255)
ManualStroke.Thickness = 1.5
ManualStroke.Transparency = 0.3

local dragging, dragInput, dragStart, startPos, dragMoved
local lastTap = 0

ManualBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = ManualBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ManualBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            dragMoved = true
        end
        ManualBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function UpdateManualBtn()
    if ManualSpamEnabled then
        ManualBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        ManualBtn.Text = "🎯 Trigger: ON"
        ManualStroke.Color = Color3.fromRGB(180, 255, 200)
    else
        ManualBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        ManualBtn.Text = "🎯 Trigger: OFF"
        ManualStroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

ManualBtn.MouseButton1Click:Connect(function()
    if dragMoved then return end
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateManualBtn()
end)

ManualBtn.TouchTap:Connect(function()
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateManualBtn()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        ManualSpamEnabled = not ManualSpamEnabled
        UpdateManualBtn()
    end
end)

UpdateManualBtn()

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "⚡ Auto Parry (Ping Adaptive)",
    Desc = "Fires earlier based on your ping",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then ballLocks = {} end
    end
})

MainTab:Slider({
    Title = "Base Distance (studs)",
    Desc = "Base trigger distance",
    Value = { Min = 5, Max = 100, Default = 25 },
    Callback = function(Value) ParryDistance = Value end
})

MainTab:Slider({
    Title = "Ping Compensation",
    Desc = "Higher = Earlier parry (150 = default)",
    Value = { Min = 0, Max = 300, Default = 150 },
    Callback = function(Value) PingCompensation = Value / 100 end
})

MainTab:Slider({
    Title = "Safety Buffer (studs)",
    Desc = "Extra distance for safety",
    Value = { Min = 0, Max = 30, Default = 8 },
    Callback = function(Value) SafetyBuffer = Value end
})

MainTab:Toggle({
    Title = "⚡ Auto Spam (Near Players)",
    Desc = "Spams when players are within range",
    Value = false,
    Callback = function(Value) AutoSpamEnabled = Value end
})

MainTab:Slider({
    Title = "Spam Range (studs)",
    Desc = "Distance to trigger auto spam",
    Value = { Min = 20, Max = 150, Default = 60 },
    Callback = function(Value) SpamRange = Value end
})

MainTab:Slider({
    Title = "CPS (Clicks Per Second)",
    Desc = "Spam rate",
    Value = { Min = 50, Max = 500, Default = 350 },
    Callback = function(Value) AutoSpamCPS = Value end
})

SettingsTab:Button({
    Title = "🔄 Reset Ball Locks",
    Desc = "Clear stuck ball locks",
    Callback = function()
        ballLocks = {}
        ParryCount = 0
    end
})

SettingsTab:Button({
    Title = "🗑️ Destroy UI",
    Callback = function()
        Window:Destroy()
        StatsGui:Destroy()
        ManualGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub Loaded ✅",
    Content = "Auto Parry + Auto Spam ready",
    Duration = 5
})

print("[Slax Hub] ✅ Loaded - No Slash version")
