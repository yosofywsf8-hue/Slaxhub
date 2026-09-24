-- Blade Ball Script - Slax Hub v18.3 (Smart Double Parry)
-- Developed by yossef

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    Icon = "swords",
    Author = "yossef",
    Folder = "SlaxHub",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
    HasOutline = true,
})

Window:EditOpenButton({
    Title = "Open Slax Hub",
    Icon = "sword",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 80, 255)),
    OnlyMobile = false,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "sword" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local AutoSpamEnabled = false

-- ⚙️ Smart Double Parry Config
local CLOSE_COMBAT_RANGE = 30       -- مسافة "قريب من لاعب"
local GLOBAL_LOCK_FAR = 0.15        -- قفل قوي لما بعيد
local GLOBAL_LOCK_NEAR = 0.06       -- قفل خفيف لما قريب
local BALL_LOCK_DURATION = 0.5

-- =========================================
-- Token
-- =========================================
local _token = nil
for _, Function in getgc(true) do
    if type(Function) == 'function' and debug.info(Function, 's'):find('PRY', 1, true) then
        for _, value in debug.getupvalues(Function) do
            if type(value) == 'function' then
                _token = value
                break
            end
        end
        if _token then break end
    end
end

local function _tokenize(_remote_uid)
    if not _token then return "" end
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)
    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

-- =========================================
-- Hooking
-- =========================================
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)
        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent')) or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _arguments = {...}
                    if _is_valid(_arguments) and not _reverted[self] then
                        _reverted[self] = _arguments
                    end
                    return _old(self, key)(_, unpack(_arguments))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

-- =========================================
-- Cache Remotes
-- =========================================
local _parryRemote = nil
local _parryArgs = nil

local function GetParryRemote()
    if not _parryRemote or not _parryRemote.Parent then
        _parryRemote = nil
        _parryArgs = nil
        for r, a in pairs(_reverted) do
            _parryRemote = r
            _parryArgs = a
            break
        end
    end
    return _parryRemote, _parryArgs
end

-- =========================================
-- Fire
-- =========================================
local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end

    local packet = {
        args[1],
        args[2],
        _tokenize(args[2]),
        0.5,
        workspace.CurrentCamera.CFrame,
        {},
        {0, 0},
        false
    }
    if remote:IsA('RemoteEvent') then
        remote:FireServer(unpack(packet))
    elseif remote:IsA('RemoteFunction') then
        remote:InvokeServer(unpack(packet))
    end
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- 🎯 Close Combat Detection
-- =========================================
local NearPlayerCached = false

task.spawn(function()
    while task.wait(0.1) do
        if not AutoParryEnabled then
            NearPlayerCached = false
            continue
        end

        local character = LocalPlayer.Character
        if not character then
            NearPlayerCached = false
            continue
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            NearPlayerCached = false
            continue
        end

        local playerPos = hrp.Position
        NearPlayerCached = false

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local p_hrp = char:FindFirstChild("HumanoidRootPart")
            if not p_hrp then continue end
            if (p_hrp.Position - playerPos).Magnitude <= CLOSE_COMBAT_RANGE then
                NearPlayerCached = true
                break
            end
        end
    end
end)

-- =========================================
-- 🌀 Anti Curve
-- =========================================
local ballTracking = {}

local function TrackBall(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return 0, false end

    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = { lastVel = vel, curveScore = 0, curveActive = false }
        return 0, false
    end

    local prevDir = data.lastVel.Unit
    local currDir = vel.Unit
    local dot = prevDir:Dot(currDir)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))

    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
    else
        data.curveScore = data.curveScore * 0.95
    end

    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel

    return data.curveScore, data.curveActive
end

task.spawn(function()
    while task.wait(2) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then ballTracking[ball] = nil end
        end
    end
end)

-- =========================================
-- ⚔️ Auto Parry - Smart Double Parry
-- =========================================
local lastParryTime = 0
local ballLocks = {}

task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then
                ballLocks[ball] = nil
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        return
    end

    local now = tick()
    local ping = GetPing()

    -- 🎯 قفل ديناميكي: قوي لما بعيد، خفيف لما قريب
    local globalLock = NearPlayerCached and GLOBAL_LOCK_NEAR or GLOBAL_LOCK_FAR

    if (now - lastParryTime) < globalLock then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local balls = ballsFolder:GetChildren()

    for i = 1, #balls do
        local ball = balls[i]
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end

        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0.3 then continue end

        local distance = (playerPos - ballPos).Magnitude
        local timeToReach = distance / speed

        local _, curveActive = TrackBall(ball)
        local curveBonus = curveActive and math.min(0.2, ballTracking[ball].curveScore * 0.05) or 0

        local timeWindow = ping + 0.35 + curveBonus

        -- 🎯 لما قريب: نافذة أوسع (double parry)
        if NearPlayerCached then
            timeWindow = timeWindow + 0.1
        end

        if (timeToReach <= timeWindow) or (distance <= 25) then
            lastParryTime = now
            ballLocks[ball] = now + BALL_LOCK_DURATION
            FireParry()
            return
        end
    end
end)

-- =========================================
-- ⚡ Auto Spam - HEARTBEAT
-- =========================================
local lastSpamTime = 0
local spamPlayerCheck = 0
local nearPlayerSpam = false

RunService.Heartbeat:Connect(function()
    if not AutoSpamEnabled then return end

    local now = tick()

    if (now - spamPlayerCheck) > 0.05 then
        spamPlayerCheck = now

        local character = LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local playerPos = hrp.Position
                nearPlayerSpam = false

                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local c = p.Character
                        if c then
                            local p_hrp = c:FindFirstChild("HumanoidRootPart")
                            if p_hrp and (p_hrp.Position - playerPos).Magnitude <= 50 then
                                nearPlayerSpam = true
                                break
                            end
                        end
                    end
                end
            else
                nearPlayerSpam = false
            end
        else
            nearPlayerSpam = false
        end
    end

    if not nearPlayerSpam then return end
    if (now - lastSpamTime) < 0.016 then return end
    lastSpamTime = now

    local remote, args = GetParryRemote()
    if not remote or not args then return end

    for _ = 1, 5 do
        local packet = {
            args[1],
            args[2],
            _tokenize(args[2]),
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
            false
        }
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(packet))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(packet))
        end
    end
end)

-- =========================================
-- UI Controls
-- =========================================
MainTab:Toggle({
    Title = "⚔️ Auto Parry",
    Desc = "Smart: Double parry near players only",
    Value = false,
    Callback = function(Value)
        AutoParryEnabled = Value
        if not Value then
            ballTracking = {}
            ballLocks = {}
        end
    end
})

MainTab:Toggle({
    Title = "⚡ Auto Spam",
    Desc = "Spams near players (50 studs)",
    Value = false,
    Callback = function(Value)
        AutoSpamEnabled = Value
    end
})

SettingsTab:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
    end
})

WindUI:Notify({
    Title = "Slax Hub v18.3",
    Content = "Smart Double Parry - Only near players",
    Duration = 5
})
