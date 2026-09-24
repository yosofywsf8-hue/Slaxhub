-- =======================================================
-- 1. تحميل واستدعاء المكتبة (UI Library Initialization)
-- =======================================================

-- إفراغ القيم في حال تم تشغيل السكربت بدون تشفير (Luraph Protection fallback)
if not LPH_OBFUSCATED then
    LPH_ENCFUNC = function(func) return func end
    LPH_NO_VIRTUALIZE = function(func) return func end
end

-- استدعاء خدمات روبلوكس الأساسية
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- =======================================================
-- 2. إعداد المجلدات ونظام الحفظ (Folder & Config Setup)
-- =======================================================
local folderName = "SlaxHub"
if makefolder and isfolder then
    if not isfolder(folderName) then makefolder(folderName) end
    if not isfolder(folderName .. "/configs") then makefolder(folderName .. "/configs") end
end

-- =======================================================
-- 3. بناء الواجهة الرئيسية (UI Window Creation)
-- =======================================================

-- ملاحظة: تم إعداد هيكل المكتبة لإنشاء نافذة السكربت الرئيسية
local SlaxHub = {
    Flags = {},
    Toggles = {},
    Options = {}
}

-- إنشاء الشاشة الرئيسية (ScreenGui)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaxHub_UI"
ScreenGui.ResetOnSpawn = false

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

-- الإطار الرئيسي للواجهة (Main Frame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 360)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 60)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- شريط العنوان (Top Bar / Header)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "Slax Hub | Premium Edition"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Parent = TopBar

-- زر إغلاق / إظهار اللوحة للجوال (Mobile Toggle Button)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "MobileToggle"
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(0, 15, 0, 15)
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ToggleButton.Text = "Slax"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 12
ToggleButton.Parent = ScreenGui

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- حاوي التبويبات والمحتوى (Container)
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -20, 1, -55)
ContentContainer.Position = UDim2.new(0, 10, 0, 45)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ContentContainer

-- =======================================================
-- 4. إضافات عناصر التحكم (Buttons, Toggles, Sliders)
-- =======================================================

-- دالة إضافة زر (Button)
function SlaxHub:CreateButton(text, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 35)
    Btn.BackgroundColor3 = Color3.fromRGB(32, 32, 45)
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    Btn.Font = Enum.Font.GothamMedium
    Btn.TextSize = 14
    Btn.Parent = ContentContainer

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
end

-- دالة إضافة تفعيل/إيقاف (Toggle)
function SlaxHub:CreateToggle(text, default, callback)
    local state = default or false
    SlaxHub.Flags[text] = state

    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 45)
    ToggleFrame.Parent = ContentContainer

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = ToggleFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.BackgroundTransparency = 1
    Label.Parent = ToggleFrame

    local Indicator = Instance.new("Frame")
    Indicator.Size = UDim2.new(0, 20, 0, 20)
    Indicator.Position = UDim2.new(1, -30, 0.5, -10)
    Indicator.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 90)
    Indicator.Parent = ToggleFrame

    local IndCorner = Instance.new("UICorner")
    IndCorner.CornerRadius = UDim.new(0, 4)
    IndCorner.Parent = Indicator

    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.Parent = ToggleFrame

    ClickBtn.MouseButton1Click:Connect(function()
        state = not state
        SlaxHub.Flags[text] = state
        Indicator.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 90)
        pcall(callback, state)
    end)
end

-- =======================================================
-- 5. ربط مميزات السكربت (Script Features Implementation)
-- =======================================================

-- تفعيل / إيقاف التتبع الفوري أو الأوتوماتيكي
SlaxHub:CreateToggle("Auto Parry / Auto Play", false, function(active)
    print("Auto Parry Status:", active)
    -- ضع كود الـ Auto Parry الخاص باللعبة هنا
end)

SlaxHub:CreateToggle("Infinite Jump", false, function(active)
    SlaxHub.Flags["InfiniteJump"] = active
end)

-- الاستماع لحدث القفز المستمر
UserInputService.JumpRequest:Connect(function()
    if SlaxHub.Flags["InfiniteJump"] and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)

-- زر لإعادة ضبط السرعة
SlaxHub:CreateButton("Set WalkSpeed (50)", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 50
    end
end)

print("Slax Hub Loaded Successfully!")
