--[[
    ██╗   ██╗██╗██╗   ██╗ ██████╗
    ██║   ██║██║██║   ██║██╔═══██╗
    ██║   ██║██║██║   ██║██║   ██║
    ╚██╗ ██╔╝██║╚██╗ ██╔╝██║   ██║
     ╚████╔╝ ██║ ╚████╔╝ ╚██████╔╝
      ╚═══╝  ╚═╝  ╚═══╝   ╚═════╝
    UI: angeli (Fluent) | ENGINE: byte (VFX fix)
]]
if not IB_OBFUSCATED then
    function IB_NO_VIRTUALIZE(Function) return Function end
end

repeat task.wait() until game:IsLoaded()

local Players, Player, playerGui = IB_NO_VIRTUALIZE(function()
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer
    while not Player do
        task.wait()
        Player = Players.LocalPlayer
    end
    return Players, Player, Player:WaitForChild("PlayerGui")
end)()

local Library = { Flags = {}, Keybinds = {} }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =========================================================
-- BYTE: createParrySender
-- =========================================================
local function createParrySender()
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

    local function capture(event, eventHash, eventKey, proof, duration, direction, targets, aim, flag)
        if eventHash == hash and type(eventKey) == "string" and type(proof) == "string"
            and type(duration) == "number" and typeof(direction) == "CFrame"
            and type(targets) == "table" and type(aim) == "table" and type(flag) == "boolean" then
            remote, key = event, eventKey
        end
    end
    local fireServer
    fireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(IB_NO_VIRTUALIZE(function(event, ...)
        if not remote and not checkcaller() then
            capture(event, ...)
        end
        return fireServer(event, ...)
    end)))

    return function(direction, targets, aim)
        local duration = durations[(playerData:Get("timesParried") or 0) + 1] or 0.5
        if noobParry then
            local kills = playerData:Get("TotalStats.Kills") or 0
            duration = kills < 20 and duration * kills / 20 or duration
        end
        if not key then
            signal:Fire(duration, direction, targets, aim, false)
            return true
        end
        timeKey = timeKey or encoder(key, "TIME")
        local stamp = tostring(math.floor(workspace:GetServerTimeNow() * 100))
        table.clear(timeHash)
        for index = 1, #stamp do
            timeHash[index] = string.char(bit32.bxor(
                (string.byte(stamp, index) + index) % 256,
                string.byte(timeKey, (index - 1) % #timeKey + 1)
            ))
        end
        fireServer(remote, hash, key, table.concat(timeHash), duration, direction, targets, aim, false)
        return true
    end
end

local sendParry = createParrySender()

-- =========================================================
-- BYTE: state + Connections
-- =========================================================
local Connections_Manager = {}
local Auto_Parry = {}
local RunService = game:GetService("RunService")
local VirtualInputManager = Instance.new("VirtualInputManager")
local balls = workspace:WaitForChild("Balls")
local UserInputService = game:GetService("UserInputService")
local touchEnabled = UserInputService.TouchEnabled
local ReplicatedInstances = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReplicatedInstances")
local Swords = require(ReplicatedInstances:WaitForChild("Swords"))

local Saved_Sword_Model = Swords:GetSword(Player:GetAttribute("CurrentlyEquippedSword"))

local Play_Parry, Sword_Function, Block_Keybind, Real_Ball_Position, Tracked_Ball

do
    Play_Parry = nil
    local swordsController
    Sword_Function = function(name)
        if not swordsController then
            for _, connection in getconnections(ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent) do
                local values = connection.Function and (getupvalues or debug.getupvalues)(connection.Function)
                if type(values) == "table" then
                    for _, value in values do
                        if type(value) == "table" and type(rawget(value, "SetSword")) == "function" then
                            swordsController = value
                            break
                        end
                    end
                end
                if swordsController then break end
            end
        end
        if swordsController then
            swordsController:SetSword(name)
        end
    end

    do
        local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
        Block_Keybind = playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind1.TextBox.Text
            or playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind2.TextBox.Text
            or playerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind3.TextBox.Text
        Real_Ball_Position = nil
        Tracked_Ball = nil

        for _, child in net:GetChildren() do
            if child:IsA("UnreliableRemoteEvent") and child.Name ~= "URE/ReplicateBallPosition" then
                Connections_Manager["Real Ball Position"] = child.OnClientEvent:Connect(function(arg, arg2)
                    if not arg or not arg.Parent then
                        if arg == Tracked_Ball then
                            Tracked_Ball = nil
                            Real_Ball_Position = nil
                        end
                        return
                    end
                    Tracked_Ball = arg
                    Real_Ball_Position = arg2
                end)
            end
        end
    end
end

for _, connection in getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent) do
    connection:Disable()
    connection:Disconnect()
end

for _, connection in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
    if connection and connection.Function then
        Play_Parry = connection.Function
        connection:Disable()
        connection:Disconnect()
    end
end

-- =========================================================
-- BYTE: state variables
-- =========================================================
local Parry_Abilities, Ignored_VFX, Infinity_Ball, Tornado_Time, Parries, Speed_Divisor_Multiplier
local Last_Parry, Parried
local Is_Curved_Data = {}
local Got_Phantomed = false
local Last_FFA_Target = nil
local Vector2_Mouse_Location = {0, 0}
local Last_Played, Bypass_Cd = 0, false
local Is_Mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

do
    Parry_Abilities = {
        "Calming Deflection","Raging Deflection","Rapture","Aerodynamic Slash",
        "Forcefield","Infinity","Fracture","Death Slash","Slashes of Fury",
    }
    Ignored_VFX = {
        "BallEmit","Upgrade","Arch2","MaxHook","Wave","Totem","TotemRange",
        "InfinityFX","maxTransmission","transmissionpart","Tornado","Barrier",
        "GUARDIAN_DRAGON","DRAGON_POSITIONER","SpiritDeflect","Vanity","Platform",
        "Swap","MaxBlink",
    }
    Infinity_Ball = false
    Tornado_Time = nil
    Last_Parry = 0
    Parried = false
    Parries = 0
    Speed_Divisor_Multiplier = 1.1
end

-- =========================================================
-- ★ VFX FIX — Weapon Changer Event (byte)
-- =========================================================
Connections_Manager["Weapon Changer Event"] = ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
    local varargs = { ... }
    local name = Player.Name
    if tostring(varargs[4]) == name then
        local sword2 = Swords:GetSword(Player:GetAttribute("CurrentlyEquippedSword"))
        if sword2 and sword2.SlashName then
            varargs[1] = sword2.SlashName
            varargs[3] = sword2.Name
        end
    end
    return Play_Parry(unpack(varargs))
end)

-- =========================================================
-- ★ VFX FIX — Parry Animation Fix (byte)
-- =========================================================
Connections_Manager["Parry Animation Fix"] = ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    Bypass_Cd = true
    local character = Player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in animator:GetPlayingAnimationTracks() do
            local n = track.Name
            if track:GetAttribute("GrabParry") or track:GetAttribute("Parry") or n == "GrabParry" or n == "Grab" then
                track:Stop(track:GetAttribute("StopFadeTime") or 0.1)
            end
        end
    end
end)

-- =========================================================
-- BYTE: ball finders
-- =========================================================
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

-- =========================================================
-- BYTE: target selection
-- =========================================================
do
    local chosen = nil

    Auto_Parry.Get_Crosshair_Target = function()
        local currentCamera = workspace.CurrentCamera
        local alive = workspace.Alive
        if not alive then return false end
        local viewportSize = currentCamera.ViewportSize
        local vector2 = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        local huge = math.huge
        local target = nil
        for _, child in alive:GetChildren() do
            if child ~= Player.Character and child.PrimaryPart then
                local screenPoint, onScreen = currentCamera:WorldToScreenPoint(child.PrimaryPart.Position)
                if onScreen then
                    local magnitude = (Vector2.new(screenPoint.X, screenPoint.Y) - vector2).Magnitude
                    if magnitude < huge then
                        target = { Character = child, Screen_Data = { screenPoint.X, screenPoint.Y } }
                        huge = magnitude
                    end
                end
            end
        end
        return target
    end

    Auto_Parry.Closest_Aim = function()
        local alive = workspace.Alive
        if Player.Character.Parent ~= alive then return false end
        local n41 = -math.huge
        local currentCamera = workspace.CurrentCamera
        local closestCharacter = nil
        for _, child in alive:GetChildren() do
            if child ~= Player.Character and child.PrimaryPart then
                local dot = currentCamera.CFrame.LookVector:Dot((child.PrimaryPart.Position - currentCamera.CFrame.Position).Unit)
                local screenPoint, onScreen = currentCamera:WorldToViewportPoint(child.PrimaryPart.Position)
                if onScreen and dot > n41 then
                    n41 = dot
                    closestCharacter = child
                end
            end
        end
        chosen = closestCharacter
        return chosen
    end

    Auto_Parry.Force_Target = function()
        local currentCamera = workspace.CurrentCamera
        local alive = workspace.Alive
        if not alive then return false end
        local huge = math.huge
        local target = nil
        for _, child in alive:GetChildren() do
            if child ~= Player.Character and child.PrimaryPart then
                local screenPoint, onScreen = currentCamera:WorldToScreenPoint(child.PrimaryPart.Position)
                if onScreen then
                    local magnitude = (Player.Character.PrimaryPart.Position - child.PrimaryPart.Position).Magnitude
                    if magnitude < huge then
                        target = { Character = child, Screen_Data = { screenPoint.X, screenPoint.Y } }
                        huge = magnitude
                    end
                end
            end
        end
        if not target then return false end
        return target
    end

    Auto_Parry.FFA = function()
        local currentCamera = workspace.CurrentCamera
        local alive = workspace.Alive
        if not alive then return false end
        local ball = Auto_Parry.Get_Ball()
        if not ball then Last_FFA_Target = nil; return false end
        if not ball:FindFirstChild("zoomies") then return false end
        local attribute = ball:GetAttribute("target")
        if attribute ~= Last_FFA_Target then Last_FFA_Target = nil end
        local targets = {}
        for _, child in alive:GetChildren() do
            if child ~= Player.Character and child.PrimaryPart then
                local screenPoint, onScreen = currentCamera:WorldToScreenPoint(child.PrimaryPart.Position)
                if onScreen and child.Name ~= attribute and child ~= Last_FFA_Target then
                    table.insert(targets, { Character = child, Screen_Data = { screenPoint.X, screenPoint.Y } })
                end
            end
        end
        if #targets < 1 then return false end
        local picked = targets[math.random(1, #targets)]
        Last_FFA_Target = picked.Character.Name
        return picked
    end

    Auto_Parry.select_target_by_mouse = function()
        local list = {}
        for _, child in workspace.Alive:GetChildren() do
            if child.Name ~= Player.Name and child.PrimaryPart then
                table.insert(list, child)
            end
        end
        local currentCamera = workspace.CurrentCamera
        local mouseLocation = UserInputService:GetMouseLocation()
        local direction = currentCamera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y).Direction
        local n41 = -math.huge
        local chosen2 = nil
        for _, entry in list do
            local dot = direction:Dot((entry.PrimaryPart.Position - currentCamera.CFrame.Position).Unit)
            if n41 < dot then
                n41 = dot
                chosen2 = entry
            end
        end
        return chosen2
    end

    Auto_Parry.Closest_Player = function()
        local alive = workspace.Alive
        if (Player.Character or Player.CharacterAdded:Wait()).Parent ~= alive then return false end
        local huge = math.huge
        local closestCharacter = nil
        for _, child in alive:GetChildren() do
            if child and child.Name ~= Player.Name then
                local distance = Player:DistanceFromCharacter(child.HumanoidRootPart.Position)
                if distance < huge then
                    huge = distance
                    closestCharacter = child
                end
            end
        end
        chosen = closestCharacter
        return chosen
    end

    Auto_Parry.Linear_Interpolation = function(arg, arg2, arg3)
        return arg + (arg2 - arg) * arg3
    end

    Auto_Parry.Get_Ping = function()
        local ok, value = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        return ok and value or Player:GetNetworkPing() * 1000
    end
end

-- =========================================================
-- BYTE: Parry_Data
-- =========================================================
Auto_Parry.Parry_Data = function(arg)
    if touchEnabled then
        Vector2_Mouse_Location = {
            workspace.CurrentCamera.ViewportSize.X / 2,
            workspace.CurrentCamera.ViewportSize.Y / 2,
        }
    else
        local mouseLocation = UserInputService:GetMouseLocation()
        Vector2_Mouse_Location = { mouseLocation.X, mouseLocation.Y }
    end

    local screenPositions = {}
    for _, child in workspace.Alive:GetChildren() do
        screenPositions[child.Name] = workspace.CurrentCamera:WorldToScreenPoint(child.HumanoidRootPart.Position)
    end

    if arg == "Camera" then
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector)
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "Random" then
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, Vector3.new(math.random(-3000, 3000), math.random(-3000, 3000), math.random(-3000, 3000)))
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "Backwards" then
        local n41 = -workspace.CurrentCamera.CFrame.LookVector * 10000
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + Vector3.new(n41.X, 100, n41.Z))
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "High" then
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 10000, 0))
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "Dot" then
        local crosshairTarget = Auto_Parry.Get_Crosshair_Target()
        if crosshairTarget then
            return {
                0,
                CFrame.new(Player.Character.PrimaryPart.Position, crosshairTarget.Character.PrimaryPart.Position + Vector3.new(0, 1.75, 0)),
                screenPositions,
                crosshairTarget.Screen_Data,
            }
        end
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector)
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "Dot Pointer" then
        local currentCamera = workspace.CurrentCamera
        local mouseTarget = Auto_Parry.select_target_by_mouse()
        local position = mouseTarget and mouseTarget.PrimaryPart and mouseTarget.PrimaryPart.Position or Player.Character.PrimaryPart.Position + currentCamera.CFrame.LookVector * 1000
        return {
            0,
            CFrame.lookAt(Player.Character.PrimaryPart.Position, position + Vector3.new(0, 2, 0)),
            screenPositions,
            Vector2_Mouse_Location,
        }
    end
    if arg == "Closest" then
        local forcedTarget = Auto_Parry.Force_Target()
        if forcedTarget then
            return {
                0,
                CFrame.new(Player.Character.PrimaryPart.Position, forcedTarget.Character.PrimaryPart.Position),
                screenPositions,
                forcedTarget.Screen_Data,
            }
        end
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector)
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    if arg == "FFA" then
        local ffaTarget = Auto_Parry.FFA()
        if ffaTarget then
            return {
                0,
                CFrame.new(Player.Character.PrimaryPart.Position, ffaTarget.Character.PrimaryPart.Position),
                screenPositions,
                ffaTarget.Screen_Data,
            }
        end
        local cframe = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector)
        return { 0, cframe, screenPositions, Vector2_Mouse_Location }
    end
    return arg
end

-- =========================================================
-- BYTE: Parry + Animation
-- =========================================================
do
    Auto_Parry.Parry = function(arg)
        if Library.Flags.Parry_Options == "Hardware" then
            mouse1click()
            return
        end
        if Library.Flags.Parry_Options == "Keyboard" then
            return Auto_Parry.Animation_Fix()
        end
        local parryData = Auto_Parry.Parry_Data(arg)
        return sendParry(parryData[2], parryData[3], parryData[4])
    end

    Auto_Parry.Animation_Fix = function()
        local identity = getthreadidentity()
        if identity ~= 8 then setthreadidentity(8) end
        local ok, message = pcall(function()
            VirtualInputManager:SendKeyEvent(true, Block_Keybind, false, game)
            VirtualInputManager:SendKeyEvent(false, Block_Keybind, false, game)
        end)
        if identity ~= 8 then setthreadidentity(identity) end
        if not ok then error(message, 0) end
    end

    local animationController = require(ReplicatedStorage.Controllers.AnimationController)
    local swordApi = require(ReplicatedStorage.Shared.SwordAPI)

    Auto_Parry.Parry_Animation = function()
        local character = Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        local attribute = character:GetAttribute("CurrentlyEquippedSword") or Player:GetAttribute("CurrentlyEquippedSword")
        if not attribute then return end
        local swordInfo = Swords:GetSword(attribute)
        if not swordInfo or character ~= Player.Character then return end
        for _, track in animationController:GetPlayingAnimationTracks(animator) do
            local n = track.Name
            if track:GetAttribute("GrabParry") or track:GetAttribute("Parry") or n == "GrabParry" or n == "Grab" or n == "Parry" or n == "SuccessParry" or n == "Success" then
                track:Stop(track:GetAttribute("StopFadeTime") or 0.1)
            end
        end
        for _, animation in swordApi:GetAnimations(character, {"Parry", "GrabParry"}, swordInfo.AnimationType, swordInfo.SwordType) do
            local track = animationController:LoadAnimation(animator, animation, true)
            local speed = track:GetAttribute("PlaySpeed") or 1
            track:Play(track:GetAttribute("PlayFadeTime") or 0.1, track:GetAttribute("PlayWeight") or 1, speed)
            character:SetAttribute("ParryTime", math.max(character:GetAttribute("ParryTime") or 0, track.Length == 0 and 1 or (track.Length - track.TimePosition) * speed))
        end
    end

    Auto_Parry.Play_Animation = function()
        if os.clock() - Last_Played >= 1 or Bypass_Cd then
            Last_Played = os.clock()
            Bypass_Cd = false
            Auto_Parry.Parry_Animation()
        end
    end
end

-- =========================================================
-- BYTE: curve cache
-- =========================================================
Auto_Parry.Get_Curve = function(ball)
    if Is_Curved_Data[ball] then return Is_Curved_Data[ball] end
    local data = {
        Curving = 0, Lerp_Radians = 0, Last_Warping = 0, Dot = 0, Flips = 0, Flip_Time = 0,
        Backward_Dot = 0, Backward_Flips = 0, Backward_Flip_Time = 0,
        Returned = false, Target_Count = 0,
    }
    Is_Curved_Data[ball] = data
    local function update()
        local from = ball:GetAttribute("from")
        local clone = Auto_Parry.Encrypted_Clone()
        local name = clone and clone.Name
        if from == Player.Name and data.First_Hit then
            data.Returned = true
        elseif from and from ~= "" and from ~= Player.Name and from ~= name then
            data.First_Hit = data.First_Hit or from
            data.Returned = false
        end
    end
    data.From = ball:GetAttributeChangedSignal("from"):Connect(update)
    data.Target = ball:GetAttributeChangedSignal("target"):Connect(function()
        Parried = false
        data.Target_Count += 1
        data.Triggerbot_Parried = false
        if Auto_Parry.Triggerbot then
            Auto_Parry.Triggerbot(ball, true)
        end
    end)
    update()
    return data
end

Auto_Parry.Encrypted_Clone = function()
    for _, child in workspace.Alive:GetChildren() do
        if child and child.Name and child.Name:find("ENCRYPTED CLONE", 1, true) then
            return child
        end
    end
end

local function Targeted_Ball()
    for _, ball in Auto_Parry.Get_Balls() do
        if ball:GetAttribute("target") == Player.Name then
            return ball
        end
    end
end

-- =========================================================
-- BYTE: Is_Curved + Is_Curved2
-- =========================================================
function Auto_Parry.Is_Curved(Ball)
    Ball = Ball or Targeted_Ball()
    local Character = Player.Character
    local PrimaryPart = Character and Character.PrimaryPart
    if not Ball or not PrimaryPart or Ball:GetAttribute("target") ~= Player.Name then return false end
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
        if Time - Curve_Data.Flip_Time < 0.2 then
            Curve_Data.Flips += 1
        else
            Curve_Data.Flips = 0
        end
        Curve_Data.Flip_Time = Time
    end
    Curve_Data.Dot = Dot
    Curve_Data.Lerp_Radians = Auto_Parry.Linear_Interpolation(Curve_Data.Lerp_Radians, Radians, 0.8)

    if Speed > 100 and Reach_Time > Pings / 10 then
        Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
    end
    if Curve_Data.Flips >= 5 then return false end
    if Dot < 0 then return true end
    if Distance < Ball_Distance_Threshold then return false end
    if Dot_Difference < Dot_Threshold then return true end
    if Curve_Data.Lerp_Radians < 0.018 then Curve_Data.Last_Warping = tick() end
    if tick() - Curve_Data.Last_Warping < Reach_Time / 1.5 then return true end
    if Distance > Ball_Distance_Threshold and tick() - Curve_Data.Curving < Reach_Time / 1.5 then return true end
    return Dot < Dot_Threshold
end

function Auto_Parry.Is_Curved2(Ball)
    if game.PlaceId == 15264892126 then return false end
    local Alive = workspace.Alive
    local Count = #Alive:GetChildren()
    if game.PlaceId == 13772394625 and Count > 2 then return false end
    local Showdown = workspace:FindFirstChild("ShowdownActive")
    if not Showdown then return false end
    Ball = Ball or Targeted_Ball()
    local Character = Player.Character
    local PrimaryPart = Character and Character.PrimaryPart
    if not Ball or not PrimaryPart or Ball:GetAttribute("target") ~= Player.Name then return false end
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
        if Time - Curve_Data.Backward_Flip_Time < 0.2 then
            Curve_Data.Backward_Flips += 1
        else
            Curve_Data.Backward_Flips = 0
        end
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

-- =========================================================
-- BYTE: ball/entity/spam properties
-- =========================================================
Auto_Parry.Get_Ball_Properties = function(arg, arg2)
    if not arg2 then return false end
    local zoomies = arg2:FindFirstChild("zoomies")
    if not zoomies then return false end
    local vectorVelocity = zoomies.VectorVelocity
    local position = (arg2 == Tracked_Ball and Real_Ball_Position) or arg2.Position
    local unit = (Player.Character.HumanoidRootPart.Position - position).Unit
    return {
        Speed = vectorVelocity.Magnitude,
        Velocity = vectorVelocity,
        Direction = unit,
        Distance = (Player.Character.HumanoidRootPart.Position - position).Magnitude,
        Dot = unit:Dot(vectorVelocity.Unit),
    }
end

Auto_Parry.Get_Entity_Properties = function()
    Auto_Parry.Closest_Player()
    local chosen2 = nil
    for _, child in workspace.Alive:GetChildren() do
        if child and child.Name ~= Player.Name then
            if not chosen2 or Player:DistanceFromCharacter(child.HumanoidRootPart.Position) < Player:DistanceFromCharacter(chosen2.HumanoidRootPart.Position) then
                chosen2 = child
            end
        end
    end
    if not chosen2 then return false end
    return {
        Velocity = chosen2.HumanoidRootPart.AssemblyLinearVelocity,
        Direction = (Player.Character.HumanoidRootPart.Position - chosen2.HumanoidRootPart.Position).Unit,
        Distance = (Player.Character.HumanoidRootPart.Position - chosen2.HumanoidRootPart.Position).Magnitude,
    }
end

Auto_Parry.Spam_Service = function(arg)
    local ball = arg.Ball
    if not ball then return false end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end
    local vectorVelocity = zoomies.VectorVelocity
    local magnitude = vectorVelocity.Magnitude
    local position = (ball == Tracked_Ball and Real_Ball_Position) or ball.Position
    local dot = (Player.Character.HumanoidRootPart.Position - position).Unit:Dot(vectorVelocity.Unit)
    local n41 = arg.Ping + math.min(magnitude / 5.8, 100)
    if arg.Entity_Properties.Distance > n41 or arg.Ball_Properties.Distance > n41 then
        return 0
    end
    local n42 = 5 - math.min(magnitude / 5, 5)
    return n41 - math.clamp(dot, -1, 0) * n42
end

-- =========================================================
-- BYTE: Triggerbot
-- =========================================================
do
    local pendingBall, pendingTarget
    local nextParry = 0

    Auto_Parry.Triggerbot = function(ball, changed)
        if not Library.Flags.Triggerbot then return end
        if pendingBall and not pendingBall.Parent then
            pendingBall = nil
            nextParry = 0
        end
        if not ball then
            for _, child in Auto_Parry.Get_Balls() do
                Auto_Parry.Triggerbot(child)
            end
            return
        end
        if changed and pendingBall == ball then
            pendingBall = nil
            nextParry = 0
        end
        if not ball.Parent or not ball:GetAttribute("realBall") or ball:GetAttribute("target") ~= Player.Name then return end
        local data = Auto_Parry.Get_Curve(ball)
        if data.Triggerbot_Parried or os.clock() < nextParry then return end
        local character = Player.Character
        local primaryPart = character and character.PrimaryPart
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not primaryPart or character.Parent ~= workspace.Alive or not humanoid or humanoid.Health <= 0 then return end
        if character:GetAttribute("Stunned") or character:GetAttribute("DoNotParry") or character:GetAttribute("IsInvisible") then return end
        if primaryPart:FindFirstChild("Shield") or primaryPart:FindFirstChild("MaxShield") or primaryPart:FindFirstChild("SingularityCape") then return end
        local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
        local block = hotbar and hotbar:FindFirstChild("Block")
        local gradient = block and block:FindFirstChildWhichIsA("UIGradient")
        if gradient and gradient.Offset.Y < 0.49 then return end
        pendingBall = ball
        pendingTarget = data.Target_Count
        Last_Parry = os.clock()
        nextParry = Last_Parry + 1.3
        Auto_Parry.Play_Animation()
        Auto_Parry.Parry(Library.Flags.Parry_Type)
    end

    function Auto_Parry.Start_Triggerbot()
        for _, name in {"Triggerbot", "Triggerbot Cooldown", "Triggerbot Success"} do
            if Connections_Manager[name] then
                Connections_Manager[name]:Disconnect()
                Connections_Manager[name] = nil
            end
        end
        pendingBall = nil
        nextParry = 0
        for _, ball in Auto_Parry.Get_Balls() do
            Auto_Parry.Get_Curve(ball).Triggerbot_Parried = false
        end
        if not Library.Flags.Triggerbot then return end
        Connections_Manager["Triggerbot Cooldown"] = ReplicatedStorage.Remotes.VisualCD.OnClientEvent:Connect(function(block, active, duration)
            if not block then return end
            nextParry = active and os.clock() + (tonumber(duration) or 1.3) or pendingBall and nextParry or 0
            if not active then Auto_Parry.Triggerbot() end
        end)
        Connections_Manager["Triggerbot Success"] = ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
            local data = pendingBall and Is_Curved_Data[pendingBall]
            if data and data.Target_Count == pendingTarget then
                data.Triggerbot_Parried = true
            end
            pendingBall = nil
            nextParry = 0
        end)
        Connections_Manager["Triggerbot"] = RunService.PreSimulation:Connect(function()
            Auto_Parry.Triggerbot()
        end)
        Auto_Parry.Triggerbot()
    end
end

-- =========================================================
-- BYTE: workspace events
-- =========================================================
Connections_Manager["Infinity Ball"] = ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(arg, arg2)
    Infinity_Ball = arg2
end)

ReplicatedStorage.Remotes.Phantom.OnClientEvent:Connect(function(arg, arg2)
    if arg2.Name == Player.Name then
        Got_Phantomed = true
        task.delay(0.35, function() Got_Phantomed = false end)
    end
end)

Connections_Manager["Phantom Detection"] = workspace.Runtime.ChildAdded:Connect(function(child)
    local name = child.Name
    if Library.Flags.Phantom_Detection and (name == "maxTransmission" or name == "transmissionpart") then
        local weldConstraint = child:FindFirstChildWhichIsA("WeldConstraint")
        if weldConstraint then
            local character = Player.Character or Player.CharacterAdded:Wait()
            if character and weldConstraint.Part1 and weldConstraint.Part1:IsDescendantOf(character) then
                local clientBall = Auto_Parry.Client_Ball()
                if clientBall and clientBall:GetAttribute("highlighted") then
                    Got_Phantomed = true
                    task.delay(0.35, function() Got_Phantomed = false end)
                end
                weldConstraint:Destroy()
            end
        end
    end
end)

workspace.Runtime.ChildAdded:Connect(function(child)
    if child.Name == "Tornado" then
        Tornado_Time = tick()
        Connections_Manager["Tornado Time"] = child:GetAttributeChangedSignal("TornadoTime"):Connect(function()
            Tornado_Time = tick()
        end)
        Connections_Manager["Tornado Destroying"] = child.Destroying:Connect(function()
            Tornado_Time = nil
        end)
    end
end)

workspace.Balls.ChildAdded:Connect(function(child)
    if child:GetAttribute("realBall") then
        Auto_Parry.Get_Curve(child)
        if Auto_Parry.Triggerbot then
            Auto_Parry.Triggerbot(child)
        end
    end
end)

for _, ball in Auto_Parry.Get_Balls() do
    Auto_Parry.Get_Curve(ball)
end

Connections_Manager["Ball Removed"] = workspace.Balls.ChildRemoved:Connect(function(child)
    local data = Is_Curved_Data[child]
    if data then
        if data.From then data.From:Disconnect() end
        if data.Target then data.Target:Disconnect() end
        Is_Curved_Data[child] = nil
    end
    Last_FFA_Target = nil
end)

-- =========================================================
-- UI: angeli (Fluent) — فقط
-- =========================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Vivo",
    SubTitle = "",
    TabWidth = 100,
    Size = UDim2.fromOffset(440, 315),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local MainTab = Window:AddTab({ Title = "main", Icon = "shield" })
local VisualTab = Window:AddTab({ Title = "visual", Icon = "eye" })

-- defaults byte
Library.Flags.Parry_Type = "Camera"
Library.Flags.Parry_Options = "Remote"
Library.Flags.Clashing_Threshold = "1"
Library.Flags.Parry_Range = 0
Library.Flags.Parry_Accuracy = 72
Speed_Divisor_Multiplier = 0.8 + (72 - 1) * 0.0030303030303030303

-- =========================================================
-- Auto Parry — byte exact
-- =========================================================
MainTab:AddToggle("AutoParryToggle", {
    Title = "auto parry",
    Default = false,
    Callback = function(arg)
        Library.Flags.Auto_Parry = arg
        if arg then
            if Connections_Manager["Auto Parry"] then
                Connections_Manager["Auto Parry"]:Disconnect()
                Connections_Manager["Auto Parry"] = nil
            end
            Connections_Manager["Auto Parry"] = RunService.PreSimulation:Connect(function()
                local alive = workspace.Alive
                if (Player.Character or Player.CharacterAdded:Wait()).Parent ~= alive then return end
                local ball = Auto_Parry.Get_Ball()

                for _, ball2 in Auto_Parry.Get_Balls() do
                    if not ball2 then return end
                    local zoomies = ball2:FindFirstChild("zoomies")
                    if not zoomies then return end

                    getgenv().Time_View = os.clock() - Last_Parry
                    local n41 = os.clock() - Last_Parry

                    local maxShield = Player.Character.PrimaryPart:FindFirstChild("MaxShield")
                    local tornado = workspace.Runtime:FindFirstChild("Tornado")
                    local abilities = Player.Character and Player.Character:FindFirstChild("Abilities")
                    local hotbar = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("Hotbar")
                    local visible = hotbar and hotbar:FindFirstChild("Ability") and hotbar.Ability:FindFirstChild("Duration") and hotbar.Ability.Duration.Visible
                    local infinity = abilities and abilities:FindFirstChild("Infinity")
                    infinity = infinity and infinity.Enabled
                    infinity = visible and infinity and Infinity_Ball
                    abilities = abilities and abilities:FindFirstChild("Time Hole")
                    abilities = abilities and abilities.Enabled

                    local singularityCape = Player.Character.PrimaryPart:FindFirstChild("SingularityCape")
                    local uiGradient = Player.PlayerGui.Hotbar.Block.UIGradient
                    getgenv().Parry_Cooldown = uiGradient
                    local uiGradient2 = Player.PlayerGui.Hotbar.Ability.UIGradient
                    local attribute = ball2:GetAttribute("target")
                    ball:GetAttribute("target")
                    local magnitude = zoomies.VectorVelocity.Magnitude
                    local value = Auto_Parry.Get_Ping()
                    local n42 = math.clamp(value / 10, 10, 16) + magnitude / (2.3497562749127492 + math.clamp(magnitude, 0, 425) * 0.002) * Speed_Divisor_Multiplier
                    local n43 = n42 + Library.Flags.Parry_Range or 0
                    local position

                    if ball2 == Tracked_Ball and Real_Ball_Position then
                        position = Real_Ball_Position
                    else
                        position = ball2.Position
                    end

                    local magnitude2 = (Player.Character.PrimaryPart.Position - position).Magnitude
                    local curved = Auto_Parry.Is_Curved(ball2)
                    local curvedMore = Auto_Parry.Is_Curved2(ball2)

                    if infinity or visible and abilities then
                        Parries = 0
                        return
                    end
                    if visible and maxShield or singularityCape then
                        Parries = 0
                        return
                    end

                    if attribute == Player.Name and tornado then
                        local n44 = (tornado:GetAttribute("TornadoTime") or 1) + 0.314159
                        if Tornado_Time then
                            if tick() - Tornado_Time < n44 then return end
                            game:GetService("Debris"):AddItem(tornado, 0)
                            Tornado_Time = nil
                        end
                    end

                    if attribute == Player.Name and getgenv().Cooldown_Protection and n41 > 0.5 and (uiGradient.Offset.Y <= 0.4 and magnitude2 <= n42 or uiGradient.Offset.Y > 0 and uiGradient.Offset.Y <= -0.15) then
                        for _, abilityName in Parry_Abilities do
                            if Player.Character.Abilities[abilityName].Enabled then
                                Parried = true
                                ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                                return
                            end
                        end
                    end

                    if attribute == Player.Name and uiGradient2.Offset.Y == 0.5 and magnitude2 <= n42 and getgenv().Auto_Ability and n41 > 0.5 then
                        for _, abilityName in Parry_Abilities do
                            if Player.Character.Abilities[abilityName].Enabled then
                                Parried = true
                                ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                                return
                            end
                        end
                    end

                    if attribute == Player.Name and curved then return end
                    if attribute == Player.Name and n41 > 0.5 and curvedMore and game.PlaceId ~= 15264892126 then return end
                    if Library.Flags.Phantom_Detection and attribute == Player.Name and Got_Phantomed then return end

                    if attribute == Player.Name and magnitude2 <= n43 and not Parried then
                        Auto_Parry.Play_Animation()
                        Auto_Parry.Parry(Library.Flags.Parry_Type)
                        Last_Parry = os.clock()
                        Parried = true
                        local now3 = os.clock()

                        task.spawn(function()
                            local n44 = math.clamp(value / 10, 5, 17)
                            local ballProperties = Auto_Parry:Get_Ball_Properties(ball2)
                            if not ballProperties then return end
                            local entityProperties = Auto_Parry:Get_Entity_Properties()
                            if not entityProperties then return end
                            local spamResult = Auto_Parry.Spam_Service({ Ball = ball2, Ball_Properties = ballProperties, Entity_Properties = entityProperties, Ping = n44 })
                            if not spamResult or spamResult == 0 then return end

                            while true do
                                RunService.Heartbeat:Wait()
                                if not (os.clock() - now3 >= 0.65 or not Parried) then continue end
                                break
                            end

                            Parried = false
                            if Parries >= 7 then return false end
                            Parries += 1

                            task.delay(0.5, function()
                                if Parries > 0 then Parries -= 1 end
                            end)

                            Connections_Manager.Prevent_AP_Parry_When_Manual_Parried = uiGradient:GetPropertyChangedSignal("Offset"):Once(function()
                                if uiGradient.Offset.Y < 0.5 and magnitude2 > spamResult then
                                    Parried = true
                                    now3 = os.clock()
                                end
                            end)
                        end)
                    end
                end
            end)
        else
            if Connections_Manager["Auto Parry"] then
                Connections_Manager["Auto Parry"]:Disconnect()
                Connections_Manager["Auto Parry"] = nil
            end
        end
    end,
})

-- =========================================================
-- Auto Spam — byte exact
-- =========================================================
MainTab:AddToggle("AutoSpamToggle", {
    Title = "auto spam",
    Default = false,
    Callback = function(arg)
        Library.Flags.Auto_Spam = arg
        if arg then
            if Connections_Manager["Auto Spam"] then
                Connections_Manager["Auto Spam"]:Disconnect()
                Connections_Manager["Auto Spam"] = nil
            end
            Connections_Manager["Auto Spam"] = RunService.PostSimulation:Connect(function()
                if not Library.Flags.Auto_Parry then return end
                local alive = workspace.Alive
                local character = Player.Character or Player.CharacterAdded:Wait()
                if character.Parent ~= alive then return end

                local ball = Auto_Parry.Get_Ball()
                if not ball then return end
                if not ball:FindFirstChild("zoomies") then return end

                local n41 = math.clamp(Auto_Parry.Get_Ping() / 10, 10, 16.5)
                local ballProperties = Auto_Parry:Get_Ball_Properties(ball)
                if not ballProperties then return end
                local entityProperties = Auto_Parry:Get_Entity_Properties()
                if not entityProperties then return end
                local spamResult = Auto_Parry.Spam_Service({ Ball = ball, Ball_Properties = ballProperties, Entity_Properties = entityProperties, Ping = n41 })
                if not spamResult or spamResult == 0 then return end

                local hotbar = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("Hotbar")
                character = character and character:FindFirstChild("Abilities")
                local visible = hotbar and hotbar:FindFirstChild("Ability") and hotbar.Ability:FindFirstChild("Duration") and hotbar.Ability.Duration.Visible
                local infinity = character and character:FindFirstChild("Infinity")
                infinity = infinity and infinity.Enabled
                infinity = visible and infinity and Infinity_Ball
                character = character and character:FindFirstChild("Time Hole")
                character = character and character.Enabled

                if infinity then
                    Parries = 0
                    return
                end

                if not (visible and character) then
                    local position = (ball == Tracked_Ball and Real_Ball_Position) or ball.Position
                    if (Player.Character.PrimaryPart.Position - position).Magnitude <= spamResult and Parries >= tonumber(Library.Flags.Clashing_Threshold) then
                        if Is_Mobile then
                            Auto_Parry.Parry_Animation()
                        end
                        if not Is_Mobile then
                            Auto_Parry.Animation_Fix()
                        end
                        Auto_Parry.Parry(Library.Flags.Parry_Type)
                    end
                    return
                end
                Parries = 0
            end)
        elseif Connections_Manager["Auto Spam"] then
            Connections_Manager["Auto Spam"]:Disconnect()
            Connections_Manager["Auto Spam"] = nil
        end
    end,
})

-- =========================================================
-- Triggerbot
-- =========================================================
MainTab:AddKeybind("TriggerbotKey", {
    Title = "triggerbot",
    Mode = "Toggle",
    Default = "T",
    Callback = function(arg)
        Library.Flags.Triggerbot = arg
        Auto_Parry.Start_Triggerbot()
    end,
})

-- =========================================================
-- Dropdowns / Sliders
-- =========================================================
MainTab:AddDropdown("ParryTypeDropdown", {
    Title = "parry type",
    Values = { "Camera", "High", "FFA", "Dot", "Dot Pointer", "Closest", "Random", "Backwards" },
    Multi = false,
    Default = "Camera",
    Callback = function(v) Library.Flags.Parry_Type = v end,
})

MainTab:AddDropdown("ParryOptionsDropdown", {
    Title = "parry options",
    Values = { "Remote", "Hardware", "Keyboard" },
    Multi = false,
    Default = "Remote",
    Callback = function(v) Library.Flags.Parry_Options = v end,
})

MainTab:AddDropdown("ClashThresholdDropdown", {
    Title = "clashing threshold",
    Values = { "1", "2", "3" },
    Multi = false,
    Default = "1",
    Callback = function(v) Library.Flags.Clashing_Threshold = tostring(v) end,
})

MainTab:AddSlider("ParryRangeSlider", {
    Title = "parry range",
    Default = 0, Min = 0, Max = 10, Rounding = 1,
    Callback = function(v) Library.Flags.Parry_Range = tonumber(v) end,
})

MainTab:AddSlider("AccuracySlider", {
    Title = "parry accuracy",
    Default = 72, Min = 1, Max = 100, Rounding = 1,
    Callback = function(v)
        Library.Flags.Parry_Accuracy = tonumber(v)
        if Library.Flags.Phantom_Detection then
            Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.024747474747474751
        else
            Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.0030303030303030303
        end
    end,
})

MainTab:AddToggle("CooldownProtectionToggle", {
    Title = "cooldown protection",
    Default = false,
    Callback = function(arg) getgenv().Cooldown_Protection = arg end,
})

MainTab:AddToggle("AutoAbilityToggle", {
    Title = "auto ability",
    Default = false,
    Callback = function(arg) getgenv().Auto_Ability = arg end,
})

VisualTab:AddToggle("PhantomDetectionToggle", {
    Title = "phantom protection",
    Default = false,
    Callback = function(arg)
        Library.Flags.Phantom_Detection = arg
        if arg then
            Speed_Divisor_Multiplier = 0.8 + ((Library.Flags.Parry_Accuracy or 72) - 1) * 0.024747474747474751
        else
            Speed_Divisor_Multiplier = 0.8 + ((Library.Flags.Parry_Accuracy or 72) - 1) * 0.0030303030303030303
        end
    end,
})

-- =========================================================
-- Hotkeys (byte)
-- =========================================================
Connections_Manager["Keybinds Parry Types"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local keyCode = input.KeyCode
    local parryType
    if keyCode == Enum.KeyCode.Z or keyCode == Enum.KeyCode.One then
        parryType = Library.Flags.Parry_Type == "Backwards" and "Camera" or "Backwards"
    end
    if keyCode == Enum.KeyCode.X or keyCode == Enum.KeyCode.Two then
        parryType = Library.Flags.Parry_Type == "Dot Pointer" and "Camera" or "Dot Pointer"
    end
    if keyCode == Enum.KeyCode.C or keyCode == Enum.KeyCode.Three then
        parryType = Library.Flags.Parry_Type == "Dot" and "Camera" or "Dot"
    end
    if keyCode == Enum.KeyCode.Four then
        parryType = Library.Flags.Parry_Type == "FFA" and "Camera" or "FFA"
    end
    if parryType then
        Library.Flags.Parry_Type = parryType
    end
end)
