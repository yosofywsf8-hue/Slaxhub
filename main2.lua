-- Blade Ball - Ultimate Slax Hub (Full Features & Auto Parry)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball Ultimate",
    SubTitle = "Professional Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 380),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Combat / Parry", Icon = "sword" }),
    Visuals = Window:AddTab({ Title = "Visuals (ESP)", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options
local autoParryEnabled = false
local autoSpamEnabled = false
local ballEspEnabled = false
local capturedRemote = nil

-- إشعار التوجيه الأولي
Fluent:Notify({
    Title = "Slax Hub Loaded",
    Content = "Press Parry manually ONCE to link the remote!",
    Duration = 6
})

-- التقاط الـ Remote الحقيقي بطريقة ذكية وآمنة
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" and self:IsA("RemoteEvent") then
        local name = string.lower(self.Name)
        if string.find(name, "parry") or string.find(name, "block") or string.find(name, "deflect") or string.find(name, "hit") then
            if not capturedRemote then
                capturedRemote = self
                Fluent:Notify({
                    Title = "Success!",
                    Content = "Parry Remote Linked Successfully! ✅",
                    Duration = 4
                })
            end
        end
    end
    return oldNamecall(self, ...)
end)

-- نافذة القتال والصد التلقائي
Tabs.Main:AddParagraph({
    Title = "Instruction",
    Content = "1. Click Parry manually once in-game.\n2. Enable Auto Parry below."
})

local ToggleParry = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry (Smart)",
    Default = false
})

ToggleParry:OnChanged(function()
    autoParryEnabled = Options.AutoParryToggle.Value
end)

local ToggleSpam = Tabs.Main:AddToggle("AutoSpamToggle", {
    Title = "Auto Spam (Clash Mode)",
    Default = false
})

ToggleSpam:OnChanged(function()
    autoSpamEnabled = Options.AutoSpamToggle.Value
end)

-- نافذة الرؤية (ESP) للكرة
Tabs.Visuals:AddToggle("BallEspToggle", {
    Title = "Ball ESP & Tracer",
    Default = false
}):OnChanged(function()
    ballEspEnabled = Options.BallEspToggle.Value
end)

-- حلقة الأداء العالي (بدون دروب فريم) لمعالجة الصد والتصدي التلقائي
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        
        for _, ball in pairs(workspace:GetChildren()) do
            if ball.Name == "Ball" and ball:IsA("BasePart") then
                local dist = (root.Position - ball.Position).Magnitude
                local vel = ball.AssemblyLinearVelocity.Magnitude
                
                -- نظام الـ Auto Parry المتقدم
                if autoParryEnabled and capturedRemote then
                    if vel > 0 then
                        local timeToReach = dist / vel
                        if timeToReach <= 0.38 or dist <= 19 then
                            capturedRemote:FireServer()
                        end
                    end
                end
                
                -- نظام الـ Auto Spam (السبام عند الاقتراب الشديد أو الاشتباك)
                if autoSpamEnabled and capturedRemote then
                    if dist <= 12 then
                        capturedRemote:FireServer()
                        task.wait(0.02)
                    end
                end
                
                -- نظام الـ ESP البسيط للكرة
                if ballEspEnabled then
                    if not ball:FindFirstChild("SlaxHighlight") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "SlaxHighlight"
                        hl.FillColor = Color3.fromRGB(255, 50, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = ball
                    end
                else
                    if ball:FindFirstChild("SlaxHighlight") then
                        ball.SlaxHighlight:Destroy()
                    end
                end
            end
        end
    end)
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Ready",
    Content = "All systems operational!",
    Duration = 3
})
