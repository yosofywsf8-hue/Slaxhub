--[[
    ═══════════════════════════════════════════════════════════
    OXY PREMIUM — Full Single-File Build (No Shop, No Key)
    Tabs : Combat | Visual | FFlags | Config | Mobile
    ═══════════════════════════════════════════════════════════
]]

if _G.OxyPremiumLoaded then return end
_G.OxyPremiumLoaded = true

--=============================================================
-- [0] SERVICES
--=============================================================
local cloneref = cloneref or function(x) return x end
local Players   = cloneref(game:GetService("Players"))
local Run       = cloneref(game:GetService("RunService"))
local UIS       = cloneref(game:GetService("UserInputService"))
local Stats     = cloneref(game:GetService("Stats"))
local RS        = cloneref(game:GetService("ReplicatedStorage"))
local WS        = cloneref(game:GetService("Workspace"))
local Http      = cloneref(game:GetService("HttpService"))
local TweenSrv  = cloneref(game:GetService("TweenService"))
local Debris    = cloneref(game:GetService("Debris"))

local LP        = Players.LocalPlayer
local dataPing  = Stats.Network.ServerStatsItem["Data Ping"]
local preSim    = Run.PreSimulation
local postSim   = Run.PostSimulation
local heartbeat = Run.Heartbeat

local touchEnabled    = UIS.TouchEnabled
local keyboardEnabled = UIS.KeyboardEnabled
local gamepadEnabled  = UIS.GamepadEnabled

--=============================================================
-- [1] CONFIG
--=============================================================
local DIR, PATH = "oxy", "oxy/config.json"
local FF_DIR    = "oxy/fflags"

local defaults = {
    accuracy = 100, spam_threshold = 3,
    curve_keybind = false, manual_notify = false, curve_notify = false,
    curve_method = "camera", manual_spam = "E",
    mobile_triggerbot_button = false, mobile_manual_spam_button = false,
    ability_esp = false, auto_parry = false,
    auto_spam = false, random_target = false,
    fflag_profile = "default", fflag_json = "", fflag_auto_load = false,
}
local Config = {}
for k, v in pairs(defaults) do Config[k] = v end

local storageOK = type(readfile) == "function" and type(writefile) == "function"
local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end

local function ensureFolder()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then return end
    if not isfolder(DIR) then pcall(makefolder, DIR) end
end

local function ensureFFFolder()
    ensureFolder()
    if type(isfolder) ~= "function" then return end
    if not isfolder(FF_DIR) then pcall(makefolder, FF_DIR) end
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = copy(v) end
    return r
end

local function normalize(d)
    local out = {}
    for k, v in pairs(defaults) do
        local cur = type(d) == "table" and d[k] or nil
        if type(v) == "table" then
            out[k] = type(cur) == "table" and copy(cur) or copy(v)
        else
            out[k] = type(cur) == type(v) and cur or v
        end
    end
    out.accuracy       = math.clamp(math.floor(out.accuracy + 0.5), 1, 100)
    out.spam_threshold = math.clamp(math.floor(out.spam_threshold + 0.5), 1, 3)
    local validCurve = { camera = 1, dot = 1, backwards = 1, slow = 1, random = 1 }
    if not validCurve[out.curve_method] then out.curve_method = "camera" end
    if Enum.KeyCode[out.manual_spam] == nil then out.manual_spam = "E" end
    out.fflag_profile = trim(out.fflag_profile)
    if out.fflag_profile == "" then out.fflag_profile = "default" end
    return out
end

if storageOK then
    ensureFolder()
    local ok, data = pcall(function() return Http:JSONDecode(readfile(PATH)) end)
    if ok then
        for k, v in pairs(normalize(data)) do Config[k] = v end
    end
end

local lastSaved, hasSaved = {}, false

local function eq(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if type(v) == "table" then
            if not eq(v, b[k]) then return false end
        elseif b[k] ~= v then return false end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function changed()
    if not hasSaved then return true end
    for k in pairs(defaults) do
        local a, b = lastSaved[k], Config[k]
        if type(a) == "table" or type(b) == "table" then
            if not eq(a, b) then return true end
        elseif a ~= b then return true end
    end
    return false
end

local function saveConfig()
    if not storageOK or not changed() then return end
    local out = {}
    for k, v in pairs(defaults) do
        local cur = Config[k]
        if type(v) == "table" then
            out[k] = type(cur) == "table" and copy(cur) or copy(v)
        else
            out[k] = type(cur) == type(v) and cur or v
        end
    end
    local ok, encoded = pcall(function() return Http:JSONEncode(out) end)
    if not ok then return end
    ensureFolder()
    if not pcall(writefile, PATH, encoded) then return end
    for k in pairs(defaults) do
        lastSaved[k] = type(out[k]) == "table" and copy(out[k]) or out[k]
    end
    hasSaved = true
end

task.spawn(function()
    while _G.OxyPremiumLoaded do
        task.wait(1)
        saveConfig()
    end
end)

--=============================================================
-- [2] FFLAGS
--=============================================================
local FFlag = {}

local function fpath(name)
    local n = trim(name)
    if n == "" then return nil, "profile name is empty" end
    n = n:gsub("[<>:\"/\\|%?%*%c]", "_"):sub(1, 64)
    return FF_DIR .. "/" .. n .. ".json", nil, n
end

local function fdecode(json)
    if type(json) ~= "string" or trim(json) == "" then return nil, "fflags json is empty" end
    local ok, d = pcall(function() return Http:JSONDecode(json) end)
    if not ok or type(d) ~= "table" then return nil, "invalid fflags json" end
    local out, count = {}, 0
    for k, v in pairs(d) do
        if type(k) ~= "string" or trim(k) == "" then return nil, "invalid flag name" end
        if type(v) ~= "string" and type(v) ~= "number" and type(v) ~= "boolean" then
            return nil, "flag values must be string/number/boolean"
        end
        out[k] = tostring(v)
        count = count + 1
    end
    if count == 0 then return nil, "no flags found" end
    return out, nil, count
end

function FFlag.apply(json)
    if type(setfflag) ~= "function" then return false, "setfflag unavailable" end
    local flags, err, count = fdecode(json)
    if not flags then return false, err end
    local failed = {}
    for k, v in pairs(flags) do
        if not pcall(setfflag, k, v) then table.insert(failed, k) end
    end
    if #failed > 0 then
        table.sort(failed)
        return false, string.format("failed %d/%d: %s", #failed, count, table.concat(failed, ", "))
    end
    return true, string.format("applied %d fflags", count)
end

function FFlag.saveProfile(name, json)
    if not storageOK then return false, "storage unavailable" end
    local flags, err = fdecode(json)
    if not flags then return false, err end
    local path, perr, safe = fpath(name)
    if not path then return false, perr end
    local ok, enc = pcall(function() return Http:JSONEncode(flags) end)
    if not ok then return false, "encode failed" end
    ensureFFFolder()
    if not pcall(writefile, path, enc) then return false, "save failed" end
    return true, enc, safe
end

function FFlag.loadProfile(name)
    if not storageOK then return false, "storage unavailable" end
    local path, err, safe = fpath(name)
    if not path then return false, err end
    local ok, content = pcall(readfile, path)
    if not ok or type(content) ~= "string" then return false, "profile not found" end
    local flags, derr = fdecode(content)
    if not flags then return false, derr end
    return true, content, safe
end

function FFlag.list()
    if type(listfiles) ~= "function" then return nil, "listfiles unavailable" end
    ensureFFFolder()
    local ok, files = pcall(listfiles, FF_DIR)
    if not ok or type(files) ~= "table" then return nil, "list failed" end
    local seen, out = {}, {}
    for _, f in ipairs(files) do
        local m = tostring(f):gsub("\\", "/"):match("([^/]+)%.json$")
        if m and not seen[m] then seen[m] = true; table.insert(out, m) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function FFlag.delete(name)
    if type(delfile) ~= "function" then return false, "delfile unavailable" end
    local path, err = fpath(name)
    if not path then return false, err end
    if not pcall(delfile, path) then return false, "delete failed" end
    return true
end

local runtimeFFlag
if Config.fflag_auto_load then
    local ok, content = FFlag.loadProfile(Config.fflag_profile)
    if ok then Config.fflag_json = content end
    local aok, amsg = FFlag.apply(Config.fflag_json)
    runtimeFFlag = { ok = aok, message = amsg }
end

--=============================================================
-- [3] UI + SPLASH
--=============================================================
local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()

local win = Fluent:CreateWindow({
    Title = "Oxy Premium", Subtitle = "private build",
    TabWidth = 155, Size = UDim2.fromOffset(530, 370),
    Acrylic = true, Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local T = {
    Combat = win:AddTab({ Title = "Combat", Icon = "swords" }),
    Visual = win:AddTab({ Title = "Visual", Icon = "eye" }),
    FFlags = win:AddTab({ Title = "FFlags", Icon = "file-json" }),
    Config = win:AddTab({ Title = "Config", Icon = "settings" }),
    Mobile = win:AddTab({ Title = "Mobile", Icon = "smartphone" }),
}
local S = {
    Combat = T.Combat:AddSection(""),
    Visual = T.Visual:AddSection(""),
    FFlags = T.FFlags:AddSection(""),
    Config = T.Config:AddSection(""),
    Mobile = T.Mobile:AddSection(""),
}

local function notify(title, content, duration)
    Fluent:Notify({ Title = title, Content = content, Duration = duration or 4 })
end

do
    local sg = Instance.new("ScreenGui")
    sg.Name = "OxySplash"; sg.IgnoreGuiInset = true; sg.DisplayOrder = 999
    sg.Parent = LP:WaitForChild("PlayerGui")
    local bg = Instance.new("Frame", sg)
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    bg.BorderSizePixel = 0
    local t1 = Instance.new("TextLabel", bg)
    t1.Size = UDim2.new(0, 500, 0, 60)
    t1.Position = UDim2.new(0.5, -250, 0.5, -40)
    t1.BackgroundTransparency = 1; t1.Text = "OXY PREMIUM"
    t1.Font = Enum.Font.GothamBlack; t1.TextSize = 44
    t1.TextColor3 = Color3.fromRGB(235, 235, 240); t1.TextTransparency = 1
    local t2 = Instance.new("TextLabel", bg)
    t2.Size = UDim2.new(0, 500, 0, 24)
    t2.Position = UDim2.new(0.5, -250, 0.5, 25)
    t2.BackgroundTransparency = 1; t2.Text = "private build · loading"
    t2.Font = Enum.Font.Gotham; t2.TextSize = 14
    t2.TextColor3 = Color3.fromRGB(110, 110, 125); t2.TextTransparency = 1
    TweenSrv:Create(t1, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    TweenSrv:Create(t2, TweenInfo.new(0.5, nil, nil, 0.2), { TextTransparency = 0 }):Play()
    task.wait(1.4)
    TweenSrv:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
    TweenSrv:Create(t1, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
    TweenSrv:Create(t2, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
    task.wait(0.5); sg:Destroy()
end

--=============================================================
-- [4] BALL STATE
--=============================================================
local Balls   = WS:WaitForChild("Balls")
local Alive   = WS:WaitForChild("Alive")
local Runtime = WS:WaitForChild("Runtime")

local ballState = { positions = {}, state = {
    AerodynamicTime = tick(), LastWarping = tick(), LerpRadians = 0, Curving = tick(),
}}

do
    local Pk = RS:FindFirstChild("Packages")
    local idx = Pk and Pk:FindFirstChild("_Index")
    local net = idx and idx:FindFirstChild("sleitnick_net@0.1.0")
    net = net and net:FindFirstChild("net")
    if net then
        for _, r in ipairs(net:GetChildren()) do
            if r:IsA("UnreliableRemoteEvent") and r.Name ~= "URE/ReplicateBallPosition" then
                r.OnClientEvent:Connect(function(ball, pos)
                    if ball and ball.Parent == Balls and ball:GetAttribute("realBall") then
                        ballState.positions[ball] = pos
                    end
                end)
                break
            end
        end
    end
end

function ballState.get()
    for _, b in ipairs(Balls:GetChildren()) do
        if b:GetAttribute("realBall") then return b end
    end
end

function ballState.position(b)
    b = b or ballState.get()
    if b then return ballState.positions[b] or b.Position end
    return Vector3.zero
end

function ballState.all()
    local t = {}
    for _, b in ipairs(Balls:GetChildren()) do
        if b:GetAttribute("realBall") then table.insert(t, b) end
    end
    return t
end

local function lerp(a, b, t) return a + (b - a) * t end

function ballState.curved(b)
    b = b or ballState.get()
    if not b then return false end
    local z = b:FindFirstChild("zoomies")
    if not z then return false end
    local char = LP.Character
    local root = char and char.PrimaryPart
    if not root then return false end
    local now  = tick()
    local ping = dataPing:GetValue()
    local v    = z.VectorVelocity
    local u    = v.Unit
    local pos  = root.Position
    local bp   = ballState.position(b)
    local u2   = (pos - bp).Unit
    local dot  = u2:Dot(u)
    local mag  = v.Magnitude
    local aux  = math.min(mag / 100, 40)
    local d1   = dot - u2:Dot((u - v).Unit)
    local dist = (pos - bp).Magnitude
    local thr  = 0.5 - ping / 1000
    local c1   = dist / mag - ping / 1000
    local c2   = 15 - math.min(dist / 1000, 15) + aux
    ballState.state.LerpRadians = lerp(
        ballState.state.LerpRadians,
        math.rad(math.asin(math.clamp(dot, -1, 1))), 0.8)
    if mag > 100 and c1 > ping / 10 then c2 = math.max(c2 - 15, 15) end
    if dist < c2 then return false end
    if d1 < thr then return true end
    if ballState.state.LerpRadians < 0.018 then ballState.state.LastWarping = now end
    if now - ballState.state.LastWarping < c1 / 1.5 then return true end
    if now - ballState.state.Curving < c1 / 1.5 then return true end
    return dot < thr
end

--=============================================================
-- [5] TARGET
--=============================================================
local targetMgr = { current = nil, visited = {} }

local function byMouse()
    local list = {}
    for _, p in ipairs(Alive:GetChildren()) do
        if p.Name ~= LP.Name and p.PrimaryPart then table.insert(list, p) end
    end
    if #list == 0 then targetMgr.current = nil; return end
    local cam = WS.CurrentCamera
    local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
    local dir
    if UIS.MouseEnabled then
        local m = UIS:GetMouseLocation()
        dir = cam:ScreenPointToRay(m.X, m.Y).Direction
    else
        local v = cam.ViewportSize
        dir = cam:ViewportPointToRay(v.X * 0.5, v.Y * 0.5).Direction
    end
    local best, bestDot = nil, -math.huge
    for _, p in ipairs(list) do
        local d = p.PrimaryPart.Position - origin
        if d.Magnitude > 0 and look:Dot(d.Unit) > 0 then
            local dot = dir:Dot(d.Unit)
            if dot > bestDot then bestDot = dot; best = p end
        end
    end
    targetMgr.current = best or list[1]
end

function targetMgr.pickRandom()
    local list = {}
    for _, p in ipairs(Alive:GetChildren()) do
        if p.Name ~= LP.Name and p.PrimaryPart then table.insert(list, p) end
    end
    if #list == 0 then targetMgr.current = nil; return end
    if #list == 1 then targetMgr.current = list[1]; return end
    local fresh = {}
    for _, p in ipairs(list) do
        if not targetMgr.visited[p.Name] then table.insert(fresh, p) end
    end
    if #fresh == 0 then
        targetMgr.visited = {}
        for _, p in ipairs(list) do
            if not targetMgr.current or p.Name ~= targetMgr.current.Name then
                table.insert(fresh, p)
            end
        end
        if #fresh == 0 then fresh = list end
    end
    local pick = fresh[math.random(1, #fresh)]
    targetMgr.visited[pick.Name] = true
    targetMgr.current = pick
end

function targetMgr.closest()
    if Config.random_target then
        if not targetMgr.current then targetMgr.pickRandom() end
        return targetMgr.current
    end
    byMouse()
    return targetMgr.current
end

--=============================================================
-- [6] PARRY HOOK
--=============================================================
local Parry = { count = 0 }

function Parry.fire(manual)
    if Parry.count > 7 then return false end
    Parry.count = Parry.count + 1
    task.delay(0.5, function()
        if Parry.count > 0 then Parry.count = Parry.count - 1 end
    end)
    -- ═══════════════════════════════════════════════════════
    -- [HOOK] اربط الريموت هنا. مثال:
    --   game:GetService("ReplicatedStorage").Remotes.Parry:FireServer(args)
    -- ═══════════════════════════════════════════════════════
    return true
end
_G.OXY_FIRE_PARRY = Parry.fire

--=============================================================
-- [7] AUTOPARRY
--=============================================================
local parryState = { debounce = false, until_at = 0, accuracy = 1.5 }

local function parryCheck()
    local char = LP.Character
    local root = char and char.PrimaryPart
    if not root then return end
    local now = tick()
    if parryState.debounce or now < parryState.until_at then return end
    local pos = root.Position
    local tol = math.clamp(dataPing:GetValue() / 100, 5, 17)
    local tornado = Runtime:FindFirstChild("Tornado")
    local tornadoTime = tornado and (tornado:GetAttribute("TornadoTime") or 1)
    for _, b in ipairs(ballState.all()) do
        local z = b:FindFirstChild("zoomies")
        if z then
            local tgt = b:GetAttribute("target")
            local mag = z.VectorVelocity.Magnitude
            local dist = (pos - ballState.position(b)).Magnitude
            local calcA = (2.4 + math.min(math.max(mag - 9.5, 0), 650) * 0.002) * parryState.accuracy
            if b:FindFirstChild("AeroDynamicSlashVFX") then
                Debris:AddItem(b.AeroDynamicSlashVFX, 0)
                ballState.state.AerodynamicTime = now
            end
            if tornado and now - ballState.state.AerodynamicTime < tornadoTime + 0.314 then return end
            if tgt == LP.Name and dist <= tol + math.max(mag / calcA, 9.5) and not ballState.curved(b) then
                Parry.fire()
                parryState.debounce = true
                parryState.until_at = now + 1
            end
        end
    end
end

local autoParryConn
local function setAutoParry(on)
    Config.auto_parry = on
    if on then
        if autoParryConn then autoParryConn:Disconnect() end
        autoParryConn = postSim:Connect(parryCheck)
    else
        if autoParryConn then autoParryConn:Disconnect(); autoParryConn = nil end
    end
end

--=============================================================
-- [8] AUTOSPAM + MANUAL
--=============================================================
local spam = { distance = 0, last_auto = 0, manual_on = false, last_manual = 0, manual_key = Enum.KeyCode.E }

local function ballProps()
    local b = ballState.get()
    if not b or not LP.Character or not LP.Character.PrimaryPart then
        return { Distance = 0, Direction = Vector3.zero, Velocity = Vector3.zero, Dot = 0 }
    end
    local p, bp = LP.Character.PrimaryPart.Position, ballState.position(b)
    return { Distance = (p - bp).Magnitude, Direction = (p - bp).Unit, Velocity = Vector3.zero, Dot = 0 }
end

local function targetProps()
    local c = targetMgr.current or targetMgr.closest()
    if not c or not c.PrimaryPart or not LP.Character or not LP.Character.PrimaryPart then
        return { distance = 0 }
    end
    local pos = LP.Character.PrimaryPart.Position
    return {
        velocity  = c.PrimaryPart.Velocity,
        direction = (pos - c.PrimaryPart.Position).Unit,
        distance  = (pos - c.PrimaryPart.Position).Magnitude,
    }
end

local function spamPerform(info)
    local b = ballState.get()
    local c = targetMgr.current or targetMgr.closest()
    if not b or not c or not c.PrimaryPart or not LP.Character.PrimaryPart then return false end
    local v = b.AssemblyLinearVelocity
    local mag = v.Magnitude
    local dot = (LP.Character.PrimaryPart.Position - ballState.position(b)).Unit:Dot(v.Unit)
    local dist = LP:DistanceFromCharacter(c.PrimaryPart.Position)
    local allowed = info.Ping + math.min(mag / 6, 95)
    if info.Entity_Properties.distance > allowed then return spam.distance end
    if allowed < info.Ball_Properties.Distance then return spam.distance end
    if allowed < dist then return spam.distance end
    spam.distance = allowed - math.clamp(dot, -1, 0) * (5 - math.min(mag / 5, 5))
    return spam.distance
end

local function autoSpamCheck()
    local b = ballState.get()
    if not b or not b:FindFirstChild("zoomies") then return end
    targetMgr.closest()
    if not targetMgr.current or not targetMgr.current.PrimaryPart then return end
    local now = tick()
    local allowed = spamPerform({
        Ball_Properties   = ballProps(),
        Entity_Properties = targetProps(),
        Ping = math.clamp(dataPing:GetValue() / 10, 1, 16),
    })
    local char = LP.Character
    if not char or not char.PrimaryPart then return end
    local ballDist = (char.PrimaryPart.Position - ballState.position(b)).Magnitude
    local tgt = b:GetAttribute("target")
    if not tgt then return end
    local distToT = LP:DistanceFromCharacter(targetMgr.current.PrimaryPart.Position)
    if distToT > allowed or ballDist > allowed then return end
    if char:GetAttribute("Pulsed") then return end
    if tgt == LP.Name and distToT > 30 and ballDist > 30 then return end
    if ballDist <= allowed and Parry.count > Config.spam_threshold and now - spam.last_auto >= 0.001 then
        spam.last_auto = now
        Parry.fire(true)
    end
end

local autoSpamConn
local function setAutoSpam(on)
    Config.auto_spam = on
    if on then
        if autoSpamConn then autoSpamConn:Disconnect() end
        autoSpamConn = preSim:Connect(autoSpamCheck)
    else
        if autoSpamConn then autoSpamConn:Disconnect(); autoSpamConn = nil end
    end
end

local manualConn
local function setManual(on)
    if spam.manual_on == on then return end
    spam.manual_on = on
    if manualConn then manualConn:Disconnect(); manualConn = nil end
    if on then
        manualConn = preSim:Connect(function()
            if tick() - spam.last_manual < 0.001 then return end
            spam.last_manual = tick()
            Parry.fire(true)
        end)
    end
    if Config.manual_notify then notify("manual spam", on and "on" or "off") end
end

--=============================================================
-- [9] TRIGGERBOT
--=============================================================
local trigger = { on = false, busy = false }

local function triggerFire()
    if trigger.busy then return end
    trigger.busy = true
    Parry.fire()
    task.delay(1, function() trigger.busy = false end)
end

local triggerConn
local function setTrigger(on)
    if trigger.on == on then return end
    trigger.on = on
    notify("triggerbot", on and "on" or "off", 2)
    if on then
        if triggerConn then triggerConn:Disconnect() end
        triggerConn = preSim:Connect(function()
            local b = ballState.get()
            if b and b:GetAttribute("target") == LP.Name then triggerFire() end
        end)
    else
        if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
    end
end

--=============================================================
-- [10] ABILITY ESP
--=============================================================
local esp = { labels = {} }

local function createEsp(player)
    task.spawn(function()
        local char = player.Character
        while not char or not char.Parent do
            task.wait(0.2); char = player.Character
        end
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        local bb = Instance.new("BillboardGui")
        bb.Adornee = head; bb.Size = UDim2.fromOffset(200, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Parent = head
        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        esp.labels[player] = lbl
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        local function update()
            local ab = player:GetAttribute("EquippedAbility")
            lbl.Text = ab and (player.DisplayName .. " [" .. ab .. "]") or player.DisplayName
            lbl.Visible = Config.ability_esp
        end
        update()
        local c1 = player:GetAttributeChangedSignal("EquippedAbility"):Connect(update)
        local conn
        conn = heartbeat:Connect(function()
            if not char or not char.Parent then
                conn:Disconnect(); c1:Disconnect(); bb:Destroy()
                esp.labels[player] = nil; return
            end
            lbl.Visible = Config.ability_esp
        end)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        p.CharacterAdded:Connect(function() createEsp(p) end)
        createEsp(p)
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() createEsp(p) end)
end)

--=============================================================
-- [11] CURVE
--=============================================================
local curveMethods = { "camera", "dot", "backwards", "slow", "random" }
local curveHotkeys = {
    [Enum.KeyCode.One]   = "camera",
    [Enum.KeyCode.Two]   = "dot",
    [Enum.KeyCode.Three] = "backwards",
    [Enum.KeyCode.Four]  = "slow",
    [Enum.KeyCode.Five]  = "random",
}

local curveDropdown
curveDropdown = S.Combat:AddDropdown("CurveMethod", {
    Title = "Curve method",
    Values = curveMethods,
    Default = Config.curve_method,
    Multi = false,
    Callback = function(v) Config.curve_method = v end,
})

UIS.InputBegan:Connect(function(input, gp)
    if gp or not Config.curve_keybind then return end
    local m = curveHotkeys[input.KeyCode]
    if m and m ~= Config.curve_method then
        Config.curve_method = m
        curveDropdown:SetValue(m)
        if Config.curve_notify then notify("curve method", "now " .. m, 3) end
    end
end)

--=============================================================
-- [12] MOBILE BUTTONS
--=============================================================
local function makeMobileButton(name, pos, label, onClick)
    if not touchEnabled then return nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "oxy_" .. name; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 50
    gui.Parent = LP:WaitForChild("PlayerGui")
    local btn = Instance.new("TextButton", gui)
    btn.Name = name; btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = pos; btn.Size = UDim2.fromOffset(140, 46)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 15; btn.Text = label
    btn.Font = Enum.Font.GothamBold; btn.ZIndex = 2
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(45, 45, 55); stroke.Thickness = 1
    btn.MouseButton1Click:Connect(function()
        onClick()
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        TweenSrv:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        }):Play()
    end)
    return btn
end

local triggerBtn = makeMobileButton("triggerbot", UDim2.new(1, -290, 0.5, 0),
    "triggerbot [off]", function() setTrigger(not trigger.on) end)
local manualBtn = makeMobileButton("manualspam", UDim2.new(1, -145, 0.5, 0),
    "manual [off]", function() setManual(not spam.manual_on) end)

local function updateMobileLabels()
    if triggerBtn then triggerBtn.Text = trigger.on and "triggerbot [on]" or "triggerbot [off]" end
    if manualBtn  then manualBtn.Text  = spam.manual_on and "manual [on]" or "manual [off]" end
end

--=============================================================
-- [13] UI BINDING — Combat
--=============================================================
S.Combat:AddToggle("AutoParry", {
    Title = "Auto parry", Default = Config.auto_parry, Callback = setAutoParry,
})

S.Combat:AddSlider("Accuracy", {
    Title = "Accuracy", Min = 1, Max = 100, Rounding = 1, Default = Config.accuracy,
    Callback = function(v)
        Config.accuracy = v
        parryState.accuracy = (v - 1) * 0.01515
    end,
})
parryState.accuracy = (Config.accuracy - 1) * 0.01515

S.Combat:AddToggle("RandomTarget", {
    Title = "Random target", Default = Config.random_target,
    Callback = function(v)
        Config.random_target = v
        targetMgr.current = nil; targetMgr.visited = {}
        if v then targetMgr.pickRandom() end
    end,
})

S.Combat:AddToggle("AutoSpam", {
    Title = "Auto spam", Default = Config.auto_spam, Callback = setAutoSpam,
})

S.Combat:AddSlider("Threshold", {
    Title = "Threshold", Min = 1, Max = 3, Rounding = 1, Default = Config.spam_threshold,
    Callback = function(v) Config.spam_threshold = v end,
})

S.Combat:AddToggle("Triggerbot", {
    Title = "Triggerbot", Default = false,
    Callback = function(v) setTrigger(v); updateMobileLabels() end,
})

S.Combat:AddToggle("hotkey_curve", {
    Title = "Hotkey curve", Default = Config.curve_keybind,
    Callback = function(v) Config.curve_keybind = v end,
})

S.Combat:AddToggle("hotkey_notify", {
    Title = "Hotkey notify", Default = Config.curve_notify,
    Callback = function(v) Config.curve_notify = v end,
})

S.Combat:AddToggle("manual_notify", {
    Title = "Manual notify", Default = Config.manual_notify,
    Callback = function(v) Config.manual_notify = v end,
})

--=============================================================
-- [14] UI BINDING — Visual
--=============================================================
S.Visual:AddToggle("AbilityESP", {
    Title = "Ability ESP", Default = Config.ability_esp,
    Callback = function(v)
        Config.ability_esp = v
        for p, lbl in pairs(esp.labels) do
            if lbl and lbl.Parent then
                local ab = p:GetAttribute("EquippedAbility")
                lbl.Text = ab and (p.DisplayName .. " [" .. ab .. "]") or p.DisplayName
                lbl.Visible = v
            end
        end
    end,
})

--=============================================================
-- [15] UI BINDING — Mobile
--=============================================================
if touchEnabled then
    S.Mobile:AddToggle("MobileTrigger", {
        Title = "Triggerbot button", Default = Config.mobile_triggerbot_button,
        Callback = function(v)
            Config.mobile_triggerbot_button = v
            if triggerBtn then triggerBtn.Visible = v end
            if not v then setTrigger(false); updateMobileLabels() end
        end,
    })
    S.Mobile:AddToggle("MobileManual", {
        Title = "Manual spam button", Default = Config.mobile_manual_spam_button,
        Callback = function(v)
            Config.mobile_manual_spam_button = v
            if manualBtn then manualBtn.Visible = v end
            if not v then setManual(false); updateMobileLabels() end
        end,
    })
    if triggerBtn then triggerBtn.Visible = Config.mobile_triggerbot_button end
    if manualBtn  then manualBtn.Visible  = Config.mobile_manual_spam_button  end
else
    S.Mobile:AddParagraph({
        Title = "Mobile",
        Content = "هذا الجهاز لا يدعم اللمس — الأزرار معطلة",
    })
end

--=============================================================
-- [16] KEYBINDS
--=============================================================
local doKeybinds = false
local function initKeybinds()
    if doKeybinds or (not keyboardEnabled and not gamepadEnabled) then return end
    doKeybinds = true
    S.Combat:AddKeybind("TriggerbotKey", {
        Title = "Triggerbot key", Default = "T", Mode = "Toggle",
        Callback = function() setTrigger(not trigger.on); updateMobileLabels() end,
    })
    S.Combat:AddKeybind("ManualSpamKey", {
        Title = "Manual spam key", Default = Config.manual_spam, Mode = "Toggle",
        ChangedCallback = function(k) Config.manual_spam = k.Name end,
        Callback = function() setManual(not spam.manual_on); updateMobileLabels() end,
    })
end
initKeybinds()

UIS.GamepadConnected:Connect(function() gamepadEnabled = true; initKeybinds() end)
UIS:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
    keyboardEnabled = UIS.KeyboardEnabled; initKeybinds()
end)
UIS:GetPropertyChangedSignal("GamepadEnabled"):Connect(function()
    gamepadEnabled = UIS.GamepadEnabled; initKeybinds()
end)

--=============================================================
-- [17] UI BINDING — FFlags
--=============================================================
local profileInput = S.FFlags:AddInput("FFlagProfile", {
    Title = "Profile name", Default = Config.fflag_profile,
    Placeholder = "default", Finished = true,
    Callback = function(v) Config.fflag_profile = trim(v) end,
})

local jsonInput = S.FFlags:AddInput("FFlagJson", {
    Title = "FFlags JSON", Default = Config.fflag_json,
    Placeholder = '{"DFIntTaskSchedulerTargetFps":"240"}', Finished = true,
    Callback = function(v) Config.fflag_json = v end,
})

local savedDropdown
do
    local opts = FFlag.list() or { "(no saved profiles)" }
    savedDropdown = S.FFlags:AddDropdown("SavedProfiles", {
        Title = "Saved profiles", Values = opts, Multi = false, Default = opts[1],
        Callback = function(selected)
            if selected == "(no saved profiles)" or selected == "(profile listing unavailable)" then return end
            local ok, content = FFlag.loadProfile(selected)
            if ok then
                Config.fflag_profile = selected; Config.fflag_json = content
                profileInput:SetValue(selected); jsonInput:SetValue(content)
                saveConfig()
            else
                notify("fflags error", content, 5)
            end
        end,
    })
end

S.FFlags:AddButton({
    Title = "Save profile",
    Callback = function()
        local ok, enc, safe = FFlag.saveProfile(profileInput.Value, jsonInput.Value)
        if ok then
            Config.fflag_profile = safe; Config.fflag_json = enc
            local opts = FFlag.list() or { "(no saved profiles)" }
            savedDropdown:SetValues(opts); savedDropdown:SetValue(safe)
            saveConfig(); notify("fflags", "saved '" .. safe .. "'", 4)
        else
            notify("fflags error", enc, 5)
        end
    end,
})

S.FFlags:AddButton({
    Title = "Load profile",
    Callback = function()
        local ok, content, safe = FFlag.loadProfile(trim(profileInput.Value))
        if ok then
            Config.fflag_profile = safe; Config.fflag_json = content
            jsonInput:SetValue(content); saveConfig()
            notify("fflags", "loaded '" .. safe .. "'", 4)
        else
            notify("fflags error", content, 5)
        end
    end,
})

S.FFlags:AddButton({
    Title = "Delete profile",
    Callback = function()
        local selected = savedDropdown.Value
        if not selected or selected == "(no saved profiles)" then
            notify("fflags error", "no profile selected", 4); return
        end
        local ok, err = FFlag.delete(selected)
        if ok then
            local opts = FFlag.list() or { "(no saved profiles)" }
            savedDropdown:SetValues(opts); savedDropdown:SetValue(opts[1])
            notify("fflags", "deleted '" .. selected .. "'", 4)
        else
            notify("fflags error", err, 5)
        end
    end,
})

local autoToggle
autoToggle = S.FFlags:AddToggle("FFlagAutoLoad", {
    Title = "Auto load profile", Default = Config.fflag_auto_load,
    Callback = function(v) Config.fflag_auto_load = v end,
})

S.FFlags:AddButton({
    Title = "Set selected as auto",
    Callback = function()
        local selected = savedDropdown.Value
        if not selected or selected == "(no saved profiles)" then
            notify("fflags error", "select a profile first", 4); return
        end
        local ok, content = FFlag.loadProfile(selected)
        if ok then
            Config.fflag_profile = selected; Config.fflag_json = content
            profileInput:SetValue(selected); jsonInput:SetValue(content)
            if autoToggle then autoToggle:SetValue(true) end
            Config.fflag_auto_load = true; saveConfig()
            notify("fflags", "auto load = '" .. selected .. "'", 4)
        else
            notify("fflags error", content, 5)
        end
    end,
})

S.FFlags:AddParagraph({ Title = "Format", Content = '{"FFlagName":"value"}' })

S.FFlags:AddButton({
    Title = "Apply FFlags",
    Callback = function()
        Config.fflag_profile = trim(profileInput.Value)
        Config.fflag_json = jsonInput.Value; saveConfig()
        local ok, msg = FFlag.apply(Config.fflag_json)
        notify(ok and "fflags" or "fflags error", msg, ok and 4 or 6)
    end,
})

if runtimeFFlag then
    task.defer(function()
        notify(runtimeFFlag.ok and "fflags" or "fflags error", runtimeFFlag.message, 5)
    end)
end

--=============================================================
-- [18] UI BINDING — Config
--=============================================================
S.Config:AddButton({
    Title = "Save config",
    Callback = function() saveConfig(); notify("config", "saved", 3) end,
})

S.Config:AddButton({
    Title = "Reset config",
    Callback = function()
        for k, v in pairs(defaults) do Config[k] = v end
        saveConfig(); notify("config", "reset — reload script", 5)
    end,
})

S.Config:AddParagraph({
    Title = "Path",
    Content = storageOK and (DIR .. "/config.json") or "storage unavailable",
})

--=============================================================
-- [19] CLEANUP
--=============================================================
LP.CharacterAdded:Connect(function()
    parryState.debounce = false; parryState.until_at = 0
    Parry.count = 0
    ballState.state.AerodynamicTime = tick()
    ballState.state.LastWarping = tick()
    ballState.state.Curving = tick()
    ballState.state.LerpRadians = 0
end)

Balls.ChildRemoved:Connect(function()
    parryState.debounce = false; parryState.until_at = 0
    Parry.count = 0
    targetMgr.current = nil; targetMgr.visited = {}
end)

--=============================================================
-- [20] STARTUP NOTIFY
--=============================================================
notify("Oxy Premium", "loaded — " .. LP.Name, 5)
