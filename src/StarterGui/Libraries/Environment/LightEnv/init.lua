local LightEnv   = {}

-- Services
local Lighting   = game:GetService("Lighting")
local Players    = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Player
local Player     = Players.LocalPlayer
local Character  = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui  = Player.PlayerGui

-- Modules and objects
local EnvSounds  = PlayerGui.Sounds.Environment

local GameValues = RepStorage.GameValues
local TimeLeft   = GameValues.Numbers.TimeLeft

local LEInfo	 = require(script.LEInfo)
local Lerp       = require(RepStorage.Modules.Util.Math.Lerp)
local Progress   = require(RepStorage.Modules.Util.Math.Progress)

local Camera     = game.Workspace.CurrentCamera
local Sounds     = PlayerGui.Sounds.Environment

-- Vars and consts
local OUTDOOR_AMBIENT = Color3.fromRGB(40, 40, 58)
local INDOOR_AMBIENT  = Color3.fromRGB(19, 19, 33)

local isOutside       = false

-- [[ funcs ]] --

-- Updates ambience
local function updateAmbience()
    -- Determines if outside
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Character}
    
    local TheRay = game.Workspace:Raycast(Camera.CFrame.Position, Vector3.new(0, 100, 0), RayParams)
    isOutside = not ((TheRay and TheRay.Instance and (TheRay.Instance.Transparency < 0.5 or TheRay.Instance:FindFirstAncestor("Platform")) and (TheRay.Instance.CanCollide == true and (not string.find(TheRay.Instance.Name, "_playcicadas")) or TheRay.Instance:FindFirstAncestor("Doors"))))

    EnvSounds.AmbienceOutdoor.Volume = isOutside and 1/8 or 0
end

-- Updates lighting
local function updateLighting()
    local ProgToDark = Progress(TimeLeft.Value, TimeLeft:GetAttribute("Init"), 0)
    Lighting.ClockTime = Lerp(LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[1], LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[2], ProgToDark)
    Lighting.Ambient = INDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), ProgToDark)
    Lighting.OutdoorAmbient = OUTDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), ProgToDark)
end

-- Main function
function LightEnv.Function()
    -- Main conn
    updateLighting()
    TimeLeft.Changed:Connect(updateLighting)
    task.spawn(function()
        while true do
            updateAmbience()
            task.wait(1/4)
        end
    end)
end

return LightEnv