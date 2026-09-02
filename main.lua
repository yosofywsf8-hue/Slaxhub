local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Slax Hub",
    SubTitle = "by dev: yosef",
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
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- المتغيرات الأساسية
local AutoParry = false
local Accuracy = 100
local AutoSpam = false
local CurveType = "straight"

-- ==================== [ محرك الـ Parry والـ Spam ] ====================

local function triggerParry()
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
        for _, obj in ipairs(remotes:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (obj.Name:find("Parry") or obj.Name:find("parry") or obj.Name:find("Hit")) then
                obj:FireServer()
                return
            end
        end
    end)
end

local function getCurrentBall()
    local ballsFolder = workspace:FindFirstChild("Balls") or workspace
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") or ball:FindFirstChild("RealBall") or ball:GetAttribute("realBall") then
            return ball
        end
    end
    return nil
end

local function isPlayerTargeted(ball)
    if not ball then return false end
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ball:GetAttribute("realTarget")
    if target and (target == LocalPlayer.Name or target == LocalPlayer.DisplayName) then
        return true
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Highlight") then
        return true
    end
    return false
end

RunService.RenderStepped:Connect(function()
    if not (AutoParry or AutoSpam) then return end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local ball = getCurrentBall()
    
    if ball and isPlayerTargeted(ball) then
        local distance = (ball.Position - hrp.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        
        local ping = 0.05
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        
        local parryRange = math.clamp((velocity * (0.32 + ping)) * (Accuracy / 100), 14, 120)
        
        if AutoSpam and distance <= 18 then
            for i = 1, 4 do
                triggerParry()
            end
        elseif AutoParry and distance <= parryRange then
            triggerParry()
        end
    end
end)

-- ==================== [ قسم Main Tab ] ====================

Tabs.Main:AddSection("Auto Parry Settings")

local AutoParryToggle = Tabs.Main:AddToggle("AutoParry", { Title = "Auto Parry", Default = false })
AutoParryToggle:OnChanged(function(Value)
    AutoParry = Value
end)

local AccSlider = Tabs.Main:AddSlider("Accuracy", {
    Title = "Accuracy",
    Min = 1,
    Max = 100,
    Default = 100,
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

local AutoSpamToggle = Tabs.Main:AddToggle("AutoSpam", { Title = "Auto Spam", Default = false })
AutoSpamToggle:OnChanged(function(Value)
    AutoSpam = Value
end)

-- ==================== [ قسم Social Tab ] ====================

Tabs.Social:AddParagraph({
    Title = "Developer & Socials",
    Content = "DEV: yosef\n\nTG: @slaxscript\nDC: discord.gg/slaxhub\nTT: @slax_dev"
})

Tabs.Social:AddButton({
    Title = "Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/slaxhub")
        Fluent:Notify({
            Title = "Slax Hub",
            Content = "Copied Discord link to clipboard!",
            Duration = 3
        })
    end
})

Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "Fluent UI loaded with 100% Accuracy and Auto Parry Engine.",
    Duration = 4
})
