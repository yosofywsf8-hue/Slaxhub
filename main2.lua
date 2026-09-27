-- ═══════════════════════════════════════════════════════════════════════════
-- ███████╗██╗      █████╗ ██╗  ██╗    ██╗  ██╗██╗   ██╗██████╗ 
-- ██╔════╝██║     ██╔══██╗╚██╗██╔╝    ██║  ██║██║   ██║██╔══██╗
-- ███████╗██║     ███████║ ╚███╔╝     ███████║██║   ██║██████╔╝
-- ╚════██║██║     ██╔══██║ ██╔██╗     ██╔══██║██║   ██║██╔═══╝ 
-- ███████║███████╗██║  ██║██╔╝ ██╗    ██║  ██║╚██████╔╝██║     
-- ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═╝     
--
-- Slax Hub V7 ULTIMATE | Blade Ball Suite | FUSION BUILD
-- Base: Ailon + Ssinfonnyy | Concepts: EclipseNexus v210
-- Author: ALPHA XK | For: Redz
-- ═══════════════════════════════════════════════════════════════════════════

-- == Load Guard ============================================================
if getgenv()._slaxv7_loaded then
    pcall(function() if _G.slaxv7_unload then _G.slaxv7_unload() end end)
    getgenv()._slaxv7_loaded = nil
    task.wait(0.2)
end
getgenv()._slaxv7_loaded = true

-- == Services ==============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CP = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer

local function cloneref(s) return s end

-- == BAC BYPASS (Ailon 3-layer) ============================================
local hook = hookfunction or detour_function
local cclosure = newcclosure or function(f) return f end
local renv = getrenv and getrenv() or _G
local set_readonly = setreadonly or (make_writeable and function(t, v)
    if v then make_writeable(t) else make_readonly(t) end
end)

local function isRelevantCaller()
    for i = 3, 6 do
        local src = debug.info(i, "s")
        if src and (src:find("RemoveLoadingScreen") or src:find("Loading") or src:find("Detection")) then
            return true
        end
    end
    if getcallingscript then
        local ok, script = pcall(getcallingscript)
        if ok and script then
            local name = tostring(script)
            if name:find("RemoveLoadingScreen") or name:find("Loading") then
                return true
            end
        end
    end
    return false
end

if hook and cclosure then
    pcall(function()
        local origRandom
        origRandom = hook(renv.math.random, cclosure(function(...)
            if isRelevantCaller() then return 0 end
            return origRandom(...)
        end))

        local origPreload
        origPreload = hook(CP.PreloadAsync, cclosure(function(self, assets, callback)
            if self ~= CP then return origPreload(self, assets, callback) end
            if isRelevantCaller() and type(assets) == "table" then
                if callback then
                    for _, asset in ipairs(assets) do
                        task.spawn(pcall, callback, asset, Enum.AssetFetchStatus.Success)
                    end
                end
                return
            end
            return origPreload(self, assets, callback)
        end))
    end)

    local mt = getrawmetatable(game)
    if mt and set_readonly then
        local origNamecall = mt.__namecall
        set_readonly(mt, false)
        mt.__namecall = cclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if method == "PreloadAsync" and self == CP and isRelevantCaller() then
                pcall(function()
                    local assets, callback = args[1], args[2]
                    if type(assets) == "table" and callback then
                        for _, asset in ipairs(assets) do
                            task.spawn(pcall, callback, asset, Enum.AssetFetchStatus.Success)
                        end
                    end
                end)
                return
            end
            return origNamecall(self, ...)
        end)
        set_readonly(mt, true)
    end
end

-- == Config ================================================================
local Config = {
    enabled         = true,
    accuracy        = 100,
    threshold       = 1,
    spamRate        = 200,
    curveMethod     = "camera",
    animFix         = false,
    autoSpam        = false,
    autoSpamCPS     = 200,
    triggerBot      = false,
    lobbyAP         = false,
    lowRender       = false,
    fovEnabled      = false,
    fovValue        = 70,
    invisEnabled    = false,
    immortalEnabled = false,
    hitSoundEnabled = false,
    hitSoundId      = "rbxassetid://6607336718",
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
    velMap          = setmetatable({}, { __mode = "k" }),
    parryCDUntil    = 0,
    parriedMain     = false,
    lastTarget      = nil,
    currentCurve    = "camera",
    playerVel       = setmetatable({}, { __mode = "k" }),
}

-- == Zero-Capture System (concept from EclipseNexus) ======================
local ZC = {
    ready = false,
    remote = nil,
    hash = nil,
    key = nil,
    num = nil,
    tokenFn = nil,
    tried = 0,
    lastRescan = 0,
}

local zc_netFolder = nil
local function zc_resolve_net()
    if zc_netFolder and zc_netFolder.Parent then return zc_netFolder end
    local ok, f = pcall(function()
        return RS.Packages._Index["sleitnick_net@0.1.0"].net
    end)
    if ok then zc_netFolder = f end
    return zc_netFolder
end

local zc_hash, zc_key, zc_num, zc_tokenFn
local zc_pryFallback = nil

local function zc_process_obj(obj, netFolder, netLit)
    local tobj = type(obj)
    if tobj == "table" then
        for _, v in pairs(obj) do
            if typeof(v) == "Instance" and v:IsA("RemoteEvent") and netFolder then
                local okNet, isNet = pcall(v.IsDescendantOf, v, netFolder)
                if okNet and isNet then netLit[v] = true end
            end
        end
    elseif tobj == "function" then
        local okSrc, src = pcall(debug.info, obj, 's')
        if okSrc and src then
            local s = tostring(src)
            if s:find('SwordsController', 1, true) and s:find('PRY', 1, true) then
                local okUps, ups = pcall(debug.getupvalues, obj)
                if okUps and type(ups) == 'table' then
                    if not zc_pryFallback then
                        for _, value in ups do
                            if type(value) == 'function' then
                                zc_pryFallback = value
                                break
                            end
                        end
                    end
                    local withKey = ups[3]
                    if type(withKey) == 'table' and type(withKey[1]) == 'table' and type(ups[8]) == 'string' then
                        zc_hash = ups[8]
                        zc_key = withKey[2]
                        zc_num = withKey[1][withKey[3]]
                        zc_tokenFn = ups[4]
                    end
                end
            elseif not zc_pryFallback and s:find('PRY', 1, true) then
                local okUps, ups = pcall(debug.getupvalues, obj)
                if okUps and type(ups) == 'table' then
                    for _, value in ups do
                        if type(value) == 'function' then
                            zc_pryFallback = value
                            break
                        end
                    end
                end
            end
        end
    end
end

local function zc_finalize()
    if not (zc_hash and zc_key and zc_tokenFn) then return false end
    local netFolder = zc_resolve_net()
    if not netFolder then return false end
    for _, r in ipairs(netFolder:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            if r.Name:sub(1, 3) == "RE/"
                and #r.Name >= 32
                and select(2, r.Name:gsub("[/`:<;_=?>]", "")) >= 3 then
                ZC.remote = r
                ZC.ready = true
                return true
            end
        end
    end
    return false
end

local function zc_scan_sync()
    if ZC.ready then return end
    if not (getgc and debug and debug.getupvalues and debug.info) then return end
    pcall(function()
        local netFolder = zc_resolve_net()
        if not netFolder then return end
        local netLit = {}
        zc_hash, zc_key, zc_num, zc_tokenFn = nil, nil, nil, nil
        for _, obj in getgc(true) do
            zc_process_obj(obj, netFolder, netLit)
        end
        if zc_hash and zc_key and zc_tokenFn then
            ZC.hash = zc_hash
            ZC.key = zc_key
            ZC.num = zc_num
            ZC.tokenFn = zc_tokenFn
        end
        zc_finalize()
    end)
end

local zc_tokWindow, zc_tokNum, zc_tokKey = -1, nil, nil
local zc_tokCheck = 0
local zc_noPos, zc_noMouse = {}, {}

local function zc_tokenize(uid)
    if not ZC.tokenFn then return nil end
    local ok, token = pcall(function()
        local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
        local key = ZC.tokenFn(uid, 'TIME')
        local chars = table.create(#t)
        for i = 1, #t do
            chars[i] = string.char(bit32.bxor(
                (string.byte(t, i) + i) % 256,
                string.byte(key, (i - 1) % #key + 1)
            ))
        end
        return table.concat(chars)
    end)
    if ok and type(token) == 'string' then return token end
    return nil
end

function ZC.fire(curveCF, screenPositions, mouseLocation, isSpam, forceFreshToken)
    if not ZC.ready then return false end
    local remote = ZC.remote
    if not remote or not remote.Parent then
        ZC.ready = false
        task.spawn(function()
            if os.clock() - (ZC.lastRescan or 0) > 10 then
                ZC.lastRescan = os.clock()
                zc_scan_sync()
            end
        end)
        return false
    end
    if not curveCF then
        local cam = WS.CurrentCamera
        curveCF = cam and cam.CFrame
    end
    if not curveCF then return false end
    
    if forceFreshToken or (os.clock() - zc_tokCheck) >= 0.005 or not zc_tokNum then
        zc_tokCheck = os.clock()
        local now100 = math.floor(WS:GetServerTimeNow() * 100)
        if now100 ~= zc_tokWindow then
            zc_tokWindow = now100
            zc_tokNum = zc_tokenize(ZC.num)
            zc_tokKey = zc_tokNum or zc_tokenize(ZC.key)
        end
    end
    local token = zc_tokNum
    if not token then token = zc_tokKey end
    if not token then return false end
    
    local ok = pcall(remote.FireServer, remote,
        ZC.hash, ZC.key, token,
        isSpam and 0 or 0.5,
        curveCF,
        screenPositions or zc_noPos,
        mouseLocation or zc_noMouse,
        false
    )
    return ok
end

task.spawn(function()
    if not (getgc and debug and debug.getupvalues and debug.info) then return end
    local backoff = 1
    while not ZC.ready and ZC.tried < 8 do
        ZC.tried = ZC.tried + 1
        zc_scan_sync()
        local waited = 0
        while not ZC.ready and waited < backoff do
            waited = waited + 0.25
            task.wait(0.25)
        end
        if ZC.ready then break end
        backoff = math.min(backoff * 2, 30)
    end
end)

-- == Remote Capture (Ailon 3-remote smart) ================================
local HookSystem = {
    ParryRemotes = {},
    CaptureComplete = false,
    RemoteCount = 0,
}

local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if HookSystem.CaptureComplete then
        return oldIndex(self, key)
    end
    if key ~= "FireServer" and key ~= "InvokeServer" then
        return oldIndex(self, key)
    end
    if checkcaller() then
        return oldIndex(self, key)
    end
    local isRemote = false
    local ok, result = pcall(function()
        if key == "FireServer" then
            return self:IsA("RemoteEvent")
        else
            return self:IsA("RemoteFunction")
        end
    end)
    if ok then isRemote = result end
    if not isRemote then
        return oldIndex(self, key)
    end
    return function(_, ...)
        local args = { ... }
        if #args == 7 
        and type(args[2]) == "string" 
        and type(args[3]) == "number" then
            if not HookSystem.ParryRemotes[self] then
                HookSystem.RemoteCount = HookSystem.RemoteCount + 1
            end
            HookSystem.ParryRemotes[self] = args
            if HookSystem.RemoteCount >= 3 then
                HookSystem.CaptureComplete = true
            end
        end
        return oldIndex(self, key)(_, unpack(args))
    end
end))

-- == Character / Alive ====================================================
local Alive = WS:FindFirstChild("Alive") or WS:WaitForChild("Alive", 10)
local Runtime = WS:FindFirstChild("Runtime")

task.spawn(function()
    while State.running do
        if not Alive or not Alive.Parent then Alive = WS:FindFirstChild("Alive") end
        if not Runtime or not Runtime.Parent then Runtime = WS:FindFirstChild("Runtime") end
        task.wait(1)
    end
end)

-- == Ball Tracker =========================================================
local Tracker = { balls = {} }

local function trackerUpdate(ball, dt)
    local z = ball:FindFirstChild('zoomies')
    if not z then return nil end
    local pos, vel = ball.Position, z.VectorVelocity
    local rec = Tracker.balls[ball]
    if not rec then
        rec = { pos = pos, vel = vel, accel = Vector3.zero, lastUpdate = tick() }
        Tracker.balls[ball] = rec
        return rec
    end
    if dt > 0.001 then
        local dvel = vel - rec.vel
        rec.accel = rec.accel * 0.5 + (dvel / dt) * 0.5
    end
    rec.pos, rec.vel, rec.lastUpdate = pos, vel, tick()
    return rec
end

local function trackerCleanup()
    for b in pairs(Tracker.balls) do
        if not b.Parent then Tracker.balls[b] = nil end
    end
end

-- == Intercept Solver =====================================================
local function solveIntercept(bPos, bVel, myPos, radius)
    local dp = bPos - myPos
    local A = bVel:Dot(bVel)
    if A < 0.0001 then return nil end
    local B = 2 * dp:Dot(bVel)
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

-- == Curve Methods (Ssinfonnyy 7 methods) ================================
local CURVE_METHODS = {"camera","dot","backwards","slow","random","accelerated","high"}

local function getCurveCFrame()
    local camera = WS.CurrentCamera
    local char = LP.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root then return camera.CFrame end
    
    local closestDot = -math.huge
    local targetPos = nil
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity ~= char and entity:FindFirstChild("HumanoidRootPart") then
                local dir = (entity.HumanoidRootPart.Position - camera.CFrame.Position).Unit
                local dot = camera.CFrame.LookVector:Dot(dir)
                if dot > closestDot then
                    closestDot = dot
                    targetPos = entity.HumanoidRootPart.Position
                end
            end
        end
    end
    targetPos = targetPos or (root.Position + camera.CFrame.LookVector * 1000)
    local toTarget = (targetPos - root.Position).Unit
    local method = State.currentCurve
    
    if method == "dot" then
        return CFrame.lookAt(root.Position, targetPos + Vector3.new(0, 1.75, 0))
    elseif method == "backwards" then
        return CFrame.new(root.Position, root.Position + (-toTarget) * 1000)
    elseif method == "slow" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, -350, 0))
    elseif method == "random" then
        local direction = (targetPos - root.Position).Unit
        local randomOffset
        local attempts = 0
        repeat
            randomOffset = Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
            local curveDir = (targetPos + randomOffset - root.Position).Unit
            local dot = direction:Dot(curveDir)
            attempts = attempts + 1
        until dot < 0.95 or attempts > 10
        return CFrame.new(root.Position, targetPos + randomOffset)
    elseif method == "accelerated" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 5, 0))
    elseif method == "high" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 9e18, 0))
    else
        return camera.CFrame
    end
end

-- == Predicted Distance (mix engine) =====================================
local function getPredictedDistance(ball, myPos)
    local z = ball:FindFirstChild("zoomies")
    if not z then return (myPos - ball.Position).Magnitude end
    local vel = z.VectorVelocity
    
    local vh = State.velMap[ball]
    if not vh then
        vh = {}
        State.velMap[ball] = vh
    end
    local n = #vh
    if n >= 5 then
        local rec = vh[n]
        table.remove(vh, n)
        rec.pos = ball.Position
        rec.vel = vel
        rec.t = tick()
        table.insert(vh, 1, rec)
    else
        table.insert(vh, 1, { pos = ball.Position, vel = vel, t = tick() })
    end
    
    local accel = Vector3.zero
    if #vh >= 2 then
        local dt = vh[1].t - vh[#vh].t
        if dt > 0 then
            accel = (vh[1].vel - vh[#vh].vel) / dt
        end
    end
    
    local t = State.ping / 2
    local ballFuture = (vh[1].pos + vh[1].vel * t) + ((0.5 * accel) * t) * t
    
    if #vh >= 3 then
        local p0, p1, p2 = vh[3].pos, vh[2].pos, vh[1].pos
        local tb = 1 + t
        local omt = 1 - tb
        local bezier = ((omt * omt) * p0 + ((2 * omt) * tb) * p1) + (tb * tb) * p2
        ballFuture = ballFuture:Lerp(bezier, 0.5)
    end
    
    local myVel = Vector3.zero
    local char = LP.Character
    if char and char.PrimaryPart then
        myVel = char.PrimaryPart.AssemblyLinearVelocity
    end
    local playerFuture = myPos + myVel * t
    return (playerFuture - ballFuture).Magnitude
end

-- == Curve Detection (4-way fusion) ======================================
local _zxEchoState = setmetatable({}, { __mode = "k" })
local _zxVelHistory = setmetatable({}, { __mode = "k" })

local function _baseCurved(ball, myPos)
    if not ball then return false end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local velocity = z.VectorVelocity
    local speed = velocity.Magnitude
    if speed == 0 then return false end
    local ball_dir = velocity.Unit
    local dir = (myPos - ball.Position).Unit
    local dot = dir:Dot(ball_dir)
    local distance = (myPos - ball.Position).Magnitude
    local ping = State.ping
    local reach = distance / speed - ping
    
    local cs = State.curveState[ball]
    if not cs then
        cs = { lerp = 0, last_warping = tick(), curving = tick() }
        State.curveState[ball] = cs
    end
    
    if ball:FindFirstChild("AeroDynamicSlashVFX") then
        ball.AeroDynamicSlashVFX:Destroy()
        cs.curving = tick()
    end
    
    local _rt = WS:FindFirstChild("Runtime")
    if _rt and _rt:FindFirstChild("Tornado") then
        if (tick() - cs.curving) < ((_rt.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
            return true
        end
    end
    
    local adj_reach = reach + 0.03
    local band = 1.45
    if speed < 300 then band = 1.15
    elseif speed < 450 then band = 1.18
    elseif speed < 600 then band = 1.3 end
    
    if (tick() - cs.curving) < (adj_reach / band) then return true end
    
    local dot_threshold = -ping
    local clamped = math.clamp(dot, -1, 1)
    local rad = math.deg(math.asin(clamped))
    cs.lerp = cs.lerp + (rad - cs.lerp) * 0.8
    
    if speed < 300 then
        if cs.lerp < 0.015 then cs.last_warping = tick() end
    else
        if cs.lerp < 0.012 then cs.last_warping = tick() end
    end
    if (tick() - cs.last_warping) < (adj_reach / band) then return true end
    
    return dot < dot_threshold
end

local function _echoCurved(ball, myPos)
    local props = _zxEchoState[ball]
    if not props then
        props = { lerp = 0, last_warping = tick(), curving = tick() }
        _zxEchoState[ball] = props
    end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local velocity = z.VectorVelocity
    local speed = velocity.Magnitude
    if speed < 1 then return false end
    local dir = (myPos - ball.Position).Unit
    local dot = dir:Dot(velocity.Unit)
    local ping = State.ping
    local distance = (myPos - ball.Position).Magnitude
    local reach = distance / speed - ping
    local dot_thr = math.clamp(0.55 - ping * 0.75, -1, 0.45)
    local clamped = math.clamp(dot, -1, 1)
    
    props.lerp = props.lerp + (math.asin(clamped) - props.lerp) * 0.85
    if props.lerp < 0.016 then props.last_warping = tick() end
    
    local dist_thr = 15 - math.min(distance / 1000, 15) + math.min(speed / 100, 45)
    if distance < dist_thr * 0.85 then return false end
    if (tick() - props.last_warping) < (reach / 1.4) then return true end
    if (tick() - props.curving) < (reach / 1.1) then return true end
    return dot < dot_thr
end

local function _lateralCurved(ball, myPos)
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local velocity = z.VectorVelocity
    local speed = velocity.Magnitude
    if speed <= 1 then return false end
    local delta = myPos - ball.Position
    local dist = delta.Magnitude
    if dist <= 0.1 then return false end
    local toMe = delta / dist
    local invDot = (velocity / speed):Dot(toMe)
    local lat = (velocity - (velocity:Dot(toMe) * toMe)).Magnitude
    if (lat / speed > 0.16) or (invDot < 0.82 and invDot > -0.75) or (math.abs(velocity.Y / speed) > 0.25) then
        return true
    end
    return false
end

local function _pathTurnCurved(ball)
    local hist = _zxVelHistory[ball]
    if not hist then
        hist = { head = 0, n = 0, q = {} }
        _zxVelHistory[ball] = hist
    end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    hist.head = (hist.head % 4) + 1
    hist.q[hist.head] = z.VectorVelocity
    if hist.n < 4 then hist.n = hist.n + 1 end
    if hist.n < 4 then return false end
    local h = hist.head
    local p1 = hist.q[((h - 4) % 4) + 1]
    local p2 = hist.q[((h - 3) % 4) + 1]
    local p3 = hist.q[((h - 2) % 4) + 1]
    local p4 = hist.q[((h - 1) % 4) + 1]
    if not (p1 and p2 and p3 and p4) then return false end
    if p1.Magnitude <= 0 or p2.Magnitude <= 0 or p3.Magnitude <= 0 or p4.Magnitude <= 0 then return false end
    local a1 = math.deg(math.acos(math.clamp(p1.Unit:Dot(p2.Unit), -1, 1)))
    local a2 = math.deg(math.acos(math.clamp(p2.Unit:Dot(p3.Unit), -1, 1)))
    local a3 = math.deg(math.acos(math.clamp(p3.Unit:Dot(p4.Unit), -1, 1)))
    local total = a1 + a2 + a3
    local maxA = math.max(a1, a2, a3)
    return total >= 6 and maxA < 45
end

local function isCurved(ball, myPos)
    if _baseCurved(ball, myPos) then return true end
    if _echoCurved(ball, myPos) then return true end
    if _lateralCurved(ball, myPos) and _pathTurnCurved(ball) then return true end
    return false
end

-- == Ping Cache ============================================================
local pingSamples = {}
task.spawn(function()
    while State.running do
        pcall(function()
            local raw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            State.ping = raw / 1000
            if type(raw) == "number" and raw > 0 then
                table.insert(pingSamples, raw)
                if #pingSamples > 8 then table.remove(pingSamples, 1) end
                local sorted = table.clone(pingSamples)
                table.sort(sorted)
                local median = sorted[math.ceil(#sorted / 2)]
                local fed = raw
                if raw > median * 2.5 + 30 then
                    fed = median + (raw - median) * 0.15
                end
                State.pingSmooth = (State.pingSmooth * 0.6 + fed * 0.4) or fed
            end
        end)
        task.wait(0.25)
    end
end)

-- == Fire Window ==========================================================
local function computeWindow(speed)
    local pingAvg = State.pingSmooth or State.ping * 1000
    local pingThr = math.clamp((pingAvg / 10) / 8, 4, 25)
    local divBase = 2.2 + 0.9 * math.log(1 + speed / 80)
    local mult = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035353535353535
    local divisor = divBase * mult
    local sf = 1
    if speed > 200 then sf = 1 + math.min((speed - 200) / 1000, 0.3) end
    local speedTerm = math.max(speed / divisor, 9.5) * sf
    local cappedDiff = math.min(math.max(speed - 9.5, 0), 650)
    local linearTerm = math.max(speed / ((2.4 + cappedDiff * 0.002) * mult), 9.5)
    if linearTerm < speedTerm then speedTerm = linearTerm end
    return pingThr + speedTerm
end

-- == Fire Parry ===========================================================
local cachedEvents = {}
local cachedAim = {0, 0}
RunService.RenderStepped:Connect(function()
    local cam = WS.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local ok, mouse = pcall(UIS.GetMouseLocation, UIS)
    cachedAim = ok and {mouse.X, mouse.Y} or {vp.X / 2, vp.Y / 2}
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        cachedAim = {vp.X / 2, vp.Y / 2}
    end
    if Alive then
        local data = {}
        for _, entity in pairs(Alive:GetChildren()) do
            local pp = entity.PrimaryPart
            if pp then
                local ok2, sp = pcall(cam.WorldToScreenPoint, cam, pp.Position)
                if ok2 then data[entity.Name] = sp end
            end
        end
        cachedEvents = data
    end
end)

local function fireParry(aim)
    aim = aim or cachedAim
    local curveCF = getCurveCFrame()
    
    -- Zero-capture first
    if ZC.ready then
        if ZC.fire(curveCF, cachedEvents, aim, false, true) then
            State.parryCount = State.parryCount + 1
            return true
        end
    end
    
    -- Fallback: captured remotes
    if next(HookSystem.ParryRemotes) then
        for remote, originalArgs in pairs(HookSystem.ParryRemotes) do
            local modifiedArgs = {
                originalArgs[1],
                originalArgs[2],
                0,
                curveCF,
                cachedEvents,
                aim,
                originalArgs[7] or false
            }
            pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(unpack(modifiedArgs))
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(unpack(modifiedArgs))
                end
            end)
        end
        State.parryCount = State.parryCount + 1
        return true
    end
    
    return false
end

-- == Main Parry Loop ======================================================
local lastFrame = tick()
local ballList = {}

RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    local now = tick()
    local dt = now - lastFrame
    lastFrame = now
    
    -- Cooldown latch (EclipseNexus style)
    if State.parriedMain then
        if now >= State.parryCDUntil then
            State.parriedMain = false
        else
            return
        end
    end
    
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if hrp:FindFirstChild("SingularityCape") then return end
    
    trackerCleanup()
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    
    -- تحديث tracker
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("realBall") then
            trackerUpdate(ball, dt)
        end
    end
    
    -- جمع candidates
    local myPos = hrp.Position
    local myName = LP.Name
    local best, bestScore, bestT = nil, math.huge, 0
    local bestSpeed = 0
    
    for _, ball in ipairs(folder:GetChildren()) do
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
        
        local dist = getPredictedDistance(ball, myPos)
        local curved = isCurved(ball, myPos)
        local window = computeWindow(speed)
        
        if curved then
            local band = (speed < 300 and 1.15) or (speed < 450 and 1.18) or (speed < 600 and 1.3) or 1.45
            window = window / band
        end
        
        if dist <= window then
            local score = dist - speed * 0.05
            if score < bestScore then
                best, bestScore, bestT = ball, score, dist
                bestSpeed = speed
            end
        end
    end
    
    if best then
        local cam = WS.CurrentCamera
        local aim
        if cam then
            local z = best:FindFirstChild("zoomies")
            if z then
                local rec = Tracker.balls[best]
                local predPos = best.Position + z.VectorVelocity * math.max(bestT, 0)
                if rec then predPos = predPos + rec.accel * (0.5 * bestT * bestT) end
                local sp = cam:WorldToScreenPoint(predPos)
                if sp then aim = {math.floor(sp.X), math.floor(sp.Y)} end
            end
        end
        
        if fireParry(aim) then
            State.parried[best] = true
            State.parriedMain = true
            State.lastParry = now
            State.parryCDUntil = now + math.clamp(4.9 - bestSpeed * 0.01, 0.7, 0.85)
            if State.ping > 0.2 then
                State.parryCDUntil = now + math.max(State.parryCDUntil - now, State.ping + 0.35)
            end
            task.delay(0.4, function()
                if State.parried[best] then State.parried[best] = nil end
            end)
        end
    end
end)

-- == Auto Spam ============================================================
local autoSpamConn = nil
local lastAutoSpam = 0

local function startAutoSpam()
    if autoSpamConn then autoSpamConn:Disconnect() end
    autoSpamConn = RunService.PreSimulation:Connect(function()
        if not Config.autoSpam then return end
        local char = LP.Character
        if not char or not char.PrimaryPart then return end
        if char.Parent ~= Alive then return end
        
        local folder = WS:FindFirstChild("Balls")
        if not folder then return end
        
        local now = tick()
        local interval = 1 / Config.autoSpamCPS
        if now - lastAutoSpam < interval then return end
        lastAutoSpam = now
        
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:GetAttribute("target") == LP.Name then
                fireParry()
                return
            end
        end
    end)
end

-- == Trigger Bot ==========================================================
local triggerState = { is_parrying = false, parries = 0, max = 10000, delay = 0.5 }
local triggerConn = nil

local function triggerBotLoop()
    if not Config.triggerBot then return end
    local char = LP.Character
    if not char or not char.PrimaryPart then return end
    if char.PrimaryPart:FindFirstChild("SingularityCape") then return end
    if triggerState.is_parrying then return end
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("target") == LP.Name then
            triggerState.is_parrying = true
            fireParry()
            task.delay(triggerState.delay, function()
                triggerState.is_parrying = false
            end)
            break
        end
    end
end

local function startTriggerBot()
    if triggerConn then triggerConn:Disconnect() end
    triggerConn = RunService.Heartbeat:Connect(triggerBotLoop)
end

-- == Lobby Auto Parry =====================================================
local lobbyConn = nil
local lobbyParried = false
local lastLobbyTarget = nil

local function getLobbyBall()
    local tb = WS:FindFirstChild("TrainingBalls")
    if not tb then return nil end
    for _, v in pairs(tb:GetChildren()) do
        if v:GetAttribute("realBall") then return v end
    end
    return nil
end

local function startLobbyAP()
    if lobbyConn then lobbyConn:Disconnect() end
    lobbyParried = false
    lastLobbyTarget = nil
    local counter = 0
    lobbyConn = RunService.Heartbeat:Connect(function()
        counter = counter + 1
        if counter % 2 ~= 0 then return end
        if not Config.lobbyAP then return end
        
        local ball = getLobbyBall()
        if not ball then
            lobbyParried = false
            lastLobbyTarget = nil
            return
        end
        
        local zoomies = ball:FindFirstChild("zoomies")
        if not zoomies then return end
        
        local ballTarget = ball:GetAttribute("target")
        if ballTarget ~= lastLobbyTarget then
            lobbyParried = false
            lastLobbyTarget = ballTarget
        end
        if lobbyParried then return end
        
        local velocity = zoomies.VectorVelocity
        local distance = LP:DistanceFromCharacter(ball.Position)
        local speed = velocity.Magnitude
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
        local capped = math.min(math.max(speed - 9.5, 0), 650)
        local sdb = 2.4 + capped * 0.002
        local parryAcc = ping + math.max(speed / sdb, 9.5)
        
        if ballTarget == tostring(LP) and distance <= parryAcc then
            fireParry()
            lobbyParried = true
            task.spawn(function()
                local t = tick()
                repeat RunService.PreSimulation:Wait()
                until (tick() - t) >= 1 or not lobbyParried
                lobbyParried = false
            end)
        end
    end)
end

-- == Low Render ===========================================================
local originalQuality = nil
local function setLowRender(enabled)
    if enabled then
        pcall(function()
            originalQuality = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end)
    else
        pcall(function()
            if originalQuality then
                settings().Rendering.QualityLevel = originalQuality
            end
        end)
        pcall(function()
            Lighting.GlobalShadows = true
        end)
    end
end

-- == FOV Changer ==========================================================
local fovLoop = nil
local function startFOVLoop()
    if fovLoop then return end
    fovLoop = RunService.RenderStepped:Connect(function()
        if Config.fovEnabled then
            WS.CurrentCamera.FieldOfView = Config.fovValue
        end
    end)
end

-- == Invisibility (Semi Immortal) =========================================
local InvisState = {
    enabled = false,
    radius = 25,
    riseHeight = 30,
    cycleSpeed = 11.9,
    desync = { cframe = nil, velocity = nil },
    cache = { char = nil, hrp = nil, head = nil, headOffset = Vector3.new(0, 0, 0) },
    conn = nil,
}

local function updateInvisCache()
    local char = LP.Character
    if char ~= InvisState.cache.char then
        InvisState.cache.char = char
        if char then
            InvisState.cache.hrp = char:FindFirstChild("HumanoidRootPart")
            InvisState.cache.head = char:FindFirstChild("Head")
            if InvisState.cache.hrp then
                InvisState.cache.headOffset = Vector3.new(0, InvisState.cache.hrp.Size.Y * 0.5 + 0.5, 0)
            end
        else
            InvisState.cache.hrp = nil
            InvisState.cache.head = nil
        end
    end
end

local function performInvis()
    updateInvisCache()
    if not InvisState.enabled or not InvisState.cache.hrp then return end
    local char = InvisState.cache.char
    local aliveFolder = WS:FindFirstChild("Alive")
    if not char or char.Parent ~= aliveFolder then return end
    
    local hrp = InvisState.cache.hrp
    InvisState.desync.cframe = hrp.CFrame
    InvisState.desync.velocity = hrp.AssemblyLinearVelocity
    
    local angle = math.random(-2147483647, 2147483647) * 1000
    local cycle = math.floor(tick() * InvisState.cycleSpeed) % 2
    local yOff = cycle == 0 and 0 or InvisState.riseHeight
    local pos = hrp.Position
    local yBase = pos.Y - hrp.Size.Y * 0.5 + 5 + yOff
    hrp.CFrame = CFrame.new(
        pos.X + math.cos(angle) * InvisState.radius,
        yBase,
        pos.Z + math.sin(angle) * InvisState.radius
    )
    hrp.AssemblyLinearVelocity = Vector3.new(1, 1, 1)
    
    RunService.RenderStepped:Wait()
    
    hrp.CFrame = InvisState.desync.cframe
    hrp.AssemblyLinearVelocity = InvisState.desync.velocity
end

_G.BB_CFrameHandlers = _G.BB_CFrameHandlers or {}
_G.BB_RegisterCFrameHandler = function(fn)
    table.insert(_G.BB_CFrameHandlers, fn)
end

local sharedOldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if key ~= "CFrame" then return sharedOldIndex(self, key) end
    if checkcaller() then return sharedOldIndex(self, key) end
    for _, h in ipairs(_G.BB_CFrameHandlers) do
        local r = h(self)
        if r ~= nil then return r end
    end
    return sharedOldIndex(self, key)
end))

_G.BB_RegisterCFrameHandler(function(self)
    if not InvisState.enabled then return nil end
    if self == InvisState.cache.hrp then
        return InvisState.desync.cframe or CFrame.new()
    elseif self == InvisState.cache.head and InvisState.desync.cframe then
        return InvisState.desync.cframe + InvisState.cache.headOffset
    end
    return nil
end)

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

-- == Immortality ==========================================================
local Imm = {
    enabled = false,
    rotation = false,
    radius = 40,
    height = 100,
    desyncForce = 3000,
    desync = {},
    rotation_deg = 0,
}

local function GenerateRandomVector(magnitude)
    return math.random(-magnitude * 90000009292929399949949496000, magnitude * -1e9) / 5e8
end

RunService.Stepped:Connect(function()
    if Imm.enabled and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            LP.Character.HumanoidRootPart:SetNetworkOwner(LP)
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not Imm.enabled then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    Imm.rotation_deg = Imm.rotation and (Imm.rotation_deg + 15) % 360 or 0
    Imm.desync[1] = hrp.CFrame
    Imm.desync[2] = hrp.AssemblyLinearVelocity
    
    local spoofed = hrp.CFrame * CFrame.Angles(0, math.rad(Imm.rotation_deg), 0) + Vector3.new(0, Imm.height, 0)
    local hWave = math.sin(tick() * 30) * Imm.radius
    local vWave = math.cos(tick() * 60) * Imm.height
    spoofed = spoofed * CFrame.new(hWave, vWave, 0) * CFrame.Angles(
        math.rad(GenerateRandomVector(Imm.desyncForce)),
        math.rad(GenerateRandomVector(Imm.desyncForce)),
        0
    )
    
    hrp.CFrame = spoofed
    hrp.AssemblyLinearVelocity = Imm.desync[2] + Vector3.new(
        math.cos(tick() * 8) * Imm.desyncForce,
        math.cos(tick() * 8) * Imm.desyncForce,
        0
    )
    
    RunService.RenderStepped:Wait()
    
    hrp.CFrame = Imm.desync[1]
    hrp.AssemblyLinearVelocity = Imm.desync[2]
end)

_G.BB_RegisterCFrameHandler(function(self)
    if not Imm.enabled then return nil end
    local char = LP.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    if self == hrp then
        return Imm.desync[1] or CFrame.new()
    elseif self == char:FindFirstChild("Head") and Imm.desync[1] then
        return Imm.desync[1] + Vector3.new(0, hrp.Size.Y / 2 + 0.5, 0)
    end
    return nil
end)

-- == Hit Sounds ===========================================================
local hitSoundFolder = Instance.new("Folder")
hitSoundFolder.Name = "SlaxV7_HitSound"
hitSoundFolder.Parent = WS
local hitSound = Instance.new("Sound", hitSoundFolder)
hitSound.Volume = 6

local HIT_SOUNDS = {
    Medal = "rbxassetid://6607336718",
    Fatality = "rbxassetid://6607113255",
    Skeet = "rbxassetid://6607204501",
    Switches = "rbxassetid://6607173363",
    Bubble = "rbxassetid://6534947588",
    Laser = "rbxassetid://7837461331",
    Steve = "rbxassetid://4965083997",
    Bat = "rbxassetid://3333907347",
    Saber = "rbxassetid://8415678813",
    Bameware = "rbxassetid://3124331820",
}

pcall(function()
    RS.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if Config.hitSoundEnabled then
            hitSound:Play()
        end
    end)
end)

-- == Keybinds =============================================================
local curveKeyMap = {
    [Enum.KeyCode.One] = "camera",
    [Enum.KeyCode.Two] = "dot",
    [Enum.KeyCode.Three] = "backwards",
    [Enum.KeyCode.Four] = "slow",
    [Enum.KeyCode.Five] = "camera",
    [Enum.KeyCode.Six] = "random",
    [Enum.KeyCode.Seven] = "accelerated",
    [Enum.KeyCode.Eight] = "high",
}

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeyMap[input.KeyCode] then
        State.currentCurve = curveKeyMap[input.KeyCode]
    end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[V7]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        Config.autoSpam = false
        Config.triggerBot = false
        Config.lobbyAP = false
        toggleInvis(false)
        Imm.enabled = false
        print("[V7] PANIC")
    end
end)

-- == UI ===================================================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "Slax V7 ULTIMATE",
    Icon = "lucide-crown",
    Author = "ALPHA XK",
    Folder = "SlaxV7",
    Size = UDim2.fromOffset(340, 480),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 0,
})

Window:EditOpenButton({
    Title = "V7",
    Icon = "lucide-crown",
    CornerRadius = UDim.new(0, 12),
    StrokeColor = Color3.fromRGB(255, 200, 80),
})

local TabCombat = Window:Tab({ Title = "Combat", Icon = "lucide-sword" })
local TabCurve = Window:Tab({ Title = "Curve", Icon = "lucide-activity" })
local TabExtra = Window:Tab({ Title = "Extra", Icon = "lucide-zap" })
local TabVisual = Window:Tab({ Title = "Visual", Icon = "lucide-eye" })

TabCombat:Toggle({
    Title = "Auto Parry",
    Value = Config.enabled,
    Callback = function(v) Config.enabled = v end,
})

TabCombat:Slider({
    Title = "Accuracy 1-100",
    Value = { Min = 1, Max = 100, Default = Config.accuracy, Step = 1 },
    Callback = function(v) Config.accuracy = v end,
})

TabCombat:Toggle({
    Title = "Auto Spam",
    Value = Config.autoSpam,
    Callback = function(v)
        Config.autoSpam = v
        if v then startAutoSpam() end
    end,
})

TabCombat:Slider({
    Title = "Spam CPS",
    Value = { Min = 50, Max = 1000, Default = Config.autoSpamCPS, Step = 50 },
    Callback = function(v) Config.autoSpamCPS = v end,
})

TabCombat:Toggle({
    Title = "Trigger Bot",
    Value = Config.triggerBot,
    Callback = function(v)
        Config.triggerBot = v
        if v then startTriggerBot() end
    end,
})

TabCombat:Toggle({
    Title = "Lobby Auto Parry",
    Value = Config.lobbyAP,
    Callback = function(v)
        Config.lobbyAP = v
        if v then startLobbyAP() end
    end,
})

TabCurve:Dropdown({
    Title = "Curve Method",
    Values = CURVE_METHODS,
    Value = Config.curveMethod,
    Callback = function(v)
        Config.curveMethod = v
        State.currentCurve = v
    end,
})

TabCurve:Paragraph({
    Title = "Curve Hotkeys",
    Desc = "1=camera, 2=dot, 3=backwards, 4=slow, 6=random, 7=accelerated, 8=high",
})

TabExtra:Toggle({
    Title = "Invisibility",
    Value = Config.invisEnabled,
    Callback = function(v)
        Config.invisEnabled = v
        toggleInvis(v)
    end,
})

TabExtra:Toggle({
    Title = "Immortality",
    Value = Config.immortalEnabled,
    Callback = function(v)
        Config.immortalEnabled = v
        Imm.enabled = v
    end,
})

TabExtra:Slider({
    Title = "Immortal Radius",
    Value = { Min = 10, Max = 100, Default = 40, Step = 5 },
    Callback = function(v) Imm.radius = v end,
})

TabExtra:Slider({
    Title = "Immortal Height",
    Value = { Min = 20, Max = 300, Default = 100, Step = 10 },
    Callback = function(v) Imm.height = v end,
})

TabExtra:Toggle({
    Title = "Hit Sound",
    Value = Config.hitSoundEnabled,
    Callback = function(v) Config.hitSoundEnabled = v end,
})

TabExtra:Dropdown({
    Title = "Hit Sound Type",
    Values = {"Medal", "Fatality", "Skeet", "Switches", "Bubble", "Laser", "Steve", "Bat", "Saber", "Bameware"},
    Value = "Medal",
    Callback = function(v)
        if HIT_SOUNDS[v] then hitSound.SoundId = HIT_SOUNDS[v] end
    end,
})

TabVisual:Toggle({
    Title = "Low Render Mode",
    Value = Config.lowRender,
    Callback = function(v)
        Config.lowRender = v
        setLowRender(v)
    end,
})

TabVisual:Toggle({
    Title = "FOV Changer",
    Value = Config.fovEnabled,
    Callback = function(v)
        Config.fovEnabled = v
        if v then startFOVLoop() end
    end,
})

TabVisual:Slider({
    Title = "FOV Value",
    Value = { Min = 50, Max = 120, Default = 70, Step = 5 },
    Callback = function(v) Config.fovValue = v end,
})

-- == Init ==================================================================
task.spawn(function()
    while not HookSystem.CaptureComplete and State.tried < 30 do
        task.wait(1)
        State.tried = State.tried + 1
    end
    if HookSystem.CaptureComplete then
        print("[V7] Remote captured successfully")
    end
end)

print("[V7] Slax Hub V7 ULTIMATE loaded")
print("[V7] Toggle: " .. Config.toggleKey .. " | Panic: " .. Config.panicKey)
print("[V7] Curve Hotkeys: 1-8")
print("[V7] Parry manually once if remote not captured")

-- == Unload ================================================================
_G.slaxv7_unload = function()
    State.running = false
    if autoSpamConn then autoSpamConn:Disconnect() end
    if triggerConn then triggerConn:Disconnect() end
    if lobbyConn then lobbyConn:Disconnect() end
    if InvisState.conn then InvisState.conn:Disconnect() end
    if fovLoop then fovLoop:Disconnect() end
    getgenv()._slaxv7_loaded = nil
end
