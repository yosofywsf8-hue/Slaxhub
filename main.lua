--[[
    ██╗   ██╗██╗██╗   ██╗ ██████╗
    Vivo — Delta Safe Edition
    Native UI (No HttpGet) | Engine Byte 100% | Auto-Save
]]
if _G.primas then return end
_G.primas = true

if setfpscap then pcall(setfpscap, 9999) end
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = Instance.new("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Library = { Flags = {} }

-- =========================================================
-- AUTO-SAVE
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

task.spawn(function()
    while task.wait(5) do save_config() end
end)

-- =========================================================
-- STATE
-- =========================================================
local Parry_Abilities, Ignored_VFX, Infinity_Ball, Tornado_Time, Parries, Speed_Divisor_Multiplier
local Last_Parry, Parried, Got_Phantomed
local Is_Curved_Data = {}
local Last_FFA_Target = nil
local Vector2_Mouse_Location = {0, 0}
local Last_Played, Bypass_Cd = 0, false
local Is_Mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local touchEnabled = UserInputService.TouchEnabled
local Real_Ball_Position, Tracked_Ball, Block_Keybind, Play_Parry
local Connections_Manager = {}
local Auto_Parry = {}
local sendParry

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
    Got_Phantomed = false
    Speed_Divisor_Multiplier = 0.8 + ((Library.Flags["accuracy"] or 72) - 1) * 0.0030303030303030303
end

-- =========================================================
-- NATIVE UI (Delta Safe)
-- =========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = CoreGui
ScreenGui.Name = "VivoUI"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 440, 0, 380)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Title.Text = "Vivo"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Parent = MainFrame
Scroll.Size = UDim2.new(1, -20, 1, -60)
Scroll.Position = UDim2.new(0, 10, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
Scroll.ScrollBarImageColor3 = Color3.fromRGB(125, 109, 247)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", Scroll).Padding = UDim.new(0, 8)
Instance.new("UIPadding", Scroll).PaddingRight = UDim.new(0, 5)

local function CreateToggle(text, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Parent = Scroll
    Frame.Size = UDim2.new(1, -5, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Frame.BorderSizePixel = 0
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Gotham

    local Button = Instance.new("TextButton")
    Button.Parent = Frame
    Button.Size = UDim2.new(0, 50, 0, 24)
    Button.Position = UDim2.new(1, -62, 0.5, -12)
    Button.BackgroundColor3 = default and Color3.fromRGB(125, 109, 247) or Color3.fromRGB(45, 45, 55)
    Button.Text = default and "ON" or "OFF"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Font = Enum.Font.GothamBold
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 4)

    local state = default
    Button.MouseButton1Click:Connect(function()
        state = not state
        Button.Text = state and "ON" or "OFF"
        Button.BackgroundColor3 = state and Color3.fromRGB(125, 109, 247) or Color3.fromRGB(45, 45, 55)
        Library.Flags[text] = state
        save_config()
        callback(state)
    end)
    return Frame
end

local function CreateDropdown(text, options, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Parent = Scroll
    Frame.Size = UDim2.new(1, -5, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Frame.BorderSizePixel = 0
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Gotham

    local CurrentBtn = Instance.new("TextButton")
    CurrentBtn.Parent = Frame
    CurrentBtn.Size = UDim2.new(0, 130, 0, 24)
    CurrentBtn.Position = UDim2.new(1, -142, 0.5, -12)
    CurrentBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    CurrentBtn.Text = tostring(default)
    CurrentBtn.TextColor3 = Color3.new(1, 1, 1)
    CurrentBtn.TextSize = 12
    CurrentBtn.Font = Enum.Font.Gotham
    Instance.new("UICorner", CurrentBtn).CornerRadius = UDim.new(0, 4)

    local index = 1
    for i, v in ipairs(options) do
        if tostring(v) == tostring(default) then index = i break end
    end

    CurrentBtn.MouseButton1Click:Connect(function()
        index = index + 1
        if index > #options then index = 1 end
        local val = options[index]
        CurrentBtn.Text = tostring(val)
        Library.Flags[text] = val
        save_config()
        callback(val)
    end)
    return Frame
end

local function CreateSlider(text, min, max, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Parent = Scroll
    Frame.Size = UDim2.new(1, -5, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Frame.BorderSizePixel = 0
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Parent = Frame
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Gotham

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Parent = Frame
    ValLabel.Size = UDim2.new(0, 40, 1, 0)
    ValLabel.Position = UDim2.new(1, -120, 0, 0)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(default)
    ValLabel.TextColor3 = Color3.fromRGB(125, 109, 247)
    ValLabel.TextSize = 14
    ValLabel.Font = Enum.Font.GothamBold

    local Minus = Instance.new("TextButton")
    Minus.Parent = Frame
    Minus.Size = UDim2.new(0, 24, 0, 24)
    Minus.Position = UDim2.new(1, -72, 0.5, -12)
    Minus.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    Minus.Text = "-"
    Minus.TextColor3 = Color3.new(1, 1, 1)
    Minus.Font = Enum.Font.GothamBold
    Instance.new("UICorner", Minus).CornerRadius = UDim.new(0, 4)

    local Plus = Instance.new("TextButton")
    Plus.Parent = Frame
    Plus.Size = UDim2.new(0, 24, 0, 24)
    Plus.Position = UDim2.new(1, -44, 0.5, -12)
    Plus.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    Plus.Text = "+"
    Plus.TextColor3 = Color3.new(1, 1, 1)
    Plus.Font = Enum.Font.GothamBold
    Instance.new("UICorner", Plus).CornerRadius = UDim.new(0, 4)

    local current = default
    local function update(v)
        current = math.clamp(v, min, max)
        ValLabel.Text = tostring(current)
        Library.Flags[text] = current
        save_config()
        callback(current)
    end

    Minus.MouseButton1Click:Connect(function() update(current - 1) end)
    Plus.MouseButton1Click:Connect(function() update(current + 1) end)
    return Frame
end

-- =========================================================
-- ENGINE INIT (task.spawn عشان UI يظهر أولاً)
-- =========================================================
task.spawn(function()
    local success, err = pcall(function()
        -- 1. Settings & Net
        pcall(function()
            Block_Keybind = PlayerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind1.TextBox.Text
                or PlayerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind2.TextBox.Text
                or PlayerGui.Settings.Frame.Frame["Keybinds/Block"].Keybind3.TextBox.Text
        end)
        Block_Keybind = Block_Keybind or "Q"

        pcall(function()
            local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
            for _, child in net:GetChildren() do
                if child:IsA("UnreliableRemoteEvent") and child.Name ~= "URE/ReplicateBallPosition" then
                    Connections_Manager["Real Ball Position"] = child.OnClientEvent:Connect(function(arg, arg2)
                        if not arg or not arg.Parent then
                            if arg == Tracked_Ball then Tracked_Ball, Real_Ball_Position = nil, nil end
                            return
                        end
                        Tracked_Ball, Real_Ball_Position = arg, arg2
                    end)
                end
            end
        end)

        -- 2. VFX Fix
        for _, connection in getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent) do
            connection:Disable(); connection:Disconnect()
        end
        for _, connection in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
            if connection and connection.Function then
                Play_Parry = connection.Function
                connection:Disable(); connection:Disconnect()
            end
        end

        if Play_Parry then
            Connections_Manager["Weapon Changer"] = ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
                local varargs = { ... }
                if tostring(varargs[4]) == LocalPlayer.Name then
                    local ok, sword = pcall(function()
                        return require(ReplicatedStorage.Shared.ReplicatedInstances.Swords):GetSword(LocalPlayer:GetAttribute("CurrentlyEquippedSword"))
                    end)
                    if ok and sword and sword.SlashName then
                        varargs[1] = sword.SlashName
                        varargs[3] = sword.Name
                    end
                end
                return Play_Parry(unpack(varargs))
            end)
        end

        Connections_Manager["Parry Animation Fix"] = ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
            Bypass_Cd = true
            Parried = false
            local character = LocalPlayer.Character
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

        -- 3. Hook Parry
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

        -- 4. Helpers
        local balls = workspace:WaitForChild("Balls")
        
        Auto_Parry.Client_Ball = function()
            for _, child in balls:GetChildren() do
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

        Auto_Parry.Get_Ping = function()
            local ok, value = pcall(function()
                return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            return ok and value or LocalPlayer:GetNetworkPing() * 1000
        end

        Auto_Parry.Linear_Interpolation = function(a, b, t) return a + (b - a) * t end

        Auto_Parry.Encrypted_Clone = function()
            for _, child in workspace.Alive:GetChildren() do
                if child and child.Name and child.Name:find("ENCRYPTED CLONE", 1, true) then
                    return child
                end
            end
        end

        -- 5. Curve
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

        local function Targeted_Ball()
            for _, ball in Auto_Parry.Get_Balls() do
                if ball:GetAttribute("target") == LocalPlayer.Name then return ball end
            end
        end

        -- 6. Is_Curved
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
                if Time - Curve_Data.Backward_Flip_Time < 0.2 then Curve_Data.Backward_Flips += 1 else Curve_Data.Backward_Flips = 0 end
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

        -- 7. Properties
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

        -- 8. Parry Data
        Auto_Parry.Parry_Data = function(arg)
            if touchEnabled then
                Vector2_Mouse_Location = { workspace.CurrentCamera.ViewportSize.X/2, workspace.CurrentCamera.ViewportSize.Y/2 }
            else
                local m = UserInputService:GetMouseLocation()
                Vector2_Mouse_Location = { m.X, m.Y }
            end
            local screen = {}
            for _, ch in workspace.Alive:GetChildren() do
                if ch:FindFirstChild("HumanoidRootPart") then
                    screen[ch.Name] = workspace.CurrentCamera:WorldToScreenPoint(ch.HumanoidRootPart.Position)
                end
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

        -- 9. Parry Exec
        Auto_Parry.Parry = function(arg)
            if Library.Flags["parry options"] == "Hardware" then mouse1click(); return end
            if Library.Flags["parry options"] == "Keyboard" then
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
                -- VFX animation trigger
            end
        end

        -- 10. Loops
        local autoParryConn = nil
        getgenv().Vivo_AutoParry = function(on)
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
                    
                    local maxShield = LocalPlayer.Character.PrimaryPart:FindFirstChild("MaxShield")
                    local singularityCape = LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape")
                    if maxShield or singularityCape then
                        Parries = 0
                        return
                    end

                    if attribute ~= LocalPlayer.Name then continue end
                    local magnitude = zoomies.VectorVelocity.Magnitude
                    local value = Auto_Parry.Get_Ping()
                    local n42 = math.clamp(value / 10, 10, 16) + magnitude / (2.3497562749127492 + math.clamp(magnitude, 0, 425) * 0.002) * Speed_Divisor_Multiplier
                    local n43 = n42 + (Library.Flags["parry range"] or 0)
                    local pos = (ball2 == Tracked_Ball and Real_Ball_Position) or ball2.Position
                    local mag2 = (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude
                    local curved = Auto_Parry.Is_Curved(ball2)
                    local curvedMore = Auto_Parry.Is_Curved2(ball2)

                    if curved then return end
                    if n41 > 0.5 and curvedMore and game.PlaceId ~= 15264892126 then return end
                    if Library.Flags["phantom protection"] and Got_Phantomed then return end

                    if mag2 <= n43 and not Parried then
                        Auto_Parry.Play_Animation()
                        Auto_Parry.Parry(Library.Flags["parry type"])
                        Last_Parry = os.clock()
                        Parried = true
                        task.delay(0.65, function() Parried = false end)
                    end
                end
            end)
        end

        local spamConn = nil
        getgenv().Vivo_AutoSpam = function(on)
            if spamConn then spamConn:Disconnect(); spamConn = nil end
            if not on then return end
            spamConn = RunService.PostSimulation:Connect(function()
                if not Library.Flags["auto parry"] then return end
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
                if (LocalPlayer.Character.PrimaryPart.Position - pos).Magnitude <= range and Parries >= tonumber(Library.Flags["clashing threshold"] or "1") then
                    if Is_Mobile then Auto_Parry.Play_Animation() end
                    if not Is_Mobile then
                        pcall(function()
                            local identity = getthreadidentity()
                            if identity ~= 8 then setthreadidentity(8) end
                            VirtualInputManager:SendKeyEvent(true, Block_Keybind, false, game)
                            VirtualInputManager:SendKeyEvent(false, Block_Keybind, false, game)
                            if identity ~= 8 then setthreadidentity(identity) end
                        end)
                    end
                    Auto_Parry.Parry(Library.Flags["parry type"])
                end
            end)
        end

        -- 11. Events
        ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(arg, arg2)
            Infinity_Ball = arg2
        end)

        ReplicatedStorage.Remotes.Phantom.OnClientEvent:Connect(function(arg, arg2)
            if arg2.Name == LocalPlayer.Name then
                Got_Phantomed = true
                task.delay(0.35, function() Got_Phantomed = false end)
            end
        end)

        workspace.Runtime.ChildAdded:Connect(function(child)
            local name = child.Name
            if Library.Flags["phantom protection"] and (name == "maxTransmission" or name == "transmissionpart") then
                local weld = child:FindFirstChildWhichIsA("WeldConstraint")
                if weld then
                    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    if char and weld.Part1 and weld.Part1:IsDescendantOf(char) then
                        local clientBall = Auto_Parry.Client_Ball()
                        if clientBall and clientBall:GetAttribute("highlighted") then
                            Got_Phantomed = true
                            task.delay(0.35, function() Got_Phantomed = false end)
                        end
                        weld:Destroy()
                    end
                end
            end
            if name == "Tornado" then
                Tornado_Time = tick()
                child:GetAttributeChangedSignal("TornadoTime"):Connect(function() Tornado_Time = tick() end)
                child.Destroying:Connect(function() Tornado_Time = nil end)
            end
        end)

        workspace.Balls.ChildAdded:Connect(function(child)
            if child:GetAttribute("realBall") then Auto_Parry.Get_Curve(child) end
        end)

        workspace.Balls.ChildRemoved:Connect(function(child)
            local data = Is_Curved_Data[child]
            if data then
                if data.From then data.From:Disconnect() end
                if data.Target then data.Target:Disconnect() end
                Is_Curved_Data[child] = nil
            end
            Last_FFA_Target = nil
        end)

        print("[Vivo] Engine Loaded Perfectly")
    end)
    
    if not success then
        warn("[Vivo] Engine Error: " .. tostring(err))
    end
end)

-- =========================================================
-- UI TOGGLES BIND
-- =========================================================
CreateToggle("auto parry", Library.Flags["auto parry"] or false, function(v)
    if getgenv().Vivo_AutoParry then getgenv().Vivo_AutoParry(v) end
end)

CreateToggle("auto spam", Library.Flags["auto spam"] or false, function(v)
    if getgenv().Vivo_AutoSpam then getgenv().Vivo_AutoSpam(v) end
end)

CreateDropdown("parry type", {"Camera", "Backwards", "High", "Random"}, Library.Flags["parry type"] or "Camera", function(v)
    -- يحدث تلقائياً في المحرك
end)

CreateDropdown("parry options", {"Remote", "Hardware", "Keyboard"}, Library.Flags["parry options"] or "Remote", function(v)
    -- يحدث تلقائياً في المحرك
end)

CreateDropdown("clashing threshold", {"1", "2", "3"}, Library.Flags["clashing threshold"] or "1", function(v)
    -- يحدث تلقائياً في المحرك
end)

CreateSlider("accuracy", 1, 100, Library.Flags["accuracy"] or 72, function(v)
    if Library.Flags["phantom protection"] then
        Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.024747474747474751
    else
        Speed_Divisor_Multiplier = 0.8 + (v - 1) * 0.0030303030303030303
    end
end)

CreateSlider("parry range", 0, 10, Library.Flags["parry range"] or 0, function(v)
    -- يحدث تلقائياً في المحرك
end)

CreateToggle("phantom protection", Library.Flags["phantom protection"] or false, function(v)
    if v then
        Speed_Divisor_Multiplier = 0.8 + ((Library.Flags["accuracy"] or 72) - 1) * 0.024747474747474751
    else
        Speed_Divisor_Multiplier = 0.8 + ((Library.Flags["accuracy"] or 72) - 1) * 0.0030303030303030303
    end
end)

print("[Vivo] Native UI Loaded Perfectly")
