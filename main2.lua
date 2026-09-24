-- Blade Ball Script - Slax Hub v20.2 (Ultra Manual Spam)
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
local AutoSpamCPS = 350

-- ⚙️ FIXED Config
local GLOBAL_LOCK = 0.20
local BALL_LOCK_DURATION = 0.5
local MAX_PARRY_DISTANCE = 150
local MAX_PARRY_ANGLE = 85
local SPAM_PROXIMITY_RANGE = 60

-- 🌸💜 ULTRA MANUAL SPAM Config
local MANUAL_SPAM_CPS = 500    -- ⚡ أقصى سرعة
local MANUAL_SPAM_BURST = 10   -- ⚡ 10 رميات per burst

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
    while task.wait(0.1) do
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
        NearPlayerCached = closest <= 30
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

-- =========================================
-- 🎯 POWERFUL AUTO ACCURACY
-- =========================================
local AutoAccuracyDebug = { Value = 50, Reason = "Starting" }

local function GetAutoAccuracy(ballSpeed, curveActive, isClose)
    local pingMs = GetPing() * 1000
    local base = 50

    if pingMs < 30 then base = base - 5
    elseif pingMs < 60 then base = base
    elseif pingMs < 90 then base = base + 15
    elseif pingMs < 130 then base = base + 25
    else base = base + 35 end

    if ballSpeed > 250 then base = base + 40
    elseif ballSpeed > 200 then base = base + 32
    elseif ballSpeed > 150 then base = base + 24
    elseif ballSpeed > 120 then base = base + 18
    elseif ballSpeed > 90 then base = base + 12
    elseif ballSpeed > 60 then base = base + 6 end

    if curveActive then base = base + 12 end
    if isClose then base = base + 10 end

    return math.clamp(math.floor(base), 1, 100)
end

-- =========================================
-- ⚔️ Auto Parry - FIXED
-- =========================================
local lastParryTime = 0
local ballLocks = {}
local ballNameLocks = {}

task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then
                ballLocks[ball] = nil
            end
        end
        for name, t in pairs(ballNameLocks) do
            if now >= t then
                ballNameLocks[name] = nil
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        ballNameLocks = {}
        return
    end

    local now = tick()
    local ping = GetPing()

    if (now - lastParryTime) < GLOBAL_LOCK then return end

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
    local bestSpeed = 0
    local bestCurve = false
    local bestDistance = 0

    for i = 1, #balls do
        local ball = balls[i]
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end

        if ballLocks[ball] then continue end
        if ballNameLocks[ball.Name] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        if not IsWithinParryAngle(playerPos, ballPos, velocity) then continue end

        local frames = 1
        if speed < 60 then frames = 4
        elseif speed < 100 then frames = 3
        elseif speed < 150 then frames = 2
        else frames = 1 end

        local predictedPos = ballPos + (velocity * (frames * (1/60)))
        local predictedDistance = (playerPos - predictedPos).Magnitude

        if predictedDistance > MAX_PARRY_DISTANCE then continue end

        local targetAttr = ball:GetAttribute("target")
        local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)
        if not isTarget then continue end

        local _, curveActive = TrackBall(ball)
        local timeToReach = predictedDistance / speed

        if timeToReach < bestTime then
            bestTime = timeToReach
            bestBall = ball
            bestSpeed = speed
            bestCurve = curveActive
            bestDistance = predictedDistance
        end
    end

    if bestBall then
        local usedAccuracy
        if AutoAccuracyEnabled then
            usedAccuracy = GetAutoAccuracy(bestSpeed, bestCurve, NearPlayerCached)
            AutoAccuracyDebug.Value = usedAccuracy
            AutoAccuracyDebug.Reason = string.format("Ping:%d Speed:%d",
                math.floor(ping * 1000), math.floor(bestSpeed))
        else
            usedAccuracy = ParryAccuracyValue
        end

        local accuracyFactor = (usedAccuracy / 100) * 0.45
        local timeWindow = ping + 0.10 + accuracyFactor

        if (bestTime <= timeWindow and bestTime >= -0.05) or bestDistance <= 20 then
            lastParryTime = now
            ballLocks[bestBall] = now + BALL_LOCK_DURATION
            ballNameLocks[bestBall.Name] = now + BALL_LOCK_DURATION
            FireParry()
        end
    end
end)

-- =========================================
-- ⚡ Auto Spam (200-500 CPS)
-- =========================================
local lastSpamTime = 0
local spamPlayerCheck = 0
local nearPlayerSpam = false

RunService.Heartbeat:Connect(function()
    if not AutoSpamEnabled then return end

    local now = tick()

    if (now - spamPlayerCheck) > 0.05 then
        spamPlayerCheck = now
        nearPlayerSpam = false

        local character = LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local playerPos = hrp.Position
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local c = p.Character
                        if c then
                            local p_hrp = c:FindFirstChild("HumanoidRootPart")
                            if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SPAM_PROXIMITY_RANGE then
                                nearPlayerSpam = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if not nearPlayerSpam then return end
    if (now - lastSpamTime) < 0.016 then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    local burst = math.max(1, math.floor(AutoSpamCPS / 60))
    for _ = 1, burst do
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
-- 🌸💜 ULTRA MANUAL SPAM (Instantly fires on toggle)
-- =========================================
local lastManualSpamTime = 0

RunService.Heartbeat:Connect(function()
    if not ManualSpamEnabled then return end

    local now = tick()
    if (now - lastManualSpamTime) < 0.005 then return end  -- ⚡ كل 5ms فقط
    lastManualSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    -- ⚡ 10 رميات لكل burst (500+ CPS)
    for _ = 1, MANUAL_SPAM_BURST do
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
-- 🌸💜 FLOATING MANUAL SPAM TOGGLE BUTTON
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

local ManualBtn = Instance.new("TextButton")
ManualBtn.Name = "ManualSpamBtn"
ManualBtn.Parent = ManualGui
ManualBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
ManualBtn.BackgroundTransparency = 0.15
ManualBtn.BorderSizePixel = 0
ManualBtn.Position = UDim2.new(0.35, 0, 0.42, 0)
ManualBtn.Size = UDim2.new(0, 100, 0, 42)
ManualBtn.Font = Enum.Font.GothamBold
ManualBtn.Text = "SPAM: OFF"
ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
ManualBtn.TextSize = 13
ManualBtn.AutoButtonColor = false
ManualBtn.Active = true
ManualBtn.Selectable = true

local ManualCorner = Instance.new("UICorner")
ManualCorner.CornerRadius = UDim.new(0, 10)
ManualCorner.Parent = ManualBtn

local ManualStroke = Instance.new("UIStroke")
ManualStroke.Parent = ManualBtn
ManualStroke.Thickness = 1.5
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

local ManualGlow = Instance.new("UIStroke")
ManualGlow.Parent = ManualBtn
ManualGlow.Thickness = 4
ManualGlow.Transparency = 0.7
ManualGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local GlowGradient = Instance.new("UIGradient")
GlowGradient.Parent = ManualGlow
GlowGradient.Rotation = 45
GlowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(210, 100, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 110, 255))
})

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
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
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

-- 🌸💜 ULTRA TOGGLE - Fires immediately on activation
local function ToggleManualSpam()
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateManualBtnVisual()

    -- ⚡ لو مفعل، أطلق فوراً burst قوي
    if ManualSpamEnabled then
        task.spawn(function()
            local remote, args = GetParryRemote()
            if not remote or not args then return end

            -- 🚀 Initial Mega Burst: 30 رمية فورية
            for _ = 1, 30 do
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
    end
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
AccLabel.Position = UDim2.new(0.68, 0, 0.02, 0)
AccLabel.Size = UDim2.new(0, 200, 0, 60)
AccLabel.Font = Enum.Font.GothamBold
AccLabel.Text = "🎯 Accuracy: 50"
AccLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
AccLabel.TextSize = 12

local AccCorner = Instance.new("UICorner")
AccCorner.CornerRadius = UDim.new(0, 10)
AccCorner.Parent = AccLabel

local AccStroke = Instance.new("UIStroke")
AccStroke.Parent = AccLabel
AccStroke.Color = Color3.fromRGB(255, 180, 230)
AccStroke.Thickness = 1.2

task.spawn(function()
    while task.wait(0.15) do
        if AutoParryEnabled and AutoAccuracyEnabled then
            local value = AutoAccuracyDebug.Value
            local color
            if value < 30 then color = Color3.fromRGB(100, 255, 100)
            elseif value < 60 then color = Color3.fromRGB(255, 220, 100)
            elseif value < 85 then color = Color3.fromRGB(255, 150, 100)
            else color = Color3.fromRGB(255, 100, 100) end

            AccLabel.Text = string.format("🎯 ACC: %d\n%s", value, AutoAccuracyDebug.Reason)
            AccLabel.TextColor3 = color
            AccStroke.Color = color
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
    Title = "⚔️ Auto Parry",
    Desc = "Fixed: No double + handles fast balls",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballTracking = {}
            ballLocks = {}
            ballNameLocks = {}
        end
    end
})

MainTab:Toggle({
    Title = "🎯 Auto Accuracy",
    Desc = "Powerful auto-adjust",
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

MainTab:Slider({
    Title = "Auto Spam CPS",
    Desc = "200-500 CPS",
    Value = {
        Min = 200,
        Max = 500,
        Default = 350,
    },
    Callback = function(Value)
        AutoSpamCPS = Value
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
    Title = "Slax Hub v20.2 🌸💜",
    Content = "Ultra Manual Spam - Instant 30 shot burst on toggle!",
    Duration = 6
})
