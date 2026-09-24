-- Blade Ball Script - Slax Hub v15.1 (Simple & Direct)
-- Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v15.1 (Simple & Direct)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local AutoSpamEnabled = false
local ParryAccuracyValue = 50

-- ⚙️ Hardcoded
local SPAM_POWER = 0.5
local SPAM_CURVE = 0
local SPAM_BURST = 5
local PROXIMITY_RANGE = 50

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
-- Fire
-- =========================================
local function FireParry()
    for _remote, _origArgs in pairs(_reverted) do
        local _packet = {
            _origArgs[1],
            _origArgs[2],
            _tokenize(_origArgs[2]),
            SPAM_POWER,
            workspace.CurrentCamera.CFrame,
            {},
            {SPAM_CURVE, 0},
            false
        }
        if _remote:IsA('RemoteEvent') then
            _remote:FireServer(unpack(_packet))
        elseif _remote:IsA('RemoteFunction') then
            _remote:InvokeServer(unpack(_packet))
        end
        break
    end
end

local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- ⚔️ Auto Parry (Simple + Direct)
-- =========================================
local lastParryTime = 0
local ballLocks = {}

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then
        ballLocks = {}
        lastParryTime = 0
        return
    end

    local now = tick()
    local currentPing = GetPing()

    -- تنظيف الأقفال
    for ball, t in pairs(ballLocks) do
        if not ball.Parent or (now - t) > 0.6 then
            ballLocks[ball] = nil
        end
    end

    -- كولداون
    if (now - lastParryTime) < (currentPing + 0.03) then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    -- Buffer بسيط: 50 = الافتراضي
    local buffer = 0.15 + ((ParryAccuracyValue / 100) * 0.25)
    local window = currentPing + buffer

    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if not ball:IsA("BasePart") then continue end
        if ball:GetAttribute("realBall") == false then continue end
        if ballLocks[ball] then continue end

        local ballPos = ball.Position
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        if speed < 3 then continue end

        -- هل الكرة جاية نحوي؟
        local toPlayer = (playerPos - ballPos).Unit
        local dot = velocity.Unit:Dot(toPlayer)
        if dot <= 0 then continue end

        local distance = (playerPos - ballPos).Magnitude
        local timeToReach = distance / speed

        -- ✅ الطريقة المباشرة:
        -- 1. لو الوقت المتوقع < window → اصد
        -- 2. لو المسافة < 15 stud → اصد فوراً (للأمان)
        if (timeToReach <= window and timeToReach > 0) or (distance < 15 and dot > 0.7) then
            lastParryTime = now
            ballLocks[ball] = now
            FireParry()
            break
        end
    end
end)

-- =========================================
-- ⚡ Auto Spam (Simple Proximity Check Every Frame)
-- =========================================
local lastSpamBurst = 0

RunService.Heartbeat:Connect(function()
    if not AutoSpamEnabled then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerPos = hrp.Position

    -- 🎯 افحص كل فريم: في لاعب قريب؟
    local playerNear = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local p_hrp = char:FindFirstChild("HumanoidRootPart")
        if not p_hrp then continue end
        if (p_hrp.Position - playerPos).Magnitude <= PROXIMITY_RANGE then
            playerNear = true
            break
        end
    end

    if not playerNear then return end

    -- في لاعب قريب → اسبم فوراً
    local now = tick()
    if (now - lastSpamBurst) < 0.016 then return end
    lastSpamBurst = now

    for _remote, _origArgs in pairs(_reverted) do
        local _tokens = {}
        for i = 1, SPAM_BURST do
            _tokens[i] = _tokenize(_origArgs[2])
        end
        for i = 1, SPAM_BURST do
            local _packet = {
                _origArgs[1],
                _origArgs[2],
                _tokens[i],
                SPAM_POWER,
                workspace.CurrentCamera.CFrame,
                {},
                {SPAM_CURVE, 0},
                false
            }
            if _remote:IsA('RemoteEvent') then
                _remote:FireServer(unpack(_packet))
            elseif _remote:IsA('RemoteFunction') then
                _remote:InvokeServer(unpack(_packet))
            end
        end
        break
    end
end)

-- =========================================
-- UI
-- =========================================
local ParryToggle = Tabs.Main:AddToggle("AutoParry", {Title = "⚔️ Auto Parry", Default = false })
ParryToggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = Early | 1 = Perfect",
    Default = 50,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

local SpamToggle = Tabs.Main:AddToggle("AutoSpam", {Title = "⚡ Auto Spam (Near Players)", Default = false })
SpamToggle:OnChanged(function(Value)
    AutoSpamEnabled = Value
end)

InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v15.1",
    Content = "Loaded - Simple & Direct",
    Duration = 5
})
