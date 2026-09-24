-- Blade Ball Script - Slax Hub v16.1 (RAW + Anti Curve)
-- Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v16.1 (Anti Curve)",
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
            0.5,
            workspace.CurrentCamera.CFrame,
            {},
            {0, 0},
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
-- 🌀 ANTI-CURVE SYSTEM
-- =========================================
-- نتتبع كل كرة: هل غيرت اتجاهها؟
-- =========================================
local ballTracking = {} -- {[ball] = {lastVel, curveScore, curveActive}}

local function TrackBall(ball)
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    if speed < 3 then return 0 end

    local data = ballTracking[ball]
    if not data then
        ballTracking[ball] = {
            lastVel = vel,
            lastSpeed = speed,
            curveScore = 0,
            curveActive = false
        }
        return 0
    end

    -- حساب الزاوية بين الاتجاه الحالي والسابق
    local prevDir = data.lastVel.Unit
    local currDir = vel.Unit
    local dot = prevDir:Dot(currDir)
    local angleChange = math.deg(math.acos(math.clamp(dot, -1, 1)))

    -- لو تغير الاتجاه بشكل كبير → الكرة تنحني
    -- العتبة: 5 درجات+ في الفريم = curve
    if angleChange > 3 then
        data.curveScore = data.curveScore + angleChange * 0.1
    else
        data.curveScore = data.curveScore * 0.95  -- decay
    end

    -- curveActive لو الـ curveScore > 1.5
    data.curveActive = data.curveScore > 1.5
    data.lastVel = vel
    data.lastSpeed = speed

    return data.curveScore, data.curveActive
end

-- تنظيف الكرات القديمة
task.spawn(function()
    while task.wait(1) do
        for ball in pairs(ballTracking) do
            if not ball.Parent then
                ballTracking[ball] = nil
            end
        end
    end
end)

-- =========================================
-- ⚔️ Auto Parry (RAW + Anti Curve)
-- =========================================
task.spawn(function()
    while task.wait(0.01) do
        if not AutoParryEnabled then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        local ping = GetPing()

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            -- 🌀 تتبع الانحناء
            local curveScore, curveActive = TrackBall(ball)

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0.3 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local timeToReach = distance / speed

            -- 🌀 تعويض الانحناء: نصد أبكر لو الكرة منحنية
            local curveBonus = 0
            if curveActive then
                -- كل ما زاد الانحناء → نصد أبكر
                curveBonus = math.min(0.2, curveScore * 0.05)
            end

            -- 🎯 الشرطان:
            -- 1. الوقت المتبقي ≤ ping + 0.35 + curveBonus
            -- 2. OR المسافة ≤ 25 stud
            local timeWindow = ping + 0.35 + curveBonus

            if (timeToReach <= timeWindow) or (distance <= 25) then
                FireParry()
                task.wait(0.05)
                break
            end
        end
    end
end)

-- =========================================
-- ⚡ Auto Spam
-- =========================================
task.spawn(function()
    while task.wait(0.02) do
        if not AutoSpamEnabled then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position

        local nearPlayer = false
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local p_hrp = char:FindFirstChild("HumanoidRootPart")
            if not p_hrp then continue end
            if (p_hrp.Position - playerPos).Magnitude <= 50 then
                nearPlayer = true
                break
            end
        end

        if not nearPlayer then continue end

        for _remote, _origArgs in pairs(_reverted) do
            local _tokens = {}
            for i = 1, 5 do
                _tokens[i] = _tokenize(_origArgs[2])
            end
            for i = 1, 5 do
                local _packet = {
                    _origArgs[1],
                    _origArgs[2],
                    _tokens[i],
                    0.5,
                    workspace.CurrentCamera.CFrame,
                    {},
                    {0, 0},
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
    end
end)

-- =========================================
-- UI
-- =========================================
local ParryToggle = Tabs.Main:AddToggle("AutoParry", {Title = "⚔️ Auto Parry", Default = false })
ParryToggle:OnChanged(function(Value)
    AutoParryEnabled = Value
    if not Value then
        ballTracking = {}
    end
end)

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
    Title = "Slax Hub v16.1",
    Content = "Anti-Curve Detection loaded",
    Duration = 5
})
