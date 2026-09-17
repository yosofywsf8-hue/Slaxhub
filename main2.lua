-- ☢️ ANTI-STUTTER & MOVEMENT FPS FIX (120Hz ULTRA STABLE) ☢️
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

print("☢️ Injecting Movement Optimization & Anti-Stutter Engine...")

-- [1] FFlags لمنع التقطيع عند الحركة والتضاريس
pcall(function()
    local AntiStutterFlags = {
        {"TaskSchedulerTargetFps", "120"},
        {"FIntTargetFps", "120"},
        {"GameBasicSettingsFramerateCap5", "False"},
        
        -- إيقاف التحميل الديناميكي المسبب للاق الحركة
        {"FFlagEnableMobileThermalThrottling", "False"},
        {"FFlagEnableMobileBatterySavingMode", "False"},
        {"DFIntTaskSchedulerTargetFps", "120"},
        
        -- تسريع استجابة الفيزياء ومنع التقطيع
        {"S2PhysicsSenderRate", "128"},
        {"PhysicsMemoryTelemetryHundredthsPercentage", "0"},
        {"TimestepArbiterHumanoidLinearVelThreshold", "1"},
        {"TimestepArbiterHumanoidTurningVelThreshold", "1"}
    }

    for _, flag in ipairs(AntiStutterFlags) do
        pcall(function()
            if setfflag then
                setfflag(flag[1], flag[2])
                setfflag("FFlag" .. flag[1], flag[2])
                setfflag("DFInt" .. flag[1], flag[2])
            end
        end)
    end

    if setfpscap then
        setfpscap(120)
    end
end)

-- [2] تخفيف تأثيرات الشخصية واللاعبين أثناء الحركة
local function SmoothCharacter(char)
    if not char then return end
    pcall(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Material = Enum.Material.SmoothPlastic
                part.CastShadow = false
            elseif part:IsA("Decal") or part:IsA("Texture") then
                part.Transparency = 1
            elseif part:IsA("ParticleEmitter") or part:IsA("Trail") then
                part.Enabled = false
            end
        end
    end)
end

-- تطبيق التخفيف على شخصيتك وكل اللاعبين المترسبنين
if player.Character then SmoothCharacter(player.Character) end
player.CharacterAdded:Connect(SmoothCharacter)

for _, otherPlayer in ipairs(Players:GetPlayers()) do
    if otherPlayer.Character then SmoothCharacter(otherPlayer.Character) end
    otherPlayer.CharacterAdded:Connect(SmoothCharacter)
end

-- [3] تنظيف الذاكرة تلقائياً (Garbage Collection) لمنع هبوط الفريمات المفاجئ
task.spawn(function()
    while task.wait(10) do
        pcall(function()
            collectgarbage("collect")
        end)
    end
end)

print("☢️ Movement Fix Active! Try walking now.")
