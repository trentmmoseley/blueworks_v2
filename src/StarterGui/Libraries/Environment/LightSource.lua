local LightSource    = {}

-- Services
local CAS		     = game:GetService("ContextActionService")
local Players		 = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local UIS			 = game:GetService("UserInputService")

local DataController = _G.Knit.GetController("DataController")

-- Player
local Player		 = Players.LocalPlayer

-- Modules and objects
local Rand			 = Random.new()
local Camera	     = game.Workspace.CurrentCamera

local LightSources   = RepStorage.PlayerRep:WaitForChild("LightSources")

local Lerp		 	 = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame	 = require(RepStorage.Modules.Util.Math.LerpByFrame)
local TrigWave	 	 = require(RepStorage.Modules.Util.Math.TrigWave)
local Spring	     = require(RepStorage.Modules.Util.Spring)

local LSPart	     = Camera:FindFirstChild("LSPart")
if LSPart then
	LSPart:Destroy()
end

LSPart			     = Instance.new("Part")
LSPart.Anchored		 = true
LSPart.CanCollide    = false
LSPart.CanQuery      = false
LSPart.CanTouch	     = false
LSPart.Transparency  = 1
LSPart.Parent	     = Camera

local LSInfo		 = nil

-- Vars and consts
local FL_MOVE_INFO   = {
	
	["WALK"]		 = {
		
		["BobA"]	 = 1,
		["BobB"]	 = 1,
		["Depth"]	 = 3, -- angle in degrees
		
	},
	
	["RUN"]			 = {

		["BobA"]	 = 0.75,
		["BobB"]	 = 2/3,
		["Depth"]	 = 20, -- angle in degrees

	},
	
	["CROUCH"]		 = {

		["BobA"]	 = 1,
		["BobB"]	 = 2,
		["Depth"]	 = 0.5, -- angle in degrees

	},
	
	["CRAWL"]		 = {

		["BobA"]	 = 0.5,
		["BobB"]	 = math.huge,
		["Depth"]	 = 0, -- angle in degrees

	},
	
	["DOWNED"]		 = {

		["BobA"]	 = 0.5,
		["BobB"]	 = math.huge,
		["Depth"]	 = 0, -- angle in degrees

	},
	
	["SLIDE"]		 = {

		["BobA"]	 = 0.5,
		["BobB"]	 = math.huge,
		["Depth"]	 = 0, -- angle in degrees

	},
	
}

local FLDepth		 = 0
local LightTilt		 = CFrame.Angles(0, 0, 0)

local TOGGLE_FL		 = "TOGGLE_FL"
local LIGHT_TREMBLE	 = 0.5

local FLActAngle	 = 360
local lastLS		 = false
local uLS			 = false

local CurrentModel	 = nil
local CurrentLight	 = nil
local CurrentToggle	 = nil

-- [[ funcs ]] --

-- Toggles flashlight
local function toggleFlashlight(actionname, inputstate)
	if actionname == TOGGLE_FL then
		if inputstate == Enum.UserInputState.Begin then
			uLS = not uLS
		end
	end
end

-- Updates part
local function updatePart(dt, sway, Character)
	LSPart.CFrame = Camera.CFrame
	if LSInfo then
		LSPart.CFrame += Camera.CFrame.LookVector * LSInfo["LVOffset"]
	end
	
	-- Sway
	local MoveInfo = FL_MOVE_INFO[Character:GetAttribute("MovementType")] or FL_MOVE_INFO["WALK"]
	local isMoving = Character:GetAttribute("rawInputDetected") == true
	local inAir	= Character:GetAttribute("inAir") == true

	FLDepth = Lerp(FLDepth, MoveInfo["Depth"] * ((isMoving and not inAir) and 1 or 0), LerpByFrame(0.05, dt))
	local MouseDelta = UIS:GetMouseDelta()
	sway:shove(Vector3.new(-MouseDelta.X + Rand:NextNumber(-1, 1) * LIGHT_TREMBLE / 2, MouseDelta.Y + Rand:NextNumber(-1, 1) * LIGHT_TREMBLE / 2, 0))
	
	if uLS then
		if lastLS ~= uLS then
			sway:shove(Vector3.new(Rand:NextNumber(-FLActAngle, FLActAngle), Rand:NextNumber(-FLActAngle, FLActAngle), Rand:NextNumber(-FLActAngle, FLActAngle)))
		end
		FLActAngle = 0
	end
	
	FLActAngle = Lerp(FLActAngle, 180, LerpByFrame(0.00005, dt))
	CurrentLight.Enabled = uLS
	
	if lastLS ~= uLS then
		CurrentToggle:Play()
	end
	
	local UpdatedSway = sway:update(dt)
	
	LightTilt = LightTilt:Lerp(CFrame.Angles(-math.rad(FLDepth + FLDepth * -math.abs(TrigWave("sin", MoveInfo["BobA"], MoveInfo["BobB"], os.clock(), 0, 0))), 0, 0), LerpByFrame(0.25, dt))
	LSPart.CFrame *= CFrame.new(UpdatedSway.X, UpdatedSway.Y, 0)
	LSPart.CFrame *= LightTilt
	
	lastLS = uLS
end

-- Attaches light source
local function attachLightSource()
	local FoundLS = LightSources:FindFirstChild(Player:GetAttribute("LightSource") or "Flashlight")
	FoundLS = FoundLS or LightSources:FindFirstChildWhichIsA("BasePart")
	
	if FoundLS then
		LSInfo = FoundLS:FindFirstChild("LSInfo") and require(FoundLS.LSInfo) or nil
		
		CurrentModel = FoundLS:Clone()
		CurrentModel.Parent = LSPart
		CurrentModel.CFrame = LSPart.CFrame
		
		local Weld = Instance.new("Motor6D")
		Weld.Part0 = CurrentModel
		Weld.Part1 = LSPart
		Weld.C0 = Weld.Part0.CFrame
		Weld.C1 = Weld.Part1.CFrame
		Weld.Parent = LSPart
		
		-- Light
		CurrentLight = CurrentModel:FindFirstChild("_light", true)
		CurrentToggle = CurrentModel:FindFirstChild("_toggle", true)
		
		if not CurrentLight or not CurrentToggle then
			CurrentModel:Destroy()
			CurrentModel, CurrentLight, CurrentToggle = nil, nil, nil
			return
		end
		
		CurrentToggle.Parent = LSPart
		CurrentLight.Enabled = uLS
	end
end

-- Detaches light source
local function detachLightSource()
	if CurrentToggle then
		CurrentToggle:Destroy()
		CurrentToggle = nil
	end
	
	if CurrentModel then
		CurrentModel:Destroy()
		CurrentModel = nil
	end
	
	CurrentLight = nil
end

-- Main function
function LightSource.Function()
	DataController:AwaitLoaded()
	
	local Sway = Spring()
	
	-- Sets up keybinds
	local Keybinds = { Enum.KeyCode[DataController:Get("Keybinds.Flashlight.Keyboard")] }
	local FL_GP = DataController:Get("Keybinds.Flashlight.Gamepad")
	if FL_GP then
		table.insert(Keybinds, Enum.KeyCode[FL_GP])
	end
	
	CAS:BindAction(TOGGLE_FL, toggleFlashlight, true, unpack(Keybinds))
	CAS:SetTitle(TOGGLE_FL, "Light")
	
	RunService.RenderStepped:Connect(function(dt)
		local Character = Player.Character
		
		if Player.Team == game.Teams.Squadmates and Player.CameraMode == Enum.CameraMode.LockFirstPerson and Character then
			if not CurrentLight then
				attachLightSource()
			end
			
			if CurrentLight then
				updatePart(dt, Sway, Character)
			end
		else
			if CurrentLight then
				detachLightSource()
			end
		end
	end)
end

return LightSource
