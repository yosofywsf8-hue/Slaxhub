--// Bypass + Autoparry
--// One script. Clean.

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace_service = cloneref(game:GetService('Workspace'))
local run_service = game:GetService('RunService')
local players = game:GetService('Players')
local user_input = game:GetService('UserInputService')

local local_player = players.LocalPlayer

--// ============ BYPASS ============

local _token
for _, Function in getgc(true) do
    if type(Function) ~= 'function' then continue end
    local src = debug.info(Function, 's')
    if not src then continue end

    for _, pattern in ipairs({'PRY', 'Parry', 'parry', 'Deflect'}) do
        if src:find(pattern, 1, true) then
            for _, value in debug.getupvalues(Function) do
                if type(value) == 'function' then
                    local params = debug.info(value, 'u') or 0
                    if params == 2 then
                        _token = value
                        break
                    end
                end
            end
            if _token then break end
        end
    end
    if _token then break end
end

assert(_token, 'token function not found — game updated?')

local function _tokenize(_remote_uid)
    local time = tostring(math.floor(workspace_service:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local out = table.create(#time)

    for i = 1, #time do
        out[i] = string.char(bit32.bxor(
            (string.byte(time, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)
        ))
    end

    return table.concat(out)
end

--// ============ CAPTURE ============

local _template = nil
local _target_remote = nil
local _captured = false

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == 'string'
        and type(args[3]) == 'string'
        and type(args[4]) == 'number'
        and typeof(args[5]) == 'CFrame'
        and type(args[6]) == 'table'
        and type(args[7]) == 'table'
        and type(args[8]) == 'boolean'
end

-- single hook via __namecall
local old_namecall
old_namecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if (method == 'FireServer' or method == 'InvokeServer')
        and not _captured
        and (self:IsA('RemoteEvent') or self:IsA('RemoteFunction')) then

        local args = {...}

        if _is_valid(args) then
            _template = args
            _target_remote = self
            _captured = true
            print(string.format('[BB] Captured | remote: %s | path: %s',
                self.Name, self:GetFullName()))
        end
    end

    return old_namecall(self, ...)
end))

--// ============ AUTOPARRY ============

local enabled = false
local hotkey = Enum.KeyCode.H
local parry_count = 0
local last_parry = 0
local min_gap = 0.08 -- don't go below 0.06, server rate limits

local ball_cache = nil
local last_scan = 0

local function find_ball()
    local now = os.clock()
    if ball_cache and ball_cache.Parent and (now - last_scan) < 1 then
        return ball_cache
    end
    last_scan = now

    for _, name in ipairs({'Ball', 'ball', 'Projectile', 'NeonBall', 'Orb'}) do
        local b = workspace_service:FindFirstChild(name)
        if b and b:IsA('BasePart') then
            ball_cache = b
            return b
        end
    end

    for _, obj in ipairs(workspace_service:GetChildren()) do
        if obj:IsA('BasePart') then
            local vel = obj.AssemblyLinearVelocity or Vector3.zero
            if vel.Magnitude > 40 then
                local lower = string.lower(obj.Name)
                if lower:find('ball') or lower:find('orb') or lower:find('proj') then
                    ball_cache = obj
                    return obj
                end
            end
        end
    end

    ball_cache = nil
    return nil
end

local function fire_parry()
    if not _captured or not _target_remote or not _template then
        return false
    end

    local uid = _template[2]
    local fresh_token = _tokenize(uid)

    local packet = {
        _template[1],
        uid,
        fresh_token,
        _template[4],
        workspace_service.CurrentCamera.CFrame,
        _template[6],
        _template[7],
        _template[8],
    }

    if _target_remote:IsA('RemoteEvent') then
        _target_remote:FireServer(unpack(packet))
    else
        pcall(function()
            _target_remote:InvokeServer(unpack(packet))
        end)
    end

    parry_count += 1
    last_parry = os.clock()
    return true
end

--// ============ PREDICTION ENGINE ============
-- Ball trajectory prediction with acceleration compensation

local function get_parry_timing(ball)
    local char = local_player.Character
    if not char then return nil, math.huge end
    local root = char:FindFirstChild('HumanoidRootPart')
    if not root then return nil, math.huge end

    local ball_pos = ball.Position
    local ball_vel = ball.AssemblyLinearVelocity or Vector3.zero
    local my_pos = root.Position

    if ball_vel.Magnitude < 5 then return false, math.huge end

    local to_me = (my_pos - ball_pos).Unit
    local direction = ball_vel.Unit
    local dot = direction:Dot(to_me)

    -- ball heading toward us
    local approaching = dot > 0.65

    -- distance
    local dist = (ball_pos - my_pos).Magnitude

    -- closing speed (how fast the ball is approaching our position)
    local closing_speed = ball_vel:Dot(to_me)
    if closing_speed < 1 then return false, math.huge end

    -- time to impact (linear)
    local tti = dist / closing_speed

    -- curved balls: predict next position by sampling velocity direction change
    -- most blade ball balls follow a slight homing curve
    local predicted_pos = ball_pos + ball_vel * tti
    local predicted_dist = (predicted_pos - my_pos).Magnitude
    local predicted_tti = predicted_dist / closing_speed

    -- use the more conservative (longer) estimate
    local best_tti = math.max(tti, predicted_tti)

    return approaching, best_tti
end

--// ============ MAIN LOOP ============

run_service.Heartbeat:Connect(function()
    if not enabled then return end
    if not _captured then return end

    local now = os.clock()
    if now - last_parry < min_gap then return end

    local ball = find_ball()
    if not ball then return end

    local approaching, tti = get_parry_timing(ball)
    if not approaching then return end

    -- parry when ball is about to hit us (within 0.35s of impact)
    if tti < 0.35 then
        fire_parry()
    end
end)

--// ============ HOTKEY ============

user_input.InputBegan:Connect(function(input, game_processed)
    if game_processed then return end
    if input.KeyCode == hotkey then
        if not _captured then
            print('[BB] Parry manually once first to capture the packet.')
            return
        end
        enabled = not enabled
        print(string.format('[BB] Autoparry: %s | Parries: %d',
            enabled and 'ON' or 'OFF', parry_count))
    end
end)

--// ============ WATCHER ============

task.spawn(function()
    while not _captured do
        task.wait(0.1)
    end
    print('[BB] Template captured.')
    print(string.format('[BB] Press %s to toggle autoparry.', hotkey.Name))
end)

print('[BB] Bypass loaded. Parry once manually to capture.')
