local Perspective = {}

-- Serivces
local Players     = game:GetService("Players")

-- Player
local Player      = Players.LocalPlayer
local Character   = Player.Character or Player.CharacterAdded:Wait()

-- Main function
function Perspective.Function(dt)
    Player.CameraMode = Enum.CameraMode[Player.Team == game.Teams.Squadmates and "LockFirstPerson" or "Classic"]
end

return Perspective