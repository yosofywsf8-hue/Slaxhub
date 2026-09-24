-- Slax Hub - Simple Auto Parry
-- Developed by yossef

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════
local PARRY_DISTANCE = 20        -- مسافة الصد (studs)
local PING_COMP = 1.5            -- تعويض البينج
local COOLDOWN = 0.05            -- كولداون بين الصدات

-- ═══════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

print("[Slax] Loading Auto Parry...")

-- ═══════════════════════════════════════
-- TOKEN
-- ═══════════════════════════════════════
local _token = nil
for _, f in getgc(true) do
    if type(f) == 'function' and debug.info(f, 's'):find('PRY', 1, true) then
        for _, v in debug.getupvalues(f) do
            if type(v) == 'function' then
                _token = v
                break
            end
        end
        if _token then break end
    end
end

print("[Slax] Token: " .. (_token and "OK ✅" or "FAILED ❌"))

local function _tokenize(uid)
    if not _token then return "" end
    local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local k = _token(uid, 'TIME')
    local chars = table.create(#t)
    for i = 1, #t do
        chars[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(k, (i - 1) % #k + 1)
        ))
    end
    return table.concat(chars)
end

-- ═══════════════════════════════════════
-- HOOK
-- ═══════════════════════════════════════
local _reverted = {}
local _original = {}

local function _is_valid(args)
    return #args == 8 
        and type(args[2]) == "string" 
        and type(args[3]) == "string" 
        and type(args[4]) == "number" 
        and typeof(args[5]) == "CFrame" 
        and type(args[6]) == "table" 
        and type(args[7]) == "table" 
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _reverted[remote] and not _original[getrawmetatable(remote)] then
        _original[getrawmetatable(remote)] = true
        local _meta = getrawmetatable(remote)
        setreadonly(_meta, false)
        local _old = _meta.__index
        _meta.__index = function(self, key)
            if (key == 'FireServer' and self:IsA('RemoteEvent')) 
                or (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_, ...)
                    local _args = {...}
                    if _is_valid(_args) and not _reverted[self] then
                        _reverted[self] = _args
                    end
                    return _old(self, key)(_, unpack(_args))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end
end

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

print("[Slax] Hooks: " .. tostring(#_reverted))

-- ═══════════════════════════════════════
-- FIRE PARRY
-- ═══════════════════════════════════════
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

local function FireParry()
    local remote, args = GetParryRemote()
    if not remote or not args then return end
    local packet = {
        args[1], args[2], _tokenize(args[2]), 0.5,
        WS.CurrentCamera.CFrame, {}, {0, 0}, false
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

-- ═══════════════════════════════════════
-- AUTO PARRY LOOP
-- ═══════════════════════════════════════
local lastParryTime = 0
local ballLocks = {}

-- Cleanup
task.spawn(function()
    while task.wait(0.3) do
        local now = tick()
        for ball, t in pairs(ballLocks) do
            if not ball.Parent or now >= t then
                ballLocks[ball] = nil
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local now = tick()
    if (now - lastParryTime) < COOLDOWN then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local playerPos = hrp.Position
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    local ping = GetPing()
    local bestBall = nil
    local bestDistance = math.huge
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end
        
        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 5 then continue end
        
        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0.2 then continue end
        
        local distance = (playerPos - ballPos).Magnitude
        
        local pingDist = ping * speed * PING_COMP
        local triggerDist = PARRY_DISTANCE + pingDist
        
        if distance <= triggerDist then
            if distance < bestDistance then
                bestDistance = distance
                bestBall = ball
            end
        end
    end
    
    if bestBall then
        lastParryTime = now
        ballLocks[bestBall] = now + 0.5
        FireParry()
    end
end)

print("[Slax] ✅ Auto Parry ACTIVE - Distance: " .. PARRY_DISTANCE .. " studs")
print("[Slax] Press E to toggle ON/OFF")

-- ═══════════════════════════════════════
-- SIMPLE TOGGLE (E key)
-- ═══════════════════════════════════════
local UserInputService = game:GetService("UserInputService")
local Active = true

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        Active = not Active
        print("[Slax] Auto Parry: " .. (Active and "ON" or "OFF"))
    end
end)
