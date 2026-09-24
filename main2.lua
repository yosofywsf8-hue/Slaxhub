-- Blade Ball Script - Bypass & Fluent UI (Simple Powerful)
-- Slax Hub v10.0 - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v10.0 (Simple & Powerful)",
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

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))
local Stats = cloneref(game:GetService('Stats'))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryAccuracyValue = 25
local TriggerbotEnabled = false

-- =========================================
-- Token Retrieval
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
-- Fire Parry (Simple - works every time)
-- =========================================
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
        break  -- ريموت واحد فقط
    end
end

-- =========================================
-- Ping
-- =========================================
local function GetPing()
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    return math.clamp(ping, 0.02, 0.4)
end

-- =========================================
-- 🎯 TRIGGERBOT LOOP
-- =========================================
task.spawn(function()
    local lastTriggerTime = 0
    while task.wait() do
        if not TriggerbotEnabled then lastTriggerTime = 0 continue end
        local now = tick()
        if (now - lastTriggerTime) < 0.08 then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0.2 then continue end

            if (playerPos - ballPos).Magnitude > 18 then continue end

            lastTriggerTime = now
            FireParryBypass()
            break
        end
    end
end)

-- =========================================
-- ⚔️ Auto Parry Loop (SIMPLE - WORKS EVERY TIME)
-- =========================================
task.spawn(function()
    local lastFire = 0

    while task.wait() do
        if not AutoParryEnabled then
            lastFire = 0
            continue
        end

        local now = tick()
        local currentPing = GetPing()

        -- كولداون صغير جدا (يمنع spam فقط)
        if (now - lastFire) < (currentPing + 0.03) then continue end

        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local playerPos = hrp.Position
        local ballsFolder = workspace:FindFirstChild("Balls")
        if not ballsFolder then continue end

        -- النافذة: وقت الوصول لازم يكون <= ping + buffer
        local buffer = 0.05 + ((ParryAccuracyValue / 100) * 0.35)
        local window = currentPing + buffer

        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if not ball:IsA("BasePart") then continue end
            if ball:GetAttribute("realBall") == false then continue end

            local ballPos = ball.Position
            local velocity = ball.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            if speed < 3 then continue end

            local toPlayer = (playerPos - ballPos).Unit
            local dot = velocity.Unit:Dot(toPlayer)
            if dot <= 0 then continue end

            local distance = (playerPos - ballPos).Magnitude
            local timeToReach = distance / speed

            -- 🎯 نصد فقط لما الوقت مناسب
            if timeToReach <= window and timeToReach >= 0 then
                lastFire = now
                FireParryBypass()
                break
            end
        end
    end
end)

-- =========================================
-- 📱 Floating Triggerbot Button
-- =========================================
local function GetGuiParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local ok2, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
    if ok2 and pg then return pg end
    return CoreGui
end

local TriggerGui = Instance.new("ScreenGui")
TriggerGui.Name = "SlaxTriggerBot_" .. tostring(math.random(1, 99999))
TriggerGui.Parent = GetGuiParent()
TriggerGui.ResetOnSpawn = false
TriggerGui.IgnoreGuiInset = true
TriggerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TriggerGui.DisplayOrder = 999
TriggerGui.Enabled = true

local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name = "TriggerBtn"
TriggerBtn.Parent = TriggerGui
TriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
TriggerBtn.BorderSizePixel = 0
TriggerBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
TriggerBtn.Size = UDim2.new(0, 160, 0, 55)
TriggerBtn.Font = Enum.Font.GothamBold
TriggerBtn.Text = "🎯 Trigger: OFF"
TriggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerBtn.TextSize = 17
TriggerBtn.AutoButtonColor = false
TriggerBtn.Active = true
TriggerBtn.Selectable = true
TriggerBtn.Modal = false

local TriggerCorner = Instance.new("UICorner")
TriggerCorner.CornerRadius = UDim.new(0, 10)
TriggerCorner.Parent = TriggerBtn

local TriggerStroke = Instance.new("UIStroke")
TriggerStroke.Parent = TriggerBtn
TriggerStroke.Color = Color3.fromRGB(255, 255, 255)
TriggerStroke.Thickness = 2

local TriggerToggle = nil

local function UpdateBtnVisual(skipToggle)
    if TriggerbotEnabled then
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        TriggerBtn.Text = "🎯 Trigger: ON"
        TriggerStroke.Color = Color3.fromRGB(180, 255, 200)
    else
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        TriggerBtn.Text = "🎯 Trigger: OFF"
        TriggerStroke.Color = Color3.fromRGB(255, 255, 255)
    end

    if not skipToggle and TriggerToggle then
        pcall(function()
            TriggerToggle:SetValue(TriggerbotEnabled)
        end)
    end
end

-- 🖐️ Drag + Press
local pressing = false
local pressStart = nil
local pressStartPos = nil
local dragMoved = false
local lastToggleTime = 0

TriggerBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        pressing = true
        dragMoved = false
        pressStart = input.Position
        pressStartPos = TriggerBtn.Position
    end
end)

TriggerBtn.InputChanged:Connect(function(input)
    if pressing and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - pressStart
        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            dragMoved = true
        end
        TriggerBtn.Position = UDim2.new(
            pressStartPos.X.Scale, pressStartPos.X.Offset + delta.X,
            pressStartPos.Y.Scale, pressStartPos.Y.Offset + delta.Y
        )
    end
end)

TriggerBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if pressing and not dragMoved then
            local now = tick()
            if now - lastToggleTime > 0.6 then
                lastToggleTime = now
                TriggerbotEnabled = not TriggerbotEnabled
                UpdateBtnVisual(false)
            end
        end
        pressing = false
    end
end)

-- =========================================
-- UI Controls
-- =========================================
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "⚔️ Auto Parry (Simple)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryAccuracy", {
    Title = "Parry Accuracy",
    Description = "100 = صد مبكر | 1 = صد مثالي - يُنصح بـ 20-35",
    Default = 25,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        ParryAccuracyValue = Value
    end
})

TriggerToggle = Tabs.Main:AddToggle("Triggerbot", {Title = "🎯 Triggerbot (MAX POWER)", Default = false })
TriggerToggle:OnChanged(function(Value)
    TriggerbotEnabled = Value
    UpdateBtnVisual(true)
end)

-- =========================================
-- Settings
-- =========================================
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Slax Hub v10.0 🔥",
    Content = "Simple Auto Parry - يصد كل الكرات بدون تعليق",
    Duration = 6
})
