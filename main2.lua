-- Blade Ball Script - Bypass & Fluent UI (Trajectory Fixed)
-- Slax Hub - Developed by yossef

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Blade Ball - Slax Hub",
    SubTitle = "v2.2 (Trajectory Fix)",
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
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AutoParryEnabled = false
local ParryDistance = 25

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

-- Fire Parry Remote manually via Bypass
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

-- Ball Retrieval
local function GetBall()
    for _, obj in pairs(workspace.Balls:GetChildren()) do
        if obj:GetAttribute("realBall") == true then
            return obj
        end
    end
    -- Fallback
    for _, obj in pairs(workspace.Balls:GetChildren()) do
        if obj:IsA("BasePart") then
            return obj
        end
    end
    return nil
end

-- Advanced Parry Loop with Direction (Dot Product)
task.spawn(function()
    while task.wait() do
        if AutoParryEnabled then
            local ball = GetBall()
            if ball then
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local playerPos = character.HumanoidRootPart.Position
                    local ballPos = ball.Position
                    local velocity = ball.AssemblyLinearVelocity
                    local distance = (playerPos - ballPos).Magnitude
                    
                    -- حساب اتجاه الكورة الفعلي
                    local directionToPlayer = (playerPos - ballPos).Unit
                    local approachSpeed = velocity:Dot(directionToPlayer)
                    
                    -- الكورة تقترب منك فقط إذا كان approachSpeed رقم موجب
                    if approachSpeed > 0 then
                        local timeToReach = distance / approachSpeed
                        local target = ball:GetAttribute("target")
                        local isTarget = (target == LocalPlayer.Name)

                        -- إذا كنت أنت المستهدف + الكورة متجهة لك + الوقت مناسب
                        if isTarget then
                            if timeToReach <= 0.35 or distance <= ParryDistance then
                                FireParryBypass()
                                task.wait(0.2) -- كول داون عشان ما يعلق (Spam)
                            end
                        -- لو ما كنت المستهدف بس الكورة قريبة جداً وبتضربك بالغلط (حماية إضافية)
                        elseif distance <= 12 and timeToReach <= 0.15 then
                            FireParryBypass()
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
end)

-- UI Controls
local Toggle = Tabs.Main:AddToggle("AutoParry", {Title = "Auto Parry (Smart Direction)", Default = false })
Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Tabs.Main:AddSlider("ParryDist", {
    Title = "Parry Distance",
    Description = "مسافة الصد (السكربت بيتجاهل الكور اللي ما تستهدفك)",
    Default = 25,
    Min = 10,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        ParryDistance = Value
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
    Content = "تم تحديث نظام الاتجاهات، السكربت ما راح يصد إلا لو الكورة متجهة لك!",
    Duration = 5
})
