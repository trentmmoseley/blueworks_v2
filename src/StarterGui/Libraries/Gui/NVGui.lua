local StaminaBar     = {}

-- Services
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local Character      = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local NVSounds       = PlayerGui.Sounds.NightVision

local Battery        = TheGui.Battery

-- [[ funcs ]] --

-- Toggles UI
local function toggleUI()
    local doVN = Character:GetAttribute("doNightVision") == true and Player.Team == game.Teams.Squadmates
    TheGui.Enabled = doVN

    if doVN then
        TheGui._static.ImageTransparency = 0
        TweenService:Create(TheGui._static, TweenInfo.new(1/2), {ImageTransparency = 0.925}):Play()
        NVSounds.Activate.Activate.TimePosition = 0.5
        NVSounds.Activate.Activate:Play()
        task.wait(0.1)
        NVSounds.Activate.Whirr.TimePosition = 1/5
        NVSounds.Activate.Whirr:Play()
    else
        NVSounds.Deactivate.TimePosition = 0.5
        NVSounds.Deactivate:Play()
    end
end

-- Main function
function StaminaBar.Function()
    toggleUI()
    Character:GetAttributeChangedSignal("doNightVision"):Connect(toggleUI)

    task.spawn(function()
        while true do
            local BatteryLife = (Character:GetAttribute("NVBattery") or 0) / (Character:GetAttribute("MaxNVBattery") or 1)
            for i = 1, 4 do
                Battery.Counters["Counter"..i].BackgroundTransparency = (BatteryLife * 5 >= i) and 0 or 1
            end

            Battery.Visible = BatteryLife > 0.2 or not Battery.Visible
            task.wait(1/2)
        end
    end)
end

return StaminaBar