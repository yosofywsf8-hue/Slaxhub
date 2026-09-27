-- ═══════════════════════════════════════════════════════
-- Slax Hub - EAGLE+ Auto Parry
-- Base by yossef | Auto Parry upgraded by ALPHA XK
-- ═══════════════════════════════════════════════════════

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub",
    Icon = "swords",
    Author = "yossef | ALPHA XK",
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
local ParryTab    = Window:Tab({ Title = "Parry",    Icon = "sword" })
local SpamTab     = Window:Tab({ Title = "Spam",     Icon = "zap" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- Sections
local ParrySection    = ParryTab:Section({ Title = "Auto Parry" })
local CurveSection    = ParryTab:Section({ Title = "Curve Mode" })
local SpamSection     = SpamTab:Section({ Title = "Auto Spam" })
local TriggerSection  = SpamTab:Section({ Title = "Triggerbot" })
local ManualSection   = SpamTab:Section({ Title = "Manual Spam" })
local SettingsSection = SettingsTab:Section({ Title = "Actions" })

-- ═══════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════
local AutoParryEnabled   = false
local AutoSpamEnabled    = false
local ManualSpamVisible  = false
local ManualSpamActive   = false
local TriggerbotVisible  = false
local TriggerbotActive   = false
local Accuracy           = 50
local DivisorMultiplier  = 1.1
local RandomAccuracy     = false
local CurrentCurve       = "Camera"
local RandomCurve        = false
local AutoSpamCPS        = 350
local SpamRange          = 60
local TriggerDistance    = 25
local TriggerCPS         = 80
local PlayAnim           = false

local CURVE_NAMES = {"Camera", "Random", "Accelerated", "Backwards", "Slow", "High", "Normal", "Speed", "Down", "Left", "Right"}

-- ═══════════════════════════════════════════════════════
-- UI CONTROLS
-- ═══════════════════════════════════════════════════════

ParrySection:Toggle({
    Title = "⚡ Auto Parry (EAGLE+)",
    Desc = "Predictive target-based parry — only when ball targets YOU",
    Value = false,
    Callback = function(Value) AutoParryEnabled = Value end
})

ParrySection:Slider({
    Title = "Accuracy",
    Desc = "1 = Late | 50 = Balanced | 100 = Early",
    Value = { Min = 1, Max = 100, Default = 50 },
    Callback = function(Value)
        Accuracy = Value
        DivisorMultiplier = 0.7 + (Accuracy - 1) * (0.9 / 99)
    end
})

ParrySection:Toggle({
    Title = "Randomized Accuracy",
    Desc = "Auto-adjust based on ping (harder to detect)",
    Value = false,
    Callback = function(Value) RandomAccuracy = Value end
})

ParrySection:Toggle({
    Title = "Play Animation",
    Desc = "Play parry animation",
    Value = false,
    Callback = function(Value) PlayAnim = Value end
})

CurveSection:Dropdown({
    Title = "Curve Mode",
    Values = CURVE_NAMES,
    Value = "Camera",
    Callback = function(Value) CurrentCurve = Value end
})

CurveSection:Toggle({
    Title = "Random Curve",
    Desc = "Random curve every parry",
    Value = false,
    Callback = function(Value) RandomCurve = Value end
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

ManualSection:Toggle({
    Title = "🌸 Manual Spam",
    Desc = "Show pink SPAM button",
    Value = false,
    Callback = function(Value)
        ManualSpamVisible = Value
        ManualSpamActive = Value
    end
})

TriggerSection:Toggle({
    Title = "🎯 Triggerbot",
    Desc = "Single parry when targeted",
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
        local Stats = game:GetService("Stats")
        local LocalPlayer = Players.LocalPlayer

        local ballLocks = {}
        local animCache = {}

        -- ═══════════════════════════════════════════════
        -- 🔐 TOKEN BYPASS
        -- ═══════════════════════════════════════════════
        local _token = nil
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
        -- 🎣 REMOTE HOOK + CAPTURE ARGS
        -- ═══════════════════════════════════════════════
        local _reverted = {}
        local _original = {}
        local _capturedRemote = nil
        local _capturedArgs = nil

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
                if _reverted[remote] then return end
                if _original[getrawmetatable(remote)] then return end
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
                                _capturedRemote = self
                                _capturedArgs = _args
                                print("[Slax Hub] Remote captured:", self.Name)
                            end
                            return _old(self, key)(_, unpack(_args))
                        end
                    end
                    return _old(self, key)
                end
                setreadonly(_meta, true)
            end)
        end

        for _, r in pairs(RS:GetDescendants()) do
            if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
                _hook(r)
            end
        end

        print("[Slax Hub] Hooks installed, waiting for capture")

        -- ═══════════════════════════════════════════════
        -- 🎨 CURVE SYSTEM
        -- ═══════════════════════════════════════════════
        local function GetCurveCFrame()
            local Camera = WS.CurrentCamera
            local char = LocalPlayer.Character
            if not char then return Camera.CFrame end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return Camera.CFrame end
            local rootPos = root.Position

            local targetPart = nil
            local bestDist = math.huge
            local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character.PrimaryPart then
                    local sp, onScreen = Camera:WorldToScreenPoint(p.Character.PrimaryPart.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - centerScreen).Magnitude
                        if d < bestDist then
                            bestDist = d
                            targetPart = p.Character.PrimaryPart
                        end
                    end
                end
            end

            local targetPos = targetPart and targetPart.Position or (rootPos + Camera.CFrame.LookVector * 100)
            local ct = RandomCurve and CURVE_NAMES[math.random(#CURVE_NAMES)] or CurrentCurve

            if ct == "Camera" then
                return Camera.CFrame
            elseif ct == "Random" then
                local dir = (targetPos - rootPos).Unit
                local offset
                for _ = 1, 10 do
                    offset = Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
                    if dir:Dot((targetPos + offset - rootPos).Unit) < 0.95 then break end
                end
                return CFrame.new(rootPos, targetPos + offset)
            elseif ct == "Accelerated" then
                return CFrame.new(rootPos, targetPos + Vector3.new(0, 5, 0))
            elseif ct == "Backwards" then
                return CFrame.new(Camera.CFrame.Position, rootPos + (rootPos - targetPos).Unit * 10000 + Vector3.new(0, 1000, 0))
            elseif ct == "Slow" then
                return CFrame.new(rootPos, targetPos + Vector3.new(0, -9e18, 0))
            elseif ct == "High" then
                return CFrame.new(rootPos, targetPos + Vector3.new(0, 9e18, 0))
            elseif ct == "Normal" then
                return CFrame.new(rootPos, rootPos + root.CFrame.LookVector)
            elseif ct == "Speed" then
                return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * 5)
            elseif ct == "Down" then
                return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * -9e9)
            elseif ct == "Left" then
                return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Camera.CFrame.RightVector * 9e9)
            elseif ct == "Right" then
                return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.RightVector * 9e9)
            end
            return Camera.CFrame
        end

        -- ═══════════════════════════════════════════════
        -- 🔥 FIRE PARRY
        -- ═══════════════════════════════════════════════
        local function FireParry()
            if not _capturedRemote or not _capturedArgs then return false end

            local Camera = WS.CurrentCamera
            local vp = Camera.ViewportSize
            local aimTarget = {math.floor(vp.X / 2), math.floor(vp.Y / 2)}

            local eventData = {}
            local Alive = WS:FindFirstChild("Alive")
            if Alive then
                for _, entity in pairs(Alive:GetChildren()) do
                    if entity.PrimaryPart then
                        local ok, sp = pcall(function() return Camera:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                        if ok then eventData[entity.Name] = sp end
                    end
                end
            end

            local ok = pcall(function()
                local packet = {
                    _capturedArgs[1],
                    _capturedArgs[2],
                    _tokenize(_capturedArgs[2]),
                    0.5,
                    GetCurveCFrame(),
                    eventData,
                    aimTarget,
                    false
                }
                if _capturedRemote:IsA('RemoteEvent') then
                    _capturedRemote:FireServer(unpack(packet))
                elseif _capturedRemote:IsA('RemoteFunction') then
                    _capturedRemote:InvokeServer(unpack(packet))
                end
            end)
            return ok
        end

        -- ═══════════════════════════════════════════════
        -- 🎬 ANIMATION
        -- ═══════════════════════════════════════════════
        local function PlayParryAnim()
            if not PlayAnim then return end
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if not humanoid then return end
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if not animator then return end

                local SwordAPI = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("SwordAPI")
                if not SwordAPI then return end
                local collection = SwordAPI:FindFirstChild("Collection")
                if not collection then return end
                local default = collection:FindFirstChild("Default")
                if not default then return end
                local anim = default:FindFirstChild("GrabParry")
                if not anim then return end

                if animCache.track then
                    pcall(function() animCache.track:Stop() end)
                end
                animCache.track = animator:LoadAnimation(anim)
                animCache.track:Play()
            end)
        end

        -- ═══════════════════════════════════════════════
        -- 🛡️ HELPERS
        -- ═══════════════════════════════════════════════
        local function IsAlive()
            local char = LocalPlayer.Character
            if not char then return false end
            local h = char:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then return false end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return false end
            return true, char, hrp
        end

        local function GetPing()
            local ok, ping_str = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
            end)
            if ok and ping_str then
                return tonumber(ping_str:match("%d+")) or 0
            end
            return 0
        end

        -- Cleanup ballLocks (buat spam/triggerbot yang pakai global lock)
        task.spawn(function()
            while task.wait(0.3) do
                local now = tick()
                for ball, t in pairs(ballLocks) do
                    if not ball.Parent or now >= t then ballLocks[ball] = nil end
                end
            end
        end)

        -- ═══════════════════════════════════════════════
        -- 🔥🔥🔥 EAGLE+ AUTO PARRY (predictive ETC)
        -- ═══════════════════════════════════════════════
        local parryStats = {
            attempts   = 0,
            success    = 0,
            pingFactor = 1.0,
            leadBonus  = 0.0,
        }
        local ballFireLock = {}

        local function estimate_ETC(ball, hrp, parry_radius)
            local ballPos = ball.Position
            local vel = ball.AssemblyLinearVelocity
            local rel = hrp.Position - ballPos
            local a = vel:Dot(vel)
            if a < 1e-3 then
                return math.huge, rel.Magnitude
            end
            local b = 2 * rel:Dot(vel)
            local c = rel:Dot(rel) - parry_radius * parry_radius
            local disc = b * b - 4 * a * c
            if disc < 0 then
                return math.huge, rel.Magnitude
            end
            local sq = math.sqrt(disc)
            local t1 = (-b - sq) / (2 * a)
            local t2 = (-b + sq) / (2 * a)
            local t = (t1 > 0 and t1) or (t2 > 0 and t2) or math.huge
            return t, rel.Magnitude
        end

        local function collect_target_balls(ballsFolder, hrp)
            local list = {}
            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if ball:FindFirstChild("ComboCounter") then continue end

                local isTargeted = (ball:GetAttribute("target") == LocalPlayer.Name)
                if not isTargeted then
                    local vel = ball.AssemblyLinearVelocity
                    local toPlayer = (hrp.Position - ball.Position)
                    if vel.Magnitude > 5 and toPlayer.Magnitude > 0 then
                        local approach = vel.Unit:Dot(toPlayer.Unit)
                        if approach > 0.85 then
                            isTargeted = true
                        end
                    end
                end
                if not isTargeted then continue end

                local zoomies = ball:FindFirstChild("zoomies")
                if not zoomies then continue end
                local speed = zoomies.VectorVelocity.Magnitude
                if speed < 1 then continue end

                table.insert(list, {
                    ball = ball,
                    speed = speed,
                    zoomies = zoomies,
                })
            end
            return list
        end

        local function compute_lead(ping_ms, speed, distance)
            local ping_lead = math.clamp(ping_ms / 1000, 0.015, 0.180)
            local speed_bonus = math.clamp((speed - 100) / 500 * 0.04, 0, 0.05)
            local dist_bonus = math.clamp(distance / 100 * 0.02, 0, 0.03)
            local adapt = parryStats.leadBonus
            return ping_lead + speed_bonus + dist_bonus + adapt
        end

        -- adaptive eval tiap 5 detik
        task.spawn(function()
            while task.wait(5) do
                local total = parryStats.attempts
                local wins = parryStats.success
                local rate = (total > 0) and (wins / total) or 0.5
                if rate < 0.75 then
                    parryStats.leadBonus = math.min(parryStats.leadBonus + 0.008, 0.06)
                elseif rate > 0.95 then
                    parryStats.leadBonus = math.max(parryStats.leadBonus - 0.004, -0.02)
                end
                parryStats.attempts = 0
                parryStats.success = 0
            end
        end)

        RunService.PreSimulation:Connect(function()
            if not AutoParryEnabled then return end

            local alive, char, hrp = IsAlive()
            if not alive then return end
            if hrp:FindFirstChild("SingularityCape") then return end

            local ballsFolder = WS:FindFirstChild("Balls")
            if not ballsFolder then return end

            local candidates = collect_target_balls(ballsFolder, hrp)
            if #candidates == 0 then return end

            local ping_ms = GetPing()
            local now = tick()
            local toFire = {}

            for _, c in ipairs(candidates) do
                local ball = c.ball
                local speed = c.speed

                if ballFireLock[ball] and now < ballFireLock[ball] then
                    continue
                end

                local effective_radius = 8 + math.min(speed / 60, 12)
                local etc, dist = estimate_ETC(ball, hrp, effective_radius)
                if etc == math.huge then continue end

                local lead = compute_lead(ping_ms, speed, dist)
                if etc <= lead then
                    table.insert(toFire, {
                        ball = ball,
                        etc = etc,
                        lead = lead,
                        dist = dist,
                        speed = speed,
                    })
                end
            end

            if #toFire == 0 then return end

            table.sort(toFire, function(a, b) return a.etc < b.etc end)

            local target = toFire[1]
            if target then
                local ok = FireParry()
                if ok then
                    parryStats.attempts = parryStats.attempts + 1
                    PlayParryAnim()
                    ballFireLock[target.ball] = now + 0.35

                    -- success heuristic
                    task.spawn(function()
                        local checkStart = tick()
                        while tick() - checkStart < 0.3 do
                            task.wait(0.05)
                            if not target.ball.Parent then
                                parryStats.success = parryStats.success + 1
                                break
                            end
                            local v = target.ball.AssemblyLinearVelocity
                            if v.Magnitude > 1 then
                                local toPlayer = (hrp.Position - target.ball.Position)
                                if toPlayer.Magnitude > 0.1 and v.Unit:Dot(toPlayer.Unit) < 0.3 then
                                    parryStats.success = parryStats.success + 1
                                    break
                                end
                            end
                        end
                    end)
                end
            end

            -- housekeeping ballFireLock
            if math.random() < 0.02 then
                for b, t in pairs(ballFireLock) do
                    if now > t + 5 or not b.Parent then
                        ballFireLock[b] = nil
                    end
                end
            end
        end)

        -- ═══════════════════════════════════════════════
        -- 🎯 TRIGGERBOT
        -- ═══════════════════════════════════════════════
        local lastTriggerTime = 0
        RunService.Heartbeat:Connect(function()
            if not TriggerbotActive then return end

            local now = tick()
            if (now - lastTriggerTime) < (1 / math.max(TriggerCPS, 1)) then return end

            local alive, char, hrp = IsAlive()
            if not alive then return end

            local ballsFolder = WS:FindFirstChild("Balls")
            if not ballsFolder then return end

            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                if ball:GetAttribute("realBall") == false then continue end
                if ballLocks[ball] then continue end
                if ball:GetAttribute('target') ~= LocalPlayer.Name then continue end

                local ballPos = ball.Position
                local distance = (hrp.Position - ballPos).Magnitude
                if distance > TriggerDistance then continue end

                lastTriggerTime = now
                ballLocks[ball] = now + 0.4
                FireParry()
                PlayParryAnim()
                return
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
                if p ~= LocalPlayer and p.Character then
                    local p_hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if p_hrp and (p_hrp.Position - playerPos).Magnitude <= SpamRange then
                        nearPlayer = true
                        break
                    end
                end
            end

            if not nearPlayer then return end
            if (now - lastSpamTime) < (1 / math.max(AutoSpamCPS, 1)) then return end
            lastSpamTime = now

            local burst = math.max(1, math.floor(AutoSpamCPS / 60))
            for _ = 1, burst do FireParry() end
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
            for _ = 1, 8 do FireParry() end
        end)

        print("[Slax Hub] ✅ EAGLE+ Auto Parry Ready")

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
        TriggerGui.Reset
