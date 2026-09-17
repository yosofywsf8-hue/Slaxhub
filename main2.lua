-- 🚀 120Hz FPS BOOSTER (LOW PING & NETWORK SAFE) 🚀
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

print("🚀 Restoring Network & Optimizing FPS Safely...")

-- [1] FFlags آمنة للـ FPS فقط دون التلاعب بالشبكة أو البنج
pcall(function()
    local SafeFlags = {
        {"TaskSchedulerTargetFps", "120"},
        {"FIntTargetFps", "120"},
        {"GameBasicSettingsFramerateCap5", "False"},
        
        -- إيقاف التنازل الحراري والبطارية
        {"FFlagEnableMobileThermalThrottling", "False"},
        {"FFlagEnableMobileBatterySavingMode", "False"},
        
        -- تخفيف الجرافيكس والـ Telemetry
        {"TextureQualityOverrideEnabled", "True"},
        {"TextureQualityOverride", "0"},
        {"DisableDPIScale", "True"},
        {"BrowserTrackerIdTelemetryEnabled", "False"},
        {"DisableFastLogTelemetry", "True"}
    }

    for _, flag in ipairs(SafeFlags) do
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

-- [2] تخفيف جرافيكس الشخصية والأجسام لتخفيف العبء على المعالج
local function LowGraphicObj(obj)
    if obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") then
        obj.Enabled = false
    end
end

for _, v in ipairs(Workspace:GetDescendants()) do LowGraphicObj(v) end
Workspace.DescendantAdded:Connect(LowGraphicObj)

-- [3] تنظيف الذاكرة الخفيف
task.spawn(function()
    while task.wait(30) do
        pcall(function()
            collectgarbage("collect")
        end)
    end
end)

print("🚀 Network Restored! Ping should return to normal now.")
