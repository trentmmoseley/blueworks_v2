local Perspective = {}

-- Serivces
local Players     = game:GetService("Players")
local RepStorage  = game:GetService("ReplicatedStorage")

-- Player
local Player      = Players.LocalPlayer
local Character   = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local Camera      = game.Workspace.CurrentCamera

local Lerp        = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- Main function
function Perspective.Function(dt)
    local QuarterLerp = LerpByFrame(1/4, dt)

    local Grabbed = Character:GetAttribute("isGrabbed") == true
    local GrabAttacker = Character:FindFirstChild("ProxyGrabAttacker")
    local GrabWindup = GrabAttacker and GrabAttacker:IsA("ObjectValue") and GrabAttacker.Value ~= nil

    Player.CameraMode = Enum.CameraMode[(Player.Team == game.Teams.Squadmates and not Character:GetAttribute("isDowned")) and "LockFirstPerson" or "Classic"]
    Camera.CameraType = Grabbed and Enum.CameraType.Scriptable or Enum.CameraType.Custom

    if GrabWindup then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, GrabWindup and GrabAttacker.Value.Head.CFrame.Position), QuarterLerp)
    end
end

return Perspective