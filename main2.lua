-- ═══════════════════════════════════════════════════════
-- Slax Hub - Wind UI & Advanced Auto Parry (V2)
-- Developed by yossef
-- ═══════════════════════════════════════════════════════

if not LPH_OBFUSCATED then
    LPH_ENCFUNC = function(func) return func end
    LPH_NO_VIRTUALIZE = function(func) return func end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════
-- 🔐 TOKEN RETRIEVAL & BYPASS SYSTEM
-- ═══════════════════════════════════════════════════════
local _token = nil
local _tokenFound = false

for _, Function in getgc(true) do
    if type(Function) ~= 'function' then continue end
    local ok, name = pcall(function() return debug.info(Function, 's') end)
    if not ok or not name or not tostring(name):find('PRY', 1, true) then continue end
    
    for _, value in debug.getupvalues(Function) do
        if type(value) == 'function' then
            _token = value
            _tokenFound = true
            break
        end
    end
    if _token then break end
end

if not _tokenFound then
    warn("❌ Token NOT FOUND - Auto Parry won't work! Make sure you are in Blade Ball.")
else
    print("✅ Token Found Successfully!")
end

local function _tokenize(_remote_uid)
    if not _token then return "" end
    local time = tostring(math.floor(WS:GetServerTimeNow() * 100))
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

-- 🎣 REMOTE HOOKING
local _reverted = {}
local _original = {}
local _capturedRemote = nil
local _capturedArgs = nil

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
    pcall(function()
        if _reverted[remote] then return end
        if _original[getrawmetatable(remote)] then return end
        
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
                        _capturedRemote = self
                        _capturedArgs = _args
                        print("🎣 Remote captured:", self.Name)
                    end
                    return _old(self, key)(_, unpack(_args))
                end
            end
            return _old(self, key)
        end
        setreadonly(_meta, true)
    end)
end

for _, r in pairs(RS:GetDescendants()) do
    if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then
        _hook(r)
    end
end

-- 🎯 FIRE PARRY
local Alive = WS:FindFirstChild("Alive") or WS:WaitForChild("Alive", 10)

local function FireParry()
    if not _capturedRemote or not _capturedArgs then return false end
    
    local cam = WS.CurrentCamera
    local vp = cam.ViewportSize
    local aimTarget = {math.floor(vp.X / 2), math.floor(vp.Y / 2)}
    
    local eventData = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                if ok then eventData[entity.Name] = sp end
            end
        end
    end
    
    local packet = {
        _capturedArgs[1], _capturedArgs[2], _tokenize(_capturedArgs[2]), 0.5, cam.CFrame, eventData, aimTarget, false
    }
    
    local ok = pcall(function()
        if _capturedRemote:IsA('RemoteEvent') then
            _capturedRemote:FireServer(unpack(packet))
        elseif _capturedRemote:IsA('RemoteFunction') then
            _capturedRemote:InvokeServer(unpack(packet))
        end
    end)
    return ok
end

local function IsAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return true, char, hrp
end

-- ═══════════════════════════════════════════════════════
-- 📱 WIND UI SETUP
-- ═══════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/macaw.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Slax Hub | Blade Ball",
    Icon = "lucide-swords",
    Author = "yossef",
    Folder = "SlaxHub_Config",
    Size = UDim2.fromOffset(550, 400),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 160,
    HasOutline = true
})

-- زر الهاتف العائم
Window:EditOpenButton({
    Title = "Slax Hub",
    Icon = "lucide-shield",
    CornerRadius = UDim.new(0, 10),
    StrokeThickness = 2,
    StrokeColor = Color3.fromRGB(60, 60, 80)
})

local MainTab = Window:Tab({
    Title = "Combat",
    Icon = "lucide-shield-alert"
})

local AUTO_PARRY_ENABLED = true

MainTab:Toggle({
    Title = "Auto Parry Bypass",
    Desc = "Advanced prediction formula (Flyte-like)",
    Value = true,
    Callback = function(state)
        AUTO_PARRY_ENABLED = state
    end
})

MainTab:Keybind({
    Title = "Toggle Auto Parry",
    Desc = "Press E to quickly enable/disable",
    Value = "E",
    Callback = function()
        AUTO_PARRY_ENABLED = not AUTO_PARRY_ENABLED
        WindUI:Notify({
            Title = "Slax Hub",
            Content = AUTO_PARRY_ENABLED and "Auto Parry: ENABLED" or "Auto Parry: DISABLED",
            Duration = 2,
            Icon = "lucide-info"
        })
    end
})

-- ═══════════════════════════════════════════════════════
-- 🔥 V2 ADVANCED PREDICTION PARRY
-- ═══════════════════════════════════════════════════════
local parriedBalls = {}

RunService.PreSimulation:Connect(function()
    if not AUTO_PARRY_ENABLED then return end
    
    local alive, char, hrp = IsAlive()
    if not alive then return end
    
    if hrp:FindFirstChild("SingularityCape") then return end
    
    local ballsFolder = WS:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    local playerPos = hrp.Position
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute('realBall') == false then continue end
        if parriedBalls[ball] then continue end
        
        local ballTarget = ball:GetAttribute('target')
        if ballTarget ~= LocalPlayer.Name then continue end
        
        local zoomies = ball:FindFirstChild('zoomies')
        if not zoomies then continue end
        
        local velocity = zoomies.VectorVelocity
        local speed = velocity.Magnitude
        if speed < 5 then continue end
        
        local directionToPlayer = (playerPos - ball.Position).Unit
        local dot = velocity.Unit:Dot(directionToPlayer)
        if dot <= 0.1 then continue end 
        
        if ball:FindFirstChild('ComboCounter') then continue end
        
        local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 1000
        local pingCompensation = math.clamp(ping, 0.03, 0.2)
        
        local expectedPosition = ball.Position + (velocity * pingCompensation)
        local distance = (playerPos - expectedPosition).Magnitude
        
        local baseRange = 12.5
        local speedFactor = speed / 4.5
        
        if speed > 120 then
            speedFactor = speedFactor + (speed / 15)
        end
        
        local parryAccuracy = baseRange + speedFactor
        local actualDistance = (playerPos - ball.Position).Magnitude
        
        if distance <= parryAccuracy or actualDistance <= (baseRange + 5) then
            FireParry()
            parriedBalls[ball] = true
            
            task.delay(0.4, function()
                if parriedBalls[ball] then parriedBalls[ball] = nil end
            end)
            break
        end
    end
end)
