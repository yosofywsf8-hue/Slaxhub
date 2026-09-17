-- ==========================================
-- BLADE BALL AUTO-PARRY V2 (FIXED FOR KICKS)
-- Uses RemoteEvent + Throttling for Stability
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- CONFIGURATION
-- ==========================================
local Config = {
    Enabled = true,
    ParryCooldown = 0.25,      -- Seconds between parries (Prevents Spam Kicks)
    MinDistanceToParry = 15,   -- Only parry if ball is within this distance
    MaxDistanceToParry = 40,   -- Don't parry if ball is too far (waste of input)
    PingThreshold = 150,       -- Ping at which to increase sensitivity
}

-- ==========================================
-- CORE VARIABLES
-- ==========================================
local Ball = nil
local PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = PlayerCharacter:WaitForChild("HumanoidRootPart")
local LastParryTime = 0
local CanParry = true

-- UI Overlay
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallUI_Fixed"
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
Label.Text = "Auto-Parry V2 [ON]"
Label.Parent = Frame

ScreenGui.Parent = PlayerGui

-- ==========================================
-- FINDING THE PARRY REMOTE
-- ==========================================
local ParryRemote = nil

local function FindParryRemote()
    -- Blade Ball typically uses ReplicatedStorage for parries
    -- Common names: "Parry", "PARRY", "Server.Parry"
    local candidates = {"Parry", "PARRY", "ParryEvent", "server_parry"}
    
    for _, name in ipairs(candidates) do
        local remote = ReplicatedStorage:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            ParryRemote = remote
            print("[Blade Ball] Found Remote: " .. name)
            return
        end
    end
    
    -- Fallback: Search all descendants
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and string.lower(obj.Name):find("parry") then
            ParryRemote = obj
            print("[Blade Ball] Found Remote via search: " .. obj.Name)
            return
        end
    end
    
    warn("[Blade Ball] Could not find Parry Remote. Parrying may fail.")
end

FindParryRemote()

-- ==========================================
-- BALL DETECTION
-- ==========================================
local function GetBall()
    -- Method 1: Direct reference (Most common in Blade Ball)
    if workspace:FindFirstChild("Ball") then
        return workspace.Ball
    end
    
    -- Method 2: Find the closest moving part to player
    local bestPart = nil
    local minDist = math.huge
    
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Ball" then
            local dist = (part.Position - HumanoidRootPart.Position).Magnitude
            if dist < minDist then
                minDist = dist
                bestPart = part
            end
        end
    end
    
    return bestPart
end

-- ==========================================
-- PARRY LOGIC
-- ==========================================
local function PerformParry()
    if not CanParry or not ParryRemote then return end
    
    local now = tick()
    
    -- Check Cooldown (Anti-Spam)
    if now - LastParryTime < Config.ParryCooldown then
        return
    end
    
    Ball = GetBall()
    if not Ball then return end
    
    local distance = (Ball.Position - HumanoidRootPart.Position).Magnitude
    
    -- Only parry if ball is in range
    if distance >= Config.MinDistanceToParry and distance <= Config.MaxDistanceToParry then
        pcall(function()
            -- Fire the remote event
            -- Some versions require arguments, most don't. 
            -- We try firing with no args first (safest for mobile)
            ParryRemote:FireServer()
            
            LastParryTime = tick()
            CanParry = false
            
            -- Visual Feedback
            Label.Text = "Parried! (" .. math.floor(distance) .. "m)"
            task.wait(0.2)
            Label.Text = "Auto-Parry V2 [ON]"
            
            -- Re-enable after cooldown
            task.delay(Config.ParryCooldown, function()
                CanParry = true
            end)
        end)
    end
end

-- ==========================================
-- MAIN LOOP
-- ==========================================
RunService.Heartbeat:Connect(function(dt)
    if not Config.Enabled then return end
    
    PerformParry()
end)

-- Handle Character Death/Respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    PlayerCharacter = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Ball = nil
end)

print("[Blade Ball] Fixed Auto-Parry V2 Loaded!")
