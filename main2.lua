--[[
    ═══════════════════════════════════════════════════════════
    🔥 Roblox FFlags Auto-Installer (Lua Script)
    ═══════════════════════════════════════════════════════════
    ▸ يشغل خارج Roblox (على الكمبيوتر)
    ▸ يتطلب مفسر Lua مثبت (Lua 5.1+ أو LuaJIT)
    ▸ يلقى أحدث إصدار Roblox تلقائياً
    ▸ ينشئ ClientAppSettings.json بأقوى الإعدادات المسموحة
    ▸ يحفظ نسخة احتياطية من الملف القديم
    ═══════════════════════════════════════════════════════════
]]

-- ═══════════════ الإعدادات (عدّل هنا حسب حاجتك) ═══════════════
local MODE = "balanced"  -- خيارات: "balanced" | "max_performance" | "custom"

-- الإعدادات المتوازنة (صورة حلوة + أداء عالي)
local FLAGS_BALANCED = {
    ["DFIntTaskSchedulerTargetFps"]        = 240,       -- إلغاء قيد الفريمات
    ["DFIntConnectionMTUSize"]             = 1490,      -- تقليل البنق
    ["DFIntCSGLevelOfDetailSwitchingDistance"] = 100,   -- تخفيف VRAM
    ["FIntRenderShadowIntensity"]          = 0,         -- إلغاء الظلال
    ["FFlagDisablePostFx"]                 = true,      -- إلغاء التأثيرات
    ["DFIntDebugDynamicRenderKiloPixels"]  = 786432,    -- دقة 1024x768
    ["FStringGetPlayerImageDefaultTimeout"] = "1",      -- تحميل أسرع للصور
}

-- أقصى أداء (صورة ضبابية بس أداء خارق)
local FLAGS_MAX_PERF = {
    ["DFIntTaskSchedulerTargetFps"]        = 240,
    ["DFIntConnectionMTUSize"]             = 1490,
    ["DFIntCSGLevelOfDetailSwitchingDistance"] = 0,
    ["FIntRenderShadowIntensity"]          = 0,
    ["FFlagDisablePostFx"]                 = true,
    ["DFIntDebugDynamicRenderKiloPixels"]  = 393216,    -- دقة منخفضة جداً
    ["FStringGetPlayerImageDefaultTimeout"] = "1",
}

-- إعدادات مخصصة (اكتب اللي تبيه)
local FLAGS_CUSTOM = {
    ["DFIntTaskSchedulerTargetFps"]        = 240,
    -- ["اسم_الفلاج"] = القيمة,
}

-- ═══════════════ اختيار الإعدادات ═══════════════
local function getSelectedFlags()
    if MODE == "balanced" then
        return FLAGS_BALANCED
    elseif MODE == "max_performance" then
        return FLAGS_MAX_PERF
    elseif MODE == "custom" then
        return FLAGS_CUSTOM
    else
        error("MODE غير صحيح! استخدم: balanced | max_performance | custom")
    end
end

-- ═══════════════ تحويل Lua Table إلى JSON ═══════════════
local function toJSON(tbl)
    local parts = {}
    for key, value in pairs(tbl) do
        local v
        if type(value) == "string" then
            v = '"' .. value .. '"'
        elseif type(value) == "boolean" then
            v = value and "true" or "false"
        elseif type(value) == "number" then
            v = tostring(value)
        else
            v = '"' .. tostring(value) .. '"'
        end
        table.insert(parts, '  "' .. key .. '": ' .. v)
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}"
end

-- ═══════════════ تنفيذ أوامر النظام ═══════════════
local function exec(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- ═══════════════ إيجاد أحدث مجلد إصدار Roblox ═══════════════
local function findLatestRobloxVersion()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData then
        return nil, "ما قدرنا نلقى مجلد LOCALAPPDATA"
    end

    local versionsPath = localAppData .. "\\Roblox\\Versions"
    print("🔍 نبحث في: " .. versionsPath)

    -- نستخدم dir عشان نلقى المجلدات
    local output = exec('dir /B /AD "' .. versionsPath .. '" 2>nul')
    if not output or output == "" then
        return nil, "ما لقينا مجلد الإصدارات. تأكد إن Roblox مثبت."
    end

    local latest = nil
    for folder in output:gmatch("[^\r\n]+") do
        if folder:match("^version%-") then
            -- نختار آخر واحد (عادة الأحدث)
            latest = folder
        end
    end

    if not latest then
        return nil, "ما لقينا أي مجلد يبدأ بـ version-"
    end

    return versionsPath .. "\\" .. latest
end

-- ═══════════════ حفظ نسخة احتياطية ═══════════════
local function backupExistingFile(filePath)
    local f = io.open(filePath, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()

    local backupPath = filePath .. ".backup_" .. os.time()
    local bf = io.open(backupPath, "w")
    if bf then
        bf:write(content)
        bf:close()
        print("💾 نسخة احتياطية: " .. backupPath)
        return true
    end
    return false
end

-- ═══════════════ إنشاء مجلد إذا ما موجود ═══════════════
local function ensureDirectory(path)
    -- نتحقق إذا موجود
    local test = io.open(path .. "\\_test.tmp", "w")
    if test then
        test:close()
        os.remove(path .. "\\_test.tmp")
        return true
    end
    -- ننشئه
    exec('mkdir "' .. path .. '" 2>nul')
    return true
end

-- ═══════════════ الدالة الرئيسية ═══════════════
local function install()
    print("═══════════════════════════════════════════════════")
    print("🔥 Roblox FFlags Installer")
    print("   الوضع الحالي: " .. MODE)
    print("═══════════════════════════════════════════════════")

    -- 1. لقاء مجلد الإصدار
    local versionPath, err = findLatestRobloxVersion()
    if not versionPath then
        print("❌ خطأ: " .. err)
        return
    end
    print("✅ لقينا الإصدار: " .. versionPath)

    -- 2. إنشاء مجلد ClientSettings
    local settingsPath = versionPath .. "\\ClientSettings"
    ensureDirectory(settingsPath)
    print("📁 مجلد الإعدادات: " .. settingsPath)

    -- 3. حفظ نسخة احتياطية إذا الملف موجود
    local filePath = settingsPath .. "\\ClientAppSettings.json"
    backupExistingFile(filePath)

    -- 4. توليد محتوى JSON
    local flags = getSelectedFlags()
    local json = toJSON(flags)

    -- 5. كتابة الملف
    local file, writeErr = io.open(filePath, "w")
    if not file then
        print("❌ ما قدرنا نكتب الملف: " .. tostring(writeErr))
        print("   جرّب تشغل السكربت كـ Administrator")
        return
    end
    file:write(json)
    file:close()

    print("═══════════════════════════════════════════════════")
    print("✅ تم التثبيت بنجاح!")
    print("📄 المسار: " .. filePath)
    print("═══════════════════════════════════════════════════")
    print("\n📋 الإعدادات المطبقة:")
    for k, v in pairs(flags) do
        print("   • " .. k .. " = " .. tostring(v))
    end
    print("\n⚠️  ملاحظة: سكّر Roblox وشغّله من جديد عشان تتفعل الإعدادات.")
end

-- ═══════════════ تشغيل ═══════════════
install()
