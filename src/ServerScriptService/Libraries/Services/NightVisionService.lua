-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local NVService       = Knit.CreateService({
    Name = "NightVisionService",
    Client = {
        NVToggle  = Knit.CreateSignal(),
    }
})

-- [[ funcs ]] --

-- Toggles NV
function NVService:ToggleNV(class : {}, on : boolean?)
    class:Toggle(on)
end

-- On knit init completion
function NVService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")

    -- On NV toggle
    self.Client.NVToggle:Connect(function(player : Player)
        if player.Team ~= game.Teams.Squadmates then return end
        local Character = player.Character or player.CharacterAdded:Wait()
        local Class = self.CharService:GetCharacterClass(Character)
        local NVClass = Class.NVClass
        self:ToggleNV(NVClass)
    end)
end

return NVService