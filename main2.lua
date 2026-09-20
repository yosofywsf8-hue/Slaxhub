-- =======================================================================
-- ًں”چ XENO EXECUTOR DETECTOR & BYPASS INTERCEPTOR
-- =======================================================================
local isXeno = false

-- à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¹€à¸­à¸پà¸¥à¸±à¸پà¸©à¸“à¹Œà¹€à¸‰à¸‍à¸²à¸°à¸‚à¸­à¸‡à¸•à¸±à¸§à¸£à¸±à¸™ Xeno (à¹€à¸ٹà¹ˆà¸™ à¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¹€à¸‰à¸‍à¸²à¸° à¸«à¸£à¸·à¸­ Global Variable)
if identifyexecutor then
    local execName = tostring(identifyexecutor()):lower()
    if execName:find("xeno") or execName:find("xen") then
        isXeno = true
    end
end

-- à¸«à¸²à¸پà¸•à¸£à¸§à¸ˆà¹€à¸ˆà¸­à¸§à¹ˆà¸²à¹€à¸›à¹‡à¸™ Xeno à¹ƒà¸«à¹‰à¸‚à¹‰à¸²à¸،à¸ھà¸„à¸£à¸´à¸›à¸•à¹Œà¸™à¸µà¹‰à¹پà¸¥à¹‰à¸§à¹„à¸›à¸£à¸±à¸™à¹‚à¸„à¹‰à¸” Xeno à¸—à¸±à¸™à¸—à¸µ
if isXeno then
    warn("[Invis Core]: Xeno Executor Detected! Skipping main script and routing to Xeno Engine.")
    
-- =======================================================================
-- ًں”’ PART 1: PHYSICS RESOLVER & XENO CAMERA CURVE SYSTEM
-- =======================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- à¸•à¸²à¸£à¸²à¸‡à¸ˆà¸±à¸”à¸پà¸²à¸£ Global State (à¸„à¸±à¸”à¸¥à¸­à¸پà¹„à¸›à¹€à¸ٹà¸·à¹ˆà¸­à¸،à¸«à¸£à¸·à¸­à¹پà¸—à¸™à¸—à¸µà¹ˆà¹ƒà¸™à¸•à¸²à¸£à¸²à¸‡ Config à¸‚à¸­à¸‡à¸„à¸¸à¸“à¹„à¸”à¹‰à¹€à¸¥à¸¢)
Xeno_Config = {
    AutoParry = true,
    AutoSpam = false,
    ManualSpam = false,
    
    AutoSpamSpeed = 0.01,    -- à¸„à¹ˆà¸²à¹€à¸£à¸´à¹ˆà¸،à¸•à¹‰à¸™ 0.01 à¸§à¸´à¸™à¸²à¸—à¸µ (à¸›à¸£à¸±à¸ڑà¹„à¸”à¹‰à¹€à¸£à¹‡à¸§à¸ھà¸¸à¸” 0.001)
    ManualSpamSpeed = 0.01,  -- à¸„à¹ˆà¸²à¹€à¸£à¸´à¹ˆà¸،à¸•à¹‰à¸™ 0.01 à¸§à¸´à¸™à¸²à¸—à¸µ (à¸›à¸£à¸±à¸ڑà¹„à¸”à¹‰à¹€à¸£à¹‡à¸§à¸ھà¸¸à¸” 0.001)
    
    wowcurve = 0.35,         -- à¸„à¹ˆà¸²à¸”à¸±à¸پà¸—à¸²à¸‡à¸ڑà¸­à¸¥à¹„à¸‹à¸”à¹Œà¹‚à¸„à¹‰à¸‡
}

local parryLocked = {}
local lockTime = {}

-- à¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¸„à¹‰à¸™à¸«à¸²à¸¥à¸¹à¸پà¸ڑà¸­à¸¥à¹پà¸—à¹‰à¹ƒà¸™à¸ھà¸™à¸²à¸،
local function GetActiveBall()
    local bc = workspace:FindFirstChild("Balls") or workspace:FindFirstChild("TrainingBalls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:IsA("BasePart") and (b:GetAttribute("realBall") or b:GetAttribute("target")) then 
                return b 
            end
        end
    end
    return nil
end

-- à¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¸”à¸±à¸پà¸ˆà¸±à¸ڑà¸§à¸´à¸–à¸µà¹‚à¸„à¹‰à¸‡ (Anti-Curve Engine)
local function IsBallCurving(ball, hrp)
    if not ball or not hrp then return false end
    local ballVel = ball.AssemblyLinearVelocity
    if ballVel.Magnitude < 1 then return false end

    local dirToPlayer = (hrp.Position - ball.Position).Unit
    local ballDir = ballVel.Unit
    local dot = ballDir:Dot(dirToPlayer)

    -- à¸ھà¹ˆà¸‡à¸„à¹ˆà¸²à¸پà¸¥à¸±à¸ڑà¹€à¸›à¹‡à¸™ True à¸«à¸²à¸پà¸ڑà¸­à¸¥à¸،à¸µà¸„à¸§à¸²à¸،à¹€à¸‰à¸µà¸¢à¸‡à¸«à¸¥à¸¸à¸”à¸ˆà¸²à¸پà¸£à¸°à¸™à¸²à¸ڑà¹پà¸پà¸™à¸•à¸£à¸‡
    return (dot < 0.75 and dot > -0.6)
end

-- ًں›،ï¸ڈ MAIN RENDERSTEPPED LOOP FOR AUTO PARRY
RunService.RenderStepped:Connect(function()
    if not Xeno_Config.AutoParry then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or (char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").Health <= 0) then return end

    local ball = GetActiveBall()
    if not ball then return end

    local targetAttr = ball:GetAttribute("target") or ball:GetAttribute("Target")
    local isTargetingMe = (tostring(targetAttr or "") == LocalPlayer.Name)
    if not isTargetingMe then return end

    local ballPos = ball.Position
    local distance = (hrp.Position - ballPos).Magnitude
    if distance > 125 then return end

    local velocity = ball.AssemblyLinearVelocity
    local speed = velocity.Magnitude
    local reachTime = distance / math.max(speed, 1)

    -- à¸£à¸°à¸ڑà¸ڑà¸›à¸¥à¸”à¸¥à¹‡à¸­à¸پ Cooldown à¸¥à¹ˆà¸§à¸‡à¸«à¸™à¹‰à¸² (Xeno Safety Buff)
    -- à¸”à¸±à¸پà¸¥à¹‰à¸²à¸‡à¸„à¸¹à¸¥à¸”à¸²à¸§à¸™à¹Œà¸¥à¹ˆà¸§à¸‡à¸«à¸™à¹‰à¸² 0.5 à¸§à¸´à¸™à¸²à¸—à¸µ à¹€à¸‍à¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¹€à¸ںà¸£à¸،à¸–à¸±à¸”à¹„à¸›à¸ھà¹پà¸•à¸™à¸”à¹Œà¸ڑà¸²à¸¢à¸„à¸¥à¸´à¸پà¹€à¸،à¸²à¸ھà¹Œà¹„à¸”à¹‰à¸—à¸±à¸™à¸—à¸µ
    if parryLocked[ball] then
        local baseCooldown = math.clamp(4.9 - (speed * 0.01), 0.7, 0.85)
        local xenoAdjustedCooldown = baseCooldown - 0.5 -- à¸«à¸±à¸پà¸¥à¸ڑà¸”à¸µà¹€à¸¥à¸¢à¹Œà¸£à¸°à¸ڑà¸ڑà¸•à¸±à¸§à¹€à¸پà¸،à¸­à¸­à¸پ 0.5 à¸§à¸´à¸™à¸²à¸—à¸µ
        
        if os.clock() - (lockTime[ball] or 0) >= math.max(0.1, xenoAdjustedCooldown) then
            parryLocked[ball] = false
        else
            return
        end
    end

    -- à¸•à¸£à¸£à¸پà¸°à¸›à¸£à¸°à¸،à¸§à¸¥à¸œà¸¥à¸،à¸¸à¸،à¸¢à¸´à¸‡à¸ھà¸³à¸«à¸£à¸±à¸ڑà¸پà¸²à¸£à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¹€à¸‡à¸·à¹ˆà¸­à¸™à¹„à¸‚
    local ballDirection = speed > 1 and velocity.Unit or Vector3.new(0, -1, 0)
    local toPlayerDirection = distance > 0.1 and (hrp.Position - ballPos).Unit or Vector3.zero
    local dotProduct = ballDirection:Dot(toPlayerDirection)

    local triggerParry = false

    -- à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¸§à¸´à¸–à¸µà¹„à¸‹à¸”à¹Œà¹‚à¸„à¹‰à¸‡
    if IsBallCurving(ball, hrp) then
        local lateralVelocity = velocity - (velocity.Unit:Dot(toPlayerDirection) * velocity.Unit)
        local strikeZone = math.clamp((12 + (speed * Xeno_Config.wowcurve)) - (lateralVelocity.Magnitude * 0.135), 17, 135)
        
        if distance <= strikeZone or reachTime <= 0.2 then
            if dotProduct > -0.35 or distance <= 35 then
                triggerParry = true
            end
        end
    else
        -- à¸§à¸´à¸–à¸µà¸•à¸£à¸‡à¸›à¸پà¸•à¸´
        local normalZone = math.clamp(8.5 + (speed * 0.3), 8.5, 68)
        if distance <= normalZone or reachTime <= 0.05 then
            triggerParry = true
        end
    end

    -- à¸ھà¸±à¹ˆà¸‡à¸پà¸²à¸£à¸ھà¹ˆà¸‡à¸ھà¸±à¸چà¸چà¸²à¸“à¸¢à¸´à¸‡à¹€à¸،à¸²à¸ھà¹Œ
    if triggerParry and not parryLocked[ball] then
        parryLocked[ball] = true
        lockTime[ball] = os.clock()
        
        -- à¹€à¸£à¸µà¸¢à¸پà¹ƒà¸ٹà¹‰à¸‡à¸²à¸™à¸‚à¹‰à¸²à¸،à¹„à¸›à¸ھà¸±à¹ˆà¸‡à¸„à¸¥à¸´à¸پà¹€à¸،à¸²à¸ھà¹Œà¹ƒà¸™à¸£à¸°à¸ڑà¸ڑà¹€à¸ھà¸،à¸·à¸­à¸™ (Part 2)
        if FireXenoSafeMouse then
            FireXenoSafeMouse()
        end
    end
end)

-- =======================================================================
-- âŒ¨ï¸ڈ PART 2: SPAM CONTROL ENGINE & SAFE XENO MOUSE INPUT
-- =======================================================================
local UserInputService = game:GetService("UserInputService")

-- ًں”’ à¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¸ھà¹ˆà¸‡à¸„à¸³à¸ھà¸±à¹ˆà¸‡à¸„à¸¥à¸´à¸پà¹€à¸،à¸²à¸ھà¹Œà¹پà¸ڑà¸ڑà¸›à¸¥à¸­à¸”à¸ à¸±à¸¢à¹پà¸¥à¸°à¸£à¸­à¸‡à¸£à¸±à¸ڑà¸پà¸²à¸£à¸ھà¸°à¸—à¹‰à¸­à¸™à¸‍à¸´à¸پà¸±à¸”à¹ƒà¸«à¹‰à¸•à¸±à¸§à¹€à¸پà¸، (Safe Mouse Input)
function FireXenoSafeMouse()
    if mouse1press and mouse1release then
        pcall(function()
            -- à¹ƒà¸ٹà¹‰à¸پà¸²à¸£à¸ھà¸°à¸پà¸´à¸”à¸پà¸”à¹پà¸¥à¹‰à¸§à¸›à¸¥à¹ˆà¸­à¸¢à¹ƒà¸™à¹€à¸ھà¸µà¹‰à¸¢à¸§à¹€à¸ںà¸£à¸،à¸—à¸µà¹ˆà¸ھà¸±à¹‰à¸™à¸—à¸µà¹ˆà¸ھà¸¸à¸”à¹€à¸‍à¸·à¹ˆà¸­à¸›à¹‰à¸­à¸‡à¸پà¸±à¸™à¸„à¸³à¸ھà¸±à¹ˆà¸‡à¸„à¹‰à¸²à¸‡à¸ڑà¸™ Xeno
            mouse1press()
            task.wait(0.0005)
            mouse1release()
        end)
    end
end

-- âڑ”ï¸ڈ LOOP 1: AUTO SPAM ENGINE (THREAD-SAFE PIPELINE)
task.spawn(function()
    while true do
        -- à¸”à¸¶à¸‡à¸„à¹ˆà¸²à¸«à¸™à¹ˆà¸§à¸‡à¹€à¸§à¸¥à¸²à¹پà¸›à¸£à¸œà¸±à¸™à¸•à¸£à¸‡ à¹پà¸¥à¸°à¸¥à¹‡à¸­à¸پà¸‚à¸­à¸ڑà¹€à¸‚à¸•à¸‚à¸±à¹‰à¸™à¸•à¹ˆà¸³à¸ھà¸¸à¸”à¹„à¸§à¹‰à¸—à¸µà¹ˆ 0.001 à¸§à¸´à¸™à¸²à¸—à¸µà¸•à¸²à¸،à¸ھà¸±à¹ˆà¸‡
        local currentDelay = tonumber(Xeno_Config.AutoSpamSpeed) or 0.01
        local enforcedDelay = math.clamp(currentDelay, 0.001, 2.0)
        
        if Xeno_Config.AutoSpam then
            pcall(FireXenoSafeMouse)
        end
        
        task.wait(enforcedDelay)
    end
end)

-- âڑ”ï¸ڈ LOOP 2: MANUAL SPAM ENGINE (THREAD-SAFE PIPELINE)
task.spawn(function()
    while true do
        -- à¸”à¸¶à¸‡à¸„à¹ˆà¸²à¸«à¸™à¹ˆà¸§à¸‡à¹€à¸§à¸¥à¸²à¹پà¸›à¸£à¸œà¸±à¸™à¸•à¸£à¸‡ à¹پà¸¥à¸°à¸¥à¹‡à¸­à¸پà¸‚à¸­à¸ڑà¹€à¸‚à¸•à¸‚à¸±à¹‰à¸™à¸•à¹ˆà¸³à¸ھà¸¸à¸”à¹„à¸§à¹‰à¸—à¸µà¹ˆ 0.001 à¸§à¸´à¸™à¸²à¸—à¸µà¸•à¸²à¸،à¸ھà¸±à¹ˆà¸‡
        local currentDelay = tonumber(Xeno_Config.ManualSpamSpeed) or 0.01
        local enforcedDelay = math.clamp(currentDelay, 0.001, 2.0)
        
        if Xeno_Config.ManualSpam then
            pcall(FireXenoSafeMouse)
        end
        
        task.wait(enforcedDelay)
    end
end)

-- âŒ¨ï¸ڈ DETECTION PIPELINE: à¸œà¸¹à¸پà¸ھà¸±à¸چà¸چà¸²à¸“à¸›à¸¸à¹ˆà¸، E à¸ھà¸³à¸«à¸£à¸±à¸ڑà¹€à¸›à¸´à¸”/à¸›à¸´à¸”à¸£à¸°à¸ڑà¸ڑ Manual Spam à¸­à¸±à¸•à¹‚à¸™à¸،à¸±à¸•à¸´
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- à¸›à¹‰à¸­à¸‡à¸پà¸±à¸™à¸ڑà¸­à¸—à¸ھà¹پà¸›à¸،à¸—à¸³à¸‡à¸²à¸™à¸•à¸­à¸™à¸—à¸µà¹ˆà¸œà¸¹à¹‰à¹€à¸¥à¹ˆà¸™à¸پà¸³à¸¥à¸±à¸‡à¸‍à¸´à¸،à¸‍à¹Œà¹ƒà¸™à¸ٹà¹ˆà¸­à¸‡à¹پà¸ٹà¸—
    
    if input.KeyCode == Enum.KeyCode.E then
        Xeno_Config.ManualSpam = not Xeno_Config.ManualSpam
        
        -- (à¹€à¸ھà¸£à¸´à¸،à¸ھà¸³à¸«à¸£à¸±à¸ڑà¸پà¸²à¸£à¹پà¸ˆà¹‰à¸‡à¹€à¸•à¸·à¸­à¸™à¸ڑà¸™à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡à¸›à¸£à¸°à¸،à¸§à¸¥à¸œà¸¥à¸‚à¸­à¸‡à¸•à¸±à¸§à¸£à¸±à¸™)
        if Xeno_Config.ManualSpam then
            print("[Xeno Input]: Manual Spam Overdrive activated.")
        else
            print("[Xeno Input]: Manual Spam Overdrive deactivated.")
        end
    end
end)

-- =======================================================================
-- ًں“Œ PART 1: STANDALONE CYBERPUNK MAIN FRAME (INTERFACE ONLY)
-- =======================================================================
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ًںژ¨ THEME COLORS & PALETTE (Cyber Neo Theme)
getgenv().InvisUI_Theme = {
    Background = Color3.fromRGB(10, 10, 14),
    CardBg     = Color3.fromRGB(18, 18, 26),
    Accent     = Color3.fromRGB(0, 240, 255),  -- Electric Cyan
    AccentGlow = Color3.fromRGB(255, 0, 128),  -- Cyber Pink
    TextMain   = Color3.fromRGB(255, 255, 255),
    TextDark   = Color3.fromRGB(130, 135, 145),
    Active     = Color3.fromRGB(0, 255, 150),
    Inactive   = Color3.fromRGB(255, 45, 85)
}
local THEME = getgenv().InvisUI_Theme

-- ًں–¼ï¸ڈ SCREEN GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InvisXeno_PremiumUI_" .. math.random(100, 999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if gethui then ScreenGui.Parent = gethui()
    elseif CoreGui then ScreenGui.Parent = CoreGui
    else ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end)
getgenv().InvisUI_ScreenGui = ScreenGui

-- ًں–¼ï¸ڈ MAIN FRAME WINDOW (à¹ƒà¸ٹà¹‰ CanvasGroup à¹€à¸‍à¸·à¹ˆà¸­à¸—à¸³à¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¹€à¸›à¸´à¸”/à¸›à¸´à¸”à¸ھà¸،à¸¹à¸—)
local MainFrame = Instance.new("CanvasGroup", ScreenGui)
MainFrame.Size = UDim2.new(0, 390, 0, 330)
MainFrame.Position = UDim2.new(0.35, 0, 0.25, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.GroupTransparency = 0
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
getgenv().InvisUI_MainFrame = MainFrame

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ًںŒˆ à¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸پà¸£à¸­à¸ڑà¹„à¸ںà¸§à¸´à¹ˆà¸‡ RGB à¹„à¸«à¸¥à¹€à¸ٹà¸·à¹ˆà¸­à¸‡à¸ٹà¹‰à¸²à¹€à¸‍à¸´à¹ˆà¸،à¸„à¸§à¸²à¸،à¹€à¸—à¹ˆà¸£à¸­à¸ڑà¸•à¸±à¸§à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡
task.spawn(function()
    while true do
        for i = 0, 1, 0.005 do
            if MainStroke and MainStroke.Parent then
                MainStroke.Color = Color3.fromHSV(i, 0.8, 1)
            end
            task.wait(0.02)
        end
    end
end)

-- ًں“Œ à¸£à¸°à¸ڑà¸ڑà¸¥à¸²à¸پà¸¢à¹‰à¸²à¸¢à¸•à¸³à¹پà¸«à¸™à¹ˆà¸‡à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡ Main Frame
local mDrag, mStart, mPos
MainFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        mDrag = true; mStart = i.Position; mPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if mDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - mStart
        MainFrame.Position = UDim2.new(mPos.X.Scale, mPos.X.Offset + d.X, mPos.Y.Scale, mPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mDrag = false end
end)

-- ًںڈ·ï¸ڈ HEADER TITLE
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 42)
Title.Text = "   âڑ، INVIS HUB â€” PREMIUM PANEL"
Title.TextColor3 = THEME.TextMain
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

-- ًں“œ SCROLL BAR CONTAINER
local Container = Instance.new("ScrollingFrame", MainFrame)
Container.Size = UDim2.new(1, -20, 1, -55)
Container.Position = UDim2.new(0, 10, 0, 46)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 2
Container.ScrollBarImageColor3 = THEME.Accent
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y

local Layout = Instance.new("UIListLayout", Container)
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ًںژ›ï¸ڈ PREMIUM ANIMATED TOGGLE CREATOR (à¸›à¸¸à¹ˆà¸،à¹€à¸›à¸´à¸”/à¸›à¸´à¸”à¹€à¸›à¸¥à¹ˆà¸²à¹† à¸„à¸·à¸™à¸„à¹ˆà¸²à¸ھà¸–à¸²à¸™à¸°à¹ƒà¸«à¹‰à¸„à¸¸à¸“à¹ƒà¸ٹà¹‰à¸£à¸±à¸™à¸ھà¸„à¸£à¸´à¸›à¸•à¹Œà¸•à¹ˆà¸­)
function createStandaloneToggle(name, defaultState, callback)
    local card = Instance.new("Frame", Container)
    card.Size = UDim2.new(1, -6, 0, 38)
    card.BackgroundColor3 = THEME.CardBg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", card)
    s.Color = Color3.fromRGB(35, 35, 45)
    s.Thickness = 1

    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Text = name
    lbl.TextColor3 = THEME.TextMain
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 48, 0, 22)
    btn.Position = UDim2.new(1, -60, 0.5, -11)
    btn.Text = ""
    btn.BackgroundColor3 = THEME.Inactive
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", btn)
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = UDim2.new(0, 3, 0.5, -8)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local currentState = defaultState or false

    local function updateVisuals(animate)
        local tPos = currentState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local tColor = currentState and THEME.Active or THEME.Inactive
        local duration = animate and 0.25 or 0
        
        TweenService:Create(thumb, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = tPos}):Play()
        TweenService:Create(btn, TweenInfo.new(duration, Enum.EasingStyle.Quad), {BackgroundColor3 = tColor}):Play()
        TweenService:Create(s, TweenInfo.new(duration, Enum.EasingStyle.Quad), {Color = currentState and THEME.Accent or Color3.fromRGB(35, 35, 45)}):Play()
    end

    btn.MouseButton1Click:Connect(function()
        currentState = not currentState
        updateVisuals(true)
        if callback then callback(currentState) end
    end)
    updateVisuals(false)
    return btn
end

-- âŒ¨ï¸ڈ PREMIUM ANIMATED TEXTBOX CREATOR (à¸ٹà¹ˆà¸­à¸‡à¸پà¸£à¸­à¸پà¸„à¹ˆà¸²à¹€à¸›à¸¥à¹ˆà¸²à¹†)
function createStandaloneTextBox(name, defaultText, callback)
    local card = Instance.new("Frame", Container)
    card.Size = UDim2.new(1, -6, 0, 38)
    card.BackgroundColor3 = THEME.CardBg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", card)
    s.Color = Color3.fromRGB(35, 35, 45)

    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0, 160, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Text = name
    lbl.TextColor3 = THEME.TextMain
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1

    local box = Instance.new("TextBox", card)
    box.Size = UDim2.new(1, -185, 0, 24)
    box.Position = UDim2.new(0, 172, 0.5, -12)
    box.Text = tostring(defaultText or "")
    box.TextColor3 = THEME.Accent
    box.Font = Enum.Font.GothamBold
    box.TextSize = 11
    box.BackgroundColor3 = THEME.Background
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", box).Color = Color3.fromRGB(45, 45, 55)

    box.Focused:Connect(function()
        TweenService:Create(s, TweenInfo.new(0.2), {Color = THEME.AccentGlow}):Play()
    end)

    box.FocusLost:Connect(function()
        TweenService:Create(s, TweenInfo.new(0.2), {Color = Color3.fromRGB(35, 35, 45)}):Play()
        if callback then callback(box.Text) end
    end)
end

-- ًں”ک à¸•à¸±à¸§à¸­à¸¢à¹ˆà¸²à¸‡à¸پà¸²à¸£à¸ھà¸£à¹‰à¸²à¸‡ UI à¹€à¸›à¸¥à¹ˆà¸²à¹† (à¸„à¸¸à¸“à¸ھà¸²à¸،à¸²à¸£à¸–à¸™à¸³ callback à¹„à¸›à¹€à¸ٹà¸·à¹ˆà¸­à¸،à¸•à¸±à¸§à¹پà¸›à¸£à¸‚à¸­à¸‡à¸ھà¸„à¸£à¸´à¸›à¸•à¹Œà¸„à¸¸à¸“à¹„à¸”à¹‰à¸—à¸±à¸™à¸—à¸µ)
createStandaloneToggle("Auto Parry System", false, function(state) end)
createStandaloneToggle("Auto Spam Clash", false, function(state) end)
createStandaloneToggle("Manual Spam Overdrive", false, function(state) end)
createStandaloneTextBox("Auto Spam Speed", "0.010", function(text) end)
createStandaloneTextBox("Manual Spam Speed", "0.010", function(text) end)
createStandaloneTextBox("Anti-Curve Adjust", "0.350", function(text) end)

-- =======================================================================
-- ًں“Œ PART 2: FLOATING TOGGLE BUTTON & PREMIUM EXPAND ANIMATIONS
-- =======================================================================
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- à¸”à¸¶à¸‡ Object à¸ھà¹ˆà¸§à¸™à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸‚à¹‰à¸²à¸،à¹„à¸ںà¸¥à¹Œà¸—à¸µà¹ˆà¹پà¸ٹà¸£à¹Œà¹„à¸§à¹‰à¸ˆà¸²à¸پà¸‍à¸²à¸£à¹Œà¸—à¹پà¸£à¸پ
local ScreenGui = getgenv().InvisUI_ScreenGui
local MainFrame = getgenv().InvisUI_MainFrame
local THEME = getgenv().InvisUI_Theme

if not ScreenGui or not MainFrame or not THEME then
    warn("[Invis UI Error]: Please run Part 1 before executing Part 2!")
    return
end

-- ًں”ک FLOATING TOGGLE BUTTON (à¸ھà¸£à¹‰à¸²à¸‡à¸›à¸¸à¹ˆà¸،à¸§à¸‡à¸پà¸¥à¸،à¸¥à¸­à¸¢à¸•à¸±à¸§à¸ھà¹„à¸•à¸¥à¹Œà¸‍à¸£à¸µà¹€à¸،à¸µà¸¢à¸،)
local ToggleBtn = Instance.new("TextButton", ScreenGui)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = THEME.Background
ToggleBtn.Text = "INVIS"
ToggleBtn.TextColor3 = THEME.Accent
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 11
ToggleBtn.AutoButtonColor = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

local ButtonStroke = Instance.new("UIStroke", ToggleBtn)
ButtonStroke.Thickness = 2
ButtonStroke.Color = THEME.Accent

-- à¹€à¸­à¸ںà¹€à¸ںà¸پà¸•à¹Œà¹„à¸ںà¸™à¸µà¸­à¸­à¸™à¸پà¸£à¸°à¸‍à¸£à¸´à¸ڑà¸§à¸¹à¸ڑà¸§à¸²à¸ڑà¸ھà¸¥à¸±à¸ڑà¸ھà¸µà¸ٹà¹‰à¸²à¹† (Neon Pulse Effect) à¸£à¸­à¸ڑà¸›à¸¸à¹ˆà¸،à¸§à¸‡à¸پà¸¥à¸،
task.spawn(function()
    while true do
        if ButtonStroke and ButtonStroke.Parent then
            TweenService:Create(ButtonStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = THEME.AccentGlow}):Play()
            task.wait(0.8)
            TweenService:Create(ButtonStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = THEME.Accent}):Play()
            task.wait(0.8)
        else
            break
        end
    end
end)

-- ًں“Œ à¸£à¸°à¸ڑà¸ڑà¸¥à¸²à¸پà¸¢à¹‰à¸²à¸¢à¸•à¸³à¹پà¸«à¸™à¹ˆà¸‡à¸›à¸¸à¹ˆà¸،à¸§à¸‡à¸پà¸¥à¸،à¸­à¸´à¸ھà¸£à¸° (à¸„à¸±à¸”à¸پà¸£à¸­à¸‡à¹„à¸،à¹ˆà¹ƒà¸«à¹‰à¸—à¸³à¸‡à¸²à¸™à¸‹à¹‰à¸­à¸™à¸پà¸±à¸ڑà¸•à¸£à¸£à¸پà¸°à¸„à¸¥à¸´à¸پà¹€à¸›à¸´à¸”à¸›à¸´à¸”à¹€à¸،à¸™à¸¹)
local tDrag, tStart, tPos, dragStartPos
local isDragging = false

ToggleBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        tDrag = true; tStart = i.Position; tPos = ToggleBtn.Position
        dragStartPos = UserInputService:GetMouseLocation()
        isDragging = false
        -- à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸›à¸¸à¹ˆà¸،à¸«à¸”à¸•à¸±à¸§à¸•à¸­à¸™à¸™à¸´à¹‰à¸§à¸پà¸”à¸ˆà¸´à¹‰à¸، (Squish Compression Impact)
        TweenService:Create(ToggleBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 44, 0, 44)}):Play()
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if tDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        if (UserInputService:GetMouseLocation() - dragStartPos).Magnitude > 5 then
            isDragging = true
        end
        if isDragging then
            local d = i.Position - tStart
            ToggleBtn.Position = UDim2.new(tPos.X.Scale, tPos.X.Offset + d.X, tPos.Y.Scale, tPos.Y.Offset + d.Y)
        end
    end
end)

local guiState = true
local isTransitioning = false

ToggleBtn.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        tDrag = false
        -- à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸›à¸¸à¹ˆà¸،à¸پà¸¥à¸،à¸”à¸µà¸”à¸•à¸±à¸§à¸پà¸¥à¸±à¸ڑà¸‚à¸™à¸²à¸”à¹€à¸”à¸´à¸،à¹پà¸ڑà¸ڑà¸ھà¸›à¸£à¸´à¸‡à¸¢à¸·à¸”à¸«à¸¢à¸¸à¹ˆà¸™ (Elastic Pop Bounce)
        TweenService:Create(ToggleBtn, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = UDim2.new(0, 50, 0, 50)}):Play()
        
        -- à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¹€à¸‡à¸·à¹ˆà¸­à¸™à¹„à¸‚: à¸«à¸²à¸پà¹„à¸،à¹ˆà¹„à¸”à¹‰à¸¥à¸²à¸پà¸›à¸¸à¹ˆà¸، à¹پà¸›à¸¥à¸§à¹ˆà¸²à¹€à¸›à¹‡à¸™à¸پà¸²à¸£ "à¸„à¸¥à¸´à¸پà¸•à¸±à¹‰à¸‡à¹ƒà¸ˆà¹€à¸›à¸´à¸”à¸›à¸´à¸”" -> à¸£à¸±à¸™à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡à¸£à¸°à¸”à¸±à¸ڑà¸—à¹‡à¸­à¸›
        if not isDragging and not isTransitioning then
            isTransitioning = true
            guiState = not guiState
            
            if guiState then
                -- âœ¨ à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¹€à¸›à¸´à¸”à¹€à¸،à¸™à¸¹: à¸£à¸°à¹€à¸ڑà¸´à¸”à¸•à¸±à¸§à¸‚à¸¢à¸²à¸¢à¸،à¸´à¸•à¸´à¹ƒà¸«à¸چà¹ˆà¸‚à¸¶à¹‰à¸™à¸،à¸²à¸ˆà¸²à¸پà¸‍à¸´à¸پà¸±à¸”à¸ˆà¸¸à¸”à¹€à¸¥à¹‡à¸پà¹† (Scale Snap Back)
                MainFrame.Visible = true
                MainFrame.Size = UDim2.new(0, 10, 0, 10)
                TweenService:Create(MainFrame, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 390, 0, 330),
                    GroupTransparency = 0
                }):Play()
                task.wait(0.38)
                isTransitioning = false
            else
                -- âœ¨ à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸›à¸´à¸”à¹€à¸،à¸™à¸¹: à¸¢à¸¸à¸ڑà¸‚à¸™à¸²à¸”à¸پà¸£à¸­à¸ڑà¸«à¸™à¹‰à¸²à¸•à¹ˆà¸²à¸‡à¸•à¸±à¸§à¸¥à¸‡à¸‍à¸£à¹‰à¸­à¸،à¸„à¹ˆà¸­à¸¢à¹† à¸ˆà¸²à¸‡à¸«à¸²à¸¢à¸¥à¸·à¹ˆà¸™à¹„à¸«à¸¥ (Smooth Fade Out)
                TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.new(0, 290, 0, 230),
                    GroupTransparency = 1
                }):Play()
                task.wait(0.22)
                MainFrame.Visible = false
                isTransitioning = false
            end
        end
    end
end)

    return -- ًں›‘ à¹ƒà¸ٹà¹‰ return à¹€à¸‍à¸·à¹ˆà¸­à¸•à¸±à¸”à¸ˆà¸ڑà¸پà¸²à¸£à¸—à¸³à¸‡à¸²à¸™ à¹„à¸،à¹ˆà¹ƒà¸«à¹‰à¹‚à¸„à¹‰à¸”à¸ڑà¸£à¸£à¸—à¸±à¸”à¸¥à¹ˆà¸²à¸‡à¸–à¸±à¸”à¸ˆà¸²à¸پà¸™à¸µà¹‰à¸—à¸³à¸‡à¸²à¸™à¸­à¸µà¸پà¸•à¹ˆà¸­à¹„à¸›
end
-- =======================================================================

if isXeno == false or not isXeno then
repeat task.wait() until game:IsLoaded()

--== AUTO COPY LINK ON START ==
pcall(function()
    if setclipboard then 
        setclipboard("https://youtube.com/@invis_in") 
    elseif toclipboard then 
        toclipboard("https://youtube.com/@invis_in") 
    end
end)

Players = game:GetService("Players")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")
Workspace = game:GetService("Workspace")
Lighting = game:GetService("Lighting")
Terrain = Workspace:FindFirstChildOfClass("Terrain")
LocalPlayer = Players.LocalPlayer

-- â•گâ•گâ•گ SERVICES & GLOBALS â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local Player            = Players.LocalPlayer
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local StatsService      = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

if shared._InvisRunning then
    shared._InvisRunning = false
    if shared._PhysicsBind then shared._PhysicsBind:Disconnect(); shared._PhysicsBind = nil end
    if shared._FlyBind then shared._FlyBind:Disconnect(); shared._FlyBind = nil end
    task.wait(0.1)
end
shared._InvisRunning = true

-- â•گâ•گâ•گ CONFIGURATION & GLOBAL STATE â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
Config = {
    AutoParry = false,
    ParryMode = "Curve", 
    TargetTime = 67,       
    DistanceTiming = 100, 
    ParryCurveMode = "Camera", 
    HitSpeedMode = "Fast ball", 
    TargetMode = "Normal", 
    AutoSpam = false,
    ManualSpam = false,
    ManualSpamSpeed = 0.015,
    SuperSpam = false,
    SuperSpamClicks = 1,
    AutoAbility = false, 
    UseMouseLocation = false,
    packetBatchSize = 3,   
    trainingPacketBatchSize = 16,   
    ClashTarget = true,        
    
    -- New Updates Config
    AbilityESP = false,
    SoccerMode = false,
    GodMode = false,
    CustomSpeed = nil,
    CustomJump = nil,
    CustomAnimID = "",
    
    SkinChangerEnabled = false,
    SwordName = "",
    SwordAnimName = "",
    SwordFXName = "",
    SwordAnimationsEnabled = true,
    EmoteName = "",
    LowGraphicsEnabled = false,
    
    SpecialSkillDetections = false,
    AutoPlay = false,
    AutoJumpEnabled = false,
    
    DesyncEnabled = false,
    DesyncMode = "1: Infinite Sky",
    ParryDirection = "Straight",
    AntiAfk = false,
    
    LookAtBallChar = false,
    LookAtBallCam = false,
    
    PlayerESP = false,  
    wowcurve = 0.33,
    
    UIBackground = "DARK",
    
    CustomComboFX = false,

    MusicEnabled = false,
    MusicLooped = false,
    MusicVolume = 0.5,
    MaxPlayTime = 60,      
    
    ParryMethodMode = "Bypass",
    AI_AutoParry = false,
}

local BackgroundColors = {
    "DARK",
    "RED",
    "BLUE",
    "PURPLE",
    "GREEN",
    "ORANGE"
}

-- ===============================================================================
-- ًں–¼ï¸ڈ SAFE SCREEN GUI SETUP (COMPLETELY FIXED & ANTI-CRASH VERSION)
-- ===============================================================================
local UI_Target_Parent = nil

-- à¹ƒà¸ٹà¹‰ pcall à¸¥à¹‰à¸­à¸،à¸£à¸­à¸ڑà¸—à¸¸à¸پà¸پà¸²à¸£à¸”à¸¶à¸‡à¸„à¹ˆà¸² Environment à¹€à¸‍à¸·à¹ˆà¸­à¸›à¹‰à¸­à¸‡à¸پà¸±à¸™à¸پà¸²à¸£à¸£à¸°à¹€à¸ڑà¸´à¸”à¸‚à¸­à¸‡ Thread
pcall(function()
    if gethui and type(gethui) == "function" then
        UI_Target_Parent = gethui()
    end
end)

pcall(function()
    if not UI_Target_Parent and get_hidden_ui and type(get_hidden_ui) == "function" then
        UI_Target_Parent = get_hidden_ui()
    end
end)

pcall(function()
    if not UI_Target_Parent then
        local coreGui = game:GetService("CoreGui")
        -- à¸”à¸¶à¸‡à¸‍à¸´à¸پà¸±à¸”à¹پà¸ڑà¸ڑà¸£à¸±à¸”à¸پà¸¸à¸،à¸—à¸µà¹ˆà¸ھà¸¸à¸” à¸•à¸£à¸§à¸ˆà¹€à¸ٹà¹‡à¸„à¸§à¹ˆà¸² CoreGui à¸•à¹‰à¸­à¸‡à¹„à¸،à¹ˆà¹ƒà¸ٹà¹ˆà¸„à¹ˆà¸²à¸§à¹ˆà¸²à¸‡à¸پà¹ˆà¸­à¸™à¹€à¸„à¸²à¸°à¸«à¸²à¸¥à¸¹à¸پ
        if coreGui and coreGui:FindFirstChild("RobloxGui") then
            UI_Target_Parent = coreGui
        end
    end
end)

-- à¹پà¸œà¸™à¸ھà¸³à¸£à¸­à¸‡à¸ھà¸¸à¸”à¸—à¹‰à¸²à¸¢: à¸«à¸²à¸پà¸•à¸±à¸§à¸£à¸±à¸™ Delta à¸•à¸±à¸”à¸‚à¸²à¸”à¸ھà¸´à¸—à¸کà¸´à¹Œà¸—à¸±à¹‰à¸‡à¸«à¸،à¸” à¹ƒà¸«à¹‰à¹‚à¸¢à¸™à¹€à¸‚à¹‰à¸² PlayerGui à¹€à¸œà¸·à¹ˆà¸­à¹€à¸‹à¸ںà¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¹ƒà¸ٹà¹‰à¸‡à¸²à¸™
if not UI_Target_Parent then
    local lp = game:GetService("Players").LocalPlayer
    UI_Target_Parent = lp and lp:WaitForChild("PlayerGui", 10)
end

-- à¸ھà¸±à¹ˆà¸‡à¹€à¸£à¸´à¹ˆà¸،à¸ھà¸£à¹‰à¸²à¸‡ Instance ScreenGui à¹€à¸،à¸·à¹ˆà¸­à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¹پà¸¥à¹‰à¸§à¸§à¹ˆà¸²à¹‚à¸ںà¸¥à¹€à¸”à¸­à¸£à¹Œà¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡à¸‍à¸£à¹‰à¸­à¸،à¹ƒà¸ٹà¹‰à¸‡à¸²à¸™
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InvisHub_Horizontal_" .. math.random(100, 999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- à¸›à¹‰à¸­à¸‡à¸پà¸±à¸™à¸ˆà¸¸à¸”à¸•à¸²à¸¢ FindFirstChild à¸ڑà¸™à¸§à¸±à¸•à¸–à¸¸ Nil à¹‚à¸”à¸¢à¹€à¸‍à¸´à¹ˆà¸،à¸£à¸°à¸ڑà¸ڑà¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¹€à¸‡à¸·à¹ˆà¸­à¸™à¹„à¸‚à¸„à¸§à¸²à¸،à¸‍à¸£à¹‰à¸­à¸،
if UI_Target_Parent then
    ScreenGui.Parent = UI_Target_Parent
    shared._InvisHubStealthGui = ScreenGui
else
    -- à¸پà¸£à¸“à¸µà¸‰à¸¸à¸پà¹€à¸‰à¸´à¸™à¸£à¸°à¸”à¸±à¸ڑà¸ھà¸¹à¸‡à¸ھà¸¸à¸”à¹€à¸‍à¸·à¹ˆà¸­à¸«à¸¥à¸µà¸پà¹€à¸¥à¸µà¹ˆà¸¢à¸‡à¸‚à¹‰à¸­à¸œà¸´à¸”à¸‍à¸¥à¸²à¸”à¹ƒà¸™ Developer Console
    warn("[Invis Core UI Error]: All parental pipelines are severely restricted.")
end

-- â•گâ•گâ•گ CUSTOM STACK-SAFE NOTIFICATION GUI QUEUE â•گâ•گâ•گ
local NotificationHolder = Instance.new("Frame", ScreenGui)
NotificationHolder.Size = UDim2.new(0, 240, 0, 450)
NotificationHolder.Position = UDim2.new(1, -255, 0, 30)
NotificationHolder.BackgroundTransparency = 1
local notifyList = Instance.new("UIListLayout", NotificationHolder)
notifyList.Padding = UDim.new(0, 6)
notifyList.SortOrder = Enum.SortOrder.LayoutOrder

-- ًںژ¨ ULTIMATE CYBERPUNK DYNAMIC NOTIFICATION SYSTEM (WITH CLOSE BUTTON & AUTO-WRAP)
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local function CustomNotify(text, duration)
    duration = duration or 4
    local timeLeft = duration

    -- ًں“¦ 1. à¸ھà¸£à¹‰à¸²à¸‡à¸پà¸£à¸­à¸ڑà¸پà¸²à¸£à¹Œà¸”à¹پà¸ˆà¹‰à¸‡à¹€à¸•à¸·à¸­à¸™à¸«à¸¥à¸±à¸پ (Main Card Container)
    local card = Instance.new("Frame", NotificationHolder)
    card.Size = UDim2.new(1, 0, 0, 40) -- à¸‚à¸™à¸²à¸”à¹€à¸£à¸´à¹ˆà¸،à¸•à¹‰à¸™ 1 à¸ڑà¸£à¸£à¸—à¸±à¸”
    card.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    -- âœ¨ à¹€à¸­à¸ںà¹€à¸ںà¸پà¸•à¹Œà¸‚à¸­à¸ڑà¹€à¸£à¸·à¸­à¸‡à¹پà¸ھà¸‡à¹„à¸¥à¹ˆà¹€à¸‰à¸”à¸ھà¸µ (Modern Neon Stroke)
    local stroke = Instance.new("UIStroke", card)
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local strokeGradient = Instance.new("UIGradient", stroke)
    strokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 90)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(152, 181, 255))
    })

    -- ًںڈ·ï¸ڈ 2. à¹„à¸­à¸„à¸­à¸™à¹پà¸¥à¸°à¸‚à¹‰à¸­à¸„à¸§à¸²à¸،à¹پà¸ˆà¹‰à¸‡à¹€à¸•à¸·à¸­à¸™ (Icon & Dynamic Text Label)
    local txt = Instance.new("TextLabel", card)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.Size = UDim2.new(1, -65, 1, -4) -- à¹€à¸§à¹‰à¸™à¸‍à¸·à¹‰à¸™à¸—à¸µà¹ˆà¸”à¹‰à¸²à¸™à¸‚à¸§à¸²à¹ƒà¸«à¹‰à¸›à¸¸à¹ˆà¸، X à¹پà¸¥à¸°à¹€à¸§à¸¥à¸²à¸™à¸±à¸ڑà¸–à¸­à¸¢à¸«à¸¥à¸±à¸‡
    txt.Text = "ًں”” " .. text
    txt.TextColor3 = Color3.fromRGB(245, 245, 250)
    txt.FontFace = Font.fromEnum(Enum.Font.GothamBold)
    txt.TextSize = 11
    txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Center
    txt.TextWrapped = true -- à¹€à¸›à¸´à¸”à¹ƒà¸ٹà¹‰à¸‡à¸²à¸™à¸£à¸°à¸ڑà¸ڑà¸‚à¸¶à¹‰à¸™à¸ڑà¸£à¸£à¸—à¸±à¸”à¹ƒà¸«à¸،à¹ˆà¸­à¸±à¸•à¹‚à¸™à¸،à¸±à¸•à¸´

    -- ًں“گ [DYNAMIC RESIZING]: à¸„à¸³à¸™à¸§à¸“à¸„à¸§à¸²à¸،à¸¢à¸²à¸§à¸‚à¹‰à¸­à¸„à¸§à¸²à¸، à¸«à¸²à¸پà¸¢à¸²à¸§à¹€à¸پà¸´à¸™à¸«à¸™à¹‰à¸²à¸ˆà¸­à¹ƒà¸«à¹‰à¸‚à¸¢à¸²à¸¢à¸پà¸£à¸­à¸ڑà¹€à¸›à¹‡à¸™ 2 à¸ڑà¸£à¸£à¸—à¸±à¸”
    task.spawn(function()
        local maxTextWidth = NotificationHolder.AbsoluteSize.X - 75
        local textParams = Instance.new("GetTextBoundsParams")
        textParams.Text = txt.Text
        textParams.Font = Enum.Font.GothamBold
        textParams.Size = txt.TextSize
        textParams.Width = maxTextWidth

        local success, textBounds = pcall(function()
            return TextService:GetTextBoundsAsync(textParams)
        end)

        if success and textBounds.Y > 16 then
            -- à¸‚à¹‰à¸­à¸„à¸§à¸²à¸،à¸¢à¸²à¸§à¹€à¸پà¸´à¸™ 1 à¸ڑà¸£à¸£à¸—à¸±à¸” à¸‚à¸¢à¸²à¸¢à¸„à¸§à¸²à¸،à¸ھà¸¹à¸‡à¸‚à¸­à¸‡à¸پà¸²à¸£à¹Œà¸”à¹€à¸›à¹‡à¸™ 54px à¸ھà¸³à¸«à¸£à¸±à¸ڑ 2 à¸ڑà¸£à¸£à¸—à¸±à¸”
            card.Size = UDim2.new(1, 0, 0, 54)
        end
    end)

    -- âڈ±ï¸ڈ 3. à¸‚à¹‰à¸­à¸„à¸§à¸²à¸،à¹پà¸ھà¸”à¸‡à¹€à¸§à¸¥à¸²à¸™à¸±à¸ڑà¸–à¸­à¸¢à¸«à¸¥à¸±à¸‡ (Time Remaining Label)
    local timeLabel = Instance.new("TextLabel", card)
    timeLabel.Size = UDim2.new(0, 24, 0, 20)
    timeLabel.Position = UDim2.new(1, -52, 0.5, -10)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = tostring(math.ceil(timeLeft)) .. "s"
    timeLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    timeLabel.Font = Enum.Font.GothamSemibold
    timeLabel.TextSize = 10
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right

    -- ًں”ک 4. à¸›à¸¸à¹ˆà¸،à¸پà¸”à¸›à¸´à¸”à¹پà¸ڑà¸ڑà¹€à¸£à¹ˆà¸‡à¸”à¹ˆà¸§à¸™ (X Close Button)
    local closeBtn = Instance.new("TextButton", card)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -26, 0.5, -10)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "âœ•"
    closeBtn.TextColor3 = Color3.fromRGB(255, 75, 75)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false

    -- âڈ³ 5. à¸«à¸¥à¸­à¸”à¸„à¸§à¸²à¸،à¸„à¸·à¸ڑà¸«à¸™à¹‰à¸²à¹€à¸§à¸¥à¸²à¸”à¹‰à¸²à¸™à¸¥à¹ˆà¸²à¸‡à¸پà¸²à¸£à¹Œà¸” (Neon Progress Timeline Bar)
    local progressBar = Instance.new("Frame", card)
    progressBar.Size = UDim2.new(1, -16, 0, 2)
    progressBar.Position = UDim2.new(0, 8, 1, -4)
    progressBar.BackgroundColor3 = Color3.fromRGB(255, 60, 90)
    progressBar.BorderSizePixel = 0
    Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 1)

    local progressGradient = Instance.new("UIGradient", progressBar)
    progressGradient.Color = strokeGradient.Color

    -- ًںژ¬ 6. à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¹€à¸›à¸´à¸”à¸•à¸±à¸§à¸پà¸²à¸£à¹Œà¸”à¹پà¸ڑà¸ڑà¸ھà¸،à¸¹à¸— (Fade-In Transition Effect)
    card.BackgroundTransparency = 1
    txt.TextTransparency = 1
    stroke.Transparency = 1
    timeLabel.TextTransparency = 1
    closeBtn.TextTransparency = 1
    progressBar.BackgroundTransparency = 1

    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(txt, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
    TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Transparency = 0}):Play()
    TweenService:Create(timeLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
    TweenService:Create(closeBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
    TweenService:Create(progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()

    -- à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸«à¸¥à¸­à¸”à¹€à¸§à¸¥à¸²à¸„à¹ˆà¸­à¸¢à¹† à¸¢à¸¸à¸ڑà¸¥à¸‡à¸•à¸²à¸،à¸£à¸°à¸¢à¸°à¹€à¸§à¸¥à¸² Duration à¸ˆà¸£à¸´à¸‡
    local timelineTween = TweenService:Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
    timelineTween:Play()

    -- ًں”پ 7. à¸¥à¸¹à¸›à¸™à¸±à¸ڑà¸–à¸­à¸¢à¸«à¸¥à¸±à¸‡à¸­à¸±à¸›à¹€à¸”à¸•à¸•à¸±à¸§à¹€à¸¥à¸‚à¸§à¸´à¸™à¸²à¸—à¸µà¹پà¸ڑà¸ڑ Real-Time à¸—à¸¸à¸پà¹† 0.1 à¸§à¸´à¸™à¸²à¸—à¸µ
    local timerRunning = true
    task.spawn(function()
        while timeLeft > 0 and timerRunning do
            task.wait(0.1)
            timeLeft = timeLeft - 0.1
            if timeLabel and timeLabel.Parent then
                timeLabel.Text = tostring(math.ceil(timeLeft)) .. "s"
            end
        end
    end)

    -- ًںژ¬ 8. à¸ںà¸±à¸‡à¸پà¹Œà¸ٹà¸±à¸™à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¸›à¸´à¸”à¸پà¸²à¸£à¹Œà¸” (Fade-Out & Destroy Function)
    local isClosing = false
    local function fadeOutAndDestroy()
        if isClosing then return end
        isClosing = true
        timerRunning = false
        timelineTween:Cancel()

        local t1 = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)})
        local t2 = TweenService:Create(txt, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextTransparency = 1})
        local t3 = TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Transparency = 1})
        local t4 = TweenService:Create(timeLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextTransparency = 1})
        local t5 = TweenService:Create(closeBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextTransparency = 1})
        local t6 = TweenService:Create(progressBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})

        t1:Play() t2:Play() t3:Play() t4:Play() t5:Play() t6:Play()
        t1.Completed:Connect(function()
            card:Destroy()
        end)
    end

    -- âڑ، à¸œà¸¹à¸پà¹€à¸«à¸•à¸¸à¸پà¸²à¸£à¸“à¹Œ: à¸›à¸´à¸”à¸پà¸²à¸£à¹Œà¸”à¸—à¸±à¸™à¸—à¸µà¹€à¸،à¸·à¹ˆà¸­à¸پà¸”à¸›à¸¸à¹ˆà¸، X à¸«à¸£à¸·à¸­à¸›à¸¥à¹ˆà¸­à¸¢à¹ƒà¸«à¹‰à¸«à¸،à¸”à¹€à¸§à¸¥à¸²à¸•à¸²à¸،à¸پà¹چà¸²à¸«à¸™à¸”
    closeBtn.MouseButton1Click:Connect(fadeOutAndDestroy)
    task.delay(duration, function()
        if card and card.Parent then
            fadeOutAndDestroy()
        end
    end)

    -- à¹€à¸­à¸ںà¹€à¸ںà¸پà¸•à¹Œà¹‚à¸®à¹€à¸§à¸­à¸£à¹Œà¹€à¸،à¸²à¸ھà¹Œà¸›à¸¸à¹ˆà¸، X à¹€à¸‍à¸´à¹ˆà¸،à¸„à¸§à¸²à¸،à¸‍à¸£à¸µà¹€à¸،à¸µà¸¢à¸،
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 120, 120)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play() end)
end

local Auto_Parry = {}
getgenv().ZX_Parry = getgenv().ZX_Parry or { Hooked = true, KeyTable = "Ball", Remote = true } -- à¹€à¸‍à¸´à¹ˆà¸،à¸ڑà¸£à¸£à¸—à¸±à¸”à¸™à¸µà¹‰à¹€à¸‍à¸·à¹ˆà¸­à¸ھà¸£à¹‰à¸²à¸‡ Table à¸£à¸­à¸‡à¸£à¸±à¸ڑà¸‚à¹‰à¸­à¸،à¸¹à¸¥
local lastParryTime = 0
local parryCooldown = 0.035
local lastHitTick = 0
local lastTargetChecked = nil
local rallyCounter = 0
local lastBallPossession = nil
local Last_Parry = 0
local Cache_Update_Tick = 0
local Last_Positions_Cache = {}

-- â•گâ•گâ•گ ANTI-SPAM HIGH SPEED RALLY TRACKER â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
local rallyTracker = {
    lastTarget = nil,
    counter = 0,
    validRallies = 0,
    lastChangeTick = 0
}

getgenv()._ZX_VelHistory = getgenv()._ZX_VelHistory or { ball = {}, player = {}, MAX_SAMPLES = 7 }
local _ZX_VelHistory = getgenv()._ZX_VelHistory

local function _ZX_pushVelSample(target, pos, vel)
    local history = target == "ball" and _ZX_VelHistory.ball or _ZX_VelHistory.player
    table.insert(history, 1, { pos = pos, vel = vel, t = tick() })
    while #history > _ZX_VelHistory.MAX_SAMPLES do table.remove(history, #history) end
end

-- â•گâ•گâ•گ EMERGENCY DISTANCE CALCULATOR (OPTIMIZED FORMULA) â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
local function GetEmergencyDistance(speed)
    local calculated = 8 + (speed * 0.09)
    return math.clamp(calculated, 10, 75)
end

function Auto_Parry.Get_Ball()
    local bc = workspace:FindFirstChild("Balls") or workspace:FindFirstChild("TrainingBalls")
    if bc then
        for _, b in pairs(bc:GetChildren()) do
            if b:IsA("BasePart") and (b:GetAttribute("realBall") or b:GetAttribute("target")) then 
                return b 
            end
        end
    end
    
    -- ًںڑ¨ [BALL RESPAWN REBOOT SYSTEM] 
    -- à¹€à¸،à¸·à¹ˆà¸­à¹„à¸،à¹ˆà¹€à¸ˆà¸­à¸ڑà¸­à¸¥à¹ƒà¸™à¸ھà¸™à¸²à¸، (à¸ˆà¸±à¸‡à¸«à¸§à¸°à¸ڑà¸­à¸¥à¸¥à¸¹à¸پà¹€à¸پà¹ˆà¸²à¸•à¸²à¸¢ / à¸ڑà¸­à¸¥à¸پà¸³à¸¥à¸±à¸‡à¹€à¸پà¸´à¸”à¹ƒà¸«à¸،à¹ˆ) 
    -- à¸ھà¸±à¹ˆà¸‡à¸¥à¹‰à¸²à¸‡à¸ھà¸–à¸²à¸™à¸°à¸¥à¹‡à¸­à¸پ à¸„à¸¹à¸¥à¸”à¸²à¸§à¸™à¹Œ à¹پà¸¥à¸°à¸„à¸´à¸§à¸ھà¹پà¸›à¸،à¸—à¸¸à¸پà¸›à¸£à¸°à¹€à¸ à¸—à¸—à¸´à¹‰à¸‡à¸—à¸±à¸™à¸—à¸µ à¹€à¸‍à¸·à¹ˆà¸­à¸ڑà¸±à¸‡à¸„à¸±à¸ڑà¹ƒà¸«à¹‰à¹€à¸ںà¸£à¸،à¹پà¸£à¸پà¸‚à¸­à¸‡à¸ڑà¸­à¸¥à¸¥à¸¹à¸پà¹ƒà¸«à¸،à¹ˆà¸™à¸±à¸ڑà¹€à¸›à¹‡à¸™ "à¸•à¸µà¸›à¸پà¸•à¸´"
    shared.ManualSpamActive = false
    shared.LastSpamTime = 0
    if shared.Clicked_Target_Name then 
        shared.Clicked_Target_Name = nil 
    end
    
    -- âڑ، à¸¥à¹‰à¸²à¸‡à¸پà¸£à¸°à¸”à¸²à¸™à¸‚à¹‰à¸­à¸،à¸¹à¸¥à¸¥à¹‡à¸­à¸پà¸ںà¸´à¸ھà¸´à¸پà¸ھà¹Œ à¹€à¸‍à¸·à¹ˆà¸­à¸ھà¸پà¸±à¸”à¸پà¸±à¹‰à¸™à¸›à¸±à¸چà¸«à¸²à¸پà¸”à¹€à¸ڑà¸´à¹‰à¸¥à¸«à¸¥à¸²à¸¢à¸„à¸¥à¸´à¸پà¸‍à¸£à¹‰à¸­à¸،à¸پà¸±à¸™ (Anti-Multi Click)
    if type(parryLocked) == "table" then table.clear(parryLocked) end
    if type(lockTime) == "table" then table.clear(lockTime) end
    if type(lastHitTicks) == "table" then table.clear(lastHitTicks) end
    
    -- à¸ھà¸¥à¸±à¸ڑà¹‚à¸«à¸،à¸”à¸پà¸²à¸£à¸„à¸³à¸™à¸§à¸“à¹پà¸‍à¹‡à¸پà¹€à¸پà¹‡à¸•à¹€à¸™à¹‡à¸•à¹€à¸§à¸´à¸£à¹Œà¸پà¸پà¸¥à¸±à¸ڑà¸،à¸²à¹€à¸›à¹‡à¸™à¹‚à¸«à¸،à¸”à¸›à¸پà¸•à¸´ (isSpam = false)
    lastParryTime = 0
    
    return nil
end

function Auto_Parry.Get_Balls()
    local foundBalls = {}
    local mainFolder = workspace:FindFirstChild("Balls")
    local trainingFolder = workspace:FindFirstChild("TrainingBalls")
    
    if mainFolder then
        for _, b in ipairs(mainFolder:GetChildren()) do
            if b:IsA("BasePart") and (b:GetAttribute("realBall") or b:GetAttribute("target")) then
                b.CanCollide = false
                table.insert(foundBalls, b)
            end
        end
    end
    
    if trainingFolder then
        for _, b in ipairs(trainingFolder:GetChildren()) do
            if b:IsA("BasePart") and (b:GetAttribute("realBall") or b:GetAttribute("target")) then
                b.CanCollide = false
                table.insert(foundBalls, b)
            end
        end
    end
    
    return foundBalls
end

function Auto_Parry.GetTargetPlayer()
    local alive = workspace:FindFirstChild("Alive")
    local myChar = LocalPlayer.Character
    local cam = workspace.CurrentCamera

    if not alive or not myChar or not cam then return nil end

    -- ًں”’ à¸•à¸£à¸§à¸ˆà¸ھà¸­à¸ڑà¸£à¸°à¸ڑà¸ڑà¸¥à¹‡à¸­à¸پà¸”à¸±à¸ڑà¹€à¸ڑà¸´à¹‰à¸¥à¸„à¸¥à¸´à¸پà¸پà¹ˆà¸­à¸™
    if Config.TargetMode == "Double click" and shared.Clicked_Target_Name then
        local target = alive:FindFirstChild(shared.Clicked_Target_Name)
        if target and target:IsA("Model") and target ~= myChar and target:FindFirstChild("HumanoidRootPart") then
            return target
        end
    end

    local viewport = cam.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local MAX_SCREEN_DISTANCE = math.min(viewport.X, viewport.Y) * 0.45

    local bestTarget = nil
    local bestScreenDistance = math.huge
    local fallbackTarget = nil
    local shortestWorldDist = math.huge

    for _, target in ipairs(alive:GetChildren()) do
        if target:IsA("Model") and target ~= myChar then
            local hrp = target:FindFirstChild("HumanoidRootPart")
            if hrp then
                local worldDist = (myChar.HumanoidRootPart.Position - hrp.Position).Magnitude
                local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)

                if screenPos.Z > 0 then
                    local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if screenDistance <= MAX_SCREEN_DISTANCE and screenDistance < bestScreenDistance then
                        bestScreenDistance = screenDistance
                        bestTarget = target
                    end
                end

                -- [FIXED LOGIC]: à¹€à¸›à¸¥à¸µà¹ˆà¸¢à¸™à¸£à¸°à¸ڑà¸ڑà¸ھà¸¸à¹ˆà¸،à¹€à¸”à¸²à¸—à¸²à¸‡ à¹€à¸›à¹‡à¸™à¸«à¸²à¸œà¸¹à¹‰à¹€à¸¥à¹ˆà¸™à¸—à¸µà¹ˆà¸¢à¸·à¸™à¹ƒà¸پà¸¥à¹‰à¹€à¸£à¸²à¸—à¸µà¹ˆà¸ھà¸¸à¸”à¹ƒà¸™à¹پà¸،à¸‍à¹پà¸—à¸™à¹€à¸‍à¸·à¹ˆà¸­à¸„à¸§à¸²à¸،à¹€à¸ھà¸–à¸µà¸¢à¸£
                if worldDist < shortestWorldDist then
                    shortestWorldDist = worldDist
                    fallbackTarget = target
                end
            end
        end
    end

    return bestTarget or fallbackTarget
end

local CachedParryTracks = {} 
local LastParryAnimTime = 0   

function Auto_Parry.Parry_Animation()
    if not Config.SwordAnimationsEnabled then return end

    local now = os.clock()
    if now - LastParryAnimTime < 0.12 then return end
    LastParryAnimTime = now

    pcall(function()
        local player = LocalPlayer or game.Players.LocalPlayer
        local char = player and player.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if not animator then return end

        local currentSword = char:GetAttribute("CurrentlyEquippedSword") or "Default"
        local track = CachedParryTracks[currentSword]

        if not track or not track.Animation or not track.Parent then
            local parryAnimation = ReplicatedStorage.Shared.SwordAPI.Collection.Default:FindFirstChild("GrabParry")

            if currentSword ~= "Default" then
                local swordDataModule = ReplicatedStorage.Shared.ReplicatedInstances.Swords
                local swordInstances = require(swordDataModule)
                local swordInfo = swordInstances and swordInstances:GetSword(currentSword)
                
                if swordInfo and swordInfo["AnimationType"] then
                    local animFolder = ReplicatedStorage.Shared.SwordAPI.Collection:FindFirstChild(swordInfo["AnimationType"])
                    if animFolder then
                        parryAnimation = animFolder:FindFirstChild("GrabParry") or animFolder:FindFirstChild("Grab") or parryAnimation
                    end
                end
            end

            if parryAnimation then
                track = animator:LoadAnimation(parryAnimation)
                track.Priority = Enum.AnimationPriority.Action
                CachedParryTracks[currentSword] = track
            end
        end

        if track then
            track:Stop(0.02) 
            track:Play(0.05, 0.65, 1.35) 
        end
    end)
end

-- ًں§¼ à¸£à¸µà¹€à¸‹à¹‡à¸•à¸„à¸¥à¸±à¸‡à¹€à¸پà¹‡à¸ڑà¹€à¸،à¸·à¹ˆà¸­à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¹€à¸پà¸´à¸”à¹ƒà¸«à¸،à¹ˆ (à¸›à¹‰à¸­à¸‡à¸پà¸±à¸™à¸‚à¹‰à¸­à¸،à¸¹à¸¥à¹پà¸­à¸™à¸´à¹€à¸،à¸ٹà¸±à¸™à¹€à¸پà¹ˆà¸²à¸¢à¸±à¸‡à¸„à¹‰à¸²à¸‡à¸„à¸²à¸ڑà¸±à¸پ)
if LocalPlayer then
    LocalPlayer.CharacterAdded:Connect(function()
        table.clear(CachedParryTracks)
    end)
end

function Auto_Parry.CalculateParryCFrame(ball, targetPlayer)
    local cam = workspace.CurrentCamera
    if not targetPlayer or not targetPlayer.PrimaryPart or not cam then
        return targetPlayer and targetPlayer.PrimaryPart and targetPlayer.PrimaryPart.Position or Vector3.zero
    end
    
    local targetPos = targetPlayer.PrimaryPart.Position
    local targetHRP = targetPlayer.PrimaryPart
    
    -- [CRITICAL FIX]: à¸‹à¸´à¸‡à¸„à¹Œà¸ٹà¸·à¹ˆà¸­à¸•à¸±à¸§à¹پà¸›à¸£à¹ƒà¸«à¹‰à¸•à¸£à¸‡à¸پà¸±à¸ڑà¸£à¸°à¸ڑà¸ڑ UI à¸ھà¹„à¸¥à¸”à¹Œà¹€à¸،à¸™à¸¹ (ParryCurveMode)
    local parryCurveMode = Config.ParryCurveMode or "Camera"
    
    if parryCurveMode == "Camera" then
        return targetPos + (cam.CFrame.RightVector * 135) + (cam.CFrame.UpVector * 45)
    elseif parryCurveMode == "Left" then
        return targetPos + (cam.CFrame.RightVector * -145)
    elseif parryCurveMode == "Right" then
        return targetPos + (cam.CFrame.RightVector * 145)
    elseif parryCurveMode == "Up" then
        return targetPos + Vector3.new(0, 150, 0)
    elseif parryCurveMode == "Down" then
        return targetPos + (cam.CFrame.LookVector * -145) + Vector3.new(0, 35, 0)
    elseif parryCurveMode == "Random" then
        local enemyLook = targetHRP.CFrame.LookVector
        local enemyRight = targetHRP.CFrame.RightVector
        return targetPos + (enemyLook * math.random(-110, -60)) + (enemyRight * math.random(-90, 90)) + Vector3.new(0, math.random(15, 65), 0)
    elseif parryCurveMode == "Straight" then
        return targetPos
    end
    
    return targetPos
end
Auto_Parry.CalculateParryCframe = Auto_Parry.CalculateParryCFrame

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))

local _token
for _, Function in getgc(true) do
    if type(Function) ~= 'function' or not debug.info(Function, 's'):find('PRY', 1, true) then
        continue
    end

    for _, value in debug.getupvalues(Function) do
        if type(value) == 'function' then
            print('found.')
         
