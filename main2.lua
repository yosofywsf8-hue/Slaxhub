-- ============================================================
-- OXY AUTHENTIC REBUILD (DRAWING UI + ORIGINAL LOGIC)
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- 1. CUSTOM UI (DRAWING API)
-- ============================================================
local OxyUI = Instance.new("ScreenGui")
OxyUI.Name = "OxyCustomUI"
OxyUI.ResetOnSpawn = false
OxyUI.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 250)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = OxyUI

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 10)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TopBar.BorderSizePixel = 0
local TopCorner = Instance.new("UICorner", TopBar)
TopCorner.CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -10, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Oxy | Rebuild"
Title.TextColor3 = Color3.fromRGB(170, 0, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(1, -40, 0, 40)
ToggleBtn.Position = UDim2.new(0, 20, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ToggleBtn.Text = "Auto Parry: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
local BtnCorner = Instance.new("UICorner", ToggleBtn)
BtnCorner.CornerRadius = UDim.new(0, 5)

local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.Size = UDim2.new(1, -40, 0, 20)
StatusLbl.Position = UDim2.new(0, 20, 0, 110)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Initializing..."
StatusLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 12
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================
-- 2. ORIGINAL OXY LOGIC (EVENT CAPTURE & TOKEN BYPASS)
-- ============================================================
local Runtime = {}
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local Balls = workspace:WaitForChild("Balls")
local Alive = workspace:WaitForChild("Alive")
local LocalName = LocalPlayer.Name

local ParryConnections = {}
local PlayParry = nil
local SwordFn = nil

if Remotes and type(getconnections) == "function" then
    local ParrySuccessAll = Remotes:WaitForChild("ParrySuccessAll", 10)
    if ParrySuccessAll then
        local success, conns = pcall(getconnections, ParrySuccessAll.OnClientEvent)
        if success and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                local s, func = pcall(function() return conn.Function end)
                if s and type(func) == "function" then
                    table.insert(ParryConnections, conn)
                    PlayParry = func
                end
            end
        end
    end
    local FireSwordInfo = Remotes:WaitForChild("FireSwordInfo", 10)
    if FireSwordInfo then
        local success, conns = pcall(getconnections, FireSwordInfo.OnClientEvent)
        if success and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                local s, func = pcall(function() return conn.Function end)
                if s and type(func) == "function" then
                    SwordFn = func
                end
            end
        end
    end
end

local EventCapture = { Captured = {}, Hooked = {}, Originals = {}, TokenFn = nil }

for _, fn in getgc(true) do
    if type(fn) == "function" and debug.info(fn, "s"):find("PRY", 1, true) then
        for _, upval in debug.getupvalues(fn) do
            if type(upval) == "function" then
                EventCapture.TokenFn = upval
                break
            end
        end
        if EventCapture.TokenFn then break end
    end
end

EventCapture.Tokenize = function(data)
    if not EventCapture.TokenFn then return data end
    local timeStr = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local secret = EventCapture.TokenFn(data, "TIME")
    local out = {}
    for i = 1, #timeStr do
        out[i] = string.char(bit32.bxor((string.byte(timeStr, i) + i) % 256, string.byte(secret, (i - 1) % #secret + 1)))
    end
    return table.concat(out)
end

EventCapture.Hook = function(remote)
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
    if obj:IsA("RemoteEvent") then
        pcall(EventCapture.Hook, obj)
    end
end

-- ============================================================
-- 3. CORE PARRY FUNCTION
-- ============================================================
local ParryController = { Count = 0, FirstSignal = nil }
local Config = { AutoParry = false, Accuracy = 100 }

local function FireParry()
    if not EventCapture.TokenFn then return end
    local Camera = workspace.CurrentCamera
    local Target = nil
    for _, v in Alive:GetChildren() do
        if v.Name ~= LocalName and v.PrimaryPart then
            Target = v
            break
        end
    end
    
    local ScreenPos = {}
    local MousePos = {Mouse.X, Mouse.Y}
    
    for _, v in Alive:GetChildren() do
        if v.PrimaryPart then
            local sp = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
            if sp.Z > 0 then ScreenPos[v.Name] = sp end
        end
    end

    if next(EventCapture.Captured) == nil then
        if not ParryController.FirstSignal then
            -- Fallback if PRY controller is not found
            local success, PRY = pcall(function() return require(ReplicatedStorage.Controllers["SwordsController \12"].PRY) end)
            if success then
                ParryController.FirstSignal = require(ReplicatedStorage.Packages.Signal).new()
                ParryController.FirstSignal:Connect(PRY)
            end
        end
        if ParryController.FirstSignal then
            ParryController.FirstSignal:Fire(0.5, Camera.CFrame, ScreenPos, MousePos, false)
        end
    else
        for remote, args in pairs(EventCapture.Captured) do
            local newArgs = {
                args[1],
                args[2],
                EventCapture.Tokenize(args[2]),
                0.5,
                Camera.CFrame,
                ScreenPos,
                MousePos,
                false
            }
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(newArgs))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(newArgs))
            end
        end
    end
end

-- ============================================================
-- 4. BALL PREDICTION & TRIGGER LOOP
-- ============================================================
local BallState = { Positions = {}, State = { LastWarping = tick(), Curving = tick() } }
local Replicator = nil

local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("_Index") and ReplicatedStorage.Packages._Index:FindFirstChild("sleitnick_net@0.1.0") and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"]:FindFirstChild("net")
if net then
    for _, v in net:GetChildren() do
        if v:IsA("UnreliableRemoteEvent") and v.Name ~= "URE/ReplicateBallPosition" then
            Replicator = v
            break
        end
    end
end

if Replicator then
    Replicator.OnClientEvent:Connect(function(ball, pos)
        if ball and ball.Parent == Balls and ball:GetAttribute("realBall") then
            BallState.Positions[ball] = pos
        end
    end)
end

local function GetBall()
    for _, v in Balls:GetChildren() do
        if v:GetAttribute("realBall") then return v end
    end
    return nil
end

local function GetBallPos(ball)
    if ball then return BallState.Positions[ball] or ball.Position end
    return Vector3.zero
end

local function IsCurved(ball)
    local b = ball or GetBall()
    if b then
        local zoomies = b:FindFirstChild("zoomies")
        if not zoomies then return false end
        local now = tick()
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        local vel = zoomies.VectorVelocity
        local unit = vel.Unit
        local myPos = LocalPlayer.Character.PrimaryPart.Position
        local bPos = GetBallPos(b)
        local dir = (myPos - bPos).Unit
        local dot = dir:Dot(unit)
        local speed = vel.Magnitude
        local dist = (myPos - bPos).Magnitude
        
        local extra = math.min(speed / 100, 40)
        local threshold = 0.5 - ping / 1000
        local timeThreshold = dist / speed - ping / 1000
        local safeDist = 15 - math.min(dist / 1000, 15) + extra
        
        if speed > 100 and timeThreshold > ping / 10 then
            safeDist = math.max(safeDist - 15, 15)
        end
        if dist < safeDist then return false end
        if dot < threshold then return true end
        if now - BallState.State.LastWarping < timeThreshold / 1.5 then return true end
        if now - BallState.State.Curving < timeThreshold / 1.5 then return true end
        return dot < threshold
    end
    return false
end

-- ============================================================
-- 5. MAIN LOOP (OXY LOGIC)
-- ============================================================
local ParryDebounce = false
local ParryUntil = 0
local AccuracyMult = 1

RunService.PostSimulation:Connect(function()
    if not Config.AutoParry then return end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end
    
    local now = tick()
    if ParryDebounce or now < ParryUntil then return end
    
    local myPos = char.PrimaryPart.Position
    local pingDist = math.clamp(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 10 / 10, 5, 17)
    local targetAttr = GetBall()
    targetAttr = targetAttr and targetAttr:GetAttribute("target")
    
    for _, ball in Balls:GetChildren() do
        if not ball then continue end
        local zoomies = ball:FindFirstChild("zoomies")
        if not zoomies then continue end
        
        local bTarget = ball:GetAttribute("target")
        local speed = zoomies.VectorVelocity.Magnitude
        local dist = (myPos - GetBallPos(ball)).Magnitude
        
        local aero = 0.002
        local calcA = (2.4 + math.min(math.max(speed - 9.5, 0), 650) * aero) * AccuracyMult
        
        if ball:FindFirstChild("AeroDynamicSlashVFX") then
            game:GetService("Debris"):AddItem(ball.AeroDynamicSlashVFX, 0)
            BallState.State.AerodynamicTime = now
        end
        
        local tornado = workspace:FindFirstChild("Runtime") and workspace.Runtime:FindFirstChild("Tornado")
        local tornadoTime = tornado and (tornado:GetAttribute("TornadoTime") or 1)
        if tornado and now - BallState.State.AerodynamicTime < tornadoTime + 0.314159 then
            continue
        end
        
        if targetAttr == LocalName and IsCurved(ball) then
            continue
        end
        
        if bTarget == LocalName and dist <= pingDist + math.max(speed / calcA, 9.5) then
            FireParry()
            ParryDebounce = true
            ParryUntil = now + 1
        end
    end
end)

-- UI Interactivity
ToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoParry = not Config.AutoParry
    ToggleBtn.Text = "Auto Parry: " .. (Config.AutoParry and "ON" or "OFF")
    ToggleBtn.TextColor3 = Config.AutoParry and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 255, 255)
    StatusLbl.Text = "Status: Active"
end)

StatusLbl.Text = "Status: Loaded & Hooked"
