-- ═══════════════════════════════════════════════════════════════════════════
-- Slax V12.1 — Auto Parry (Ailon/Zythera-Inspired Fix)
-- Author: ALPHA XK
-- Fixes: checkcaller guard, fast path hook, loose arg filter, token fallback
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
local CurrentCurve      = "camera"

local L5                = {}       -- [remote] = captured args
local Q5                = nil      -- original __index
local _captureDone      = false    -- flag: stop hook work after 2 captures
local capturedCount     = 0
local parried_ids       = {}
local lastParryTime     = 0
local lastParryAnim     = 0

local infinity_active   = false
local deathslash_active = false
local timehole_active   = false

local cachedBall        = nil
local cachedHrp         = nil
local lastCache         = 0
local lastHrpCache      = 0

local parryAnimTrack    = nil

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
pcall(function()
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
end)

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

print("[V12.1] token:", _token and "OK" or "FAIL")

-- ═══ PARRY ANIMATION ════════════════════════════════════════════
local function Play_Parry_Animation()
    if not AnimFix then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    local swordName = char:GetAttribute("CurrentlyEquippedSword")
    local anim

    local shared = RS:FindFirstChild("Shared")
    local swordAPI = shared and shared:FindFirstChild("SwordAPI")
    local collection = swordAPI and swordAPI:FindFirstChild("Collection")
    local default = collection and collection:FindFirstChild("Default")

    if swordName and shared then
        local repInst = shared:FindFirstChild("ReplicatedInstances")
        local swords = repInst and repInst:FindFirstChild("Swords")
        local getSword = swords and swords:FindFirstChild("GetSword")
        if getSword then
            local ok, swordData = pcall(function()
                return getSword:Invoke(swordName)
            end)
            if ok and type(swordData) == "table" and swordData.AnimationType and collection then
                for _, obj in pairs(collection:GetChildren()) do
                    if obj.Name == swordData.AnimationType then
                        local a = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
                        if a then anim = a end
                    end
                end
            end
        end
    end
    anim = anim or (default and default:FindFirstChild("GrabParry"))
    if not anim then return end

    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            pcall(function() track:Stop(0.1) end)
        end
    end

    local ok2, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok2 and track then
        pcall(function() track:Play(0, 1, 1) end)
        parryAnimTrack = track
    end
end

pcall(function()
    RS.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if parryAnimTrack then pcall(function() parryAnimTrack:Stop() end) end
    end)
end)

-- ═══ PING ═══════════════════════════════════════════════════════
local function Get_Ping()
    local ok, res = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and res or 60
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

-- ═══ HOOK — FIXED (checkcaller, fast path, pcall IsA) ═══════════
-- Filter args: longgar (kayak Ailon — cuma 2 type check)
local function is_valid_args(args)
    return #args >= 6
        and type(args[2]) == "string"
        and type(args[3]) == "number"
end

if typeof(hookmetamethod) == "function" then
    Q5 = hookmetamethod(game, "__index", newcclosure(function(self, key)
        -- FAST PATH 1: capture done, bail (zero work)
        if _captureDone then
            return Q5(self, key)
        end
        -- FAST PATH 2: not FireServer/InvokeServer
        if key ~= "FireServer" and key ~= "InvokeServer" then
            return Q5(self, key)
        end
        -- FAST PATH 3: our own call
        if checkcaller and checkcaller() then
            return Q5(self, key)
        end
        -- SLOW PATH: safe IsA check via pcall
        local isRemote = false
        pcall(function()
            if key == "FireServer" then
                isRemote = self:IsA("RemoteEvent")
            else
                isRemote = self:IsA("RemoteFunction")
            end
        end)
        if not isRemote then
            return Q5(self, key)
        end

        return function(_, ...)
            local args = { ... }
            if not L5[self] and is_valid_args(args) then
                L5[self] = args
                capturedCount = capturedCount + 1
                print("[V12.1] captured:", self.Name or "?", "#args="..#args, "count="..capturedCount)
                if capturedCount >= 2 then _captureDone = true end
            end
            return Q5(self, key)(_, ...)
        end
    end))
    print("[V12.1] hookmetamethod installed")
else
    warn("[V12.1] hookmetamethod not available")
end

-- ═══ CURVE ══════════════════════════════════════════════════════
local function build_parry_data()
    local cam = WS.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize

    local aim = {vp.X / 2, vp.Y / 2}
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        aim = {vp.X / 2, vp.Y / 2}
    else
        local ok, m = pcall(function() return UIS:GetMouseLocation() end)
        if ok and m then aim = {m.X, m.Y} end
    end

    local events = {}
    local alive = WS:FindFirstChild("Alive")
    if alive then
        for _, e in pairs(alive:GetChildren()) do
            if e ~= LP.Character and e.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok and sp then events[tostring(e)] = sp end
            end
        end
    end

    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local cframe
    local m = CurrentCurve
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

-- ═══ FIRE — token regen with fallback 0 (Zythera style) ═════════
local function Fire_Parry()
    if tick() - lastParryTime < 0.05 then return false end
    lastParryTime = tick()

    if not next(L5) then
        local vim = game:GetService("VirtualInputManager")
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
            vim:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
        end)
        Play_Parry_Animation()
        return false
    end

    local fired = false
    for remote, origArgs in pairs(L5) do
        local data = build_parry_data()
        if not data then break end

        local uid = origArgs[2]
        local tok = _tokenize(uid) or 0

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

    Play_Parry_Animation()
    return fired
end

-- ═══ TARGET CHECK ═══════════════════════════════════════════════
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

    local speed = zoomies.VectorVelocity.Magnitude
    local dist = (cachedHrp.Position - ball.Position).Magnitude
    local is_target = is_my_target(ball)

    if ball:FindFirstChild("ComboCounter") then return end
    if cachedHrp:FindFirstChild("SingularityCape") then return end
    if InfinityDetect and infinity_active then return end
    if DeathSlashDetect and deathslash_active then return end
    if TimeHoleDetect and timehole_active then return end

    -- ═══ AUTO PARRY (Ailon formula) ═══
    if AutoParry and next(L5) then
        local ping = Get_Ping() / 10
        local ping_thresh = math.clamp(ping / 10, 5, 17)
        local capped = math.max(speed - 9.5, 0)
        local divisor = 2.4 + capped * 0.002
        local accuracy = ping_thresh + math.max(speed / divisor, 9.5)

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

    -- ═══ TRIGGERBOT ═══
    if TriggerBot and is_target then
        local bID = ball:GetDebugId()
        if not parried_ids[bID] then
            Fire_Parry()
            parried_ids[bID] = true
            task.delay(0.5, function() parried_ids[bID] = nil end)
        end
    end

    -- ═══ AUTO SPAM ═══
    if AutoSpam then
        local closest = Closest_Player()
        if closest and closest.PrimaryPart then
            local ping = Get_Ping() / 10
            local threshold = math.clamp(ping, 1, 16) + math.min(speed / 6, 255)
            local dist_ent = LP:DistanceFromCharacter(closest.PrimaryPart.Position)
            if dist <= threshold and dist_ent <= threshold then
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
        print("[V12.1] AutoParry:", AutoParry and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.End then
        AutoParry = false; AutoSpam = false; TriggerBot = false
        print("[V12.1] PANIC")
    end
end)

-- ═══ UI — WindUI v2 ═════════════════════════════════════════════
local ok_w, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok_w or not WindUI then
    warn("[V12.1] WindUI load fail — running headless")
    return
end

local Window = WindUI:CreateWindow({
    Title = "Slax V12.1",
    Icon = "solar:crown-bold",
    Author = "ALPHA XK",
    Folder = "SlaxV121",
    Size = UDim2.fromOffset(540, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
})

local TabMain  = Window:Tab({ Title = "Combat", Icon = "solar:sword-bold" })
local TabDet   = Window:Tab({ Title = "Detection", Icon = "solar:shield-bold" })
local TabCurve = Window:Tab({ Title = "Curve", Icon = "solar:activity-bold" })
local TabInfo  = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

local SecMain = TabMain:Section({ Title = "Auto Parry" })

SecMain:Toggle({
    Title = "Auto Parry",
    Desc = "checkcaller-fixed hook + Ailon formula",
    Value = false,
    Callback = function(v)
        AutoParry = v
        WindUI:Notify({ Title = "Auto Parry", Content = v and "ON" or "OFF", Duration = 2 })
    end,
})

SecMain:Toggle({
    Title = "Auto Spam",
    Desc = "Adaptive spam near players",
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

SecDet:Toggle({ Title = "Infinity Ball", Value = true, Callback = function(v) InfinityDetect = v end })
SecDet:Toggle({ Title = "Death Slash",   Value = true, Callback = function(v) DeathSlashDetect = v end })
SecDet:Toggle({ Title = "Time Hole",     Value = true, Callback = function(v) TimeHoleDetect = v end })

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
                "Hook: %s\nCapture: %s (%d remotes)\nToken: %s\nParry count: %d\nPing: %d ms",
                Q5 and "OK" or "FAIL",
                _captureDone and "DONE" or "waiting",
                capturedCount,
                _token and "OK" or "FAIL",
                (function() local n=0 for _ in pairs(parried_ids) do n=n+1 end return n end)(),
                Get_Ping()))
        end)
        task.wait(1)
    end
end)

-- Curve hotkeys 1-8
local curveKeys = {
    [Enum.KeyCode.One]="camera",[Enum.KeyCode.Two]="straight",[Enum.KeyCode.Three]="backwards",
    [Enum.KeyCode.Four]="slowball",[Enum.KeyCode.Five]="random",[Enum.KeyCode.Six]="high",
    [Enum.KeyCode.Seven]="left",[Enum.KeyCode.Eight]="right",
}
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if curveKeys[input.KeyCode] then
        CurrentCurve = curveKeys[input.KeyCode]
        print("[V12.1] Curve:", CurrentCurve)
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Slax V12.1",
    Content = "Parry manual SEKALI untuk capture remote",
    Duration = 6,
})

print("[V12.1] loaded")
print("[V12.1] Toggle: E | Panic: END | Curves: 1-8")

_G.v12_unload = function()
    getgenv()._v12_loaded = nil
    pcall(function() Window:Destroy() end)
end
