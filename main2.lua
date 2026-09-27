-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V10 RAW — Fire Everything, Zero Filter
-- Author: ALPHA XK | For: Redz
-- Prinsip: tiap bola yang approaching player = fire. Selesai.
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._slax_loaded then
    pcall(function() if _G.slax_unload then _G.slax_unload() end end)
    getgenv()._slax_loaded = nil
    task.wait(0.15)
end
getgenv()._slax_loaded = true

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG — raw minimal
-- ═══════════════════════════════════════════════════════════════════════════
local Config = {
    enabled         = true,
    accuracy        = 100,     -- slider di UI
    maxDist         = 200,     -- radius bola approaching
    fireCooldown    = 0.08,    -- min jeda antar-fire (biar nggak kick)
    maxFirePerFrame = 3,       -- cap fire per frame
    curveMethod     = "camera",
}

local State = {
    running      = true,
    parryCount   = 0,
    lastFireTime = 0,
    currentCurve = "camera",
    ballLastFire = setmetatable({}, { __mode = "k" }),
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOKEN — scan + regen
-- ═══════════════════════════════════════════════════════════════════════════
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' then
        local ok, src = pcall(function() return debug.info(f, 's') end)
        if ok and src and tostring(src):find('PRY', 1, true) then
            local ok2, ups = pcall(function() return debug.getupvalues(f) end)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if type(v) == 'function' then _token = v; break end
                end
            end
            if _token then break end
        end
    end
end

local function _tokenize(uid)
    if not _token then return nil end
    local ok, res = pcall(function()
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
    return ok and res or nil
end

print("[V10] token:", _token and "OK" or "FAIL")

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK — capture remote & args
-- ═══════════════════════════════════════════════════════════════════════════
local Captured = { remote = nil, method = nil, args = nil, done = false }

local function _hook_remote(remote, mt)
    pcall(setreadonly, mt, false)
    local old = mt.__index
    mt.__index = function(inst, key)
        if key == 'FireServer' or key == 'InvokeServer' then
            return function(_, ...)
                local args = { ... }
                if not Captured.remote and #args >= 6
                and type(args[2]) == 'string'
                and type(args[3]) == 'string'
                and typeof(args[5]) == 'CFrame' then
                    Captured.remote = inst
                    Captured.method = key
                    Captured.args = args
                    Captured.done = true
                    print("[V10] captured:", inst.Name, "#args="..#args)
                end
                return old(inst, key)(_, ...)
            end
        end
        return old(inst, key)
    end
    pcall(setreadonly, mt, true)
end

local _hooked = {}
for _, r in ipairs(RS:GetDescendants()) do
    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
        local ok, mt = pcall(getrawmetatable, r)
        if ok and mt and not _hooked[mt] then
            _hooked[mt] = true
            _hook_remote(r, mt)
        end
    end
end

print("[V10] remotes hooked")

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARACTER
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- CURVE
-- ═══════════════════════════════════════════════════════════════════════════
local cachedAim = {0, 0}
local cachedEvents = {}
local _camAcc = 0

RunService.RenderStepped:Connect(function(dt)
    _camAcc = _camAcc + dt
    if _camAcc < 0.05 then return end
    _camAcc = 0
    local cam = WS.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        cachedAim = {vp.X/2, vp.Y/2}
    else
        local ok, m = pcall(UIS.GetMouseLocation, UIS)
        cachedAim = ok and {m.X, m.Y} or {vp.X/2, vp.Y/2}
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
                if dot > bestDot then bestDot, bestPos = dot, hrp.Position end
            end
        end
        if bestPos then targetPos = bestPos end
    end
    local m = State.currentCurve
    if m == "dot" then
        return CFrame.lookAt(myPos, targetPos + Vector3.new(0, 1.75, 0))
    elseif m == "backwards" then
        return CFrame.new(myPos, myPos + (myPos - targetPos).Unit * 1000)
    elseif m == "high" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 9e18, 0))
    elseif m == "slow" then
        return CFrame.new(myPos, myPos + Vector3.new(0, -350, 0))
    elseif m == "random" then
        local rnd = Vector3.new(math.random(-3000,3000), math.random(-3000,3000), math.random(-3000,3000))
        return CFrame.new(myPos, targetPos + rnd)
    elseif m == "accelerated" then
        return CFrame.new(myPos, targetPos + Vector3.new(0, 5, 0))
    else
        return cam.CFrame
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FIRE — simple, no timing window, no mode
-- ═══════════════════════════════════════════════════════════════════════════
local function fireParry(aim)
    if not Captured.remote or not Captured.args then return false end
    local cam = WS.CurrentCamera
    if not cam then return false end
    local char = LP.Character
    if not char or not char.PrimaryPart then return false end

    aim = aim or cachedAim
    local curveCF = getCurveCFrame(char.PrimaryPart.Position)

    local uid = Captured.args[2]
    local tok = _tokenize(uid) or Captured.args[3]

    local pkt = {
        Captured.args[1],
        uid,
        tok,
        0.5,
        curveCF,
        cachedEvents,
        aim,
        false
    }
    if #Captured.args > 8 then
        pkt[6] = Captured.args[6] or cachedEvents
        pkt[7] = Captured.args[7] or aim
        pkt[8] = Captured.args[8] or false
    end

    local ok = pcall(function()
        if Captured.method == 'FireServer' then
            Captured.remote:FireServer(unpack(pkt))
        else
            Captured.remote:InvokeServer(unpack(pkt))
        end
    end)
    if ok then State.parryCount = State.parryCount + 1 end
    return ok
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN LOOP — fire tiap bola approaching, zero filter
-- ═══════════════════════════════════════════════════════════════════════════
RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    local now = tick()

    local alive, char, hrp = isAlive()
    if not alive then return end

    local folder = WS:FindFirstChild("Balls")
    if not folder then return end

    -- cooldown global (anti-kick)
    if now - State.lastFireTime < Config.fireCooldown then return end

    local myPos = hrp.Position
    local myName = LP.Name

    -- kumpulin SEMUA bola approaching (nggak peduli target attribute)
    local balls = {}

    for _, ball in ipairs(folder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ball:FindFirstChild("ComboCounter") then continue end

        -- lock per-bola (cegah double fire di bola sama)
        local lf = State.ballLastFire[ball]
        if lf and (now - lf) < 0.15 then continue end

        local z = ball:FindFirstChild("zoomies")
        if not z then continue end
        local vel = z.VectorVelocity
        local speed = vel.Magnitude
        if speed < 3 then continue end

        local toPlayer = myPos - ball.Position
        local dist = toPlayer.Magnitude
        if dist > Config.maxDist then continue end

        -- bola mendekat player? dot > 0.5 = approach
        local approach = vel.Unit:Dot(toPlayer.Unit)
        if approach < 0.5 then continue end

        table.insert(balls, {
            ball = ball,
            z = z,
            dist = dist,
            speed = speed,
            approach = approach,
        })
    end

    if #balls == 0 then return end

    -- sort by jarak (terdekat duluan)
    table.sort(balls, function(a, b) return a.dist < b.dist end)

    -- fire semua (cap maxFirePerFrame)
    local fireN = math.min(#balls, Config.maxFirePerFrame)
    local best = balls[1].ball
    local cam = WS.CurrentCamera
    local aim
    if cam then
        local sp = cam:WorldToScreenPoint(best.Position + balls[1].z.VectorVelocity * 0.05)
        if sp then aim = {math.floor(sp.X), math.floor(sp.Y)} end
    end

    for i = 1, fireN do
        State.ballLastFire[balls[i].ball] = now
        fireParry(aim)
    end

    State.lastFireTime = now
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════
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
    end
    if input.KeyCode == Enum.KeyCode.E then
        Config.enabled = not Config.enabled
        print("[V10]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.End then
        Config.enabled = false
        print("[V10] PANIC")
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title       = "Slax V10 RAW",
    Icon        = "solar:crown-bold",
    Author      = "ALPHA XK",
    Folder      = "SlaxV10",
    Size        = UDim2.fromOffset(520, 420),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth= 150,
})

Window:EditOpenButton({
    Title        = "V10 RAW",
    Icon         = "solar:crown-bold",
    CornerRadius = UDim.new(0, 14),
    Color        = ColorSequence.new(
        Color3.fromRGB(255, 60, 60),
        Color3.fromRGB(255, 200, 80)
    ),
    OnlyMobile   = true,
})

local TabMain = Window:Tab({ Title = "Raw", Icon = "solar:sword-bold" })
local TabInfo = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

local SecA = TabMain:Section({ Title = "Auto Parry" })

SecA:Toggle({
    Title    = "Auto Parry RAW",
    Desc     = "Fire tiap bola approaching — zero filter",
    Value    = Config.enabled,
    Callback = function(v) Config.enabled = v end,
})

SecA:Slider({
    Title    = "Accuracy",
    Desc     = "1 = late | 100 = early (fire awal)",
    Value    = { Min = 1, Max = 100, Default = Config.accuracy, Rounding = 0 },
    Callback = function(v) Config.accuracy = v end,
})

SecA:Slider({
    Title    = "Max Distance",
    Desc     = "Radius deteksi bola (studs)",
    Value    = { Min = 50, Max = 400, Default = Config.maxDist, Rounding = 0 },
    Callback = function(v) Config.maxDist = v end,
})

local SecInfo = TabInfo:Section({ Title = "Status" })
local infoPara = SecInfo:Paragraph({ Title = "Runtime", Desc = "init..." })

task.spawn(function()
    while State.running do
        pcall(function()
            infoPara:Set(string.format(
                "Token: %s\nRemote: %s\nParry: %d",
                _token and "OK" or "FAIL",
                Captured.remote and Captured.remote.Name or "not captured",
                State.parryCount
            ))
        end)
        task.wait(1)
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V10 RAW",
    Content = "Zero filter — parry manual sekali",
    Duration = 5,
})

print("[V10] loaded")

_G.slax_unload = function()
    State.running = false
    getgenv()._slax_loaded = nil
end
