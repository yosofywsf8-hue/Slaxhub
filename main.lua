-- [[ SLAX HUB - INTEGRATED VERSION ]] --
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- // [ الإعدادات العامة ] // --
local cfg = {
    parry = true,
    spam = false,
    cps = 200,
    accuracy = 3.3,
    animfix = true,
    curveType = 'straight'
}

local parried_balls = {}
local AnimationCache = {}
local spamActive = false
local lastSpamTime = 0
local Lerp_Radians = 0
local Last_Warping = tick()

-- // [ Sword API & Animations ] // --
local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")

local function GetPing()
    local success, result = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and result or 100
end

-- // [ كشف انحناء الكرة (Curve Detection) ] // --
local function Is_Curved(ball)
    local Zoomies = ball:FindFirstChild("zoomies")
    if not Zoomies then return false end
    
    local Velocity = Zoomies.VectorVelocity
    local Character = player.Character
    if not Character or not Character.PrimaryPart then return false end

    -- حد 25 وحدة: عدم تجاهل الكرة إذا كانت قريبة جداً
    local distanceToBall = (Character.PrimaryPart.Position - ball.Position).Magnitude
    if distanceToBall <= 25 then
        return false
    end

    local Speed = Velocity.Magnitude
    local Direction = (Character.PrimaryPart.Position - ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)

    local Ping = GetPing() / 1000
    local Distance = (Character.PrimaryPart.Position - ball.Position).Magnitude
    local Reach_Time = Distance / Speed - Ping
    local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
    Lerp_Radians = Lerp_Radians + (Radians - Lerp_Radians) * 0.8

    if Lerp_Radians < 0.018 then
        Last_Warping = tick()
    end

    if (tick() - Last_Warping) < (Reach_Time / 1.5) then
        return true
    end
    return Dot < (0.5 - Ping)
end

-- // [ أنيميشن الصد ] // --
local function GetParryAnimation()
    local char = player.Character
    local currentSword = char and char:GetAttribute("CurrentlyEquippedSword")
    if not currentSword then
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    if AnimationCache[currentSword] then
        return AnimationCache[currentSword]
    end
    local success, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(currentSword)
    end)
    if success and type(swordData) == "table" then
        for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
            if obj.Name == swordData.AnimationType then
                local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
                if anim then
                    AnimationCache[currentSword] = anim
                    return anim
                end
            end
        end
    end
    return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
end

local function PlayParryAnimation()
    if not cfg.animfix then return end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum:FindFirstChild("Animator") then return end
    local animation = GetParryAnimation()
    if not animation then return end
    for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name:find("Grab") or track.Name:find("Parry") then
            track:Stop(0.1)
        end
    end
    local track = hum.Animator:LoadAnimation(animation)
    track:Play(0, 1, 1)
end

-- // [ تطبيق منحنى الاتجاه (Curve Angle) ] // --
local function ApplyCurveToCFrame(baseCFrame)
    if not cfg.curveType or cfg.curveType == 'straight' then
        return baseCFrame
    end
    local rotation = CFrame.new()
    if cfg.curveType == 'backwards' then
        rotation = CFrame.Angles(0, math.rad(180), 0)
    elseif cfg.curveType == 'down' then
        rotation = CFrame.Angles(math.rad(-45), 0, 0)
    elseif cfg.curveType == 'up' then
        rotation = CFrame.Angles(math.rad(45), 0, 0)
    elseif cfg.curveType == 'left' then
        rotation = CFrame.Angles(0, math.rad(-90), 0)
    elseif cfg.curveType == 'right' then
        rotation = CFrame.Angles(0, math.rad(90), 0)
    elseif cfg.curveType == 'random' then
        local randomAngle = math.random() * math.pi * 2
        rotation = CFrame.Angles(0, randomAngle, 0)
    end
    return baseCFrame * rotation
end

-- // [ استخراج بيانات التشفير والريموت ] // --
local function GetParryData()
    local viewportSize = Camera.ViewportSize
    local centerPos = { viewportSize.X / 2, viewportSize.Y / 2 }
    local events = {}
    for _, v in pairs(workspace.Alive:GetChildren()) do
        if v ~= player.Character and v:FindFirstChild("HumanoidRootPart") then
            local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.HumanoidRootPart.Position)
            if isOnScreen then
                events[tostring(v)] = screenPos
            end
        end
    end
    return Camera.CFrame, events, centerPos
end

local PRY = require(ReplicatedStorage:FindFirstChild('PRY', true))
local Network = getupvalue(PRY, 6)
local Constants = getupvalue(PRY, 3)
local Convert = getupvalue(PRY, 4)

local Hash1 = getupvalue(PRY, 8)
local Hash2 = Constants[2]
local Hash3 = function()
    local Constant = Convert(Hash2, 'TIME')
    local Time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local Encoded = {}
    for i = 1, #Time do
        local s1 = string.byte(Constant, ((i - 1) % #Constant) + 1)
        Encoded[i] = string.char(bit32.bxor((string.byte(Time, i) + i) % 256, s1))
    end
    return table.concat(Encoded)
end

local ParryRemote = nil
do
    local RemoteName = string.gsub(game.JobId, '-', '')
    local GetRemote = Network.RemoteEvent
    task.spawn(function()
        setthreadidentity(2)
        setfenv(0, getfenv(PRY))
        setfenv(1, getfenv(PRY))
        ParryRemote = GetRemote(Network, RemoteName)
    end)
end

-- // [ إرسال أمر الصد (Send Parry) ] // --
local function SendParry()
    if not ParryRemote then return false end
    local camCF, events, mousePos = GetParryData()
    local modifiedCF = ApplyCurveToCFrame(camCF)
    local success, err = pcall(function()
        ParryRemote:FireServer(
            Hash1,
            Hash2,
            Hash3(),
            0.025,
            modifiedCF,
            events,
            mousePos,
            false
        )
    end)
    if success and cfg.animfix then
        task.spawn(PlayParryAnimation)
    end
    return success
end

-- // [ نظام Auto Parry الرئيسي ] // --
local function ProcessAutoParry(ball)
    if not cfg.parry or spamActive then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name or parried_balls[bID] then
        return
    end
    if Is_Curved(ball) then
        return
    end
    local charPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not charPart then return end
    
    local velocity = ball.zoomies.VectorVelocity
    local ballPos = ball.Position
    local playerPos = charPart.Position
    local dist = (playerPos - ballPos).Magnitude
    local ping = GetPing()
    local threshold = (velocity.Magnitude / cfg.accuracy) + (ping / 10)
    
    if dist <= threshold or dist <= 20 then
        parried_balls[bID] = true
        SendParry()
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

-- // [ خيط السبام السريع (Spam Loop) ] // --
task.spawn(function()
    while true do
        if spamActive and ParryRemote then
            local delay = 1 / cfg.cps
            if tick() - lastSpamTime >= delay then
                SendParry()
                lastSpamTime = tick()
            end
        end
        task.wait(0.001)
    end
end)

-- // [ الحلقة الرئيسية (Heartbeat Loop) ] // --
RunService.Heartbeat:Connect(function()
    if not ParryRemote then return end
    local ball = nil
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then
            ball = v
            break
        end
    end
    if ball then
        if not spamActive and cfg.parry then
            ProcessAutoParry(ball)
        end
    end
end)

-- إيقاف الأنيميشن عند نجاح الصد من السيرفر
ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum:FindFirstChild("Animator") then return end
    for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name:find("Grab") or track.Name:find("Parry") then
            track:Stop(0.1)
        end
    end
end)
