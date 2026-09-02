-- ==========================================
-- 📱 BLADE BALL MOBILE SCRIPT (V4)
-- Optimized for Delta/Hydrogen/Fluxus
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- --- CONFIGURATION ---
local Config = {
    SwingDelayMin = 0.15, -- Slightly slower for mobile stability
    SwingDelayMax = 0.30,
    Mode = "Remote", -- "Remote" is faster, "Input" is safer
    ToggleKey = Enum.KeyCode.G -- Use G to toggle (or tap screen if supported)
}

-- --- VARIABLES ---
local LocalPlayer = Players.LocalPlayer
local SwingEvent = nil
local IsActive = false
local LastSwingTime = 0

-- --- FIND EVENT ---
local function findSwingEvent()
    local names = {"Swing", "SwingBall", "Attack"}
    for _, name in ipairs(names) do
        local event = ReplicatedStorage:FindFirstChild(name)
        if event then
            SwingEvent = event
            return true
        end
    end
    print("⚠️ Swing Event not found directly.")
    return false
end

-- --- SWING LOGIC ---
local function performSwing()
    if not IsActive then return end
    
    local now = tick()
    local delay = math.random(Config.SwingDelayMin * 100, Config.SwingDelayMax * 100) / 100
    
    if (now - LastSwingTime) < Config.SwingDelayMin then
        return
    end
    
    if Config.Mode == "Remote" and SwingEvent then
        SwingEvent:FireServer()
    else
        -- Fallback: Simulate Spacebar press
        UserInputService:KeyDown("Space")
        task.wait(0.05)
        UserInputService:KeyUp("Space")
    end
    
    LastSwingTime = tick()
end

-- --- MAIN LOOP ---
findSwingEvent()

print("📱 Mobile Script Loaded! Press 'G' to Toggle.")

while task.wait(0.1) do
    if IsActive then
        performSwing()
    end
end

-- --- TOGGLE ---
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey then
        IsActive = not IsActive
        print("🟢 ON" .. (IsActive and "" or " OFF"))
    end
end)
