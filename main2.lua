-- ☢️ CUSTOM ENGINE OVERRIDE (Mobile Adapted FFlags) ☢️
print("☢️ Injecting Custom JSON FFlags for Mobile...")

pcall(function()
    -- تحويل قائمة الـ JSON إلى صيغة مدعومة للمشغلات (String Values)
    local CustomFFlags = {
        -- 1. كسر الفريمات وجدولة المهام (FPS & Task Scheduler)
        {"TaskSchedulerTargetFps", "2222"},
        {"TaskSchedulerLimitTargetFpsTo2402", "False"},
        {"GameBasicSettingsFramerateCap5", "False"}, -- تم التعديل لكسر القفل
        {"MaxFrameBufferSize", "10"},
        {"RenderingThrottleDelayInMS", "1"},

        -- 2. تدمير الرندرة والجرافيكس لتخفيف المعالج
        {"TextureQualityOverrideEnabled", "True"},
        {"TextureQualityOverride", "0"},
        {"DFIntTextureQualityOverride", "0"},
        {"DebugFRMQualityLevelOverride", "1"},
        {"RobloxGuiBlurIntensity", "0"},
        {"DebugSkyGray", "True"},
        {"DFFlagDebugPauseVoxelizer", "True"}, -- إيقاف معالجة الإضاءة المعقدة
        {"FastGPULightCulling3", "True"},
        {"DisableDPIScale", "True"}, -- يمنع اللعبة من محاولة تحسين الدقة بناء على شاشة الجوال

        -- 3. إيقاف التتبع والتحليلات الخلفية (Massive CPU/RAM Saver)
        {"BrowserTrackerIdTelemetryEnabled", "False"},
        {"DisableFastLogTelemetry", "True"},
        {"DebugAssertTelemetry", "False"},
        {"MeshCompressionTelemetry", "False"},
        {"CLI46794SendToTelemetry", "False"},
        {"EnablePerfDataGatherTelemetry2", "False"},
        {"ReportOutputDeviceWithRobloxTelemetry", "False"},

        -- 4. تحسين استجابة الشبكة والـ Ping
        {"S2PhysicsSenderRate", "128"},
        {"RakNetLoopMs", "1"},
        {"ClientPacketMaxDelayMs", "1"},
        {"NetworkQualityResponderMaxWaitTime", "5"},
        {"DataSenderMaxBandwidthBps", "555"},

        -- 5. تحسين المحرك الفيزيائي (Ragdoll & Physics)
        {"SimCSG3DcdMaxContacts", "32"},
        {"SimCSG3DCDMaxNumConvexHulls", "500"}
    }

    -- حقن الـ FFlags داخل محرك اللعبة
    for _, flag in ipairs(CustomFFlags) do
        pcall(function()
            if setfflag then
                setfflag(flag[1], flag[2])
                -- بعض المشغلات تحتاج وضع بادئة "FInt" أو "FFlag" أو "DFFlag"
                setfflag("FFlag" .. flag[1], flag[2])
                setfflag("FInt" .. flag[1], flag[2])
            end
        end)
    end

    -- الكسر النهائي لإطارات الشاشة
    if setfpscap then
        setfpscap(2222)
    end
end)

print("☢️ Custom FFlags Injected! VSync & Telemetry Destroyed.")
