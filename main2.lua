-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V12 — Auto Parry (Zythera-Inspired)
-- Author: ALPHA XK | Learn-from: Zythera-X
-- Hookmetamethod + Parry Animation + Curve Detection + Spam Service
-- ═══════════════════════════════════════════════════════════════════════════

if getgenv()._v12_loaded then
    pcall(function() if _G.v12_unload then _G.v12_unload() end end)
    getgenv()._v12_loaded = nil
    task.wait(0.15)
end
getgenv()._v12_loaded = true

-- ═══ SERVICES ═══════════════════════════════════════════════════
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local LP         = Players.LocalPlayer
local UIS        = game:GetService("UserInputService")
local Stats      = game:GetService("Stats")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local CoreGui    = game:GetService("CoreGui")
local Debris     = game:GetService("Debris")
local Tween      = game:GetService("TweenService")

-- ═══ STATE ══════════════════════════════════════════════════════
local AutoParry         = false
local AutoSpam          = false
local TriggerBot        = false
local AnimFix           = true
local InfinityDetect    = true
local DeathSlashDetect  = true
local TimeHoleDetect    = true
local ParryType         = "Camera"
local SpamThreshold     = 2.5
local CurrentCurve      = "camera"

local L5                = {}    -- [remote] = captured_args
local Q5                = nil   -- original __index
local capturedCount     = 0
local parried_ids       = {}
local lastSpamTime      = 0
local lastParryAnim     = 0
local V5_count          = 0     -- spam throttle counter
local A                 = 0.0   -- parry cooldown
local m                 = 0     -- last parry time
local y                 = false
local M                 = 1

local infinity_active   = false
local deathslash_active = false
local timehole_active   = false

local cachedBall        = nil
local cachedHrp         = nil
local lastCache         = 0
local lastHrpCache      = 0

local parryAnimTrack    = nil
local curlAnimCache     = {}

-- ═══ BALL / TARGET HELPERS ══════════════════════════════════════
local function Get_Ball()
    local bc = WS:FindFirstChild("Balls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:GetAttribute("realBall") then return b end
        end
    end
    return nil
end

local function Get_Balls()
    local out = {}
    local bc = WS:FindFirstChild("Balls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:GetAttribute("realBall") then table.insert(out, b) end
        end
    end
    return out
end

local function Closest_Player()
    local nearest, closest = math.huge, nil
    local alive = WS:FindFirstChild("Alive")
    if not alive then return nil end
    for _, c in pairs(alive:GetChildren()) do
        if c ~= LP.Character and c:FindFirstChild("HumanoidRootPart") then
            local d = (LP.Character.HumanoidRootPart.Position - c.HumanoidRootPart.Position).Magnitude
            if d < nearest then nearest, closest = d, c end
        end
    end
    return closest
end

-- ═══ TOKEN — scan getgc + getupvalues ═══════════════════════════
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

print("[V12] token:", _token and "OK" or "FAIL")

-- ═══ PARRY ANIMATION (Zythera-style) ════════════════════════════
local function Play_Parry_Animation()
    if not AnimFix then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.Animator then return end

    local swordName = char:GetAttribute("CurrentlyEquippedSword")
    local anim = nil

    -- default grab parry
    local default = RS:FindFirstChild("Shared")
        and RS.Shared:FindFirstChild("SwordAPI")
        and RS.Shared.SwordAPI:FindFirstChild("Collection")
        and RS.Shared.SwordAPI.Collection:FindFirstChild("Default")
        and RS.Shared.SwordAPI.Collection.Default:FindFirstChild("GrabParry")

    if swordName then
        local ok, swordData = pcall(function()
            return RS.Shared.ReplicatedInstances.Swords.GetSword:Invoke(swordName)
        end)
        if ok and type(swordData) == "table" and swordData.AnimationType then
            for _, obj in pairs(RS.Shared.SwordAPI.Collection:GetChildren()) do
                if obj.Name == swordData.AnimationType then
                    local a = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
                    if a then anim = a end
                end
            end
        end
    end
    anim = anim or default
    if not anim then return end

    -- stop existing
    for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            pcall(function() track:Stop(0.1) end)
        end
    end

    local track = hum.Animator:LoadAnimation(anim)
    pcall(function() track:Play(0, 1, 1) end)
    parryAnimTrack = track
end

pcall(function()
    RS.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if parryAnimTrack then pcall(function() parryAnimTrack:Stop() end) end
    end)
end)

-- ═══ PING (Zythera-style — baca dari PerformanceStats) ══════════
local function Get_Ping()
    local ok, res = pcall(function()
        local rg = CoreGui:FindFirstChild("RobloxGui")
        if rg then
            local perf = rg:FindFirstChild("PerformanceStats")
            if perf then
                for _, d in perf:GetDescendants() do
                    if d:IsA("TextLabel") then
                        local ms = d.Text:match("(%d+)%s*ms")
                        if ms then return tonumber(ms) or 50 end
                    end
                end
            end
        end
        return 50
    end)
    return ok and res or 50
end

-- ═══ CURVE DETECTION (Zythera-style — track 4 velocity) ═════════
local vel_history = {}
local last_curve_check = tick()
local smooth_angle = 0

local function Is_Curved(ball)
    if not ball then return false end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end

    local ping = Get_Ping()
    local vel = z.VectorVelocity
    local dir = vel.Unit
    local myPos = LP.Character and LP.Character.PrimaryPart and LP.Character.PrimaryPart.Position
    if not myPos then return false end

    local toPlayer = (myPos - ball.Position).Unit
    local dot = toPlayer:Dot(dir)

    table.insert(vel_history, vel)
    if #vel_history > 4 then table.remove(vel_history, 1) end

    local speed = vel.Magnitude
    if speed > 160 then
        local distance = (myPos - ball.Position).Magnitude
        local eta = distance / speed - ping / 1000
        if eta > ping / 10 + 0.03 then
            -- approaching fast, fire earlier
            return true
        end
    end

    if #vel_history == 4 then
        for i = 1, 2 do
            local d = (dir - vel_history[i].Unit).Unit
            local proj = toPlayer:Dot(d)
            if dot - proj < -ping / 1000 then return true end
        end
    end

    return false
end

-- ═══ HOOK — hookmetamethod(game, "__index") — ZYTHERA STYLE ═════
local function is_valid_args(args)
    return #args == 7
        and type(args[2]) == "string"
        and type(args[3]) == "number"
        and typeof(args[4]) == "CFrame"
        and type(args[5]) == "table"
        and type(args[6]) == "table"
        and type(args[7]) == "boolean"
end

if typeof(hookmetamethod) == "function" then
    Q5 = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if (key == "FireServer" and self:IsA("RemoteEvent"))
        or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return function(_, ...)
                local args = { ... }
                if is_valid_args(args) then
                    if not L5[self] then
                        L5[self] = args
                        capturedCount = capturedCount + 1
                        print("[V12] captured:", self.Name or "?", "count=" .. capturedCount)
                    end
                end
                return Q5(self, key)(_, ...)
            end
        end
        return Q5(self, key)
    end))
    print("[V12] hookmetamethod installed")
else
    warn("[V12] hookmetamethod not available")
end

-- ═══ PARRY DATA (Zythera-style — build curve payload) ═══════════
local function build_parry_data()
    local cam = WS.CurrentCamera
    local vp = cam.ViewportSize
    local aim = {vp.X / 2, vp.Y / 2}

    local events = {}
    local alive = WS:FindFirstChild("Alive")
    if alive then
        for _, e in pairs(alive:GetChildren()) do
            if e ~= LP.Character and e.PrimaryPart then
                local sp, vis = cam:WorldToScreenPoint(e.PrimaryPart.Position)
                if vis then events[tostring(e)] = sp end
            end
        end
    end

    local cframe
    local m = CurrentCurve
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    if m == "camera" then
        cframe = cam.CFrame
    elseif m == "straight" or m == "dot" then
        local target = Closest_Player()
        if target and target.PrimaryPart then
            cframe = CFrame.new(root.Position, target.PrimaryPart.Position)
        else
            cframe = cam.CFrame
        end
    elseif m == "backwards" then
        cframe = CFrame.new(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.LookVector * 10000)
    elseif m == "high" then
        cframe = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + Vector3.new(0, 10000, 0))
    elseif m == "slowball" then
        cframe = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + Vector3.new(0, -10000, 0))
    elseif m == "random" then
        cframe = CFrame.new(cam.CFrame.Position, Vector3.new(
            math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000)))
    elseif m == "left" then
        cframe = CFrame.new(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.RightVector * 10000)
    elseif m == "right" then
        cframe = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.RightVector * 10000)
    else
        cframe = cam.CFrame
    end

    return { cframe = cframe, events = events, aim = aim }
end

-- ═══ FIRE PARRY — inject token + curve ke captured args ═════════
local function Fire_Parry()
    if tick() - m < A then return false end
    m = tick()

    local count = M or 1
    local fired = false

    for remote, origArgs in pairs(L5) do
        fired = true
        for _ = 1, count do
            local data = build_parry_data()
            if not data then break end

            -- build packet: original + regen token + new curve
            local uid = origArgs[2]
            local tok = _tokenize(uid) or origArgs[3]

            local pkt = {
                origArgs[1],
                uid,
                tok,
                data.cframe,
                data.events,
                data.aim,
                origArgs[7] or false,
            }

            local ok = pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(unpack(pkt))
                else
                    remote:InvokeServer(unpack(pkt))
                end
            end)
            if ok then fired = true end
        end
    end

    -- fallback: kirim F key
    if not fired then
        local vim = game:GetService("VirtualInputManager")
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
            vim:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
        end)
    end

    Play_Parry_Animation()
    return fired
end

-- ═══ SPAM SERVICE — Zythera formula ═════════════════════════════
local function Spam_Service(ball, ping)
    if not ball then return 5 end
    local closest = Closest_Player()
    if not closest or not closest.PrimaryPart then return 5 end

    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local dist_ball = (LP.Character.PrimaryPart.Position - ball.Position).Magnitude
    local dist_ent = LP:DistanceFromCharacter(closest.PrimaryPart.Position)

    -- close contact detection
    _G.In_Close_Contact = _G.In_Close_Contact or false
    _G.Last_Close_Contact = _G.Last_Close_Contact or 0
    if dist_ent <= 3 then _G.In_Close_Contact = true end
    if _G.In_Close_Contact and dist_ent > 3.3 then
        _G.In_Close_Contact = false
        _G.Last_Close_Contact = tick()
    end

    local move_dir = LP.Character.Humanoid.MoveDirection
    local toEnemy = (closest.PrimaryPart.Position - LP.Character.PrimaryPart.Position).Unit
    local enemy_move = closest.Humanoid and closest.Humanoid.MoveDirection or Vector3.zero

    local E = 1
    local since_contact = tick() - _G.Last_Close_Contact
    if not _G.In_Close_Contact and since_contact >= 1.5 then
        if move_dir.Magnitude > 0.2 and move_dir:Dot(toEnemy) < -0.4 then E = 10 end
        if enemy_move.Magnitude > 0.2 and enemy_move:Dot(-toEnemy) < -0.4 then E = 10 end
    end

    local threshold = ping * 0.7 + math.min(speed / (E * 1.2), 80)
    if dist_ent > threshold then return threshold end
    if dist_ball > threshold then return threshold end

    return threshold
end

-- ═══ DETECTION EVENTS ════════════════════════════════════════════
pcall(function()
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(_, active)
        infinity_active = active or false
    end)
end)
pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(_, active)
        deathslash_active = active or false
    end)
end)
pcall(function()
    RS.Remotes.TimeHoleHoldBall.OnClientEvent:Connect(function(_, active)
        timehole_active = active or false
    end)
end)

-- ═══ TARGET CHECK — MULTI-FALLBACK ══════════════════════════════
local function is_my_target(ball)
    local t = ball:GetAttribute("target")
        or ball:GetAttribute("Target")
        or ball:GetAttribute("targetPlayer")
    if not t then return false end
    if t == LP.Name then return true end
    if t == LP.UserId then return true end
    if tostring(t) == tostring(LP.UserId) then return true end
    return false
end

-- ═══ MAIN LOOP ══════════════════════════════════════════════════
RunService.PreSimulation:Connect(function()
    local now = tick()

    -- cache hrp + ball
    if now - lastHrpCache > 0.15 then
        local ch = LP.Character
        cachedHrp = ch and ch:FindFirstChild("HumanoidRootPart")
        lastHrpCache = now
    end
    if not cachedHrp then return end

    if now - lastCache > 0.06 then
        cachedBall = Get_Ball()
        lastCache = now
    end
    local ball = cachedBall
    if not ball then return end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end

    local ping = Get_Ping() / 10
    local speed = zoomies.VectorVelocity.Magnitude
    local dist = (cachedHrp.Position - ball.Position).Magnitude
    local target = ball:GetAttribute("target")
    local is_target = is_my_target(ball)

    -- skip conditions
    if ball:FindFirstChild("ComboCounter") then return end
    if cachedHrp:FindFirstChild("SingularityCape") then return end
    if InfinityDetect and infinity_active then return end
    if DeathSlashDetect and deathslash_active then return end
    if TimeHoleDetect and timehole_active then return end

    -- AUTO PARRY
    if AutoParry and next(L5) then
        -- Zythera-style accuracy formula
        local ping_thresh = math.clamp(Get_Ping() / 10, 5, 17)
        local capped = math.min(math.max(speed - 9.5, 0), 650)
        local divisor = 2.4 + capped * 0.002
        local accuracy = ping_thresh + math.max(speed / divisor, 9.5)

        local curved = Is_Curved(ball)
        if curved then accuracy = accuracy * 0.85 end

        if is_target and dist <= accuracy then
            local bID = ball:GetDebugId()
            if not parried_ids[bID] then
                Fire_Parry()
                parried_ids[bID] = true
                task.spawn(function()
                    ball:GetAttributeChangedSignal("target"):Wait()
                    parried_ids[bID] = nil
                end)
                task.delay(3, function() parried_ids[bID] = nil end)
            end
        end
    end

    -- TRIGGERBOT
    if TriggerBot and is_target then
        local bID = ball:GetDebugId()
        if not parried_ids[bID] then
            Fire_Parry()
            parried_ids[bID] = true
            task.delay(0.5, function() parried_ids[bID] = nil end)
        end
    end

    -- AUTO SPAM
    if AutoSpam then
        local closest = Closest_Player()
        if closest and closest.PrimaryPart then
            local thresh = Spam_Service(ball, ping)
            local dist_ent = LP:DistanceFromCharacter(closest.PrimaryPart.Position)
            if dist <= thresh or dist_ent <= thresh then
                if not LP.Character:GetAttribute("Pulsed") then
                    local bID = ball:GetDebugId()
                    if not parried_ids[bID] then
                        Fire_Parry()
                        parried_ids[bID] = true
                        task.delay(0.15, function() parried_ids[bID] = nil end)
                    end
                end
            end
        end
    end
end)

-- ═══ KEYBINDS ═══════════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        AutoParry = not AutoParry
        print("[V12] AutoParry:", AutoParry and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.End then
        AutoParry = false; AutoSpam = false; TriggerBot = false
        print("[V12] PANIC")
    end
end)

-- ═══ UI — WindUI v2 ═════════════════════════════════════════════
local ok_w, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok_w or not WindUI then
    warn("[V12] WindUI fail — running headless")
    return
end

local Window = WindUI:CreateWindow({
    Title = "Slax V12",
    Icon = "solar:crown-bold",
    Author = "ALPHA XK",
    Folder = "SlaxV12",
    Size = UDim2.fromOffset(540, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
})

local TabMain = Window:Tab({ Title = "Combat", Icon = "solar:sword-bold" })
local TabDet  = Window:Tab({ Title = "Detection", Icon = "solar:shield-bold" })
local TabCurve= Window:Tab({ Title = "Curve", Icon = "solar:activity-bold" })
local TabInfo = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

local SecMain = TabMain:Section({ Title = "Auto Parry" })

SecMain:Toggle({
    Title = "Auto Parry",
    Desc = "Hookmetamethod + token regen + animation",
    Value = false,
    Callback = function(v)
        AutoParry = v
        WindUI:Notify({ Title = "Auto Parry", Content = v and "ON" or "OFF", Duration = 2 })
    end,
})

SecMain:Toggle({
    Title = "Auto Spam",
    Desc = "Zythera Spam Service — adaptive",
    Value = false,
    Callback = function(v) AutoSpam = v end,
})

SecMain:Toggle({
    Title = "Trigger Bot",
    Desc = "Instant parry when targeted",
    Value = false,
    Callback = function(v) TriggerBot = v end,
})

SecMain:Toggle({
    Title = "Animation Fix",
    Desc = "Play GrabParry anim (stealth)",
    Value = true,
    Callback = function(v) AnimFix = v end,
})

local SecDet = TabDet:Section({ Title = "Skip Parry" })

SecDet:Toggle({
    Title = "Infinity Ball",
    Value = true,
    Callback = function(v) InfinityDetect = v end,
})

SecDet:Toggle({
    Title = "Death Slash",
    Value = true,
    Callback = function(v) DeathSlashDetect = v end,
})

SecDet:Toggle({
    Title = "Time Hole",
    Value = true,
    Callback = function(v) TimeHoleDetect = v end,
})

local SecCurve = TabCurve:Section({ Title = "Curve Method" })
SecCurve:Dropdown({
    Title = "Curve",
    Values = {"camera","straight","backwards","slowball","random","high","left","right"},
    Value = "camera",
    Callback = function(v) CurrentCurve = v end,
})

local SecInfo = TabInfo:Section({ Title = "Status" })
local infoPara = SecInfo:Paragraph({ Title = "Runtime", Desc = "init..." })

task.spawn(function()
    while getgenv()._v12_loaded do
        pcall(function()
            infoPara:Set(string.format(
                "Hook: %s\nToken: %s\nCaptured remotes: %d\nParry count: %d\nPing: %d ms",
                Q5 and "OK" or "FAIL",
                _token and "OK" or "FAIL",
                capturedCount,
                (function() local n=0 for _ in pairs(parried_ids) do n=n+1 end return n end)(),
                Get_Ping()))
        end)
        task.wait(1)
    end
end)

-- Curve hotkeys 1-7
local curveKeys = {
    [Enum.KeyCode.One]="camera",[Enum.KeyCode.Two]="straight",[Enum.KeyCode.Three]="backwards",
    [Enum.KeyCode.Four]="slowball",[Enum.KeyCode.Five]="random",[Enum.KeyCode.Six]="high",
    [Enum.KeyCode.Seven]="left",[Enum.KeyCode.Eight]="right",
}
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeys[input.KeyCode] then
        CurrentCurve = curveKeys[input.KeyCode]
        print("[V12] Curve:", CurrentCurve)
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V12",
    Content = "Hookmetamethod ready — parry manual sekali kalau perlu",
    Duration = 5,
})

print("[V12] loaded")
print("[V12] Toggle: E | Panic: END | Curves: 1-8")

_G.v12_unload = function()
    getgenv()._v12_loaded = nil
    pcall(function() Window:Destroy() end)
end
