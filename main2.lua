-- Blade Ball - Fluent UI Auto Parry by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball",
    SubTitle = "Auto Parry Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- المتغيرات والوظائف
local autoParryEnabled = false

local function getParryRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = string.lower(obj.Name)
            if string.find(name, "parry") or string.find(name, "ability") or string.find(name, "deflect") then
                return obj
            end
        end
    end
    return nil
end

-- واجهة التحكم داخل مكتبة Fluent
Tabs.Main:AddParagraph({
    Title = "Status Info",
    Content = "Make sure you are in a match. Toggle Auto Parry below to start."
})

local ToggleParry = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry",
    Default = false
})

ToggleParry:OnChanged(function()
    autoParryEnabled = Options.AutoParryToggle.Value
    if autoParryEnabled then
        Fluent:Notify({
            Title = "Auto Parry",
            Content = "Auto Parry Activated! 🟢",
            Duration = 3
        })
    else
        Fluent:Notify({
            Title = "Auto Parry",
            Content = "Auto Parry Deactivated! 🔴",
            Duration = 3
        })
    end
end)

-- حلقة التصدّي التلقائي (Auto Parry Loop)
task.spawn(function()
    while true do
        task.wait(0.01)
        if autoParryEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            local remote = getParryRemote()
            
            for _, ball in pairs(workspace:GetChildren()) do
                if (ball.Name == "Ball" or string.find(string.lower(ball.Name), "ball")) and ball:IsA("BasePart") then
                    local distance = (root.Position - ball.Position).Magnitude
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    local triggerDistance = math.clamp(velocity * 0.12, 14, 30)
                    
                    if distance <= triggerDistance and remote then
                        pcall(function()
                            remote:FireServer()
                        end)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "Fluent UI initialized successfully!",
    Duration = 5
})
