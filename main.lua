local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local function cref(o) if cloneref then local ok,r=pcall(cloneref,o) if ok then return r end end return o end
local RS=cref(ReplicatedStorage) local WS=cref(Workspace) local UIS=cref(UserInputService)
local RunS=cref(RunService) local TS=cref(TweenService) local CG=cref(CoreGui)

local function sgup(fn)
    if getupvalues then local ok,u=pcall(getupvalues,fn) if ok then return u end end
    if debug and debug.getupvalues then local ok,u=pcall(debug.getupvalues,fn) if ok then return u end end
end
local function sgmt(o) if getrawmetatable then local ok,m=pcall(getrawmetatable,o) if ok then return m end end end
local function ssro(m,s) if setreadonly then pcall(setreadonly,m,s) end end

local _PARRY_PATCH={keyTable=nil,transformFn=nil,parryHash=nil,parryRemote=nil,ready=false}
task.spawn(function() pcall(function()
    local C=RS:WaitForChild("Controllers",30) if not C then return end
    local SC for _,c in ipairs(C:GetChildren()) do if c.Name:sub(1,16)=="SwordsController" then SC=c break end end
    if not SC then return end
    local PRY=SC:WaitForChild("PRY",30) if not PRY then return end
    local fn=require(PRY) local ups=sgup(fn) if not ups or #ups<8 then return end
    _PARRY_PATCH.keyTable=ups[3] _PARRY_PATCH.transformFn=ups[4] _PARRY_PATCH.parryHash=ups[8]
    print("[PARRY] keys captured")
end) end)

local _rev={}
local function _val(a) return #a==8 and type(a[2])=="string" and type(a[3])=="string" and type(a[4])=="number" and typeof(a[5])=="CFrame" and type(a[6])=="table" and type(a[7])=="table" and type(a[8])=="boolean" end
local function _hook(r)
    if _rev[r] then return end
    local mt=sgmt(r)
    if mt then local ok=pcall(function()
        ssro(mt,false) local old=mt.__index
        mt.__index=function(self,key)
            if (key=='FireServer' and self:IsA('RemoteEvent')) or (key=='InvokeServer' and self:IsA('RemoteFunction')) then
                return function(_,...) local a={...} if _val(a) and not _rev[self] then _rev[self]=a _PARRY_PATCH.ready=true _PARRY_PATCH.parryRemote=self end return old(self,key)(_,unpack(a)) end
            end
            return old(self,key)
        end
        ssro(mt,true)
    end) if ok then return end end
end
for _,r in ipairs(RS:GetDescendants()) do if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then _hook(r) end end
RS.DescendantAdded:Connect(function(r) if r:IsA('RemoteEvent') or r:IsA('RemoteFunction') then _hook(r) end end)

function _PARRY_PATCH.fire(ccf,sp,ml)
    if not _PARRY_PATCH.ready then return false end
    local kt=_PARRY_PATCH.keyTable if not kt then return false end
    local ki=kt[1] local key=kt[2] and kt[2][ki] if not key then return false end
    local tok,tr=pcall(_PARRY_PATCH.transformFn,key,"TIME")
    if not tok or not tr then tok,tr=pcall(_PARRY_PATCH.transformFn,key) if not tok or not tr then return false end end
    local st=tostring(math.floor(WS:GetServerTimeNow()*100)) local tc={}
    for i=1,#st do local k=(i-1)%#tr+1 tc[i]=string.char(bit32.bxor((string.byte(st,i)+i)%256,string.byte(tr,k))) end
    return pcall(function() _PARRY_PATCH.parryRemote:FireServer(_PARRY_PATCH.parryHash,key,table.concat(tc),0.5,ccf,sp,ml,false) end)
end

local Alive=WS:FindFirstChild("Alive") or WS:WaitForChild("Alive",30)
local System={__properties={__autoparry_enabled=false,__manual_spam_enabled=false,__auto_spam_enabled=false,__curve_mode=1,__accuracy=50,__divisor_multiplier=1.1,__parried=false,__training_parried=false,__spam_threshold=1.5,__spam_accumulator=0,__spam_rate=100,__connections={},__humanizer_enabled=false,__humanizer_min_accuracy=1,__humanizer_max_accuracy=50,__humanizer_last_update=0,__humanizer_next_change=0.8,__infinity_active=false,__deathslash_active=false,__timehole_active=false,__slashesoffury_active=false,__slashesoffury_count=0},__config={__curve_names={'Camera','Random','Accelerated','Backwards','Slow','High','Left','Right'},__detections={__infinity=false,__deathslash=false,__timehole=false,__slashesoffury=false,__phantom=false,__dribble=false}},__triggerbot={__enabled=false,__is_parrying=false,__parries=0,__max_parries=10000,__parry_delay=0.5}}

System.ball={}
function System.ball.get() local b=WS:FindFirstChild('Balls') if not b then return end for _,x in pairs(b:GetChildren()) do if x:GetAttribute('realBall') then x.CanCollide=false return x end end end
function System.ball.get_all() local t={} local b=WS:FindFirstChild('Balls') if not b then return t end for _,x in pairs(b:GetChildren()) do if x:GetAttribute('realBall') then x.CanCollide=false table.insert(t,x) end end return t end

System.player={}
function System.player.get_closest() local md,cl=math.huge,nil if not Alive then return end for _,e in pairs(Alive:GetChildren()) do if e~=LocalPlayer.Character and e.PrimaryPart then local d=LocalPlayer:DistanceFromCharacter(e.PrimaryPart.Position) if d<md then md,cl=d,e end end end return cl end
function System.player.get_closest_to_cursor() local ch=LocalPlayer.Character if not ch or not ch:FindFirstChild('HumanoidRootPart') then return end local cam=WS.CurrentCamera local ok,ml=pcall(function() return UIS:GetMouseLocation() end) if not ok then return end local ray=cam:ScreenPointToRay(ml.X,ml.Y) local ptr=CFrame.lookAt(ray.Origin,ray.Origin+ray.Direction) local b,bs=nil,-math.huge if not Alive then return end for _,p in pairs(Alive:GetChildren()) do if p~=ch and p:FindFirstChild('HumanoidRootPart') then local dir=(p.HumanoidRootPart.Position-cam.CFrame.Position).Unit local d=ptr.LookVector:Dot(dir) if d>bs then bs,b=d,p end end end return b end

System.curve={}
function System.curve.get_cframe() local cam=WS.CurrentCamera local ch=LocalPlayer.Character local root=ch and ch:FindFirstChild('HumanoidRootPart') if not root then return cam.CFrame end local t=System.player.get_closest_to_cursor() local tp=(t and t:FindFirstChild('HumanoidRootPart') and t.HumanoidRootPart.Position) or (root.Position+cam.CFrame.LookVector*100) local m=System.__properties.__curve_mode if m==1 then return cam.CFrame end if m==2 then local dir=(tp-root.Position).Unit local off,tr=nil,0 repeat off=Vector3.new(math.random(-4000,4000),math.random(-4000,4000),math.random(-4000,4000)) tr+=1 until dir:Dot((tp+off-root.Position).Unit)<0.95 or tr>10 return CFrame.new(root.Position,tp+off) end if m==3 then return CFrame.new(root.Position,tp+Vector3.new(0,5,0)) end if m==4 then local dir=(root.Position-tp).Unit return CFrame.new(cam.CFrame.Position,root.Position+dir*10000+Vector3.new(0,1000,0)) end if m==5 then return CFrame.new(root.Position,tp+Vector3.new(0,-9e18,0)) end if m==6 then return CFrame.new(root.Position,tp+Vector3.new(0,9e18,0)) end if m==7 then return CFrame.new(root.Position,root.Position-cam.CFrame.RightVector*10000) end if m==8 then return CFrame.new(root.Position,root.Position+cam.CFrame.RightVector*10000) end return cam.CFrame end

System.detection={__bp={__lw=tick(),__cv=tick(),__lr=0}}
function System.detection.is_curved() local bp=System.detection.__bp local ball=System.ball.get() if not ball then return false end local ch=LocalPlayer.Character if not ch or not ch.PrimaryPart then return false end local z=ball:FindFirstChild('zoomies') if not z then return false end local vel=z.VectorVelocity or Vector3.new() local sp=vel.Magnitude if sp==0 then return false end local bd=vel.Unit local dv=ch.PrimaryPart.Position-ball.Position if dv.Magnitude==0 then return false end local dir=dv.Unit local dot=dir:Dot(bd) local dist=dv.Magnitude local ping=Stats.Network.ServerStatsItem['Data Ping']:GetValue() local thr=0.5-(ping/1000) local reach=dist/sp-(ping/1000) local bthr=15-math.min(dist/1000,15)+math.min(sp/100,40) local cl=math.clamp(dot,-1,1) local rad=math.rad(math.asin(cl)) bp.__lr=bp.__lr+(rad-bp.__lr)*0.8 if sp>0 and reach>ping/10 then bthr=math.max(bthr-15,15) end if dist<bthr then return false end if bp.__lr<0.018 then bp.__lw=tick() end if (tick()-bp.__lw)<(reach/1.5) then return true end if (tick()-bp.__cv)<(reach/1.5) then return true end return dot<thr end

System.parry={}
function System.parry.execute() if not _PARRY_PATCH.ready then return end local cam=WS.CurrentCamera local ok,ml=pcall(function() return UIS:GetMouseLocation() end) if not ok then return end local sp={} if Alive then for _,e in pairs(Alive:GetChildren()) do if e.PrimaryPart then local ok2,s=pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end) if ok2 then sp[e.Name]=s end end end end _PARRY_PATCH.fire(System.curve.get_cframe(),sp,{ml.X,ml.Y}) end
function System.parry.keypress() if PF then pcall(PF) end end

pcall(function()
    RS.Remotes.DeathBall.OnClientEvent:Connect(function(c,d) System.__properties.__deathslash_active=d or false end)
    RS.Remotes.InfinityBall.OnClientEvent:Connect(function(a,b) System.__properties.__infinity_active=b or false end)
end)
pcall(function()
    local n=RS.Packages._Index["sleitnick_net@0.1.0"].net
    n["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...) local a={...} local p=a[1] if p==LocalPlayer or p==LocalPlayer.Name or (p and p.Name==LocalPlayer.Name) then System.__properties.__timehole_active=true end end)
    n["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function() System.__properties.__timehole_active=false end)
    n["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...) local a={...} local p=a[1] if p==LocalPlayer or p==LocalPlayer.Name or (p and p.Name==LocalPlayer.Name) then System.__properties.__slashesoffury_active=true System.__properties.__slashesoffury_count=0 end end)
    n["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function() System.__properties.__slashesoffury_active=false System.__properties.__slashesoffury_count=0 end)
    n["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function() System.__properties.__slashesoffury_count+=1 end)
end)

local function upd_div() System.__properties.__divisor_multiplier=0.7+(System.__properties.__accuracy-1)*0.0035353535353535 end
local function upd_rand()
    if not System.__properties.__humanizer_enabled then return end
    local p=System.__properties local now=os.clock()
    if now<p.__humanizer_last_update+p.__humanizer_next_change then return end
    p.__humanizer_last_update=now
    local ps=Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping=tonumber(ps:match("%d+")) or 0
    local mn=math.clamp(p.__humanizer_min_accuracy,1,50) local mx=math.clamp(p.__humanizer_max_accuracy,1,50)
    if mn>mx then mn,mx=mx,mn end
    local cur=math.clamp(p.__accuracy,mn,mx) local span=math.max(1,mx-mn)
    local pf=ping>=90 and 0.75 or (ping<=50 and 1.25 or 1)
    local roll=math.random(1,100) local nw
    if ping>=90 then nw=math.clamp(cur+math.random(-1,1),mn,mx)
    elseif roll<=45 then nw=math.clamp(cur+math.random(-2,2),mn,mx)
    elseif roll<=80 then local d=math.random(2,math.max(3,math.floor(span*0.2))) local dir=math.random()<0.5 and -d or d nw=math.clamp(cur+dir,mn,mx)
    else nw=math.random(mn,mx) end
    if nw then p.__accuracy=nw p.__humanizer_next_change=math.random(0.7,1.4)/pf upd_div() end
end
task.spawn(function() while task.wait(0.1) do if System.__properties.__humanizer_enabled then pcall(upd_rand) end end end)

System.autoparry={}
function System.autoparry.start()
    if System.__properties.__connections.__ap then System.__properties.__connections.__ap:Disconnect() end
    System.__properties.__connections.__ap=RunS.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled then return end
        local ch=LocalPlayer.Character if not ch or not ch.PrimaryPart then return end
        for _,ball in pairs(System.ball.get_all()) do
            if getgenv().BallVelocityAbove800 then return end
            if not ball then continue end
            local z=ball:FindFirstChild('zoomies') if not z then continue end
            ball:GetAttributeChangedSignal('target'):Once(function() System.__properties.__parried=false end)
            if System.__properties.__parried then continue end
            local tgt=ball:GetAttribute('target')
            local vel=z.VectorVelocity
            local dist=(ch.PrimaryPart.Position-ball.Position).Magnitude
            local ping=Stats.Network.ServerStatsItem['Data Ping']:GetValue()/10
            local pthr=math.clamp(ping/10,5,17)
            local sp=vel.Magnitude
            local csd=math.min(math.max(sp-9.5,0),650)
            local sd=(2.4+csd*0.002)*System.__properties.__divisor_multiplier
            local acc=pthr+math.max(sp/sd,9.5)
            local curved=System.detection.is_curved()
            if ball:FindFirstChild('AeroDynamicSlashVFX') then ball.AeroDynamicSlashVFX:Destroy() end
            if ball:FindFirstChild('ComboCounter') then continue end
            if ch.PrimaryPart:FindFirstChild('SingularityCape') then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            if tgt==LocalPlayer.Name and dist<=acc then
                if getgenv().AutoParryMode=="Keypress" then System.parry.keypress() else System.parry.execute() end
                System.__properties.__parried=true
            end
            local t=tick() repeat RunS.Stepped:Wait() until (tick()-t)>=1 or not System.__properties.__parried
            System.__properties.__parried=false
        end
    end)
end
function System.autoparry.stop() if System.__properties.__connections.__ap then System.__properties.__connections.__ap:Disconnect() System.__properties.__connections.__ap=nil end end

System.auto_spam={}
function System.auto_spam.start()
    if System.__properties.__connections.__as then System.__properties.__connections.__as:Disconnect() end
    System.__properties.__connections.__as=RunS.PreSimulation:Connect(function()
        if not System.__properties.__auto_spam_enabled then return end
        local ball=System.ball.get() if not ball then return end
        local ch=LocalPlayer.Character if not ch or not ch.PrimaryPart then return end
        local z=ball:FindFirstChild('zoomies') if not z then return end
        local tgt=System.player.get_closest() if not tgt or not tgt.PrimaryPart then return end
        local ping=Stats.Network.ServerStatsItem['Data Ping']:GetValue()
        local pthr=math.clamp(ping/10,1,16)
        local vel=z.VectorVelocity if vel.Magnitude==0 then return end
        local dist=LocalPlayer:DistanceFromCharacter(ball.Position)
        local tdist=LocalPlayer:DistanceFromCharacter(tgt.PrimaryPart.Position)
        if dist<=pthr+9.5 or tdist<=pthr+9.5 then
            if System.__properties.__slashesoffury_active then return end
            if getgenv().AutoSpamMode=="Keypress" then if PF then PF() end else System.parry.execute() end
        end
    end)
end
function System.auto_spam.stop() if System.__properties.__connections.__as then System.__properties.__connections.__as:Disconnect() System.__properties.__connections.__as=nil end end

System.manual_spam={}
function System.manual_spam.start()
    if System.__properties.__connections.__ms then System.__properties.__connections.__ms:Disconnect() end
    System.__properties.__manual_spam_enabled=true
    System.__properties.__connections.__ms=RunS.Heartbeat:Connect(function(dt)
        if not System.__properties.__manual_spam_enabled then return end
        local ch=LocalPlayer.Character if not ch or ch.Parent~=Alive then return end
        System.__properties.__spam_accumulator+=dt
        local interval=1/(getgenv().ManualSpamCPS or 100)
        if System.__properties.__spam_accumulator<interval then return end
        System.__properties.__spam_accumulator=0
        System.parry.execute()
    end)
end
function System.manual_spam.stop() System.__properties.__manual_spam_enabled=false if System.__properties.__connections.__ms then System.__properties.__connections.__ms:Disconnect() System.__properties.__connections.__ms=nil end end

System.triggerbot={}
function System.triggerbot.trigger(ball)
    if System.__triggerbot.__is_parrying or System.__triggerbot.__parries>System.__triggerbot.__max_parries then return end
    local ch=LocalPlayer.Character if ch and ch.PrimaryPart and ch.PrimaryPart:FindFirstChild('SingularityCape') then return end
    System.__triggerbot.__is_parrying=true System.__triggerbot.__parries+=1
    System.parry.execute()
    task.delay(System.__triggerbot.__parry_delay,function() if System.__triggerbot.__parries>0 then System.__triggerbot.__parries-=1 end end)
    local c c=ball:GetAttributeChangedSignal('target'):Once(function() System.__triggerbot.__is_parrying=false if c then c:Disconnect() end end)
end
function System.triggerbot.enable(en)
    System.__triggerbot.__enabled=en
    if en then
        if not System.__properties.__connections.__tb then
            System.__properties.__connections.__tb=RunS.Heartbeat:Connect(function()
                if not System.__triggerbot.__enabled then return end
                local ch=LocalPlayer.Character if ch and ch.PrimaryPart and ch.PrimaryPart:FindFirstChild('SingularityCape') then return end
                local b=WS:FindFirstChild('Balls') if not b then return end
                for _,ball in pairs(b:GetChildren()) do if ball:IsA('BasePart') and ball:GetAttribute('target')==LocalPlayer.Name then System.triggerbot.trigger(ball) break end end
            end)
        end
    else
        if System.__properties.__connections.__tb then System.__properties.__connections.__tb:Disconnect() System.__properties.__connections.__tb=nil end
        System.__triggerbot.__is_parrying=false System.__triggerbot.__parries=0
    end
end

-- ===== LIBRARY (UI) =====
local Library={_config={_flags={},_keybinds={},_library={}},_tabs={},_tab=0,_ui_open=true,_ui_scale=1,_dragging=false,_drag_start=nil,_container_position=nil}
Library.__index=Library

local function getConfigPath() return "Azure/"..tostring(game.GameId)..".json" end
local function saveConfig()
    pcall(function()
        if not isfolder("Azure") then makefolder("Azure") end
        writefile(getConfigPath(), game:GetService("HttpService"):JSONEncode(Library._config._flags))
    end)
end
local function loadConfig()
    pcall(function()
        if isfile(getConfigPath()) then
            local d=game:GetService("HttpService"):JSONDecode(readfile(getConfigPath()))
            if type(d)=="table" then Library._config._flags=d end
        end
    end)
end
loadConfig()

local THEME={
    bg=Color3.fromRGB(30,30,35), accent=Color3.fromRGB(78,92,122),
    text=Color3.fromRGB(255,255,255), text_dim=Color3.fromRGB(200,200,200),
    stroke=Color3.fromRGB(78,92,122), module_bg=Color3.fromRGB(16,17,22),
}

local function corner(p,r) local c=Instance.new('UICorner') c.CornerRadius=r or UDim.new(0,8) c.Parent=p return c end
local function stroke(p,c,t) local s=Instance.new('UIStroke') s.Color=c or THEME.stroke s.Thickness=1 s.Transparency=t or 0.28 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=p return s end

local NOTIF_ROOT=nil
local function createNotifRoot()
    if NOTIF_ROOT then return end
    local g=Instance.new('ScreenGui') g.Name='AzureNotifs' g.ResetOnSpawn=false g.IgnoreGuiInset=true g.Parent=CG
    local holder=Instance.new('Frame') holder.AnchorPoint=Vector2.new(0.5,0) holder.Position=UDim2.new(0.5,0,0,14) holder.Size=UDim2.new(0.82,0,1,-28) holder.BackgroundTransparency=1 holder.Parent=g
    local sc=Instance.new('UISizeConstraint',holder) sc.MaxSize=Vector2.new(390,math.huge)
    local ll=Instance.new('UIListLayout',holder) ll.FillDirection=Enum.FillDirection.Vertical ll.HorizontalAlignment=Enum.HorizontalAlignment.Center ll.Padding=UDim.new(0,8)
    NOTIF_ROOT={gui=g,holder=holder}
end

function Library:notify(opt)
    createNotifRoot()
    local card=Instance.new('Frame')
    card.Size=UDim2.new(1,0,0,44) card.BackgroundColor3=Color3.fromRGB(18,20,28) card.BackgroundTransparency=0.02 card.BorderSizePixel=0 card.Parent=NOTIF_ROOT.holder
    corner(card,UDim.new(0,12)) stroke(card,Color3.fromRGB(70,75,90),0.25)
    local lbl=Instance.new('TextLabel',card) lbl.BackgroundTransparency=1 lbl.Position=UDim2.new(0,18,0,0) lbl.Size=UDim2.new(1,-36,1,0) lbl.Text=(opt.title and opt.text) and (opt.title.." - "..opt.text) or (opt.title or opt.text or "Notification") lbl.TextColor3=THEME.text lbl.TextSize=13 lbl.TextXAlignment=Enum.TextXAlignment.Left
    task.delay(opt.duration or 2.5,function() pcall(function() card:Destroy() end) end)
end

local function mkWindow()
    local old=CG:FindFirstChild('Azure') if old then old:Destroy() end
    local g=Instance.new('ScreenGui') g.Name='Azure' g.ResetOnSpawn=false g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling g.Parent=CG
    local c=Instance.new('Frame') c.Name='Container' c.AnchorPoint=Vector2.new(0.5,0.5) c.Position=UDim2.new(0.5,0,0.5,0) c.Size=UDim2.new(0,0,0,0) c.BackgroundColor3=THEME.bg c.BorderSizePixel=0 c.ClipsDescendants=true c.Active=true c.ZIndex=2 c.Parent=g
    corner(c,UDim.new(0,12)) stroke(c,THEME.stroke,0.28)
    local side=Instance.new('Frame') side.Name='GradientSide' side.Size=UDim2.new(0,10,1,0) side.BackgroundTransparency=1 side.Parent=c
    local sg=Instance.new('UIGradient') sg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(30,30,34)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(55,110,190)),ColorSequenceKeypoint.new(1,Color3.fromRGB(110,80,200))} sg.Rotation=90 sg.Parent=side
    local h=Instance.new('Frame') h.Name='Handler' h.BackgroundTransparency=1 h.Size=UDim2.new(0,750,0,530) h.Parent=c
    local tabs=Instance.new('ScrollingFrame') tabs.Name='Tabs' tabs.Size=UDim2.new(0,140,0,445) tabs.Position=UDim2.new(0.026,0,0.111,10) tabs.BackgroundTransparency=1 tabs.ScrollBarThickness=0 tabs.CanvasSize=UDim2.new(0,0,0.5,0) tabs.Parent=h
    local tl=Instance.new('UIListLayout',tabs) tl.Padding=UDim.new(0,4) tl.SortOrder=Enum.SortOrder.LayoutOrder
    local icon=Instance.new('ImageLabel') icon.Name='AzureIcon' icon.BackgroundTransparency=1 icon.Position=UDim2.new(0.02,0,0.049,0) icon.Size=UDim2.new(0,25,0,25) icon.AnchorPoint=Vector2.new(0,0.5) icon.Image='rbxassetid://86155014390461' icon.ScaleType=Enum.ScaleType.Fit icon.Parent=h
    local title=Instance.new('TextLabel') title.Name='ClientName' title.Font=Enum.Font.GothamBold title.TextColor3=Color3.fromRGB(255,255,255) title.Text='Raya hub' title.Size=UDim2.new(0,200,0,20) title.AnchorPoint=Vector2.new(0,0.5) title.Position=UDim2.new(0.060,0,0.049,1) title.BackgroundTransparency=1 title.TextXAlignment=Enum.TextXAlignment.Left title.TextSize=16 title.Parent=h
    local div=Instance.new('Frame') div.Name='Divider' div.BackgroundTransparency=0.5 div.Position=UDim2.new(0.225,0,0,68) div.Size=UDim2.new(0,1,0,440) div.BackgroundColor3=Color3.fromRGB(255,255,255) div.BorderSizePixel=0 div.Parent=h
    local sections=Instance.new('Folder') sections.Name='Sections' sections.Parent=h
    local min=Instance.new('TextButton') min.Name='Minimize' min.Text='' min.AutoButtonColor=false min.BackgroundTransparency=1 min.Position=UDim2.new(0.02,0,0.029,0) min.Size=UDim2.new(0,24,0,24) min.Parent=h
    local uscale=Instance.new('UIScale') uscale.Parent=c
    Library._ui=g Library._container=c Library._tabs_frame=tabs Library._sections=sections Library._handler=h Library._uis=uscale

    local function setVis(s) g.Enabled=s c.Visible=s end
    Library._set_visibility=setVis

    local function dragStart(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            Library._dragging=true Library._drag_start=input.Position Library._container_position=c.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then Library._dragging=false end end)
        end
    end
    c.InputBegan:Connect(dragStart)
    UIS.InputChanged:Connect(function(input)
        if not Library._dragging then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            local delta=input.Position-Library._drag_start
            TS:Create(c,TweenInfo.new(0.2),{Position=UDim2.new(Library._container_position.X.Scale,Library._container_position.X.Offset+delta.X,Library._container_position.Y.Scale,Library._container_position.Y.Offset+delta.Y)}):Play()
        end
    end)

    function Library:change_visiblity(s)
        if s then TS:Create(c,TweenInfo.new(0.5,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(750,530)}):Play()
        else TS:Create(c,TweenInfo.new(0.5,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(104,52)}):Play() end
    end

    function Library:load()
        TS:Create(c,TweenInfo.new(0.5,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(750,530)}):Play()
    end
end

function Library:create_tab(name)
    local TM={_name=name}
    local tab=Instance.new('TextButton') tab.Font=Enum.Font.GothamBold tab.TextColor3=Color3.fromRGB(255,255,255) tab.Text='' tab.AutoButtonColor=false tab.BackgroundTransparency=1 tab.Name='Tab' tab.Size=UDim2.new(0,129,0,38) tab.TextSize=14 tab.BackgroundColor3=Color3.fromRGB(22,22,22) tab.Parent=Library._tabs_frame tab.LayoutOrder=Library._tab
    corner(tab,UDim.new(0,8))
    local lbl=Instance.new('TextLabel',tab) lbl.Font=Enum.Font.GothamBold lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.TextTransparency=0.7 lbl.Text=name lbl.Size=UDim2.new(0,100,0,16) lbl.AnchorPoint=Vector2.new(0,0.5) lbl.Position=UDim2.new(0.24,0,0.5,0) lbl.BackgroundTransparency=1 lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.TextSize=13 lbl.Parent=tab

    local left=Instance.new('ScrollingFrame') left.Name='Left' left.AutomaticCanvasSize=Enum.AutomaticSize.XY left.ScrollBarThickness=0 left.Size=UDim2.new(0,243,0,445) left.AnchorPoint=Vector2.new(0,0.5) left.Position=UDim2.new(0.259,0,0.5,25) left.BackgroundTransparency=1 left.CanvasSize=UDim2.new(0,0,0.5,0) left.Visible=false left.Parent=Library._sections
    local lll=Instance.new('UIListLayout',left) lll.Padding=UDim.new(0,18) lll.HorizontalAlignment=Enum.HorizontalAlignment.Center lll.SortOrder=Enum.SortOrder.LayoutOrder
    local right=Instance.new('ScrollingFrame') right.Name='Right' right.AutomaticCanvasSize=Enum.AutomaticSize.XY right.ScrollBarThickness=0 right.Size=UDim2.new(0,243,0,445) right.AnchorPoint=Vector2.new(0,0.5) right.Position=UDim2.new(0.629,0,0.5,25) right.BackgroundTransparency=1 right.CanvasSize=UDim2.new(0,0,0.5,0) right.Visible=false right.Parent=Library._sections
    local rll=Instance.new('UIListLayout',right) rll.Padding=UDim.new(0,18) rll.HorizontalAlignment=Enum.HorizontalAlignment.Center rll.SortOrder=Enum.SortOrder.LayoutOrder

    TM._left=left TM._right=right TM._tab=tab
    Library._tab+=1

    local first=#Library._tabs==0
    if first then tab.BackgroundTransparency=0.85 left.Visible=true right.Visible=true end

    tab.MouseButton1Click:Connect(function()
        for _,t in ipairs(Library._tabs) do
            if t._tab==tab then t._tab.BackgroundTransparency=0.85 t._left.Visible=true t._right.Visible=true
            else t._tab.BackgroundTransparency=1 t._left.Visible=false t._right.Visible=false end
        end
    end)

    function TM:create_module(cfg)
        local MM={_state=false,_size=0,_mult=0}
        local sec=cfg.section=='right' and right or left
        local mod=Instance.new('Frame') mod.Name='Module' mod.ClipsDescendants=true mod.Size=UDim2.new(0,241,0,93) mod.BackgroundColor3=THEME.module_bg mod.BackgroundTransparency=0.02 mod.BorderSizePixel=0 mod.Parent=sec
        corner(mod,UDim.new(0,8)) stroke(mod,Color3.fromRGB(255,255,255),0.72)
        local ll=Instance.new('UIListLayout',mod) ll.SortOrder=Enum.SortOrder.LayoutOrder
        local hdr=Instance.new('TextButton') hdr.Name='Header' hdr.Text='' hdr.AutoButtonColor=false hdr.BackgroundTransparency=1 hdr.Size=UDim2.new(0,241,0,93) hdr.Parent=mod
        local nm=Instance.new('TextLabel',hdr) nm.Text=cfg.title or 'Module' nm.Font=Enum.Font.GothamSemibold nm.TextColor3=Color3.fromRGB(255,255,255) nm.TextTransparency=0.2 nm.Size=UDim2.new(0,205,0,13) nm.AnchorPoint=Vector2.new(0,0.5) nm.Position=UDim2.new(0.073,0,0.24,0) nm.BackgroundTransparency=1 nm.TextXAlignment=Enum.TextXAlignment.Left nm.TextSize=13
        local ds=Instance.new('TextLabel',hdr) ds.Text=cfg.description or '' ds.Font=Enum.Font.GothamSemibold ds.TextColor3=Color3.fromRGB(255,255,255) ds.TextTransparency=0.7 ds.Size=UDim2.new(0,205,0,13) ds.AnchorPoint=Vector2.new(0,0.5) ds.Position=UDim2.new(0.073,0,0.42,0) ds.BackgroundTransparency=1 ds.TextXAlignment=Enum.TextXAlignment.Left ds.TextSize=10
        local tg=Instance.new('Frame',hdr) tg.Name='Toggle' tg.BackgroundTransparency=0.7 tg.Position=UDim2.new(0.82,0,0.757,0) tg.Size=UDim2.new(0,25,0,12) tg.BackgroundColor3=Color3.fromRGB(44,44,52) tg.BorderSizePixel=0 corner(tg,UDim.new(1,0))
        local circ=Instance.new('Frame',tg) circ.AnchorPoint=Vector2.new(0,0.5) circ.Position=UDim2.new(0,0,0.5,0) circ.Size=UDim2.new(0,12,0,12) circ.BackgroundColor3=Color3.fromRGB(120,120,132) circ.BorderSizePixel=0 circ.Parent=tg corner(circ,UDim.new(1,0))
        local opts=Instance.new('Frame',mod) opts.Name='Options' opts.BackgroundTransparency=1 opts.Position=UDim2.new(0,0,1,0) opts.Size=UDim2.new(0,241,0,8) opts.Parent=mod
        local pad=Instance.new('UIPadding',opts) pad.PaddingTop=UDim.new(0,8)
        local oll=Instance.new('UIListLayout',opts) oll.Padding=UDim.new(0,5) oll.HorizontalAlignment=Enum.HorizontalAlignment.Center oll.SortOrder=Enum.SortOrder.LayoutOrder

        function MM:change_state(s)
            self._state=s
            if s then
                TS:Create(mod,TweenInfo.new(0.5),{Size=UDim2.fromOffset(241,93+self._size+self._mult)}):Play()
                TS:Create(tg,TweenInfo.new(0.5),{BackgroundColor3=Color3.fromRGB(205,205,220)}):Play()
                TS:Create(circ,TweenInfo.new(0.5),{Position=UDim2.fromScale(0.53,0.5),BackgroundColor3=Color3.fromRGB(245,245,250)}):Play()
            else
                TS:Create(mod,TweenInfo.new(0.5),{Size=UDim2.fromOffset(241,93)}):Play()
                TS:Create(tg,TweenInfo.new(0.5),{BackgroundColor3=Color3.fromRGB(44,44,52)}):Play()
                TS:Create(circ,TweenInfo.new(0.5),{Position=UDim2.fromScale(0,0.5),BackgroundColor3=Color3.fromRGB(120,120,132)}):Play()
            end
            if cfg.flag then Library._config._flags[cfg.flag]=s saveConfig() end
            if cfg.callback then pcall(cfg.callback,s) end
        end

        hdr.MouseButton1Click:Connect(function() MM:change_state(not MM._state) end)

        function MM:create_checkbox(c)
            local cb=Instance.new('TextButton',opts) cb.Name='Checkbox' cb.Size=UDim2.new(0,207,0,15) cb.BackgroundTransparency=1 cb.Text='' cb.AutoButtonColor=false cb.LayoutOrder=self._size self._size+=20
            if MM._state then mod.Size=UDim2.fromOffset(241,93+self._size) end
            opts.Size=UDim2.fromOffset(241,self._size)
            local tl=Instance.new('TextLabel',cb) tl.Text=c.title or 'Check' tl.Font=Enum.Font.GothamSemibold tl.TextColor3=Color3.fromRGB(255,255,255) tl.TextTransparency=0.2 tl.Size=UDim2.new(0,142,0,13) tl.AnchorPoint=Vector2.new(0,0.5) tl.Position=UDim2.new(0,0,0.5,0) tl.BackgroundTransparency=1 tl.TextXAlignment=Enum.TextXAlignment.Left tl.TextSize=11
            local bx=Instance.new('Frame',cb) bx.Name='Box' bx.AnchorPoint=Vector2.new(1,0.5) bx.Position=UDim2.new(1,0,0.5,0) bx.Size=UDim2.new(0,15,0,15) bx.BackgroundColor3=Color3.fromRGB(245,245,250) bx.BackgroundTransparency=0.9 bx.BorderSizePixel=0 corner(bx,UDim.new(0,7))
            local fl=Instance.new('Frame',bx) fl.AnchorPoint=Vector2.new(0.5,0.5) fl.Position=UDim2.new(0.5,0,0.5,0) fl.Size=UDim2.fromOffset(0,0) fl.BackgroundColor3=Color3.fromRGB(245,245,250) fl.BorderSizePixel=0 corner(fl,UDim.new(0,6))
            local st=false
            function MM._set_check(v) st=v if v then TS:Create(bx,TweenInfo.new(0.3),{BackgroundTransparency=0.7}):Play() TS:Create(fl,TweenInfo.new(0.3),{Size=UDim2.fromOffset(9,9)}):Play() else TS:Create(bx,TweenInfo.new(0.3),{BackgroundTransparency=0.9}):Play() TS:Create(fl,TweenInfo.new(0.3),{Size=UDim2.fromOffset(0,0)}):Play() end if c.flag then Library._config._flags[c.flag]=v saveConfig() end if c.callback then pcall(c.callback,v) end end
            cb.MouseButton1Click:Connect(function() MM._set_check(not st) end)
            if c.flag and Library._config._flags[c.flag]==true then MM._set_check(true) end
            return cb
        end

        function MM:create_slider(c)
            local sl=Instance.new('TextButton',opts) sl.Name='Slider' sl.Size=UDim2.new(0,207,0,22) sl.BackgroundTransparency=1 sl.Text='' sl.AutoButtonColor=false sl.LayoutOrder=self._size self._size+=27
            if MM._state then mod.Size=UDim2.fromOffset(241,93+self._size) end
            opts.Size=UDim2.fromOffset(241,self._size)
            local tl=Instance.new('TextLabel',sl) tl.Text=c.title or 'Slider' tl.Font=Enum.Font.GothamSemibold tl.TextColor3=Color3.fromRGB(255,255,255) tl.TextTransparency=0.2 tl.Size=UDim2.new(0,153,0,13) tl.Position=UDim2.new(0,0,0.05,0) tl.BackgroundTransparency=1 tl.TextXAlignment=Enum.TextXAlignment.Left tl.TextSize=11
            local dr=Instance.new('Frame',sl) dr.AnchorPoint=Vector2.new(0.5,1) dr.Position=UDim2.new(0.5,0,0.95,0) dr.Size=UDim2.new(0,207,0,4) dr.BackgroundColor3=Color3.fromRGB(34,34,40) dr.BackgroundTransparency=0.7 dr.BorderSizePixel=0 corner(dr,UDim.new(1,0))
            local fi=Instance.new('Frame',dr) fi.AnchorPoint=Vector2.new(0,0.5) fi.Position=UDim2.new(0,0,0.5,0) fi.Size=UDim2.new(0,0,1,0) fi.BackgroundColor3=Color3.fromRGB(255,255,255) fi.BackgroundTransparency=0.15 fi.BorderSizePixel=0 corner(fi,UDim.new(0,3))
            local vl=Instance.new('TextLabel',sl) vl.Text='0' vl.Font=Enum.Font.GothamSemibold vl.TextColor3=Color3.fromRGB(255,255,255) vl.TextTransparency=0.2 vl.Size=UDim2.new(0,42,0,13) vl.AnchorPoint=Vector2.new(1,0) vl.Position=UDim2.new(1,0,0,0) vl.BackgroundTransparency=1 vl.TextXAlignment=Enum.TextXAlignment.Right vl.TextSize=10
            local mn=c.minimum_value or 0 local mx=c.maximum_value or 100 local cur=c.value or mn
            local function setpct(pct)
                local v=math.floor(mn+(mx-mn)*math.clamp(pct,0,1))
                cur=v vl.Text=tostring(v)
                TS:Create(fi,TweenInfo.new(0.2),{Size=UDim2.new(math.clamp(pct,0,1),0,1,0)}):Play()
                if c.flag then Library._config._flags[c.flag]=v saveConfig() end
                if c.callback then pcall(c.callback,v) end
            end
            local function upd()
                local ok,ml=pcall(function() return UIS:GetMouseLocation() end) if not ok then return end
                local pos=(ml.X-dr.AbsolutePosition.X)/dr.AbsoluteSize.X
                setpct(pos)
            end
            sl.MouseButton1Down:Connect(function()
                upd()
                local c1 UIS.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then upd() end end)
                UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if c1 then c1:Disconnect() end end end)
            end)
            setpct((cur-mn)/(mx-mn))
            return {set_percentage=setpct,update=upd}
        end

        function MM:create_dropdown(c)
            local dd=Instance.new('TextButton',opts) dd.Name='Dropdown' dd.Size=UDim2.new(0,207,0,39) dd.BackgroundTransparency=1 dd.Text='' dd.AutoButtonColor=false dd.LayoutOrder=self._size self._size+=44
            if MM._state then mod.Size=UDim2.fromOffset(241,93+self._size) end
            opts.Size=UDim2.fromOffset(241,self._size)
            local tl=Instance.new('TextLabel',dd) tl.Text=c.title or 'Select' tl.Font=Enum.Font.GothamSemibold tl.TextColor3=Color3.fromRGB(255,255,255) tl.TextTransparency=0.2 tl.Size=UDim2.new(0,207,0,13) tl.BackgroundTransparency=1 tl.TextXAlignment=Enum.TextXAlignment.Left tl.TextSize=11
            local bx=Instance.new('Frame',tl) bx.ClipsDescendants=true bx.AnchorPoint=Vector2.new(0.5,0) bx.Position=UDim2.new(0.5,0,1.2,0) bx.Size=UDim2.new(0,207,0,22) bx.BackgroundColor3=Color3.fromRGB(245,245,250) bx.BackgroundTransparency=0.9 bx.BorderSizePixel=0 corner(bx,UDim.new(0,4))
            local cur=tl:FindFirstChild('CurrentOption') or Instance.new('TextLabel',bx) cur.Name='CurrentOption' cur.Font=Enum.Font.GothamSemibold cur.TextColor3=Color3.fromRGB(255,255,255) cur.TextTransparency=0.2 cur.Size=UDim2.new(0,161,0,13) cur.AnchorPoint=Vector2.new(0,0.5) cur.Position=UDim2.new(0.05,0,0.5,0) cur.BackgroundTransparency=1 cur.TextXAlignment=Enum.TextXAlignment.Left cur.TextSize=10
            if cur.Parent~=bx then cur.Parent=bx end
            local opts_f=Instance.new('ScrollingFrame',bx) opts_f.Name='Options' opts_f.Size=UDim2.new(0,207,0,0) opts_f.Position=UDim2.new(0,0,1,0) opts_f.BackgroundTransparency=1 opts_f.BorderSizePixel=0 opts_f.ScrollBarThickness=0 opts_f.CanvasSize=UDim2.new(0,0,0.5,0) opts_f.AutomaticCanvasSize=Enum.AutomaticSize.XY
            local oll=Instance.new('UIListLayout',opts_f) oll.SortOrder=Enum.SortOrder.LayoutOrder
            local opened=false
            local selected=c.options and c.options[1] or ''
            local function render()
                for _,ch in ipairs(opts_f:GetChildren()) do if ch:IsA('TextButton') then ch:Destroy() end end
                for i,o in ipairs(c.options or {}) do
                    local ob=Instance.new('TextButton',opts_f) ob.Text=tostring(o) ob.Font=Enum.Font.GothamSemibold ob.TextColor3=Color3.fromRGB(255,255,255) ob.TextTransparency=(o==selected) and 0.2 or 0.6 ob.TextSize=10 ob.Size=UDim2.new(0,186,0,16) ob.BackgroundTransparency=1 ob.TextXAlignment=Enum.TextXAlignment.Left ob.LayoutOrder=i
                    ob.MouseButton1Click:Connect(function()
                        selected=o cur.Text=tostring(o) opened=false
                        TS:Create(dd,TweenInfo.new(0.3),{Size=UDim2.fromOffset(207,39)}):Play()
                        TS:Create(bx,TweenInfo.new(0.3),{Size=UDim2.fromOffset(207,22)}):Play()
                        TS:Create(opts_f,TweenInfo.new(0.3),{Size=UDim2.new(0,207,0,0)}):Play()
                        if c.flag then Library._config._flags[c.flag]=o saveConfig() end
                        if c.callback then pcall(c.callback,o) end
                        render()
                    end)
                end
            end
            cur.Text=tostring(selected)
            render()
            dd.MouseButton1Click:Connect(function()
                opened=not opened
                local h=opened and (#(c.options or {})*16+22) or 22
                TS:Create(dd,TweenInfo.new(0.3),{Size=UDim2.fromOffset(207,39+(opened and (#(c.options or {})*16+4) or 0))}):Play()
                TS:Create(bx,TweenInfo.new(0.3),{Size=UDim2.fromOffset(207,h)}):Play()
                TS:Create(opts_f,TweenInfo.new(0.3),{Size=UDim2.new(0,207,0,opened and (#(c.options or {})*16) or 0)}):Play()
            end)
            return {update=function(_,v) selected=v cur.Text=tostring(v) if c.flag then Library._config._flags[c.flag]=v saveConfig() end render() end}
        end

        function MM:create_button(c)
            local b=Instance.new('TextButton',opts) b.Name='Button' b.Size=UDim2.new(0,207,0,20) b.Text=c.title or 'Button' b.Font=Enum.Font.GothamSemibold b.TextColor3=Color3.fromRGB(255,255,255) b.TextTransparency=0.2 b.BackgroundColor3=Color3.fromRGB(22,22,27) b.BackgroundTransparency=0.2 b.TextSize=11 b.LayoutOrder=self._size self._size+=20
            if MM._state then mod.Size=UDim2.fromOffset(241,93+self._size) end
            opts.Size=UDim2.fromOffset(241,self._size)
            corner(b,UDim.new(0,4))
            b.MouseButton1Click:Connect(function() if c.callback then pcall(c.callback) end end)
            return b
        end

        if c.flag and Library._config._flags[c.flag]==true then MM:change_state(true) end
        return MM
    end

    if first then
        tab.BackgroundTransparency=0.85 left.Visible=true right.Visible=true
    end
    Library._tabs[#Library._tabs+1]=TM
    return TM
end

mkWindow()
Library:load()
UIS.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.LeftControl then
        Library._ui_open=not Library._ui_open Library:change_visiblity(Library._ui_open)
    end
end)
Library._container.Handler.Minimize.MouseButton1Click:Connect(function()
    Library._ui_open=not Library._ui_open Library:change_visiblity(Library._ui_open)
end)

-- ===== TABS =====
local MainTab=Library:create_tab("Main")
local SpamTab=Library:create_tab("Spam")
local DetectTab=Library:create_tab("Detection")
local GuiTab=Library:create_tab("GUI")

-- Autoparry
local apmod=MainTab:create_module({title='Auto Parry',description='Auto Parry Settings',flag='AutoParryModule',section='left',callback=function(s) System.__properties.__autoparry_enabled=s if s then System.autoparry.start() if getgenv().AutoParryNotify then Library:notify({title='Auto Parry',text='ON',duration=2}) end else System.autoparry.stop() if getgenv().AutoParryNotify then Library:notify({title='Auto Parry',text='OFF',duration=2}) end end end})
apmod:create_dropdown({title='Parry Mode',flag='ParryMode',options={'Remote','Keypress'},callback=function(v) getgenv().AutoParryMode=v end})
apmod:create_dropdown({title='Curve Mode',flag='ModeCurve',options=System.__config.__curve_names,callback=function(v) for i,n in ipairs(System.__config.__curve_names) do if n==v then System.__properties.__curve_mode=i break end end end})
apmod:create_slider({title='Parry Accuracy',flag='ParryAccuracy',minimum_value=1,maximum_value=50,value=50,round_number=true,callback=function(v) System.__properties.__accuracy=v upd_div() end})
local hm=apmod:create_module({title='Humanizer',description='Random accuracy',flag='HumanizerModule',section='left',callback=function(s) System.__properties.__humanizer_enabled=s if s then pcall(upd_rand) end end})
hm:create_slider({title='Min Accuracy',flag='HumanizerMin',minimum_value=1,maximum_value=50,value=1,round_number=true,callback=function(v) System.__properties.__humanizer_min_accuracy=v end})
hm:create_slider({title='Max Accuracy',flag='HumanizerMax',minimum_value=1,maximum_value=50,value=50,round_number=true,callback=function(v) System.__properties.__humanizer_max_accuracy=v end})
apmod:create_checkbox({title='Notify',flag='AutoParryNotify',callback=function(v) getgenv().AutoParryNotify=v end})

local tbmod=MainTab:create_module({title='Triggerbot',description='Triggerbot Settings',flag='TriggerbotModule',section='right',callback=function(s) System.__properties.__triggerbot_enabled=s System.triggerbot.enable(s) if getgenv().TriggerbotNotify then Library:notify({title='Triggerbot',text=s and 'ON' or 'OFF',duration=2}) end end})
tbmod:create_checkbox({title='Notify',flag='TriggerbotNotify',callback=function(v) getgenv().TriggerbotNotify=v end})

-- Manual spam
local msmod=SpamTab:create_module({title='Manual Spam',description='Manually spams parry',flag='Manual_Spam_Parry',section='left',callback=function(s)
    if s then System.manual_spam.start() else System.manual_spam.stop() end
    if getgenv().ManualSpamNotify then Library:notify({title='Manual Spam',text=s and 'ON' or 'OFF',duration=2}) end
end})
msmod:create_slider({title='CPS',flag='Manual_Spam_CPS',minimum_value=1,maximum_value=2000,value=100,round_number=true,callback=function(v) getgenv().ManualSpamCPS=v end})
msmod:create_checkbox({title='Notify',flag='Manual_Spam_Parry_Notify',callback=function(v) getgenv().ManualSpamNotify=v end})

-- Auto spam
local asmod=SpamTab:create_module({title='Auto Spam',description='Auto spam parries ball',flag='AutoSpamModule',section='right',callback=function(s) System.__properties.__auto_spam_enabled=s if s then System.auto_spam.start() if getgenv().AutoSpamNotify then Library:notify({title='Auto Spam',text='ON',duration=2}) end else System.auto_spam.stop() if getgenv().AutoSpamNotify then Library:notify({title='Auto Spam',text='OFF',duration=2}) end end end})
asmod:create_dropdown({title='Mode',flag='AutoSpamMode',options={'Remote','Keypress'},callback=function(v) getgenv().AutoSpamMode=v end})
asmod:create_checkbox({title='Notify',flag='AutoSpamNotify',callback=function(v) getgenv().AutoSpamNotify=v end})

-- Detection
local infmod=DetectTab:create_module({title='Infinity Detection',description='Detect infinity',flag='InfinityModule',section='left',callback=function(s) System.__config.__detections.__infinity=s if getgenv().InfinityNotify then Library:notify({title='Infinity',text=s and 'ON' or 'OFF',duration=2}) end end})
infmod:create_checkbox({title='Notify',flag='InfinityNotify',callback=function(v) getgenv().InfinityNotify=v end})
DetectTab:create_module({title='Death Slash Detection',description='Detect death slash',flag='DeathSlashModule',section='right',callback=function(s) System.__config.__detections.__deathslash=s end})
DetectTab:create_module({title='Time Hole Detection',description='Detect time hole',flag='TimeHoleModule',section='left',callback=function(s) System.__config.__detections.__timehole=s end})
local sfmod=DetectTab:create_module({title='Slashes Of Fury',description='Detect slashes',flag='SlashesModule',section='right',callback=function(s) System.__config.__detections.__slashesoffury=s end})
sfmod:create_slider({title='Parry Delay',flag='ParryDelay',minimum_value=0.05,maximum_value=0.25,value=0.05,callback=function(v) System.__triggerbot.__parry_delay=v end})
DetectTab:create_module({title='Anti-Phantom',description='Anti phantom',flag='PhantomModule',section='left',callback=function(s) System.__config.__detections.__phantom=s end})

-- GUI
local guimod=GuiTab:create_module({title='GUI Visible',description='Toggle GUI',flag='guilibraryvisible',section='left',callback=function(s) getgenv().guilibraryVisible=s end})
GuiTab:create_module({title='Theme Editor',description='Customize theme',flag='ThemeEditor',section='right',callback=function(s) end})

return Library
