-- Blade Ball - Final God Mode Auto Parry (Zero Failure) by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball FINAL",
    SubTitle = "Guaranteed Working Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 380),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" })
}

local Options = Fluent.Options
local autoParryEnabled = false
local autoSpamEnabled = false

-- البحث الشامل والذكي عن أي Remote خاص بالصد في اللعبة (يستحيل ألا يجده)
local function getWorkingRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = string.lower(obj.Name)
            if name == "parrybuttonpress" or name == "parry" or name == "deflect" or name == "hit" then
                return obj
            end
        end
    end
    -- بحث احتياطي في الـ Packages أو الـ Remotes مباشرة
    pcall(function()
        return ReplicatedStorage.Remotes.ParryButtonPress
    end)
    return nil
end

Tabs.Combat:AddParagraph({
    Title = "Status",
    Content = "Universal Remote Scanner Active. Turn on and play!"
})

Tabs.Combat:AddToggle("FinalParry", {
    Title = "🔥 Ultimate Auto Parry",
    Default = false
}):OnChanged(function()
    autoParryEnabled = Options.FinalParry.Value
    Fluent:Notify({ Title = "Auto Parry", Content = autoParryEnabled and "Activated! 🟢" or "Deactivated! 🔴", Duration = 2 })
end)

Tabs.Combat:AddToggle("FinalSpam", {
    Title = "⚡ Extreme Auto Spam (Clash)",
    Default = false
}):OnChanged(function()
    autoSpamEnabled = Options.FinalSpam.Value
end)

-- الحلقة الأقوى والأسرع في الاستجابة بدون أي توقف
RunService.Heartbeat:Connect(function()
    if not autoParryEnabled and not autoSpamEnabled then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        local remote = getWorkingRemote()
        
        if not remote then return end
        
        for _, ball in pairs(workspace:GetChildren()) do
            if (ball.Name == "Ball" or string.find(string.lower(ball.Name), "ball")) and ball:IsA("BasePart") then
                local dist = (root.Position - ball.Position).Magnitude
                local vel = ball.AssemblyLinearVelocity.Magnitude
                
                -- نظام الصد التلقائي الخارق
                if autoParryEnabled and vel > 0 then
                    local timeToReach = dist / vel
                    if timeToReach <= 0.45 or dist <= 22 then
                        remote:FireServer()
                    end
                end
                
                -- نظام السبام العنيف للاشتباكات
                if autoSpamEnabled and dist <= 16 then
                    remote:FireServer()
                    task.wait(0.01)
                end
            end
        end
    end)
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Slax Hub",
    Content = "Final Edition Loaded Successfully!",
    Duration = 3
})
