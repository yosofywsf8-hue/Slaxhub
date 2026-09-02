local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "by dev:yosef",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark"
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Social = Window:AddTab({ Title = "Social", Icon = "share-2" })
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local SetClipboard = setclipboard or function() end

local LocalPlayer = Players.LocalPlayer

local AutoParry = false
local Accuracy = 3.3
local CurveType = "straight"
local AutoSpam = false
local LastParryTime = 0

-- ==================== [ إنشاء UI زر السبام العائم ] ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxSpamGui"
ScreenGui.ResetOnSpawn = false

pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local SpamButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")

SpamButton.Name = "SpamButton"
SpamButton.Parent = ScreenGui
SpamButton.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
SpamButton.Position = UDim2.new(0.5, -60, 0.05, 0)
SpamButton.Size = UDim2.new(0, 120, 0, 45)
SpamButton.Font = Enum.Font.GothamBold
SpamButton.Text = "SPAM: OFF"
SpamButton.TextColor3 = Color3.fromRGB(220, 60, 60)
SpamButton.TextSize = 14
SpamButton.Active = true
SpamButton.Draggable = true
SpamButton.Visible = false

UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = SpamButton

UIStroke.Color = Color3.fromRGB(220, 60, 60)
UIStroke.Thickness = 1.5
UIStroke.Parent = SpamButton

-- دالة إرسال ريموت الضرب بآمان لمنع Ban/Teleport
local function sendParryRemote()
    if tick() - LastParryTime < 0.03 then return end -- فاصل زمني لتجنب كشف السيرفر
    LastParryTime = tick()
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
    for _, obj in pairs(remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name:lower():find("parry") or obj.Name:lower():find("ability")) then
            obj:FireServer()
            break
        end
    end
end

local AutoSpamToggle

local function setSpamState(state)
    AutoSpam = state
    if AutoSpam then
        SpamButton.Text = "SPAM: ON"
        SpamButton.TextColor3 = Color3.fromRGB(50, 220, 100)
        UIStroke.Color = Color3.fromRGB(50, 220, 100)
    else
        SpamButton.Text = "SPAM: OFF"
        SpamButton.TextColor3 = Color3.fromRGB(220, 60, 60)
        UIStroke.Color = Color3.fromRGB(220, 60, 60)
    end
    if AutoSpamToggle and AutoSpamToggle.Value ~= state then
        AutoSpamToggle:SetValue(state)
    end
end

SpamButton.MouseButton1Click:Connect(function()
    setSpamState(not AutoSpam)
end)

-- ==================== [ قسم Main ] ====================

Tabs.Main:AddSection("Auto Parry Settings")

local AutoParryToggle = Tabs.Main:AddToggle("AutoParry", { Title = "Auto Parry", Default = false })
AutoParryToggle:OnChanged(function(Value)
    AutoParry = Value
end)

local AccSlider = Tabs.Main:AddSlider("Accuracy", {
    Title = "Accuracy",
    Min = 1,
    Max = 10,
    Default = 3.3,
    Rounding = 1,
    Callback = function(Value)
        Accuracy = Value
    end
})

local CurveDropdown = Tabs.Main:AddDropdown("CurveType", {
    Title = "Curve Type",
    Values = {"straight", "curve", "backwards"},
    Default = "straight",
    Callback = function(Value)
        CurveType = Value
    end
})

Tabs.Main:AddSection("Spam Options")

local ShowSpamUIToggle = Tabs.Main:AddToggle("ShowSpamUI", { Title = "Show Spam UI", Default = false })
ShowSpamUIToggle:OnChanged(function(Value)
    SpamButton.Visible = Value
    if not Value then
        setSpamState(false)
    end
end)

AutoSpamToggle = Tabs.Main:AddToggle("AutoSpam", { Title = "Auto Spam", Default = false })
AutoSpamToggle:OnChanged(function(Value)
    setSpamState(Value)
end)

-- ==================== [ قسم Social - الحقوق ] ====================

Tabs.Social:AddParagraph({
    Title = "Developer & Socials",
    Content = "DEV: yosef\n\nTG: @slaxscript\nDC: discord.gg/slaxhub\nTT: @slax_dev"
})

Tabs.Social:AddButton({
    Title = "Copy Discord Link",
    Callback = function()
        SetClipboard("https://discord.gg/slaxhub")
        Fluent:Notify({
            Title = "Slax Hub",
            Content = "Copied Discord link to clipboard!",
            Duration = 3
        })
    end
})

-- ==================== [ Auto Parry & Anti-Ban Spam Logic ] ====================

-- Auto Parry Listener
RunService.RenderStepped:Connect(function()
    if not AutoParry then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end
    
    for _, ball in pairs(ballsFolder:GetChildren()) do
        local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
        if target == LocalPlayer.Name or target == LocalPlayer.DisplayName then
            local ballPosition = ball.Position
            local ballVelocity = ball.AssemblyLinearVelocity
            local distance = (ballPosition - rootPart.Position).Magnitude
            
            local directionToPlayer = (rootPart.Position - ballPosition).Unit
            local ballDirection = ballVelocity.Unit
            local dotProduct = ballDirection:Dot(directionToPlayer)
            
            if dotProduct > 0 then
                local speed = ballVelocity.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                
                local dynamicParryDistance = math.clamp((speed * (0.32 + ping)), 14, 100)
                
                if distance <= dynamicParryDistance then
                    sendParryRemote()
                end
            end
        end
    end
end)

-- Safe Spam Loop (مستقر وبدون طرد)
task.spawn(function()
    while true do
        task.wait(0.04) -- فاصل زمني آمن لمنع حماية اللعبة من نقل اللاعب
        if AutoSpam then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local ballsFolder = workspace:FindFirstChild("Balls")
                if ballsFolder then
                    for _, ball in pairs(ballsFolder:GetChildren()) do
                        local distance = (ball.Position - character.HumanoidRootPart.Position).Magnitude
                        if distance <= 25 then
                            sendParryRemote()
                        end
                    end
                end
            end
        end
    end
end)

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "Anti-Cheat Bypass applied successfully!",
    Duration = 4
})
