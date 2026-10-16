-- جرّب أول: هل library يحمّل في Delta؟
local ok, lib = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/riqegopeek/NeverLose/refs/heads/main/src/interface.luau"))()
end)

if not ok or not lib then
    warn("Library failed to load:", lib)
    return
end

lib:Theme("white")

local oxy = lib:AddWindow("oxy", "oxy")
local combat = oxy:AddTab("combat", "rbxassetid://10734951847")
local visual2 = oxy:AddTab("visual", "rbxassetid://10723346959")
local misc2 = oxy:AddTab("misc", "rbxassetid://10709797985")
local fflags = oxy:AddTab("fflags", "rbxassetid://10723364435")

local parry = combat:AddSection("parry", "left")
local curve = combat:AddSection("curve", "right")
local spam = combat:AddSection("spam", "left")
local hotkeys = combat:AddSection("hotkeys", "right")
local visual = visual2:AddSection("visual", "left")
local misc = misc2:AddSection("misc", "left")

-- عناصر تجريبية
parry:AddToggle("auto parry", false, function(v) print("parry:", v) end)
parry:AddSlider("accuracy", 1, 100, 100, function(v) print("acc:", v) end)
curve:AddDropdown("curve method", {"camera","dot","backwards","slow","random"}, "camera", function(v) print(v) end)

print("Oxy loaded with original library")
