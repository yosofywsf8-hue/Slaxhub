-- ================================================================
-- Timebomb Duels | Full AutoPlay + UI
-- Nyx | stealth build, drag-able panel, toggles + sliders
-- ================================================================

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local TweenS      = game:GetService("TweenService")
local CoreGui     = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- 1) الإعدادات الافتراضية
-- ================================================================
_G.AutoPlay       = true
_G.TouchRange     = 3.2
_G.ChaseRange     = 4.5
_G.SpeedMult      = 1.15
_G.UpdateRate     = 1/40
_G.Smooth         = 0.4
_G.Jitter         = 0.03
_G.StopOnBombLoss = true

-- ================================================================
-- 2) مساعدات
-- ================================================================
local function getHRP(plr)
    plr = plr or LocalPlayer
    if plr.Character then
        return plr.Character:FindFirstChild("HumanoidRootPart")
    end
end

local function getHumanoid(plr)
    plr = plr or LocalPlayer
    if plr.Character then
        return plr.Character:FindFirstChildOfClass("Humanoid")
    end
end

local function hasBomb()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, obj in ipairs(char:GetChildren()) do
        local n = obj.Name:lower()
        if n:find("bomb") or n:find("c4") or n:find("tnt")
           or n:find("device") or n:find("payload") or n:find("قنبلة") then
            return true
        end
    end
    for _, attr in ipairs(LocalPlayer:GetAttributes()) do
        local a = attr:lower()
        if (a:find("bomb") or a:find("carrier") or a:find("has") or a:find("holding"))
           and LocalPlayer:GetAttribute(attr) == true then
            return true
        end
    end
    if LocalPlayer:HasTag("HasBomb") or LocalPlayer:HasTag("Bomb") then return true end
    if char:HasTag("HasBomb") or char:HasTag("Bomb") then return true end
    for _, obj in ipairs(char:GetDescendants()) do
        if (obj:IsA("Highlight") or obj:IsA("BillboardGui")) and obj.Enabled then
            if obj.Name:lower():find("bomb") then return true end
        end
    end
    return false
end

local function getTargets()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hum, hrp = getHumanoid(plr), getHRP(plr)
            if hum and hrp and hum.Health > 0 then
                table.insert(list, plr)
            end
        end
    end
    return list
end

local function getNearest(players)
    local myHRP = getHRP()
    if not myHRP then return nil, math.huge end
    local closest, dist = nil, math.huge
    for _, plr in ipairs(players) do
        local hrp = getHRP(plr)
        if hrp then
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d < dist then closest, dist = plr, d end
        end
    end
    return closest, dist
end

local function jitter(v)
    return v + Vector3.new(
        (math.random() - 0.5) * _G.Jitter, 0,
        (math.random() - 0.5) * _G.Jitter
    )
end

-- ================================================================
-- 3) بناء الواجهة
-- ================================================================
local parentGui = (gethui and gethui()) or CoreGui
local old = parentGui:FindFirstChild("NyxTimebombUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NyxTimebombUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- ---- الحاوية الرئيسية ----
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 360)
Main.Position = UDim2.new(0, 30, 0, 100)
Main.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(180, 110, 200)
MainStroke.Thickness = 1.2
MainStroke.Transparency = 0.35
MainStroke.Parent = Main

-- ---- الشريط العلوي ----
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(28, 20, 34)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

-- نظبط الزوايا السفلية (نخفيها بقص)
local fixBottom = Instance.new("Frame")
fixBottom.Size = UDim2.new(1, 0, 0, 12)
fixBottom.Position = UDim2.new(0, 0, 1, -12)
fixBottom.BackgroundColor3 = TopBar.BackgroundColor3
fixBottom.BorderSizePixel = 0
fixBottom.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "♥ Timebomb AutoPlay"
Title.TextColor3 = Color3.fromRGB(230, 200, 240)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- زر التصغير
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -60, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 70)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(230, 200, 240)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = true
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- زر الإغلاق
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -30, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(90, 35, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 210, 220)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- ---- حاوية المحتوى ----
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -50)
Content.Position = UDim2.new(0, 10, 0, 45)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

-- ================================================================
-- 4) مكونات الواجهة
-- ================================================================
local function makeToggle(name, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundColor3 = Color3.fromRGB(24, 18, 30)
    Row.BorderSizePixel = 0
    Row.Parent = Content
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 200, 230)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local state = default

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 42, 0, 20)
    Btn.Position = UDim2.new(1, -52, 0, 5)
    Btn.BackgroundColor3 = state and Color3.fromRGB(160, 90, 190)
                             or Color3.fromRGB(50, 40, 60)
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Btn.Parent = Row
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = state and UDim2.new(1, -18, 0, 2)
                        or UDim2.new(0, 2, 0, 2)
    Knob.BackgroundColor3 = Color3.fromRGB(240, 225, 245)
    Knob.BorderSizePixel = 0
    Knob.Parent = Btn
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    Btn.MouseButton1Click:Connect(function()
        state = not state
        TweenS:Create(Btn, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Color3.fromRGB(160, 90, 190)
                                       or Color3.fromRGB(50, 40, 60)
        }):Play()
        TweenS:Create(Knob, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -18, 0, 2)
                               or UDim2.new(0, 2, 0, 2)
        }):Play()
        if callback then callback(state) end
    end)

    return { set = function(v) state = v end }
end

local function makeSlider(name, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 48)
    Row.BackgroundColor3 = Color3.fromRGB(24, 18, 30)
    Row.BorderSizePixel = 0
    Row.Parent = Content
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 22)
    Label.Position = UDim2.new(0, 12, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = name .. "  •  " .. tostring(default)
    Label.TextColor3 = Color3.fromRGB(220, 200, 230)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -24, 0, 6)
    Track.Position = UDim2.new(0, 12, 0, 30)
    Track.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
    Track.BorderSizePixel = 0
    Track.Parent = Row
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    local startPct = (default - min) / (max - min)
    Fill.Size = UDim2.new(startPct, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(180, 110, 200)
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Drag = Instance.new("TextButton")
    Drag.Size = UDim2.new(1, 0, 1, 0)
    Drag.BackgroundTransparency = 1
    Drag.Text = ""
    Drag.Parent = Track

    local dragging = false
    local value = default

    local function update(input)
        local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        value = min + (max - min) * rel
        value = math.floor(value * 100 + 0.5) / 100
        Fill.Size = UDim2.new(rel, 0, 1, 0)
        Label.Text = name .. "  •  " .. tostring(value)
        if callback then callback(value) end
    end

    Drag.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(i)
        end
    end)
    Drag.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
           or i.UserInputType == Enum.UserInputType.Touch) then
            update(i)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function makeButton(name, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = Color3.fromRGB(140, 75, 170)
    Btn.Text = name
    Btn.TextColor3 = Color3.fromRGB(245, 230, 250)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.Parent = Content
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    Btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
end

-- ---- ملء الواجهة ----
makeToggle("AutoPlay", _G.AutoPlay, function(v) _G.AutoPlay = v end)
makeToggle("Stop after pass", _G.StopOnBombLoss, function(v) _G.StopOnBombLoss = v end)

makeSlider("Speed Multiplier", 1.0, 1.3, _G.SpeedMult, function(v) _G.SpeedMult = v end)
makeSlider("Touch Range", 2.5, 6.0, _G.TouchRange, function(v) _G.TouchRange = v end)
makeSlider("Chase Range", 3.0, 8.0, _G.ChaseRange, function(v) _G.ChaseRange = v end)
makeSlider("Smooth", 0.1, 0.9, _G.Smooth, function(v) _G.Smooth = v end)

makeButton("Reset Defaults", function()
    _G.SpeedMult = 1.15
    _G.TouchRange = 3.2
    _G.ChaseRange = 4.5
    _G.Smooth = 0.4
    print("[Nyx] Defaults restored")
end)

-- ---- حالة تحتية (Footer) ----
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 16)
Footer.BackgroundTransparency = 1
Footer.Text = "Nyx ♥ stealth build"
Footer.TextColor3 = Color3.fromRGB(150, 120, 160)
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 11
Footer.Parent = Content

-- ================================================================
-- 5) أزرار الشريط العلوي
-- ================================================================
local minimized = false
local origSize = Main.Size

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenS:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad),
        { Size = minimized and UDim2.new(0, 300, 0, 40) or origSize }):Play()
    Content.Visible = not minimized
end)

CloseBtn.MouseButton1Click:Connect(function()
    _G.AutoPlay = false
    ScreenGui:Destroy()
    print("[Nyx] UI closed")
end)

-- ================================================================
-- 6) Main Loop (نفس المنطق النظيف)
-- ================================================================
task.spawn(function()
    local stuckTimer, lastPos, strafe = 0, Vector3.zero, 1
    while true do
        task.wait(_G.UpdateRate)
        if not _G.AutoPlay then continue end

        local myHRP = getHRP()
        local myHum = getHumanoid()
        if not myHRP or not myHum or myHum.Health <= 0 then continue end

        local bomb = hasBomb()
        if not bomb and _G.StopOnBombLoss then
            myHum:MoveTo(myHRP.Position)
            continue
        end
        if not bomb then continue end

        local targets = getTargets()
        if #targets == 0 then continue end
        local target, dist = getNearest(targets)
        if not target then continue end

        local thrp = getHRP(target)
        if not thrp then continue end

        if dist <= _G.TouchRange then
            myHum:MoveTo(myHRP.Position)
            if (thrp.Position - myHRP.Position).Magnitude > 0.1 then
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, thrp.Position)
            end
            continue
        end

        if (myHRP.Position - lastPos).Magnitude < 0.15 then
            stuckTimer = stuckTimer + _G.UpdateRate
        else
            stuckTimer = 0
        end
        lastPos = myHRP.Position

        local targetPos = jitter(thrp.Position)
        if stuckTimer > 0.5 then
            strafe = strafe * -1
            targetPos = targetPos + myHRP.CFrame.RightVector * (2.5 * strafe)
            stuckTimer = 0
        end

        local dir = (targetPos - myHRP.Position)
        if dir.Magnitude > 0.1 then
            dir = dir.Unit
            local wp = myHRP.Position + dir * 8
            myHum:MoveTo(Vector3.new(wp.X, myHRP.Position.Y, wp.Z))
        end

        local targetSpeed = 20 * _G.SpeedMult
        myHum.WalkSpeed = myHum.WalkSpeed + (targetSpeed - myHum.WalkSpeed) * _G.Smooth
        if dist < _G.ChaseRange + 2 then
            myHum.WalkSpeed = myHum.WalkSpeed * 0.85
        end
    end
end)

-- ================================================================
-- 7) Anti-AFK
-- ================================================================
local VU = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VU:CaptureController()
    VU:ClickButton2(Vector2.new())
end)

-- ================================================================
-- 8) زر تصغير الواجهة (K = hide/show)
-- ================================================================
UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

print("[Nyx] UI loaded ❤️  — اضغطي RightCtrl لإخفاء/إظهار الواجهة")
