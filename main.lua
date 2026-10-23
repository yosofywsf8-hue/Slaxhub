--[[
    ██╗   ██╗██╗██╗   ██╗ ██████╗
    Vivo — UI FIRST | Engine background | BindToClose fixed
]]
if _G.primas then return end
_G.primas = true

local function log(msg)
    pcall(function() print("[Vivo] " .. tostring(msg)) end)
end
log("1. mulai")

if setfpscap then pcall(setfpscap, 9999) end
repeat task.wait() until game:IsLoaded()
log("2. game loaded")

cloneref = cloneref or function(x) return x end

local Players          = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService       = cloneref(game:GetService("RunService"))
local HttpService      = cloneref(game:GetService("HttpService"))
local VirtualInputManager = Instance.new("VirtualInputManager")
local LocalPlayer      = Players.LocalPlayer
local playerGui        = LocalPlayer:WaitForChild("PlayerGui")

local Library = { Flags = {}, Keybinds = {} }

-- =========================================================
-- CONFIG (sebelum UI, karena UI load dari config)
-- =========================================================
local function save_config()
    pcall(function()
        if not isfolder or not writefile then return end
        if not isfolder("Vivo") then makefolder("Vivo") end
        writefile("Vivo/config.json", HttpService:JSONEncode(Library.Flags))
    end)
end

local function load_config()
    pcall(function()
        if not isfile or not readfile then return end
        if isfile("Vivo/config.json") then
            local data = HttpService:JSONDecode(readfile("Vivo/config.json"))
            for k, v in pairs(data) do Library.Flags[k] = v end
        end
    end)
end
load_config()

-- Auto-save tiap 5 detik — BUKAN BindToClose
task.spawn(function()
    while task.wait(5) do save_config() end
end)

-- Simpan saat player keluar (client-safe)
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer.Parent then save_config() end
end)

log("3. config ready")

-- =========================================================
-- UI FIRST
-- =========================================================
log("4. load Fluent")
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
log("5. Fluent ready")

local Window = Fluent:CreateWindow({
    Title = "Vivo",
    SubTitle = "",
    TabWidth = 100,
    Size = UDim2.fromOffset(440, 315),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl,
})
log("6. Window ready")

local MainTab   = Window:AddTab({ Title = "main",   Icon = "shield" })
local VisualTab = Window:AddTab({ Title = "visual", Icon = "eye" })
log("7. Tabs ready")

Fluent:Notify({ Title = "Vivo", Content = "جاري تحميل المحرك...", Duration = 4 })

-- defaults
Library.Flags.Parry_Type          = Library.Flags.Parry_Type or "Camera"
Library.Flags.Parry_Options       = Library.Flags.Parry_Options or "Remote"
Library.Flags.Clashing_Threshold  = Library.Flags.Clashing_Threshold or "1"
Library.Flags.Parry_Range         = Library.Flags.Parry_Range or 0
Library.Flags.Parry_Accuracy      = Library.Flags.Parry_Accuracy or 72

-- =========================================================
-- STATE (deklarasi awal — engine pakai ini)
-- =========================================================
local Connections_Manager = {}
local Auto_Parry = {}
local Parry_Abilities, Infinity_Ball, Tornado_Time, Parries, Speed_Divisor_Multiplier
local Last_Parry, Parried, Got_Phantomed
local Is_Curved_Data = {}
local Last_FFA_Target = nil
local Vector2_Mouse_Location = {0, 0}
local Last_Played, Bypass_Cd = 0, false
local Is_Mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local touchEnabled = UserInputService.TouchEnabled
local Real_Ball_Position, Tracked_Ball, Block_Keybind, Play_Parry

do
    Parry_Abilities = {
        "Calming Deflection","Raging Deflection","Rapture","Aerodynamic Slash",
        "Forcefield","Infinity","Fracture","Death Slash","Slashes of Fury",
    }
    Infinity_Ball = false
    Tornado_Time = nil
    Last_Parry = 0
    Parried = false
    Parries = 0
    Got_Phantomed = false
    Speed_Divisor_Multiplier = 0.8 + (Library.Flags.Parry_Accuracy - 1) *
        (Library.Flags.Phantom_Detection and 0.024747474747474751 or 0.0030303030303030303)
end

-- =========================================================
-- ENGINE di task.spawn — UI tetap hidup
-- =========================================================
task.spawn(function()
    log("8. engine start")

    local ok_engine, err_engine = pcall(function()
        -- ---- require yang lambat ----
        local ReplicatedInstances = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReplicatedInstances")
        local Swords = require(ReplicatedInstances:WaitForChild("Swords"))
        local balls = workspace:WaitForChild("Balls")

        -- ---- settings ----
        pcall(function()
            Block_Keybind = playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind1.TextBox.Text
                or playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind2.TextBox.Text
                or playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind3.TextBox.Text
        end)
        Block_Keybind = Block_Keybind or "Q"

        -- ---- real ball position ----
        pcall(function()
            local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
            for _, child in net:GetChildren() do
                if child:IsA("UnreliableRemoteEvent") and child.Name ~= "URE/ReplicateBallPosition" then
                    Connections_Manager["Real Ball Position"] = child.OnClientEvent:Connect(function(arg, arg2)
                        if not arg or not arg.Parent then
                            if arg == Tracked_Ball then
                                Tracked_Ball, Real_Ball_Position = nil, nil
                            end
                            return
                        end
                        Tracked_Ball, Real_Ball_Position = arg, arg2
                    end)
                end
            end
        end)

        -- ---- capture play_parry + disable old ----
        for _, connection in getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent) do
            connection:Disable(); connection:Disconnect()
        end
        for _, connection in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
            if connection and connection.Function then
                Play_Parry = connection.Function
                connection:Disable(); connection:Disconnect()
            end
        end

        -- ---- VFX fix ----
        if Play_Parry then
            Connections_Manager["Weapon Changer Event"] = ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
                local varargs = { ... }
                if tostring(varargs[4]) == LocalPlayer.Name then
                    local sword2 = Swords:GetSword(LocalPlayer:GetAttribute("CurrentlyEquippedSword"))
                    if sword2 and sword2.SlashName then
                        varargs[1] = sword2.SlashName
                        varargs[3] = sword2.Name
                    end
                end
                return Play_Parry(unpack(varargs))
            end)
        end

        Connections_Manager["Parry Animation Fix"] = ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
            Bypass_Cd = true
            Parried = false
        end)

        -- ---- parry sender (bisa lambat) ----
        local playerData = require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data")
        local serverInfo = require(ReplicatedStorage.ServerInfo)
        local universeIds = require(ReplicatedStorage.Shared.UniverseIds)
        local noobParry = not serverInfo.isDungeonsMatchServer()
            and game.PlaceId ~= universeIds.RankedMatches.PlaceId
            and game.PlaceId ~= universeIds.RankedMatchesNoAbility.PlaceId
            and not serverInfo.isMedalServer()
            and not serverInfo.isClanWarServer()
            and not serverInfo.isTournamentMatchServer()
            and require(ReplicatedStorage.Common.Utils).FFlag.GetInstantFFlag("NoobParryEnabled", true)

        local parryFunction = require(ReplicatedStorage.Controllers["SwordsController \012"].PRY)
        local encoder = debug.getupvalue(parryFunction, 4)
        local hash = debug.getupvalue(parryFunction, 8)

        local remote, key, timeKey
        local timeHash = {}
        local durations = {1.5, 1.25, 1, 0.75, 0.625}
        local signal = require(ReplicatedStorage.Packages.Signal).new()
        signal:Connect(parryFunction)

        LocalPlayer.CharacterAdded:Connect(function()
            remote, key, timeKey = nil, nil, nil
        end)

        local function capture(event, eventHash, eventKey, proof, duration, direction, targets, aim, flag)
            if eventHash == hash and type(eventKey) == "string" and type(proof) == "string"
                and type(duration) == "number" and typeof(direction) == "CFrame"
                and type(targets) == "table" and type(aim) == "table" and type(flag) == "boolean" then
                remote, key = event, eventKey
            end
        end

        local fireServer
        fireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(event, ...)
            if not remote and not checkcaller() then
                capture(event, ...)
            end
            return fireServer(event, ...)
        end))

        sendParry = function(direction, targets, aim)
            local idx = math.min((playerData:Get("timesParried") or 0) + 1, #durations)
            local duration = durations[idx] or 0.5
            if noobParry then
                local kills = playerData:Get("TotalStats.Kills") or 0
                duration = kills < 20 and duration * kills / 20 or duration
            end
            if not key then
                pcall(function() signal:Fire(duration, direction, targets, aim, false) end)
                return false
            end
            local okE, tk = pcall(function() return encoder(key, "TIME") end)
            if not okE or type(tk) ~= "string" then
                local ok2, tk2 = pcall(function() return encoder(key, "NONCE") end)
                if ok2 and type(tk2) == "string" then timeKey = tk2
                else
                    pcall(function() signal:Fire(duration, direction, targets, aim, false) end)
                    return false
                end
            else
                timeKey = tk
            end
            local stamp = tostring(math.floor(workspace:GetServerTimeNow() * 100))
            table.clear(timeHash)
            local ok3 = pcall(function()
                for index = 1, #stamp do
                    timeHash[index] = string.char(bit32.bxor(
                        (string.byte(stamp, index) + index) % 256,
                        string.byte(timeKey, (index - 1) % #timeKey + 1)
                    ))
                end
            end)
            if not ok3 then
                pcall(function() signal:Fire(duration, direction, targets, aim, false) end)
                return false
            end
            local ok4 = pcall(function()
                fireServer(remote, hash, key, table.concat(timeHash), duration, direction, targets, aim, false)
            end)
            if not ok4 then
                pcall(function() signal:Fire(duration, direction, targets, aim, false) end)
                return false
            end
            return true
        end

        -- ---- fungsi ball ----
        Auto_Parry.Client_Ball = function()
            for _, child in workspace.Balls:GetChildren() do
                if not child:GetAttribute("realBall") then return child end
            end
        end
        Auto_Parry.Get_Ball = function()
            for _, child in balls:GetChildren() do
                if child:GetAttribute("realBall") then return child end
            end
        end
        Auto_Parry.Get_Balls = function()
            local list = {}
            for _, child in balls:GetChildren() do
                if child:GetAttribute("realBall") then table.insert(list, child) end
            end
            return list
        end

        -- ---- target selection (singkat) ----
        Auto_Parry.Get_Ping = function()
            local ok, value = pcall(function()
                return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            return ok and value or LocalPlayer:GetNetworkPing() * 1000
        end

        Auto_Parry.Linear_Interpolation = function(a, b, t) return a + (b - a) * t end

        -- ---- curve ----
        Auto_Parry.Encrypted_Clone = function()
            for _, child in workspace.Alive:GetChildren() do
                if child and child.Name and child.Name:find("ENCRYPTED CLONE", 1, true) then
                    return child
                end
            end
        end

        Auto_Parry.Get_Curve = function(ball)
            if Is_Curved_Data[ball] then return Is_Curved_Data[ball] end
            local data = { Curving=0, Lerp_Radians=0, Last_Warping=0, Dot=0, Flips=0, Flip_Time=0,
                Backward_Dot=0, Backward_Flips=0, Backward_Flip_Time=0, Returned=false, Target_Count=0 }
            Is_Curved_Data[ball] = data
            local function update()
                local from = ball:GetAttribute("from")
                local clone = Auto_Parry.Encrypted_Clone()
                local name = clone and clone.Name
                if from == LocalPlayer.Name and data.First_Hit then data.Returned = true
                elseif from and from ~= "" and from ~= LocalPlayer.Name and from ~= name then
                    data.First_Hit = data.First_Hit or from
                    data.Returned = false
                end
            end
            data.From = ball:GetAttributeChangedSignal("from"):Connect(update)
            data.Target = ball:GetAttributeChangedSignal("target"):Connect(function()
                Parried = false
                data.Target_Count += 1
                data.Triggerbot_Parried = false
                if Auto_Parry.Triggerbot then Auto_Parry.Triggerbot(ball, true) end
            end)
            update()
            return data
        end

        -- ---- Is_Curved ----
        local function Targeted_Ball()
            for _, ball in Auto_Parry.Get_Balls() do
                if ball:GetAttribute("target") == LocalPlayer.Name then return ball end
            end
        end

        Auto_Parry.Is_Curved = function(Ball)
            Ball = Ball or Targeted_Ball()
            local Character = LocalPlayer.Character
            local PrimaryPart = Character and Character.PrimaryPart
            if not Ball or not PrimaryPart or Ball:GetAttribute("target") ~= LocalPlayer.Name then return false end
            local Zoomies = Ball:FindFirstChild("zoomies")
            if not Zoomies then return false end
            local Velocity = Zoomies.VectorVelocity
            local Ball_Position = Ball == Tracked_Ball and Real_Ball_Position or Ball.Position
            local Offset = PrimaryPart.Position - Ball_Position
            local Speed = Velocity.Magnitude
            local Distance = Offset.Magnitude
            if Speed < 0.001 or Distance < 0.001 then return false end
            local Curve_Data = Auto_Parry.Get_Curve(Ball)
            local Ball_Direction = Velocity.Unit
            local Direction = Offset.Unit
            local Dot = Direction:Dot(Ball_Direction)
            local Speed_Threshold = math.min(Speed / 100, 40)
            local Direction_Difference = Ball_Direction - Velocity
            local Dot_Difference = Direction_Difference.Magnitude > 0.001 and math.clamp(Dot - Direction:Dot(Direction_Difference.Unit), -1, 1) or Dot
            local Pings = Auto_Parry.Get_Ping()
            local Dot_Threshold = 0.5 - Pings / 1000
            local Angle_Threshold = 20 * math.max(Dot, 0)
            local Reach_Time = math.max(0, Distance / Speed - Pings / 1000)
            local Ball_Distance_Threshold = 15 - math.min(Distance / 1000, 15) + Angle_Threshold + Speed_Threshold
            local Singularity = PrimaryPart:FindFirstChild("SingularityCape")
            local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
            local Time = os.clock()

            if not Singularity and math.sign(Dot) ~= math.sign(Curve_Data.Dot) then
                if Time - Curve_Data.Flip_Time < 0.2 then Curve_Data.Flips += 1 else Curve_Data.Flips = 0 end
                Curve_Data.Flip_Time = Time
            end
            Curve_Data.Dot = Dot
            Curve_Data.Lerp_Radians = Auto_Parry.Linear_Interpolation(Curve_Data.Lerp_Radians, Radians, 0.8)
            if Speed > 100 and Reach_Time > Pings / 10 then
                Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
            end
            if Curve_Data.Flips >= 5 then return false end
            if Distance < 10 then return false end
            if Dot < 0 then return true end
            if Distance < Ball_Distance_Threshold then return false end
            if Dot_Difference < Dot_Threshold then return true end
            if Curve_Data.Lerp_Radians < 0.018 then Curve_Data.Last_Warping = tick() end
            if tick() - Curve_Data.Last_Warping < Reach_Time / 1.5 then return true end
            if Distance > Ball_Distance_Threshold and tick() - Curve_Data.Curving < Reach_Time / 1.5 then return true end
            return Dot < Dot_Threshold
        end

        Auto_Parry.Is_Curved2 = function(Ball)
            if game.PlaceId == 15264892126 then return false end
            local Alive = workspace.Alive
            local Count = #Alive:GetChildren()
            if game.PlaceId == 13772394625 and Count > 2 then return false end
            if not workspace:FindFirstChild("ShowdownActive") then return false end
            Ball = Ball or Targeted_Ball()
            local Character = LocalPlayer.Character
            local PrimaryPart = Character and Character.PrimaryPart
            if not Ball or not PrimaryPart or Ball:GetAttribute("target") ~= LocalPlayer.Name then return false end
            local Zoomies = Ball:FindFirstChild("zoomies")
            if not Zoomies then return false end
            local Ball_Position = Ball == Tracked_Ball and Real_Ball_Position or Ball.Position
            local Velocity = Zoomies.VectorVelocity
            local Offset = PrimaryPart.Position - Ball_Position
            local Distance = Offset.Magnitude
            if Distance < 0.001 or Velocity.Magnitude < 0.001 then return false end
            local Curve_Data = Auto_Parry.Get_Curve(Ball)
            local Dot = Offset.Unit:Dot(Velocity.Unit)
            local Time = os.clock()
            if math.sign(Dot) ~= math.sign(Curve_Data.Backward_Dot) then
                if Time - Curve_Data.Backward_Flip_Time < 0.2 then Curve_Data.Backward_Flips += 1
                else Curve_Data.Backward_Flips = 0 end
                Curve_Data.Backward_Flip_Time = Time
            end
            Curve_Data.Backward_Dot = Dot
            local From = Ball:GetAttribute("from")
            local Clone = Auto_Parry.Encrypted_Clone()
            local Name = Clone and Clone.Name
            if Name and Curve_Data.First_Hit and Curve_Data.First_Hit ~= Name and From == Name and not Curve_Data.Returned and game.PlaceId == 15234596844 and Count > 2 then
                return false
            end
            Auto_Parry.Is_Curved(Ball)
            local Look_Vector = workspace.CurrentCamera.CFrame.LookVector
            local Camera_Direction = Vector3.new(Look_Vector.X, 0, Look_Vector.Z)
            if Camera_Direction.Magnitude > 0 and Camera_Direction.Unit:Dot((Ball_Position - PrimaryPart.Position).Unit) >= 0 and Dot >= 0 then
                return false
            end
            local Predicted_Distance = (Offset + Velocity * 0.15).Magnitude
            return (game.PlaceId == 15234596844 or Count == 2) and Time - Last_Parry > 0.5 and Predicted_Distance > Distance + 15.5 and Curve_Data.Backward_Flips < 6
        end

        -- ---- properties ----
        Auto_Parry.Get_Ball_Properties = function(_, arg2)
            if not arg2 then return false end
            local zoomies = arg2:FindFirstChild("zoomies")
            if not zoomies then return false end
            local v = zoomies.VectorVelocity
            local pos = (arg2 == Tracked_Ball and Real_Ball_Position) or arg2.Position
            local unit = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Unit
            return { Speed=v.Magnitude, Velocity=v, Direction=unit,
                Distance=(LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude,
                Dot=unit:Dot(v.Unit) }
        end

        Auto_Parry.Get_Entity_Properties = function()
            local chosen2 = nil
            for _, child in workspace.Alive:GetChildren() do
                if child and child.Name ~= LocalPlayer.Name and child:FindFirstChild("HumanoidRootPart") then
                    if not chosen2 or LocalPlayer:DistanceFromCharacter(child.HumanoidRootPart.Position) < LocalPlayer:DistanceFromCharacter(chosen2.HumanoidRootPart.Position) then
                        chosen2 = child
                    end
                end
            end
            if not chosen2 then return false end
            return {
                Velocity = chosen2.HumanoidRootPart.AssemblyLinearVelocity,
                Direction = (LocalPlayer.Character.HumanoidRootPart.Position - chosen2.HumanoidRootPart.Position).Unit,
                Distance = (LocalPlayer.Character.HumanoidRootPart.Position - chosen2.HumanoidRootPart.Position).Magnitude,
            }
        end

        Auto_Parry.Spam_Service = function(arg)
            local ball = arg.Ball
            if not ball then return 0 end
            local zoomies = ball:FindFirstChild("zoomies")
            if not zoomies then return 0 end
            local v = zoomies.VectorVelocity
            local mag = v.Magnitude
            local pos = (ball == Tracked_Ball and Real_Ball_Position) or ball.Position
            local dot = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Unit:Dot(v.Unit)
            local n41 = arg.Ping + math.min(mag / 5.8, 100)
            local closest = math.min(arg.Entity_Properties.Distance, arg.Ball_Properties.Distance)
            if closest > n41 * 1.5 then return 0 end
            local n42 = 5 - math.min(mag / 5, 5)
            return n41 - math.clamp(dot, -1, 0) * n42
        end

        -- ---- parry data + animation ----
        Auto_Parry.Parry_Data = function(arg)
            if touchEnabled then
                Vector2_Mouse_Location = { workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2 }
            else
                local m = UserInputService:GetMouseLocation()
                Vector2_Mouse_Location = { m.X, m.Y }
            end
            local screen = {}
            for _, ch in workspace.Alive:GetChildren() do
                screen[ch.Name] = workspace.CurrentCamera:WorldToScreenPoint(ch.HumanoidRootPart.Position)
            end
            if arg == "Camera" then
                return { 0, CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector), screen, Vector2_Mouse_Location }
            end
            if arg == "Backwards" then
                local n41 = -workspace.CurrentCamera.CFrame.LookVector * 10000
                return { 0, CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + Vector3.new(n41.X, 100, n41.Z)), screen, Vector2_Mouse_Location }
            end
            if arg == "High" then
                return { 0, CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 10000, 0)), screen, Vector2_Mouse_Location }
            end
            if arg == "Random" then
                return { 0, CFrame.new(workspace.CurrentCamera.CFrame.Position, Vector3.new(math.random(-3000,3000),math.random(-3000,3000),math.random(-3000,3000))), screen, Vector2_Mouse_Location }
            end
            return { 0, CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector), screen, Vector2_Mouse_Location }
        end

        Auto_Parry.Parry = function(arg)
            if Library.Flags.Parry_Options == "Hardware" then mouse1click(); return end
            if Library.Flags.Parry_Options == "Keyboard" then
                pcall(function()
                    local identity = getthreadidentity()
                    if identity ~= 8 then setthreadidentity(8) end
                    VirtualInputManager:SendKeyEvent(true, Block_Keybind, false, game)
                    VirtualInputManager:SendKeyEvent(false, Block_Keybind, false, game)
                    if identity ~= 8 then setthreadidentity(identity) end
                end)
                return
            end
            local pd = Auto_Parry.Parry_Data(arg)
            return sendParry(pd[2], pd[3], pd[4])
        end

        Auto_Parry.Play_Animation = function()
            if os.clock() - Last_Played >= 1 or Bypass_Cd then
                Last_Played = os.clock(); Bypass_Cd = false
                -- simplified: skip complex anim replay
            end
        end

        -- ---- main loop ----
        local autoParryConn = nil
        Auto_Parry.SetAutoParry = function(on)
            if autoParryConn then autoParryConn:Disconnect(); autoParryConn = nil end
            if not on then return end
            autoParryConn = RunService.PreSimulation:Connect(function()
                local alive = workspace.Alive
                if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= alive then return end
                for _, ball2 in Auto_Parry.Get_Balls() do
                    local zoomies = ball2:FindFirstChild("zoomies")
                    if not zoomies then continue end
                    local n41 = os.clock() - Last_Parry
                    local attribute = ball2:GetAttribute("target")
                    if attribute ~= LocalPlayer.Name then continue end
                    local magnitude = zoomies.VectorVelocity.Magnitude
                    local value = Auto_Parry.Get_Ping()
                    local n42 = math.clamp(value / 10, 10, 16) + magnitude / (2.3497562749127492 + math.clamp(magnitude, 0, 425) * 0.002) * Speed_Divisor_Multiplier
                    local n43 = n42 + (Library.Flags.Parry_Range or 0)
                    local pos = (ball2 == Tracked_Ball and Real_Ball_Position) or ball2.Position
                    local mag2 = (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude
                    if mag2 <= n43 and not Parried then
                        Auto_Parry.Parry(Library.Flags.Parry_Type)
                        Last_Parry = os.clock()
                        Parried = true
                        task.delay(0.65, function() Parried = false end)
                    end
                end
            end)
        end

        -- ---- spam loop ----
        local spamConn = nil
        Auto_Parry.SetAutoSpam = function(on)
            if spamConn then spamConn:Disconnect(); spamConn = nil end
            if not on then return end
            spamConn = RunService.PostSimulation:Connect(function()
                if not Library.Flags.Auto_Parry then return end
                if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= workspace.Alive then return end
                local ball = Auto_Parry.Get_Ball()
                if not ball or not ball:FindFirstChild("zoomies") then return end
                local n41 = math.clamp(Auto_Parry.Get_Ping() / 10, 10, 16.5)
                local bp = Auto_Parry.Get_Ball_Properties(nil, ball)
                if not bp then return end
                local ep = Auto_Parry.Get_Entity_Properties()
                if not ep then return end
                local range = Auto_Parry.Spam_Service({ Ball=ball, Ball_Properties=bp, Entity_Properties=ep, Ping=n41 })
                if not range or range == 0 then return end
                local pos = (ball == Tracked_Ball and Real_Ball_Position) or ball.Position
                if (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude <= range and Parries >= tonumber(Library.Flags.Clashing_Threshold) then
                    Auto_Parry.Parry(Library.Flags.Parry_Type)
                end
            end)
        end

        log("9. engine ready")
        Fluent:Notify({ Title = "Vivo", Content = "المحرك جاهز", Duration = 3 })
    end)

    if not ok_engine then
        warn("[Vivo] engine error: " .. tostring(err_engine))
        Fluent:Notify({ Title = "Vivo", Content = "فشل تحميل المحرك: " .. tostring(err_engine), Duration = 6 })
    end
end)

-- =========================================================
-- UI TOGGLES (جاهزة من البداية)
-- =========================================================
MainTab:AddToggle("AutoParryToggle", {
    Title = "auto parry",
    Default = Library.Flags.Auto_Parry or false,
    Callback = function(arg)
        Library.Flags.Auto_Parry = arg
        save_config()
        if Auto_Parry.SetAutoParry then Auto_Parry.SetAutoParry(arg) end
    end,
})

MainTab:AddToggle("AutoSpamToggle", {
    Title = "auto spam",
    Default = Library.Flags.Auto_Spam or false,
    Callback = function(arg)
        Library.Flags.Auto_Spam = arg
        save_config()
        if Auto_Parry.SetAutoSpam then Auto_Parry.SetAutoSpam(arg) end
    end,
})

MainTab:AddDropdown("ParryTypeDropdown", {
    Title = "parry type",
    Values = { "Camera", "High", "FFA", "Dot", "Dot Pointer", "Closest", "Random", "Backwards" },
    Multi = false,
    Default = Library.Flags.Parry_Type,
    Callback = function(v)
        Library.Flags.Parry_Type = v
        save_config()
    end,
})

MainTab:AddDropdown("ParryOptionsDropdown", {
    Title = "parry options",
    Values = { "Remote", "Hardware", "Keyboard" },
    Multi = false,
    Default = Library.Flags.Parry_Options,
    Callback = function(v)
        Library.Flags.Parry_Options = v
        save_config()
    end,
})

MainTab:AddDropdown("ClashThresholdDropdown", {
    Title = "clashing threshold",
    Values = { "1", "2", "3" },
    Multi = false,
    Default = tostring(Library.Flags.Clashing_Threshold),
    Callback = function(v)
        Library.Flags.Clashing_Threshold = tostring(v)
        save_config()
    end,
})

MainTab:AddSlider("ParryRangeSlider", {
    Title = "parry range",
    Default = Library.Flags.Parry_Range or 0,
    Min = 0, Max = 10, Rounding = 1,
    Callback = function(v)
        Library.Flags.Parry_Range = tonumber(v)
        save_config()
    end,
})

MainTab:AddSlider("AccuracySlider", {
    Title = "parry accuracy",
    Default = Library.Flags.Parry_Accuracy or 72,
    Min = 1, Max = 100, Rounding = 1,
    Callback = function(v)
        Library.Flags.Parry_Accuracy = tonumber(v)
        save_config()
        if Library.Flags.Phantom_Detection then
            Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.024747474747474751
        else
            Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.0030303030303030303
        end
    end,
})

MainTab:AddToggle("CooldownProtectionToggle", {
    Title = "cooldown protection",
    Default = Library.Flags.Cooldown_Protection or false,
    Callback = function(arg)
        Library.Flags.Cooldown_Protection = arg
        getgenv().Cooldown_Protection = arg
        save_config()
    end,
})

VisualTab:AddToggle("PhantomDetectionToggle", {
    Title = "phantom protection",
    Default = Library.Flags.Phantom_Detection or false,
    Callback = function(arg)
        Library.Flags.Phantom_Detection = arg
        save_config()
        if arg then
            Speed_Divisor_Multiplier = 0.8 + ((Library.Flags.Parry_Accuracy or 72) - 1) * 0.024747474747474751
        else
            Speed_Divisor_Multiplier = 0.8 + ((Library.Flags.Parry_Accuracy or 72) - 1) * 0.0030303030303030303
        end
    end,
})

log("10. UI ready")
