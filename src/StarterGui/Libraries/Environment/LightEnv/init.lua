local LightEnv   = {}

-- Services
local CAS        = game:GetService("ContextActionService")
local Lighting   = game:GetService("Lighting")
local Players    = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataC      = _G.Knit.GetController("DataController")
local NVService  = _G.Knit.GetService("NightVisionService")

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

local Atmosphere = RepStorage.VFX.AtmosphericParts

local Camera     = game.Workspace.CurrentCamera
local Sounds     = PlayerGui.Sounds.Environment

local CC         : ColorCorrectionEffect = Lighting:WaitForChild("ColorCorrection")
local NVLight    = nil

-- Vars and consts
local OUTDOOR_AMBIENT = Color3.fromRGB(59, 59, 84)
local INDOOR_AMBIENT  = Color3.fromRGB(30, 30, 45)

local NV_DEFAULT      = Color3.fromHSV(0.4, 1, 1)

local isOutside       = false

local TOGGLE_NV       = "TOGGLE_NV"

-- [[ funcs ]] --

-- Toggles night vision
local function toggleNightVision(actionname, inputstate)
    if actionname == TOGGLE_NV and inputstate == Enum.UserInputState.Begin then
        NVService.NVToggle:Fire()
    end
end

-- Updates ambience
local function updateAmbience()
    -- Determines if outside
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Character}
    
    local TheRay = game.Workspace:Raycast(Camera.CFrame.Position, Vector3.new(0, 100, 0), RayParams)
    isOutside = not ((TheRay and TheRay.Instance and (TheRay.Instance.Transparency < 0.5 or TheRay.Instance:FindFirstAncestor("Platform")) and (TheRay.Instance.CanCollide == true and (not string.find(TheRay.Instance.Name, "_playcicadas")) or TheRay.Instance:FindFirstAncestor("Doors"))))

    EnvSounds.AmbienceOutdoor.Volume = isOutside and 1/8 or 0
    EnvSounds.AmbienceIndoor.Volume = not isOutside and 1/8 or 0

    -- Finds atmospheric particles if they already exist
	local TheseParticles = game.Workspace:FindFirstChild(Atmosphere.Name)
	if not TheseParticles then
		TheseParticles = Atmosphere:Clone()
		TheseParticles.Parent = game.Workspace
	end

    -- Atmospheric particles
	local ParticleOrigin = Camera.CFrame

    TheseParticles.Dust.ParticleEmitter.Enabled = not isOutside
    for _, part in pairs(TheseParticles:GetChildren()) do
        part.Position = ParticleOrigin.Position
    end

    for _, pr in pairs(TheseParticles.Rain:GetChildren()) do
        pr.Enabled = false
    end
    
    TheseParticles.Snow.ParticleEmitter.Enabled = false
end

-- Updates lighting
local function updateLighting()
    local ProgToDark = Progress(TimeLeft.Value, TimeLeft:GetAttribute("Init"), 0)
    Lighting.ClockTime = Lerp(LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[1], LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[2], ProgToDark)
    
    local doNV = Character:GetAttribute("doNightVision")
    if NVLight then
        NVLight.Enabled = doNV
    end

    if not doNV then
        Lighting.Ambient = INDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), ProgToDark)
        Lighting.OutdoorAmbient = OUTDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), ProgToDark)
        CC.Saturation = 0
        CC.TintColor = Color3.fromHSV(1, 0, 1)
    else
        Lighting.Ambient = NV_DEFAULT:Lerp(Color3.fromHSV(0, 0, 0), 0.4)
        Lighting.OutdoorAmbient = NV_DEFAULT:Lerp(Color3.fromHSV(0, 0, 0), 0.75)
        CC.Saturation = -1
        CC.TintColor = NV_DEFAULT
    end
end

-- Main function
function LightEnv.Function()
    NVLight = Instance.new("PointLight")
    NVLight.Name 		 = "NVLight"
    NVLight.Parent 		 = Character.PrimaryPart
    NVLight.Color 		 = Color3.fromHSV(0.4, 1, 1)
    NVLight.Brightness   = 2
    NVLight.Range		 = 20
    NVLight.Enabled      = false

    -- Main conn
    updateLighting()
    TimeLeft.Changed:Connect(updateLighting)
    task.spawn(function()
        while true do
            updateAmbience()
            task.wait(1/2)
        end
    end)

    -- Night vision
    CAS:BindAction(TOGGLE_NV, toggleNightVision, false, Enum.KeyCode[DataC:Get("Keybinds.NightVision.Keyboard")], Enum.KeyCode[DataC:Get("Keybinds.NightVision.Gamepad")])
    Character:GetAttributeChangedSignal("doNightVision"):Connect(updateLighting)
end

return LightEnv