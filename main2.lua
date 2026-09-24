-- =========================================
-- 🎯 PREMIUM FLOATING TRIGGERBOT BUTTON
-- =========================================
local TriggerGui = Instance.new("ScreenGui")
TriggerGui.Name = "SlaxTriggerBotGui"
TriggerGui.Parent = CoreGui
TriggerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TriggerGui.ResetOnSpawn = false
TriggerGui.IgnoreGuiInset = true

-- الحاوية الرئيسية (شفافة - للسحب والظل)
local BtnContainer = Instance.new("Frame")
BtnContainer.Name = "Container"
BtnContainer.Parent = TriggerGui
BtnContainer.BackgroundTransparency = 1
BtnContainer.Size = UDim2.new(0, 150, 0, 50)
BtnContainer.Position = UDim2.new(0.05, 0, 0.5, 0)

-- زر أساسي
local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name = "TriggerBtn"
TriggerBtn.Parent = BtnContainer
TriggerBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
TriggerBtn.BorderSizePixel = 0
TriggerBtn.Position = UDim2.new(0, 0, 0, 0)
TriggerBtn.Size = UDim2.new(1, 0, 1, 0)
TriggerBtn.Font = Enum.Font.GothamBold
TriggerBtn.Text = ""
TriggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerBtn.AutoButtonColor = false
TriggerBtn.ClipsDescendants = true

-- زوايا دائرية
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = TriggerBtn

-- تدرج لوني (Gradient)
local Gradient = Instance.new("UIGradient")
Gradient.Parent = TriggerBtn
Gradient.Rotation = 45
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(45, 48, 70)),   -- رمادي مزرق
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(35, 38, 55)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(25, 28, 42))
})

-- حدود (Stroke) فاخرة
local Stroke = Instance.new("UIStroke")
Stroke.Parent = TriggerBtn
Stroke.Color = Color3.fromRGB(90, 100, 140)
Stroke.Thickness = 1
Stroke.Transparency = 0.3
Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- توهج خارجي (Glow Effect)
local GlowStroke = Instance.new("UIStroke")
GlowStroke.Parent = TriggerBtn
GlowStroke.Color = Color3.fromRGB(120, 130, 255)
GlowStroke.Thickness = 4
GlowStroke.Transparency = 1
GlowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ============ ICON ============
local IconLabel = Instance.new("TextLabel")
IconLabel.Name = "Icon"
IconLabel.Parent = TriggerBtn
IconLabel.BackgroundTransparency = 1
IconLabel.Position = UDim2.new(0, 12, 0, 0)
IconLabel.Size = UDim2.new(0, 28, 1, 0)
IconLabel.Font = Enum.Font.GothamBold
IconLabel.Text = "🎯"
IconLabel.TextColor3 = Color3.fromRGB(200, 210, 255)
IconLabel.TextSize = 22
IconLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ============ TEXT ============
local TextLabel = Instance.new("TextLabel")
TextLabel.Name = "Label"
TextLabel.Parent = TriggerBtn
TextLabel.BackgroundTransparency = 1
TextLabel.Position = UDim2.new(0, 42, 0, 0)
TextLabel.Size = UDim2.new(1, -50, 0, 22)
TextLabel.Font = Enum.Font.GothamBold
TextLabel.Text = "TRIGGER"
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize = 13
TextLabel.TextXAlignment = Enum.TextXAlignment.Left
TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom

-- ============ STATUS ============
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Parent = TriggerBtn
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 42, 0, 20)
StatusLabel.Size = UDim2.new(1, -50, 0, 18)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "● OFF"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top

-- ============ DOT INDICATOR ============
local Dot = Instance.new("Frame")
Dot.Name = "Dot"
Dot.Parent = TriggerBtn
Dot.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
Dot.BorderSizePixel = 0
Dot.Position = UDim2.new(1, -18, 0.5, -4)
Dot.Size = UDim2.new(0, 8, 0, 8)

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = Dot

local DotStroke = Instance.new("UIStroke")
DotStroke.Parent = Dot
DotStroke.Color = Color3.fromRGB(255, 90, 90)
DotStroke.Thickness = 3
DotStroke.Transparency = 1

-- ============ نظام السحب ============
local dragging, dragInput, dragStart, startPos
local dragMoved = false
local pressStart = 0

BtnContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        pressStart = tick()
        dragStart = input.Position
        startPos = BtnContainer.Position
        
        -- تأثير الضغط
        game:GetService("TweenService"):Create(TriggerBtn, TweenInfo.new(0.1), {
            Size = UDim2.new(0.95, 0, 0.9, 0)
        }):Play()
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                -- رجوع الحجم
                game:GetService("TweenService"):Create(TriggerBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()
            end
        end)
    end
end)

BtnContainer.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
            dragMoved = true
        end
        BtnContainer.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============ دالة تحديث المظهر ============
local TweenService = game:GetService("TweenService")
local isAnimating = false

local function UpdateTriggerBtnVisual()
    if TriggerbotEnabled then
        -- 🟢 مفعل - أخضر نيون
        TweenService:Create(Gradient, TweenInfo.new(0.4), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 80, 60)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(15, 60, 45)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 45, 35))
            })
        }):Play()
        
        TweenService:Create(Stroke, TweenInfo.new(0.4), {
            Color = Color3.fromRGB(80, 255, 160),
            Transparency = 0.1
        }):Play()
        
        TweenService:Create(GlowStroke, TweenInfo.new(0.4), {
            Color = Color3.fromRGB(80, 255, 160),
            Transparency = 0.6
        }):Play()
        
        TweenService:Create(IconLabel, TweenInfo.new(0.4), {
            TextColor3 = Color3.fromRGB(150, 255, 200)
        }):Play()
        
        TweenService:Create(StatusLabel, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(120, 255, 180),
            Text = "● ACTIVE"
        }):Play()
        
        TweenService:Create(Dot, TweenInfo.new(0.3), {
            BackgroundColor3 = Color3.fromRGB(80, 255, 160)
        }):Play()
        
        TweenService:Create(DotStroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(80, 255, 160)
        }):Play()
        
        TextLabel.TextColor3 = Color3.fromRGB(200, 255, 220)
        
        -- نبض ضوئي متكرر
        if not isAnimating then
            isAnimating = true
            task.spawn(function()
                while TriggerbotEnabled and isAnimating do
                    TweenService:Create(GlowStroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                        Transparency = 0.85
                    }):Play()
                    task.wait(1)
                    if not TriggerbotEnabled then break end
                    TweenService:Create(GlowStroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                        Transparency = 0.5
                    }):Play()
                    task.wait(1)
                end
                isAnimating = false
            end)
        end
    else
        -- 🔴 معطل - رمادي داكن
        TweenService:Create(Gradient, TweenInfo.new(0.4), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(45, 48, 70)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(35, 38, 55)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(25, 28, 42))
            })
        }):Play()
        
        TweenService:Create(Stroke, TweenInfo.new(0.4), {
            Color = Color3.fromRGB(90, 100, 140),
            Transparency = 0.3
        }):Play()
        
        TweenService:Create(GlowStroke, TweenInfo.new(0.4), {
            Color = Color3.fromRGB(120, 130, 255),
            Transparency = 1
        }):Play()
        
        TweenService:Create(IconLabel, TweenInfo.new(0.4), {
            TextColor3 = Color3.fromRGB(200, 210, 255)
        }):Play()
        
        TweenService:Create(StatusLabel, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(255, 100, 100),
            Text = "● OFF"
        }):Play()
        
        TweenService:Create(Dot, TweenInfo.new(0.3), {
            BackgroundColor3 = Color3.fromRGB(255, 90, 90)
        }):Play()
        
        TweenService:Create(DotStroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(255, 90, 90)
        }):Play()
        
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ============ تفعيل عند الضغط ============
TriggerBtn.MouseButton1Click:Connect(function()
    if not dragMoved and (tick() - pressStart) < 0.5 then
        TriggerbotEnabled = not TriggerbotEnabled
        UpdateTriggerBtnVisual()
        if TriggerToggle then
            TriggerToggle:SetValue(TriggerbotEnabled)
        end
    end
end)

-- مزامنة مع Toggle
local oldOnChanged = nil

-- تهيئة أولية
UpdateTriggerBtnVisual()
