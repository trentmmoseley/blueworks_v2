-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local NVService       = Knit.CreateService({
    Name = "NightVisionService",
    Client = {
        NVToggle  = Knit.CreateSignal(),
    },

    -- When true, night vision is off for everyone and can no longer be toggled
    Disabled = false,
})

-- [[ funcs ]] --

-- Toggles NV
function NVService:ToggleNV(class : {}, on : boolean?)
    if class.Character:GetAttribute("NVBattery") > 0 then
        class:Toggle(on)
    else
        self.CommsService:SendSubtitle(nil, class.CharacterClass.Player, "Replace goggles' batteries", "Red")
    end
end

-- Permanently disables night vision: active goggles are turned off and all
-- further toggle requests are ignored
function NVService:Disable() : ()
    self.Disabled = true

    for _, class in self.CharService:GetAllCharClasses() do
        local NVClass = class.NVClass
        if NVClass and NVClass.doNightVision then
            NVClass:Toggle(false)
        end
    end
end

-- On knit init completion
function NVService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
    self.CommsService = _G.Knit.GetService("CommsService")

    -- On NV toggle
    self.Client.NVToggle:Connect(function(player : Player)
        if self.Disabled then return end
        if player.Team ~= game.Teams.Squadmates then return end
        if player:GetAttribute("InitiationActive") == true then return end
        local Character = player.Character or player.CharacterAdded:Wait()
        local Class = self.CharService:GetCharacterClass(Character)
        local NVClass = Class.NVClass
        self:ToggleNV(NVClass)
    end)
end

return NVService