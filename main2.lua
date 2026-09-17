-- ==========================================
-- BLADE BALL: ULTIMATE AUTO-PARRY ENGINE v2.0
-- "Best Parry Remote Ever" Edition
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- CONFIGURATION (Tweak these for your playstyle)
-- ==========================================
local Config = {
    -- SPEED SETTINGS
    ParryCooldown = 0.15,       -- Lower = Faster spam (Riskier). Higher = Safer.
    JitterMin = 5,              -- Random delay in ms to look human
    JitterMax = 25,
    
    -- RANGE SETTINGS (Critical for "Best" parry)
    MinParryDist = 8,           -- Don't parry if ball is too close (misses)
    MaxParryDist = 35,          -- Don't parry if ball is too far (wastes input)
    
    -- DETECTION MODES
    UseRemoteFire = true,       -- TRUE: Uses RemoteEvent (Fastest). FALSE: Uses UI Click.
    VirtualInputFallback = true,-- If Remote fails, click the button instead.
    
    -- BALL NAMES (In case of weird game updates)
    BallNames = {"Ball", "TheBall", "BallPart", "Sphere", "Projectile"}
}

-- ==========================================
-- CORE VARIABLES
-- ==========================================
local Ball = nil
local ParryRemote = nil
local PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = PlayerCharacter:WaitForChild("HumanoidRootPart")
local LastParryTime = 0
local IsParrying = false

-- UI Overlay for Status
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UltimateParryUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 300, 0, 70)
Frame.Position = UDim2.new(0.5, -150, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderSizePixel = 0
Frame.BackgroundTransparency = 0.1
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0.4, 0)
Title.Position = UDim2.new(0, 10, 0, 5)
Title.BackgroundColor3 = Color3.fromRGB(0, 0, 0, 0)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Text = "🔥 ULTIMATE PARRY ENGINE 🔥"
Title.Parent = Frame

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0.6, 0)
Status.Position = UDim2.new(0, 10, 0.45, 0)
Status.BackgroundColor3 = Color3.fromRGB(0, 0, 0, 0)
Status.TextColor3 = Color3.fromRGB(0, 255, 136) -- Neon Green
Status.Font = Enum.Font.GothamSemibold
Status.TextSize = 14
Status.Text = "Initializing..."
Status.Parent = Frame

ScreenGui.Parent = PlayerGui

-- ==========================================
-- PHASE 1: DEEP SCAN REMOTE (The "Finder")
-- ==========================================
local function FindParryRemote()
    print("[Ultimate] Scanning for Parry Remote...")
    
    -- List of possible names
    local keywords = {"Parry", "PARRY", "parry", "Server_Parry", "server_parry", "Attack"}
    
    -- Helper: Recursive Folder Search
    local function searchDescendants(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") then
                local name = tostring(child.Name):lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw:lower()) then
                        print("[Ultimate] Found Remote: " .. child.Name)
                        return child
                    end
                end
            elseif child:IsA("Folder") or child:IsA("ModuleScript") then
                local found = searchDescendants(child)
                if found then return found end
            end
        end
    end
    
    -- 1. Check Direct Children
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        if child:IsA("RemoteEvent") then
            local name = tostring(child.Name):lower()
            for _, kw in ipairs(keywords) do
                if name:find(kw:lower()) then
                    print("[Ultimate] Found Direct Remote: " .. child.Name)
                    return child
                end
            end
        elseif child:IsA("Folder") then
            local found = searchDescendants(child)
            if found then return found end
        end
    end
    
    -- 2. Search ALL descendants of ReplicatedStorage (Brute Force)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = tostring(obj.Name):lower()
            for _, kw in ipairs(keywords) do
                if name:find(kw:lower()) then
                    print("[Ultimate] Found Deep Remote: " .. obj.Name)
                    return obj
                end
            end
        end
    end
    
    warn("[Ultimate] No Remote found! Falling back to Virtual Input.")
    Config.UseRemoteFire = false
    return nil
end

-- ==========================================
-- PHASE 2: BALL TRACKING (The "Eye")
-- ==========================================
local function FindBall()
    for _, name in ipairs(Config.BallNames) do
        local found = Workspace:FindFirstChild(name)
        if found and found:IsA("BasePart") then
            return found
        end
    end
    
    -- Fallback: Search by name containing "ball"
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and string.lower(obj.Name):find("ball") then
            return obj
        end
    end
    return nil
end

-- ==========================================
-- PHASE 3: INPUT ENGINE (The "Hand")
-- ==========================================
local function TriggerParry()
    local jitter = math.random(Config.JitterMin, Config.JitterMax) / 1000
    
    if Config.UseRemoteFire and ParryRemote then
        -- FASTEST METHOD: Fire Remote Directly
        pcall(function()
            ParryRemote:FireServer()
        end)
        Status.Text = "Parried (Remote)"
        Status.TextColor3 = Color3.fromRGB(0, 255, 136)
        
    elseif Config.VirtualInputFallback then
        -- SAFE METHOD: Click UI Button
        local parryBtn = PlayerGui:FindFirstChild("Parry")
        if not parryBtn then
            for _, btn in ipairs(PlayerGui:GetChildren()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and tostring(btn.Text):lower():find("parry") then
                    parryBtn = btn
                    break
                end
            end
        end

        if parryBtn then
            local centerX = parryBtn.AbsolutePosition.X + (parryBtn.AbsoluteSize.X / 2)
            local centerY = parryBtn.AbsolutePosition.Y + (parryBtn.AbsoluteSize.Y / 2)
            
            VirtualInputManager:SendMouseButtonEvent(0, centerX, centerY, 0, true, game)
            task.wait(jitter)
            VirtualInputManager:SendMouseButtonEvent(0, centerX, centerY, 0, false, game)
            
            Status.Text = "Parried (UI)"
            Status.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end
    
    LastParryTime = tick()
end

-- ==========================================
-- PHASE 4: MAIN LOOP (The "Brain")
-- ==========================================
local function Initialize()
    -- Find Remote
    ParryRemote = FindParryRemote()
    
    -- Find Ball
    Ball = FindBall()
    
    if not Ball then
        Status.Text = "Waiting for Ball..."
        Status.TextColor3 = Color3.fromRGB(255, 200, 0)
    else
        Status.Text = "Ready. Remote: " .. tostring(ParryRemote and ParryRemote.Name or "UI")
        Status.TextColor3 = Color3.fromRGB(0, 255, 136)
    end
end

Initialize()

RunService.Heartbeat:Connect(function(dt)
    if not Config.Enabled then return end
    
    -- 1. Ensure Ball Exists
    if not Ball or not Ball:IsA("BasePart") then
        local newBall = FindBall()
        if newBall then
            Ball = newBall
            Status.Text = "Ball Found!"
            Status.TextColor3 = Color3.fromRGB(0, 255, 136)
        else
            return -- Don't parry if no ball
        end
    end
    
    -- 2. Calculate Distance & Angle
    local distance = (Ball.Position - HumanoidRootPart.Position).Magnitude
    
    -- 3. Check Cooldown
    if tick() - LastParryTime < Config.ParryCooldown then return end
    
    -- 4. Parry Logic
    -- We parry if the ball is within our optimal range
    if distance >= Config.MinParryDist and distance <= Config.MaxParryDist then
        TriggerParry()
    end
end)

-- Handle Respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    PlayerCharacter = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Ball = nil 
    Status.Text = "Respawned. Re-scanning..."
    Status.TextColor3 = Color3.fromRGB(255, 200, 0)
    
    -- Small delay to let character settle
    task.wait(1)
    Initialize()
end)

print("[Ultimate] Engine Loaded. Best Parry Active.")
