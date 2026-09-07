-- Blade Ball - Smart Auto Parry & Spam (Fluent UI) by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball",
    SubTitle = "Smart Parry & Spam",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" })
}

local Options = Fluent.Options
local autoParryEnabled = false
local capturedRemote = nil

-- إشعار توجيهي للمستخدم لتنفيذ الصد اليدوي أولاً
Fluent:Notify({
    Title = "Important Instruction",
    Content = "Press Parry manually ONCE to hook the remote, then turn on Auto Parry!",
    Duration = 6
})

Tabs.Main:AddParagraph({
    Title = "Status Guide",
    Content = "1. Press Parry manually in-game once.\n2. Status will show 'Connected'.\n3. Enable Auto Parry toggle below."
})

local StatusToggle = Tabs.Main:AddParagraph({
    Title = "Connection Status",
    Content = "Remote Hooked: ❌ (Waiting for manual parry)"
})

local ToggleParry = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry / Spam",
    Default = false
})

ToggleParry:OnChanged(function()
    autoParryEnabled = Options.AutoParryToggle.Value
    if autoParryEnabled and not capturedRemote then
        Fluent:Notify({
            Title = "Warning",
            Content = "Please press Parry manually first so the script can hook the remote!",
            Duration = 4
        })
    end
end)

-- التقاط الـ Remote تلقائياً عند أول ضغطة يدويّة يقوم بها اللاعب (نفس فكرة الفيديو)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" and self:IsA("RemoteEvent") then
        local name = string.lower(self.Name)
        if string.find(name, "parry") or string.find(name, "block") or string.find(name, "hit") or string.find(name, "deflect") then
            if not capturedRemote then
                capturedRemote = self
                StatusToggle:SetDesc("Remote Hooked: ✅ (Ready to auto-parry)")
                Fluent:Notify({
                    Title = "Success",
                    Content = "Parry Remote Hooked Successfully!",
                    Duration = 3
                })
            end
        end
    end
    return oldNamecall(self, ...)
end)

-- حلقة الصد التلقائي الذكية بناءً على مسافة الكرة وسرعتها
RunService.PreRender:Connect(function()
    if not autoParryEnabled or not capturedRemote then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        
        for _, ball in pairs(workspace:GetChildren()) do
            if ball.Name == "Ball" and ball:IsA("BasePart") then
                local distance = (root.Position - ball.Position).Magnitude
                local velocity = ball.AssemblyLinearVelocity.Magnitude
                
                if velocity > 0 then
                    local timeToReach = distance / velocity
                    -- المسافة الحرجة أو الوقت للصد مثل نظام الفيديو
                    if timeToReach <= 0.4 or distance <= 20 then
                        capturedRemote:FireServer()
                    end
                end
            end
        end
    end)
end)

Window:SelectTab(1)
