-- ☢️ 120Hz UNLOCKER & ANTI-THROTTLING OVERRIDE ☢️
pcall(function()
    local CustomFFlags = {
        -- 1. إجبار المحرك على 120 فريم بالتحديد (الأرقام الكبيرة جداً قد تسبب تراجع المحرك)
        {"TaskSchedulerTargetFps", "120"},
        {"FIntTargetFps", "120"},
        {"GameBasicSettingsFramerateCap5", "False"},

        -- 2. إيقاف الاختناق الحراري وتوفير طاقة الجوال (السبب الرئيسي للوقوف عند 96)
        {"FFlagEnableMobileThermalThrottling", "False"}, 
        {"FFlagEnableMobileBatterySavingMode", "False"},
        {"FIntMobileThermalThrottlingThreshold", "9999"},
        {"FIntTargetMethodMaxThrottlingFps", "120"},

        -- 3. تقليل حجم البفر لتسريع استجابة الشاشة (Input Lag)
        {"MaxFrameBufferSize", "2"}, 
        {"DFIntMaxFrameBufferSize", "2"},

        -- 4. إيقاف الجرافيكس وتتبع البيانات (لتخفيف الضغط على المعالج)
        {"TextureQualityOverrideEnabled", "True"},
        {"TextureQualityOverride", "0"},
        {"DFIntTextureQualityOverride", "0"},
        {"DisableDPIScale", "True"},
        {"BrowserTrackerIdTelemetryEnabled", "False"},
        {"DisableFastLogTelemetry", "True"}
    }

    for _, flag in ipairs(CustomFFlags) do
        pcall(function()
            if setfflag then
                setfflag(flag[1], flag[2])
                setfflag("FFlag" .. flag[1], flag[2])
                setfflag("FInt" .. flag[1], flag[2])
                setfflag("DFInt" .. flag[1], flag[2])
            end
        end)
    end

    if setfpscap then
        setfpscap(120) -- نحددها 120 ليتزامن مع الشاشة بدون هدر موارد
    end
end)

print("☢️ Anti-Thermal Limits Injected! Pushing to 120 FPS...")
