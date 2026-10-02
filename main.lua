repeat task.wait() until game:IsLoaded()

local function cleanup()
    for _,n in pairs({"UwuHubGui","SpamCenter","UwuMiniGui","EagleSpamGui"}) do
        local o=game.CoreGui:FindFirstChild(n); if o then o:Destroy() end
    end
end
cleanup()

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local StatsService      = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")

local remote,f_raw=nil,nil
local c={nil,nil,nil,nil,nil,nil,nil}
local AutoParry=false; local AnimFix=false
local AutoJump=false; local hasJumped=false
local ManualSpam=false; local spamActive=false
local lastSpamTime=0; local spamInterval=1/15
local remoteHooked=false; local parried_balls={}; local billboardLabels={}
local detections={infinity=false,deathslash=false,timehole=false,slashesoffury=false,phantom=false}
local infinity_active=false; local deathslash_active=false
local timehole_active=false; local slashesoffury_active=false
local slashesoffury_count=0; local maxParryCount=36; local parryDelay=0.05
local CurrentCurveMethod="camera"
local AntiCurve=false; local ParryDist=8
local HideKey=Enum.KeyCode.RightShift
local LowGraphics=false
local ShowBallStats=false; local peakVel=0
getgenv().AbilityESP=false

local function isInGame() return workspace:FindFirstChild("Alive")~=nil end
local Alive=workspace:FindFirstChild("Alive")
local Runtime=workspace:FindFirstChild("Runtime")
RunService.Heartbeat:Connect(function()
    if not Alive or not Alive.Parent then Alive=workspace:FindFirstChild("Alive") end
    if not Runtime or not Runtime.Parent then Runtime=workspace:FindFirstChild("Runtime") end
end)

-- CURVE
local function getCurveCFrame()
    local camera=workspace.CurrentCamera
    local char=LocalPlayer.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then return camera.CFrame end
    local closestDot=-math.huge; local targetPos=nil
    if Alive then
        for _,entity in pairs(Alive:GetChildren()) do
            if entity~=char and entity:FindFirstChild("HumanoidRootPart") then
                local dir=(entity.HumanoidRootPart.Position-camera.CFrame.Position).Unit
                local dot=camera.CFrame.LookVector:Dot(dir)
                if dot>closestDot then closestDot=dot; targetPos=entity.HumanoidRootPart.Position end
            end
        end
    end
    targetPos=targetPos or (root.Position+camera.CFrame.LookVector*1000)
    local toTarget=(targetPos-root.Position).Unit
    if CurrentCurveMethod=="dot" then return CFrame.lookAt(root.Position,targetPos+Vector3.new(0,1.75,0))
    elseif CurrentCurveMethod=="backwards" then return CFrame.new(root.Position,root.Position+(-toTarget)*1000)
    elseif CurrentCurveMethod=="slow" then return CFrame.new(root.Position,root.Position+Vector3.new(0,-350,0))
    elseif CurrentCurveMethod=="random" then
        local direction=(targetPos-root.Position).Unit; local randomOffset; local attempts=0
        repeat randomOffset=Vector3.new(math.random(-4000,4000),math.random(-4000,4000),math.random(-4000,4000))
        local curveDir=(targetPos+randomOffset-root.Position).Unit; local dot=direction:Dot(curveDir); attempts+=1
        until dot<0.95 or attempts>10; return CFrame.new(root.Position,targetPos+randomOffset)
    elseif CurrentCurveMethod=="accelerated" then return CFrame.new(root.Position,targetPos+Vector3.new(0,5,0))
    elseif CurrentCurveMethod=="high" then return CFrame.new(root.Position,targetPos+Vector3.new(0,9e18,0))
    else return camera.CFrame end
end

-- ANIMATION
local SwordAPI=ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local lastplayedd=0; local bypasscd=false; local AnimationDelay=1; local AnimationCache={}
local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid() local char=GetCharacter(); return char and char:FindFirstChildOfClass("Humanoid") end
local function StopAnimation(track) track:Stop(track:GetAttribute("StopFadeTime") or 0.1) end
local function PlayGrabAnimation(track) track:Play(track:GetAttribute("PlayFadeTime") or 0,track:GetAttribute("PlayWeight") or 1,track:GetAttribute("PlaySpeed") or 1) end
local function GetParryAnimation()
    local char=GetCharacter(); if not char then return nil end
    local cs=char:GetAttribute("CurrentlyEquippedSword"); if not cs then return SwordAPI.Collection.Default:FindFirstChild("GrabParry") end
    if AnimationCache[cs] then return AnimationCache[cs] end
    local ok,sd=pcall(function() return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(cs) end)
    if not ok or type(sd)~="table" then AnimationCache[cs]=SwordAPI.Collection.Default:FindFirstChild("GrabParry"); return AnimationCache[cs] end
    for _,obj in pairs(SwordAPI.Collection:GetChildren()) do if obj.Name==sd.AnimationType then local a=obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab"); if a then AnimationCache[cs]=a; return a end end end
    AnimationCache[cs]=SwordAPI.Collection.Default:FindFirstChild("GrabParry"); return AnimationCache[cs]
end
local function PlayParry_Animation()
    local hum=GetHumanoid(); if not hum then return end; local anim=GetParryAnimation(); if not anim then return end
    for _,track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name=="GrabParry" or track.Name=="Grab" then track.TimePosition=0; StopAnimation(track)
        elseif track.Name=="SuccessParry" or track.Name=="Success" then StopAnimation(track) end
    end
    local g=hum.Animator:LoadAnimation(anim); PlayGrabAnimation(g)
end
local function SpamParry_Animation()
    if (os.clock()-lastplayedd)>=(AnimationDelay-0.8) or bypasscd then lastplayedd=os.clock(); bypasscd=false; PlayParry_Animation() end
end
pcall(function()
    ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        bypasscd=true; local hum=GetHumanoid()
        if hum then for _,t in pairs(hum.Animator:GetPlayingAnimationTracks()) do if t.Name=="GrabParry" or t.Name=="Grab" then StopAnimation(t) end end end
    end)
end)

-- HEADLESS & KORBLOX
local Byte_Library={}
function Byte_Library.Korblox(char)
    if not char then return end; local leg=char:FindFirstChild("Right Leg"); if not leg then return end
    if not leg:FindFirstChild("KorbloxMesh") then
        for _,v in leg:GetChildren() do if v:IsA("SpecialMesh") then v:Destroy() end end
        local m=Instance.new("SpecialMesh"); m.Name="KorbloxMesh"; m.MeshId="rbxassetid://902942096"; m.TextureId="rbxassetid://902843398"; m.Offset=Vector3.new(0,0.7,0); m.Parent=leg
    end
end
function Byte_Library.Restore_Leg(char)
    if not char then return end; local leg=char:FindFirstChild("Right Leg"); if not leg then return end
    for _,v in leg:GetChildren() do if v:IsA("SpecialMesh") then v:Destroy() end end
end
function Byte_Library.Headless(char)
    if not char then return end; local head=char:FindFirstChild("Head"); if not head then return end
    head.Transparency=1
    for _,child in head:GetChildren() do
        if child:IsA("Decal") or child.Name=="face" then child.Transparency=1
        elseif child:IsA("SpecialMesh") or child:IsA("DataModelMesh") then
            if not child:GetAttribute("OriginalScale") then child:SetAttribute("OriginalScale",child.Scale); child.Scale=Vector3.new(0,0,0) end
        end
    end
end
function Byte_Library.Restore_Head(char)
    if not char then return end; local head=char:FindFirstChild("Head"); if not head then return end
    head.Transparency=0
    for _,child in head:GetChildren() do
        if child:IsA("Decal") or child.Name=="face" then child.Transparency=0
        elseif child:IsA("SpecialMesh") or child:IsA("DataModelMesh") then
            local orig=child:GetAttribute("OriginalScale"); if orig then child.Scale=orig; child:SetAttribute("OriginalScale",nil) end
        end
    end
end

local headlessKorblox_conn=nil
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if getgenv().HeadlessKorbloxEnabled then Byte_Library.Headless(char); Byte_Library.Korblox(char) end
    if LowGraphics then
        pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    end
    hasJumped=false
end)

-- AVATAR CHANGER
local __av_flags={}; local __av_persistent={}
local function __av_match(a,b)
    if not a or not b then return false end
    for _,k in ipairs({"Shirt","Pants","ShirtGraphic","Head","Face","BodyTypeScale","HeightScale","WidthScale"}) do
        local av,bv=a[k],b[k]; if av~=nil and bv~=nil and tostring(av)~=tostring(bv) then return false end
    end; return true
end
local function __av_force_apply(hum,desc)
    if not hum or not desc then return false end
    for _=1,20 do pcall(function() hum:ApplyDescriptionClientServer(desc) end); task.wait(0.05); local ok,ap=pcall(function() return hum:GetAppliedDescription() end); if ok and ap and __av_match(ap,desc) then return true end end
    pcall(function() hum.Description=Instance.new("HumanoidDescription") end); task.wait(0.1)
    for _=1,40 do pcall(function() hum:ApplyDescriptionClientServer(desc) end); task.wait(0.05); local ok,ap=pcall(function() return hum:GetAppliedDescription() end); if ok and ap and __av_match(ap,desc) then return true end end
    return false
end
local function __av_start_persistent(char,desc)
    if not char or not desc then return end; local key=char; if __av_persistent[key] then return end
    local stop=false; __av_persistent[key]={stop=function() stop=true end}
    task.spawn(function()
        local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5); if not hum then __av_persistent[key]=nil; return end
        while not stop and char.Parent do
            pcall(function() __av_force_apply(hum,desc) end)
            local ok,ap=pcall(function() return hum:GetAppliedDescription() end)
            if ok and ap and __av_match(ap,desc) then for _=1,40 do if stop or not char.Parent then break end; task.wait(0.25) end
            else for _=1,20 do if stop or not char.Parent then break end; pcall(function() hum:ApplyDescriptionClientServer(desc) end); task.wait(0.1) end end
            if not hum.Parent then hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5) end
        end; __av_persistent[key]=nil
    end)
end
local function __av_stop_all() for k,v in pairs(__av_persistent) do if v and type(v.stop)=="function" then pcall(v.stop) end; __av_persistent[k]=nil end end
local function __av_set(name,char)
    if not name or name=="" then return end; local hum=char and char:WaitForChild("Humanoid",5); if not hum then return end
    local ok,desc=pcall(function() local id=Players:GetUserIdFromNameAsync(name); return Players:GetHumanoidDescriptionFromUserId(id) end)
    if not ok or not desc then return end
    pcall(function() LocalPlayer:ClearCharacterAppearance(); hum.Description=Instance.new("HumanoidDescription") end)
    task.wait(0.05); pcall(function() __av_force_apply(hum,desc) end); __av_start_persistent(char,desc)
end

-- ABILITY ESP
local function createBillboardGui(p)
    task.spawn(function()
        local character=p.Character; while not character or not character.Parent do task.wait(); character=p.Character end
        local head=character:WaitForChild("Head",10); if not head then return end
        local bg=Instance.new("BillboardGui"); bg.Name="AbilityESP_Gui"; bg.Adornee=head
        bg.Size=UDim2.new(0,220,0,60); bg.StudsOffset=Vector3.new(0,3.5,0); bg.AlwaysOnTop=true; bg.Parent=head
        local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,0,1,0)
        tl.TextColor3=Color3.new(1,1,1); tl.TextSize=14; tl.TextStrokeTransparency=0
        tl.Font=Enum.Font.GothamBold; tl.BackgroundTransparency=1; tl.Parent=bg; tl.Visible=false; billboardLabels[p]=tl
        local hum=character:FindFirstChild("Humanoid"); if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
        local conn; conn=RunService.Heartbeat:Connect(function()
            if not(character and character.Parent) then conn:Disconnect(); pcall(function() bg:Destroy() end); billboardLabels[p]=nil; return end
            tl.Visible=getgenv().AbilityESP
            if getgenv().AbilityESP then local ab=p:GetAttribute("EquippedAbility"); tl.Text=ab and(p.DisplayName.." ["..ab.."]") or p.DisplayName end
        end)
    end)
end
for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then p.CharacterAdded:Connect(function() createBillboardGui(p) end); if p.Character then createBillboardGui(p) end end end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() createBillboardGui(p) end) end)

-- BAC BYPASS
local function getExecutorGlobal(name)
    if getfenv(0) and getfenv(0)[name] then return getfenv(0)[name] end
    if getgenv and getgenv()[name] then return getgenv()[name] end
    if getrenv and getrenv()[name] then return getrenv()[name] end
    if _G and _G[name] then return _G[name] end
    if shared and shared[name] then return shared[name] end
    local val=nil
    for _,fn in ipairs({
        function() if gethui and gethui()[name] then return gethui()[name] end end,
        function() if getsenv and getsenv()[name] then return getsenv()[name] end end,
        function() if getmenv and getmenv()[name] then return getmenv()[name] end end,
    }) do pcall(function() val=fn() end); if val then return val end end
    pcall(function() if getgc then for _,v in pairs(getgc(true)) do if type(v)=="table" and v[name] then val=v[name]; break end end end end)
    pcall(function() for i=1,30 do local env=getfenv(i); if env and env[name] then val=env[name]; break end end end)
    return val
end

local hookfn=hookfunction or getExecutorGlobal("hookfunction") or getExecutorGlobal("hookfunc")
local newcc=newcclosure or getExecutorGlobal("newcclosure") or function(f) return f end
local function isValidRemoteArgs(args) return #args>=4 and typeof(args[4])=="CFrame" end
getgenv()._hookUsedStr="None"

if hookfn and newcc then
    pcall(function()
        local dE=Instance.new("RemoteEvent"); local dF=Instance.new("RemoteFunction")
        local origFS
        origFS=hookfn(dE.FireServer,newcc(function(self,...)
            local args={...}
            if isValidRemoteArgs(args) then
                if not remoteHooked then remoteHooked=true; remote=self; f_raw=origFS; for i=1,7 do c[i]=args[i] end
                else for i=1,7 do c[i]=args[i] end end
                local curveCF=getCurveCFrame(); if curveCF then args[4]=curveCF end
                return origFS(self,unpack(args))
            end
            return origFS(self,...)
        end))
        local origIS
        origIS=hookfn(dF.InvokeServer,newcc(function(self,...)
            local args={...}
            if isValidRemoteArgs(args) then
                if not remoteHooked then remoteHooked=true; remote=self; f_raw=origIS; for i=1,7 do c[i]=args[i] end
                else for i=1,7 do c[i]=args[i] end end
                local curveCF=getCurveCFrame(); if curveCF then args[4]=curveCF end
                return origIS(self,unpack(args))
            end
            return origIS(self,...)
        end))
        getgenv()._hookUsedStr="HookFunction (Deep Bypass)"
    end)
end
if getgenv()._hookUsedStr=="None" then
    local mt=getrawmetatable(game); local old=mt.__index
    setreadonly(mt,false)
    mt.__index=newcc(function(self,key)
        if key=="FireServer" or key=="InvokeServer" then
            return function(instance,...)
                local args={...}
                if #args>=4 then remoteHooked=true; remote=instance; f_raw=old(instance,"FireServer"); for i=1,7 do c[i]=args[i] end end
                return old(self,key)(instance,...)
            end
        end
        return old(self,key)
    end)
    setreadonly(mt,true)
    getgenv()._hookUsedStr="__index Fallback"
end

-- FIRE PARRY
local cachedEvents={}; local lastEventCache=0
local function fireParry()
    if not(remote and f_raw) then return end
    local cam=workspace.CurrentCamera; local char=LocalPlayer.Character; if not char then return end
    local now=tick()
    if now-lastEventCache>0.1 then
        cachedEvents={}
        if Alive then for _,v in ipairs(Alive:GetChildren()) do if v~=char and v.PrimaryPart then local sp,vis=cam:WorldToScreenPoint(v.PrimaryPart.Position); if vis then cachedEvents[tostring(v)]=sp end end end end
        lastEventCache=now
    end
    local vp=cam.ViewportSize; local curveCF=getCurveCFrame()
    c[3]=curveCF.LookVector; c[4]=curveCF; c[5]=cachedEvents; c[6]={vp.X/2,vp.Y/2}
    pcall(function() f_raw(remote,unpack(c)) end)
    if AnimFix then task.spawn(SpamParry_Animation) end
end

-- DETECTION LISTENERS
pcall(function() ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(_,d) deathslash_active=d or false end) end)
pcall(function() ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(_,b) infinity_active=b or false end) end)
pcall(function()
    local net=ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
    net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...) local p=(...); if p==LocalPlayer or(p and p.Name==LocalPlayer.Name) then timehole_active=true end end)
    net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function() timehole_active=false end)
    net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...) local p=(...); if p==LocalPlayer or(p and p.Name==LocalPlayer.Name) then slashesoffury_active=true; slashesoffury_count=0 end end)
    net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function() slashesoffury_active=false; slashesoffury_count=0 end)
    net["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function() slashesoffury_count+=1 end)
    net["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
        task.spawn(function()
            while slashesoffury_active and slashesoffury_count<maxParryCount do
                if detections.slashesoffury then fireParry(); task.wait(parryDelay) else break end
            end
        end)
    end)
end)
pcall(function()
    if Runtime then Runtime.ChildAdded:Connect(function(obj)
        if not detections.phantom then return end
        if obj.Name~="maxTransmission" and obj.Name~="transmissionpart" then return end
        local weld=obj:FindFirstChildWhichIsA("WeldConstraint"); if not weld then return end
        local char=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        if char and weld.Part1==char.HumanoidRootPart then
            local bc=workspace:FindFirstChild("Balls"); local ball=bc and bc:GetChildren()[1]; weld:Destroy()
            if ball then
                local conn; conn=RunService.RenderStepped:Connect(function()
                    local h=ball:GetAttribute("highlighted")
                    if h==true then ReplicatedStorage.Remotes.AbilityButtonPress:Fire() elseif h==false then conn:Disconnect() end
                end); task.delay(3,function() if conn and conn.Connected then conn:Disconnect() end end)
            end
        end
    end) end
end)

-- AUTO JUMP â€” dأ¼zة™ldilmiإں
UserInputService.JumpRequest:Connect(function()
    if not AutoJump then return end
    local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- LOW GRAPHICS
local origQuality=nil
local function setLowGraphics(v)
    LowGraphics=v
    if v then
        pcall(function() origQuality=settings().Rendering.QualityLevel; settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
        pcall(function() game:GetService("Lighting").GlobalShadows=false; game:GetService("Lighting").FogEnd=9e9 end)
    else
        pcall(function() if origQuality then settings().Rendering.QualityLevel=origQuality end end)
        pcall(function() game:GetService("Lighting").GlobalShadows=true end)
    end
end

-- SKIN CHANGER
task.spawn(function()
    pcall(function()
        local oi=getthreadidentity and getthreadidentity() or 2; if setthreadidentity then setthreadidentity(2) end
        local sim=ReplicatedStorage:WaitForChild("Shared",9e9):WaitForChild("ReplicatedInstances",9e9):WaitForChild("Swords",9e9); local si=require(sim)
        if setthreadidentity then setthreadidentity(oi) end
        local sc; while task.wait() and not sc do for _,v in pairs(getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent)) do if v.Function and islclosure(v.Function) then local up=getupvalues(v.Function); if #up==1 and type(up[1])=="table" then sc=up[1]; break end end end end
        local function gsn(sn) local i2=getthreadidentity and getthreadidentity() or 2; if setthreadidentity then setthreadidentity(2) end; local sln; pcall(function() sln=si:GetSword(sn) end); if setthreadidentity then setthreadidentity(i2) end; return (sln and sln.SlashName) or "SlashEffect" end
        local function setSword()
            if not getgenv().skinChangerEnabled then return end; local char=LocalPlayer.Character; local aF=workspace:FindFirstChild("Alive")
            if not char or not aF or char.Parent~=aF then return end; if not char:FindFirstChild("Humanoid") or char.Humanoid.Health<=0 then return end
            local i2=getthreadidentity and getthreadidentity() or 2; if setthreadidentity then setthreadidentity(2) end
            pcall(function() setupvalue(rawget(si,"EquipSwordTo"),3,false); if getgenv().changeSwordModel and getgenv().swordModel and getgenv().swordModel~="" then si:EquipSwordTo(char,getgenv().swordModel) end; if getgenv().changeSwordAnimation and getgenv().swordAnimations and getgenv().swordAnimations~="" then sc:SetSword(getgenv().swordAnimations) end end)
            if setthreadidentity then setthreadidentity(i2) end
        end
        local ppf; while not ppf do for _,v in pairs(getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent)) do if v.Function and getinfo(v.Function).name=="parrySuccessAll" then ppf=v.Function; v:Disable(); break end end; if not ppf then task.wait() end end
        getgenv().slashName=gsn(getgenv().swordFX or "")
        ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...) setthreadidentity(2); local args={...}; if tostring(args[4])==LocalPlayer.Name then if getgenv().skinChangerEnabled and getgenv().changeSwordFX and getgenv().swordFX and getgenv().swordFX~="" then args[1]=getgenv().slashName; args[3]=getgenv().swordFX end end; return ppf(unpack(args)) end)
        getgenv().updateSword=function() if getgenv().changeSwordFX and getgenv().swordFX and getgenv().swordFX~="" then getgenv().slashName=gsn(getgenv().swordFX) end; setSword() end
        while task.wait(0.1) do
            if getgenv().skinChangerEnabled and getgenv().changeSwordModel and getgenv().swordModel and getgenv().swordModel~="" then
                local char=LocalPlayer.Character; local aF=workspace:FindFirstChild("Alive")
                if char and aF and char.Parent==aF and char:FindFirstChild("Humanoid") and char.Humanoid.Health>0 then
                    local cur=LocalPlayer:GetAttribute("CurrentlyEquippedSword")
                    if cur and cur~=getgenv().swordModel and cur~=char:GetAttribute("LastOverwrittenSword") then char:SetAttribute("LastOverwrittenSword",cur); setSword() elseif not char:FindFirstChild(getgenv().swordModel) then setSword() end
                    for _,v in pairs(char:GetChildren()) do if v:IsA("Model") and v.Name~=getgenv().swordModel and v:FindFirstChild("Handle") then v:Destroy() end end
                end
            end
        end
    end)
end)

-- EAGLE MACRO SPAM (sة™nin gist kodun)
local eagleSpamLoaded=false
local function loadEagleSpam()
    if eagleSpamLoaded then return end
    eagleSpamLoaded=true
    pcall(function()
        loadstring(game:HttpGet("https://gist.githubusercontent.com/fuadq294-max/2fc34c928644d74b99c5c382397e927b/raw/6573feb3c0bdb2bc148bd993005d68bcda811f0e/Lua"))() -- die
    end)
end

-- OBSIDIAN UI
local repo="https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library=loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager=loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager=loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()
local Options=Library.Options

local Window=Library:CreateWindow({
    Title = "EAGLE Hub X Paid",
    Footer = "Blade Ball",
    Icon = 135334786148169,
    NotifySide = "Right",
    ShowCustomCursor = true,
    AutoShow = true,
})

local function N(t,m) Library:Notify({Title=t,Description=m,Time=3}) end

local Tabs={
    Combat   = Window:AddTab("Combat",   "shield"),
    Detect   = Window:AddTab("Detection","shield"),
    Visuals  = Window:AddTab("Visuals",  "eye"),
    Player   = Window:AddTab("Player",   "user"),
    Skin     = Window:AddTab("Skin Changer",     "zap"),
    Spam     = Window:AddTab("Spam",     "zap"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- COMBAT
local CL=Tabs.Combat:AddLeftGroupbox("Auto Parry")
local CR=Tabs.Combat:AddRightGroupbox("Spam & Misc")

CL:AddToggle("AutoParry",{Text="Auto Parry",Default=false,
    Callback=function(v) AutoParry=v; table.clear(parried_balls); N("Auto Parry",v and "ON" or "OFF") end})
CL:AddToggle("AnimFix",{Text="Animation Fix",Default=false,Callback=function(v) AnimFix=v end})
CL:AddToggle("AntiCurve",{Text="Anti Curve",Default=false,
    Callback=function(v) AntiCurve=v; N("Anti Curve",v and "ON" or "OFF") end})
CL:AddSlider("ParryDist",{Text="Parry Distance",Default=8,Min=4,Max=30,Rounding=1,
    Callback=function(v) ParryDist=v end})
CL:AddDivider()
CL:AddDropdown("CurveMethod",{
    Values={"camera","dot","backwards","slow","random","accelerated","high"},
    Default="camera",Text="Curve Method",
    Callback=function(v) CurrentCurveMethod=v end})

CR:AddToggle("ManualSpam",{Text="Manual Spam",Default=false,Tooltip="E key to toggle",
    Callback=function(v)
        ManualSpam=v
        if not v then spamActive=false end
        N("Manual Spam",v and "ON" or "OFF")
    end})
CR:AddSlider("SpamCPS",{Text="Spam CPS",Default=15,Min=1,Max=30,Rounding=0,
    Callback=function(v) spamInterval=1/v end})
CR:AddToggle("AutoJump",{Text="Auto Jump",Default=false,
    Callback=function(v) AutoJump=v; N("Auto Jump",v and "ON" or "OFF") end})
CR:AddButton({Text="Remote Status",Func=function()
    N("Remote",remoteHooked and "Hooked â€” "..(getgenv()._hookUsedStr or "") or "Not hooked")
end})

-- DETECTION
local DL=Tabs.Detect:AddLeftGroupbox("Detections")
local DR=Tabs.Detect:AddRightGroupbox("Slashes of Fury")

DL:AddToggle("DetInfinity",{Text="Infinity",Default=false,Callback=function(v) detections.infinity=v; N("Infinity",v and "ON" or "OFF") end})
DL:AddToggle("DetDeathSlash",{Text="Death Slash",Default=false,Callback=function(v) detections.deathslash=v; N("Death Slash",v and "ON" or "OFF") end})
DL:AddToggle("DetTimeHole",{Text="Time Hole",Default=false,Callback=function(v) detections.timehole=v; N("Time Hole",v and "ON" or "OFF") end})
DL:AddToggle("DetPhantom",{Text="Anti-Phantom",Default=false,Callback=function(v) detections.phantom=v; N("Anti-Phantom",v and "ON" or "OFF") end})

DR:AddToggle("DetSoF",{Text="Slashes of Fury",Default=false,Callback=function(v) detections.slashesoffury=v; N("SoF",v and "ON" or "OFF") end})
DR:AddSlider("SofDelay",{Text="Parry Delay (ms)",Default=5,Min=5,Max=25,Rounding=0,Callback=function(v) parryDelay=v/100 end})
DR:AddSlider("SofMax",{Text="Max Parry Count",Default=36,Min=1,Max=36,Rounding=0,Callback=function(v) maxParryCount=v end})

-- VISUALS
local VL=Tabs.Visuals:AddLeftGroupbox("Display")
local VR=Tabs.Visuals:AddRightGroupbox("Effects")

VL:AddToggle("BallStats",{Text="Ball Stats",Default=false,
    Callback=function(v) ShowBallStats=v; if not v then peakVel=0 end; N("Ball Stats",v and "ON" or "OFF") end})
VL:AddToggle("AbilityESP",{Text="Ability ESP",Default=false,
    Callback=function(v)
        getgenv().AbilityESP=v
        for _,l in pairs(billboardLabels) do if l then l.Visible=v end end
        N("Ability ESP",v and "ON" or "OFF")
    end})
VL:AddToggle("HeadlessKorblox",{Text="Headless & Korblox",Default=false,
    Callback=function(v)
        getgenv().HeadlessKorbloxEnabled=v
        local char=LocalPlayer.Character
        if char then if v then Byte_Library.Headless(char); Byte_Library.Korblox(char) else Byte_Library.Restore_Head(char); Byte_Library.Restore_Leg(char) end end
        if v then
            if not headlessKorblox_conn then
                headlessKorblox_conn=LocalPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.5); if getgenv().HeadlessKorbloxEnabled then Byte_Library.Headless(char); Byte_Library.Korblox(char) end
                end)
            end
        else if headlessKorblox_conn then headlessKorblox_conn:Disconnect(); headlessKorblox_conn=nil end end
        N("Headless & Korblox",v and "ON" or "OFF")
    end})
VL:AddToggle("LowGraphics",{Text="Low Graphics",Default=false,
    Callback=function(v) setLowGraphics(v); N("Low Graphics",v and "ON" or "OFF") end})

VR:AddToggle("FOVEnabled",{Text="FOV Changer",Default=false,
    Callback=function(v)
        getgenv().CameraEnabled=v; local Cam=workspace.CurrentCamera
        if v then
            getgenv().CameraFOV=getgenv().CameraFOV or 70; Cam.FieldOfView=getgenv().CameraFOV
            if not getgenv().FOVLoop then
                getgenv().FOVLoop=RunService.RenderStepped:Connect(function()
                    if getgenv().CameraEnabled then Cam.FieldOfView=getgenv().CameraFOV end
                end)
            end
        else
            Cam.FieldOfView=70
            if getgenv().FOVLoop then getgenv().FOVLoop:Disconnect(); getgenv().FOVLoop=nil end
        end
    end})
VR:AddSlider("CameraFOV",{Text="FOV",Default=70,Min=50,Max=120,Rounding=1,
    Callback=function(v) getgenv().CameraFOV=v; if getgenv().CameraEnabled then workspace.CurrentCamera.FieldOfView=v end end})

-- PLAYER
local PL=Tabs.Player:AddLeftGroupbox("Movement")
local PR=Tabs.Player:AddRightGroupbox("Avatar")

PL:AddToggle("FlyToggle",{Text="Fly (W/A/S/D+Space/Shift)",Default=false,
    Callback=function(v)
        getgenv().FlyEnabled=v
        if v then
            local char=LocalPlayer.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); if hum then hum.PlatformStand=true end
            if getgenv().FlyBV then getgenv().FlyBV:Destroy() end
            getgenv().FlyBV=Instance.new("BodyVelocity"); getgenv().FlyBV.Velocity=Vector3.zero; getgenv().FlyBV.MaxForce=Vector3.new(1e5,1e5,1e5); getgenv().FlyBV.Parent=hrp
            if getgenv().FlyConn then getgenv().FlyConn:Disconnect() end
            getgenv().FlyConn=RunService.RenderStepped:Connect(function()
                if not getgenv().FlyEnabled then return end
                local c2=LocalPlayer.Character; local r2=c2 and c2:FindFirstChild("HumanoidRootPart"); if not r2 then return end
                local cam=workspace.CurrentCamera; local md=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then md+=cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then md-=cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then md-=cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then md+=cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md+=Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md-=Vector3.new(0,1,0) end
                if getgenv().FlyBV and getgenv().FlyBV.Parent then getgenv().FlyBV.Velocity=md.Magnitude>0 and md.Unit*(getgenv().FlySpeed or 50) or Vector3.zero end
            end)
        else
            if getgenv().FlyConn then getgenv().FlyConn:Disconnect(); getgenv().FlyConn=nil end
            if getgenv().FlyBV then getgenv().FlyBV:Destroy(); getgenv().FlyBV=nil end
            local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then hum.PlatformStand=false end
        end
        N("Fly",v and "ON" or "OFF")
    end})
PL:AddSlider("FlySpeed",{Text="Fly Speed",Default=50,Min=10,Max=300,Rounding=0,
    Callback=function(v) getgenv().FlySpeed=v end})
PL:AddDivider()
PL:AddToggle("SpeedHack",{Text="Speed Hack",Default=false,
    Callback=function(v)
        getgenv().SpeedEnabled=v
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=v and (getgenv().SpeedVal or 30) or 16 end
        N("Speed Hack",v and "ON" or "OFF")
    end})
PL:AddSlider("SpeedVal",{Text="Walk Speed",Default=30,Min=16,Max=150,Rounding=0,
    Callback=function(v)
        getgenv().SpeedVal=v
        if getgenv().SpeedEnabled then local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed=v end end
    end})
PL:AddDivider()
PL:AddToggle("HighJump",{Text="High Jump",Default=false,
    Callback=function(v)
        getgenv().HJEnabled=v
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.JumpHeight=v and (getgenv().HJVal or 120) or 7.2 end)
            pcall(function() hum.JumpPower=v and (getgenv().HJVal or 120) or 50 end)
        end
        N("High Jump",v and "ON" or "OFF")
    end})
PL:AddSlider("HJVal",{Text="Jump Height",Default=120,Min=8,Max=500,Rounding=0,
    Callback=function(v)
        getgenv().HJVal=v
        if getgenv().HJEnabled then local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum.JumpHeight=v end); pcall(function() hum.JumpPower=v end) end end
    end})

-- AVATAR
PR:AddToggle("AvatarChanger",{Text="Avatar Changer",Default=false,
    Callback=function(v)
        __av_flags["AvatarChanger"]=v
        if v then
            local char=LocalPlayer.Character
            if char and __av_flags["name"] and __av_flags["name"]~="" then __av_set(__av_flags["name"],char) end
            if not __av_flags["loop"] then
                __av_flags["loop"]=LocalPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.05); if __av_flags["name"] then __av_set(__av_flags["name"],char) end
                end)
            end
        else
            if __av_flags["loop"] then __av_flags["loop"]:Disconnect(); __av_flags["loop"]=nil end
            __av_stop_all()
            local char=LocalPlayer.Character
            if char then pcall(function() LocalPlayer:ClearCharacterAppearance(); local ok,desc=pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end); if ok and desc then local hum=char:FindFirstChildOfClass("Humanoid"); if hum then hum:ApplyDescriptionClientServer(desc) end end end) end
        end
        N("Avatar Changer",v and "ON" or "OFF")
    end})
PR:AddInput("AvatarName",{Default="",Numeric=false,Finished=true,Text="Username",Placeholder="Enter username...",
    Callback=function(v)
        __av_flags["name"]=v
        if __av_flags["AvatarChanger"] and v~="" then local char=LocalPlayer.Character; if char then __av_set(v,char) end end
    end})

-- SKIN
local SL=Tabs.Skin:AddLeftGroupbox("Skin Changer")
local SR=Tabs.Skin:AddRightGroupbox("Avatar")

SL:AddToggle("SkinChanger",{Text="Skin Changer",Default=false,
    Callback=function(v)
        getgenv().skinChangerEnabled=v; getgenv().changeSwordModel=v; getgenv().changeSwordAnimation=v; getgenv().changeSwordFX=v
        if getgenv().updateSword then getgenv().updateSword() end; N("Skin Changer",v and "ON" or "OFF")
    end})
SL:AddInput("SwordName",{Default="",Numeric=false,Finished=true,Text="Sword Name",Placeholder="Sword Name...",
    Callback=function(v)
        getgenv().swordModel=v; getgenv().swordAnimations=v; getgenv().swordFX=v
        if getgenv().updateSword then getgenv().updateSword() end
    end})

SR:AddToggle("AvatarChanger2",{Text="Avatar Changer",Default=false,
    Callback=function(v)
        __av_flags["AvatarChanger"]=v
        if v then
            local char=LocalPlayer.Character
            if char and __av_flags["name"] and __av_flags["name"]~="" then __av_set(__av_flags["name"],char) end
            if not __av_flags["loop"] then
                __av_flags["loop"]=LocalPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.05); if __av_flags["name"] then __av_set(__av_flags["name"],char) end
                end)
            end
        else
            if __av_flags["loop"] then __av_flags["loop"]:Disconnect(); __av_flags["loop"]=nil end
            __av_stop_all()
        end
        N("Avatar Changer",v and "ON" or "OFF")
    end})
SR:AddInput("AvatarName2",{Default="",Numeric=false,Finished=true,Text="Username",Placeholder="Enter username...",
    Callback=function(v)
        __av_flags["name"]=v
        if __av_flags["AvatarChanger"] and v~="" then local char=LocalPlayer.Character; if char then __av_set(v,char) end end
    end})

-- SPAM TAB â€” Eagle Macro Paid
local SpamLeft=Tabs.Spam:AddLeftGroupbox("Eagle Macro Paid")
local SpamRight=Tabs.Spam:AddRightGroupbox("Info")

SpamLeft:AddLabel("Eagle Macro Paid")
SpamLeft:AddLabel("Executo")
SpamLeft:AddDivider()
SpamLeft:AddButton({Text="Load Eagle Macro",Func=function()
    loadEagleSpam()
    N("Eagle Macro","Spam script Loaded")
end})
SpamLeft:AddButton({Text="Close Eagle Macro",Func=function()
    local g=game.CoreGui:FindFirstChild("SpamHubGui")
    if g then g:Destroy(); eagleSpamLoaded=false; N("Eagle Macro","Closed") else N("Eagle Macro","Not Open") end
end})

SpamRight:AddLabel("Eagle Macro Paid:")
SpamRight:AddLabel("CPS Slider")
SpamRight:AddLabel("Toggle / Hold Mode")
SpamRight:AddLabel("Anim Fix")
SpamRight:AddLabel("Anti Lag")
SpamRight:AddLabel("FOV Changer")
SpamRight:AddLabel("Spam Key seأ§imi")

-- SETTINGS
local UG=Tabs.Settings:AddLeftGroupbox("Menu","wrench")

UG:AddToggle("ShowCustomCursor",{Text="Custom Cursor",Default=true,Callback=function(v) Library.ShowCustomCursor=v end})
UG:AddDivider()
UG:AddLabel("Hide UI Key"):AddKeyPicker("HideKeybind",{Default="RightShift",NoUI=false,Text="Hide/Show keybind",
    Callback=function(v) HideKey=v end})
UG:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind",{Default="RightShift",NoUI=true,Text="Menu keybind"})
UG:AddButton("Unload",function() Library:Unload() end)
Library.ToggleKeybind=Options.MenuKeybind

ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({"MenuKeybind","HideKeybind"})
ThemeManager:SetFolder("UwuDll"); SaveManager:SetFolder("UwuDll/settings")
SaveManager:BuildConfigSection(Tabs.Settings); ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- BALL STATS GUI
local StatsGui=Instance.new("ScreenGui",CoreGui)
StatsGui.Name="UwuBallStats"; StatsGui.ResetOnSpawn=false; StatsGui.IgnoreGuiInset=true

local StatsFrame=Instance.new("Frame",StatsGui)
StatsFrame.Size=UDim2.new(0,175,0,110); StatsFrame.Position=UDim2.new(0,20,0.5,-55)
StatsFrame.BackgroundColor3=Color3.fromRGB(10,10,10); StatsFrame.BorderSizePixel=0; StatsFrame.Visible=false
Instance.new("UICorner",StatsFrame).CornerRadius=UDim.new(0,10)
Instance.new("UIStroke",StatsFrame).Color=Color3.fromRGB(255,140,0)

local STitle=Instance.new("TextLabel",StatsFrame); STitle.Size=UDim2.new(1,0,0,28); STitle.Text=" BALL STATS"; STitle.TextColor3=Color3.fromRGB(255,140,0); STitle.BackgroundTransparency=1; STitle.Font=Enum.Font.GothamBold; STitle.TextSize=13; STitle.TextXAlignment=Enum.TextXAlignment.Left
local VLog=Instance.new("TextLabel",StatsFrame); VLog.Position=UDim2.new(0.08,0,0.4,0); VLog.Size=UDim2.new(0.8,0,0,26); VLog.Text="0.0"; VLog.TextColor3=Color3.new(1,1,1); VLog.BackgroundTransparency=1; VLog.Font=Enum.Font.GothamBold; VLog.TextSize=24; VLog.TextXAlignment=Enum.TextXAlignment.Left
local VLabel=Instance.new("TextLabel",StatsFrame); VLabel.Position=UDim2.new(0.08,0,0.28,0); VLabel.Size=UDim2.new(0.8,0,0,14); VLabel.Text="Current"; VLabel.TextColor3=Color3.fromRGB(130,130,130); VLabel.BackgroundTransparency=1; VLabel.Font=Enum.Font.Gotham; VLabel.TextSize=10; VLabel.TextXAlignment=Enum.TextXAlignment.Left
local PLog=Instance.new("TextLabel",StatsFrame); PLog.Position=UDim2.new(0.08,0,0.78,0); PLog.Size=UDim2.new(0.8,0,0,18); PLog.Text="0.0"; PLog.TextColor3=Color3.fromRGB(50,220,80); PLog.BackgroundTransparency=1; PLog.Font=Enum.Font.GothamBold; PLog.TextSize=14; PLog.TextXAlignment=Enum.TextXAlignment.Left
local PLabel=Instance.new("TextLabel",StatsFrame); PLabel.Position=UDim2.new(0.08,0,0.68,0); PLabel.Size=UDim2.new(0.8,0,0,12); PLabel.Text="Peak"; PLabel.TextColor3=Color3.fromRGB(130,130,130); PLabel.BackgroundTransparency=1; PLabel.Font=Enum.Font.Gotham; PLabel.TextSize=10; PLabel.TextXAlignment=Enum.TextXAlignment.Left

-- Ball Stats toggle-u StatsFrame ilة™ baؤںla
Library.Toggles["BallStats"]:OnChanged(function()
    StatsFrame.Visible=Library.Toggles["BallStats"].Value
    if not Library.Toggles["BallStats"].Value then peakVel=0; VLog.Text="0.0"; PLog.Text="0.0" end
end)

-- HIDE KEY
UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode==HideKey then
        Library.Toggled=not Library.Toggled
        Library:SetWindowVis(Library.Toggled)
    end
    if inp.KeyCode==Enum.KeyCode.E and ManualSpam then
        if not isInGame() then return end
        spamActive=not spamActive
        N("Manual Spam",spamActive and "ON" or "OFF")
    end
end)

task.spawn(function()
    while not remoteHooked do task.wait(0.1) end
    N("Eagle hub","Remote  â€” "..(getgenv()._hookUsedStr or "OK"))
end)
N("Eagle hub","Loaded |  RightShift = Toggle UI")

-- MAIN HEARTBEAT
local lastBallCheck=0; local cachedBall=nil; local lastHrpCache=0; local cachedHrp=nil; local frameCount=0
RunService.Heartbeat:Connect(function()
    local now=tick(); frameCount+=1
    if now-lastHrpCache>0.15 then local ch=LocalPlayer.Character; cachedHrp=ch and ch:FindFirstChild("HumanoidRootPart"); lastHrpCache=now end
    local hrp=cachedHrp; if not hrp then return end
    if now-lastBallCheck>0.08 then
        cachedBall=nil
        local bc=workspace:FindFirstChild("Balls")
        if bc then for _,b in pairs(bc:GetChildren()) do if b:IsA("BasePart") and b:GetAttribute("realBall") then cachedBall=b; break end end end
        lastBallCheck=now
    end
    local ball=cachedBall; local inGame=isInGame()

    -- Speed maintain
    if getgenv().SpeedEnabled then
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed~=(getgenv().SpeedVal or 30) then hum.WalkSpeed=getgenv().SpeedVal or 30 end
    end

    -- High Jump maintain
    if getgenv().HJEnabled then
        local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() if hum.JumpHeight~=(getgenv().HJVal or 120) then hum.JumpHeight=getgenv().HJVal or 120 end end)
            pcall(function() if hum.JumpPower~=(getgenv().HJVal or 120) then hum.JumpPower=getgenv().HJVal or 120 end end)
        end
    end

    if ball and ball:IsA("BasePart") then
        local vel=ball.Velocity.Magnitude

        -- Ball Stats
        if ShowBallStats and frameCount%3==0 then
            VLog.Text=string.format("%.1f",vel)
            if vel>peakVel then peakVel=vel; PLog.Text=string.format("%.1f",peakVel) end
        end

        local Ping=0.08; pcall(function() Ping=StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
        local target=ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("targetPlayer") or ball:GetAttribute("TargetPlayer")
        local isMyBall=(target==LocalPlayer.Name) or (target==LocalPlayer.UserId) or (target==tostring(LocalPlayer.UserId))
        local speed=vel
        local dist=(hrp.Position-ball.Position).Magnitude

        -- AUTO PARRY
       if AutoParry and remote and f_raw and isMyBall then
            local blocked=(detections.infinity and infinity_active)
                       or (detections.deathslash and deathslash_active)
                       or (detections.timehole and timehole_active)
            if not blocked then
                local bID=ball:GetDebugId()
                if not parried_balls[bID] then
                    local shouldParry=false
                    local Zoomies=ball:FindFirstChild("zoomies")
                    if Zoomies then
                        local Vel=Zoomies.VectorVelocity; local Dir=(hrp.Position-ball.Position).Unit; local Dot=Dir:Dot(Vel.Unit)
                        if AntiCurve then
                            if dist<=ParryDist then shouldParry=true end
                        else
                            if Dot>=(0.1-Ping*0.2) then
                                local current_ping_ms = Ping * 100
                                local Ping_Threshold = math.clamp(current_ping_ms / 10, 5, 17)
                                local dynamic_speed = speed * 1.4 
                                local cappedSpeedDiff = math.min(math.max(dynamic_speed - 9.2, 0), 640)
                                local speed_divisor = 2.1 + cappedSpeedDiff * 0.006
                                local Parry_Accuracy = Ping_Threshold + math.max(dynamic_speed / speed_divisor, 9.2) + (dist / 75)
                                if (dist - 4) <= Parry_Accuracy then 
                                    shouldParry=true 
                                end
                            end
                        end
                    else
                        if dist<=ParryDist and speed>0.6 then shouldParry=true end
                    end
                    if shouldParry then
                        fireParry(); parried_balls[bID]=true
                        task.spawn(function() ball:GetAttributeChangedSignal("target"):Wait(); parried_balls[bID]=nil end)
                    end
                end
            end
        end
    else
        if ShowBallStats and frameCount%3==0 then VLog.Text="0.0" end
    end

    -- MANUAL SPAM
    if ManualSpam and spamActive and remote and f_raw and inGame then
        if now-lastSpamTime>=spamInterval then lastSpamTime=now; fireParry() end
    end
    if not inGame and spamActive then spamActive=false end
end)
