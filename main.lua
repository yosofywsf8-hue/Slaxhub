-- ============================================================
-- AUTO PIANO — GUI كامل مع أغاني جاهزة
-- File: auto_piano_gui.lua
-- البيانو: QWERTY (A-Z letters) — Roblox Piano العادي
-- الأغاني: Beethoven Virus, Für Elise, Moonlight Sonata,
--          Turkish March, Twinkle, Happy Birthday, Jingle Bells
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")

-- ============================================================
-- 1. KEYMAP — QWERTY كامل (Roblox Piano القياسي)
-- ============================================================
local KEYMAP = {
    -- ═══ Octave 3 (منخفض) ═══
    ["C3"]  = Enum.KeyCode.Z,
    ["C#3"] = Enum.KeyCode.X,
    ["D3"]  = Enum.KeyCode.C,
    ["D#3"] = Enum.KeyCode.V,
    ["E3"]  = Enum.KeyCode.B,
    ["F3"]  = Enum.KeyCode.N,
    ["F#3"] = Enum.KeyCode.M,
    ["G3"]  = Enum.KeyCode.Comma,
    ["G#3"] = Enum.KeyCode.Period,
    ["A3"]  = Enum.KeyCode.Slash,
    ["A#3"] = Enum.KeyCode.RightShift,
    ["B3"]  = Enum.KeyCode.Return,

    -- ═══ Octave 4 (وسط) ═══
    ["C4"]  = Enum.KeyCode.A,
    ["C#4"] = Enum.KeyCode.W,
    ["D4"]  = Enum.KeyCode.S,
    ["D#4"] = Enum.KeyCode.E,
    ["E4"]  = Enum.KeyCode.D,
    ["F4"]  = Enum.KeyCode.F,
    ["F#4"] = Enum.KeyCode.T,
    ["G4"]  = Enum.KeyCode.G,
    ["G#4"] = Enum.KeyCode.Y,
    ["A4"]  = Enum.KeyCode.H,
    ["A#4"] = Enum.KeyCode.U,
    ["B4"]  = Enum.KeyCode.J,

    -- ═══ Octave 5 (عالي) ═══
    ["C5"]  = Enum.KeyCode.K,
    ["C#5"] = Enum.KeyCode.O,
    ["D5"]  = Enum.KeyCode.L,
    ["D#5"] = Enum.KeyCode.P,
    ["E5"]  = Enum.KeyCode.Semicolon,
    ["F5"]  = Enum.KeyCode.Quote,
    ["F#5"] = Enum.KeyCode.LeftBracket,
    ["G5"]  = Enum.KeyCode.RightBracket,
    ["G#5"] = Enum.KeyCode.BackSlash,
    ["A5"]  = Enum.KeyCode.Up,
    ["A#5"] = Enum.KeyCode.Down,
    ["B5"]  = Enum.KeyCode.Left,

    -- ═══ Octave 6 (أعلى نادر) ═══
    ["C6"]  = Enum.KeyCode.Right,
    ["C#6"] = Enum.KeyCode.NumOne,
    ["D6"]  = Enum.KeyCode.NumTwo,
    ["D#6"] = Enum.KeyCode.NumThree,
    ["E6"]  = Enum.KeyCode.NumFour,
    ["F6"]  = Enum.KeyCode.NumFive,
}

-- ============================================================
-- 2. SONGS LIBRARY
-- ============================================================
local SONGS = {}

-- ═══════════════════════════════════════════════════════════════
-- BEETHOVEN VIRUS — الأصلي (BanYa, 2008)
-- السرعة الأصلية ~140 BPM
-- ═══════════════════════════════════════════════════════════════
SONGS["Beethoven Virus"] = {
    -- INTRO — Octave riff
    {0.00,  "E4",  0.15},
    {0.15,  "E4",  0.15},
    {0.30,  "E4",  0.15},
    {0.45,  "E4",  0.15},
    {0.60,  "C4",  0.30},
    {0.90,  "E4",  0.15},
    {1.05,  "G4",  0.30},

    {1.40,  "E4",  0.15},
    {1.55,  "E4",  0.15},
    {1.70,  "E4",  0.15},
    {1.85,  "E4",  0.15},
    {2.00,  "C4",  0.30},
    {2.30,  "G4",  0.15},
    {2.45,  "B4",  0.30},

    -- MAIN THEME — اللحن الشهير
    {2.90,  "C5",  0.30},
    {3.20,  "B4",  0.30},
    {3.50,  "A4",  0.30},
    {3.80,  "G4",  0.30},
    {4.10,  "A4",  0.30},
    {4.40,  "B4",  0.30},
    {4.70,  "C5",  0.60},

    {5.30,  "E5",  0.30},
    {5.60,  "D5",  0.30},
    {5.90,  "C5",  0.30},
    {6.20,  "B4",  0.30},
    {6.50,  "C5",  0.30},
    {6.80,  "D5",  0.30},
    {7.10,  "E5",  0.60},

    {7.70,  "A4",  0.30},
    {8.00,  "C5",  0.30},
    {8.30,  "E5",  0.30},
    {8.60,  "A4",  0.30},
    {8.90,  "C5",  0.30},
    {9.20,  "E5",  0.30},
    {9.50,  "A5",  0.60},

    -- DESCENDING RUN
    {10.10, "A5",  0.10},
    {10.20, "G5",  0.10},
    {10.30, "F5",  0.10},
    {10.40, "E5",  0.10},
    {10.50, "D5",  0.10},
    {10.60, "C5",  0.10},
    {10.70, "B4",  0.10},
    {10.80, "A4",  0.10},
    {10.90, "G4",  0.10},
    {11.00, "F4",  0.10},
    {11.10, "E4",  0.10},
    {11.20, "D4",  0.10},
    {11.30, "C4",  0.60},

    -- SECOND PHRASE
    {12.00, "E4",  0.15},
    {12.15, "G4",  0.15},
    {12.30, "C5",  0.30},
    {12.60, "B4",  0.15},
    {12.75, "A4",  0.15},
    {12.90, "G4",  0.30},
    {13.20, "A4",  0.15},
    {13.35, "B4",  0.15},
    {13.50, "C5",  0.60},

    {14.10, "E5",  0.15},
    {14.25, "D5",  0.15},
    {14.40, "C5",  0.30},
    {14.70, "B4",  0.15},
    {14.85, "A4",  0.15},
    {15.00, "G4",  0.30},
    {15.30, "A4",  0.15},
    {15.45, "B4",  0.15},
    {15.60, "C5",  0.30},

    -- CLIMAX — Chromatic
    {16.10, "A4",  0.15},
    {16.25, "A#4", 0.15},
    {16.40, "B4",  0.15},
    {16.55, "C5",  0.15},
    {16.70, "C#5", 0.15},
    {16.85, "D5",  0.15},
    {17.00, "D#5", 0.15},
    {17.15, "E5",  0.40},

    {17.60, "F5",  0.15},
    {17.75, "E5",  0.15},
    {17.90, "D#5", 0.15},
    {18.05, "D5",  0.15},
    {18.20, "C#5", 0.15},
    {18.35, "C5",  0.15},
    {18.50, "B4",  0.15},
    {18.65, "A#4", 0.40},

    -- FALLING
    {19.10, "A4",  0.20},
    {19.30, "G4",  0.20},
    {19.50, "F4",  0.20},
    {19.70, "E4",  0.20},
    {19.90, "D4",  0.20},
    {20.10, "C4",  0.20},
    {20.30, "B3",  0.20},
    {20.50, "A3",  0.60},

    -- REPEAT MAIN (octave up)
    {21.20, "C5",  0.30},
    {21.50, "B4",  0.30},
    {21.80, "A4",  0.30},
    {22.10, "G4",  0.30},
    {22.40, "A4",  0.30},
    {22.70, "B4",  0.30},
    {23.00, "C5",  0.60},

    {23.60, "E5",  0.30},
    {23.90, "D5",  0.30},
    {24.20, "C5",  0.30},
    {24.50, "B4",  0.30},
    {24.80, "C5",  0.30},
    {25.10, "D5",  0.30},
    {25.40, "E5",  0.60},

    -- FINAL CHORD
    {26.10, "C4",  0.40},
    {26.50, "E4",  0.40},
    {26.90, "G4",  0.40},
    {27.30, "C5",  1.50},
}

-- ═══════════════════════════════════════════════════════════════
-- FÜR ELISE — Beethoven
-- ═══════════════════════════════════════════════════════════════
SONGS["Für Elise"] = {
    {0.00,  "E5",  0.30},
    {0.30,  "D#5", 0.30},
    {0.60,  "E5",  0.30},
    {0.90,  "D#5", 0.30},
    {1.20,  "E5",  0.30},
    {1.50,  "B4",  0.30},
    {1.80,  "D5",  0.30},
    {2.10,  "C5",  0.30},
    {2.40,  "A4",  0.60},

    {3.20,  "C4",  0.30},
    {3.50,  "E4",  0.30},
    {3.80,  "A4",  0.30},
    {4.10,  "B4",  0.60},

    {4.90,  "E4",  0.30},
    {5.20,  "G#4", 0.30},
    {5.50,  "B4",  0.30},
    {5.80,  "C5",  0.60},

    {6.60,  "E4",  0.30},
    {6.90,  "E5",  0.30},
    {7.20,  "D#5", 0.30},
    {7.50,  "E5",  0.30},
    {7.80,  "D#5", 0.30},
    {8.10,  "E5",  0.30},
    {8.40,  "B4",  0.30},
    {8.70,  "D5",  0.30},
    {9.00,  "C5",  0.30},
    {9.30,  "A4",  0.60},

    {10.10, "C4",  0.30},
    {10.40, "E4",  0.30},
    {10.70, "A4",  0.30},
    {11.00, "B4",  0.60},

    {11.80, "E4",  0.30},
    {12.10, "C5",  0.30},
    {12.40, "B4",  0.30},
    {12.70, "A4",  0.90},
}

-- ═══════════════════════════════════════════════════════════════
-- MOONLIGHT SONATA — Beethoven (1st Movement opening)
-- ═══════════════════════════════════════════════════════════════
SONGS["Moonlight Sonata"] = {
    {0.00,  "C#4", 0.60},
    {0.60,  "G#4", 0.60},
    {1.20,  "C#5", 0.60},
    {1.80,  "G#4", 0.60},
    {2.40,  "C#4", 0.60},
    {3.00,  "G#4", 0.60},

    {3.60,  "A3",  0.60},
    {4.20,  "E4",  0.60},
    {4.80,  "A4",  0.60},
    {5.40,  "E4",  0.60},
    {6.00,  "A3",  0.60},
    {6.60,  "E4",  0.60},

    {7.20,  "D#3", 0.60},
    {7.80,  "A#3", 0.60},
    {8.40,  "D#4", 0.60},
    {9.00,  "A#3", 0.60},
    {9.60,  "D#3", 0.60},
    {10.20, "A#3", 0.60},

    {10.80, "G#3", 0.60},
    {11.40, "D#4", 0.60},
    {12.00, "G#4", 0.60},
    {12.60, "D#4", 0.60},
    {13.20, "G#3", 0.60},
    {13.80, "D#4", 0.60},

    {14.40, "C#4", 0.60},
    {15.00, "G#4", 0.60},
    {15.60, "C#5", 0.60},
    {16.20, "G#4", 0.60},
    {16.80, "C#4", 0.60},
    {17.40, "G#4", 0.90},
}

-- ═══════════════════════════════════════════════════════════════
-- TURKISH MARCH — Mozart
-- ═══════════════════════════════════════════════════════════════
SONGS["Turkish March"] = {
    {0.00,  "B4",  0.15},
    {0.15,  "A4",  0.15},
    {0.30,  "G#4", 0.15},
    {0.45,  "A4",  0.15},
    {0.60,  "C5",  0.30},
    {0.90,  "A4",  0.15},
    {1.05,  "C5",  0.15},
    {1.20,  "A4",  0.30},

    {1.50,  "B4",  0.15},
    {1.65,  "A4",  0.15},
    {1.80,  "G#4", 0.15},
    {1.95,  "A4",  0.15},
    {2.10,  "C5",  0.30},
    {2.40,  "A4",  0.15},
    {2.55,  "C5",  0.15},
    {2.70,  "A4",  0.30},

    {3.00,  "B4",  0.15},
    {3.15,  "C5",  0.15},
    {3.30,  "D5",  0.15},
    {3.45,  "E5",  0.15},
    {3.60,  "F5",  0.15},
    {3.75,  "G5",  0.15},
    {3.90,  "A5",  0.30},
    {4.20,  "G5",  0.30},
    {4.50,  "F5",  0.30},
    {4.80,  "E5",  0.30},
    {5.10,  "D5",  0.30},
    {5.40,  "C5",  0.30},
    {5.70,  "B4",  0.30},
    {6.00,  "A4",  0.60},
}

-- ═══════════════════════════════════════════════════════════════
-- TWINKLE TWINKLE — سهل
-- ═══════════════════════════════════════════════════════════════
SONGS["Twinkle Twinkle"] = {
    {0.00,  "C4",  0.40},
    {0.40,  "C4",  0.40},
    {0.80,  "G4",  0.40},
    {1.20,  "G4",  0.40},
    {1.60,  "A4",  0.40},
    {2.00,  "A4",  0.40},
    {2.40,  "G4",  0.80},
    {3.20,  "F4",  0.40},
    {3.60,  "F4",  0.40},
    {4.00,  "E4",  0.40},
    {4.40,  "E4",  0.40},
    {4.80,  "D4",  0.40},
    {5.20,  "D4",  0.40},
    {5.60,  "C4",  0.80},
    {6.40,  "G4",  0.40},
    {6.80,  "G4",  0.40},
    {7.20,  "F4",  0.40},
    {7.60,  "F4",  0.40},
    {8.00,  "E4",  0.40},
    {8.40,  "E4",  0.40},
    {8.80,  "D4",  0.80},
    {9.60,  "G4",  0.40},
    {10.00, "G4",  0.40},
    {10.40, "F4",  0.40},
    {10.80, "F4",  0.40},
    {11.20, "E4",  0.40},
    {11.60, "E4",  0.40},
    {12.00, "D4",  0.80},
    {12.80, "C4",  0.40},
    {13.20, "C4",  0.40},
    {13.60, "G4",  0.40},
    {14.00, "G4",  0.40},
    {14.40, "A4",  0.40},
    {14.80, "A4",  0.40},
    {15.20, "G4",  0.80},
    {16.00, "F4",  0.40},
    {16.40, "F4",  0.40},
    {16.80, "E4",  0.40},
    {17.20, "E4",  0.40},
    {17.60, "D4",  0.40},
    {18.00, "D4",  0.40},
    {18.40, "C4",  0.80},
}

-- ═══════════════════════════════════════════════════════════════
-- HAPPY BIRTHDAY
-- ═══════════════════════════════════════════════════════════════
SONGS["Happy Birthday"] = {
    {0.00,  "C4",  0.20},
    {0.20,  "C4",  0.20},
    {0.40,  "D4",  0.40},
    {0.80,  "C4",  0.40},
    {1.20,  "F4",  0.40},
    {1.60,  "E4",  0.80},
    {2.40,  "C4",  0.20},
    {2.60,  "C4",  0.20},
    {2.80,  "D4",  0.40},
    {3.20,  "C4",  0.40},
    {3.60,  "G4",  0.40},
    {4.00,  "F4",  0.80},
    {4.80,  "C4",  0.20},
    {5.00,  "C4",  0.20},
    {5.20,  "C5",  0.40},
    {5.60,  "A4",  0.40},
    {6.00,  "F4",  0.40},
    {6.40,  "E4",  0.40},
    {6.80,  "D4",  0.80},
    {7.60,  "A#4", 0.20},
    {7.80,  "A#4", 0.20},
    {8.00,  "A4",  0.40},
    {8.40,  "F4",  0.40},
    {8.80,  "G4",  0.40},
    {9.20,  "F4",  0.80},
}

-- ═══════════════════════════════════════════════════════════════
-- JINGLE BELLS
-- ═══════════════════════════════════════════════════════════════
SONGS["Jingle Bells"] = {
    {0.00,  "E4",  0.30},
    {0.30,  "E4",  0.30},
    {0.60,  "E4",  0.60},
    {1.20,  "E4",  0.30},
    {1.50,  "E4",  0.30},
    {1.80,  "E4",  0.60},
    {2.40,  "E4",  0.30},
    {2.70,  "G4",  0.30},
    {3.00,  "C4",  0.30},
    {3.30,  "D4",  0.30},
    {3.60,  "E4",  0.90},
    {4.50,  "F4",  0.30},
    {4.80,  "F4",  0.30},
    {5.10,  "F4",  0.30},
    {5.40,  "F4",  0.30},
    {5.70,  "F4",  0.30},
    {6.00,  "E4",  0.30},
    {6.30,  "E4",  0.30},
    {6.60,  "E4",  0.30},
    {6.90,  "E4",  0.30},
    {7.20,  "D4",  0.30},
    {7.50,  "D4",  0.30},
    {7.80,  "E4",  0.30},
    {8.10,  "D4",  0.60},
    {8.70,  "G4",  0.60},
}

-- ============================================================
-- 3. STATE
-- ============================================================
local STATE = {
    running      = false,
    loop         = false,
    speed        = 1.0,
    current_song = nil,
    current_run  = 0,
    pressed_keys = {},
}

-- ============================================================
-- 4. CORE — تشغيل نوتة
-- ============================================================
local function press_key(keycode, duration)
    if not keycode then return end

    pcall(function()
        VIM:SendKeyEvent(true, keycode, false, game)
    end)

    if duration and duration > 0 then
        task.wait(duration)
    end

    pcall(function()
        VIM:SendKeyEvent(false, keycode, false, game)
    end)
end

local function release_all_keys()
    for keycode, _ in pairs(STATE.pressed_keys) do
        pcall(function()
            VIM:SendKeyEvent(false, keycode, false, game)
        end)
    end
    STATE.pressed_keys = {}
end

-- تشغيل Sheet
local function play_sheet(sheet, on_finish)
    STATE.running = true
    STATE.current_run = STATE.current_run + 1
    local run_id = STATE.current_run

    local start_time = tick()

    for _, entry in ipairs(sheet) do
        if not STATE.running or STATE.current_run ~= run_id then
            release_all_keys()
            return
        end

        local time  = entry[1] / STATE.speed
        local note  = entry[2]
        local dur   = entry[3] or 0.15

        local now = tick() - start_time
        if time > now then
            task.wait(time - now)
        end

        if not STATE.running or STATE.current_run ~= run_id then
            release_all_keys()
            return
        end

        local key = KEYMAP[note]
        if key then
            STATE.pressed_keys[key] = true
            task.spawn(function()
                pcall(function()
                    VIM:SendKeyEvent(true, key, false, game)
                end)
                task.wait(math.min(dur, 0.3))
                pcall(function()
                    VIM:SendKeyEvent(false, key, false, game)
                end)
                STATE.pressed_keys[key] = nil
            end)
        end
    end

    -- انتظار آخر نوتة
    task.wait(0.5)

    if STATE.running and STATE.current_run == run_id then
        if STATE.loop then
            task.wait(0.5)
            if STATE.running and STATE.current_run == run_id then
                return play_sheet(sheet, on_finish)
            end
        else
            STATE.running = false
            if on_finish then on_finish() end
        end
    end
end

-- ============================================================
-- 5. THEME + HELPERS
-- ============================================================
local THEME = {
    bg         = Color3.fromRGB(14, 14, 20),
    soft       = Color3.fromRGB(24, 24, 32),
    soft_hover = Color3.fromRGB(34, 34, 44),
    stroke     = Color3.fromRGB(60, 60, 80),
    text       = Color3.fromRGB(240, 240, 245),
    dim        = Color3.fromRGB(150, 150, 170),
    on         = Color3.fromRGB(90, 210, 130),
    warn       = Color3.fromRGB(230, 180, 80),
    accent     = Color3.fromRGB(120, 150, 250),
    font       = Font.new("rbxasset://fonts/families/GothamSSm.json",
                          Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
    bold       = Font.new("rbxasset://fonts/families/GothamSSm.json",
                          Enum.FontWeight.Bold, Enum.FontStyle.Normal),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
    return c
end

local function stroke(p, color)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.stroke
    s.Thickness = 1
    s.Transparency = 0.3
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function tween(o, d, props)
    return TweenService:Create(
        o,
        TweenInfo.new(d or 0.2, Enum.EasingStyle.Quint,
                      Enum.EasingDirection.Out),
        props
    )
end

-- ============================================================
-- 6. UI
-- ============================================================
local parent_gui = CoreGui
if gethui then
    local ok, h = pcall(gethui)
    if ok and h then parent_gui = h end
end

local screen = Instance.new("ScreenGui")
screen.Name = "AutoPianoUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 500
screen.Parent = parent_gui

-- زر تعليق (♪)
local toggle_btn = Instance.new("TextButton")
toggle_btn.Size = UDim2.new(0, 54, 0, 54)
toggle_btn.Position = UDim2.new(0, 16, 0.5, -27)
toggle_btn.BackgroundColor3 = THEME.bg
toggle_btn.BackgroundTransparency = 0.1
toggle_btn.BorderSizePixel = 0
toggle_btn.Text = "♪"
toggle_btn.TextColor3 = THEME.text
toggle_btn.FontFace = THEME.bold
toggle_btn.TextSize = 22
toggle_btn.AutoButtonColor = false
toggle_btn.Parent = screen
corner(toggle_btn, 27)
stroke(toggle_btn)

-- اللوحة الرئيسية
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 460)
panel.Position = UDim2.new(0, 16, 0.5, -230)
panel.BackgroundColor3 = THEME.bg
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen
corner(panel, 14)
stroke(panel)

-- الهيدر
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "♪ Auto Piano"
title.TextColor3 = THEME.text
title.FontFace = THEME.bold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Parent = header

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 30, 0, 30)
close_btn.Position = UDim2.new(1, -38, 0, 7)
close_btn.BackgroundColor3 = THEME.soft
close_btn.BorderSizePixel = 0
close_btn.Text = "×"
close_btn.TextColor3 = THEME.dim
close_btn.FontFace = THEME.bold
close_btn.TextSize = 20
close_btn.AutoButtonColor = false
close_btn.Parent = header
corner(close_btn, 8)

-- Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(1, -24, 0, 1)
div.Position = UDim2.new(0, 12, 0, 44)
div.BackgroundColor3 = THEME.stroke
div.BorderSizePixel = 0
div.Parent = panel

-- محتوى
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -20, 1, -60)
content.Position = UDim2.new(0, 10, 0, 52)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = THEME.stroke
content.ScrollBarImageTransparency = 0.5
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 2)
pad.PaddingRight = UDim.new(0, 2)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = content

-- ============================================================
-- 7. SECTION TITLES + BUTTONS
-- ============================================================
local function make_section_label(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. text .. " —"
    lbl.TextColor3 = THEME.dim
    lbl.FontFace = THEME.font
    lbl.TextSize = 11
    lbl.LayoutOrder = order
    lbl.Parent = content
end

local function make_button(label, order, callback, color_override)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color_override or THEME.soft
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = THEME.text
    btn.FontFace = THEME.font
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Parent = content
    corner(btn, 8)
    stroke(btn)

    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = THEME.soft_hover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = color_override or THEME.soft }):Play()
    end)
    btn.MouseButton1Click:Connect(callback)

    return btn
end

-- قائمة الأغاني
make_section_label("الأغاني", 1)

local song_buttons = {}
local song_names = {
    "Beethoven Virus",
    "Für Elise",
    "Moonlight Sonata",
    "Turkish March",
    "Twinkle Twinkle",
    "Happy Birthday",
    "Jingle Bells",
}

local function refresh_song_buttons()
    for name, btn in pairs(song_buttons) do
        local is_active = (STATE.current_song == name and STATE.running)
        btn.BackgroundColor3 = is_active and THEME.on or THEME.soft
        btn.TextColor3 = is_active and THEME.bg or THEME.text
        btn.Text = (is_active and "▶ " or "") .. name
    end
end

for i, song_name in ipairs(song_names) do
    local btn = make_button(song_name, 10 + i, function()
        STATE.current_song = song_name
        refresh_song_buttons()

        if STATE.running then
            STATE.running = false
            task.wait(0.15)
        end

        task.spawn(function()
            play_sheet(SONGS[song_name], function()
                refresh_song_buttons()
            end)
        end)
    end)
    song_buttons[song_name] = btn
end

-- أزرار التحكم
make_section_label("التحكم", 40)

local stop_btn = make_button("■ إيقاف", 41, function()
    STATE.running = false
    release_all_keys()
    task.wait(0.1)
    refresh_song_buttons()
end, THEME.soft)

local loop_btn = make_button("Loop: OFF", 42, function()
    STATE.loop = not STATE.loop
    loop_btn.Text = STATE.loop and "Loop: ON" or "Loop: OFF"
    loop_btn.BackgroundColor3 = STATE.loop and THEME.on or THEME.soft
    loop_btn.TextColor3 = STATE.loop and THEME.bg or THEME.text
end)

-- Speed buttons
make_section_label("السرعة", 50)

local speed_buttons = {}
local speed_options = {0.5, 0.75, 1.0, 1.25, 1.5, 2.0}

local speed_row = Instance.new("Frame")
speed_row.Size = UDim2.new(1, 0, 0, 38)
speed_row.BackgroundTransparency = 1
speed_row.LayoutOrder = 51
speed_row.Parent = content

local speed_layout = Instance.new("UIListLayout")
speed_layout.FillDirection = Enum.FillDirection.Horizontal
speed_layout.Padding = UDim.new(0, 4)
speed_layout.Parent = speed_row

local function refresh_speed_buttons()
    for val, btn in pairs(speed_buttons) do
        local is_active = (STATE.speed == val)
        btn.BackgroundColor3 = is_active and THEME.accent or THEME.soft
        btn.TextColor3 = is_active and THEME.text or THEME.dim
    end
end

for _, val in ipairs(speed_options) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 1, 0)
    btn.BackgroundColor3 = THEME.soft
    btn.BorderSizePixel = 0
    btn.Text = val .. "x"
    btn.TextColor3 = THEME.dim
    btn.FontFace = THEME.font
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = speed_row
    corner(btn, 6)
    stroke(btn)

    btn.MouseButton1Click:Connect(function()
        STATE.speed = val
        refresh_speed_buttons()
    end)

    speed_buttons[val] = btn
end

refresh_speed_buttons()

-- ============================================================
-- 8. DRAG + OPEN/CLOSE
-- ============================================================
local dragging, drag_start, panel_start = false, nil, nil

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        drag_start = input.Position
        panel_start = panel.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local d = input.Position - drag_start
    panel.Position = UDim2.new(
        panel_start.X.Scale,
        panel_start.X.Offset + d.X,
        panel_start.Y.Scale,
        panel_start.Y.Offset + d.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local is_open = false

local function set_open(state)
    is_open = state
    if state then
        panel.Visible = true
        panel.Size = UDim2.new(0, 300, 0, 60)
        tween(panel, 0.25, { Size = UDim2.new(0, 300, 0, 460) }):Play()
    else
        tween(panel, 0.2, { Size = UDim2.new(0, 300, 0, 44) }):Play()
        task.delay(0.2, function()
            if not is_open then panel.Visible = false end
        end)
    end
end

toggle_btn.MouseButton1Click:Connect(function() set_open(not is_open) end)
close_btn.MouseButton1Click:Connect(function() set_open(false) end)

-- ============================================================
-- 9. EXPORTS
-- ============================================================
getgenv().__AUTO_PIANO = {
    KEYMAP        = KEYMAP,
    SONGS         = SONGS,
    STATE         = STATE,
    play          = function(name)
        if not name or not SONGS[name] then return false end
        STATE.current_song = name
        STATE.running = false
        task.wait(0.1)
        task.spawn(play_sheet, SONGS[name], function() end)
        return true
    end,
    stop          = function()
        STATE.running = false
        release_all_keys()
    end,
    set_loop      = function(v)
        STATE.loop = v == true
    end,
    set_speed     = function(v)
        STATE.speed = tonumber(v) or 1.0
    end,
    get_songs     = function()
        local names = {}
        for k in pairs(SONGS) do table.insert(names, k) end
        table.sort(names)
        return names
    end,
    ui            = {
        open  = function() set_open(true) end,
        close = function() set_open(false) end,
    },
}

print("[AUTO PIANO] جاهز — ABSOLUTE KODE، يا ريدز")
print("[AUTO PIANO] Songs:", #song_names)
