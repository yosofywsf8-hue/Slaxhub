
-- ☢️ ULTIMATE NUCLEAR FPS BOOSTER & FFLAG ENGINE ☢️
-- Developed by: HackerGPT AI (Max Override Mode)
-- ⚠️ WARNING: This will make the game look terrible but run at lightspeed.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local MaterialService = game:GetService("MaterialService")
local player = Players.LocalPlayer

print("☢️ INITIATING NUCLEAR FPS BOOST...")

-- [1] فتح قفل الفريمات (FPS Unlocker)
pcall(function()
    if setfpscap then
        setfpscap(999) -- فتح الفريمات لأقصى حد
    end
end)

-- [2] تعديل محرك روبلوكس العميق (FFlags Override)
-- تحذير: تعمل فقط على بعض الإكسبلويترز (مثل Delta/Arceus) التي تدعم setfflag
local fflags = {
    {"FFlagDebugDisableGlobalShadows", "True"}, -- إغلاق الظلال من الجذور
    {"FIntRenderShadowmapBias", "0"},
    {"FIntRenderShadowIntensity", "0"},
    {"FIntTaskSchedulerTargetFps", "9999"}, -- رفع هدف معالجة الإطارات
    {"DFIntTextureCompositorActive", "0"}, -- تقليل معالجة التكسرتشرز
    {"FFlagDisablePostFx", "True"}, -- إغلاق الفلاتر
    {"DFIntCSGLevelOfDetailSwitchingDistance", "0"},
    {"DFIntCSGLevelOfDetailSwitchingDistanceL12", "0"},
    {"DFIntCSGLevelOfDetailSwitchingDistanceL23", "0"},
    {"DFIntCSGLevelOfDetailSwitchingDistanceL34", "0"}
}

for _, flag in ipairs(fflags) do
    pcall(function()
        if setfflag then
            setfflag(flag[1], flag[2])
        end
    end)
end

-- [3] التلاعب بخصائص اللعبة المخفية (Hidden Properties)
pcall(function()
    -- إجبار اللعبة على استخدام تقنية إضاءة قديمة جداً (Compatibility/Voxel)
    if sethiddenproperty then
        sethiddenproperty(Lighting, "Technology", 2)
        sethiddenproperty(Terrain, "Decoration", false)
    end
    
    -- إجبار اللعبة على جودة (Level 1) من الداخل
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
end)

-- [4] تدمير شامل لكل ما يستهلك الرامات وكارت الشاشة (Nuclear Cleanup)
local function NuclearOptimization(obj)
    if obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
        if obj.Transparency < 1 then
            -- تخفيف ألوان الأجزاء (اختياري، يقلل معالجة الألوان المزدوجة)
            obj.Color = Color3.new(0.5, 0.5, 0.5) 
        end
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1 -- إخفاء الصور الملصقة
        pcall(function() obj:Destroy() end) -- تدميرها إذا أمكن
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        obj.Enabled = false
        pcall(function() obj:Destroy() end)
    elseif obj:IsA("MeshPart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
        obj.TextureID = "" -- مسح الـ Texture للـ Meshes
    elseif obj:IsA("PostEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") then
        obj.Enabled = false
        pcall(function() obj:Destroy() end)
    elseif obj:IsA("Atmosphere") or obj:IsA("Sky") or obj:IsA("Clouds") then
        pcall(function() obj:Destroy() end) -- حذف السماء والغيوم بالكامل
    end
end

-- تطبيق التدمير على كل الموجود في الماب حالياً
for _, v in ipairs(Workspace:GetDescendants()) do
    NuclearOptimization(v)
end
for _, v in ipairs(Lighting:GetDescendants()) do
    NuclearOptimization(v)
end

-- تطبيق التدمير على أي شيء جديد يترسبط في اللعبة (لضمان بقاء اللاق معدوماً)
Workspace.DescendantAdded:Connect(NuclearOptimization)
Lighting.DescendantAdded:Connect(NuclearOptimization)

-- [5] تدمير التضاريس والماء
pcall(function()
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
        Terrain:Clear() -- (تحذير: هذا السطر قد يحذف التضاريس في بعض الألعاب، امسحه لو اختفت الأرضية تماماً)
    end
end)

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 1
    MaterialService.Use2022Materials = false -- إيقاف خامات روبلوكس الجديدة الثقيلة
end)

-- [6] واجهة تتبع للفريمات المهكرة
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NuclearFPS"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 160, 0, 30)
fpsLabel.Position = UDim2.new(0.02, 0, 0.02, 0)
fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- لون أحمر نووي
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 14
fpsLabel.Text = "☢️ OVERRIDE FPS: ..."
fpsLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = fpsLabel

local lastUpdate = tick()
local frames = 0

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    local now = tick()
    if now - lastUpdate >= 1 then
        local fps = math.floor(frames / (now - lastUpdate))
        fpsLabel.Text = "☢️ FPS: " .. tostring(fps) .. " (MAX)"
        frames = 0
        lastUpdate = now
    end
end)

print("☢️ NUCLEAR ENGINE ACTIVE! FPS CAPPED AT INF. GRAHPICS AT POTATO.")
