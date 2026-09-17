--[[
    Advanced Blade Ball Auto-Parry for Mobile (Delta, Arceus X)
    Features:
    - Dynamic Auto-Parry with Velocity Prediction & Ping Compensation
    - Timebomb Mode Support
    - Human-Like Touch Simulation (No Remote Firing)
    - Randomized Jitter for Undetectability
    - Telemetry & FPS Optimization
    - Self-Contained, Robust, and Commented
]]

-- ========================================================
-- 1. SERVICES & INITIALIZATION
-- ========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ========================================================
-- 2. CONFIGURATION & STATE
-- ========================================================
local CONFIG = {
    -- Auto-Parry
    ENABLED = true,
    PARRY_COOLDOWN = 0.15, -- Minimum time between parries (seconds)
    PREDICTION_MULTIPLIER = 1.0, -- Adjusts how early to parry (1.0 = neutral)
    PING_SMOOTHING = 5, -- Number of ping samples to average
    MAX_PARRY_DISTANCE = 150, -- Max distance (studs) to consider a ball
    
    -- Timebomb
    TIMEBOMB_ENABLED = true,
    TIMEBOMB_SAFE_DISTANCE = 30, -- Distance to avoid false parries in Timebomb
    
    -- Anti-Detection
    JITTER_MIN = 0.001, -- 1ms
    JITTER_MAX = 0.005, -- 5ms
    
    -- Performance
    FPS_CAP = 120,
}

local State = {
    isEnabled = CONFIG.ENABLED,
    lastParryTime = 0,
    pingHistory = {},
    watchedBalls = {},
}

-- ========================================================
-- 3. PING COMPENSATION ENGINE
-- ========================================================
-- Retrieves the current server ping in milliseconds
local function GetCurrentPing()
    local success, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and value or 0
end

-- Returns a smoothed average of recent ping samples
local function GetSmoothedPing()
    local ping = GetCurrentPing()
    table.insert(State.pingHistory, ping)
    while #State.pingHistory > CONFIG.PING_SMOOTHING do
        table.remove(State.pingHistory, 1)
    end
    if #State.pingHistory == 0 then return 0 end
    
    local sum = 0
    for _, p in ipairs(State.pingHistory) do
        sum = sum + p
    end
    return sum / #State.pingHistory
end

-- Calculates a dynamic parry delay based on current ping
local function CalculateParryDelay()
    local ping = GetSmoothedPing()
    -- Base delay: 100ms. Ping adds to the reaction time.
    -- The game's parry window is roughly 100-150ms.
    -- We aim to parry slightly before the ball arrives.
    local baseDelay = 0.100
    local pingDelay = (ping / 1000) * 0.5 -- Half of ping as a safety margin
    return math.max(0.05, baseDelay - pingDelay) -- Never less than 50ms
end

-- ========================================================
-- 4. HUMAN-LIKE INPUT SIMULATION
-- ========================================================
-- Simulates a mouse click/tap without firing the game's remote directly
local function SimulateParryInput()
    -- Using VirtualInputManager for a more native-like interaction
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(math.random(CONFIG.JITTER_MIN * 1000, CONFIG.JITTER_MAX * 1000) / 1000)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

-- Wrapper for parry with cooldown and jitter
local function ExecuteParry()
    if not State.isEnabled then return end
    local now = tick()
    if now - State.lastParryTime < CONFIG.PARRY_COOLDOWN then return end
    
    State.lastParryTime = now
    SimulateParryInput()
end

-- ========================================================
-- 5. BALL WATCHER & PREDICTION
-- ========================================================
-- Checks if the ball is targeting the local player
local function IsTargetingPlayer(ball)
    return ball:GetAttribute("target") == LocalPlayer.Name or 
           (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Highlight"))
end

-- Estimates time to impact using distance and velocity
local function TimeToImpact(ball)
    if not LocalPlayer.Character then return math.huge end
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return math.huge end
    
    local distance = (ball.Position - rootPart.Position).Magnitude
    local velocity = ball.AssemblyLinearVelocity.Magnitude
    if velocity < 1 then return math.huge end
    
    return distance / velocity
end

-- Main logic for watching a ball
local function WatchBall(ball)
    if not ball:IsA("BasePart") or ball:GetAttribute("realBall") ~= true then return end
    if State.watchedBalls[ball] then return end
    State.watchedBalls[ball] = true
    
    -- Cleanup when ball is removed
    ball.AncestryChanged:Connect(function(_, parent)
        if not parent then
            State.watchedBalls[ball] = nil
        end
    end)
    
    -- Predictive parry loop
    task.spawn(function()
        while ball.Parent and State.isEnabled do
            if IsTargetingPlayer(ball) then
                local tImpact = TimeToImpact(ball)
                local delay = CalculateParryDelay()
                
                -- Timebomb logic: If in Timebomb mode, avoid parrying too early if ball is close
                if CONFIG.TIMEBOMB_ENABLED and tImpact < (CONFIG.TIMEBOMB_SAFE_DISTANCE / ball.AssemblyLinearVelocity.Magnitude) then
                    -- Do nothing, let the ball come closer or let another player handle it
                else
                    -- If time to impact is less than our calculated delay, PARRY!
                    if tImpact <= delay then
                        ExecuteParry()
                        -- Break the loop for this ball after a successful parry attempt
                        task.wait(CONFIG.PARRY_COOLDOWN)
                    end
                end
            end
            task.wait() -- Yield to prevent freezing
        end
    end)
end

-- ========================================================
-- 6. ANTI-DETECTION & TELEMETRY
-- ========================================================
local function ApplyAntiDetection()
    -- Randomized delay for a more human-like reaction
    local function RandomJitter()
        return math.random(CONFIG.JITTER_MIN * 1000, CONFIG.JITTER_MAX * 1000) / 1000
    end
    
    -- Disable Roblox telemetry (as per available FFlags)
    pcall(function()
        if setfflag then
            setfflag("FFlagDebugDisableTelemetryV2Counter", "True")
            setfflag("FFlagDebugDisableTelemetryV2Event", "True")
            setfflag("FFlagDebugDisableTelemetryV2Stat", "True")
        end
    end)
    
    -- Simple detection bypass by blocking known anti-cheat remotes (example)
    -- NOTE: This is a basic implementation. Advanced bypasses require more complex hooking.
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("anticheat") or obj.Name:lower():find("detect")) then
            pcall(function()
                obj:Destroy() -- Simple destruction, may not always work
            end)
        end
    end
end

-- ========================================================
-- 7. FPS & PERFORMANCE OPTIMIZATION
-- ========================================================
local function OptimizePerformance()
    -- 1. Lighting
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 2
    end)
    
    -- 2. Workspace Objects
    local function OptimizeObject(obj)
        if obj == LocalPlayer.Character then return end -- Skip own character
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            if obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                -- Keep crucial parts visible, but reduce complexity
            else
                obj.Transparency = 0.7 -- Slight transparency to reduce overdraw
            end
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj.Enabled = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1 -- Hide decals/textures
        elseif obj:IsA("Sky") then
            obj.Parent = nil -- Remove skybox
        elseif obj:IsA("PostEffect") then
            obj.Enabled = false -- Disable blur, bloom, etc.
        end
    end
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        pcall(OptimizeObject, obj)
    end
    
    -- 3. Handle new objects
    Workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.1) -- Small delay to avoid performance hits on spawn
        pcall(OptimizeObject, obj)
    end)
    
    -- 4. FPS Cap (Safe method using FFlag if available)
    pcall(function()
        if setfflag then
            setfflag("DFIntTaskSchedulerTargetFps", tostring(CONFIG.FPS_CAP))
        end
    end)
end

-- ========================================================
-- 8. MOBILE UI OVERLAY
-- ========================================================
local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BladeBallAutoParryUI"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 160, 0, 80)
    frame.Position = UDim2.new(0, 10, 0.4, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "Auto Parry"
    title.TextColor3 = Color3.fromRGB(0, 255, 100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 25)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: " .. (State.isEnabled and "ON" or "OFF")
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.Parent = frame
    
    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.9, 0, 0, 25)
    toggleBtn.Position = UDim2.new(0.05, 0, 0, 50)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.Text = "Toggle"
    toggleBtn.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn
    
    -- Toggle Logic
    toggleBtn.MouseButton1Click:Connect(function()
        State.isEnabled = not State.isEnabled
        statusLabel.Text = "Status: " .. (State.isEnabled and "ON" or "OFF")
        toggleBtn.BackgroundColor3 = State.isEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(40, 40, 50)
    end)
    
    -- Initialize button color
    toggleBtn.BackgroundColor3 = State.isEnabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(40, 40, 50)
    
    -- FPS/Ping Display
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Position = UDim2.new(0, 0, 0, 80)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 10
    infoLabel.Parent = frame
    
    -- Update info periodically
    task.spawn(function()
        while gui.Parent do
            local fps = math.floor(1 / RunService.RenderStepped:Wait())
            local ping = math.floor(GetCurrentPing())
            infoLabel.Text = string.format("FPS: %d | Ping: %d ms", fps, ping)
            task.wait(0.5)
        end
    end)
end

-- ========================================================
-- 9. MAIN EXECUTION
-- ========================================================
local function Main()
    -- Initialize Anti-Detection and Performance
    ApplyAntiDetection()
    OptimizePerformance()
    
    -- Create UI
    CreateUI()
    
    -- Watch existing and new balls
    local Balls = Workspace:WaitForChild("Balls", 30)
    if not Balls then
        warn("[Auto-Parry] 'Balls' folder not found. Script may not work.")
        return
    end
    
    for _, ball in ipairs(Balls:GetChildren()) do
        WatchBall(ball)
    end
    Balls.ChildAdded:Connect(WatchBall)
    
    print("[Auto-Parry] Loaded successfully for Mobile.")
end

-- Execute with pcall to prevent crashes
pcall(Main)
