-- ==========================================
-- BLADE BALL MOBILE AUTO-PARRY (DELTA/ARCEUS)
-- Optimized for VirtualInputManager & Performance
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- CONFIGURATION
-- ==========================================
local Config = {
    Enabled = true,
    ParryButtonName = "Parry", -- Usually "Parry" or "P" depending on UI version
    MinDelayMs = 10,          -- Minimum delay for parry input (ms)
    MaxDelayMs = 40,          -- Maximum delay jitter (ms)
    PingThreshold = 200,      -- High ping threshold in ms
    AutoParryMode = true,     -- True = Parry automatically when ball is close
    TimebombDetection = true, -- Disable auto-parry if "Timebomb" mode is active
}

-- ==========================================
-- CORE VARIABLES
-- ==========================================
local Ball = nil
local PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = PlayerCharacter:WaitForChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera

-- UI Overlay for Mobile (Lightweight)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 50)
Frame.Position = UDim2.new(0.5, -100, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20, 200)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Label = Instance.new("TextLabel")
Label.Size = UDim2.new(1, 0, 1, 0)
Label.BackgroundColor3 = Color3.fromRGB(0, 0, 0, 0)
Label.TextColor3 = Color3.fromRGB(255, 255, 255)
Label.Font = Enum.Font.GothamBold
Label.TextSize = 18
Label.Text = "Blade Ball Auto-Parry [ON]"
Label.Parent = Frame

ScreenGui.Parent = PlayerGui

-- ==========================================
-- PERFORMANCE OPTIMIZATION (FPS BOOST)
-- ==========================================
local function OptimizeGraphics()
    pcall(function()
        -- Disable Shadows
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CastShadow = false
                part.Transparency = 0.95 -- Make parts slightly see-through for performance
            end
        end
        
        -- Disable Post-Processing
        local Lighting = game:GetService("Lighting")
        Lighting.Bloom.Enabled = false
        Lighting.ColorCorrection.Enabled = false
        Lighting.GodRaysEnabled = false
        Lighting.FogEnd = 1000 -- Reduce fog distance for clarity
    end)
end

OptimizeGraphics()

-- ==========================================
-- NETWORK & PING COMPENSATION
-- ==========================================
local function GetPing()
    local stats = game:GetService("Stats")
    local network = stats:FindFirstChild("Network")
    if network then
        local pingItem = network:FindFirstChild("Data Ping")
        if pingItem then
            return pingItem.Value
        end
    end
    return 50 -- Default fallback
end

local function GetPingOffset()
    local ping = GetPing()
    -- Add extra delay for high ping to ensure ball is actually at the predicted location
    if ping > Config.PingThreshold then
        return (ping / 2) + 10
    end
    return 0
end

-- ==========================================
-- INPUT SIMULATION (ANTI-CHEAT SAFE)
-- ==========================================
local function SimulateParry()
    pcall(function()
        -- Generate random jitter to mimic human reaction
        local jitter = math.random(Config.MinDelayMs, Config.MaxDelayMs)
        
        -- Small delay before input to allow network sync
        task.wait(jitter / 1000)

        -- Method 1: Try finding the Parry Button in UI and clicking it via VIM
        -- This is safer than firing Remotes
        local parryButton = nil
        
        -- Search for common parry button names in Blade Ball UI
        local candidates = {"Parry", "P", "ParryButton", "Action"}
        for _, name in ipairs(candidates) do
            local btn = PlayerGui:FindFirstChild(name) or PlayerGui:FindFirstChildOfClass("TextButton")
            if btn then
                parryButton = btn
                break
            end
        end

        if parryButton then
            -- Simulate a touch input on the button's position
            -- For mobile, we simulate a tap at the center of the button
            local x = parryButton.AbsolutePosition.X + parryButton.AbsoluteSize.X / 2
            local y = parnergyButton.AbsolutePosition.Y + parryButton.AbsoluteSize.Y / 2
            
            VirtualInputManager:SendMouseButtonEvent(0, x, y, 0, true, game)
            task.wait(0.05) -- Lift finger
            VirtualInputManager:SendMouseButtonEvent(0, x, y, 0, false, game)
        else
            -- Fallback: Simulate a keyboard press if UI detection fails
            -- Some executors map 'P' to parry
            VirtualInputManager:SendKeyEvent(true, "P", false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, "P", false, game)
        end
        
        -- Update UI text briefly
        Label.Text = "Parried!"
        task.wait(0.2)
        Label.Text = "Blade Ball Auto-Parry [ON]"
    end)
end

-- ==========================================
-- TIMEBOMB MODE DETECTION
-- ==========================================
local function IsTimebombMode()
    -- Check for specific UI elements or game modes that indicate Timebomb
    -- Blade Ball often uses a specific frame or text for Timebomb
    local timebombFrame = PlayerGui:FindFirstChild("Timebomb") or 
                          PlayerGui:FindFirstChild("Timer") or 
                          PlayerGui:FindFirstChildOfClass("TextLabel")
    
    if timebombFrame then
        -- Heuristic: If the text says "Timebomb" or similar, disable auto parry
        -- Note: This is a heuristic and may need updates based on game patches
        return string.find(tostring(timebombFrame.Text), "Timebomb", 1, true) ~= nil
    end
    return false
end

-- ==========================================
-- MAIN PARRY LOGIC (VELOCITY PREDICTION)
-- ==========================================
local function CalculateParryTime()
    if not Ball or not HumanoidRootPart then 
        return nil 
    end

    -- Get Ball Velocity and Position
    local ballPos = Ball.Position
    local ballVel = Ball.Velocity
    
    -- Calculate distance from player to ball
    local distance = (ballPos - HumanoidRootPart.Position).Magnitude
    
    -- Estimate time to impact
    -- Speed = Distance / Time => Time = Distance / Speed
    local speed = ballVel.Magnitude
    if speed < 1 then return nil end -- Ball not moving enough

    local timeToImpact = distance / speed
    
    -- Adjust for Ping and Network Latency
    local pingOffset = GetPingOffset()
    
    -- Humanize the timing slightly
    timeToImpact = timeToImpact + (pingOffset / 1000)
    
    return timeToImpact
end

-- ==========================================
-- GAME LOOP
-- ==========================================
RunService.Heartbeat:Connect(function(dt)
    if not Config.Enabled then return end

    -- 1. Identify Ball
    -- Blade Ball usually has a specific model or part named "Ball" or similar
    -- We search for the most prominent moving part that isn't the player
    local potentialBalls = workspace:GetDescendants()
    for _, obj in ipairs(potentialBalls) do
        if obj:IsA("BasePart") and obj.Name == "Ball" then
            Ball = obj
            break
        end
    end

    -- Fallback: If "Ball" part not found, look for a part with high velocity near center
    if not Ball then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Velocity.Magnitude > 50 then
                -- Heuristic: Is it close to the middle of the map?
                local distToCenter = (obj.Position - Vector3.new(0, 50, 0)).Magnitude
                if distToCenter < 200 then
                    Ball = obj
                    break
                end
            end
        end
    end

    if not Ball then return end

    -- 2. Check Timebomb Mode
    if Config.TimebombDetection and IsTimebombMode() then
        return -- Skip parry in timebomb mode to avoid false positives
    end

    -- 3. Calculate Parry Timing
    local timeToImpact = CalculateParryTime()
    
    if timeToImpact then
        -- If the ball is within a certain threshold (e.g., 2-5 meters), trigger parry
        -- This prevents spamming parries when the ball is far away
        local distance = (Ball.Position - HumanoidRootPart.Position).Magnitude
        
        -- Dynamic Hit Radius based on Ping
        local hitRadius = 10 + GetPingOffset() 
        
        if distance < hitRadius and timeToImpact < 0.5 then
            -- Trigger Parry
            SimulateParry()
            
            -- Small cooldown to prevent spamming multiple parries for one ball
            task.wait(0.3) 
        end
    end
end)

-- ==========================================
-- CHARACTER RESET HANDLER
-- ==========================================
LocalPlayer.CharacterAdded:Connect(function(char)
    PlayerCharacter = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Ball = nil -- Reset ball reference
end)

print("[Blade Ball] Mobile Auto-Parry Loaded Successfully!")
