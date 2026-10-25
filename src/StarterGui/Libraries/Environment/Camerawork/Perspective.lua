local Perspective = {}

-- Serivces
local Players     = game:GetService("Players")
local RepStorage  = game:GetService("ReplicatedStorage")

-- Player
local Player      = Players.LocalPlayer
local Character   = Player.Character or Player.CharacterAdded:Wait()
local Humanoid    = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local Camera      = game.Workspace.CurrentCamera

local Lerp        = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- Vars and consts
local WasGrabbed  = Character:GetAttribute("isGrabbed") == true

-- [[ funcs ]] --

local function restoreCamera()
    Player.CameraMode = Enum.CameraMode[(Player.Team == game.Teams.Squadmates and not Character:GetAttribute("isDowned")) and "LockFirstPerson" or "Classic"]
    Camera.CameraType = Enum.CameraType.Custom

    if Humanoid then
        Camera.CameraSubject = Humanoid
    end
    if Character.PrimaryPart then
        Camera.Focus = Character.PrimaryPart.CFrame
    end

    local Head = Character:FindFirstChild("Head")
    if Head then
        Camera.CFrame = Head.CFrame
    end
end

-- Main function
function Perspective.Function(dt)
    local QuarterLerp = LerpByFrame(1/4, dt)

    local Grabbed = Character:GetAttribute("isGrabbed") == true
    local GrabAttacker = Character:FindFirstChild("ProxyGrabAttacker")
    local Attacker = GrabAttacker and GrabAttacker:IsA("ObjectValue") and GrabAttacker.Value or nil
    local AttackerHead = Attacker and Attacker:FindFirstChild("Head")

    -- While seated at a node the Node camera module owns the camera; Classic mode frees the mouse for puzzle buttons
    local Seated = (Character:GetAttribute("NodeID") or 0) > 0
    if Seated then
        Player.CameraMode = Enum.CameraMode.Classic
        WasGrabbed = Grabbed
        return
    end

    if not Grabbed and (WasGrabbed or Camera.CameraType == Enum.CameraType.Scriptable) then
        restoreCamera()
    else
        Player.CameraMode = Enum.CameraMode[(Player.Team == game.Teams.Squadmates and not Character:GetAttribute("isDowned")) and "LockFirstPerson" or "Classic"]
        Camera.CameraType = Grabbed and Enum.CameraType.Scriptable or Enum.CameraType.Custom
    end
    WasGrabbed = Grabbed

    if AttackerHead then
        -- Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, AttackerHead.CFrame.Position), QuarterLerp)
    end
end

return Perspective