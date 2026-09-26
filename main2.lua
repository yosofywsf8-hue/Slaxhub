-- ═══════════════════════════════════════════════════════
-- EAGLE Hub X - Fixed Double Parry + Direction Check
-- Original EAGLE + Fix
-- ═══════════════════════════════════════════════════════

task.spawn(function()

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "EAGLE Hub X",
    SubTitle = "Paid Version",
    TabWidth = 100,
    Size = UDim2.fromOffset(440, 315),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Rage      = Window:AddTab({Title = "Autoparry", Icon = "sword"}),
    Spam      = Window:AddTab({Title = "Spam",       Icon = "skull"}),
    Detection = Window:AddTab({Title = "Detection",  Icon = "monitor"}),
    Visuals   = Window:AddTab({Title = "Visuals",    Icon = "eye"}),
    Misc      = Window:AddTab({Title = "Misc",       Icon = "settings"}),
    Settings  = Window:AddTab({Title = "Settings",   Icon = "sliders"})
}

local Options = Fluent.Options

repeat task.wait(0.5) until game:IsLoaded()

local Players           = cloneref(game:GetService('Players'))
local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local UserInputService  = cloneref(game:GetService('UserInputService'))
local RunService        = cloneref(game:GetService('RunService'))
local TweenService      = cloneref(game:GetService('TweenService'))
local Stats             = cloneref(game:GetService('Stats'))
local Debris            = cloneref(game:GetService('Debris'))
local CoreGui           = cloneref(game:GetService('CoreGui'))
local HttpService       = cloneref(game:GetService('HttpService'))
local Workspace         = cloneref(game:GetService('Workspace'))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local Alive   = Workspace:FindFirstChild("Alive") or Workspace:WaitForChild("Alive")
local Runtime = Workspace.Runtime

local function detectMobile()
    local touch = UserInputService.TouchEnabled
    local mouse = UserInputService.MouseEnabled
    local keyboard = UserInputService.KeyboardEnabled
    if touch and not keyboard then return true end
    if touch and not mouse then return true end
    return false
end

local System = {
    __properties = {
        __autoparry_enabled = false,
        __triggerbot_enabled = false,
        __manual_spam_enabled = false,
        __auto_spam_enabled = false,
        __play_animation = false,
        __accuracy = 50,
        __divisor_multiplier = 1.1,
        __parried = false,
        __training_parried = false,
        __spam_threshold = 1.5,
        __parries = 0,
        __parry_key = nil,
        __grab_animation = nil,
        __tornado_time = tick(),
        __first_parry_done = false,
        __connections = {},
        __reverted_remotes = {},
        __spam_accumulator = 0,
        __spam_rate = 340,
        __infinity_active = false,
        __deathslash_active = false,
        __timehole_active = false,
        __slashesoffury_active = false,
        __slashesoffury_count = 0,
        __is_mobile = detectMobile(),
        __mobile_guis = {},
        __randomized_accuracy_enabled = false,
        __speed_display_enabled = false,
        __auto_jump_enabled = false,
        __ball_speed = 0,
        __peak_ball_speed = 0,
        __headless_enabled = false,
        __korblox_enabled = false,
        __thunder_dash_enabled = false
    },
    __config = {
        __detections = {
            __infinity=false,__deathslash=false,
            __timehole=false,__slashesoffury=false,__phantom=false
        }
    },
    __triggerbot = {
        __enabled=false,__is_parrying=false,
        __parries=0,__max_parries=10000,__parry_delay=0.05
    }
}

local function update_divisor()
    System.__properties.__divisor_multiplier = 0.7 + (System.__properties.__accuracy - 1) * (0.9/99)
end

local function update_randomized_accuracy()
    if not System.__properties.__randomized_accuracy_enabled then return end
    local ping_str = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping = tonumber(ping_str:match("%d+")) or 0
    local new_accuracy
    if ping >= 90 then new_accuracy = 4
    elseif ping <= 50 then new_accuracy = math.random(70, 100)
    else new_accuracy = System.__properties.__accuracy end
    if new_accuracy then System.__properties.__accuracy = new_accuracy; update_divisor() end
end

task.spawn(function()
    while task.wait(1) do
        if System.__properties.__randomized_accuracy_enabled then update_randomized_accuracy() end
    end
end)

-- ============================================================
-- TOKEN-BASED REMOTE FINDER
-- ============================================================

local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
local workspace = cloneref(game:GetService('Workspace'))

local _token
local _tokenFound = false

for _, Function in getgc(true) do
    if type(Function) ~= 'function' or not debug.info(Function, 's'):find('PRY', 1, true) then
        continue
    end
    for _, value in debug.getupvalues(Function) do
        if type(value) == 'function' then
            print('found.')
            _token = value
            _tokenFound = true
            break
        end
    end
    if _token then break end
end

if not _tokenFound then
    Fluent:Notify({Title="EAGLE Hub X", Content="Remote not found executo script again Eror inject.", Duration=5})
    return
end

function _tokenize(_remote_uid)
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)
    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index ) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

local _reverted = {}
local _original = {}
local _captured = nil
local _capturedRemote = nil
local _capturedArgs = nil

function _is_valid(args)
    if not args or #args < 8 then return false end
    return true
end

function _hook(remote)
    if not remote then return end
    if _reverted[remote] then return end
    if _original[getrawmetatable(remote)] then return end
    
    _original[getrawmetatable(remote)] = true
    local _meta = getrawmetatable(remote)
    setreadonly(_meta, false)

    local _old = _meta.__index
    _meta.__index = function(self, key)
        if (key == 'FireServer' and self:IsA('RemoteEvent')) or
           (key == 'InvokeServer' and self:IsA('RemoteFunction')) then
            return function(_, ...)
                local _arguments = {...}
                if _is_valid(_arguments) then
                    if not _reverted[self] then
                        _reverted[self] = _arguments
                        _captured = {remote = self, args = _arguments}
                        _capturedRemote = self
                        _capturedArgs = _arguments
                        print("Remote captured! Name:", self.Name)
                    end
                end
                return _old(self, key)(_, unpack(_arguments))
            end
        end
        return _old(self, key)
    end
    setreadonly(_meta, true)
end

for _iterator, _remote in pairs(replicated_storage:GetDescendants()) do
    if _remote:IsA('RemoteEvent') or _remote:IsA('RemoteFunction') then
        _hook(_remote)
    end
end

task.wait(5)

task.spawn(function()
    local attempts = 0
    while not _capturedRemote and attempts < 30 do
        task.wait(1)
        attempts = attempts + 1
    end
    if _capturedRemote then
        Fluent:Notify({Title="EAGLE Hub X", Content="The anticheat Bypass succes", Duration=3})
        print("Remote captured:", _capturedRemote.Name)
    else
        Fluent:Notify({Title="EAGLE Hub X", Content="Remote not found Eror Args (2) Bypass.", Duration=5})
        print("Remote not captured!")
    end
end)

-- ========== FIRE PARRY ==========
local function fireParryRemote(curveCF)
    if not _capturedRemote or not _capturedArgs then
        return false
    end
    
    local cam = Workspace.CurrentCamera
    local is_mobile = System.__properties.__is_mobile
    local aim_target

    if is_mobile then
        local vp = cam.ViewportSize
        aim_target = {math.floor(vp.X / 2), math.floor(vp.Y / 2)}
    else
        local ok, mouse = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and mouse then
            aim_target = {math.floor(mouse.X), math.floor(mouse.Y)}
        else
            local vp = cam.ViewportSize
            aim_target = {math.floor(vp.X / 2), math.floor(vp.Y / 2)}
        end
    end

    local event_data = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local ok, sp = pcall(function() return cam:WorldToScreenPoint(entity.PrimaryPart.Position) end)
                if ok then event_data[entity.Name] = sp end
            end
        end
    end
    
    local packet = {
        _capturedArgs[1],
        _capturedArgs[2],
        _tokenize(_capturedArgs[2]),
        0.5,
        curveCF or cam.CFrame,
        event_data,
        aim_target,
        false
    }
    
    pcall(function()
        if _capturedRemote:IsA('RemoteEvent') then
            _capturedRemote:FireServer(unpack(packet))
        elseif _capturedRemote:IsA('RemoteFunction') then
            _capturedRemote:InvokeServer(unpack(packet))
        end
    end)
    return true
end

print("Based Remote Loaded!")

-- ========== ANIMATION SYSTEM ==========
System.animation = {}

local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local LastPlayedd = 0
local Sword_CP = false
local Sword_Spped = 1
local Grab_Parry = nil
local AnimFix_Cache = {}

local function GetParryAnimation(swordName)
    if not swordName or swordName == "" then
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    if AnimFix_Cache[swordName] then
        return AnimFix_Cache[swordName]
    end
    local ok, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(swordName)
    end)
    if not ok or not swordData or type(swordData) ~= "table" or not swordData.AnimationType then
        AnimFix_Cache[swordName] = SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        return AnimFix_Cache[swordName]
    end
    for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
        if obj.Name == swordData.AnimationType then
            local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
            if anim then
                AnimFix_Cache[swordName] = anim
                return anim
            end
        end
    end
    AnimFix_Cache[swordName] = SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    return AnimFix_Cache[swordName]
end

local function GrabParryPlay(track)
    if not track then return end
    pcall(function()
        track:Play(
            track:GetAttribute("PlayFadeTime") or 0,
            track:GetAttribute("PlayWeight") or 1,
            track:GetAttribute("PlaySpeed") or 1
        )
    end)
end

local function GrabParryStop(track)
    if not track then return end
    pcall(function()
        track:Stop(track:GetAttribute("StopFadeTime") or 0.1)
    end)
end

function System.animation.play_grab_parry()
    if not System.__properties.__play_animation then return end
    if not ((os.clock() - LastPlayedd) >= (Sword_Spped - 0.8) or Sword_CP) then return end
    LastPlayedd = os.clock()
    Sword_CP = false
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local currentSword
    if getgenv().skinChanger then
        currentSword = (getgenv().swordAnimations ~= "" and getgenv().swordAnimations)
                    or (getgenv().swordModel ~= "" and getgenv().swordModel)
                    or char:GetAttribute("CurrentlyEquippedSword")
    else
        currentSword = char:GetAttribute("CurrentlyEquippedSword")
    end
    local animation = GetParryAnimation(currentSword)
    if not animation then return end
    for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            track.TimePosition = 0
            GrabParryStop(track)
        elseif track.Name == "SuccessParry" or track.Name == "Success" then
            GrabParryStop(track)
        end
    end
    Grab_Parry = humanoid.Animator:LoadAnimation(animation)
    GrabParryPlay(Grab_Parry)
end

pcall(function()
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function()
        Sword_CP = true
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
            if track.Name == "GrabParry" or track.Name == "Grab" then
                GrabParryStop(track)
            end
        end
    end)
end)

-- ========== BALL SYSTEM ==========
System.ball = {}
function System.ball.get()
    local balls=Workspace:FindFirstChild('Balls'); if not balls then return nil end
    for _,ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then ball.CanCollide=false; return ball end
    end; return nil
end
function System.ball.get_all()
    local balls_table={}; local balls=Workspace:FindFirstChild('Balls')
    if not balls then return balls_table end
    for _,ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then ball.CanCollide=false; table.insert(balls_table,ball) end
    end; return balls_table
end

System.player = {}
local Closest_Entity=nil; local last_closest_check=0
function System.player.get_closest()
    local now=tick()
    if now-last_closest_check < 0.1 then return Closest_Entity end
    last_closest_check=now
    local max_distance=math.huge; local closest_entity=nil
    if not Alive then return nil end
    for _,entity in pairs(Alive:GetChildren()) do
        if entity ~= LocalPlayer.Character and entity.PrimaryPart then
            local distance=LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
            if distance < max_distance then max_distance=distance; closest_entity=entity end
        end
    end
    Closest_Entity=closest_entity; return closest_entity
end

local CURVE_NAMES = {"Camera","Random","Accelerated","Backwards","Slow","High","Normal","Speed","Down","Left","Right"}
local Selected_Parry_Type = "Camera"
local CurveType = "Camera"

System.curve = {}

function System.curve.get_cframe()
    local Camera = Workspace.CurrentCamera
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local root_pos = root and root.Position or Camera.CFrame.Position

    local targetPart
    do
        local bestDist = math.huge
        local mouseLoc = not System.__properties.__is_mobile and UserInputService:GetMouseLocation() or nil
        if Alive then
            for _, v in pairs(Alive:GetChildren()) do
                if v ~= LocalPlayer.Character and v.PrimaryPart then
                    local screenPos, onScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                    if onScreen then
                        local dist
                        if mouseLoc then
                            dist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                        else
                            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                            dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        end
                        if dist < bestDist then bestDist = dist; targetPart = v.PrimaryPart end
                    end
                end
            end
        end
    end
    local target_pos = targetPart and targetPart.Position or (root_pos + Camera.CFrame.LookVector * 100)

    local Parry_Type = Selected_Parry_Type
    local cf

    if Parry_Type == "Camera" then
        cf = Camera.CFrame
    elseif Parry_Type == "Random" then
        local direction = (target_pos - root_pos).Unit
        local random_offset
        local attempts = 0
        repeat
            random_offset = Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000))
            local curve_dir = (target_pos + random_offset - root_pos).Unit
            local dot = direction:Dot(curve_dir)
            attempts = attempts + 1
        until dot < 0.95 or attempts > 10
        cf = CFrame.new(root_pos, target_pos + random_offset)
    elseif Parry_Type == "Accelerated" then
        cf = CFrame.new(root_pos, target_pos + Vector3.new(0, 5, 0))
    elseif Parry_Type == "Backwards" then
        local direction = (root_pos - target_pos).Unit
        local backwards_pos = root_pos + direction * 10000 + Vector3.new(0, 1000, 0)
        cf = CFrame.new(Camera.CFrame.Position, backwards_pos)
    elseif Parry_Type == "Slow" then
        cf = CFrame.new(root_pos, target_pos + Vector3.new(0, -9e18, 0))
    elseif Parry_Type == "High" then
        cf = CFrame.new(root_pos, target_pos + Vector3.new(0, 9e18, 0))
    elseif Parry_Type == "Normal" then
        cf = CFrame.new(root_pos, root_pos + (root and root.CFrame.LookVector or Camera.CFrame.LookVector))
    elseif Parry_Type == "Speed" then
        cf = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * 5)
    elseif Parry_Type == "Down" then
        cf = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * -9e9)
    elseif Parry_Type == "Left" then
        cf = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Camera.CFrame.RightVector * 9e9)
    elseif Parry_Type == "Right" then
        cf = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.RightVector * 9e9)
    else
        cf = Camera.CFrame
    end

    return cf
end

System.parry = {}
function System.parry.execute()
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    fireParryRemote(System.curve.get_cframe())
    if System.__properties.__parries > 10000 then return end
    System.__properties.__parries=System.__properties.__parries+1
    task.delay(0.5,function() if System.__properties.__parries > 0 then System.__properties.__parries=System.__properties.__parries-1 end end)
end

function System.parry.keypress()
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    fireParryRemote(System.curve.get_cframe())
    if System.__properties.__parries > 10000 then return end
    System.__properties.__parries=System.__properties.__parries+1
    task.delay(0.5,function() if System.__properties.__parries > 0 then System.__properties.__parries=System.__properties.__parries-1 end end)
end

function System.parry.execute_action()
    System.animation.play_grab_parry(); System.parry.execute()
end

local function linear_predict(a,b,t) return a+(b-a)*t end

System.detection = {
    __ball_properties = {__aerodynamic_time=tick(),__last_warping=tick(),__lerp_radians=0,__curving=tick()}
}

function System.detection.is_curved()
    local props=System.detection.__ball_properties
    local ball=System.ball.get(); if not ball then return false end
    local zoomies=ball:FindFirstChild("zoomies"); if not zoomies then return false end
    local velocity=zoomies.VectorVelocity; local speed=velocity.Magnitude
    if speed < 1 then return false end
    local ball_dir=velocity.Unit; local char=LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local pos=char.PrimaryPart.Position; local direction=(pos-ball.Position).Unit
    local dot=direction:Dot(ball_dir)
    local ping=Stats.Network.ServerStatsItem["Data Ping"]:GetValue()/1000
    local distance=(pos-ball.Position).Magnitude; local reach_time=distance/speed-ping
    local dot_threshold=math.clamp(0.55-(ping*0.75),-1,0.45)
    local speed_threshold=math.min(speed/100,45)
    local ball_distance_threshold=15-math.min(distance/1000,15)+speed_threshold
    local clamped_dot=math.clamp(dot,-1,1); local radians=math.asin(clamped_dot)
    props.__lerp_radians=linear_predict(props.__lerp_radians,radians,0.85)
    if props.__lerp_radians < 0.016 then props.__last_warping=tick() end
    if distance < (ball_distance_threshold*0.85) then return false end
    if (tick()-props.__last_warping) < (reach_time/1.4) then return true end
    if (tick()-props.__curving) < (reach_time/1.1) then return true end
    return dot < dot_threshold
end

ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(c,d)
    System.__properties.__deathslash_active = d or false
end)
ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(a,b)
    System.__properties.__infinity_active = b or false
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
    local args={...}; local player=args[1]
    if player==LocalPlayer or player==LocalPlayer.Name or (player and player.Name==LocalPlayer.Name) then
        System.__properties.__timehole_active=true
    end
end)
ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
    System.__properties.__timehole_active=false
end)

local maxParryCount=36; local parryDelay=0.05

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    local args={...}; local player=args[1]
    if player==LocalPlayer or player==LocalPlayer.Name or (player and player.Name==LocalPlayer.Name) then
        System.__properties.__slashesoffury_active=true; System.__properties.__slashesoffury_count=0
    end
end)
ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_active=false; System.__properties.__slashesoffury_count=0
end)
ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_count=System.__properties.__slashesoffury_count+1
end)
ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    spawn(function()
        while System.__properties.__slashesoffury_active and System.__properties.__slashesoffury_count < maxParryCount do
            if System.__config.__detections.__slashesoffury then System.parry.execute(); task.wait(parryDelay)
            else break end
        end
    end)
end)

Runtime.ChildAdded:Connect(function(Object)
    if System.__config.__detections.__phantom then
        if Object.Name=="maxTransmission" or Object.Name=="transmissionpart" then
            local Weld=Object:FindFirstChildWhichIsA("WeldConstraint")
            if Weld then
                local Character=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                if Character and Weld.Part1==Character.HumanoidRootPart then
                    local CurrentBall=System.ball.get(); Weld:Destroy()
                    if CurrentBall then
                        local FocusConnection
                        FocusConnection=RunService.RenderStepped:Connect(function()
                            local Highlighted=CurrentBall:GetAttribute("highlighted")
                            if Highlighted==true then
                                ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                                System.__properties.__parried=true
                                task.delay(1,function() System.__properties.__parried=false end)
                            elseif Highlighted==false then FocusConnection:Disconnect() end
                        end)
                        task.delay(3,function() if FocusConnection and FocusConnection.Connected then FocusConnection:Disconnect() end end)
                    end
                end
            end
        end
    end
end)

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_,root)
    if root.Parent and root.Parent ~= LocalPlayer.Character then
        if not Alive or root.Parent.Parent ~= Alive then return end
    end
    local closest=System.player.get_closest(); local ball=System.ball.get()
    if not ball or not closest then return end
    local target_distance=(LocalPlayer.Character.PrimaryPart.Position-closest.PrimaryPart.Position).Magnitude
    local distance=(LocalPlayer.Character.PrimaryPart.Position-ball.Position).Magnitude
    local direction=(LocalPlayer.Character.PrimaryPart.Position-ball.Position).Unit
    local dot=direction:Dot(ball.AssemblyLinearVelocity.Unit)
    local curve_detected=System.detection.is_curved()
    if target_distance < 15 and distance < 15 and dot > -0.25 then
        if curve_detected then System.parry.execute_action() end
    end
    if System.__properties.__grab_animation then System.__properties.__grab_animation:Stop() end
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    if not Alive or LocalPlayer.Character.Parent ~= Alive then return end
    if System.__properties.__grab_animation then System.__properties.__grab_animation:Stop() end
end)

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(a,b)
    local Primary_Part=LocalPlayer.Character.PrimaryPart
    local Ball=System.ball.get(); if not Ball then return end
    local Zoomies=Ball:FindFirstChild('zoomies'); if not Zoomies then return end
    local Speed=Zoomies.VectorVelocity.Magnitude
    local Distance=(LocalPlayer.Character.PrimaryPart.Position-Ball.Position).Magnitude
    local Velocity=Zoomies.VectorVelocity; local Ball_Direction=Velocity.Unit
    local Direction=(LocalPlayer.Character.PrimaryPart.Position-Ball.Position).Unit
    local Dot=Direction:Dot(Ball_Direction)
    local Pings=Stats.Network.ServerStatsItem['Data Ping']:GetValue()
    local Speed_Threshold=math.min(Speed/100,40)
    local Reach_Time=Distance/Speed-(Pings/1000)
    local Enough_Speed=Speed > 1
    local Ball_Distance_Threshold=15-math.min(Distance/1000,15)+Speed_Threshold
    if Enough_Speed and Reach_Time > Pings/10 then
        Ball_Distance_Threshold=math.max(Ball_Distance_Threshold-15,15)
    end
    if b ~= Primary_Part and Distance > Ball_Distance_Threshold then
        System.detection.__ball_properties.__curving=tick()
    end
end)

-- ========== THUNDER DASH ==========
local ThunderDash = {}

function ThunderDash:Enable()
    if System.__properties.__thunder_dash_enabled then return end
    System.__properties.__thunder_dash_enabled = true
    local Abilities = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Abilities")
    local function removeCooldowns(ability)
        local success, module = pcall(require, ability)
        if success and module then
            if module.cooldown ~= nil then module.cooldown = 0 end
            if module.cooldownReductionPerUpgrade ~= nil then module.cooldownReductionPerUpgrade = 0 end
        end
    end
    for _, ability in ipairs(Abilities:GetChildren()) do
        removeCooldowns(ability)
    end
    Abilities.ChildAdded:Connect(removeCooldowns)
end

function ThunderDash:Disable()
    System.__properties.__thunder_dash_enabled = false
    local Abilities = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Abilities")
    local function restoreCooldowns(ability)
        local success, module = pcall(require, ability)
        if success and module then
            if module._originalCooldown ~= nil then module.cooldown = module._originalCooldown end
        end
    end
    for _, ability in ipairs(Abilities:GetChildren()) do
        restoreCooldowns(ability)
    end
end

-- ========== TRIGGERBOT ==========
System.triggerbot = {}

local triggerbotCooldown = false

function System.triggerbot.trigger(ball)
    if triggerbotCooldown then return end
    if System.__triggerbot.__is_parrying then return end
    if System.__triggerbot.__parries > System.__triggerbot.__max_parries then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and
       LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then return end
    
    triggerbotCooldown = true
    System.__triggerbot.__is_parrying=true
    System.__triggerbot.__parries=System.__triggerbot.__parries+1
    
    System.parry.execute()
    
    if System.__properties.__play_animation then
        System.animation.play_grab_parry()
    end
    
    task.delay(0.2,function()
        triggerbotCooldown = false
        if System.__triggerbot.__parries > 0 then System.__triggerbot.__parries=System.__triggerbot.__parries-1 end
    end)
    
    task.spawn(function()
        local start_time=tick()
        repeat RunService.Heartbeat:Wait()
        until (tick()-start_time >= 0.15 or not System.__triggerbot.__is_parrying)
        System.__triggerbot.__is_parrying=false
    end)
end

function System.triggerbot.loop()
    if not System.__triggerbot.__enabled then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and
       LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then return end
    local balls=Workspace:FindFirstChild('Balls'); if not balls then return end
    for _,ball in pairs(balls:GetChildren()) do
        if ball:IsA('BasePart') and ball:GetAttribute('target')==LocalPlayer.Name then
            System.triggerbot.trigger(ball)
            break
        end
    end
end

function System.triggerbot.enable(enabled)
    System.__triggerbot.__enabled=enabled
    if enabled then
        if not System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot=RunService.Heartbeat:Connect(System.triggerbot.loop)
        end
    else
        if System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot:Disconnect()
            System.__properties.__connections.__triggerbot=nil
        end
        System.__triggerbot.__is_parrying=false
        System.__triggerbot.__parries=0
        triggerbotCooldown = false
    end
end

System.manual_spam = {}
local manualSpamThread=nil
local macroSpamActive=false
local macroFrameFireCount=0; local macroFrameTime=0; local macroRealCPS=0; local macroAnimFix=true

function System.manual_spam.start()
    System.manual_spam.stop()
    System.__properties.__manual_spam_enabled=true; macroSpamActive=true
    local parry_keypress=System.parry.keypress; local parry_execute=System.parry.execute
    local play_animation=System.animation.play_grab_parry; local threshold=0.015
    manualSpamThread=coroutine.create(function()
        local last_spam=0
        while System.__properties.__manual_spam_enabled do
            local now=os.clock()
            if now-last_spam >= threshold then
                last_spam=now
                if getgenv().ManualSpamMode=="Keypress" then parry_keypress()
                else parry_execute(); if getgenv().ManualSpamAnimationFix then play_animation() end end
            end
            coroutine.yield()
        end
    end)
    task.spawn(function()
        while System.__properties.__manual_spam_enabled and manualSpamThread
              and coroutine.status(manualSpamThread) ~= "dead" do
            coroutine.resume(manualSpamThread); task.wait()
        end
    end)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled=false; macroSpamActive=false; manualSpamThread=nil
end

RunService.Heartbeat:Connect(function(dt)
    macroFrameTime=macroFrameTime+dt
    if macroFrameTime >= 0.1 then
        if macroSpamActive then macroRealCPS=math.floor(macroFrameFireCount/macroFrameTime) end
        macroFrameFireCount=0; macroFrameTime=0
    end
    if macroSpamActive and _capturedRemote then
        pcall(function() fireParryRemote(System.curve.get_cframe()); macroFrameFireCount=macroFrameFireCount+1 end)
        if macroAnimFix then System.animation.play_grab_parry() end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🔥 AUTO PARRY (FIXED - No Double Parry + Direction Check)
-- ═══════════════════════════════════════════════════════
System.autoparry = {}

-- 🎯 Table لتتبع الكرات المصدودة
local parriedBalls = {}

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry=RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or
           not LocalPlayer.Character.PrimaryPart then return end
        local balls=System.ball.get_all(); local one_ball=System.ball.get()
        local training_ball=nil
        if Workspace:FindFirstChild("TrainingBalls") then
            for _,Instance in pairs(Workspace.TrainingBalls:GetChildren()) do
                if Instance:GetAttribute("realBall") then training_ball=Instance; break end
            end
        end
        
        -- 🧹 تنظيف الكرات المختفية
        for ball in pairs(parriedBalls) do
            if not ball.Parent then parriedBalls[ball] = nil end
        end
        
        local char = LocalPlayer.Character
        local playerPos = char.PrimaryPart.Position
        
        for _,ball in pairs(balls) do
            if System.__triggerbot.__enabled then return end
            if getgenv().BallVelocityAbove800 then return end
            if not ball then continue end
            local zoomies=ball:FindFirstChild('zoomies'); if not zoomies then continue end
            
            -- 🎯 FIX: تجاهل الكرة إذا مصدودة
            if parriedBalls[ball] then continue end
            
            local ball_target=ball:GetAttribute('target')
            
            -- 🎯 FIX: لازم الكرة مستهدفة لك
            if ball_target ~= LocalPlayer.Name then continue end
            
            local velocity=zoomies.VectorVelocity
            local speed=velocity.Magnitude
            if speed < 5 then continue end
            
            -- 🎯 FIX: Direction Check - الكرة لازم جاية نحوي!
            local directionToPlayer = (playerPos - ball.Position).Unit
            local dot = velocity.Unit:Dot(directionToPlayer)
            if dot <= 0.3 then continue end
            
            local distance=(playerPos-ball.Position).Magnitude
            local ping=Stats.Network.ServerStatsItem['Data Ping']:GetValue()/10
            local ping_threshold=math.clamp(ping/10,5,17)
            local capped_speed_diff=math.min(math.max(speed-9.5,0),650)
            local speed_divisor=(2.4+capped_speed_diff*0.002)*System.__properties.__divisor_multiplier
            local parry_accuracy=ping_threshold+math.max(speed/speed_divisor,9.5)
            local curved=System.detection.is_curved()
            if ball:FindFirstChild('AeroDynamicSlashVFX') then
                ball.AeroDynamicSlashVFX:Destroy(); System.__properties.__tornado_time=tick()
            end
            if Runtime:FindFirstChild('Tornado') then
                if (tick()-System.__properties.__tornado_time) <
                   (Runtime.Tornado:GetAttribute('TornadoTime') or 1)+0.314159 then continue end
            end
            if one_ball and one_ball:GetAttribute('target')==LocalPlayer.Name and curved then continue end
            if ball:FindFirstChild('ComboCounter') then continue end
            if LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            
            if ball_target==LocalPlayer.Name and distance <= parry_accuracy then
                if getgenv().AutoAbility then
                    local AbilityCD=LocalPlayer.PlayerGui.Hotbar.Ability.UIGradient
                    if AbilityCD and AbilityCD.Offset.Y==0.5 then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Abilities") then
                            local abilities=LocalPlayer.Character.Abilities
                            if (abilities:FindFirstChild("Raging Deflection") and abilities["Raging Deflection"].Enabled) or
                               (abilities:FindFirstChild("Rapture") and abilities["Rapture"].Enabled) or
                               (abilities:FindFirstChild("Calming Deflection") and abilities["Calming Deflection"].Enabled) or
                               (abilities:FindFirstChild("Aerodynamic Slash") and abilities["Aerodynamic Slash"].Enabled) or
                               (abilities:FindFirstChild("Fracture") and abilities["Fracture"].Enabled) or
                               (abilities:FindFirstChild("Death Slash") and abilities["Death Slash"].Enabled) then
                                parriedBalls[ball] = true
                                ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                                task.wait(2.432)
                                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DeathSlashShootActivation"):FireServer(true)
                                continue
                            end
                        end
                    end
                end
            end
            
            if ball_target==LocalPlayer.Name and distance <= parry_accuracy then
                if getgenv().AutoParryMode=="Keypress" then System.parry.keypress()
                else System.parry.execute_action() end
                
                -- 🎯 FIX: قفل الكرة (يمنع الصد المزدوج)
                parriedBalls[ball] = true
                task.delay(0.8, function()
                    if parriedBalls[ball] then parriedBalls[ball] = nil end
                end)
                
                break
            end
        end
        
        if training_ball then
            local zoomies=training_ball:FindFirstChild('zoomies')
            if zoomies then
                if parriedBalls[training_ball] then return end
                
                local ball_target=training_ball:GetAttribute('target')
                if ball_target ~= LocalPlayer.Name then return end
                
                local velocity=zoomies.VectorVelocity
                local speed=velocity.Magnitude
                if speed < 5 then return end
                
                local directionToPlayer = (playerPos - training_ball.Position).Unit
                local dot = velocity.Unit:Dot(directionToPlayer)
                if dot <= 0.3 then return end
                
                local distance=LocalPlayer:DistanceFromCharacter(training_ball.Position)
                local ping=Stats.Network.ServerStatsItem['Data Ping']:GetValue()/10
                local ping_threshold=math.clamp(ping/10,5,17)
                local capped_speed_diff=math.min(math.max(speed-9.5,0),650)
                local speed_divisor=(2.4+capped_speed_diff*0.002)*System.__properties.__divisor_multiplier
                local parry_accuracy=ping_threshold+math.max(speed/speed_divisor,9.5)
                if ball_target==LocalPlayer.Name and distance <= parry_accuracy then
                    if getgenv().AutoParryMode=="Keypress" then System.parry.keypress()
                    else System.parry.execute_action() end
                    
                    parriedBalls[training_ball] = true
                    task.delay(0.8, function()
                        if parriedBalls[training_ball] then parriedBalls[training_ball] = nil end
                    end)
                end
            end
        end
    end)
end

function System.autoparry.stop()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
        System.__properties.__connections.__autoparry=nil
    end
    parriedBalls = {}
end

-- ========== HEADLESS & KORBLOX ==========
local Byte_Library = {}

function Byte_Library.Korblox(char)
    if not char then return end
    local leg = char:FindFirstChild("Right Leg")
    if not leg then return end
    if not leg:FindFirstChild("KorbloxMesh") then
        for _, v in leg:GetChildren() do
            if v:IsA("SpecialMesh") then v:Destroy() end
        end
        local m = Instance.new("SpecialMesh")
        m.Name = "KorbloxMesh"
        m.MeshId = "rbxassetid://902942096"
        m.TextureId = "rbxassetid://902843398"
        m.Offset = Vector3.new(0, 0.7, 0)
        m.Parent = leg
    end
end

function Byte_Library.Restore_Leg(char)
    if not char then return end
    local leg = char:FindFirstChild("Right Leg")
    if not leg then return end
    for _, v in leg:GetChildren() do
        if v:IsA("SpecialMesh") then v:Destroy() end
    end
end

function Byte_Library.Headless(char)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    head.Transparency = 1
    for _, child in head:GetChildren() do
        if child:IsA("Decal") or child.Name == "face" then
            child.Transparency = 1
        elseif child:IsA("SpecialMesh") or child:IsA("DataModelMesh") then
            if not child:GetAttribute("OriginalScale") then
                child:SetAttribute("OriginalScale", child.Scale)
                child.Scale = Vector3.new(0, 0, 0)
            end
        end
    end
end

function Byte_Library.Restore_Head(char)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    head.Transparency = 0
    for _, child in head:GetChildren() do
        if child:IsA("Decal") or child.Name == "face" then
            child.Transparency = 0
        elseif child:IsA("SpecialMesh") or child:IsA("DataModelMesh") then
            local orig = child:GetAttribute("OriginalScale")
            if orig then
                child.Scale = orig
                child:SetAttribute("OriginalScale", nil)
            end
        end
    end
end

local function ApplyHeadlessKorblox()
    local char = LocalPlayer.Character
    if not char then return end
    if System.__properties.__headless_enabled then Byte_Library.Headless(char) end
    if System.__properties.__korblox_enabled then Byte_Library.Korblox(char) end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    ApplyHeadlessKorblox()
end)

-- ========== MOBILE BUTTON ==========
local mobile_ui_button = nil

local function create_mobile_ui_button()
    if mobile_ui_button then
        mobile_ui_button.gui:Destroy()
    end
    local gui = Instance.new('ScreenGui')
    gui.Name = 'EagleHubMobileUIButton'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 9999
    
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(0.95, -25, 0.05, 0)
    button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    button.BackgroundTransparency = 0.3
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Draggable = true
    button.AutoButtonColor = true
    button.ZIndex = 10000
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button
    
    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = button
    
    local text = Instance.new('TextLabel')
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = "X"
    text.Font = Enum.Font.GothamBold
    text.TextSize = 24
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.ZIndex = 10001
    text.Parent = button
    
    button.MouseButton1Click:Connect(function()
        Window:Minimize(not Window.Minimized)
    end)
    
    button.Parent = gui
    gui.Parent = CoreGui
    
    mobile_ui_button = {gui = gui, button = button}
    return mobile_ui_button
end

local function create_mobile_button(name, position_y, color, toggleName)
    local gui = Instance.new('ScreenGui')
    gui.Name = 'EagleHub_' .. name .. '_Mobile'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(0, 105, 0, 48)
    button.Position = UDim2.new(0.5, -52, position_y, 0)
    button.BackgroundTransparency = 1
    button.AnchorPoint = Vector2.new(0.5, 0)
    button.Draggable = true
    button.AutoButtonColor = false
    button.ZIndex = 2
    local bg = Instance.new('Frame')
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.Parent = button
    Instance.new('UICorner', bg).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new('UIStroke', bg)
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    local text = Instance.new('TextLabel')
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = name
    text.Font = Enum.Font.GothamBold
    text.TextSize = 16
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.ZIndex = 3
    text.Parent = button
    button.Parent = gui
    gui.Parent = CoreGui
    return {gui = gui, button = button, text = text, bg = bg}
end

local function destroy_mobile_gui(gui_data)
    if gui_data and gui_data.gui then gui_data.gui:Destroy() end
end

-- ========== SKIN CHANGER ==========
local swordInstancesInstance = ReplicatedStorage:WaitForChild("Shared",9e9):WaitForChild("ReplicatedInstances",9e9):WaitForChild("Swords",9e9)

local SKIN_LAST_EQUIPPED_CONFIG_KEY = "Skin.LastEquippedSword"
local AUTO_CONFIG_FILE = "EagleHubX/auto_config.json"

local function readLeviHubAutoConfig()
    local data = {}
    pcall(function()
        if isfile and isfile(AUTO_CONFIG_FILE) then
            local decoded = HttpService:JSONDecode(readfile(AUTO_CONFIG_FILE))
            if type(decoded) == "table" then data = decoded end
        end
    end)
    return data
end

local function writeLeviHubAutoConfig(data)
    pcall(function()
        if isfolder and makefolder and not isfolder("LeviHubX") then makefolder("LeviHubX") end
        if writefile then writefile(AUTO_CONFIG_FILE, HttpService:JSONEncode(data or {})) end
    end)
end

local function loadLastEquippedSword()
    local data = readLeviHubAutoConfig()
    local saved = data[SKIN_LAST_EQUIPPED_CONFIG_KEY]
    return type(saved) == "string" and saved or ""
end

getgenv().saveLastEquippedSword = function(swordName)
    if type(swordName) ~= "string" or swordName == "" then return end
    local data = readLeviHubAutoConfig()
    data[SKIN_LAST_EQUIPPED_CONFIG_KEY] = swordName
    writeLeviHubAutoConfig(data)
end

do
    local savedLastSword = loadLastEquippedSword()
    getgenv().skinChanger = getgenv().skinChanger or savedLastSword ~= ""
    getgenv().swordModel = type(getgenv().swordModel) == "string" and getgenv().swordModel ~= "" and getgenv().swordModel or savedLastSword
    getgenv().swordAnimations = type(getgenv().swordAnimations) == "string" and getgenv().swordAnimations ~= "" and getgenv().swordAnimations or savedLastSword
    getgenv().swordFX = type(getgenv().swordFX) == "string" and getgenv().swordFX ~= "" and getgenv().swordFX or savedLastSword
end

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local swordInstancesInstance = rs:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
    local swordInstances = require(swordInstancesInstance)
    local swordsController
    task.spawn(function()
        while task.wait(0.25) and not swordsController do
            local ok, conns = pcall(getconnections, rs.Remotes.FireSwordInfo.OnClientEvent)
            if ok and conns then
                for _, v in ipairs(conns) do
                    if v.Function and islclosure and islclosure(v.Function) then
                        local ok2, up = pcall(getupvalues, v.Function)
                        if ok2 and #up == 1 and type(up[1]) == "table" then
                            swordsController = up[1]
                            break
                        end
                    end
                end
            end
        end
    end)
    local function getSlashName(swordName)
        local ok, sln = pcall(function() return swordInstances:GetSword(swordName) end)
        return (ok and sln and sln.SlashName) or "SlashEffect"
    end
    local function refreshSlashName()
        local fxName = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
        if fxName ~= "" then getgenv().slashName = getSlashName(fxName)
        else getgenv().slashName = "SlashEffect" end
    end
    refreshSlashName()
    local func
