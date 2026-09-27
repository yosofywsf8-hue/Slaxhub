-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V7 MOBILE — Blade Ball Auto Parry (Anti-Crash)
-- Author: ALPHA XK | For: Redz
-- Mobile-Optimized | No getgc scan | Single hook | Throttled loops
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._slax_mobile_loaded then
    pcall(function() if _G.slax_mobile_unload then _G.slax_mobile_unload() end end)
    getgenv()._slax_mobile_loaded = nil
    task.wait(0.15)
end
getgenv()._slax_mobile_loaded = true

-- == Services =============================================================
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local WS            = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local Stats         = game:GetService("Stats")
local LP            = Players.LocalPlayer

-- == Config ===============================================================
local Config = {
    enabled         = true,
    accuracy        = 100,
    curveMethod     = "camera",
    autoSpam        = false,
    autoSpamCPS     = 200,
    triggerBot      = false,
    invisEnabled    = false,
    toggleKey       = "E",
    panicKey        = "END",
}

-- == State ================================================================
local State = {
    running         = true,
    parried         = setmetatable({}, { __mode = "k" }),
    parryCount      = 0,
    lastParry       = 0,
    lastSpam        = 0,
    ping            = 0.06,
    pingSmooth      = 60,
    curveState      = setmetatable({}, { __mode = "k" }),
    parryCDUntil    = 0,
    parriedMain     = false,
    currentCurve    = "camera",
}

-- == Remote Hook — مفرد، خفيف =============================================
local Captured = {
    remote = nil,
    method = nil,
    args = nil,
    done = false,
}

local _origIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if Captured.done then
        return _origIndex(self, key)
    end
    if key ~= "FireServer" and key ~= "InvokeServer" then
        return _origIndex(self, key)
    end
    if checkcaller() then
        return _origIndex(self, key)
    end
    return function(_, ...)
        local args = { ... }
        if not Captured.remote and #args == 7
            and type(args[2]) == "string"
            and type(args[3]) == "string"
            and typeof(args[4]) == "number"
            and typeof(args[5]) == "CFrame"
            and type(args[6]) == "table"
            and type(args[7]) == "table" then
            Captured.remote = self
            Captured.method = key
            Captured.args = args
            Captured.done = true
            print("[V7M] Remote captured:", self.Name)
        end
        return _origIndex(self, key)(_, ...)
    end
end))

-- == Character ============================================================
local function isAlive()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if hrp:FindFirstChild("SingularityCape") then return false end
    return true, char, hrp
end

-- == Ping Cache ===========================================================
task.spawn(function()
    while State.running do
        pcall(function()
            local raw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            State.ping = raw / 1000
            State.pingSmooth = State.pingSmooth * 0.6 + raw * 0.4
        end)
        task.wait(1)
    end
end)

-- == Curve Methods (7) ====================================================
local function getCurveCFrame(myPos)
    local cam = WS.CurrentCamera
    if not cam then return CFrame.new(myPos) end
    
    local targetPos = myPos + cam.CFrame.LookVector * 1000
    local aliveFolder = WS:FindFirstChild("Alive")
    if aliveFolder then
        local bestDot, bestPos = -math.huge, nil
        for _, e in ipairs(aliveFolder:GetChildren()) do
            local hrp = e:FindFirstChild("HumanoidRootPart")
            if hrp and e ~= LP.Character then
                local dir = (hrp.Position - cam.CFrame.Position).Unit
                local dot = cam.CFrame.LookVector:Dot(dir)
                if dot > bestDot then
                    bestDot, bestPos = dot, hrp.Position
                end
            end
        end
        if bestPos then targetPos = bestPos end
    end
    
    local method = State.currentCurve
    if method == "dot" then
        return CFrame.lookAt(myPos, targetPos + Vector3.new(0, 1.75, 0))
    elseif method == "backwards" then
        return CFrame.new(myPos, myPos + (myPos - targetPos).Unit * 1000)
    elseif method == "high" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 9e18, 0))
    elseif method == "slow" then
        return CFrame.new(myPos, myPos + Vector3.new(0, -350, 0))
    elseif method == "random" then
        local rnd = Vector3.new(math.random(-3000, 3000), math.random(-3000, 3000), math.random(-3000, 3000))
        return CFrame.new(myPos, targetPos + rnd)
    elseif method == "accelerated" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 5, 0))
    else
        return cam.CFrame
    end
end

-- == Curve Detection — خفيف (طريقتين فقط) =================================
local function isCurved(ball, myPos)
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local vel = z.VectorVelocity
    local spd = vel.Magnitude
    if spd < 5 then return false end
    
    local dir = (myPos - ball.Position).Unit
    local dot = dir:Dot(vel.Unit)
    
    -- طريقة 1: backward curve
    if dot < -0.1 then return true end
    
    -- طريقة 2: lateral component
    local lat = (vel - (vel:Dot(dir) * dir)).Magnitude
    if lat / spd > 0.35 then return true end
    
    return false
end

-- == Fire Window ==========================================================
local function computeWindow(speed)
    local ping = State.pingSmooth or State.ping * 1000
    local pingThr = math.clamp(ping / 80, 4, 25)
    local mult = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035353535353535
    local divisor = (2.2 + 0.9 * math.log(1 + speed / 80)) * mult
    local sf = 1
    if speed > 200 then sf = 1 + math.min((speed - 200) / 1000, 0.3) end
    return pingThr + math.max(speed / divisor, 9.5) * sf
end

-- == Fire Parry ===========================================================
local cachedAim = {0, 0}
local cachedEvents = {}
local _camUpdateAcc = 0

RunService.RenderStepped:Connect(function(dt)
    -- Throttle: 20fps بدل 60fps
    _camUpdateAcc = _camUpdateAcc + dt
    if _camUpdateAcc < 0.05 then return end
    _camUpdateAcc = 0
    
    local cam = WS.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        cachedAim = {vp.X / 2, vp.Y / 2}
    else
        local ok, mouse = pcall(UIS.GetMouseLocation, UIS)
        cachedAim = ok and {mouse.X, mouse.Y} or {vp.X / 2, vp.Y / 2}
    end
    
    local aliveFolder = WS:FindFirstChild("Alive")
    if aliveFolder then
        local data = {}
        for _, e in ipairs(aliveFolder:GetChildren()) do
            local pp = e.PrimaryPart
            if pp then
                local ok2, sp = pcall(cam.WorldToScreenPoint, cam, pp.Position)
                if ok2 then data[e.Name] = sp end
            end
        end
        cachedEvents = data
    end
end)

local function fireParry(aim)
    if not Captured.remote or not Captured.args then return false end
    local cam = WS.CurrentCamera
    if not cam then return false end
    local char = LP.Character
    if not char or not char.PrimaryPart then return false end
    
    aim = aim or cachedAim
    local curveCF = getCurveCFrame(char.PrimaryPart.Position)
    
    local pkt = {
        Captured.args[1],
        Captured.args[2],
        Captured.args[3],
        Captured.args[4],
        curveCF,
        cachedEvents,
        aim,
        Captured.args[8] or false
    }
    
    local ok = pcall(function()
        if Captured.method == "FireServer" then
            Captured.remote:FireServer(unpack(pkt))
        else
            Captured.remote:InvokeServer(unpack(pkt))
        end
    end)
    if ok then
        State.parryCount = State.parryCount + 1
    end
    return ok
end

-- == Main Parry Loop ======================================================
local lastFrame = tick()

RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    local now = tick()
    local dt = now - lastFrame
    lastFrame = now
    
    if State.parriedMain then
        if now >= State.parryCDUntil then
            State.parriedMain = false
        else
            return
        end
    end
    
    local alive, char, hrp = isAlive()
    if not alive then return end
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    
    local myPos = hrp.Position
    local myName = LP.Name
    local best, bestScore, bestSpeed = nil, math.huge, 0
    
    -- cached ball list (10 Hz refresh)
    local _nowT = tick()
    if not State._ballCache or _nowT - (State._ballCacheTime or 0) > 0.1 then
        State._ballCache = folder:GetChildren()
        State._ballCacheTime = _nowT
    end
    
    for _, ball in ipairs(State._ballCache) do
        if not ball.Parent then continue end
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if State.parried[ball] then continue end
        if ball:FindFirstChild("ComboCounter") then continue end
        if ball:GetAttribute("target") ~= myName then continue end
        
        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        local vel = z.VectorVelocity
        local speed = vel.Magnitude
        if speed < 5 then continue end
        
        local rawDist = (myPos - ball.Position).Magnitude
        if rawDist > 120 then continue end -- تجاهل البعيد
        
        -- ping compensation
        local t = State.ping / 2
        local predPos = ball.Position + vel * t
        local dist = (myPos - predPos).Magnitude
        
        local curved = isCurved(ball, myPos)
        local window = computeWindow(speed)
        if curved then window = window * 0.7 end
        
        if dist <= window then
            local score = dist - speed * 0.05
            if score < bestScore then
                best, bestScore, bestSpeed = ball, score, speed
            end
        end
    end
    
    if best then
        local cam = WS.CurrentCamera
        local aim
        if cam then
            local z = best:FindFirstChild("zoomies")
            if z then
                local sp = cam:WorldToScreenPoint(best.Position + z.VectorVelocity * 0.05)
                if sp then aim = {math.floor(sp.X), math.floor(sp.Y)} end
            end
        end
        
        if fireParry(aim) then
            State.parried[best] = true
            State.parriedMain = true
            State.lastParry = now
            State.parryCDUntil = now + math.clamp(4.9 - bestSpeed * 0.01, 0.7, 0.85)
            task.delay(0.4, function()
                if State.parried[best] then State.parried[best] = nil end
            end)
        end
    end
end)

-- == Auto Spam ============================================================
local autoSpamConn = nil

local function startAutoSpam()
    if autoSpamConn then autoSpamConn:Disconnect() end
    autoSpamConn = RunService.PreSimulation:Connect(function()
        if not Config.autoSpam then return end
        local alive, char = isAlive()
        if not alive then return end
        
        local now = tick()
        local interval = 1 / Config.autoSpamCPS
        if now - State.lastSpam < interval then return end
        State.lastSpam = now
        
        local folder = WS:FindFirstChild("Balls")
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:GetAttribute("target") == LP.Name then
                fireParry()
                return
            end
        end
    end)
end

-- == Trigger Bot ==========================================================
local triggerConn = nil
local triggerBusy = false

local function startTriggerBot()
    if triggerConn then triggerConn:Disconnect() end
    triggerConn = RunService.Heartbeat:Connect(function()
        if not Config.triggerBot then return end
        if triggerBusy then return end
        local alive = isAlive()
        if not alive then return end
        
        local folder = WS:FindFirstChild("Balls")
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:IsA("BasePart") and ball:GetAttribute("target") == LP.Name then
                triggerBusy = true
                fireParry()
                task.delay(0.5, function() triggerBusy = false end)
                break
            end
        end
    end)
end

-- == Invisibility — خفيف ==================================================
local InvisState = { enabled = false, conn = nil, desync = {} }

local function performInvis()
    if not InvisState.enabled then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local alive = WS:FindFirstChild("Alive")
    if not alive or char.Parent ~= alive then return end
    
    InvisState.desync[1] = hrp.CFrame
    InvisState.desync[2] = hrp.AssemblyLinearVelocity
    
    local angle = math.random() * math.pi * 2
    hrp.CFrame = CFrame.new(
        hrp.Position.X + math.cos(angle) * 25,
        hrp.Position.Y + 15,
        hrp.Position.Z + math.sin(angle) * 25
    )
    hrp.AssemblyLinearVelocity = Vector3.zero
    
    RunService.RenderStepped:Wait()
    
    hrp.CFrame = InvisState.desync[1]
    hrp.AssemblyLinearVelocity = InvisState.desync[2]
end

local function toggleInvis(enabled)
    InvisState.enabled = enabled
    if enabled then
        if not InvisState.conn then
            InvisState.conn = RunService.Heartbeat:Connect(performInvis)
        end
    else
        if InvisState.conn then
            InvisState.conn:Disconnect()
            InvisState.conn = nil
        end
    end
end

-- == Keybinds =============================================================
local curveKeyMap = {
    [Enum.KeyCode.One]   = "camera",
    [Enum.KeyCode.Two]   = "dot",
    [Enum.KeyCode.Three] = "backwards",
    [Enum.KeyCode.Four]  = "slow",
    [Enum.KeyCode.Five]  = "random",
    [Enum.KeyCode.Six]   = "accelerated",
    [Enum.KeyCode.Seven] = "high",
}

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeyMap[input.KeyCode] then
        State.currentCurve = curveKeyMap[input.KeyCode]
        print("[V7M] Curve:", State.currentCurve)
    end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[V7M]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        Config.autoSpam = false
        Config.triggerBot = false
        toggleInvis(false)
        print("[V7M] PANIC")
    end
end)

-- == UI — بسيط للجوال =====================================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "Slax V7 Mobile",
    Icon = "lucide-crown",
    Author = "ALPHA XK",
    Folder = "SlaxV7M",
    Size = UDim2.fromOffset(320, 400),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 0,
})

Window:EditOpenButton({
    Title = "V7M",
    Icon = "lucide-crown",
    CornerRadius = UDim.new(0, 12),
    StrokeColor = Color3.fromRGB(255, 200, 80),
})

local TabMain = Window:Tab({ Title = "Combat", Icon = "lucide-sword" })
local TabCurve = Window:Tab({ Title = "Curve", Icon = "lucide-activity" })
local TabExtra = Window:Tab({ Title = "Extra", Icon = "lucide-zap" })

TabMain:Toggle({
    Title = "Auto Parry",
    Value = Config.enabled,
    Callback = function(v) Config.enabled = v end,
})

TabMain:Slider({
    Title = "Accuracy 1-100",
    Value = { Min = 1, Max = 100, Default = Config.accuracy, Step = 1 },
    Callback = function(v) Config.accuracy = v end,
})

TabMain:Toggle({
    Title = "Auto Spam",
    Value = Config.autoSpam,
    Callback = function(v)
        Config.autoSpam = v
        if v then startAutoSpam() end
    end,
})

TabMain:Slider({
    Title = "Spam CPS",
    Value = { Min = 50, Max = 1000, Default = Config.autoSpamCPS, Step = 50 },
    Callback = function(v) Config.autoSpamCPS = v end,
})

TabMain:Toggle({
    Title = "Trigger Bot",
    Value = Config.triggerBot,
    Callback = function(v)
        Config.triggerBot = v
        if v then startTriggerBot() end
    end,
})

TabCurve:Dropdown({
    Title = "Curve Method",
    Values = {"camera", "dot", "backwards", "slow", "random", "accelerated", "high"},
    Value = Config.curveMethod,
    Callback = function(v)
        Config.curveMethod = v
        State.currentCurve = v
    end,
})

TabCurve:Paragraph({
    Title = "Curve Hotkeys",
    Desc = "1=camera, 2=dot, 3=backwards, 4=slow, 5=random, 6=accelerated, 7=high",
})

TabExtra:Toggle({
    Title = "Invisibility",
    Value = Config.invisEnabled,
    Callback = function(v)
        Config.invisEnabled = v
        toggleInvis(v)
    end,
})

-- == Init =================================================================
task.spawn(function()
    local deadline = tick() + 30
    while not Captured.done and tick() < deadline do
        task.wait(0.5)
    end
    if Captured.done then
        print("[V7M] Remote captured: " .. tostring(Captured.remote.Name))
    else
        print("[V7M] Remote not captured — parry manually 1-3 times")
    end
end)

print("[V7M] Slax V7 Mobile loaded")
print("[V7M] Toggle: E | Panic: END | Curves: 1-7")

-- == Unload ===============================================================
_G.slax_mobile_unload = function()
    State.running = false
    if autoSpamConn then autoSpamConn:Disconnect() end
    if triggerConn then triggerConn:Disconnect() end
    if InvisState.conn then InvisState.conn:Disconnect() end
    getgenv()._slax_mobile_loaded = nil
end
