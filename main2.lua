-- ============================================================
-- OXY V2 FULL RESTORATION (PREMIUM UI)
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- تحميل واجهة Fluent
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Oxy | Premium V2",
    SubTitle = "Absolute Restoration",
    TabWidth = 150,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Inventory = Window:AddTab({ Title = "Inventory", Icon = "box" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings" }),
}

-- ============================================================
-- 1. CORE VARIABLES & SERVICES
-- ============================================================
local Config = {
    AutoParry = false,
    Accuracy = 100,
    RandomTarget = false,
    AutoSpam = false,
    UnlockAll = false,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local Balls = Workspace:WaitForChild("Balls")
local Alive = Workspace:WaitForChild("Alive")
local Runtime = Workspace:WaitForChild("Runtime")
local LocalName = LocalPlayer.Name
local DataPing = Stats.Network.ServerStatsItem["Data Ping"]

local TokenFn = nil
local EventCapture = { Captured = {}, Hooked = {}, Originals = {}, TokenFn = nil }
local BallState = { Positions = {}, State = { AerodynamicTime = tick(), LastWarping = tick(), LerpRadians = 0, Curving = tick() } }
local ParryState = { Debounce = false, Until = 0, Accuracy = 1.5 }
local ParryController = { Count = 0, FirstSignal = nil }
local SwordAnimationState = { Active = nil, Cache = {}, Tracks = {}, API = nil, Generation = 0, LastSpam = 0, CancelDelay = 0.12, CancelFraction = 0.35 }
local InventoryUnlockManager = { Current = nil, Visited = {} }

-- ============================================================
-- 2. TOKEN & HOOK (BYPASS)
-- ============================================================
for _, fn in getgc(true) do
    if type(fn) == "function" and debug.info(fn, "s"):find("PRY", 1, true) then
        for _, upval in debug.getupvalues(fn) do
            if type(upval) == "function" then
                TokenFn = upval
                break
            end
        end
    end
    if TokenFn then break end
end

local function Tokenize(data)
    if not TokenFn then return data end
    local timeStr = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local secret = TokenFn(data, "TIME")
    local out = {}
    for i = 1, #timeStr do
        out[i] = string.char(bit32.bxor((string.byte(timeStr, i) + i) % 256, string.byte(secret, (i - 1) % #secret + 1)))
    end
    return table.concat(out)
end

local function HookRemote(remote)
    local mt = getrawmetatable(remote)
    if EventCapture.Hooked[mt] then return end
    EventCapture.Hooked[mt] = true
    setreadonly(mt, false)
    local oldIndex = mt.__index
    EventCapture.Originals[mt] = oldIndex
    mt.__index = function(self, key)
        if key == "FireServer" and self:IsA("RemoteEvent") then
            return function(obj, ...)
                local args = {...}
                if #args == 8 and typeof(args[5]) == "CFrame" and type(args[6]) == "table" then
                    EventCapture.Captured[self] = args
                end
                return oldIndex(obj, key)(obj, ...)
            end
        end
        return oldIndex(self, key)
    end
    setreadonly(mt, true)
end

for _, obj in ReplicatedStorage:GetDescendants() do
    if obj:IsA("RemoteEvent") then pcall(HookRemote, obj) end
end

-- ============================================================
-- 3. OXY FUNCTIONS (PARRY, SPAM, ANIMATION)
-- ============================================================
local function FireParry()
    if not EventCapture.TokenFn then return end
    local Camera = Workspace.CurrentCamera
    
    if Config.RandomTarget then
        InventoryUnlockManager.Closest()
    else
        InventoryUnlockManager.ByMouse()
    end
    
    local targetPos = {}
    local mousePos = {UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y}
    
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position or Vector3.zero
    if InventoryUnlockManager.Current and InventoryUnlockManager.Current.PrimaryPart then
        local sp = Camera:WorldToViewportPoint(InventoryUnlockManager.Current.PrimaryPart.Position)
        targetPos = {sp.X, sp.Y}
    end
    
    if next(EventCapture.Captured) == nil then
        if not ParryController.FirstSignal then
            local s, PRY = pcall(function() return require(ReplicatedStorage.Controllers["SwordsController \12"].PRY) end)
            if s then
                ParryController.FirstSignal = require(ReplicatedStorage.Packages.Signal).new()
                ParryController.FirstSignal:Connect(PRY)
            end
        end
        if ParryController.FirstSignal then
            ParryController.FirstSignal:Fire(0.5, Camera.CFrame, targetPos, mousePos, false)
        end
    else
        for remote, args in pairs(EventCapture.Captured) do
            local newArgs = {args[1], args[2], Tokenize(args[2]), 0.5, Camera.CFrame, targetPos, mousePos, false}
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(newArgs))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(newArgs))
            end
        end
    end
    ParryController.Count = ParryController.Count + 1
    task.delay(0.5, function() ParryController.Count = math.max(0, ParryController.Count - 1) end)
end

local function SwordGrab(isSpam)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    local swordName = char:GetAttribute("CurrentlyEquippedSword") or "Base Sword"
    local anim = SwordAnimationState.Resolve(char, swordName)
    if not anim then return end
    
    local track = SwordAnimationState.Tracks[animator] and SwordAnimationState.Tracks[animator][anim]
    if not track or not track.Parent then
        local s, t = pcall(function() return animator:LoadAnimation(anim) end)
        if not s or not t then return end
        t.Priority = Enum.AnimationPriority.Action4
        SwordAnimationState.Tracks[animator] = SwordAnimationState.Tracks[animator] or {}
        SwordAnimationState.Tracks[animator][anim] = t
        track = t
    end
    track.TimePosition = 0
    track:Play(0.05, 1, 1)
    SwordAnimationState.Active = track
end

-- ============================================================
-- 4. BALL PREDICTION
-- ============================================================
local function GetBall() 
    for _, v in Balls:GetChildren() do if v:GetAttribute("realBall") then return v end end 
end

local function IsCurved(ball)
    if not ball then return false end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end
    local now = tick()
    local ping = DataPing:GetValue()
    local vel = zoomies.VectorVelocity
    local unit = vel.Unit
    local myPos = LocalPlayer.Character.PrimaryPart.Position
    local bPos = BallState.Positions[ball] or ball.Position
    local dir = (myPos - bPos).Unit
    local dot = dir:Dot(unit)
    local speed = vel.Magnitude
    local dist = (myPos - bPos).Magnitude
    
    local extra = math.min(speed / 100, 40)
    local threshold = 0.5 - ping / 1000
    local timeThreshold = dist / speed - ping / 1000
    local safeDist = 15 - math.min(dist / 1000, 15) + extra
    
    if speed > 100 and timeThreshold > ping / 10 then safeDist = math.max(safeDist - 15, 15) end
    if dist < safeDist then return false end
    if dot < threshold then return true end
    if now - BallState.State.LastWarping < timeThreshold / 1.5 then return true end
    if now - BallState.State.Curving < timeThreshold / 1.5 then return true end
    return dot < threshold
end

-- ============================================================
-- 5. MAIN LOOP
-- ============================================================
RunService.PostSimulation:Connect(function()
    if not Config.AutoParry then return end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end
    local now = tick()
    if ParryState.Debounce or now < ParryState.Until then return end
    
    local myPos = char.PrimaryPart.Position
    local pingDist = math.clamp(DataPing:GetValue() / 10 / 10, 5, 17)
    local ball = GetBall()
    local targetAttr = ball and ball:GetAttribute("target")
    
    for _, b in Balls:GetChildren() do
        if not b then continue end
        local zoomies = b:FindFirstChild("zoomies")
        if not zoomies then continue end
        
        local bTarget = b:GetAttribute("target")
        local speed = zoomies.VectorVelocity.Magnitude
        local dist = (myPos - (BallState.Positions[b] or b.Position)).Magnitude
        local calcA = (2.4 + math.min(math.max(speed - 9.5, 0), 650) * 0.002) * ParryState.Accuracy
        
        if b:FindFirstChild("AeroDynamicSlashVFX") then
            game:GetService("Debris"):AddItem(b.AeroDynamicSlashVFX, 0)
            BallState.State.AerodynamicTime = now
        end
        if Workspace.Runtime:FindFirstChild("Tornado") and now - BallState.State.AerodynamicTime < (Workspace.Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159 then return end
        if targetAttr == LocalName and IsCurved(b) then return end
        
        if bTarget == LocalName and dist <= pingDist + math.max(speed / calcA, 9.5) then
            FireParry()
            SwordGrab(true)
            ParryState.Debounce = true
            ParryState.Until = now + 1
        end
    end
end)

-- ============================================================
-- 6. UI BINDINGS
-- ============================================================
local CombatSec = Tabs.Combat:AddSection("Combat")

CombatSec:AddToggle("AutoParry", {
    Title = "Auto Parry [Oxy Core]",
    Default = Config.AutoParry,
    Callback = function(state)
        Config.AutoParry = state
        Fluent:Notify({ Title = "Oxy Premium", Content = "Auto-Parry: " .. (state and "ON" or "OFF"), Duration = 3 })
    end
})

CombatSec:AddSlider("Accuracy", {
    Title = "Accuracy",
    Min = 1, Max = 100, Default = Config.Accuracy, Rounding = 0,
    Callback = function(val)
        ParryState.Accuracy = (val - 1) * 0.015151515151515152
    end
})

CombatSec:AddToggle("RandomTarget", {
    Title = "Random Target",
    Default = Config.RandomTarget,
    Callback = function(state) Config.RandomTarget = state end
})

Tabs.Misc:AddParagraph({
    Title = "Oxy Premium V2",
    Content = "Full Restoration.\nPredictive TTI Enabled."
})

Fluent:Notify({ Title = "Oxy V2", Content = "Loaded Successfully.", Duration = 5 })
