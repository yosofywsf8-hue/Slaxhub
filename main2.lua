-- LocalScript
-- StarterPlayerScripts/MobileParry.client.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

local CONFIG = {
    Enabled = true,
    Range = 30,
    Cooldown = 0.12,
    MaxRange = 40,
}

local state = {
    lastParry = 0,
}

local gui = Instance.new("ScreenGui")
gui.Name = "BladeBallMobile"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(280, 190)
main.Position = UDim2.new(0, 15, 0.5, -95)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "BLADE BALL  •  MAX"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 28)
status.Position = UDim2.fromOffset(10, 48)
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.GothamBold
status.TextSize = 14
status.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -30, 0, 42)
toggle.Position = UDim2.fromOffset(15, 82)
toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Text = "AUTO PARRY"
toggle.TextSize = 15
toggle.Font = Enum.Font.GothamBold
toggle.BorderSizePixel = 0
toggle.Parent = main

Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 9)

local range = Instance.new("TextLabel")
range.Size = UDim2.new(1, -30, 0, 28)
range.Position = UDim2.fromOffset(15, 135)
range.BackgroundTransparency = 1
range.TextXAlignment = Enum.TextXAlignment.Left
range.TextColor3 = Color3.fromRGB(220, 220, 225)
range.TextSize = 14
range.Font = Enum.Font.Gotham
range.Parent = main

local function refresh()
    status.Text = CONFIG.Enabled and "STATUS: ACTIVE" or "STATUS: OFF"
    status.TextColor3 = CONFIG.Enabled
        and Color3.fromRGB(80, 255, 120)
        or Color3.fromRGB(255, 90, 90)

    range.Text = "RANGE: " .. CONFIG.Range
end

toggle.Activated:Connect(function()
    CONFIG.Enabled = not CONFIG.Enabled
    refresh()
end)

-- زر لمس لزيادة المدى
local rangeButton = Instance.new("TextButton")
rangeButton.Size = UDim2.fromOffset(45, 28)
rangeButton.Position = UDim2.new(1, -60, 0, 135)
rangeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
rangeButton.Text = "+"
rangeButton.TextColor3 = Color3.new(1, 1, 1)
rangeButton.TextSize = 18
rangeButton.Font = Enum.Font.GothamBold
rangeButton.BorderSizePixel = 0
rangeButton.Parent = main

Instance.new("UICorner", rangeButton).CornerRadius = UDim.new(0, 7)

rangeButton.Activated:Connect(function()
    CONFIG.Range = math.min(CONFIG.Range + 2, CONFIG.MaxRange)
    refresh()
end)

refresh()

-- Drag support للموبايل والماوس
local dragging = false
local dragStart
local startPos

local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = main.Position
end

local function updateDrag(input)
    if not dragging then
        return
    end

    local delta = input.Position - dragStart

    main.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        beginDrag(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Parry loop للماب الذي تملكه
RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local ball = workspace:FindFirstChild("Ball")

    if not root or not ball or not ball:IsA("BasePart") then
        return
    end

    if os.clock() - state.lastParry < CONFIG.Cooldown then
        return
    end

    if (root.Position - ball.Position).Magnitude <= CONFIG.Range then
        state.lastParry = os.clock()

        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        local parry = remotes and remotes:FindFirstChild("Parry")

        if parry and parry:IsA("RemoteEvent") then
            parry:FireServer({
                timestamp = workspace:GetServerTimeNow(),
                position = root.Position,
            })
        end
    end
end)
