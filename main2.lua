-- ============================================================
-- Blade Ball — MANUAL-TEACH AUTO-PARRY
-- Lu parry manual beberapa kali, hook rekam timing-nya,
-- abis itu autoparry pakai timing yang lu ajarin.
-- ============================================================

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP  = Char:WaitForChild("HumanoidRootPart")

Char.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    enabled       = false,   -- autoparry baru nyala setelah belajar
    teachTarget   = 5,       -- berapa parry manual buat "lulus"
    parryWindow   = 0.18,    -- default, akan di-override hasil belajar
    cooldown      = 0.15,
    maxDist       = 60,
    minSpeed      = 40,
    useLearned    = true,    -- pakai timing hasil belajar
}

local Learn = {
    samples   = {},          -- TTI saat lu parry manual
    done      = false,
}

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local parryRemote = nil
local function scanRemotes()
    parryRemote = nil
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("parry") or n:find("block") or n:find("deflect") then
                parryRemote = v
                return
            end
        end
    end
end
scanRemotes()

-- ============================================================
-- DETECT MANUAL PARRY
-- Hook FireServer di remote parry.
-- Kalau LP kirim parry TANPA autoparry aktif → itu manual.
-- ============================================================
local learning = false

local function installParryHook()
    if not parryRemote then scanRemotes() end
    if not parryRemote then return end

    local mt = getrawmetatable(parryRemote)
    if mt and not mt.__teach_hooked then
        local oldIdx = mt.__index
        mt.__index = newcclosure(function(t, k)
            if k == "FireServer" then
                return newcclosure(function(_, ...)
                    if learning and not CFG.enabled then
                        -- manual parry terdeteksi → rekam TTI sekarang
                        if Stats.currentTTI and Stats.currentTTI < math.huge then
                            table.insert(Learn.samples, Stats.currentTTI)
                            if #Learn.samples >= CFG.teachTarget then
                                Learn.done = true
                                learning = false
                                CFG.enabled = true
                                -- hitung rata-rata TTI parry manual
                                local sum = 0
                                for _, v in ipairs(Learn.samples) do sum = sum + v end
                                CFG.parryWindow = sum / #Learn.samples
                                print(string.format(
                                    "[TEACH] belajar selesai. parry window = %.3f (%d sampel)",
                                    CFG.parryWindow, #Learn.samples
                                ))
                            end
                        end
                    end
                    return oldIdx(t, k)(t, ...)
                end)
            end
            return oldIdx(t, k)
        end)
        mt.__teach_hooked = true
    end
end
installParryHook()

-- ============================================================
-- BALL TRACKING (dipakai buat rekam + trigger)
-- ============================================================
Stats = Stats or {}
Stats.currentTTI = math.huge

local function getBalls()
    local c = WS:FindFirstChild("Balls") or WS:FindFirstChild("Ball")
    return c and c:GetChildren() or {}
end

local function timeToImpact(ballPos, ballVel, myPos)
    local toMe = myPos - ballPos
    local dist = toMe.Magnitude
    if dist > CFG.maxDist then return math.huge end
    local speed = ballVel.Magnitude
    if speed < CFG.minSpeed then return math.huge end
    local closing = ballVel:Dot(toMe.Unit)
    if closing <= 0 then return math.huge end
    return dist / closing
end

RunService.RenderStepped:Connect(function()
    if not HRP or not HRP.Parent then return end
    local myPos = HRP.Position
    local best = math.huge
    for _, ball in ipairs(getBalls()) do
        if ball:IsA("BasePart") then
            local t = timeToImpact(ball.Position, ball.AssemblyLinearVelocity, myPos)
            if t < best then best = t end
        end
    end
    Stats.currentTTI = best
end)

-- ============================================================
-- AUTOPARRY TRIGGER
-- ============================================================
local lastParry = 0

local function fireParry()
    if not parryRemote then scanRemotes() end
    if not parryRemote then return end
    pcall(function() parryRemote:FireServer() end)
end

RunService.RenderStepped:Connect(function()
    if not CFG.enabled then return end
    local now = tick()
    if now - lastParry < CFG.cooldown then return end
    if Stats.currentTTI <= CFG.parryWindow then
        fireParry()
        lastParry = now
    end
end)

-- ============================================================
-- UI
-- ============================================================
local function make(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local gui = make("ScreenGui", {
    Name = "TeachParry",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, {})
local ok = pcall(function() gui.Parent = CoreGui end)
if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = make("Frame", {
    Size = UDim2.new(0, 300, 0, 280),
    Position = UDim2.new(0.05, 0, 0.3, 0),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, {})
main.Parent = gui
make("UICorner", {CornerRadius = UDim.new(0, 10)}, {}).Parent = main
make("UIStroke", {Color = Color3.fromRGB(60, 60, 70)}, {}).Parent = main

local title = make("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(28, 28, 34),
    BorderSizePixel = 0,
}, {})
title.Parent = main
make("UICorner", {CornerRadius = UDim.new(0, 10)}, {}).Parent = title

make("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "TEACH AUTO-PARRY",
    TextColor3 = Color3.fromRGB(255, 90, 90),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = title

local close = make("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0, 6),
    BackgroundColor3 = Color3.fromRGB(45, 45, 55),
    Text = "X",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, {})
close.Parent = title
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = close
close.MouseButton1Click:Connect(function() gui.Enabled = false end)

local content = make("Frame", {
    Size = UDim2.new(1, -20, 1, -56),
    Position = UDim2.new(0, 10, 0, 46),
    BackgroundTransparency = 1,
}, {})
content.Parent = main
make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, {}).Parent = content

-- Teach count input
local teachRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Color3.fromRGB(26, 26, 32),
    BorderSizePixel = 0,
    LayoutOrder = 1,
}, {})
teachRow.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = teachRow

make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18),
    Position = UDim2.new(0, 10, 0, 4),
    BackgroundTransparency = 1,
    Text = "Parry manual yang dibutuhin:",
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, {}).Parent = teachRow

local countLabel = make("TextLabel", {
    Size = UDim2.new(0, 60, 0, 30),
    Position = UDim2.new(0, 10, 0, 22),
    BackgroundColor3 = Color3.fromRGB(40, 40, 50),
    Text = tostring(CFG.teachTarget),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, {})
countLabel.Parent = teachRow
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = countLabel

local minus = make("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(0, 78, 0, 22),
    BackgroundColor3 = Color3.fromRGB(50, 50, 60),
    Text = "-",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, {})
minus.Parent = teachRow
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = minus

local plus = make("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(0, 114, 0, 22),
    BackgroundColor3 = Color3.fromRGB(50, 50, 60),
    Text = "+",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, {})
plus.Parent = teachRow
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = plus

minus.MouseButton1Click:Connect(function()
    if CFG.enabled then return end
    CFG.teachTarget = math.max(1, CFG.teachTarget - 1)
    countLabel.Text = tostring(CFG.teachTarget)
end)
plus.MouseButton1Click:Connect(function()
    if CFG.enabled then return end
    CFG.teachTarget = math.min(50, CFG.teachTarget + 1)
    countLabel.Text = tostring(CFG.teachTarget)
end)

-- Start teach button
local startBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(60, 200, 100),
    Text = "MULAI BELAJAR",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BorderSizePixel = 0,
    LayoutOrder = 2,
}, {})
startBtn.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = startBtn

local statusLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    Text = "Status: idle",
    TextColor3 = Color3.fromRGB(180, 180, 200),
    Font = Enum.Font.Code,
    TextSize = 11,
    BorderSizePixel = 0,
    LayoutOrder = 3,
}, {})
statusLabel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = statusLabel

-- Learned info
local learnedLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    Text = "Belajar: 0/0 | Window: -",
    TextColor3 = Color3.fromRGB(180, 180, 200),
    Font = Enum.Font.Code,
    TextSize = 11,
    BorderSizePixel = 0,
    LayoutOrder = 4,
}, {})
learnedLabel.Parent = content
make("UICorner", {CornerRadius = UDim.new(0, 6)}, {}).Parent = learnedLabel

startBtn.MouseButton1Click:Connect(function()
    if CFG.enabled then
        CFG.enabled = false
        Learn.samples = {}
        Learn.done = false
        startBtn.Text = "MULAI BELAJAR"
        startBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        statusLabel.Text = "Status: idle"
        learnedLabel.Text = "Belajar: 0/0 | Window: -"
        return
    end
    Learn.samples = {}
    Learn.done = false
    learning = true
    CFG.enabled = false
    startBtn.Text = "BATAL BELAJAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    statusLabel.Text = "Status: rekam parry manual lu..."
end)

-- Update loop UI
task.spawn(function()
    while gui.Parent do
        if learning then
            statusLabel.Text = string.format("Status: rekam %d/%d manual parry",
                #Learn.samples, CFG.teachTarget)
            learnedLabel.Text = string.format("Belajar: %d/%d | Window: -",
                #Learn.samples, CFG.teachTarget)
        elseif CFG.enabled then
            statusLabel.Text = "Status: AUTO-PARRY ON"
            learnedLabel.Text = string.format("Belajar: selesai (%d) | Window: %.3f",
                #Learn.samples, CFG.parryWindow)
        else
            statusLabel.Text = "Status: idle"
        end
        task.wait(0.1)
    end
end)

print("[TEACH AUTO-PARRY] loaded")
