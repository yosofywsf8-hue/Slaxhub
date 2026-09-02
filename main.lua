local MacLib = loadstring(game:HttpGet("https://github.com/kal3b/Maclib/releases/latest/download/maclib.txt"))()

local Window = MacLib:Window({
    Title = "Slax Hub | Anime Edition",
    Subtitle = "by dev: yosef",
    Size = UDim2.fromOffset(600, 480),
    Dragable = true
})

local MainGroup = Window:TabGroup()

local MainTab = MainGroup:Tab({ Title = "Main", Image = "rbxassetid://10723407389" })
local SocialTab = MainGroup:Tab({ Title = "Socials", Image = "rbxassetid://10723346959" })

-- المتغيرات الأساسية
local AutoParry = false
local Accuracy = 100
local AutoSpam = false

-- ==================== [ إدراج صورة أنمي بنت HD ] ====================

task.spawn(function()
    task.wait(0.8)
    local coreGui = game:GetService("CoreGui")
    local maclibGui = coreGui:FindFirstChild("Maclib") or coreGui:FindFirstChildOfClass("ScreenGui")
    
    if maclibGui then
        local AnimeImage = Instance.new("ImageLabel")
        local UICorner = Instance.new("UICorner")
        local UIStroke = Instance.new("UIStroke")
        
        AnimeImage.Name = "AnimeGirlDisplay"
        AnimeImage.Size = UDim2.new(0, 110, 0, 110)
        AnimeImage.Position = UDim2.new(0.78, -10, 0.06, 0)
        AnimeImage.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        AnimeImage.Image = "rbxassetid://11713589000" -- صورة أنمي بنت بدقة عالية HD
        AnimeImage.ScaleType = Enum.ScaleType.Crop
        AnimeImage.ZIndex = 100
        AnimeImage.Parent = maclibGui
        
        UICorner.CornerRadius = UDim.new(0, 14)
        UICorner.Parent = AnimeImage

        UIStroke.Color = Color3.fromRGB(140, 90, 230)
        UIStroke.Thickness = 2
        UIStroke.Parent = AnimeImage
    end
end)

-- ==================== [ قسم Auto Parry ] ====================

local ParrySection = MainTab:Section({ Title = "Auto Parry Settings" })

ParrySection:Toggle({
    Title = "Auto Parry",
    Default = false,
    Callback = function(Value)
        AutoParry = Value
    end
})

ParrySection:Slider({
    Title = "Accuracy",
    Default = 100,
    Minimum = 1,
    Maximum = 100,
    DisplayMethod = "%",
    Callback = function(Value)
        Accuracy = Value
    end
})

ParrySection:Dropdown({
    Title = "Curve Type",
    Multi = false,
    Required = true,
    Options = {"Straight", "Curve", "Backwards"},
    Default = "Straight",
    Callback = function(Value)
    end
})

local SpamSection = MainTab:Section({ Title = "Spam Options" })

SpamSection:Toggle({
    Title = "Auto Spam",
    Default = false,
    Callback = function(Value)
        AutoSpam = Value
    end
})

-- ==================== [ قسم Socials ] ====================

local SocialSection = SocialTab:Section({ Title = "Developer Information" })

SocialSection:Label({
    Title = "DEV: yosef\nTelegram: @slaxscript\nDiscord: discord.gg/slaxhub\nTikTok: @slax_dev"
})

SocialSection:Button({
    Title = "Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/slaxhub")
        MacLib:Notification({
            Title = "Slax Hub",
            Description = "Copied Discord link to clipboard!",
            Lifetime = 3
        })
    end
})

MacLib:Notification({
    Title = "Slax Hub Loaded",
    Description = "Welcome to Slax Hub Anime Edition!",
    Lifetime = 4
})
