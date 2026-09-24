-- =========================================
-- 🎯 PREMIUM FLOATING TRIGGERBOT BUTTON (Fixed)
-- =========================================
local TweenService = game:GetService("TweenService")

local TriggerGui = Instance.new("ScreenGui")
TriggerGui.Name = "SlaxTriggerBotGui"
TriggerGui.Parent = CoreGui
TriggerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TriggerGui.ResetOnSpawn = false
TriggerGui.IgnoreGuiInset = true

local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name = "TriggerBtn"
TriggerBtn.Parent = TriggerGui
TriggerBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 55)
TriggerBtn.BorderSizePixel = 0
TriggerBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
TriggerBtn.Size = UDim2.new(0, 150, 0, 50)
TriggerBtn.Font = Enum.Font.GothamBold
TriggerBtn.Text = ""
TriggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerBtn.AutoButtonColor = false
TriggerBtn.Active = true

-- زوايا دائرية
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = TriggerBtn

-- تدرج لوني
local Gradient = Instance.new("UIGradient")
Gradient.Parent = TriggerBtn
Gradient.Rotation = 45
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(45, 48, 70)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(35, 38, 55)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(25, 28, 42))
})

-- الحدود
local Stroke = Instance.new("UIStroke")
Stroke.Parent = TriggerBtn
Stroke.Color = Color3.fromRGB(90, 100, 140)
Stroke.Thickness = 1
Stroke.Transparency = 0.3

-- التوهج
local GlowStroke = Instance.new("UIStroke")
GlowStroke.Parent = TriggerBtn
GlowStroke.Color = Color3.fromRGB(120, 130, 255)
GlowStroke.Thickness = 4
GlowStroke.Transparency = 1

-- الأيقونة
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

-- النص الرئيسي
local MainText = Instance.new("TextLabel")
MainText.Name = "MainText"
MainText.Parent = TriggerBtn
MainText.BackgroundTransparency = 1
MainText.Position = UDim2.new(0, 42, 0, 6)
MainText.Size = UDim2.new(1, -55, 0, 22)
MainText.Font = Enum.Font.GothamBold
MainText.Text = "TRIGGER"
MainText.TextColor3 = Color3.fromRGB(255, 255, 255)
MainText.TextSize = 13
MainText.TextXAlignment = Enum.TextXAlignment.Left
MainText.TextYAlignment = Enum.TextYAlignment.Center

-- الحالة
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Parent = TriggerBtn
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 42, 0, 24)
StatusLabel.Size = UDim2.new(1, -55, 0, 18)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "● OFF"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Center

-- النقطة المضيئة
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

-- ============ نظام السحب ============
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local dragMoved = false
local pressStartTime = 0

TriggerBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        pressStartTime = tick()
        dragStart = input.Position
        startPos = TriggerBtn.Position
        
        TweenService:Create(TriggerBtn, TweenInfo.new(0.1), {
            Size = UDim2.new(0, 145, 0, 48)
        }):Play()
        
        local endConn
        endConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                TweenService:Create(TriggerBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
                    Size = UDim2.new(0, 150, 0, 50)
                }):Play()
                if endConn then endConn:Disconnect() end
            end
        end)
    end
end)

TriggerBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
            dragMoved = true
        end
        TriggerBtn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============ تحديث المظهر ============
local pulseActive = false

local function UpdateTriggerBtnVisual()
    if TriggerbotEnabled then
        -- 🟢 مفعل
        TweenService:Create(TriggerBtn, TweenInfo.new(0.4), {
            BackgroundColor3 = Color3.fromRGB(15, 60, 45)
        }):Play()
        
        TweenService:Create(Gradient, TweenInfo.new(0.4), {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(25, 90, 65)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(15, 65, 48)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 50, 38))
            })
        }):Play()
        
        TweenService:Create(Stroke, TweenInfo.new(0.4), {
            Color = Color3.fromRGB(80, 255, 160),
            Transparency = 0.1
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
        
        MainText.TextColor3 = Color3.fromRGB(200, 255, 220)
        
        -- نبض ضوئي
        if not pulseActive then
            pulseActive = true
            task.spawn(function()
                while TriggerbotEnabled do
                    TweenService:Create(GlowStroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                        Color = Color3.fromRGB(80, 255, 160),
                        Transparency = 0.85
                    }):Play()
                    task.wait(1)
                    if not TriggerbotEnabled then break end
                    TweenService:Create(GlowStroke, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                        Transparency = 0.4
                    }):Play()
                    task.wait(1)
                end
                pulseActive = false
            end)
        end
    else
        -- 🔴 معطل
        TweenService:Create(TriggerBtn, TweenInfo.new(0.4), {
            BackgroundColor3 = Color3.fromRGB(35, 38, 55)
        }):Play()
        
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
        
        MainText.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ============ الضغط ============
TriggerBtn.MouseButton1Click:Connect(function()
    if not dragMoved and (tick() - pressStartTime) < 0.8 then
        TriggerbotEnabled = not TriggerbotEnabled
        UpdateTriggerBtnVisual()
        if TriggerToggle then
            TriggerToggle:SetValue(TriggerbotEnabled)
        end
    end
end)

-- تهيئة أولية
UpdateTriggerBtnVisual()
