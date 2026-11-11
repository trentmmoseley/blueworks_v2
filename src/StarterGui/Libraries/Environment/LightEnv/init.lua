local LightEnv   = {}

-- Services
local CAS        = game:GetService("ContextActionService")
local Lighting   = game:GetService("Lighting")
local Players    = game:GetService("Players")
local Rand       = Random.new()
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataC      = _G.Knit.GetController("DataController")
local NVService  = _G.Knit.GetService("NightVisionService")
local TweenService = game:GetService("TweenService")

-- Player
local Player     = Players.LocalPlayer
local Character  = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui  = Player.PlayerGui

-- Modules and objects
local EnvSounds  = PlayerGui.Sounds.Environment

local GameValues = RepStorage.GameValues
local TimeLeft   = GameValues.Numbers.TimeLeft
local WVal	     = GameValues.Strings.Weather

local LEInfo	 = require(script.LEInfo)
local Lerp       = require(RepStorage.Modules.Util.Math.Lerp)
local Progress   = require(RepStorage.Modules.Util.Math.Progress)

local Atmosphere = RepStorage.VFX.AtmosphericParts

local Camera     = game.Workspace.CurrentCamera
local Sounds     = PlayerGui.Sounds.Environment

local CC         : ColorCorrectionEffect = Lighting:WaitForChild("ColorCorrection")
local NVLight    = nil

local ATM        = Lighting.Atmosphere
local Clouds	 = game.Workspace.Terrain.Clouds

-- Vars and consts
local OUTDOOR_AMBIENT = Color3.fromRGB(59, 59, 84)
local INDOOR_AMBIENT  = Color3.fromRGB(30, 30, 45)

local NV_DEFAULT      = Color3.fromHSV(0.4, 1, 1)

local doLightning     = false
local isOutside       = false
local NextLightning   = 0

local TOGGLE_NV       = "TOGGLE_NV"

local RAIN_WEATHERS   = {"RAINY", "STORMY"}

local THUNDER_SOUNDS = {
	
	{7768751498, false}, -- id, do muffle indoors
	{7768747890, false},
	{7768750314, false},
	
	{5246104843, true},
	{6767192500, true},
	{5246103002, true},
	{4961240438, true},
	{6734393210, true},
	{6201159307, true}
	
}

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
        pr.Enabled = isOutside and table.find(RAIN_WEATHERS, WVal.Value)
    end

    -- Weather + atmosphere
    local initActive = Player:GetAttribute("InitiationActive")
	local WeatherInfo = LEInfo.Weather[GameValues.Strings.Weather.Value]

    -- Atmosphere
    for name, val in pairs(WeatherInfo.Atmosphere) do
        ATM[name] = ((name ~= "Density" or isOutside) and not initActive) and val or 0
    end
    
    -- Clouds
    for name, val in pairs(WeatherInfo.Clouds) do
        Clouds[name] = val
    end

    -- Lighting / thunder (if applicable)
    EnvSounds.Rain.Volume = (table.find(RAIN_WEATHERS, WVal.Value) and isOutside and GameValues.Numbers.Temperature.Value >= 1/3 and not initActive) and 1 or 0
    EnvSounds.Wind.Volume = (WVal.Value == "STORMY" and isOutside and not initActive) and 0.5 or 0
    
    TheseParticles.Snow.ParticleEmitter.Enabled = false

    -- Updates muffled thunder sounds
    for _, sound : Sound in PlayerGui:GetChildren() do
        if not sound:IsA("Sound") or sound.Name ~= "Thunder" or not sound:FindFirstChild("EqualizerSoundEffect") then continue end
        sound:FindFirstChildOfClass("EqualizerSoundEffect").Enabled = not isOutside
    end
end

-- Gets desired ambient lighting
local function getAmbient(doNV, progtodark) : (Color3, Color3)
    if not doNV then
        return INDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), progtodark), OUTDOOR_AMBIENT:Lerp(Color3.fromHSV(0, 0, 0), progtodark)
    else
        return NV_DEFAULT:Lerp(Color3.fromHSV(0, 0, 0), 0.4), NV_DEFAULT:Lerp(Color3.fromHSV(0, 0, 0), 0.75)
    end
end

-- Updates lighting
local function updateLighting()
    local ProgToDark = Progress(TimeLeft.Value, TimeLeft:GetAttribute("Init"), 0)
    Lighting.ClockTime = Lerp(LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[1], LEInfo.TimeOfDay[GameValues.Strings.TimeOfDay.Value].ClockTime[2], ProgToDark)
    
    local doNV = Character:GetAttribute("doNightVision")
    if NVLight then
        NVLight.Enabled = doNV
    end

    local IndoorA, OutdoorA = getAmbient(doNV, ProgToDark)
    Lighting.Ambient = IndoorA
    if not doLightning then
        Lighting.OutdoorAmbient = OutdoorA
    end

    if not doNV then
        CC.Saturation = 0
        CC.TintColor = Color3.fromHSV(1, 0, 1)
    else
        CC.Saturation = -1
        CC.TintColor = NV_DEFAULT
    end

    -- Lighting if applicable
    if os.clock() >= NextLightning and WVal.Value == "STORMY" then
        NextLightning = os.clock() + Rand:NextNumber(5, 45)

        task.delay(Rand:NextNumber() * 10, function()
            local ChosenSound = THUNDER_SOUNDS[math.random(1, #THUNDER_SOUNDS)]
            local NewSound = Instance.new("Sound")
            NewSound.Name = "Thunder"
            NewSound.Volume = 1
            NewSound.SoundId = "rbxassetid://"..ChosenSound[1]
            NewSound.Parent = PlayerGui
            
            if ChosenSound[2] then
                local NewMuffler = Instance.new("EqualizerSoundEffect")
                NewMuffler.HighGain = -60
                NewMuffler.LowGain = 20
                NewMuffler.MidGain = -20
                NewMuffler.Parent = NewSound

                NewMuffler.Enabled = not isOutside
            end
            
            NewSound.PlaybackSpeed = Rand:NextNumber(0.9, 1.05)
            NewSound:Play()
            game:GetService("Debris"):AddItem(NewSound, 30)
        end)

        task.defer(function()
            for _ = 1, 7 do
                doLightning = true
                local FlashLength = Rand:NextNumber() * 3/8
                Lighting.OutdoorAmbient = Color3.fromRGB(191, 170, 255)
                TweenService:Create(Lighting, TweenInfo.new(FlashLength), {OutdoorAmbient = OutdoorA}):Play()
                task.wait(FlashLength)
                doLightning = false
            end
        end)
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