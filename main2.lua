-- Slax Hub - Blade Ball Script (Fixed with Sections)
-- Developed by yossef

-- ═══════════════════════════════════════════════════════
-- UI LIBRARY
-- ═══════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(620, 500),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
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

-- ═══════════════════════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════════════════════
local ParryTab = Window:Tab({ Title = "Auto Parry", Icon = "sword" })
local SpamTab = Window:Tab({ Title = "Spam", Icon = "zap" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- ═══════════════════════════════════════════════════════
-- SECTIONS
-- ═══════════════════════════════════════════════════════
local ParrySection = ParryTab:Section({ Title = "Auto Parry" })
local SpamSection = SpamTab:Section({ Title = "Auto Spam" })
local TriggerSection = SpamTab:Section({ Title = "Triggerbot" })
local SettingsSection = SettingsTab:Section({ Title = "Actions" })

-- ═══════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════
local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamEnabled = false
local TriggerbotEnabled = false
local Accuracy = 75
local AutoSpamCPS = 350
local SpamRange = 60
local TriggerDistance = 12
local TriggerCPS = 60
local TriggerHitRadius = 5
local HitRadius = 6
local PingCompensation = 1.5
local SafetyBuffer = 8

-- ═══════════════════════════════════════════════════════
-- UI CONTROLS (BEFORE any logic)
-- ═══════════════════════════════════════════════════════

-- TAB 1: AUTO PARRY
ParrySection:Toggle({
    Title = "⚡ Auto Parry",
    Desc = "Trajectory check + Fast ball emergency",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
    end
})

ParrySection:Slider({
    Title = "Accuracy",
    Desc = "100 = Early | 1 = Perfect (recommend 60-85)",
    Value = { Min = 1, Max = 100, Default = 75 },
    Callback = function(Value)
        Accuracy = Value
    end
})

-- TAB 2: SPAM
SpamSection:Toggle({
    Title = "⚡ Auto Spam",
    Desc = "Spams when players are within range",
    Value = false,
    Callback = function(Value)
        AutoSpamEnabled = Value
    end
})

SpamSection:Slider({
    Title = "Spam Range (studs)",
    Desc = "Distance to trigger auto spam",
    Value = { Min = 20, Max = 150, Default = 60 },
    Callback = function(Value)
        SpamRange = Value
    end
})

SpamSection:Slider({
    Title = "CPS",
    Desc = "Spam rate (Clicks Per Second)",
    Value = { Min = 50, Max = 500, Default = 350 },
    Callback = function(Value)
        AutoSpamCPS = Value
    end
})

-- TAB 2: TRIGGERBOT SECTION
TriggerSection:Toggle({
    Title = "🎯 Triggerbot",
    Desc = "Fires ONLY when ball is heading at you",
    Value = false,
    Callback = function(Value)
        TriggerbotEnabled = Value
    end
})

TriggerSection:Slider({
    Title = "Trigger Distance (studs)",
    Desc = "Distance for triggerbot to fire",
    Value = { Min = 5, Max = 30, Default = 12 },
    Callback = function(Value)
        TriggerDistance = Value
    end
})

TriggerSection:Slider({
    Title = "Trigger Hit Radius (studs)",
    Desc = "Lower = stricter trajectory",
    Value = { Min = 3, Max = 10, Default = 5 },
    Callback = function(Value)
        TriggerHitRadius = Value
    end
})

TriggerSection:Slider({
    Title = "Trigger CPS",
    Desc = "Triggerbot fire rate",
    Value = { Min = 30, Max = 120, Default = 60 },
    Callback = function(Value)
        TriggerCPS = Value
    end
})

-- TAB 3: SETTINGS
SettingsSection:Button({
    Title = "🔄 Reset Counters",
    Desc = "Clear parry/trigger counters",
    Callback = function()
        -- Will be updated when logic loads
    end
})

SettingsSection:Button({
    Title = "🗑️ Destroy UI",
    Callback = function()
        pcall(function() Window:Destroy() end)
    end
})

print("[Slax Hub] UI Ready ✅")

-- ═══════════════════════════════════════════════════════
-- LOGIC (in pcall so errors don't break UI)
-- ═══════════════════════════════════════════════════════

task.spawn(function()
    local success, err = pcall(function()
        -- Services
        local RS = game:GetService("ReplicatedStorage")
        local WS = game:GetService("Workspace")
        local Stats = game:GetService("Stats")
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local CoreGui = game:GetService("CoreGui")
        local LocalPlayer = Players.LocalPlayer

        local ballLocks = {}
        local triggerLocks = {}
        local ParryCount = 0
        local TriggerCount = 0

        -- ═══ Token ═══
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

        -- ═══ Hook ═══
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

        -- ═══ Fire Parry ═══
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

        -- ═══ Trajectory ═══
        local function WillHitMe(ballPos, ballVel, playerPos, hitRadius)
            hitRadius = hitRadius or HitRadius
            local speed = ballVel.Magnitude
            if speed < 1 then return false end
            
            local toPlayer = playerPos - ballPos
            local dir = ballVel.Unit
            
            local dot = dir:Dot(toPlayer.Unit)
            if dot <= 0 then return false end
            
            local projection = toPlayer:Dot(dir)
            if projection <= 0 then return false end
            
            local closestPoint = ballPos + (dir * projection)
            local missDistance = (playerPos - closestPoint).Magnitude
            
            if missDistance > hitRadius then return false end
            
            return true
        end

        -- ═══ Cleanup Locks ═══
        task.spawn(function()
            while task.wait(0.3) do
                local now = tick()
                for ball, t in pairs(ballLocks) do
                    if not ball.Parent or now >= t then ballLocks[ball] = nil end
                end
                for ball, t in pairs(triggerLocks) do
                    if not ball.Parent or now >= t then triggerLocks[ball] = nil end
                end
            end
        end)

        -- ═══ Triggerbot Loop ═══
        local lastTriggerTime = 0
        RunService.Heartbeat:Connect(function()
            if not TriggerbotEnabled then return end
            
            local now = tick()
            if (now - lastTriggerTime) < (1 / math.max(TriggerCPS, 1)) then return end
            
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local playerPos = hrp.Position
            local ballsFolder = WS:FindFirstChild("Balls")
            if not ballsFolder then return end
            
            local bestBall = nil
            local bestDistance = math.huge
            
            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if triggerLocks[ball] then continue end
                
                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < 5 then continue end
                
                local distance = (playerPos - ballPos).Magnitude
                if distance > TriggerDistance then continue end
                
                if not WillHitMe(ballPos, velocity, playerPos, TriggerHitRadius) then continue end
                
                if distance < bestDistance then
                    bestDistance = distance
                    bestBall = ball
                end
            end
            
            if bestBall then
                lastTriggerTime = now
                triggerLocks[bestBall] = now + 0.3
                FireParry()
                TriggerCount = TriggerCount + 1
            end
        end)

        -- ═══ Auto Parry Loop ═══
        local lastParryTime = 0
        RunService.Heartbeat:Connect(function()
            if not AutoParryEnabled then return end
            
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
            local parryDist = 8 + (Accuracy / 100) * 42
            local balls = ballsFolder:GetChildren()
            
            -- PHASE 1: Fast Ball Emergency
            for _, ball in ipairs(balls) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if ballLocks[ball] then continue end
                
                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < 5 then continue end
                
                local toPlayer = (playerPos - ballPos).Unit
                local dot = velocity.Unit:Dot(toPlayer)
                if dot <= 0.3 then continue end
                
                local distance = (playerPos - ballPos).Magnitude
                
                local isEmergency = false
                if speed >= 200 and distance < 100 then isEmergency = true
                elseif speed >= 150 and distance < 70 then isEmergency = true
                elseif speed >= 120 and distance < 40 then isEmergency = true
                elseif distance <= 15 then isEmergency = true end
                
                if isEmergency then
                    if WillHitMe(ballPos, velocity, playerPos) or distance <= 12 then
                        lastParryTime = now
                        ballLocks[ball] = now + 0.5
                        FireParry()
                        ParryCount = ParryCount + 1
                        return
                    end
                end
            end
            
            -- PHASE 2: Normal Parry
            local bestBall = nil
            local bestDistance = math.huge
            
            for _, ball in ipairs(balls) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if ballLocks[ball] then continue end
                
                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < 5 then continue end
                
                if not WillHitMe(ballPos, velocity, playerPos) then continue end
                
                local distance = (playerPos - ballPos).Magnitude
                local pingDist = ping * speed * PingCompensation
                local triggerDist = parryDist + pingDist + SafetyBuffer
                
                if speed > 150 then triggerDist = triggerDist + 15
                elseif speed > 100 then triggerDist = triggerDist + 8 end
                
                if distance <= triggerDist then
                    if distance < bestDistance then
                        bestDistance = distance
                        bestBall = ball
                    end
                end
            end
            
            if bestBall then
                lastParryTime = now
                ballLocks[bestBall] = now + 0.5
                FireParry()
                ParryCount = ParryCount + 1
            end
        end)

        -- ═══ Auto Spam Loop ═══
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

        -- ═══ Manual Spam Loop ═══
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

        print("[Slax Hub] ✅ All systems ready")

        -- ═══ GUI Parent ═══
        local function GetGuiParent()
            local ok, hui = pcall(gethui)
            if ok and hui then return hui end
            local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
            if ok2 and pg then return pg end
            return CoreGui
        end

        -- ═══ Stats UI ═══
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
        StatsLabel.Position = UDim2.new(0.62, 0, 0.02, 0)
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

        task.spawn(function()
            while task.wait(0.5) do
                pcall(function()
                    local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                    StatsLabel.Text = string.format(
                        "Slax Hub | Ping: %d ms\nParry: %s | Parries: %d\nTrigger: %s | Triggers: %d",
                        ping,
                        AutoParryEnabled and "ON" or "OFF",
                        ParryCount,
                        TriggerbotEnabled and "ON" or "OFF",
                        TriggerCount
                    )
                    if AutoParryEnabled or TriggerbotEnabled then
                        StatsLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                        StatsStroke.Color = Color3.fromRGB(80, 255, 160)
                    else
                        StatsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                        StatsStroke.Color = Color3.fromRGB(150, 150, 150)
                    end
                end)
            end
        end)

        -- ═══ Pink SPAM Button ═══
        local ManualGui = Instance.new("ScreenGui")
        ManualGui.Name = "SlaxManualSpam_" .. math.random(1, 99999)
        ManualGui.Parent = GetGuiParent()
        ManualGui.ResetOnSpawn = false
        ManualGui.IgnoreGuiInset = true
        ManualGui.DisplayOrder = 99999

        local ManualBtn = Instance.new("TextButton")
        ManualBtn.Parent = ManualGui
        ManualBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        ManualBtn.BackgroundTransparency = 0.15
        ManualBtn.BorderSizePixel = 0
        ManualBtn.Position = UDim2.new(0.05, 0, 0.45, 0)
        ManualBtn.Size = UDim2.new(0, 110, 0, 42)
        ManualBtn.Font = Enum.Font.GothamBold
        ManualBtn.Text = "SPAM: OFF"
        ManualBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
        ManualBtn.TextSize = 13
        ManualBtn.AutoButtonColor = false
        ManualBtn.Active = true

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
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
        })

        local function UpdateManualBtn()
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
                if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then dragMoved = true end
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

        ManualBtn.MouseButton1Click:Connect(function()
            if dragMoved then return end
            local now = tick()
            if now - lastTap > 0.3 then
                lastTap = now
                ManualSpamEnabled = not ManualSpamEnabled
                UpdateManualBtn()
            end
        end)

        ManualBtn.TouchTap:Connect(function()
            local now = tick()
            if now - lastTap > 0.3 then
                lastTap = now
                ManualSpamEnabled = not ManualSpamEnabled
                UpdateManualBtn()
            end
        end)

        UpdateManualBtn()

        -- ═══ Pink TRIGGER Button ═══
        local TriggerGui = Instance.new("ScreenGui")
        TriggerGui.Name = "SlaxTrigger_" .. math.random(1, 99999)
        TriggerGui.Parent = GetGuiParent()
        TriggerGui.ResetOnSpawn = false
        TriggerGui.IgnoreGuiInset = true
        TriggerGui.DisplayOrder = 99999

        local TriggerBtn = Instance.new("TextButton")
        TriggerBtn.Parent = TriggerGui
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        TriggerBtn.BackgroundTransparency = 0.15
        TriggerBtn.BorderSizePixel = 0
        TriggerBtn.Position = UDim2.new(0.05, 0, 0.55, 0)
        TriggerBtn.Size = UDim2.new(0, 110, 0, 42)
        TriggerBtn.Font = Enum.Font.GothamBold
        TriggerBtn.Text = "TRIGGER: OFF"
        TriggerBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
        TriggerBtn.TextSize = 13
        TriggerBtn.AutoButtonColor = false
        TriggerBtn.Active = true

        local TriggerCorner = Instance.new("UICorner")
        TriggerCorner.CornerRadius = UDim.new(0, 10)
        TriggerCorner.Parent = TriggerBtn

        local TriggerStroke = Instance.new("UIStroke")
        TriggerStroke.Parent = TriggerBtn
        TriggerStroke.Thickness = 1.5
        TriggerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local TStrokeGradient = Instance.new("UIGradient")
        TStrokeGradient.Parent = TriggerStroke
        TStrokeGradient.Rotation = 45
        TStrokeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(230, 80, 230)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(180, 90, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 100, 255))
        })

        local TriggerGlow = Instance.new("UIStroke")
        TriggerGlow.Parent = TriggerBtn
        TriggerGlow.Thickness = 4
        TriggerGlow.Transparency = 0.7
        TriggerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local TGlowGradient = Instance.new("UIGradient")
        TGlowGradient.Parent = TriggerGlow
        TGlowGradient.Rotation = 45
        TGlowGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 100, 200)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(210, 100, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 110, 255))
        })

        local TBgGradient = Instance.new("UIGradient")
        TBgGradient.Parent = TriggerBtn
        TBgGradient.Rotation = 45
        TBgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
        })

        local function UpdateTriggerBtn()
            if TriggerbotEnabled then
                TriggerBtn.Text = "TRIGGER: ON"
                TriggerBtn.TextColor3 = Color3.fromRGB(80, 255, 180)
                TBgGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
                })
            else
                TriggerBtn.Text = "TRIGGER: OFF"
                TriggerBtn.TextColor3 = Color3.fromRGB(255, 180, 230)
                TBgGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(35, 20, 50)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(50, 25, 60))
                })
            end
        end

        local tDragging, tDragStart, tStartPos, tDragMoved
        local tLastTap = 0

        TriggerBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                tDragging = true
                tDragMoved = false
                tDragStart = input.Position
                tStartPos = TriggerBtn.Position
            end
        end)

        TriggerBtn.InputChanged:Connect(function(input)
            if tDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - tDragStart
                if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then tDragMoved = true end
                TriggerBtn.Position = UDim2.new(
                    tStartPos.X.Scale, tStartPos.X.Offset + delta.X,
                    tStartPos.Y.Scale, tStartPos.Y.Offset + delta.Y
                )
            end
        end)

        TriggerBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                tDragging = false
            end
        end)

        TriggerBtn.MouseButton1Click:Connect(function()
            if tDragMoved then return end
            local now = tick()
            if now - tLastTap > 0.3 then
                tLastTap = now
                TriggerbotEnabled = not TriggerbotEnabled
                UpdateTriggerBtn()
            end
        end)

        TriggerBtn.TouchTap:Connect(function()
            local now = tick()
            if now - tLastTap > 0.3 then
                tLastTap = now
                TriggerbotEnabled = not TriggerbotEnabled
                UpdateTriggerBtn()
            end
        end)

        UpdateTriggerBtn()

        -- Keyboard
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.E then
                ManualSpamEnabled = not ManualSpamEnabled
                UpdateManualBtn()
            elseif input.KeyCode == Enum.KeyCode.Q then
                TriggerbotEnabled = not TriggerbotEnabled
                UpdateTriggerBtn()
            end
        end)

        -- Watch UI toggles (سواء من الزر أو من القائمة)
        task.spawn(function()
            while task.wait(0.2) do
                pcall(function()
                    if ManualSpamEnabled and ManualBtn.Text == "SPAM: OFF" then
                        UpdateManualBtn()
                    elseif not ManualSpamEnabled and ManualBtn.Text == "SPAM: ON" then
                        UpdateManualBtn()
                    end
                    if TriggerbotEnabled and TriggerBtn.Text == "TRIGGER: OFF" then
                        UpdateTriggerBtn()
                    elseif not TriggerbotEnabled and TriggerBtn.Text == "TRIGGER: ON" then
                        UpdateTriggerBtn()
                    end
                end)
            end
        end)

        -- Update Reset Button in Settings
        SettingsSection:Button({
            Title = "🔄 Full Reset",
            Desc = "Reset counters and states",
            Callback = function()
                ParryCount = 0
                TriggerCount = 0
                ballLocks = {}
                triggerLocks = {}
            end
        })
    end)

    if not success then
        warn("[Slax Hub] Logic Error: " .. tostring(err))
    end
end)

-- ═══════════════════════════════════════════════════════
-- NOTIFICATION
-- ═══════════════════════════════════════════════════════
WindUI:Notify({
    Title = "Slax Hub Loaded ✅",
    Content = "Auto Parry + Spam + Triggerbot ready!",
    Duration = 5
})

print("[Slax Hub] ✅ Loaded successfully")
