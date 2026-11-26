local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local DataPing = Stats.Network.ServerStatsItem["Data Ping"]

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Oxy | Premium",
    SubTitle = "Predictive AI Engine",
    TabWidth = 145,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local CONFIG = {
    AutoParry = false,
    Accuracy = 100,
    Range = 45,
    HumanReaction = 0.1,
}

local token_fn = nil
for _, fn in getgc(true) do
    if type(fn) == "function" and debug.info(fn, "s"):find("PRY", 1, true) then
        for _, upval in debug.getupvalues(fn) do
            if type(upval) == "function" then
                token_fn = upval
                break
            end
        end
    end
    if token_fn then break end
end

if not token_fn then
    Window:Dialog({ Title = "Error", Content = "Executor not supported.", Buttons = {{Title = "OK", Callback = function() end}} })
    return
end

local function generateToken(data)
    local timeStr = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local secret = token_fn(data, "TIME")
    local output = {}
    for i = 1, #timeStr do
        output[i] = string.char(bit32.bxor((string.byte(timeStr, i) + i) % 256, string.byte(secret, (i - 1) % #secret + 1)))
    end
    return table.concat(output)
end

local captured_remote, captured_args = nil, nil
local hooked_mts = {}
local function hookRemote(remote)
    local mt = getrawmetatable(remote)
    if hooked_mts[mt] then return end
    hooked_mts[mt] = true
    setreadonly(mt, false)
    local old_index = mt.__index
    mt.__index = function(self, key)
        if key == "FireServer" then
            return function(obj, ...)
                local args = {...}
                if #args == 8 and typeof(args[5]) == "CFrame" and type(args[6]) == "table" then
                    captured_remote = obj
                    captured_args = args
                end
                return old_index(obj, key)(obj, ...)
            end
        end
        return old_index(self, key)
    end
    setreadonly(mt, true)
end

for _, obj in ReplicatedStorage:GetDescendants() do
    if obj:IsA("RemoteEvent") then
        pcall(hookRemote, obj)
    end
end

local last_parry = 0
local function fireParry()
    if not (captured_remote and captured_args) then return end
    if tick() - last_parry < 0.1 then return end
    
    local new_token = generateToken(captured_args[2])
    captured_args[3] = new_token
    captured_args[8] = false
    
    pcall(function()
        captured_remote:FireServer(unpack(captured_args))
    end)
    last_parry = tick()
end

local BallsFolder = Workspace:WaitForChild("Balls")
RunService.PreSimulation:Connect(function()
    if not CONFIG.AutoParry then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local ping = DataPing:GetValue()
    local accuracyMult = 1 + ((100 - CONFIG.Accuracy) / 100)
    
    for _, ball in BallsFolder:GetChildren() do
        if ball:GetAttribute("realBall") then
            local zoomies = ball:FindFirstChild("zoomies")
            if zoomies then
                local velocity = zoomies.VectorVelocity
                local speed = velocity.Magnitude
                if speed > 5 then
                    local distance = (hrp.Position - ball.Position).Magnitude
                    if distance <= CONFIG.Range then
                        local timeToImpact = distance / speed
                        local predictTime = (timeToImpact - (ping / 1000) - CONFIG.HumanReaction) * accuracyMult
                        
                        if predictTime <= 0.05 and predictTime > -0.2 then
                            fireParry()
                        end
                    end
                end
            end
        end
    end
end)

local CombatSection = Tabs.Combat:AddSection("Combat Settings")

CombatSection:AddToggle("AutoParryToggle", {
    Title = "Auto Parry [Predictive]",
    Default = CONFIG.AutoParry,
    Callback = function(state)
        CONFIG.AutoParry = state
        Fluent:Notify({ Title = "Oxy Premium", Content = state and "Auto-Parry: ENABLED" or "Auto-Parry: DISABLED", Duration = 3 })
    end
})

CombatSection:AddSlider("AccuracySlider", {
    Title = "Accuracy",
    Min = 1,
    Max = 100,
    Default = CONFIG.Accuracy,
    Rounding = 0,
    Callback = function(val)
        CONFIG.Accuracy = val
    end
})

CombatSection:AddSlider("RangeSlider", {
    Title = "Max Range",
    Min = 10,
    Max = 100,
    Default = CONFIG.Range,
    Rounding = 1,
    Callback = function(val)
        CONFIG.Range = val
    end
})

CombatSection:AddSlider("ReactionSlider", {
    Title = "Human Reaction (s)",
    Min = 0.01,
    Max = 0.5,
    Default = CONFIG.HumanReaction,
    Rounding = 2,
    Callback = function(val)
        CONFIG.HumanReaction = val
    end
})

local InfoSection = Tabs.Settings:AddSection("Information")
InfoSection:AddParagraph({
    Title = "Oxy Premium | God Mode",
    Content = "Developed for Blade Ball.\nPredictive TTI Engine integrated."
})

Fluent:Notify({ Title = "Oxy Premium", Content = "Interface Loaded successfully.", Duration = 5 })
