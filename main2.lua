-- ═══════════════════════════════════════════════════════════════
-- SLAX MANUAL CAPTURE — Redz يضغط Block → السكربت يلتقط
-- Author: ALPHA XK | For: Redz | Mobile-Safe
-- ═══════════════════════════════════════════════════════════════

if getgenv()._slax_mc_loaded then
    pcall(function() if _G.slax_mc_unload then _G.slax_mc_unload() end end)
    getgenv()._slax_mc_loaded = nil
    task.wait(0.15)
end
getgenv()._slax_mc_loaded = true

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
    autoParry       = false,   -- بعد الالتقاط، فعل auto
    accuracy        = 100,
    autoSpam        = false,
    autoSpamCPS     = 200,
    triggerBot      = false,
    toggleKey       = "E",
    panicKey        = "END",
}

-- == State ================================================================
local State = {
    running     = true,
    captured    = false,       -- هل تم الالتقاط؟
    remote      = nil,
    method      = nil,
    args        = nil,
    parryCount  = 0,
    lastParry   = 0,
    ping        = 0.06,
    parried     = setmetatable({}, { __mode = "k" }),
}

-- == Remote Capture — Hook واحد خفيف ======================================
local _hookCalls = 0
local _origIndex

_origIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    -- ═══════════════════════════════════════════════
    -- FAST PATH 1: الالتقاط انتهى → لا overhead
    -- ═══════════════════════════════════════════════
    if State.captured then
        return _origIndex(self, key)
    end
    
    -- ═══════════════════════════════════════════════
    -- FAST PATH 2: مو FireServer/InvokeServer
    -- ═══════════════════════════════════════════════
    if key ~= "FireServer" and key ~= "InvokeServer" then
        return _origIndex(self, key)
    end
    
    -- ═══════════════════════════════════════════════
    -- FAST PATH 3: استدعاء من script تبعنا
    -- ═══════════════════════════════════════════════
    if checkcaller() then
        return _origIndex(self, key)
    end
    
    -- ═══════════════════════════════════════════════
    -- SLOW PATH: فقط خلال capture phase
    -- ═══════════════════════════════════════════════
    _hookCalls = _hookCalls + 1
    print("[MC] Hook called #" .. _hookCalls .. " for " .. tostring(key))
    
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
        return _origIndex(self, key)
    end
    
    return function(_, ...)
        local args = { ... }
        
        -- ═══ اطبع كل FireServer لتشوف الـ signature ═══
        print("[MC] FireServer on: " .. self.Name)
        print("[MC] #args: " .. #args)
        for i = 1, math.min(#args, 8) do
            print("[MC]   args[" .. i .. "] = " .. typeof(args[i]) .. ": " .. tostring(args[i]):sub(1, 60))
        end
        
        -- ═══ Signature check ═══
        -- اقبل 7 أو 8 args
        if (#args == 7 or #args == 8)
            and type(args[2]) == "string"       -- UID
            and type(args[3]) == "string"       -- hash
            and type(args[4]) == "number" then  -- token
            
            if not State.captured then
                State.remote = self
                State.method = key
                State.args = args
                State.captured = true
                print("")
                print("════════════════════════════════════")
                print("[MC] ✅ REMOTE CAPTURED!")
                print("[MC] Remote: " .. self.Name)
                print("[MC] Path: " .. self:GetFullName())
                print("[MC] Method: " .. key)
                print("[MC] Args count: " .. #args)
                print("════════════════════════════════════")
                print("")
            end
        end
        
        return _origIndex(self, key)(_, ...)
    end
end))

-- == Fire Function =========================================================
local function fireParry(aim)
    if not State.remote or not State.args then
        warn("[MC] Remote not captured yet")
        return false
    end
    
    local cam = WS.CurrentCamera
    if not cam then return false end
    
    -- aim
    if not aim then
        local vp = cam.ViewportSize
        aim = { math.floor(vp.X / 2), math.floor(vp.Y / 2) }
    end
    
    -- screen positions
    local events = {}
    local alive = WS:FindFirstChild("Alive")
    if alive then
        for _, e in ipairs(alive:GetChildren()) do
            local pp = e.PrimaryPart
            if pp then
                local ok, sp = pcall(cam.WorldToScreenPoint, cam, pp.Position)
                if ok and sp then events[e.Name] = sp end
            end
        end
    end
    
    -- build packet: نفس الـ args الأصلية + تعديلات
    local origArgs = State.args
    local pkt = {}
    
    -- copy all args
    for i = 1, #origArgs do
        pkt[i] = origArgs[i]
    end
    
    -- override: camera CFrame (arg 5), events (arg 6), aim (arg 7)
    pkt[5] = cam.CFrame
    pkt[6] = events
    pkt[7] = aim
    
    local ok = pcall(function()
        if State.method == "FireServer" then
            State.remote:FireServer(unpack(pkt))
        else
            State.remote:InvokeServer(unpack(pkt))
        end
    end)
    
    if ok then
        State.parryCount = State.parryCount + 1
    end
    return ok
end

-- == Ping Cache ===========================================================
task.spawn(function()
    while State.running do
        pcall(function()
            State.ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        task.wait(1)
    end
end)

-- == Auto Parry Loop ======================================================
local lastFrame = tick()

RunService.PreSimulation:Connect(function()
    if not Config.autoParry then return end
    if not State.captured then return end
    
    local now = tick()
    if now - State.lastParry < 0.15 then return end
    
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if hrp:FindFirstChild("SingularityCape") then return end
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    
    local myPos = hrp.Position
    local myName = LP.Name
    
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
        
        -- window بسيط
        local window = 12 + speed * 0.03
        if dist <= window then
            if fireParry() then
                State.parried[ball] = true
                State.lastParry = now
                task.delay(0.4, function()
                    if State.parried[ball] then State.parried[ball] = nil end
                end)
            end
            break
        end
    end
end)

-- == Auto Spam ============================================================
local lastSpam = 0
RunService.PreSimulation:Connect(function()
    if not Config.autoSpam then return end
    if not State.captured then return end
    
    local now = tick()
    local interval = 1 / Config.autoSpamCPS
    if now - lastSpam < interval then return end
    lastSpam = now
    
    local folder = WS:FindFirstChild("Balls")
    if not folder then return end
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:GetAttribute("target") == LP.Name then
            fireParry()
            return
        end
    end
end)

-- == Trigger Bot ==========================================================
local triggerBusy = false
RunService.Heartbeat:Connect(function()
    if not Config.triggerBot then return end
    if not State.captured then return end
    if triggerBusy then return end
    
    local char = LP.Character
    if not char or not char.PrimaryPart then return end
    if char.PrimaryPart:FindFirstChild("SingularityCape") then return end
    
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

-- == Keybinds =============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[Config.toggleKey] then
        fireParry()
    elseif input.KeyCode == Enum.KeyCode[Config.panicKey] then
        Config.autoParry = false
        Config.autoSpam = false
        Config.triggerBot = false
        print("[MC] PANIC")
    end
end)

-- == UI ===================================================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "Slax Manual Capture",
    Icon = "lucide-hand",
    Author = "ALPHA XK",
    Folder = "SlaxMC",
    Size = UDim2.fromOffset(320, 400),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 0,
})

Window:EditOpenButton({
    Title = "MC",
    Icon = "lucide-hand",
    CornerRadius = UDim.new(0, 12),
    StrokeColor = Color3.fromRGB(255, 200, 80),
})

local TabMain = Window:Tab({ Title = "Capture", Icon = "lucide-hand" })
local TabCombat = Window:Tab({ Title = "Combat", Icon = "lucide-sword" })

TabMain:Paragraph({
    Title = "Status",
    Desc = "Not captured — press BLOCK in-game",
})

local statusP = TabMain:Paragraph({
    Title = "Remote",
    Desc = "Waiting for Block press...",
})

TabMain:Button({
    Title = "🔄 Refresh Status",
    Callback = function()
        if State.captured then
            pcall(function() statusP:SetDesc("✅ " .. State.remote.Name .. " | Fired: " .. State.parryCount) end)
        else
            pcall(function() statusP:SetDesc("❌ Not captured — press BLOCK in-game") end)
        end
    end,
})

TabMain:Section({ Title = "Instructions" })

TabMain:Paragraph({
    Title = "How to use",
    Desc = "1. Parry/Block once in-game (press Block button or key)\n2. Watch console for '[MC] REMOTE CAPTURED!'\n3. Toggle Auto Parry ON below\n4. Bot starts working",
})

TabCombat:Toggle({
    Title = "Auto Parry",
    Value = Config.autoParry,
    Callback = function(v)
        Config.autoParry = v
        if v and not State.captured then
            warn("[MC] Capture first — press Block in-game")
        end
    end,
})

TabCombat:Slider({
    Title = "Accuracy 1-100",
    Value = { Min = 1, Max = 100, Default = Config.accuracy, Step = 1 },
    Callback = function(v) Config.accuracy = v end,
})

TabCombat:Toggle({
    Title = "Auto Spam",
    Value = Config.autoSpam,
    Callback = function(v) Config.autoSpam = v end,
})

TabCombat:Slider({
    Title = "Spam CPS",
    Value = { Min = 50, Max = 1000, Default = Config.autoSpamCPS, Step = 50 },
    Callback = function(v) Config.autoSpamCPS = v end,
})

TabCombat:Toggle({
    Title = "Trigger Bot",
    Value = Config.triggerBot,
    Callback = function(v) Config.triggerBot = v end,
})

TabCombat:Section({ Title = "Info" })

TabCombat:Paragraph({
    Title = "Manual Fire",
    Desc = "Press " .. Config.toggleKey .. " to fire parry manually",
})

-- == Init =================================================================
task.spawn(function()
    while State.running and not State.captured do
        task.wait(1)
        if State.captured then
            pcall(function()
                statusP:SetDesc("✅ " .. State.remote.Name)
            end)
            break
        end
    end
end)

print("[MC] Slax Manual Capture loaded")
print("[MC] Step 1: Press BLOCK button in-game (or keyboard block key)")
print("[MC] Step 2: Wait for 'REMOTE CAPTURED' message")
print("[MC] Step 3: Toggle Auto Parry ON")

-- == Unload ===============================================================
_G.slax_mc_unload = function()
    State.running = false
    getgenv()._slax_mc_loaded = nil
end
