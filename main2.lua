local Library = {}
Library.Flags = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- دالة المساعدة للتحريك (Tweening)
local function tween(object, info, properties)
    local anim = TweenService:Create(object, TweenInfo.new(unpack(info)), properties)
    anim:Play()
    return anim
end

-- إنشاء النافذة الرئيسية
function Library:CreateWindow(hubTitle)
    local AngeliUI = Instance.new("ScreenGui")
    AngeliUI.Name = "AngeliStyleUI"
    AngeliUI.Parent = CoreGui
    AngeliUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = AngeliUI
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.Position = UDim2.new(0.3, 0, 0.25, 0)
    Main.Size = UDim2.new(0, 550, 0, 380)
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = Main

    -- جعل النافذة قابلة للسحب
    local dragging, dragInput, dragStart, startPos
    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    Main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- شريط العنوان (TopBar)
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Parent = Main
    TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    TopBar.Size = UDim2.new(1, 0, 0, 40)

    local Title = Instance.new("TextLabel")
    Title.Parent = TopBar
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Size = UDim2.new(0.5, 0, 1, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = hubTitle or "Angeli Hub"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left

    -- القائمة الجانبية (Sidebar)
    local SideBar = Instance.new("Frame")
    SideBar.Name = "SideBar"
    SideBar.Parent = Main
    SideBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    SideBar.Position = UDim2.new(0, 0, 0, 40)
    SideBar.Size = UDim2.new(0, 140, 1, -40)

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Parent = SideBar
    TabContainer.BackgroundTransparency = 1
    TabContainer.Size = UDim2.new(1, 0, 1, 0)
    TabContainer.ScrollBarThickness = 2

    local TabList = Instance.new("UIListLayout")
    TabList.Parent = TabContainer
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Padding = UDim.new(0, 5)

    -- منطقة عرض المحتوى
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Parent = Main
    ContentArea.BackgroundTransparency = 1
    ContentArea.Position = UDim2.new(0, 145, 0, 45)
    ContentArea.Size = UDim2.new(1, -150, 1, -50)

    local Window = {}
    local currentTab = nil

    -- إنشاء Tab جديد
    function Window:CreateTab(tabName)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Name = tabName .. "Btn"
        TabBtn.Parent = TabContainer
        TabBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        TabBtn.Size = UDim2.new(0.9, 0, 0, 32)
        TabBtn.Font = Enum.Font.Gotham
        TabBtn.Text = tabName
        TabBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
        TabBtn.TextSize = 12

        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 6)
        TabCorner.Parent = TabBtn

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Name = tabName .. "Page"
        TabPage.Parent = ContentArea
        TabPage.BackgroundTransparency = 1
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.Visible = false
        TabPage.ScrollBarThickness = 3

        local PageList = Instance.new("UIListLayout")
        PageList.Parent = TabPage
        PageList.SortOrder = Enum.SortOrder.LayoutOrder
        PageList.Padding = UDim.new(0, 8)

        if currentTab == nil then
            currentTab = TabPage
            TabPage.Visible = true
            TabBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
            TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        TabBtn.MouseButton1Click:Connect(function()
            for _, page in pairs(ContentArea:GetChildren()) do
                if page:IsA("ScrollingFrame") then page.Visible = false end
            end
            for _, btn in pairs(TabContainer:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
                    btn.TextColor3 = Color3.fromRGB(180, 180, 190)
                end
            end
            TabPage.Visible = true
            TabBtn.BackgroundColor3 = Color3.fromRGB(85, 95, 220)
            TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)

        local Tab = {}

        -- إضافة Button
        function Tab:CreateButton(btnText, callback)
            local Button = Instance.new("TextButton")
            Button.Parent = TabPage
            Button.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
            Button.Size = UDim2.new(0.98, 0, 0, 35)
            Button.Font = Enum.Font.GothamMedium
            Button.Text = btnText
            Button.TextColor3 = Color3.fromRGB(240, 240, 240)
            Button.TextSize = 12

            local BtnCorner = Instance.new("UICorner")
            BtnCorner.CornerRadius = UDim.new(0, 6)
            BtnCorner.Parent = Button

            Button.MouseButton1Click:Connect(function()
                pcall(callback)
            end)
        end

        -- إضافة Toggle
        function Tab:CreateToggle(toggleText, callback)
            local state = false
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Parent = TabPage
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
            ToggleFrame.Size = UDim2.new(0.98, 0, 0, 35)

            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame

            local Label = Instance.new("TextLabel")
            Label.Parent = ToggleFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(0.7, 0, 1, 0)
            Label.Font = Enum.Font.Gotham
            Label.Text = toggleText
            Label.TextColor3 = Color3.fromRGB(220, 220, 220)
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local Switch = Instance.new("Frame")
            Switch.Parent = ToggleFrame
            Switch.Position = UDim2.new(0.85, 0, 0.25, 0)
            Switch.Size = UDim2.new(0, 35, 0, 18)
            Switch.BackgroundColor3 = Color3.fromRGB(45, 45, 55)

            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(1, 0)
            SCorner.Parent = Switch

            local Knob = Instance.new("Frame")
            Knob.Parent = Switch
            Knob.Position = UDim2.new(0, 2, 0.1, 0)
            Knob.Size = UDim2.new(0, 14, 0, 14)
            Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)

            local KCorner = Instance.new("UICorner")
            KCorner.CornerRadius = UDim.new(1, 0)
            KCorner.Parent = Knob

            local Click = Instance.new("TextButton")
            Click.Parent = ToggleFrame
            Click.BackgroundTransparency = 1
            Click.Size = UDim2.new(1, 0, 1, 0)
            Click.Text = ""

            Click.MouseButton1Click:Connect(function()
                state = not state
                if state then
                    tween(Switch, {0.2}, {BackgroundColor3 = Color3.fromRGB(85, 95, 220)})
                    tween(Knob, {0.2}, {Position = UDim2.new(1, -16, 0.1, 0)})
                else
                    tween(Switch, {0.2}, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)})
                    tween(Knob, {0.2}, {Position = UDim2.new(0, 2, 0.1, 0)})
                end
                pcall(callback, state)
            end)
        end

        return Tab
    end

    return Window
end

-- =========================================
-- طريقة التشغيل والاستخدام:
-- =========================================

local AngeliHub = Library:CreateWindow("Angeli UI - Slax Hub")

-- إنشاء التبويبات
local MainTab = AngeliHub:CreateTab("Main")
local VisualsTab = AngeliHub:CreateTab("Visuals")

-- إضافة أزرار ومفاتيح داخل تبويب Main
MainTab:CreateButton("Auto Farm", function()
    print("Auto Farm Activated")
end)

MainTab:CreateToggle("Enable Kill Aura", function(state)
    print("Kill Aura:", state)
end)

-- إضافة عناصر داخل تبويب Visuals
VisualsTab:CreateToggle("ESP Box", function(state)
    print("ESP Box:", state)
end)
