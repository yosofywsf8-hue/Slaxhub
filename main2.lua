-- Blade Ball Script - Slax Hub v22.0 (Clean Working)
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
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

local replicated_storage = game:GetService('ReplicatedStorage')
local workspace = game:GetService('Workspace')
local Stats = game:GetService('Stats')
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamEnabled = false
local AutoSlashEnabled = false
local AutoAccuracyEnabled = true

local PARRY_TIME_MS = 100
local GLOBAL_LOCK = 0.18
local BALL_LOCK_DURATION = 0.5

local CLOSE_RANGE_DISTANCE = 50
local VERY_CLOSE_DISTANCE = 25
local POINT_BLANK_DISTANCE = 12

local SLASH_DISTANCE = 35
local SLASH_SPEED_THRESHOLD = 80
local SLASH_COOLDOWN = 1.5
local lastSlashTime = 0
local SLASH_PAUSE_DURATION = 1.2

local ParryPaused = false
local ParryPauseUntil = 0

local AutoSpamCPS = 350
local SPAM_PROXIMITY_RANGE = 60
local SlashCount = 0

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
-- Remotes
-- =========================================
local _parryRemote = nil
local _parryArgs = nil
local _abilityRemote = nil

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

local function GetAbilityRemote()
    if not _abilityRemote or not _abilityRemote.Parent then
        _abilityRemote = nil
        local remotesFolder = replicated_storage:FindFirstChild("Remotes")
        if remotesFolder then
            _abilityRemote = remotesFolder:FindFirstChild("AbilityButtonPress")
        end
    end
    return _abilityRemote
end

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    local packet = {
        args[1], args[2], _tokenize(args[2]), 0.5,
        workspace.CurrentCamera.CFrame, {}, {0, 0}, false
    }
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
end

local function FireAbility()
    local remote = GetAbilityRemote()
    if not remote then return false end
    if remote:IsA('RemoteEvent') then
        remote:FireServer()
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer()
    end
    return true
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- ⚔️ Main Heartbeat
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
    local now = tick()

    -- ⏸️ Pause check
    if ParryPaused then
        if now >= ParryPauseUntil then
            ParryPaused = false
        else
            return  -- متوقف
        end
    end

    -- ⚔️ AUTO SLASHES OF FURY
    if AutoSlashEnabled then
        if (now - lastSlashTime) >= SLASH_COOLDOWN then
            local character = LocalPlayer.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local playerPos = hrp.Position
                    local ballsFolder = workspace:FindFirstChild("Balls")
                    if ballsFolder then
                        for _, ball in ipairs(ballsFolder:GetChildren()) do
                            if not ball:IsA("BasePart") then continue end
                            if ball:GetAttribute("realBall") == false then continue end

                            local ballPos = ball.Position
                            local velocity = ball.AssemblyLinearVelocity
                            local speed = velocity.Magnitude
                            if speed < SLASH_SPEED_THRESHOLD then continue end

                            local distance = (playerPos - ballPos).Magnitude
                            if distance > SLASH_DISTANCE then continue end

                            local toPlayer = (playerPos - ballPos).Unit
                            local dot = velocity.Unit:Dot(toPlayer)
                            if dot <= 0.3 then continue end

                            lastSlashTime = now
                            local success = FireAbility()
                            if success then
                                SlashCount = SlashCount + 1
                                -- ⏸️ Pause Auto Parry
                                ParryPaused = true
                                ParryPauseUntil = now + SLASH_PAUSE_DURATION
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    if not AutoParryEnabled then
        ballLocks = {}
        ballNameLocks = {}
        return
    end

    local ping = GetPing()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local balls = ballsFolder:GetChildren()

    -- 🎯 Point Blank / Very Close / Close
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

        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0 then continue end

        local distance = (playerPos - ballPos).Magnitude

        local shouldFire = false
        if distance <= POINT_BLANK_DISTANCE and dot > 0.2 then
            shouldFire = true
        elseif distance <= VERY_CLOSE_DISTANCE and dot > 0.3 then
            shouldFire = true
        elseif distance <= CLOSE_RANGE_DISTANCE and dot > 0.4 and speed > 40 then
            shouldFire = true
        end

        if shouldFire then
            lastParryTime = now
            ballLocks[ball] = now + BALL_LOCK_DURATION
            ballNameLocks[ball.Name] = now + BALL_LOCK_DURATION
            FireParry()
            return
        end
    end

    -- ⚙️ Normal Scan
    if (now - lastParryTime) < GLOBAL_LOCK then return end

    local bestBall = nil
    local bestTime = math.huge

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

        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0 then continue end

        local distance = (playerPos - ballPos).Magnitude
        if distance > 200 then continue end

        local timeToReach = distance / speed

        if timeToReach < bestTime then
            bestTime = timeToReach
            bestBall = ball
        end
    end

    if bestBall then
        -- ⏱️ MS-Based window
        local windowMs = PARRY_TIME_MS
        if not AutoAccuracyEnabled then
            windowMs = PARRY_TIME_MS
        else
            -- Auto: 50-250ms
            local ballSpeed = bestBall.AssemblyLinearVelocity.Magnitude
            local base = 100
            if ballSpeed > 200 then base = base + 80
            elseif ballSpeed > 150 then base = base + 60
            elseif ballSpeed > 100 then base = base + 40
            elseif ballSpeed > 60 then base = base + 20 end
            windowMs = base
        end

        local timeWindow = ping + (windowMs / 1000)

        if bestTime <= timeWindow and bestTime >= -0.1 then
            lastParryTime = now
            ballLocks[bestBall] = now + BALL_LOCK_DURATION
            ballNameLocks[bestBall.Name] = now + BALL_LOCK_DURATION
            FireParry()
        end
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
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local p_hrp = c:FindFirstChild("HumanoidRootPart")
                if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SPAM_PROXIMITY_RANGE then
                    nearPlayer = true
                    break
                end
            end
        end
    end

    if not nearPlayer then return end
    if (now - lastSpamTime) < 0.016 then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    local burst = math.max(1, math.floor(AutoSpamCPS / 60))
    for _ = 1, burst do
        local packet = {
            args[1], args[2], _tokenize(args[2]), 0.5,
            workspace.CurrentCamera.CFrame, {}, {0, 0}, false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- Manual Spam
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
        local packet = {
            args[1], args[2], _tokenize(args[2]), 0.5,
            workspace.CurrentCamera.CFrame, {}, {0, 0}, false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- Floating SPAM Button
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

local BgGradient = Instance.new("UIGradient")
BgGradient.Parent = ManualBtn
BgGradient.Rotation = 45
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
})

local function UpdateManualBtnVisual()
    if ManualSpamEnabled then
        ManualBtn.Text = "SPAM: ON"
        ManualBtn.TextColor3 = Color3.fromRGB(80, 255, 180)
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
        })
    else
        ManualBtn.Text = "SPAM: OFF"
        ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
        })
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

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        ToggleManualSpam()
    end
end)

-- =========================================
-- Slash Counter Display
-- =========================================
local SlashGui = Instance.new("ScreenGui")
SlashGui.Name = "SlaxSlashCounter_" .. math.random(1, 99999)
SlashGui.Parent = GetGuiParent()
SlashGui.ResetOnSpawn = false
SlashGui.IgnoreGuiInset = true
SlashGui.DisplayOrder = 99996

local SlashFrame = Instance.new("Frame")
SlashFrame.Name = "SlashFrame"
SlashFrame.Parent = SlashGui
SlashFrame.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
SlashFrame.BackgroundTransparency = 0.15
SlashFrame.BorderSizePixel = 0
SlashFrame.Position = UDim2.new(0.02, 0, 0.55, 0)
SlashFrame.Size = UDim2.new(0, 160, 0, 90)
SlashFrame.Active = true
SlashFrame.Draggable = true

local SlashCorner = Instance.new("UICorner")
SlashCorner.CornerRadius = UDim.new(0, 12)
SlashCorner.Parent = SlashFrame

local SlashStroke = Instance.new("UIStroke")
SlashStroke.Parent = SlashFrame
SlashStroke.Thickness = 2
SlashStroke.Color = Color3.fromRGB(255, 150, 200)

local SlashTitle = Instance.new("TextLabel")
SlashTitle.Name = "Title"
SlashTitle.Parent = SlashFrame
SlashTitle.BackgroundTransparency = 1
SlashTitle.Position = UDim2.new(0, 0, 0, 6)
SlashTitle.Size = UDim2.new(1, 0, 0, 20)
SlashTitle.Font = Enum.Font.GothamBold
SlashTitle.Text = "⚔️ SLASHES"
SlashTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
SlashTitle.TextSize = 12

local SlashCountLabel = Instance.new("TextLabel")
SlashCountLabel.Name = "Count"
SlashCountLabel.Parent = SlashFrame
SlashCountLabel.BackgroundTransparency = 1
SlashCountLabel.Position = UDim2.new(0, 0, 0, 26)
SlashCountLabel.Size = UDim2.new(1, 0, 0, 26)
SlashCountLabel.Font = Enum.Font.GothamBold
SlashCountLabel.Text = "0"
SlashCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SlashCountLabel.TextSize = 22

local SlashStatusLabel = Instance.new("TextLabel")
SlashStatusLabel.Name = "Status"
SlashStatusLabel.Parent = SlashFrame
SlashStatusLabel.BackgroundTransparency = 1
SlashStatusLabel.Position = UDim2.new(0, 0, 0, 54)
SlashStatusLabel.Size = UDim2.new(1, 0, 0, 16)
SlashStatusLabel.Font = Enum.Font.Gotham
SlashStatusLabel.Text = "READY"
SlashStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
SlashStatusLabel.TextSize = 11

local PauseLabel = Instance.new("TextLabel")
PauseLabel.Name = "Pause"
PauseLabel.Parent = SlashFrame
PauseLabel.BackgroundTransparency = 1
PauseLabel.Position = UDim2.new(0, 0, 0, 70)
PauseLabel.Size = UDim2.new(1, 0, 0, 14)
PauseLabel.Font = Enum.Font.GothamBold
PauseLabel.Text = "▶️ ACTIVE"
PauseLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
PauseLabel.TextSize = 10

task.spawn(function()
    while task.wait(0.1) do
        if not AutoSlashEnabled then
            SlashStatusLabel.Text = "OFF"
            SlashStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        else
            local now = tick()
            local remaining = SLASH_COOLDOWN - (now - lastSlashTime)
            if remaining > 0 then
                SlashStatusLabel.Text = string.format("CD: %.1fs", remaining)
                SlashStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            else
                SlashStatusLabel.Text = "READY"
                SlashStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
            end
            SlashCountLabel.Text = tostring(SlashCount)
        end

        if ParryPaused then
            local rem = ParryPauseUntil - tick()
            PauseLabel.Text = string.format("⏸️ PAUSED %.1fs", rem)
            PauseLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
        else
            PauseLabel.Text = "▶️ ACTIVE"
            PauseLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        end
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "Auto Parry",
    Desc = "Strong at any range",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballLocks = {}
            ballNameLocks = {}
        end
    end
})

MainTab:Toggle({
    Title = "Auto Accuracy",
    Desc = "Auto-adjust timing",
    Value = true,
    Callback = function(Value)
        AutoAccuracyEnabled = Value
    end
})

MainTab:Slider({
    Title = "Parry Time (ms)",
    Desc = "Used when Auto Accuracy is OFF",
    Value = {
        Min = 30,
        Max = 300,
        Default = 100,
    },
    Callback = function(Value)
        PARRY_TIME_MS = Value
    end
})

MainTab:Toggle({
    Title = "⚔️ Auto Slashes of Fury",
    Desc = "Auto-cast + Pauses Auto Parry 1.2s",
    Value = false,
    Callback = function(Value)
        AutoSlashEnabled = Value
        lastSlashTime = 0
    end
})

MainTab:Button({
    Title = "🔄 Reset Slash Counter",
    Callback = function()
        SlashCount = 0
    end
})

MainTab:Toggle({
    Title = "Auto Spam",
    Desc = "Spams near players",
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
        SlashGui:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v22.0 ✅",
    Content = "Clean version loaded",
    Duration = 5
})
