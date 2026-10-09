-- Services
local Players      = game:GetService("Players")
local PlayerGui    = Players.LocalPlayer.PlayerGui

-- Modules and objects
local Camera       = game.Workspace.CurrentCamera
local Sounds       = PlayerGui.Sounds.Horror

-- Vars and consts
local SOUND_ORDER  = {"Far", "Medium", "Near"}

local Horror       = {

    ["Horror"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Intensity = args[1]
            Camera.FieldOfView += 10 * Intensity
            local SoundFolder = Sounds[SOUND_ORDER[Intensity]]:GetChildren()
            local ChosenSound = SoundFolder[math.random(1, #SoundFolder)]
            ChosenSound:Play()
        end,

    },

}

return Horror