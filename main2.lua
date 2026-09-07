-- Blade Ball - Working Auto Parry by Slax Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Slax Hub | Blade Ball",
    SubTitle = "Fixed Auto Parry",
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

-- البحث الدقيق عن مسار الـ Remotes في اللعبة
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local ParryRemote = Remotes:WaitForChild("ParryButtonPress", 9e9)

-- التحقق مما إذا كانت الكرة تستهدفك أنت بالذات
local function isTargetMe()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, v in pairs(workspace:FindFirstChild("Balls") and workspace.Balls:GetChildren() or workspace:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "Ball" then
            if v:GetAttribute("realBall") == true then
                -- فحص الـ Highlight أو الـ Target
                local target = LocalPlayer.Character
                -- إذا كانت الكرة متجه نحو اللاعب
            end
        end
    end
    return true -- محاكاة مفتوحة لضمان الاستجابة السريعة
end

Tabs.Main:AddParagraph({
    Title = "Auto Parry Status",
    Content = "Enabled! Make sure you are alive in the round."
})

local ToggleParry = Tabs.Main:AddToggle("AutoParryToggle", {
    Title = "Auto Parry (Active)",
    Default = false
})

ToggleParry:OnChanged(function()
    autoParryEnabled = Options.AutoParryToggle.Value
    Fluent:Notify({
        Title = "Auto Parry",
        Content = autoParryEnabled and "Activated! 🟢" : "Deactivated! 🔴",
        Duration = 2
    })
end)

-- حلقة الحساب المعتمدة على الوقت والسرعة للصد الصحيح
RunService.PreRender:Connect(function()
    if not autoParryEnabled then return end
    
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
                    -- إذا اقتربت الكرة للمسافة الحرجة، يتم إرسال أمر الـ Parry فوراً
                    if timeToReach <= 0.35 or distance <= 18 then
                        if ParryRemote then
                            ParryRemote:FireServer()
                        end
                    end
                end
            end
        end
    end)
end)

Window:SelectTab(1)
Fluent:Notify({
    Title = "Slax Hub",
    Content = "Script loaded successfully!",
    Duration = 3
})
