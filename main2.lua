-- Blade Ball Script - Slax Hub v19.7 (Smaller SPAM Button)
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "Open Slax Hub",
    Icon = "sword",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 80, 255)),
    OnlyMobile = false,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamEnabled = false
local ParryAccuracyValue = 50
local AutoAccuracyEnabled = true

-- ⚙️ Config
local CLOSE_COMBAT_RANGE = 30
local GLOBAL_LOCK_FAR = 0.15
local GLOBAL_LOCK_NEAR = 0.06
local BALL_LOCK_DURATION = 0.5
local MAX_PARRY_DISTANCE = 150
local MAX_PARRY_ANGLE = 85

local PRE_PARRY_BASE = 0.15
local PRE_PARRY_FAST_BONUS = 0.25
local SPAM_PROXIMITY_RANGE = 60

-- =========================================
-- Token
-- =========================================
local _token = nil
for _, Function in getgc(true) do
    if type(Function) == 'function' and debug.info(Function, 's'):find('PRY', 1, true) then
        for _, value in debug.getupvalues(Function) do
            if type(value) == 'function' then
                _token = value
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(_remote_uid)
    if not _token then return "" end
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)
    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

-- =========================================
-- Hooking
-- =========================================
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
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
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

-- =========================================
-- Cache Remotes
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
        args[1],
        args[2],
        _tokenize(args[2]),
        0.5,
        workspace.CurrentCamera.CFrame,
        {},
        {0, 0},
        false
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
-- Close Combat Detection
-- =========================================
local NearPlayerCached = false
local ClosestPlayerDist = math.huge

task.spawn(function()
    while task.wait(0.05) do
        if not AutoParryEnabled and not AutoSpamEnabled then
            NearPlayerCached = false
            ClosestPlayerDist = math.huge
            continue
        end

        local character = LocalPlayer.Character
        if not character then
            NearPlayerCached = false
            ClosestPlayerDist = math.huge
            continue
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            NearPlayerCached = false
            ClosestPlayerDist = math.huge
            continue
        end

        local playerPos = hrp.Position
        local closest = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local p_hrp = char:FindFirstChild("HumanoidRootPart")
            if not p_hrp then continue end
            local d = (p_hrp.Position - playerPos).Magnitude
            if d < closest then closest = d end
        end

        ClosestPlayerDist = closest
        NearPlayerCached = closest <= CLOSE_COMBAT_RANGE
    end
end)

-- =========================================
-- Anti Curve
-- =========================================
local ballTracking = {}

local function TrackBall(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return 0, false end

    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = { lastVel = vel, curveScore = 0, curveActive = false }
        return 0, false
    end

    local prevDir = data.lastVel.Unit
    local currDir = vel.Unit
    local dot = prevDir:Dot(currDir)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))

    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
    else
        data.curveScore = data.curveScore * 0.95
    end

    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel

    return data.curveScore, data.curveActive
end

task.spawn(function()
    while task.wait(2) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then ballTracking[ball] = nil end
        end
    end
end)

local function IsWithinParryAngle(playerPos, ballPos, ballVel)
    local toPlayer = (playerPos - ballPos).Unit
    local velDir = ballVel.Unit
    local dot = velDir:Dot(toPlayer)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= MAX_PARRY_ANGLE
end

local function GetPredictionFrames(ballSpeed)
    if ballSpeed > 200 then return 1
    elseif ballSpeed > 150 then return 2
    elseif ballSpeed > 100 then return 3
    elseif ballSpeed > 60 then return 4
    else return 3 end
end

local function GetPreParryWindow(ballSpeed)
    if ballSpeed > 200 then
        return PRE_PARRY_BASE + PRE_PARRY_FAST_BONUS * 1.2
    elseif ballSpeed > 150 then
        return PRE_PARRY_BASE + PRE_PARRY_FAST_BONUS
    elseif ballSpeed > 120 then
        return PRE_PARRY_BASE + PRE_PARRY_FAST_BONUS * 0.7
    elseif ballSpeed > 80 then
        return PRE_PARRY_BASE + PRE_PARRY_FAST_BONUS * 0.4
    else
        return PRE_PARRY_BASE
    end
end

-- =========================================
-- Auto Accuracy
-- =========================================
local AutoAccuracyDebug = { Value = 50, Reason = "Starting" }

local function GetAutoAccuracy(ballSpeed, curveActive, isClose)
    local pingMs = GetPing() * 1000
    local base = 50

    if pingMs < 30 then base = base - 5
    elseif pingMs < 60 then base = base
    elseif pingMs < 90 then base = base + 10
    elseif pingMs < 130 then base = base + 18
    else base = base + 25 end

    if ballSpeed > 200 then base = base + 22
    elseif ballSpeed > 150 then base = base + 15
    elseif ballSpeed > 100 then base = base + 10
    elseif ballSpeed > 60 then base = base + 5 end

    if curveActive then base = base + 8 end
    if isClose then base = base + 5 end

    return math.clamp(math.floor(base), 1, 100)
end

-- =========================================
-- Auto Parry
-- =========================================
local lastParryTime = 0
local ballLocks = {}

task.spawn(function()
    while task.wait(0.5) do
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
    local ping = GetPing()

    local globalLock = NearPlayerCached and GLOBAL_LOCK_NEAR or GLOBAL_LOCK_FAR
    if (now - lastParryTime) < globalLock then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local balls = ballsFolder:GetChildren()
    local bestBall = nil
    local bestTime = math.huge

    for i = 1, #balls do
        local ball = balls[i]
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

        local frames = GetPredictionFrames(speed)
        local predictedPos = ballPos + (velocity * (frames * (1/60)))
        local predictedDistance = (playerPos - predictedPos).Magnitude

        if predictedDistance > MAX_PARRY_DISTANCE then continue end

        local targetAttr = ball:GetAttribute("target")
        local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
        if not isTarget then continue end

        local curveScore, curveActive = TrackBall(ball)
        local curveBonus = curveActive and math.min(0.25, curveScore * 0.05) or 0

        local timeToReach = predictedDistance / speed

        local usedAccuracy
        if AutoAccuracyEnabled then
            usedAccuracy = GetAutoAccuracy(speed, curveActive, NearPlayerCached)
            AutoAccuracyDebug.Value = usedAccuracy
            AutoAccuracyDebug.Reason = string.format("Ping:%dms Speed:%d",
                math.floor(GetPing() * 1000), math.floor(speed))
        else
            usedAccuracy = ParryAccuracyValue
        end

        local accuracyFactor = (usedAccuracy / 100) * 0.3

        local closeBonus = 0
        if NearPlayerCached then
            if ClosestPlayerDist < 15 then closeBonus = 0.10
            elseif ClosestPlayerDist < 25 then closeBonus = 0.06
            else closeBonus = 0.03 end
        end

        local preParryWindow = GetPreParryWindow(speed)

        local timeWindow = ping + 0.30 + accuracyFactor + curveBonus + closeBonus + preParryWindow

        if (timeToReach <= timeWindow) and (timeToReach >= -0.1) then
            if timeToReach < bestTime then
                bestTime = timeToReach
                bestBall = ball
            end
        end

        if predictedDistance <= 30 and speed > 150 then
            if timeToReach < bestTime then
                bestTime = timeToReach
                bestBall = ball
            end
        end
    end

    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + BALL_LOCK_DURATION
        FireParry()
    end
end)

-- =========================================
-- Auto Spam
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
        if p == LocalPlayer then continue end
        local c = p.Character
        if c then
            local p_hrp = c:FindFirstChild("HumanoidRootPart")
            if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SPAM_PROXIMITY_RANGE then
                nearPlayer = true
                break
            end
        end
    end

    if not nearPlayer then return end
    if (now - lastSpamTime) < 0.02 then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    for _ = 1, 5 do
        local packet = {
            args[1],
            args[2],
            _tokenize(args[2]),
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
            false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- MANUAL SPAM TOGGLE - Continuous Spam Loop
-- =========================================
local lastManualSpamTime = 0

RunService.Heartbeat:Connect(function()
    if not ManualSpamEnabled then return end

    local now = tick()
    if (now - lastManualSpamTime) < 0.02 then return end
    lastManualSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    for _ = 1, 5 do
        local packet = {
            args[1],
            args[2],
            _tokenize(args[2]),
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
            false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- 🌸💜 FLOATING MANUAL SPAM TOGGLE BUTTON (SMALLER)
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
        if gui.Name:find("SlaxManualSpam") then
            gui:Destroy()
        end
    end
end)

local ManualGui = Instance.new("ScreenGui")
ManualGui.Name = "SlaxManualSpam_" .. math.random(1, 99999)
ManualGui.Parent = GetGuiParent()
ManualGui.ResetOnSpawn = false
ManualGui.IgnoreGuiInset = true
ManualGui.DisplayOrder = 99999

-- ✅ صغير: 120x50 بدل 200x80
local ManualBtn = Instance.new("TextButton")
ManualBtn.Name = "ManualSpamBtn"
ManualBtn.Parent = ManualGui
ManualBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
ManualBtn.BackgroundTransparency = 0.15
ManualBtn.BorderSizePixel = 0
ManualBtn.Position = UDim2.new(0.35, 0, 0.42, 0)
ManualBtn.Size = UDim2.new(0, 120, 0, 50)  -- ✅ أصغر
ManualBtn.Font = Enum.Font.GothamBold
ManualBtn.Text = "SPAM: OFF"
ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
ManualBtn.TextSize = 15  -- ✅ أصغر شوي
ManualBtn.AutoButtonColor = false
ManualBtn.Active = true
ManualBtn.Selectable = true

-- زوايا دائرية
local ManualCorner = Instance.new("UICorner")
ManualCorner.CornerRadius = UDim.new(0, 12)  -- ✅ أصغر
ManualCorner.Parent = ManualBtn

-- 🌸💜 الحدود بتدرج وردي-بنفسجي
local ManualStroke = Instance.new("UIStroke")
ManualStroke.Parent = ManualBtn
ManualStroke.Thickness = 2
ManualStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Parent = ManualStroke
StrokeGradient.Rotation = 45
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(230, 80, 230)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 90, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 100, 255))
})

-- توهج خارجي (Glow)
local ManualGlow = Instance.new("UIStroke")
ManualGlow.Parent = ManualBtn
ManualGlow.Thickness = 6  -- ✅ أصغر
ManualGlow.Transparency = 0.75
ManualGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local GlowGradient = Instance.new("UIGradient")
GlowGradient.Parent = ManualGlow
GlowGradient.Rotation = 45
GlowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(210, 100, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 110, 255))
})

-- تدرج خفيف على الخلفية
local BgGradient = Instance.new("UIGradient")
BgGradient.Parent = ManualBtn
BgGradient.Rotation = 45
BgGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.00, 0.15),
    NumberSequenceKeypoint.new(0.50, 0.25),
    NumberSequenceKeypoint.new(1.00, 0.15)
})
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
})

-- 🎨 Update Visual based on Toggle State
local function UpdateManualBtnVisual()
    if ManualSpamEnabled then
        ManualBtn.Text = "SPAM: ON"
        ManualBtn.TextColor3 = Color3.fromRGB(80, 255, 180)

        TweenService:Create(BgGradient, TweenInfo.new(0.3), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
            })
        }):Play()

        TweenService:Create(StrokeGradient, TweenInfo.new(0.3), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(80, 255, 180)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(100, 255, 220)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 200, 255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(180, 220, 255))
            })
        }):Play()
    else
        ManualBtn.Text = "SPAM: OFF"
        ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)

        TweenService:Create(BgGradient, TweenInfo.new(0.3), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
            })
        }):Play()

        TweenService:Create(StrokeGradient, TweenInfo.new(0.3), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(230, 80, 230)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 90, 255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 100, 255))
            })
        }):Play()
    end
end

-- 🖐️ Drag System
local dragging, dragStart, startPos, dragMoved
local lastTap = 0

ManualBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = ManualBtn.Position
    end
end)

ManualBtn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            dragMoved = true
        end
        ManualBtn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

ManualBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- 🎯 Toggle Trigger
local function ToggleManualSpam()
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateManualBtnVisual()
end

ManualBtn.MouseButton1Click:Connect(function()
    if not dragMoved then
        local now = tick()
        if now - lastTap > 0.3 then
            lastTap = now
            ToggleManualSpam()
        end
    end
end)

ManualBtn.TouchTap:Connect(function()
    local now = tick()
    if now - lastTap > 0.3 then
        lastTap = now
        ToggleManualSpam()
    end
end)

-- ⌨️ E key toggles too
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        ToggleManualSpam()
    end
end)

-- =========================================
-- 📊 ACCURACY DISPLAY
-- =========================================
local AccGui = Instance.new("ScreenGui")
AccGui.Name = "SlaxAccDisplay_" .. math.random(1, 99999)
AccGui.Parent = GetGuiParent()
AccGui.ResetOnSpawn = false
AccGui.IgnoreGuiInset = true
AccGui.DisplayOrder = 99998

local AccLabel = Instance.new("TextLabel")
AccLabel.Name = "AccLabel"
AccLabel.Parent = AccGui
AccLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
AccLabel.BackgroundTransparency = 0.3
AccLabel.BorderSizePixel = 0
AccLabel.Position = UDim2.new(0.72, 0, 0.02, 0)
AccLabel.Size = UDim2.new(0, 180, 0, 55)
AccLabel.Font = Enum.Font.GothamBold
AccLabel.Text = "🎯 Accuracy: 50"
AccLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
AccLabel.TextSize = 13

local AccCorner = Instance.new("UICorner")
AccCorner.CornerRadius = UDim.new(0, 10)
AccCorner.Parent = AccLabel

local AccStroke = Instance.new("UIStroke")
AccStroke.Parent = AccLabel
AccStroke.Color = Color3.fromRGB(255, 180, 230)
AccStroke.Thickness = 1.5

task.spawn(function()
    while task.wait(0.2) do
        if AutoParryEnabled and AutoAccuracyEnabled then
            AccLabel.Text = string.format("🎯 AUTO: %d\n%s",
                AutoAccuracyDebug.Value, AutoAccuracyDebug.Reason)
            AccLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
            AccStroke.Color = Color3.fromRGB(255, 180, 230)
        elseif AutoParryEnabled then
            AccLabel.Text = "🎯 MANUAL: " .. ParryAccuracyValue
            AccLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
            AccStroke.Color = Color3.fromRGB(255, 200, 80)
        else
            AccLabel.Text = "🎯 Parry: OFF"
            AccLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            AccStroke.Color = Color3.fromRGB(150, 150, 150)
        end
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "⚔️ Auto Parry (Pre-Parry)",
    Desc = "Parries BEFORE ball arrives",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballTracking = {}
            ballLocks = {}
        end
    end
})

MainTab:Toggle({
    Title = "🎯 Auto Accuracy",
    Desc = "Auto-adjusts based on ping, speed, curve",
    Value = true,
    Callback = function(Value)
        AutoAccuracyEnabled = Value
    end
})

MainTab:Slider({
    Title = "Parry Accuracy (Manual)",
    Desc = "Used only when Auto is OFF",
    Value = {
        Min = 1,
        Max = 100,
        Default = 50,
    },
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

MainTab:Toggle({
    Title = "⚡ Auto Spam",
    Desc = "Spams near players (60 studs)",
    Value = false,
    Callback = function(Value)
        AutoSpamEnabled = Value
    end
})

SettingsTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
        ManualGui:Destroy()
        AccGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v19.7 🌸💜",
    Content = "Smaller SPAM button - Clean look",
    Duration = 6
})
