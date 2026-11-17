local SanityGui = {}

--// Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--// Player
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Sounds = PlayerGui.Sounds.Sanity

--// Modules / Objects
local TheGui = PlayerGui:WaitForChild(script.Name)
local Camera = Workspace.CurrentCamera
local Characters = Workspace:WaitForChild("Characters")

local Frame = TheGui.Frame
local Static = TheGui._static

local TetheredDoc = require(RepStorage.Modules.Data.Documents.Tethered)

local SanityCC : ColorCorrectionEffect = Lighting:FindFirstChild("SanityCC")

local Lerp        = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress    = require(RepStorage.Modules.Util.Math.Progress)
local VFX		= require(PlayerGui.Libraries.Environment.VFX.Tethered)

--// Constants
local Rand = Random.new()

local STATIC_POW = {1, 3, 9}

local ENTITY_NAME = "Tethered"
local ENTITY_RANGE = 50
local MAX_DISTANCE = 99999

-- Proximity calculations do not need to happen every rendered frame.
-- Adjust this depending on how responsive you want the effect to feel.
local PROXIMITY_UPDATE_RATE = 1 / 20

--// State
local Character
local RootPart

local Sanity = 100
local MaxSanity = 100

local SanityProgress = 0
local ProximityDistortion = 0
local MIN_MS_VOL		   = 0

local EntityCount = 0
local EntityPresent = false

local Running = false
local Connections = {}

local MIN_PART_CD	  = 0.5
local MAX_PART_CD	  = 10

local NextDP		  = os.clock()
local NextTB		  = os.clock()
local NextMsg 		  = os.clock()

local TETHERED_TAUNT	  =  {
	
	84463422927637,
	112532176303591,

}

local NextPNDRHall	   = 0

-- Stores only valid insanity-inducing entities.
local Entities = {}

--// Helpers

local function disconnectAll()
	for _, connection in Connections do
		connection:Disconnect()
	end

	table.clear(Connections)
end

local function isEntity(instance: Instance): boolean
	return instance:IsA("Model") and instance.Name == ENTITY_NAME
end

local function updateEntityState()
	EntityPresent = EntityCount > 0 and Character ~= nil and Character:GetAttribute("beingBrainwashed") ~= true
end

local function addEntity(instance: Instance)
	if not isEntity(instance) or Entities[instance] then
		return
	end

	Entities[instance] = true
	EntityCount += 1

	updateEntityState()
end

local function removeEntity(instance: Instance)
	if not Entities[instance] then
		return
	end

	Entities[instance] = nil
	EntityCount -= 1

	updateEntityState()
end

local function getClosestEntityDistance(): number
	if not RootPart then
		return MAX_DISTANCE
	end

	local playerPosition = RootPart.Position
	local closestDistance = MAX_DISTANCE

	for entity in Entities do
		if entity.Parent then
			local primaryPart = entity.PrimaryPart

			if primaryPart then
				local distance = (primaryPart.Position - playerPosition).Magnitude

				if distance < closestDistance then
					closestDistance = distance

					-- Can't get closer than zero.
					if closestDistance <= 0 then
						break
					end
				end
			end
		end
	end

	return math.min(closestDistance, MAX_DISTANCE)
end

local function updateProximity()
	if not EntityPresent then
		ProximityDistortion = 0
		return
	end

	local closestDistance = getClosestEntityDistance()

	ProximityDistortion = math.clamp(
		Progress(closestDistance, ENTITY_RANGE, 0),
		0,
		1
	) ^ 2
end

local function updateSanity()
	Sanity = Character:GetAttribute("Sanity") or 100
	MaxSanity = Character:GetAttribute("MaxSanity") or 100

	-- Preserve the original behavior.
	SanityProgress = Progress(
		Sanity,
		MaxSanity,
		0
	) ^ 3
end

local function updateStaticSounds()
	local playersTeam = game.Teams.Squadmates

	if Player.Team == playersTeam and ProximityDistortion > 0 then
		local proximityVolume = Progress(
			1 - ProximityDistortion,
			1,
			0.5
		)

		for _, sound in Sounds.Proximity:GetChildren() do
			if sound.Name:find("Static") then
				local index = tonumber(sound.Name:sub(-1))

				if index then
					sound.Volume = proximityVolume ^ (STATIC_POW[index] or 1)
				end
			end
		end
	end

	if Player.Team ~= playersTeam or ProximityDistortion <= 0 then
		for _, sound in Sounds.Proximity:GetChildren() do
			if sound.Name:find("Static") then
				sound.Volume = 0
			end
		end
	end
end

local function updateMadnessStatic()
	Sounds.MadnessStatic.Volume = math.max(MIN_MS_VOL, 0, SanityProgress)
	Sounds.MadnessStatic.PlaybackSpeed = Lerp(
		0.775,
		2,
		SanityProgress ^ 3
	)
	Static.ImageTransparency = math.min(1, Lerp(1, 2/3, SanityProgress), EntityPresent and Lerp(1, 1/2, ProximityDistortion) or 1)
end

local function updateSoundState()
	updateMadnessStatic()
	updateStaticSounds()
end

local function updateCharacter(newCharacter: Model)
	Character = newCharacter
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	if not RootPart then
		RootPart = Character:WaitForChild("HumanoidRootPart")
	end

	updateSanity()
	updateSoundState()
end

local function updateCC()
	SanityCC.Contrast = 1 * SanityProgress ^ 2
	SanityCC.TintColor = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(238, 176, 255), SanityProgress)
end

--// Main

function SanityGui.Function()
	if Running then
		return
	end

	local TetheredTaunts = game.Workspace:FindFirstChild("TetheredTaunts")
	if not TetheredTaunts then
		TetheredTaunts = Instance.new("Folder")
		TetheredTaunts.Name = "TetheredTaunts"
		TetheredTaunts.Parent = game.Workspace
	end
	
	TetheredTaunts:ClearAllChildren()

	Running = true

	Character = Player.Character or Player.CharacterAdded:Wait()
	updateCharacter(Character)

	-- Replaces SanityCC
	if not SanityCC then
		SanityCC = Instance.new("ColorCorrectionEffect")
		SanityCC.Name = "SanityCC"
		SanityCC.Parent = Lighting
	end

	SanityCC.Contrast = 0
	SanityCC.TintColor = Color3.fromHSV(1, 0, 1)

	-- Build the initial entity cache once.
	for _, child in Characters:GetChildren() do
		addEntity(child)
	end

	-- Entity tracking is event-driven.
	table.insert(Connections, Characters.ChildAdded:Connect(addEntity))
	table.insert(Connections, Characters.ChildRemoved:Connect(removeEntity))

	-- Character replacement / respawn.
	table.insert(Connections, Player.CharacterAdded:Connect(updateCharacter))

	-- Sanity updates are event-driven.
	table.insert(Connections, Character:GetAttributeChangedSignal("Sanity"):Connect(function()
		updateSanity()
		updateSoundState()
		updateCC()
	end))

	table.insert(Connections, Character:GetAttributeChangedSignal("MaxSanity"):Connect(function()
		updateSanity()
		updateSoundState()
		updateCC()
	end))
	
	table.insert(Connections, Character:GetAttributeChangedSignal("beingBrainwashed"):Connect(function()
		updateEntityState()
		updateSanity()
		updateSoundState()
		updateCC()
	end))

	-- Proximity is updated independently of rendering.
	local proximityAccumulator = 0

	table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
		updateSoundState()

		-- If neither condition can produce distortion, do nothing.
		if not EntityPresent and SanityProgress <= 0 then
			ProximityDistortion = 0
			return
		end

		updateCC()

		proximityAccumulator += dt

		if proximityAccumulator < PROXIMITY_UPDATE_RATE then
			return
		end

		proximityAccumulator = 0

		if EntityPresent then
			updateProximity()
		else
			ProximityDistortion = 0
		end
	end))

	-- Camera manipulation is the only thing that needs PreRender.
	table.insert(Connections, RunService.PreRender:Connect(function(dt)
		-- Manages taunts
		if #TetheredTaunts:GetChildren() > 0 then
			for _, taunt in pairs(TetheredTaunts:GetChildren()) do
				if taunt.Name ~= " " then
					local _, onScreen = Camera:WorldToScreenPoint(taunt.PrimaryPart.CFrame.Position)
					if onScreen then
						taunt.Name = " "
						task.wait(1/4)
						game:GetService("TweenService"):Create(taunt.PrimaryPart, TweenInfo.new(1/8), {CFrame = taunt.PrimaryPart.CFrame * CFrame.new(50 * (math.random() == 0 and 1 or -1), 0, 0)}):Play()
						game:GetService("Debris"):AddItem(taunt, 1/8)
					end
				end
			end
		end

		-- Important: no camera work at all when there is no distortion.
		if not EntityPresent and (SanityProgress <= 0 or SanityProgress >= 1) then
			return
		end

		-- Track breaks + dead pixels
		if os.clock() >= NextDP and EntityPresent then
			NextDP = os.clock() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD) * Lerp(1, 0.25, SanityProgress)
			
			for i = 1, math.random(1, 6) do
				task.spawn(function()
					task.wait(Rand:NextNumber(0, 0.5))
					local NewDP = Static.DeadPixel:Clone()
					NewDP.Parent = Static
					NewDP.Position = UDim2.fromScale(Rand:NextNumber(0, 1), Rand:NextNumber(0, 1))
					NewDP.Visible = true
					task.wait(Rand:NextNumber(0, 0.05))
					NewDP:Destroy()
				end)
			end
		end
		
		-- Track break
		if os.clock() >= NextTB	and EntityPresent then
			NextTB = os.clock() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD) * Lerp(1, 0.25, SanityProgress)
			for i = 1, 3 do
				task.spawn(function()
					task.wait(Rand:NextNumber(0, 0.5))
					local NewTB = Static.TrackBreak:Clone()
					NewTB.Parent = Static
					NewTB.Position = UDim2.fromScale(Rand:NextNumber(0, 1), 0)
					NewTB.Visible = true
					task.wait(Rand:NextNumber(0, 0.05))
					NewTB:Destroy()
				end)
			end
		end

		-- Cryptic message
		if os.clock() >= NextMsg and SanityProgress > 0 and SanityProgress < 1 then
			NextMsg = os.clock() + Rand:NextNumber(0, 1) * Lerp(50, 0, SanityProgress)
			task.spawn(function()
				local Msg2 = TheGui.Frame.Msg2:Clone()
				local SplitDoc = string.split(TetheredDoc, " ")
				local CurrentIndex = math.random(1, #SplitDoc)
				Msg2.Text = SplitDoc[CurrentIndex]
				Msg2.Position = UDim2.fromScale(Rand:NextNumber(0, 1), Rand:NextNumber(0, 1))
				Msg2.Parent = TheGui.Frame
				Msg2.Visible = true

				VFX.Flash1.Function({SplitDoc[CurrentIndex], Camera.CFrame.Position + Vector3.new(Rand:NextNumber(-1, 1), Rand:NextNumber(-1, 1), Rand:NextNumber(-1, 1)) * 100})

				for i = 1, math.random(10, 30) do
					CurrentIndex = math.max((CurrentIndex + 1) % #SplitDoc, 1)
					Msg2.Text = SplitDoc[CurrentIndex]
					task.wait(Rand:NextNumber(0.025, 0.06))
				end

				Msg2:Destroy()
			end)
		end

		-- Tetehered taunt
		if os.clock() >= NextPNDRHall and SanityProgress >= 1/2 then
			NextPNDRHall = os.clock() + Rand:NextNumber(0, (1 - SanityProgress) * 50)

			-- Creates PNDR taunt
			local RayParams = RaycastParams.new()
			RayParams.FilterType = Enum.RaycastFilterType.Exclude
			RayParams.FilterDescendantsInstances = {}
			
			local RefCF = Character.PrimaryPart.CFrame * CFrame.Angles(0, Rand:NextNumber() * 2 * math.pi, 0)
			local Direction = RefCF.LookVector * 10
			local FinalPos = (RefCF + Direction).Position
			
			local TheRay = game.Workspace:Raycast(Character.PrimaryPart.CFrame.Position, Direction, RayParams)
			if TheRay and TheRay.Instance then
				FinalPos = TheRay.Position
			end
			
			local _, onCamScreen = Camera:WorldToScreenPoint(FinalPos)
			
			repeat
				RefCF = Character.PrimaryPart.CFrame * CFrame.Angles(0, Rand:NextNumber() * 2 * math.pi, 0)
				Direction = RefCF.LookVector * 10
				FinalPos = (RefCF + Direction).Position

				TheRay = game.Workspace:Raycast(Character.PrimaryPart.CFrame.Position, Direction, RayParams)
				if TheRay and TheRay.Instance then
					FinalPos = TheRay.Position
				end
				
				_, onCamScreen = Camera:WorldToScreenPoint(FinalPos)
				
				task.wait()
			until not onCamScreen

			-- Creates rig
			local NewRig = RepStorage.Rigs.Tethered.Skins._default._rig:Clone()
			NewRig.Parent = TetheredTaunts
			NewRig:PivotTo(CFrame.lookAt(FinalPos, Character.PrimaryPart.CFrame.Position))
			
			local IK = Instance.new("IKControl", NewRig)
			IK.ChainRoot = NewRig.PrimaryPart
			IK.EndEffector = NewRig.Head
			IK.Target = Camera
			IK.Type = Enum.IKControlType.LookAt
			IK.Weight = 1/2
			
			local Anim = Instance.new("Animation")
			Anim.AnimationId = "rbxassetid://"..TETHERED_TAUNT[math.random(1, #TETHERED_TAUNT)]
			local LoadedAnim = NewRig.Humanoid.Animator:LoadAnimation(Anim)
			LoadedAnim.Looped = true
			LoadedAnim:Play()
			Anim:Destroy()
		end

		-- Camera distortion
		local distortion = ProximityDistortion
		Camera.FieldOfView += Rand:NextNumber(0, (distortion) ^ 3 * 35 * LerpByFrame(0.5, dt)) * (math.random() == 0 and 1 or -1) / 2

		local xManip = 1 - math.max(
			Rand:NextNumber(0, 0.1 * distortion),
			Rand:NextNumber(0, 0.1 * SanityProgress)
		)

		local yManip = 1 - math.max(
			Rand:NextNumber(0, 0.1 * distortion),
			Rand:NextNumber(0, 0.1 * SanityProgress)
		)

		Camera.CFrame *=
			CFrame.new(
				0,
				0,
				0,
				xManip, 0, 0,
				0, yManip, 0,
				0, 0, 1
			)
			* CFrame.Angles(
				math.rad(Rand:NextNumber(-1, 1)) * SanityProgress ^ 2,
				math.rad(Rand:NextNumber(-1, 1)) * SanityProgress ^ 2,
				math.rad(Rand:NextNumber(-1, 1)) * SanityProgress ^ 2 * 2.5
			)
	end))
end

return SanityGui