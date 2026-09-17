--[[
    ═══════════════════════════════════════════════════════
    🔥 Delta Executor - FFlags Loader Script
    ═══════════════════════════════════════════════════════
    ▸ يحاول تعيين FFlags عبر دوال مختلفة
    ▸ يشتغل على النسخ المطورة من Delta فقط
    ▸ إذا ما اشتغل، معناه نسختك ما تدعم FFlags
    ═══════════════════════════════════════════════════════
]]

-- ═══════════════ الإعدادات ═══════════════
local FLAGS = {
    ["DFIntTaskSchedulerTargetFps"]        = 240,
    ["DFIntConnectionMTUSize"]             = 1490,
    ["DFIntCSGLevelOfDetailSwitchingDistance"] = 100,
    ["FIntRenderShadowIntensity"]          = 0,
    ["FFlagDisablePostFx"]                 = true,
    ["DFIntDebugDynamicRenderKiloPixels"]  = 786432,
    ["FStringGetPlayerImageDefaultTimeout"] = "1",
}

-- ═══════════════ دوال محتملة لتعديل FFlags ═══════════════
local function trySetFFlag(name, value)
    -- المحاولة 1: دالة setfflag (الأكثر شيوعاً في Delta)
    if setfflag then
        pcall(setfflag, name, value)
        return true
    end
    
    -- المحاولة 2: دالة SetFFlag
    if SetFFlag then
        pcall(SetFFlag, name, value)
        return true
    end
    
    -- المحاولة 3: دالة set_fflag
    if set_fflag then
        pcall(set_fflag, name, value)
        return true
    end
    
    -- المحاولة 4: عبر getgenv
    if getgenv().setfflag then
        pcall(getgenv().setfflag, name, value)
        return true
    end
    
    -- المحاولة 5: عبر rawset في _G
    if _G.setfflag then
        pcall(_G.setfflag, name, value)
        return true
    end
    
    return false
end

-- ═══════════════ الدالة الرئيسية ═══════════════
local function main()
    print("═══════════════════════════════════════")
    print("🔥 Delta FFlags Loader")
    print("═══════════════════════════════════════")
    
    -- نتحقق إذا أي دالة موجودة
    local hasFunction = false
    if setfflag or SetFFlag or set_fflag or (getgenv() and getgenv().setfflag) or _G.setfflag then
        hasFunction = true
    end
    
    if not hasFunction then
        print("❌ ما لقينا أي دالة FFlags")
        print("⚠️  نسختك من Delta ما تدعم FFlags")
        print("💡 استخدم Chevstrap أو Masterstrap بدلاً منها")
        return
    end
    
    -- نطبق الفلاجات
    local successCount = 0
    local failCount = 0
    
    for name, value in pairs(FLAGS) do
        local ok = trySetFFlag(name, value)
        if ok then
            print("✅ " .. name .. " = " .. tostring(value))
            successCount = successCount + 1
        else
            print("❌ فشل: " .. name)
            failCount = failCount + 1
        end
    end
    
    print("═══════════════════════════════════════")
    print("📊 النتيجة: " .. successCount .. " نجح | " .. failCount .. " فشل")
    print("⚠️  لازم تعيد تشغيل Roblox عشان تتفعل الفلاجات")
    print("═══════════════════════════════════════")
end

-- ═══════════════ تشغيل ═══════════════
main()
