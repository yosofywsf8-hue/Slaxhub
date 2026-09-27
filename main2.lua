-- Blade Ball AutoParry — community version, minimal, no dependency
-- Based on the token bypass you gave me
local cloneref = cloneref or function(o) return o end
local RS = cloneref(game:GetService("ReplicatedStorage"))
local WS = cloneref(game:GetService("Workspace"))
local LP = cloneref(game:GetService("Players")).LocalPlayer

-- step 1: cari token function
local _token
for _, f in ipairs(getgc(true)) do
    if type(f) ~= "function" then continue end
    local ok, src = pcall(debug.info, f, "s")
    if not ok or type(src) ~= "string" then continue end
    if not src:find("PRY", 1, true) then continue end
    for _, up in ipairs(debug.getupvalues(f)) do
        if type(up) == "function" then
            _token = up
            break
        end
    end
    if _token then break end
end

if not _token then
    warn("token fn nggak ketemu — executor lo kurang (butuh getgc + debug.getupvalues)")
    return
end
print("token fn OK")

-- step 2: hook remote
local _reverted = {}
local _original = {}

for _, r in ipairs(RS:GetDescendants()) do
    if not (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then continue end
    local mt = getrawmetatable(r)
    if not mt or mt.__BBHOOK then continue end
    mt.__BBHOOK = true
    setreadonly(mt, false)
    local old = mt.__index
    mt.__index = function(self, key)
        if key == "FireServer" or key == "InvokeServer" then
            return function(_, ...)
                local a = { ... }
                if #a == 8 and type(a[2]) == "string" and type(a[3]) == "string" and typeof(a[5]) == "CFrame" then
                    if not _original[self] then
                        _original[self] = a
                    end
                end
                return old(self, key)(_, ...)
            end
        end
        return old(self, key)
    end
    setreadonly(mt, true)
end

print("remotes hooked — parry manual sekali")

-- step 3: tunggu capture
while not next(_original) do task.wait(0.5) end
local remote, args = next(_original)
print("captured!")

-- step 4: loop parry
while task.wait(0.1) do
    local uid = args[2]
    local t = tostring(math.floor(WS:GetServerTimeNow() * 100))
    local key = _token(uid, "TIME")
    local out = table.create(#t)
    for i = 1, #t do
        out[i] = string.char(bit32.bxor(
            (string.byte(t, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)))
    end
    local packet = {
        args[1], uid, table.concat(out), 0.5,
        WS.CurrentCamera.CFrame, {}, {0, 0}, false
    }
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(packet))
        else
            remote:InvokeServer(table.unpack(packet))
        end
    end)
end
