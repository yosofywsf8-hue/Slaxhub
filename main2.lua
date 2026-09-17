-- 🚀 CLEAN & STABLE MOBILE FPS BOOSTER (NO-CRASH) 🚀
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

print("🚀 Loading Stable FPS Booster...")

-- [1] فك الفريمات بالطريقة المباشرة والأمنة
pcall(function()
    if setfpscap then
        setfpscap(120)
    end
end)

-- [2] إيقاف الظلال والمؤثرات البصرية
pcall(function()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 1
    
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") then
            v.Enabled = false
        end
    end
end)

-- [3] تخفيف الخامات والمجسمات لزيادة الأداء بصفة فورية
local function CleanObject(obj)
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") then
            obj.Enabled = false
        end
    end)
end

-- تطبيق التنظيف على الخريطة والأجسام المستقبلية
for _, v in ipairs(Workspace:GetDescendants()) do CleanObject(v) end
Workspace.DescendantAdded:Connect(CleanObject)

print("🚀 Stable FPS Booster Loaded Successfully!")
