-- ================================================================
-- Timebomb Duels | AutoPlay — Minimal Tab
-- Nyx | one toggle. one tab. clean.
-- ================================================================

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local TweenS      = game:GetService("TweenService")
local CoreGui     = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- 1) الإعدادات الداخلية (لا تُعرض)
-- ================================================================
local CFG = {
    AutoPlay       = true,
    TouchRange     = 3.2,
    ChaseRange     = 4.5,
    SpeedMult      = 1.0,
    UpdateRate     = 1/40,
    Smooth         = 0.45,
    Jitter         = 0.03,
    StopOnBombLoss = true,
    SlowdownNear   = true,
}

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
        (math.random() - 0.5) * CFG.Jitter, 0,
        (math.random() - 0.5) * CFG.Jitter
    )
end

-- ================================================================
-- 3) الواجهة — Tab واحد فقط
-- ================================================================
local parentGui = (gethui and gethui()) or CoreGui
local old = parentGui:FindFirstChild("NyxTimebombUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NyxTimebombUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 200, 0, 62)
Main.Position = UDim2.new(0, 30, 0, 100)
Main.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(180, 110, 200)
Stroke.Thickness = 1.2
Stroke.Transparency = 0.35
Stroke.Parent = Main

-- التاب (شريط الاسم)
local Tab = Instance.new("Frame")
Tab.Size = UDim2.new(1, 0, 0, 26)
Tab.BackgroundColor3 = Color3.fromRGB(28, 20, 34)
Tab.BorderSizePixel = 0
Tab.Parent = Main
Instance.new("UICorner", Tab).CornerRadius = UDim.new(0, 10)

local hideBottom = Instance.new("Frame")
hideBottom.Size = UDim2.new(1, 0, 0, 8)
hideBottom.Position = UDim2.new(0, 0, 1, -8)
hideBottom.BackgroundColor3 = Tab.BackgroundColor3
hideBottom.BorderSizePixel = 0
hideBottom.Parent = Tab

local TabTitle = Instance.new("TextLabel")
TabTitle.Size = UDim2.new(1, -12, 1, 0)
TabTitle.Position = UDim2.new(0, 10, 0, 0)
TabTitle.BackgroundTransparency = 1
TabTitle.Text = "♥ AutoPlay"
TabTitle.TextColor3 = Color3.fromRGB(230, 200, 240)
TabTitle.Font = Enum.Font.GothamBold
TabTitle.TextSize = 12
TabTitle.TextXAlignment = Enum.TextXAlignment.Left
TabTitle.Parent = Tab

-- زر الـ Toggle الوحيد
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -20, 0, 26)
ToggleBtn.Position = UDim2.new(0, 10, 0, 32)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(160, 90, 190)
ToggleBtn.Text = "ON"
ToggleBtn.TextColor3 = Color3.fromRGB(250, 240, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Parent = Main
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 7)

-- ================================================================
-- 4) التوجل
-- ================================================================
ToggleBtn.MouseButton1Click:Connect(function()
    CFG.AutoPlay = not CFG.AutoPlay
    if CFG.AutoPlay then
        TweenS:Create(ToggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = Color3.fromRGB(160, 90, 190)
        }):Play()
        ToggleBtn.Text = "ON"
    else
        TweenS:Create(ToggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = Color3.fromRGB(80, 45, 60)
        }):Play()
        ToggleBtn.Text = "OFF"
    end
end)

-- RightCtrl يخفي/يظهر
UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

-- ================================================================
-- 5) Main Loop
-- ================================================================
task.spawn(function()
    local stuckTimer, lastPos, strafe = 0, Vector3.zero, 1
    while true do
        task.wait(CFG.UpdateRate)
        if not CFG.AutoPlay then continue end

        local myHRP = getHRP()
        local myHum = getHumanoid()
        if not myHRP or not myHum or myHum.Health <= 0 then continue end

        if not hasBomb() then
            if CFG.StopOnBombLoss then
                myHum:MoveTo(myHRP.Position)
            end
            continue
        end

        local targets = getTargets()
        if #targets == 0 then continue end
        local target, dist = getNearest(targets)
        if not target then continue end

        local thrp = getHRP(target)
        if not thrp then continue end

        if dist <= CFG.TouchRange then
            myHum:MoveTo(myHRP.Position)
            if (thrp.Position - myHRP.Position).Magnitude > 0.1 then
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, thrp.Position)
            end
            continue
        end

        if (myHRP.Position - lastPos).Magnitude < 0.15 then
            stuckTimer = stuckTimer + CFG.UpdateRate
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

        local targetSpeed = 20 * CFG.SpeedMult
        myHum.WalkSpeed = myHum.WalkSpeed + (targetSpeed - myHum.WalkSpeed) * CFG.Smooth
        if CFG.SlowdownNear and dist < CFG.ChaseRange + 2 then
            myHum.WalkSpeed = myHum.WalkSpeed * 0.85
        end
    end
end)

-- ================================================================
-- 6) Anti-AFK
-- ================================================================
local VU = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VU:CaptureController()
    VU:ClickButton2(Vector2.new())
end)

print("[Nyx] Minimal tab loaded ❤️")
