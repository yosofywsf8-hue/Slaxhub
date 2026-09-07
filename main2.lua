-- Blade Ball - God Mode Ultra Auto Parry by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball GOD MODE",
    SubTitle = "Ultra Fast Auto Parry",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "sword" })
}

local Options = Fluent.Options
local autoParryEnabled = false

-- البحث المباشر عن زر الصد في كل مكان باللعبة
local function getParryRemote()
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (string.lower(v.Name) == "parrybuttonpress" or string.lower(v.Name) == "parry") then
            return v
        end
    end
    return nil
end

Tabs.Main:AddParagraph({
    Title = "Status",
    Content = "God Mode Active! Just turn on Auto Parry and let it destroy."
})

local ToggleParry = Tabs.Main:AddToggle("GodParryToggle", {
    Title = "⚡ ULTIMATE AUTO PARRY",
    Default = false
})

ToggleParry:OnChanged(function()
    autoParryEnabled = Options.GodParryToggle.Value
    Fluent:Notify({
        Title = "Auto Parry",
        Content = autoParryEnabled and "GOD MODE ON! 🟢" : "Deactivated! 🔴",
        Duration = 2
    })
end)

-- حلقة الاستجابة الفائقة (أقوى أداء ممكن بدون دروب فريم)
RunService.Heartbeat:Connect(function()
    if not autoParryEnabled then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        local remote = getParryRemote()
        
        if not remote then return end
        
        for _, ball in pairs(workspace:GetChildren()) do
            if (ball.Name == "Ball" or string.find(string.lower(ball.Name), "ball")) and ball:IsA("BasePart") then
                local distance = (root.Position - ball.Position).Magnitude
                local velocity = ball.AssemblyLinearVelocity.Magnitude
                
                -- الحساب الفائق للوقت والمسافة لتنفيذ الصد في أجزاء من الثانية
                if velocity > 0 then
                    local timeToReach = distance / velocity
                    if timeToReach <= 0.5 or distance <= 25 then
                        remote:FireServer()
                    end
                end
            end
        end
    end)
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Slax Hub",
    Content = "Ultimate Script Loaded!",
    Duration = 3
})
