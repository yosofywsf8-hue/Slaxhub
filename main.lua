-- ================================================================
-- Timebomb Duels | Assist — Stops on Pass
-- Nyx | يتوقف لحظة التسليم
-- ================================================================

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============ الإعدادات ============
local CONFIG = {
    RUN_TIME      = 3.0,     -- حد أقصى للملاحقة (احتياطي)
    TICK          = 0.15,
    TOUCH_RANGE   = 3.8,
    JITTER        = 0.06,
    HOLD_AT_TOUCH = 0.4,     -- وقت انتظار عند التلامس قبل ما يقرر
    KEYBIND       = Enum.KeyCode.G,
}

local active = false

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

local function getNearestTarget()
    local myHRP = getHRP()
    if not myHRP then return nil end
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hum = getHumanoid(plr)
            local hrp = getHRP(plr)
            if hum and hrp and hum.Health > 0 then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < dist then closest, dist = plr, d end
            end
        end
    end
    return closest
end

local function jitter(v)
    return v + Vector3.new(
        (math.random() - 0.5) * CONFIG.JITTER, 0,
        (math.random() - 0.5) * CONFIG.JITTER
    )
end

-- ============ المنطق — يتوقف أول ما تعطي القنبلة ============
local function runOnce()
    if active then return end

    -- تأكد إن عندك القنبلة قبل ما تبدأ
    if not hasBomb() then return end

    active = true
    local startTime = os.clock()
    local touchStartTime = nil   -- وقت بداية التلامس

    local function stop()
        active = false
        local myHum = getHumanoid()
        if myHum then
            myHum:MoveTo(getHRP().Position)  -- يوقف فوراً
        end
    end

    local function tick()
        if not active then return end

        -- 1) فحص: هل لسا عندي القنبلة؟
        -- إذا لا → التسليم صار → وقف فوراً
        if not hasBomb() then
            stop()
            return
        end

        -- 2) فحص الوقت الأقصى (احتياطي عشان ما يظل شغال للأبد)
        if os.clock() - startTime >= CONFIG.RUN_TIME then
            stop()
            return
        end

        -- 3) فحص الجسم
        local myHRP = getHRP()
        local myHum = getHumanoid()
        if not myHRP or not myHum or myHum.Health <= 0 then
            stop()
            return
        end

        -- 4) الهدف
        local target = getNearestTarget()
        if not target then
            stop()
            return
        end

        local thrp = getHRP(target)
        if not thrp then
            stop()
            return
        end

        local dist = (thrp.Position - myHRP.Position).Magnitude

        -- 5) وصلنا لمسافة التلامس؟
        if dist <= CONFIG.TOUCH_RANGE then
            -- نوقف الحركة، نخلي الـ TouchTransmitter يسوي شغله
            myHum:MoveTo(myHRP.Position)
            myHRP.CFrame = CFrame.lookAt(myHRP.Position, thrp.Position)

            -- نبدأ عداد التلامس
            if not touchStartTime then
                touchStartTime = os.clock()
            end

            -- إذا مر وقت كافي عند التلامس ولم تسلم بعد، نستنى شوي زيادة
            -- إذا التسليم صار، الفحص #1 فوق راح يوقفه
            if os.clock() - touchStartTime > CONFIG.HOLD_AT_TOUCH then
                -- نستمر في التلامس (بدون حركة) لين ما التسليم يصير
                -- أو ينتهي RUN_TIME
            end
        else
            -- نلحق
            touchStartTime = nil
            local dir = (jitter(thrp.Position) - myHRP.Position)
            if dir.Magnitude > 0.1 then
                dir = dir.Unit
                local wp = myHRP.Position + dir * 8
                myHum:MoveTo(Vector3.new(wp.X, myHRP.Position.Y, wp.Z))
            end
        end

        task.delay(CONFIG.TICK, tick)
    end

    task.delay(CONFIG.TICK, tick)
end

-- ============ الزرار ============
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CONFIG.KEYBIND then
        runOnce()
    end
end)

-- ============ زر على الشاشة (للجوال) ============
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("NyxAssistBtn")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "NyxAssistBtn"
sg.ResetOnSpawn = false
sg.Parent = parentGui

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 60, 0, 60)
btn.Position = UDim2.new(0, 30, 0.5, -30)
btn.BackgroundColor3 = Color3.fromRGB(60, 40, 70)
btn.BackgroundTransparency = 0.35
btn.Text = "G"
btn.TextColor3 = Color3.fromRGB(230, 210, 240)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 20
btn.BorderSizePixel = 0
btn.Active = true
btn.Draggable = true
btn.Parent = sg
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

-- تأثير بصري لما يشتغل
local function setBtnState(on)
    btn.BackgroundColor3 = on and Color3.fromRGB(160, 90, 190)
                                or Color3.fromRGB(60, 40, 70)
    btn.Text = on and "…" or "G"
end

local oldRun = runOnce
runOnce = function()
    if active then return end
    if not hasBomb() then
        -- ما عندك قنبلة، ما يشتغل
        return
    end
    setBtnState(true)
    oldRun()
    -- نراقب متى يخلص
    task.spawn(function()
        while active do task.wait(0.1) end
        setBtnState(false)
    end)
end

btn.MouseButton1Click:Connect(function()
    runOnce()
end)

print("[Nyx] Assist loaded — يوقف فوراً لما يعطي القنبلة ❤️")
