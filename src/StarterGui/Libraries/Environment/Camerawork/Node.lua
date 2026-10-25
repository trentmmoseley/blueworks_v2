local NodeCam           = {}

-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")

-- Player
local Player            = Players.LocalPlayer
local Character         = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local Camera            : Camera = game.Workspace.CurrentCamera
local Node              : Model? = nil

local Lerp              = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame       = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- [[ funcs ]] --

-- Getting node by ID
local function getNode(id : number) : Model?
    local Playspace = game.Workspace:FindFirstChild("Playspace")
    local Folder    = Playspace and Playspace:FindFirstChild("Interactables") and Playspace.Interactables:FindFirstChild("Nodes")
    if Folder then
        for _, node : Model in Folder:GetChildren() do
            if node:GetAttribute("NodeID") == id then
                return node
            end
        end
    end
end

-- Main function
function NodeCam.Function(dt)
    local QuarterLerp = LerpByFrame(1/4, dt)
    local NodeID = Character and Character:GetAttribute("NodeID") or 0
    if Player.Team == game.Teams.Squadmates and NodeID > 0 then
        if not Node then
            Node = getNode(NodeID)
            if not Node then return end
            Camera.CameraType = Enum.CameraType.Scriptable
        end

        Camera.CFrame = Camera.CFrame:Lerp((Node.PrimaryPart.CFrame + Node.PrimaryPart.CFrame.LookVector * 4) * CFrame.Angles(0, math.pi, 0), QuarterLerp)
        Camera.FieldOfView = Lerp(Camera.FieldOfView, 50, QuarterLerp)
    else
        if Node then
            Camera.CameraType = Enum.CameraType.Custom
            Node = nil
        end
    end
end

-- Rebinds character on respawn
Player.CharacterAdded:Connect(function(char : Model)
    Character = char
end)

return NodeCam
