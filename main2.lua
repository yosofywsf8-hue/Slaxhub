-- Slax Hub - Blade Ball Script
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(700, 500),
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

local APTab = Window:Tab({ Title = "AP", Icon = "sword" })
local OptimTab = Window:Tab({ Title = "OPTIM", Icon = "zap" })
local SocialTab = Window:Tab({ Title = "SOCIAL", Icon = "users" })

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
local AutoAccuracyEnabled = false
local AccuracyValue = 100
local SpamThreshold = 1
local CurveType = "straight"
local CPSValue = 225
local AnimFix = false

local ShowBallStats = false
local ShowFpsUI = true
local ShowKeybindUI = false
local ShowSpamUI = false
local ShowTriggerBotUI = false
local ShowImmortalUI = false
local ShowCurvesUI = false
local ImmortalEnabled = false

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
-- Main Loop
-- =========================================
local lastParryTime = 0
local GLOBAL_LOCK = 0.15
local BALL_LOCK = 0.5
local ballLocks = {}

local function WillHitPlayer(ballPos, ballVel, playerPos)
    local speed = ballVel.Magnitude
    if speed < 1 then return false end
    local dir = ballVel.Unit
    local toPlayer = playerPos - ballPos
    local dot = dir:Dot(toPlayer.Unit)
    if dot <= 0.4 then return false end
    local projection = toPlayer:Dot(dir)
    if projection <= 0 then return false end
    local closestPoint = ballPos + (dir * projection)
    local missDistance = (playerPos - closestPoint).Magnitude
    return missDistance <= 8
end

task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then ballLocks[ball] = nil end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        return
    end

    local now = tick()
    if (now - lastParryTime) < GLOBAL_LOCK then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end

    local distanceThreshold = 5 + ((AccuracyValue / 100) * 35)

    local bestBall = nil
    local bestDistance = math.huge

    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        local distance = (playerPos - ballPos).Magnitude
        if distance > 100 then continue end
        if distance > distanceThreshold then continue end
        if not WillHitPlayer(ballPos, velocity, playerPos) then continue end

        if distance < bestDistance then
            bestDistance = distance
            bestBall = ball
        end
    end

    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + BALL_LOCK
        FireParry()
    end
end)

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
                if p_hrp and (p_hrp.Position - playerPos).Magnitude <= 60 then
                    nearPlayer = true
                    break
                end
            end
        end
    end

    if not nearPlayer then return end
    if (now - lastSpamTime) < (1 / math.max(CPSValue, 1)) then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    local burst = math.max(1, math.floor(CPSValue / 60))
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
-- GetGuiParent
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

-- =========================================
-- FPS UI
-- =========================================
local FpsGui = Instance.new("ScreenGui")
FpsGui.Name = "SlaxFpsUI_" .. math.random(1, 99999)
FpsGui.Parent = GetGuiParent()
FpsGui.ResetOnSpawn = false
FpsGui.IgnoreGuiInset = true
FpsGui.DisplayOrder = 99999

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Name = "FpsLabel"
FpsLabel.Parent = FpsGui
FpsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
FpsLabel.BackgroundTransparency = 0.3
FpsLabel.BorderSizePixel = 0
FpsLabel.Position = UDim2.new(0.78, 0, 0.02, 0)
FpsLabel.Size = UDim2.new(0, 220, 0, 30)
FpsLabel.Font = Enum.Font.GothamBold
FpsLabel.Text = "FPS: 0 | PING: 0 ms"
FpsLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
FpsLabel.TextSize = 13

local FpsCorner = Instance.new("UICorner")
FpsCorner.CornerRadius = UDim.new(0, 8)
FpsCorner.Parent = FpsLabel

local FpsStroke = Instance.new("UIStroke")
FpsStroke.Parent = FpsLabel
FpsStroke.Color = Color3.fromRGB(255, 180, 80)
FpsStroke.Thickness = 1.2

local FpsCounter = 0
local FpsTime = tick()

RunService.RenderStepped:Connect(function()
    FpsCounter = FpsCounter + 1
    if (tick() - FpsTime) >= 1 then
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        FpsLabel.Text = string.format("FPS: %d | PING: %d ms", FpsCounter, ping)
        FpsCounter = 0
        FpsTime = tick()
    end
end)

-- =========================================
-- Ball Stats UI
-- =========================================
local BallStatsGui = Instance.new("ScreenGui")
BallStatsGui.Name = "SlaxBallStats_" .. math.random(1, 99999)
BallStatsGui.Parent = GetGuiParent()
BallStatsGui.ResetOnSpawn = false
BallStatsGui.IgnoreGuiInset = true
BallStatsGui.DisplayOrder = 99998

local BallStatsLabel = Instance.new("TextLabel")
BallStatsLabel.Parent = BallStatsGui
BallStatsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
BallStatsLabel.BackgroundTransparency = 0.3
BallStatsLabel.BorderSizePixel = 0
BallStatsLabel.Position = UDim2.new(0.02, 0, 0.02, 0)
BallStatsLabel.Size = UDim2.new(0, 220, 0, 50)
BallStatsLabel.Font = Enum.Font.GothamBold
BallStatsLabel.Text = "No Balls"
BallStatsLabel.TextColor3 = Color3.fromRGB(255, 180, 230)
BallStatsLabel.TextSize = 11
BallStatsLabel.Visible = false

local BallStatsCorner = Instance.new("UICorner")
BallStatsCorner.CornerRadius = UDim.new(0, 8)
BallStatsCorner.Parent = BallStatsLabel

task.spawn(function()
    while task.wait(0.2) do
        BallStatsLabel.Visible = ShowBallStats
        if ShowBallStats then
            local ballsFolder = WS:FindFirstChild("Balls")
            local count = 0
            local closest = math.huge
            local closestSpeed = 0

            if ballsFolder then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                for _, ball in ipairs(ballsFolder:GetChildren()) do
                    if not ball:IsA("BasePart") then continue end
                    if ball:GetAttribute("realBall") == false then continue end
                    count = count + 1
                    if hrp then
                        local d = (hrp.Position - ball.Position).Magnitude
                        if d < closest then
                            closest = d
                            closestSpeed = ball.AssemblyLinearVelocity.Magnitude
                        end
                    end
                end
            end

            if count > 0 then
                BallStatsLabel.Text = string.format("Balls: %d\nClosest: %d studs\nSpeed: %d", 
                    count, math.floor(closest), math.floor(closestSpeed))
            else
                BallStatsLabel.Text = "No Balls"
            end
        end
    end
end)

-- =========================================
-- Spam UI
-- =========================================
local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpamUI_" .. math.random(1, 99999)
SpamGui.Parent = GetGuiParent()
SpamGui.ResetOnSpawn = false
SpamGui.IgnoreGuiInset = true
SpamGui.DisplayOrder = 99997

local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "SpamBtn"
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
SpamBtn.BorderSizePixel = 0
SpamBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
SpamBtn.Size = UDim2.new(0, 140, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "🎯 Trigger: OFF"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 15
SpamBtn.AutoButtonColor = false
SpamBtn.Active = true
SpamBtn.Visible = false

local SpamCorner = Instance.new("UICorner")
SpamCorner.CornerRadius = UDim.new(0, 8)
SpamCorner.Parent = SpamBtn

local SpamStroke = Instance.new("UIStroke")
SpamStroke.Parent = SpamBtn
SpamStroke.Color = Color3.fromRGB(255, 255, 255)
SpamStroke.Thickness = 1.5

local ManualSpamEnabled = false
local dragging = false
local dragInput, dragStart, startPos, dragMoved
local lastTap = 0

SpamBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = SpamBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

SpamBtn.InputChanged:Connect(function(input)
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
        SpamBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function UpdateSpamBtn()
    if ManualSpamEnabled then
        SpamBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        SpamBtn.Text = "🎯 Trigger: ON"
        SpamStroke.Color = Color3.fromRGB(180, 255, 200)
    else
        SpamBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        SpamBtn.Text = "🎯 Trigger: OFF"
        SpamStroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

SpamBtn.MouseButton1Click:Connect(function()
    if dragMoved then return end
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateSpamBtn()
end)

SpamBtn.TouchTap:Connect(function()
    local now = tick()
    if now - lastTap < 0.3 then return end
    lastTap = now
    ManualSpamEnabled = not ManualSpamEnabled
    UpdateSpamBtn()
end)

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

UpdateSpamBtn()

task.spawn(function()
    while task.wait(0.2) do
        SpamBtn.Visible = ShowSpamUI
    end
end)

-- =========================================
-- UI Controls
-- =========================================

-- ═══════════════ AP TAB ═══════════════

APTab:Toggle({
    Title = "Auto Parry",
    Desc = "Auto parry balls that will hit you",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
    end
})

APTab:Slider({
    Title = "Accuracy",
    Desc = "Higher = Earlier parry",
    Value = {
        Min = 1,
        Max = 100,
        Default = 100,
    },
    Callback = function(Value)
        AccuracyValue = Value
    end
})

APTab:Toggle({
    Title = "Auto Accuracy",
    Desc = "Auto-adjust timing",
    Value = false,
    Callback = function(Value)
        AutoAccuracyEnabled = Value
    end
})

APTab:Toggle({
    Title = "Auto Spam",
    Desc = "Spams near players",
    Value = false,
    Callback = function(Value)
        AutoSpamEnabled = Value
    end
})

APTab:Slider({
    Title = "Spam Threshold",
    Desc = "Minimum balls to trigger spam",
    Value = {
        Min = 1,
        Max = 10,
        Default = 1,
    },
    Callback = function(Value)
        SpamThreshold = Value
    end
})

APTab:Dropdown({
    Title = "Curve Type",
    Values = { "straight", "left", "right", "up", "down" },
    Value = "straight",
    Callback = function(Value)
        CurveType = Value
    end
})

APTab:Slider({
    Title = "CPS",
    Desc = "Spam clicks per second",
    Value = {
        Min = 50,
        Max = 500,
        Default = 225,
    },
    Callback = function(Value)
        CPSValue = Value
    end
})

APTab:Toggle({
    Title = "Anim Fix",
    Desc = "Fix animation glitches",
    Value = false,
    Callback = function(Value)
        AnimFix = Value
    end
})

APTab:Toggle({
    Title = "Show Ball Stats",
    Desc = "Show ball count and info",
    Value = false,
    Callback = function(Value)
        ShowBallStats = Value
    end
})

APTab:Toggle({
    Title = "Fps UI",
    Desc = "Show FPS and ping",
    Value = true,
    Callback = function(Value)
        ShowFpsUI = Value
        FpsGui.Enabled = Value
    end
})

APTab:Toggle({
    Title = "Show Keybind UI",
    Desc = "Show keybind hints",
    Value = false,
    Callback = function(Value)
        ShowKeybindUI = Value
    end
})

APTab:Toggle({
    Title = "Show Spam UI",
    Desc = "Show manual spam button",
    Value = false,
    Callback = function(Value)
        ShowSpamUI = Value
    end
})

APTab:Toggle({
    Title = "Show TriggerBot UI",
    Desc = "Show triggerbot UI",
    Value = false,
    Callback = function(Value)
        ShowTriggerBotUI = Value
    end
})

APTab:Toggle({
    Title = "Show Immortal UI",
    Desc = "Show immortal status",
    Value = false,
    Callback = function(Value)
        ShowImmortalUI = Value
    end
})

APTab:Toggle({
    Title = "Show Curves UI",
    Desc = "Show curve visualization",
    Value = false,
    Callback = function(Value)
        ShowCurvesUI = Value
    end
})

APTab:Toggle({
    Title = "Immortal (bannable)",
    Desc = "⚠️ BANNABLE - Use at your own risk",
    Value = false,
    Callback = function(Value)
        ImmortalEnabled = Value
    end
})

-- ═══════════════ OPTIM TAB ═══════════════

OptimTab:Toggle({
    Title = "FPS Boost",
    Desc = "Remove visual effects for FPS",
    Value = false,
    Callback = function(Value)
        if Value then
            pcall(function()
                for _, obj in pairs(WS:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    end
                end
            end)
        end
    end
})

OptimTab:Toggle({
    Title = "Disable Fog",
    Desc = "Remove fog effect",
    Value = false,
    Callback = function(Value)
        pcall(function()
            game:GetService("Lighting").FogEnd = Value and 100000 or 10000
        end)
    end
})

OptimTab:Button({
    Title = "Clear Cache",
    Desc = "Clear temporary data",
    Callback = function()
        pcall(function()
            for _, obj in pairs(WS:GetDescendants()) do
                if obj.Name:find("Debris") then
                    obj:Destroy()
                end
            end
        end)
    end
})

-- ═══════════════ SOCIAL TAB ═══════════════

SocialTab:Paragraph({
    Title = "About",
    Desc = "Slax Hub - Blade Ball Script - Made by yossef",
})

SocialTab:Button({
    Title = "Copy Discord",
    Desc = "discord.gg/slaxhub",
    Callback = function()
        pcall(function()
            if setclipboard then
                setclipboard("discord.gg/slaxhub")
            end
        end)
    end
})

SocialTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
        FpsGui:Destroy()
        BallStatsGui:Destroy()
        SpamGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub",
    Content = "Loaded successfully",
    Duration = 5
})
