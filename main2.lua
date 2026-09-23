local cloneref = cloneref or function(o) return o end
local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))

-- ==========================================
-- 1. استخراج التوكن (Token Finder)
-- ==========================================
local _token = nil
for _, Function in getgc(true) do
    if type(Function) ~= 'function' or not debug.info(Function, 's'):find('PRY', 1, true) then
        continue
    end

    for _, value in debug.getupvalues(Function) do
        if type(value) == 'function' then
            _token = value
            break
        end
    end

    if _token then
        break
    end
end

-- ==========================================
-- 2. دالة التشفير (Tokenize)
-- ==========================================
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

-- ==========================================
-- 3. التقاط الـ Remotes
-- ==========================================
local _reverted = {}
local _original_meta = {}

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
    if not _reverted[remote] then
        local meta = getrawmetatable(remote)
        if meta and not _original_meta[meta] then
            _original_meta[meta] = true
            setreadonly(meta, false)

            local _old = meta.__index
            meta.__index = function(self, key)
                if (key == 'FireServer' and self:IsA('RemoteEvent')) or
                   (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
                    return function(_, ...)
                        local _arguments = {...}
                        if _is_valid(_arguments) then
                            if not _reverted[self] then
                                _reverted[self] = _arguments
                            end
                        end
                        return _old(self, key)(_, unpack(_arguments))
                    end
                end
                return _old(self, key)
            end
            setreadonly(meta, true)
        end
    end
end

for _, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

-- ==========================================
-- 4. المتغير والإنهاء الذكي للحلقة
-- ==========================================
local AutoParryEnabled = false

task.spawn(function()
    while task.wait() do
        if AutoParryEnabled then
            for _remote, _original in pairs(_reverted) do
                local _packet = {
                    _original[1],
                    _original[2],
                    _tokenize(_original[2]),
                    0.5,
                    workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new(),
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
    end
end)

-- ==========================================
-- 5. واجهة المستخدم (Fluent UI / Slax Hub)
-- ==========================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "by yossef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "rbxassetid://4483345998" })
}

-- خيار التشغيل والإيقاف
local Toggle = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry",
    Default = false
})

Toggle:OnChanged(function(Value)
    AutoParryEnabled = Value
end)

Window:SelectTab(1)
