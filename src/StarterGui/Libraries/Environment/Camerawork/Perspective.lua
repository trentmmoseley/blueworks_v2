local Perspective = {}

-- Serivces
local Players     = game:GetService("Players")

-- Player
local Player      = Players.LocalPlayer
local Character   = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local Camera      = game.Workspace.CurrentCamera

-- Main function
function Perspective.Function(dt)
    local Grabbed = Character:GetAttribute("isGrabbed") == true
    Player.CameraMode = Enum.CameraMode[(Player.Team == game.Teams.Squadmates and not Character:GetAttribute("isDowned")) and "LockFirstPerson" or "Classic"]
    Camera.CameraType = Grabbed and Enum.CameraType.Scriptable or Enum.CameraType.Custom
end

return Perspective