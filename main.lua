-- ================================================================
-- Timebomb Duels | AutoPlay — Human Behavior Edition
-- Nyx | randomized, delayed, breaks patterns
-- ================================================================

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local TweenS      = game:GetService("TweenService")
local CoreGui     = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ============ إعدادات داخلية ============
local CFG = {
    AutoPlay        = true,
    UpdateRate      = 0.1,      -- 10Hz بدل 40Hz (بصمة أقل بكثير)
    MinIdleTime     = 0.8,      -- أقل وقت "وقوف"
    MaxIdleTime     = 2.4,      -- أطول وقت "وقوف"
    MinRunTime      = 3.0,      -- أقل وقت ملاحقة
    MaxRunTime      = 7.0,      -- أطول وقت ملاحقة
    TouchRange      = 3.5,
    ChaseRange      = 5.0,
    Jitter          = 0.08,     -- اهتزاز أكبر
    LookAround      = true,     -- يلتفت حوله وأنت واقف
    StartDelay      = 3.0,      -- ينتظر قبل ما يبدأ كل مرة
}

-- ============ مساعدات ============
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
           or n:find("device") or n:find("payload") then
            return true
        end
    end
    for _, attr in ipairs(LocalPlayer:GetAttributes()) do
        local a = attr:lower()
        if (a:find("bomb") or a:find("carrier") or a:find("has"))
           and LocalPlayer:GetAttribute(attr) == true then
            return true
        end
    end
    if LocalPlayer:HasTag("HasBomb") or LocalPlayer:HasTag("Bomb") then return true end
    if char:HasTag("HasBomb") or char:HasTag("Bomb") then return true end
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

local function getRandomTarget(players)
    if #players == 0 then return nil end
    -- أحياناً يختار أقرب، أحياناً عشوائي (يكسر الـ pattern)
    if math.random() < 0.6 then
        -- أقرب
        local myHRP = getHRP()
        if not myHRP then return players[1] end
        local closest, dist = nil, math.huge
        for _, plr in ipairs(players) do
            local hrp = getHRP(plr)
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < dist then closest, dist = plr, d end
            end
        end
        return closest
    else
        -- عشوائي
        return players[math.random(1, #players)]
    end
end

local function jitter(v)
    return v + Vector3.new(
        (math.random() - 0.5) * CFG.Jitter, 0,
        (math.random() - 0.5) * CFG.Jitter
    )
end

-- ============ الواجهة — Tab واحد ============
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

ToggleBtn.MouseButton1Click:Connect(function()
    CFG.AutoPlay = not CFG.AutoPlay
    TweenS:Create(ToggleBtn, TweenInfo.new(0.18), {
        BackgroundColor3 = CFG.AutoPlay and Color3.fromRGB(160, 90, 190)
                                          or Color3.fromRGB(80, 45, 60)
    }):Play()
    ToggleBtn.Text = CFG.AutoPlay and "ON" or "OFF"
end)

UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

-- ============ Main Loop — Human Behavior ============
task.spawn(function()
    -- تأخير أولي
    task.wait(CFG.StartDelay)

    local state = "idle"         -- idle / chase
    local stateTimer = 0
    local currentTarget = nil
    local lookAngle = 0

    while true do
        task.wait(CFG.UpdateRate)
        if not CFG.AutoPlay then
            state = "idle"
            stateTimer = 0
            continue
        end

        local myHRP = getHRP()
        local myHum = getHumanoid()
        if not myHRP or not myHum or myHum.Health <= 0 then continue end

        -- ما عندي قنبلة؟ وقف تماماً
        if not hasBomb() then
            myHum:MoveTo(myHRP.Position)
            state = "idle"
            stateTimer = 0
            continue
        end

        -- ---- حالة "وقوف": يلتفت حوله بدون حركة ----
        if state == "idle" then
            stateTimer = stateTimer + CFG.UpdateRate

            -- يلتفت ببطء حوله
            if CFG.LookAround then
                lookAngle = lookAngle + CFG.UpdateRate * 0.6
                local radius = 8
                local lookAt = myHRP.Position + Vector3.new(
                    math.cos(lookAngle) * radius, 0,
                    math.sin(lookAngle) * radius
                )
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, lookAt)
            end

            if stateTimer >= math.random(CFG.MinIdleTime, CFG.MaxIdleTime) then
                state = "chase"
                stateTimer = 0
                local targets = getTargets()
                currentTarget = getRandomTarget(targets)
            end
            continue
        end

        -- ---- حالة "ملاحقة" ----
        if state == "chase" then
            stateTimer = stateTimer + CFG.UpdateRate

            -- نوقف الملاحقة إذا:
            -- - مضى وقت كافي
            -- - أو ما فيه هدف
            -- - أو ما فيه أهداف
            if stateTimer >= math.random(CFG.MinRunTime, CFG.MaxRunTime) then
                state = "idle"
                stateTimer = 0
                currentTarget = nil
                myHum:MoveTo(myHRP.Position)
                continue
            end

            local targets = getTargets()
            if #targets == 0 then
                state = "idle"
                stateTimer = 0
                continue
            end

            -- لو الهدف مات أو اختفى، نختار غيره
            if not currentTarget or not currentTarget.Character
               or not currentTarget.Character:FindFirstChild("HumanoidRootPart")
               or not currentTarget.Character:FindFirstChildOfClass("Humanoid")
               or currentTarget.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                currentTarget = getRandomTarget(targets)
            end

            if not currentTarget then
                state = "idle"
                stateTimer = 0
                continue
            end

            local thrp = getHRP(currentTarget)
            if not thrp then
                state = "idle"
                stateTimer = 0
                continue
            end

            local dist = (thrp.Position - myHRP.Position).Magnitude

            -- وصلنا؟ نوقف ونتجه نحوهم
            if dist <= CFG.TouchRange then
                myHum:MoveTo(myHRP.Position)
                if dist > 0.1 then
                    myHRP.CFrame = CFrame.lookAt(myHRP.Position, thrp.Position)
                end
                -- أحياناً "يتصرف بشكل بشري": يدور حولهم
                if math.random() < 0.15 then
                    local offset = myHRP.CFrame.RightVector * (math.random() - 0.5) * 2
                    myHum:MoveTo(myHRP.Position + offset)
                end
                continue
            end

            -- حركة عادية نحو الهدف
            local dir = (jitter(thrp.Position) - myHRP.Position)
            if dir.Magnitude > 0.1 then
                dir = dir.Unit
                local wp = myHRP.Position + dir * 8
                myHum:MoveTo(Vector3.new(wp.X, myHRP.Position.Y, wp.Z))
            end
        end
    end
end)

print("[Nyx] Human behavior build loaded ❤️")
