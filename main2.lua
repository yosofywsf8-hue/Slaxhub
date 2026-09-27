-- ═══════════════════════════════════════════════════════════════════════════
-- ███████╗██╗      █████╗ ██╗  ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗
-- ██╔════╝██║     ██╔══██╗╚██╗██╔╝    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║
-- ███████╗██║     ███████║ ╚███╔╝     ██║     ██║     █████╗  ███████║██╔██╗ ██║
-- ╚════██║██║     ██╔══██║ ██╔██╗     ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║
-- ███████║███████╗██║  ██║██╔╝ ██╗    ╚██████╗███████╗███████╗██║  ██║██║ ╚████║
-- ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝     ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝
--
-- SLAX CLEAN — Blade Ball Auto Parry (Anti-Crash Edition)
-- Author: ALPHA XK | For: Redz
-- Design:
--   * Token via getgc — مرة واحدة، chunked
--   * Remote capture — hook مرة واحدة على per-remote metatable
--   * Auto parry — يرسل فقط لما ball يقترب فعلياً
--   * Rate limit — 6-8 fire/sec max
--   * No spam، no BAC bypass، no zero-capture، no fusion
-- ═══════════════════════════════════════════════════════════════════════════

-- == Load Guard ============================================================
if getgenv()._slax_clean_loaded then
    pcall(function() if _G.slax_clean_unload then _G.slax_clean_unload() end end)
    getgenv()._slax_clean_loaded = nil
    task.wait(0.2)
end
getgenv()._slax_clean_loaded = true

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
    accuracy        = 100,          -- 1..100
    parryCooldown   = 0.15,          -- ثواني بين parry و parry
    maxRange        = 18,            -- studs (بس لو ball قريب)
    toggleKey       = "E",
    panicKey        = "END",
    debugMode       = false,
}

-- == State ================================================================
local State = {
    running         = true,
    captured        = false,
    remote          = nil,
    method          = nil,
    args            = nil,
    token           = nil,
    tokenOK         = false,
    parried         = setmetatable({}, { __mode = "k" }),
    lastParry       = 0,
    parryCount      = 0,
    ping            = 0.06,
    aliveFolder     = nil,
    lastAliveCheck  = 0,
}

-- == Token Retrieval — chunked، خفيف ======================================
local function findToken()
    if not (getgc and debug and debug.getupvalues and debug.info) then
        return nil
    end
    
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
        ok, gc = pcall(getgc, false)
    end
    if not ok or type(gc) ~= "table" then return nil end
    
    local n = #gc
    if n == 0 then return nil end
    
    for i = 1, n do
        local fn = gc[i]
        if type(fn) ~= "function" then continue end
        
        local ok2, name = pcall(debug.info, fn, 's')
        if not ok2 or not name then continue end
        if not tostring(name):find('PRY', 1, true) then continue end
        
        local ok3, ups = pcall(debug.getupvalues, fn)
        if not ok3 or type(ups) ~= "table" then continue end
        
        for _, v in ipairs(ups) do
            if type(v) == "function" then
                return v
            end
        end
    end
    
    return nil
end

print("[SlaxClean] Scanning for token...")
State.token = findToken()

if State.token then
    State.tokenOK = true
    print("[SlaxClean] ✅ Token found")
else
    warn("[SlaxClean] Token not found — retrying in background")
    task.spawn(function()
        local deadline = tick() + 30
        while tick() < deadline and not State.tokenOK do
            task.wait(2)
            State.token = findToken()
            if State.token then
                State.tokenOK = true
                print("[SlaxClean] ✅ Token found (late)")
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

-- == Remote Hook — per-remote metatable (خفيف) ============================
local _hooked = setmetatable({}, { __mode = "k" })
local _capturedArgs = nil

local function isValidArgs(args)
    if type(args) ~= "table" then return false end
    if #args ~= 8 then return false end
    if type(args[2]) ~= "string" then return false end
    if type(args[3]) ~= "string" then return false end
    if type(args[4]) ~= "number" then return false end
    if typeof(args[5]) ~= "CFrame" then return false end
    if type(args[6]) ~= "table" then return false end
    if type(args[7]) ~= "table" then return false end
    if type(args[8]) ~= "boolean" then return false end
    return true
end

local function hookRemote(remote)
    if _hooked[remote] then return end
    
    local meta
    local ok, m = pcall(getrawmetatable, remote)
    if ok and m then meta = m end
    if not meta then
        local ok2, m2 = pcall(getmetatable, remote)
        if ok2 and m2 then meta = m2 end
    end
    if not meta then return end
    
    _hooked[remote] = true
    
    local oldIndex = meta.__index
    pcall(setreadonly, meta, false)
    
    meta.__index = function(self, key)
        -- Fast path: مو FireServer/InvokeServer
        if key ~= 'FireServer' and key ~= 'InvokeServer' then
            return oldIndex(self, key)
        end
        if self ~= remote then
            return oldIndex(self, key)
        end
        
        local original = oldIndex(self, key)
        if type(original) ~= "function" then
            return original
        end
        
        return function(_, ...)
            local a = {...}
            if not State.captured and isValidArgs(a) then
                State.remote = self
                State.method = key
                State.args = a
                State.captured = true
                print("[SlaxClean] ✅ Remote captured: " .. self.Name)
                print("[SlaxClean]    Args count: " .. #a)
            end
            return original(_, ...)
        end
    end
    
    pcall(setreadonly, meta, true)
end

-- hook كل الـ remotes الموجودة حالياً
for _, r in ipairs(RS:GetDescendants()) do
    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
        hookRemote(r)
    end
end

-- hook الـ remotes اللي تجي لاحقاً (بس بـ connection واحد، مو loop)
RS.DescendantAdded:Connect(function(r)
    if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
        hookRemote(r)
    end
end)

-- == Alive Folder (cached) ================================================
local function getAlive()
    local now = tick()
    if now - State.lastAliveCheck > 2 then
        State.aliveFolder = WS:FindFirstChild("Alive")
        State.lastAliveCheck = now
    end
    return State.aliveFolder
end

-- == Ping Cache — كل ثانية ================================================
task.spawn(function()
    while State.running do
        pcall(function()
            local raw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            State.ping = math.clamp(raw / 1000, 0.02, 0.30)
        end)
        task.wait(1)
    end
end)

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

-- == Fire Parry — مرة واحدة، مع cache =====================================
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
        State.args[1],
        uid,
        tokenize(uid),
        0.5,
        cam.CFrame,
        {},
        aim,
        false
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

-- == Auto Parry Loop — rate-limited =======================================
local lastFrame = tick()

RunService.PreSimulation:Connect(function()
    if not Config.enabled then return end
    if not State.captured then return end
    
    local now = tick()
    if now - State.lastParry < Config.parryCooldown then return end
    
    local alive, char, hrp = isAlive()
    if not alive then return end
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    
    local myPos = hrp.Position
    local myName = LP.Name
    local best = nil
    local bestDist = math.huge
    
    -- فحص كل ball
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
        
        -- ping compensation
        local t = State.ping / 2
        local predPos = ball.Position + vel * t
        local dist = (myPos - predPos).Magnitude
        
        -- window بناء على السرعة + accuracy
        local accMul = 0.7 + (math.clamp(Config.accuracy, 1, 100) - 1) * 0.0035
        local baseWindow = Config.maxRange * accMul
        local speedFactor = math.min(speed * 0.03, 15)
        local window = baseWindow + speedFactor
        
        if dist <= window then
            if dist < bestDist then
                best = ball
                bestDist = dist
            end
        end
    end
    
    if best then
        local cam = WS.CurrentCamera
        local aim
        if cam then
            local z = best:FindFirstChild("zoomies")
            if z then
                local sp = cam:WorldToScreenPoint(best.Position)
                if sp then aim = { math.floor(sp.X), math.floor(sp.Y) } end
            end
        end
        
        if fireParry(aim) then
            State.parried[best] = true
            State.lastParry = now
            task.delay(0.5, function()
                if State.parried[best] then State.parried[best] = nil end
            end)
        end
    end
end)

-- == Keybinds =============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        Config.enabled = not Config.enabled
        print("[SlaxClean]", Config.enabled and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.enabled = false
        print("[SlaxClean] PANIC")
    end
end)

-- == UI — بسيط ============================================================
local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"
    ))()
end)

if ok and WindUI then
    local Window = WindUI:CreateWindow({
        Title = "Slax Clean",
        Icon = "lucide-feather",
        Author = "ALPHA XK",
        Folder = "SlaxClean",
        Size = UDim2.fromOffset(320, 380),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 0,
    })
    
    Window:EditOpenButton({
        Title = "Clean",
        Icon = "lucide-feather",
        CornerRadius = UDim.new(0, 12),
        StrokeColor = Color3.fromRGB(80, 200, 120),
    })
    
    local Tab = Window:Tab({ Title = "Combat", Icon = "lucide-sword" })
    
    Tab:Toggle({
        Title = "Auto Parry",
        Desc = "يشتغل فقط لما ball يستهدفك ويقترب",
        Value = Config.enabled,
        Callback = function(v) Config.enabled = v end,
    })
    
    Tab:Slider({
        Title = "Accuracy 1-100",
        Value = { Min = 1, Max = 100, Default = Config.accuracy, Step = 1 },
        Callback = function(v) Config.accuracy = v end,
    })
    
    Tab:Slider({
        Title = "Parry Cooldown (ms)",
        Value = { Min = 80, Max = 500, Default = 150, Step = 10 },
        Callback = function(v) Config.parryCooldown = v / 1000 end,
    })
    
    Tab:Section({ Title = "Info" })
    
    Tab:Paragraph({
        Title = "Token",
        Desc = State.tokenOK and "✅ Found" or "⏳ Searching...",
    })
    
    Tab:Paragraph({
        Title = "Remote",
        Desc = State.captured and ("✅ " .. State.remote.Name) or "⏳ Parry once in-game",
    })
    
    Tab:Paragraph({
        Title = "Parries",
        Desc = "0",
    })
else
    warn("[SlaxClean] WindUI failed — script running headless")
end

-- == Init =================================================================
print("[SlaxClean] Loaded")
print("[SlaxClean] Toggle: " .. Config.toggleKey .. " | Panic: " .. Config.panicKey)
if not State.captured then
    print("[SlaxClean] Parry once in-game to capture remote")
end

-- == Unload ===============================================================
_G.slax_clean_unload = function()
    State.running = false
    getgenv()._slax_clean_loaded = nil
    print("[SlaxClean] Unloaded")
end
