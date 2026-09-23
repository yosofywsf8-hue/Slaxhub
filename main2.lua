-- Blade Ball Script - Bypass & Fluent UI (CPS Customization Edition)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v3.1 (CPS Customization)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Auto", Icon = "swords" }),
    Spam = Window:AddTab({ Title = "Spam Modes", Icon = "zap" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Services & References
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryAccuracyValue = 8

local AutoSpamEnabled = false
local ManualSpamEnabled = false
local SpamDistance = 14
local SpamCPS = 200 -- الـ CPS الطبيعي الافتراضي

-- Token Retrieval Logic
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

-- Hooking Logic for Remote Capture
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

-- Fire Parry Remote
local function FireParryBypass()
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
    end
end

-- Find Ball
local function GetBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") and obj:GetAttribute("realBall") == true then
                return obj
            end
        end
        for _, obj in pairs(ballsFolder:GetChildren()) do
            if obj:IsA("BasePart") then
                return obj
            end
        end
    end
    return nil
end

-- Get Current Ping in Seconds
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- Main Auto Parry Loop Logic
task.spawn(function()
    local lastParryTime = 0

    while task.wait(0.003) do
        if AutoParryEnabled and not ManualSpamEnabled then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local distance = (playerPos - ballPos).Magnitude
                    local velocity = ball.AssemblyLinearVelocity
                    local speed = velocity.Magnitude

                    local directionToPlayer = (playerPos - ballPos).Unit
                    local dotProduct = velocity:Dot(directionToPlayer)

                    local target = ball:GetAttribute("target")
                    local isTarget = (target == LocalPlayer.Name)

                    local timeToReach = (speed > 0) and (distance / speed) or 999

                    -- Auto Spam Logic عند المسافة القريبة
                    if AutoSpamEnabled and distance <= SpamDistance then
                        FireParryBypass()
                        task.wait(1 / SpamCPS)
                    elseif isTarget and dotProduct > 0 then
                        local convertedAccuracy = 0.45 - ((ParryAccuracyValue / 10) * 0.29)
                        local currentPing = GetPing()
                        local adjustedAccuracy = convertedAccuracy + (currentPing * 0.7)
                        local safeCooldown = 0.35 + (currentPing * 1.2)

                        if timeToReach <= adjustedAccuracy then
                            if tick() - lastParryTime >= safeCooldown then
                                lastParryTime = tick()
                                FireParryBypass()
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Manual Spam Loop Logic (Controlled by CPS)
task.spawn(function()
    while true do
        if ManualSpamEnabled then
            FireParryBypass()
            task.wait(1 / SpamCPS)
        else
            task.wait(0.01)
        end
    end
end)

-- Main Controls
local ToggleAuto = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry (Ping Adaptive)", Default = false })
ToggleAuto:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "درجة الدقة من 1 إلى 10",
    Default = 8,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- Spam Mode Controls
local ToggleAutoSpam = Tabs.Spam:AddToggle("AutoSpam", {Title = "Enable Auto Spam", Default = false })
ToggleAutoSpam:OnChanged(function(Value)
    AutoSpamEnabled = Value
end)

local ToggleManualSpam = Tabs.Spam:AddToggle("ManualSpam", {Title = "Enable Manual Spam", Default = false })
ToggleManualSpam:OnChanged(function(Value)
    ManualSpamEnabled = Value
end)

Tabs.Spam:AddSlider("SpamCPS", {
    Title = "Spam Speed (CPS)",
    Description = "حدد عدد الضغطات في الثانية (طبيعي: 200 - أقصى حد: 500)",
    Default = 200,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        SpamCPS = Value
    end
})

Tabs.Spam:AddSlider("SpamDist", {
    Title = "Auto Spam Distance",
    Description = "المسافة القريبة للبدء التلقائي في السبام (الموصى بها: 12 - 16)",
    Default = 14,
    Min = 5,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        SpamDistance = Value
    end
})

-- UI Settings Manager
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "تم ضبط الـ CPS للسبام حتى 500 بنجاح!",
    Duration = 5
})
