-- Blade Ball Script - Bypass & Fluent UI (Per-Ball Lock Fix)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v3.4 (Per-Ball Lock Fix)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Auto", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Services & References
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryAccuracyValue = 90

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

-- Hooking Logic
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

-- Fire Parry Remote (SINGLE REMOTE ONLY)
local _parryRemote = nil
local _parryArgs = nil

local function FireParryBypass()
    if not _parryRemote then
        for _remote, _origArgs in pairs(_reverted) do
            _parryRemote = _remote
            _parryArgs = _origArgs
            break
        end
    end

    if not _parryRemote or not _parryArgs then return end

    local _packet = {
        _parryArgs[1],
        _parryArgs[2],
        _tokenize(_parryArgs[2]),
        0.5,
        workspace.CurrentCamera.CFrame,
        {},
        {0, 0},
        false
    }

    if _parryRemote:IsA('RemoteEvent') then
        _parryRemote:FireServer(unpack(_packet))
    elseif _parryRemote:IsA('RemoteFunction') then
        _parryRemote:InvokeServer(unpack(_packet))
    end
end

-- Get Current Ping
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- Auto Parry Loop (Per-Ball Lock - No Double Parry)
-- =========================================
task.spawn(function()
    local lastParryTime = 0
    local parriedBalls = {} -- {[ball] = parryTime}

    while task.wait() do
        if AutoParryEnabled then
            local character = LocalPlayer.Character
            if not character then continue end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            local playerPos = hrp.Position
            local ballsFolder = workspace:FindFirstChild("Balls")
            if not ballsFolder then continue end

            local currentPing = GetPing()
            local convertedAccuracy = 0.55 - ((ParryAccuracyValue / 100) * 0.45)
            local adjustedAccuracy = convertedAccuracy + (currentPing * 0.85)
            local safeCooldown = 0.20 + (currentPing * 0.5)

            local bestBall = nil
            local bestTime = math.huge

            for _, ball in ipairs(ballsFolder:GetChildren()) do
                if not ball:IsA("BasePart") then continue end
                local realAttr = ball:GetAttribute("realBall")
                if realAttr == false then continue end

                local ballPos = ball.Position
                local velocity = ball.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                if speed < 1 then continue end

                local directionToPlayer = (playerPos - ballPos).Unit
                local dotProduct = velocity:Dot(directionToPlayer)
                local distance = (playerPos - ballPos).Magnitude
                local isComingToMe = dotProduct > 0 or distance < 12

                local targetAttr = ball:GetAttribute("target")
                local isTarget = (targetAttr == nil) or (targetAttr == LocalPlayer.Name)

                -- إذا الكرة كانت مقفولة واتجاهها انعكس = نجح الصد → افتح القفل
                if parriedBalls[ball] then
                    if dotProduct < 0 then
                        parriedBalls[ball] = nil
                    elseif tick() - parriedBalls[ball] > 2 then
                        parriedBalls[ball] = nil
                    end
                end

                if isComingToMe and isTarget and not parriedBalls[ball] then
                    local timeToReach = distance / speed
                    if timeToReach <= adjustedAccuracy and timeToReach >= -0.08 then
                        if timeToReach < bestTime then
                            bestTime = timeToReach
                            bestBall = ball
                        end
                    end
                end
            end

            -- نصد مرة واحدة ونقفل الكرة
            if bestBall then
                if tick() - lastParryTime >= safeCooldown then
                    lastParryTime = tick()
                    parriedBalls[bestBall] = tick()
                    FireParryBypass()
                end
            end
        else
            parriedBalls = {}
        end
    end
end)

-- UI Controls
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry (Per-Ball Lock)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "1 = صد مبكر | 100 = صد متأخر مثالي (Perfect) - يُنصح بـ 90-100",
    Default = 90,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

-- =========================================
-- Manual Spam UI Button
-- =========================================
local SpamGui = Instance.new("ScreenGui")
SpamGui.Name = "SlaxSpamGui"
SpamGui.Parent = CoreGui
SpamGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local SpamBtn = Instance.new("TextButton")
SpamBtn.Name = "ManualSpamBtn"
SpamBtn.Parent = SpamGui
SpamBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
SpamBtn.BorderSizePixel = 0
SpamBtn.Position = UDim2.new(0.82, 0, 0.45, 0)
SpamBtn.Size = UDim2.new(0, 110, 0, 45)
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Text = "Spam"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 18
SpamBtn.AutoButtonColor = true

local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = SpamBtn
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 1.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local dragging, dragInput, dragStart, startPos
SpamBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = SpamBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

SpamBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        SpamBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function TriggerSpam()
    task.spawn(function()
        for i = 1, 5 do
            FireParryBypass()
            task.wait(0.015)
        end
    end)
end

SpamBtn.MouseButton1Click:Connect(function()
    TriggerSpam()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.E then
        TriggerSpam()
    end
end)

-- UI Settings Manager
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub Loaded ✅",
    Content = "Per-Ball Lock جاهز! ما راح يصد مرتين لنفس الكرة",
    Duration = 5
})
