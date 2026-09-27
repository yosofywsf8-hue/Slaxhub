-- ═══════════════════════════════════════════════════════════════════════════
-- ███████╗██╗      █████╗ ██╗  ██╗    ██╗   ██╗██████╗ 
-- ██╔════╝██║     ██╔══██╗╚██╗██╔╝    ██║   ██║╚════██╗
-- ███████╗██║     ███████║ ╚███╔╝     ██║   ██║ █████╔╝
-- ╚════██║██║     ██╔══██║ ██╔██╗     ╚██╗ ██╔╝ ╚═══██╗
-- ███████║███████╗██║  ██║██╔╝ ██╗     ╚████╔╝ ██████╔╝
-- ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═══╝  ╚═════╝ 
--
-- Slax V2 UI — Mobile-Optimized Auto Parry
-- Author: ALPHA XK | For: Redz
-- Core: Clean V2 (hook stops after capture, intercept solver)
-- UI: WindUI with mobile layout, floating button, live stats
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._slax_v2ui_loaded then
    pcall(function() if _G.slax_v2ui_unload then _G.slax_v2ui_unload() end end)
    getgenv()._slax_v2ui_loaded = nil
    task.wait(0.2)
end
getgenv()._slax_v2ui_loaded = true

-- == Services =============================================================
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local WS            = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local Stats         = game:GetService("Stats")
local UIS           = game:GetService("UserInputService")
local LP            = Players.LocalPlayer

-- == Config ===============================================================
local Config = {
    enabled         = true,
    accuracy        = 100,
    parryCooldown   = 0.08,
    maxRange        = 20,
    pingComp        = 0.6,
    humanize        = false,
    humanizeJitter  = 0.015,
    autoClash       = true,
    clashRadius     = 22,
    ballESP         = false,
    toggleKey       = "E",
    panicKey        = "END",
    debugMode       = false,
}

-- == State ===============================================================
local State = {
    running         = true,
    captured        = false,
    remote          = nil,
    method          = nil,
    args            = nil,
    token           = nil,
    tokenOK         = false,
    parried         = setmetatable({}, { __mode = "k" }),
    tracker         = setmetatable({}, { __mode = "k" }),
    lastParry       = 0,
    parryCount      = 0,
    clashCount      = 0,
    ping            = 0.06,
    hookedMetas     = {},
    espHighlights   = setmetatable({}, { __mode = "k" }),
}

-- == Token ==============================================================
local function findToken()
    if not (getgc and debug and debug.getupvalues and debug.info) then return nil end
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then return nil end
    for i = 1, #gc do
        local fn = gc[i]
        if type(fn) ~= "function" then continue end
        local ok2, name = pcall(debug.info, fn, 's')
        if not ok2 or not name or not tostring(name):find('PRY', 1, true) then continue end
        local ok3, ups = pcall(debug.getupvalues, fn)
        if not ok3 then continue end
        for _, v in ipairs(ups) do
            if type(v) == "function" then return v end
        end
    end
    return nil
end

print("[SlaxV2] Scanning token...")
State.token = findToken()
if State.token then
    State.tokenOK = true
    print("[SlaxV2] Token OK")
else
    task.spawn(function()
        for _ = 1, 15 do
            task.wait(2)
            State.token = findToken()
            if State.token then
                State.tokenOK = true
                print("[SlaxV2] Token OK (late)")
                break
            end
        end
    end)
end

local function tokenize(uid)
    if not State.token then return "" end
    local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local ok, key = pcall(State.token, uid, 'TIME')
    if not ok or type(key) ~= "string" or #key == 0 then return "" end
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)
        ))
    end
    return table.concat(out)
end

-- == Remote Hook =========================================================
local function hookRemote(remote)
    local meta
    local ok, m = pcall(getrawmetatable, remote)
    if ok and m then meta = m end
    if not meta then
        local ok2, m2 = pcall(getmetatable, remote)
        if ok2 and m2 then meta = m2 end
    end
    if not meta then return end
    if State.hookedMetas[meta] then return end

    local oldIndex = meta.__index
    State.hookedMetas[meta] = { meta = meta, oldIndex = oldIndex }

    pcall(setreadonly, meta, false)
    meta.__index = function(self, key)
        if key == 'FireServer' or key == 'InvokeServer' then
            if self == remote then
                local original = oldIndex(self, key)
                if not State.captured and type(original) == "function" then
                    return function(_, ...)
                        local a = {...}
                        if not State.captured and #a == 8
                            and type(a[2]) == "string"
                            and type(a[3]) == "string"
                            and type(a[4]) == "number"
                            and typeof(a[5]) == "CFrame"
                            and type(a[6]) == "table"
                            and type(a[7]) == "table"
                            and type(a[8]) == "boolean" then
                            State.remote = self
                            State.method = key
                            State.args = a
                            State.captured = true
                            print("[SlaxV2] Remote captured: " .. self.Name)

                            task.spawn(function()
                                task.wait(1)
                                for _, info in pairs(State.hookedMetas) do
                                    pcall(function()
                                        setreadonly(info.meta, false)
                                        info.meta.__index = info.oldIndex
                                        setreadonly(info.meta, true)
                                    end)
                                end
                                print("[SlaxV2] Hooks uninstalled")
                            end)
                        end
                        return original(_, ...)
                    end
                end
                return original
            end
        end
        return oldIndex(self, key)
    end
    pcall(setreadonly, meta, true)
end

for _, r in ipairs(RS:GetDescendants()) do
    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
        hookRemote(r)
    end
end

-- == Ping Cache =========================================================
task.spawn(function()
    while State.running do
        pcall(function()
            local raw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            State.ping = math.clamp(raw / 1000, 0.02, 0.30)
        end)
        task.wait(0.5)
    end
end)

-- == Character ==========================================================
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

-- == Tracker ============================================================
local function updateTracker(ball, dt)
    local z = ball:FindFirstChild("zoomies")
    if not z then return nil end
    local pos, vel = ball.Position, z.VectorVelocity
    local rec = State.tracker[ball]
    if not rec then
        rec = { pos = pos, vel = vel, accel = Vector3.zero, t = tick() }
        State.tracker[ball] = rec
        return rec
    end
    if dt > 0.001 then
        local dvel = vel - rec.vel
        rec.accel = rec.accel * 0.5 + (dvel / dt) * 0.5
    end
    rec.pos, rec.vel, rec.t = pos, vel, tick()
    return rec
end

-- == Intercept Solver ===================================================
local function solveIntercept(ballPos, ballVel, myPos, radius)
    local dp = ballPos - myPos
    local A = ballVel:Dot(ballVel)
    if A < 0.0001 then return nil end
    local B = 2 * dp:Dot(ballVel)
    local C = dp:Dot(dp) - radius * radius
    local disc = B * B - 4 * A * C
    if disc < 0 then return nil end
    local sq = math.sqrt(disc)
    local t1 = (-B - sq) / (2 * A)
    local t2 = (-B + sq) / (2 * A)
    if t1 > 0 then return t1 end
    if t2 > 0 then return t2 end
    return nil
end

-- == Fire ===============================================================
local function fireParry(aim)
    if not State.captured then return false end
    if not State.remote or not State.remote.Parent then
        State.captured = false
        return false
    end
    local cam = WS.CurrentCamera
    if not cam then return false end
    if not aim then
        local vp = cam.ViewportSize
        aim = { math.floor(vp.X / 2), math.floor(vp.Y / 2) }
    end
    local uid = State.args[2]
    local packet = {
        State.args[1], uid, tokenize(uid), 0.5,
        cam.CFrame, {}, aim, false
    }
    local ok = pcall(function()
        if State.method == "FireServer" then
            State.remote:FireServer(unpack(packet))
        else
            State.remote:InvokeServer(unpack(packet))
        end
    end)
    if ok then
        State.parryCount = State.parryCount + 1
    end
    return ok
end

-- == Main Loop ==========================================================
local lastFrame = tick()

RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    if not State.captured then return end

    local now = tick()
    local dt = now - lastFrame
    lastFrame = now

    local cd = Config.parryCooldown
    if Config.humanize and Config.humanizeJitter > 0 then
        cd = cd + (math.random() * 2 - 1) * Config.humanizeJitter
    end
    if now - State.lastParry < cd then return end

    local alive, char, hrp = isAlive()
    if not alive then return end

    local folder = WS:FindFirstChild("Balls")
    if not folder then return end

    local myPos = hrp.Position
    local myName = LP.Name
    local best, bestT = nil, math.huge

    for _, ball in ipairs(folder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if State.parried[ball] then continue end
        if ball:FindFirstChild("ComboCounter") then continue end
        if ball:GetAttribute("target") ~= myName then continue end

        local rec = updateTracker(ball, dt)
        if not rec then continue end
        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        local vel = z.VectorVelocity
        local speed = vel.Magnitude
        if speed < 5 then continue end

        local toMe = myPos - ball.Position
        if toMe.Magnitude < 0.1 then continue end
        local dot = vel.Unit:Dot(toMe.Unit)
        if dot <= 0.15 then continue end

        local accMul = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035
        local window = Config.maxRange * accMul + math.min(speed * 0.05, 20)

        local tI = solveIntercept(ball.Position, vel, myPos, window)
        if not tI then
            local predPos = ball.Position + vel * (State.ping * Config.pingComp)
            local dist = (myPos - predPos).Magnitude
            if dist <= window then tI = State.ping end
        end
        if not tI or tI < 0 then continue end

        local fireAt = tI - State.ping * Config.pingComp
        if fireAt <= 0.01 and tI < bestT then
            bestT, best = tI, ball
        end
    end

    -- clash detection
    if not best and Config.autoClash then
        local count = 0
        for _, b in ipairs(folder:GetChildren()) do
            if b:IsA("BasePart") and b:GetAttribute("realBall") ~= false then
                local z = b:FindFirstChild("zoomies")
                if z and z.VectorVelocity.Magnitude > 30 then
                    if (myPos - b.Position).Magnitude < Config.clashRadius then
                        count = count + 1
                    end
                end
            end
        end
        if count >= 2 then
            if fireParry() then
                State.lastParry = now
                State.clashCount = State.clashCount + 1
            end
            return
        end
    end

    if best then
        local cam = WS.CurrentCamera
        local aim
        if cam then
            local sp = cam:WorldToScreenPoint(best.Position)
            if sp then aim = { math.floor(sp.X), math.floor(sp.Y) } end
        end
        if fireParry(aim) then
            State.parried[best] = true
            State.lastParry = now
            task.delay(0.35, function()
                if State.parried[best] then State.parried[best] = nil end
            end)
        end
    end
end)

-- == ESP ================================================================
task.spawn(function()
    while State.running do
        if not Config.ballESP then
            for ball, hl in pairs(State.espHighlights) do
                pcall(function() hl:Destroy() end)
                State.espHighlights[ball] = nil
            end
        else
            local folder = WS:FindFirstChild("Balls")
            if folder then
                for _, ball in ipairs(folder:GetChildren()) do
                    if ball:IsA("BasePart")
                        and ball:GetAttribute("target") == LP.Name
                        and not State.espHighlights[ball] then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.fromRGB(255, 60, 60)
                        hl.FillTransparency = 0.55
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = ball
                        State.espHighlights[ball] = hl
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- == Keybinds ===========================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[SlaxV2]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        Config.autoClash = false
        Config.ballESP = false
        print("[SlaxV2] PANIC")
    end
end)

-- ═════════════════════════════════════════════════════════════════════════
-- UI — WindUI Mobile Layout
-- ═════════════════════════════════════════════════════════════════════════

local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"
    ))()
end)

if ok and WindUI then
    local Window = WindUI:CreateWindow({
        Title = "Slax V2",
        Icon = "lucide-sword",
        Author = "ALPHA XK",
        Folder = "SlaxV2",
        Size = UDim2.fromOffset(330, 440),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 0,
    })

    Window:EditOpenButton({
        Title = "Slax",
        Icon = "lucide-sword",
        CornerRadius = UDim.new(0, 12),
        StrokeThickness = 2,
        StrokeColor = Color3.fromRGB(80, 200, 120),
    })

    local TabMain    = Window:Tab({ Title = "Main",    Icon = "lucide-shield" })
    local TabCombat  = Window:Tab({ Title = "Combat",  Icon = "lucide-sword" })
    local TabVisual  = Window:Tab({ Title = "Visual",  Icon = "lucide-eye" })
    local TabInfo    = Window:Tab({ Title = "Info",    Icon = "lucide-info" })

    -- MAIN
    TabMain:Toggle({
        Title = "Auto Parry",
        Desc = "Predicted parry + intercept solver",
        Value = Config.enabled,
        Callback = function(v) Config.enabled = v end,
    })

    TabMain:Toggle({
        Title = "Auto Clash",
        Desc = "Parry saat 2+ balls mendekat",
        Value = Config.autoClash,
        Callback = function(v) Config.autoClash = v end,
    })

    TabMain:Slider({
        Title = "Clash Radius",
        Value = { Min = 12, Max = 40, Default = Config.clashRadius, Step = 1 },
        Callback = function(v) Config.clashRadius = v end,
    })

    TabMain:Toggle({
        Title = "Humanize (Anti-Detect)",
        Desc = "jitter ±15ms delay",
        Value = Config.humanize,
        Callback = function(v) Config.humanize = v end,
    })

    TabMain:Slider({
        Title = "Jitter (ms)",
        Value = { Min = 0, Max = 50, Default = 15, Step = 1 },
        Callback = function(v) Config.humanizeJitter = v / 1000 end,
    })

    -- COMBAT
    TabCombat:Slider({
        Title = "Accuracy 1-100",
        Desc = "1 = konservatif | 100 = OP",
        Value = { Min = 1, Max = 100, Default = Config.accuracy, Step = 1 },
        Callback = function(v) Config.accuracy = v end,
    })

    TabCombat:Slider({
        Title = "Parry Cooldown (ms)",
        Value = { Min = 50, Max = 300, Default = 80, Step = 10 },
        Callback = function(v) Config.parryCooldown = v / 1000 end,
    })

    TabCombat:Slider({
        Title = "Max Range (studs)",
        Value = { Min = 10, Max = 40, Default = 20, Step = 1 },
        Callback = function(v) Config.maxRange = v end,
    })

    TabCombat:Slider({
        Title = "Ping Compensation",
        Desc = "0.5 = conservative | 0.8 = aggressive",
        Value = { Min = 40, Max = 90, Default = 60, Step = 5 },
        Callback = function(v) Config.pingComp = v / 100 end,
    })

    TabCombat:Section({ Title = "Keybinds" })

    TabCombat:Keybind({
        Title = "Toggle Auto Parry",
        Value = Config.toggleKey,
        Callback = function(k)
            if type(k) == "string" then Config.toggleKey = k end
        end,
    })

    TabCombat:Keybind({
        Title = "Panic Key",
        Value = Config.panicKey,
        Callback = function(k)
            if type(k) == "string" then Config.panicKey = k end
        end,
    })

    -- VISUAL
    TabVisual:Toggle({
        Title = "Ball ESP",
        Desc = "Highlight الكرات اللي تستهدفك",
        Value = Config.ballESP,
        Callback = function(v) Config.ballESP = v end,
    })

    TabVisual:Section({ Title = "Info" })

    TabVisual:Paragraph({
        Title = "Token",
        Desc = State.tokenOK and "✅ Found" or "⏳ Searching...",
    })

    TabVisual:Paragraph({
        Title = "Remote",
        Desc = State.captured and ("✅ " .. State.remote.Name) or "⏳ Parry once in-game",
    })

    -- INFO (Live Stats)
    local infoParries = TabInfo:Paragraph({
        Title = "Total Parries",
        Desc = "0",
    })

    local infoClash = TabInfo:Paragraph({
        Title = "Clash Parries",
        Desc = "0",
    })

    local infoPing = TabInfo:Paragraph({
        Title = "Ping",
        Desc = "0 ms",
    })

    local infoStatus = TabInfo:Paragraph({
        Title = "Status",
        Desc = "Idle",
    })

    task.spawn(function()
        while State.running do
            task.wait(0.5)
            pcall(function()
                infoParries:SetDesc(tostring(State.parryCount))
                infoClash:SetDesc(tostring(State.clashCount))
                infoPing:SetDesc(string.format("%.0f ms", State.ping * 1000))

                local status = "Idle"
                if not State.captured then
                    status = "Waiting for remote"
                elseif Config.enabled then
                    status = "Active"
                else
                    status = "Disabled"
                end
                infoStatus:SetDesc(status)
            end)
        end
    end)

    TabInfo:Section({ Title = "Instructions" })

    TabInfo:Paragraph({
        Title = "How to use",
        Desc = "1. Parry once in-game\n2. Wait for 'Remote captured'\n3. Auto Parry يعمل تلقائياً",
    })

    TabInfo:Paragraph({
        Title = "Hotkeys",
        Desc = Config.toggleKey .. " = Toggle | " .. Config.panicKey .. " = Panic",
    })

    TabInfo:Section({ Title = "Actions" })

    TabInfo:Button({
        Title = "Unload Script",
        Callback = function()
            if _G.slax_v2ui_unload then
                _G.slax_v2ui_unload()
            end
        end,
    })
end

-- == Init ==============================================================
print("[SlaxV2] Loaded")
print("[SlaxV2] Toggle: " .. Config.toggleKey .. " | Panic: " .. Config.panicKey)

-- == Unload ============================================================
_G.slax_v2ui_unload = function()
    State.running = false
    -- uninstall hooks
    for _, info in pairs(State.hookedMetas) do
        pcall(function()
            setreadonly(info.meta, false)
            info.meta.__index = info.oldIndex
            setreadonly(info.meta, true)
        end)
    end
    -- destroy ESP
    for _, hl in pairs(State.espHighlights) do
        pcall(function() hl:Destroy() end)
    end
    getgenv()._slax_v2ui_loaded = nil
    print("[SlaxV2] Unloaded")
end
