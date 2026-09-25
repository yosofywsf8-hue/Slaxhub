-- ═══════════════════════════════════════════════════════
-- Slax Hub - Smart Auto Parry (Self-Adaptive)
-- Developed by yossef
-- ═══════════════════════════════════════════════════════

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(560, 500),
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
    OnlyMobile = true,
})

-- Tabs
local ParryTab = Window:Tab({ Title = "Parry", Icon = "sword" })
local SpamTab = Window:Tab({ Title = "Spam", Icon = "zap" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- Sections
local ParrySection = ParryTab:Section({ Title = "Auto Parry" })
local SpamSection = SpamTab:Section({ Title = "Auto Spam" })
local TriggerSection = SpamTab:Section({ Title = "Triggerbot" })
local SettingsSection = SettingsTab:Section({ Title = "Actions" })

-- ═══════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════
local AutoParryEnabled = false
local AutoSpamEnabled = false
local ManualSpamVisible = false
local ManualSpamActive = false
local TriggerbotVisible = false
local TriggerbotActive = false
local AutoSpamCPS = 350
local SpamRange = 60
local TriggerDistance = 25
local TriggerCPS = 80

-- ═══════════════════════════════════════════════════════
-- UI CONTROLS (بدون Accuracy)
-- ═══════════════════════════════════════════════════════

ParrySection:Toggle({
    Title = "⚡ Auto Parry (Smart)",
    Desc = "Self-adaptive - handles fast/curved/close combat automatically",
    Value = false,
    Callback = function(Value) AutoParryEnabled = Value end
})

SpamSection:Toggle({
    Title = "⚡ Auto Spam",
    Desc = "Spams near players",
    Value = false,
    Callback = function(Value) AutoSpamEnabled = Value end
})

SpamSection:Slider({
    Title = "Spam Range (studs)",
    Value = { Min = 20, Max = 150, Default = 60 },
    Callback = function(Value) SpamRange = Value end
})

SpamSection:Slider({
    Title = "CPS",
    Value = { Min = 50, Max = 500, Default = 350 },
    Callback = function(Value) AutoSpamCPS = Value end
})

SpamSection:Toggle({
    Title = "🌸 Manual Spam",
    Desc = "Show pink SPAM button on screen",
    Value = false,
    Callback = function(Value)
        ManualSpamVisible = Value
        ManualSpamActive = Value
    end
})

TriggerSection:Toggle({
    Title = "🎯 Triggerbot",
    Desc = "Show TRIGGER button on screen",
    Value = false,
    Callback = function(Value)
        TriggerbotVisible = Value
        TriggerbotActive = Value
    end
})

TriggerSection:Slider({
    Title = "Trigger Distance (studs)",
    Value = { Min = 10, Max = 50, Default = 25 },
    Callback = function(Value) TriggerDistance = Value end
})

TriggerSection:Slider({
    Title = "Trigger CPS",
    Value = { Min = 30, Max = 120, Default = 80 },
    Callback = function(Value) TriggerCPS = Value end
})

SettingsSection:Button({
    Title = "🗑️ Destroy UI",
    Callback = function() pcall(function() Window:Destroy() end) end
})

print("[Slax Hub] UI Ready")

-- ═══════════════════════════════════════════════════════
-- LOGIC
-- ═══════════════════════════════════════════════════════
task.spawn(function()
    local success, err = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local WS = game:GetService("Workspace")
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local CoreGui = game:GetService("CoreGui")
        local LocalPlayer = Players.LocalPlayer

        local ballLocks = {}
        local ballHistory = {}  -- 🧠 لتتبع انحناء الكرة

        -- ═══════════════════════════════════════════════
        -- 🔐 BYPASS - Token Retrieval
        -- ═══════════════════════════════════════════════
        local _token = nil

        -- Method 1: by name
        for _, f in getgc(true) do
            if type(f) == 'function' then
                local ok, name = pcall(function() return debug.info(f, 's') end)
                if ok and name and tostring(name):find('PRY', 1, true) then
                    local ok2, ups = pcall(function() return debug.getupvalues(f) end)
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

        -- Method 2: by upvalues
        if not _token then
            for _, f in getgc(true) do
                if type(f) == 'function' then
                    local ok, ups = pcall(function() return debug.getupvalues(f) end)
                    if ok and ups then
                        for _, v in pairs(ups) do
                            if type(v) == 'function' then
                                local ok2, name = pcall(function() return debug.info(v, 's') end)
                                if ok2 and name and tostring(name):find('PRY', 1, true) then
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

        print("[Slax Hub] Token: " .. (_token and "✅ OK" or "❌ FAILED"))

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

        -- ═══════════════════════════════════════════════
        -- 🎣 HOOK
        -- ═══════════════════════════════════════════════
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
            pcall(function()
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
            end)
        end

        for _, r in pairs(RS:GetDescendants()) do
            if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
                _hook(r)
            end
        end

        print("[Slax Hub] Hooks: " .. tostring(#_reverted))

        -- ═══════════════════════════════════════════════
        -- 🔥 FIRE PARRY
        -- ═══════════════════════════════════════════════
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

        -- ═══════════════════════════════════════════════
        -- 🛡️ HELPERS
        -- ═══════════════════════════════════════════════
        local function IsAlive()
            local char = LocalPlayer.Character
            if not char then return false end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return false end
            if humanoid.Health <= 0 then return false end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return false end
            return true, char, hrp
        end

        local function GetClosestEnemy(playerPos)
            local closest = math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local c = p.Character
                    if c then
                        local p_hrp = c:FindFirstChild("HumanoidRootPart")
                        if p_hrp then
                            local d = (p_hrp.Position - playerPos).Magnitude
                            if d < closest then closest = d end
                        end
                    end
                end
            end
            return closest
        end

        -- 🧠 Curve Detection - track ball direction
        local function TrackCurve(ball, ballPos)
            local now = tick()
            local history = ballHistory[ball]
            
            if not history then
                ballHistory[ball] = {
                    lastPos = ballPos,
                    lastTime = now,
                    curveScore = 0,
                    direction = nil
                }
                return false
            end
            
            local timeDiff = now - history.lastTime
            if timeDiff > 0.01 then
                local moveDir = (ballPos - history.lastPos)
                if moveDir.Magnitude > 0.5 then
                    local newDir = moveDir.Unit
                    if history.direction then
                        local dot = history.direction:Dot(newDir)
                        local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
                        if angle > 3 then
                            history.curveScore = history.curveScore + angle * 0.1
                        else
                            history.curveScore = history.curveScore * 0.9
                        end
                    end
                    history.direction = newDir
                    history.lastPos = ballPos
                    history.lastTime = now
                end
            end
            
            return history.curveScore > 3
        end

        -- Cleanup locks
        task.spawn(function()
            while task.wait(0.3) do
                local now = tick()
                for ball, t in pairs(ballLocks) do
                    if not ball.Parent or now >= t then ballLocks[ball] = nil end
                end
                for ball in pairs(ballHistory) do
                    if not ball.Parent then ballHistory[ball] = nil end
                end
            end
        end)

        -- ═══════════════════════════════════════════════
        -- 🔥🔥🔥 SMART AUTO PARRY - NO ACCURACY NEEDED
        -- ═══════════════════════════════════════════════
        local lastParryTime = 0

        RunService.Heartbeat:Connect(function()
            if not AutoParryEnabled then return end
            
            local now = tick()
            -- Anti-double parry: 35ms cooldown
            if (now - lastParryTime) < 0.035 then return end
            
            -- Anti post-death
            local alive, char, hrp = IsAlive()
            if not alive then return end
            
            local playerPos = hrp.Position
            local playerVel = hrp.AssemblyLinearVelocity
            local playerSpeed = playerVel.Magnitude
            
            local ballsFolder = WS:FindFirstChild("Balls")
            if not ballsFolder then return end
            
            -- 🔍 Get context
            local enemyDist = GetClosestEnemy(playerPos)
            
            local bestBall = nil
            local bestScore = -math.huge
            
            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if ballLocks[ball] then continue end
                
                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < 5 then continue end
                
                -- 🧠 Curve detection
                local isCurving = TrackCurve(ball, ballPos)
                
                -- 🏃 Relative velocity
                local relVel = velocity - playerVel
                local relSpeed = relVel.Magnitude
                if relSpeed < 3 then relSpeed = speed end
                
                local toPlayer = playerPos - ballPos
                local distance = toPlayer.Magnitude
                local toPlayerUnit = toPlayer.Unit
                
                -- 🎯 Direction check (Dynamic)
                local minDot = 0.25  -- default
                
                -- إذا قريب من عدو → تسامح أكثر
                if enemyDist < 15 then minDot = 0.05
                elseif enemyDist < 25 then minDot = 0.1
                elseif enemyDist < 40 then minDot = 0.15 end
                
                -- إذا الكرة سريعة → تسامح أكثر
                if relSpeed > 200 then minDot = minDot - 0.1 end
                if relSpeed > 150 then minDot = minDot - 0.05 end
                
                -- إذا الكرة منحنية → تسامح أكثر
                if isCurving then minDot = minDot - 0.1 end
                
                minDot = math.max(minDot, 0)
                
                local dot = relVel.Unit:Dot(toPlayerUnit)
                if dot <= minDot then continue end
                
                -- ═══════════════════════════════════════
                -- 🎯 SMART DISTANCE CALCULATION
                -- ═══════════════════════════════════════
                -- Base distance (ثابت ومناسب لكل الحالات)
                local triggerDist = 35
                
                -- 🚀 Speed adjustment
                if relSpeed >= 300 then triggerDist = triggerDist + 40
                elseif relSpeed >= 250 then triggerDist = triggerDist + 32
                elseif relSpeed >= 200 then triggerDist = triggerDist + 25
                elseif relSpeed >= 150 then triggerDist = triggerDist + 18
                elseif relSpeed >= 100 then triggerDist = triggerDist + 10
                elseif relSpeed >= 70 then triggerDist = triggerDist + 5 end
                
                -- 🔥 Close Combat adjustment
                if enemyDist < 10 then triggerDist = triggerDist + 25
                elseif enemyDist < 15 then triggerDist = triggerDist + 20
                elseif enemyDist < 25 then triggerDist = triggerDist + 15
                elseif enemyDist < 40 then triggerDist = triggerDist + 8
                elseif enemyDist < 60 then triggerDist = triggerDist + 3 end
                
                -- 🏃 Movement adjustment
                if playerSpeed > 15 then triggerDist = triggerDist + 15
                elseif playerSpeed > 8 then triggerDist = triggerDist + 8
                elseif playerSpeed > 4 then triggerDist = triggerDist + 4 end
                
                -- 🌀 Curve adjustment (يصد أبكر للكرة المنحنية)
                if isCurving then triggerDist = triggerDist + 15 end
                
                -- 🎯 Distance check
                if distance > triggerDist then continue end
                
                -- ═══════════════════════════════════════
                -- 🎯 SCORE - choose best ball
                -- ═══════════════════════════════════════
                -- Ball closer = higher score
                -- Ball heading at us more = higher score
                local score = (1 / math.max(distance, 1)) * dot
                
                -- Bonus if very close
                if distance < 15 then score = score * 2 end
                
                if score > bestScore then
                    bestScore = score
                    bestBall = ball
                end
            end
            
            -- 🚀 FIRE!
            if bestBall then
                lastParryTime = now
                ballLocks[bestBall] = now + 0.5
                FireParry()
            end
        end)

        -- ═══════════════════════════════════════════════
        -- 🎯 TRIGGERBOT (Smart)
        -- ═══════════════════════════════════════════════
        local lastTriggerTime = 0
        RunService.Heartbeat:Connect(function()
            if not TriggerbotActive then return end
            
            local now = tick()
            if (now - lastTriggerTime) < (1 / math.max(TriggerCPS, 1)) then return end
            
            local alive, char, hrp = IsAlive()
            if not alive then return end
            
            local playerPos = hrp.Position
            local playerVel = hrp.AssemblyLinearVelocity
            local ballsFolder = WS:FindFirstChild("Balls")
            if not ballsFolder then return end
            
            local enemyDist = GetClosestEnemy(playerPos)
            
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
                
                local relVel = velocity - playerVel
                
                local dotMin = 0.2
                if enemyDist < 20 then dotMin = 0.1
                elseif enemyDist < 40 then dotMin = 0.15 end
                
                local toPlayer = (playerPos - ballPos).Unit
                local dot = relVel.Unit:Dot(toPlayer)
                if dot <= dotMin then continue end
                
                local distance = (playerPos - ballPos).Magnitude
                local maxDist = TriggerDistance
                if enemyDist < 20 then maxDist = maxDist + 15
                elseif enemyDist < 40 then maxDist = maxDist + 8 end
                
                if distance > maxDist then continue end
                
                if distance < bestDistance then
                    bestDistance = distance
                    bestBall = ball
                end
            end
            
            if bestBall then
                lastTriggerTime = now
                ballLocks[bestBall] = now + 0.4
                FireParry()
            end
        end)

        -- ═══════════════════════════════════════════════
        -- ⚡ AUTO SPAM
        -- ═══════════════════════════════════════════════
        local lastSpamTime = 0
        RunService.Heartbeat:Connect(function()
            if not AutoSpamEnabled then return end
            local now = tick()
            
            local alive, char, hrp = IsAlive()
            if not alive then return end
            
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
                pcall(function()
                    local packet = {args[1], args[2], _tokenize(args[2]), 0.5, WS.CurrentCamera.CFrame, {}, {0, 0}, false}
                    if remote:IsA('RemoteEvent') then
                        remote:FireServer(unpack(packet))
                    elseif remote:IsA('RemoteFunction') then
                        remote:InvokeServer(unpack(packet))
                    end
                end)
            end
        end)

        -- ═══════════════════════════════════════════════
        -- 🖐️ MANUAL SPAM
        -- ═══════════════════════════════════════════════
        local lastManualSpamTime = 0
        RunService.Heartbeat:Connect(function()
            if not ManualSpamActive then return end
            local now = tick()
            if (now - lastManualSpamTime) < 0.008 then return end
            lastManualSpamTime = now
            
            local remote, args = GetParryRemote()
            if not remote or not args then return end
            for _ = 1, 8 do
                pcall(function()
                    local packet = {args[1], args[2], _tokenize(args[2]), 0.5, WS.CurrentCamera.CFrame, {}, {0, 0}, false}
                    if remote:IsA('RemoteEvent') then
                        remote:FireServer(unpack(packet))
                    elseif remote:IsA('RemoteFunction') then
                        remote:InvokeServer(unpack(packet))
                    end
                end)
            end
        end)

        print("[Slax Hub] ✅ SMART Mode Ready")

        -- ═══════════════════════════════════════════════
        -- GUI PARENT
        -- ═══════════════════════════════════════════════
        local function GetGuiParent()
            local ok, hui = pcall(gethui)
            if ok and hui then return hui end
            local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
            if ok2 and pg then return pg end
            return CoreGui
        end

        -- 🌸 SPAM BUTTON
        local ManualGui = Instance.new("ScreenGui")
        ManualGui.Name = "SlaxManualSpam_" .. math.random(1, 99999)
        ManualGui.Parent = GetGuiParent()
        ManualGui.ResetOnSpawn = false
        ManualGui.IgnoreGuiInset = true
        ManualGui.DisplayOrder = 99999
        ManualGui.Enabled = false

        local ManualBtn = Instance.new("TextButton")
        ManualBtn.Parent = ManualGui
        ManualBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        ManualBtn.BackgroundTransparency = 0.15
        ManualBtn.BorderSizePixel = 0
        ManualBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
        ManualBtn.Size = UDim2.new(0, 130, 0, 50)
        ManualBtn.Font = Enum.Font.GothamBold
        ManualBtn.Text = "SPAM: ON"
        ManualBtn.TextColor3 = Color3.fromRGB(80, 255, 180)
        ManualBtn.TextSize = 15
        ManualBtn.AutoButtonColor = false
        ManualBtn.Active = true

        local ManualCorner = Instance.new("UICorner")
        ManualCorner.CornerRadius = UDim.new(0, 12)
        ManualCorner.Parent = ManualBtn

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

        local BgGradient = Instance.new("UIGradient")
        BgGradient.Parent = ManualBtn
        BgGradient.Rotation = 45
        BgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
        })

        local function UpdateManualBtnVisual()
            if ManualSpamActive then
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
                if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then dragMoved = true end
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
                ManualSpamActive = not ManualSpamActive
                UpdateManualBtnVisual()
            end
        end)

        ManualBtn.TouchTap:Connect(function()
            local now = tick()
            if now - lastTap > 0.3 then
                lastTap = now
                ManualSpamActive = not ManualSpamActive
                UpdateManualBtnVisual()
            end
        end)

        UpdateManualBtnVisual()

        -- 🎯 TRIGGER BUTTON
        local TriggerGui = Instance.new("ScreenGui")
        TriggerGui.Name = "SlaxTrigger_" .. math.random(1, 99999)
        TriggerGui.Parent = GetGuiParent()
        TriggerGui.ResetOnSpawn = false
        TriggerGui.IgnoreGuiInset = true
        TriggerGui.DisplayOrder = 99999
        TriggerGui.Enabled = false

        local TriggerBtn = Instance.new("TextButton")
        TriggerBtn.Parent = TriggerGui
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
        TriggerBtn.BackgroundTransparency = 0.15
        TriggerBtn.BorderSizePixel = 0
        TriggerBtn.Position = UDim2.new(0.05, 0, 0.52, 0)
        TriggerBtn.Size = UDim2.new(0, 130, 0, 50)
        TriggerBtn.Font = Enum.Font.GothamBold
        TriggerBtn.Text = "TRIGGER: ON"
        TriggerBtn.TextColor3 = Color3.fromRGB(80, 255, 180)
        TriggerBtn.TextSize = 15
        TriggerBtn.AutoButtonColor = false
        TriggerBtn.Active = true

        local TriggerCorner = Instance.new("UICorner")
        TriggerCorner.CornerRadius = UDim.new(0, 12)
        TriggerCorner.Parent = TriggerBtn

        local TriggerStroke = Instance.new("UIStroke")
        TriggerStroke.Parent = TriggerBtn
        TriggerStroke.Thickness = 2
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

        local TBgGradient = Instance.new("UIGradient")
        TBgGradient.Parent = TriggerBtn
        TBgGradient.Rotation = 45
        TBgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 60, 50)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 80, 60))
        })

        local function UpdateTriggerBtnVisual()
            if TriggerbotActive then
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
                if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then tDragMoved = true end
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
                TriggerbotActive = not TriggerbotActive
                UpdateTriggerBtnVisual()
            end
        end)

        TriggerBtn.TouchTap:Connect(function()
            local now = tick()
            if now - tLastTap > 0.3 then
                tLastTap = now
                TriggerbotActive = not TriggerbotActive
                UpdateTriggerBtnVisual()
            end
        end)

        UpdateTriggerBtnVisual()

        -- Watch visibility
        task.spawn(function()
            while task.wait(0.2) do
                pcall(function()
                    if ManualSpamVisible and not ManualGui.Enabled then
                        ManualGui.Enabled = true
                    elseif not ManualSpamVisible and ManualGui.Enabled then
                        ManualGui.Enabled = false
                    end
                    
                    if TriggerbotVisible and not TriggerGui.Enabled then
                        TriggerGui.Enabled = true
                    elseif not TriggerbotVisible and TriggerGui.Enabled then
                        TriggerGui.Enabled = false
                    end
                end)
            end
        end)

        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.E then
                ManualSpamActive = not ManualSpamActive
                UpdateManualBtnVisual()
            elseif input.KeyCode == Enum.KeyCode.Q then
                TriggerbotActive = not TriggerbotActive
                UpdateTriggerBtnVisual()
            end
        end)
    end)

    if not success then
        warn("[Slax Hub] Logic Error: " .. tostring(err))
    end
end)

WindUI:Notify({
    Title = "Slax Hub 🔥",
    Content = "SMART Auto Parry - No Accuracy Needed!",
    Duration = 5
})

print("[Slax Hub] ✅ SMART Mode Loaded")
