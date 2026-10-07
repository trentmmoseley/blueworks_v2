local Ragdolls     = {}

-- Services
local Debris       = game:GetService("Debris")
local Players  	   = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")

-- Player
local Player       = Players.LocalPlayer

-- Modules and objects
local Corpses	   = game.Workspace:FindFirstChild("Corpses")
if not Corpses then
	Corpses 	   = Instance.new("Folder")
	Corpses.Name   = "Corpses"
	Corpses.Parent = game.Workspace
end

local Characters   = game.Workspace:WaitForChild("Characters")

local DeathTypes   = require(script.DeathTypes)

-- Vars and consts
local BL_M6D	   = {"Handle", "RootJoint", "Neck", "HumanoidRootPart"}
local MAX_CORPSES  = 12
local REPL_WAIT    = 10 -- max seconds to wait for a rig's Humanoid/isNPC attribute to replicate in
local CorpseCount  = 0

-- Builds joints
local function buildJoints(char : Model)
	local HRP = char:FindFirstChild("HumanoidRootPart")

	for _, joint in pairs(char:GetDescendants()) do
		if joint:IsA("Motor6D") and not table.find(BL_M6D, joint.Name) and not joint:FindFirstAncestor("Head") then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame = joint.C0
			a1.CFrame = joint.C1
			a0.Parent = joint.Part0
			a1.Parent = joint.Part1

			a0.Name = "RagdollAttachment"
			a1.Name = "RagdollAttachment"

			local b = Instance.new("BallSocketConstraint")
			b.Name = "RagdollConstraint"
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Parent = joint.Part0
			b.TwistLimitsEnabled = true
			b.LimitsEnabled = true

			joint.Enabled = false
		end
	end
end

-- Destroys joints
local function destroyJoints(char : Model)
	for _, v in pairs(char:GetDescendants()) do
		if v.Name == "RagdollAttachment" or v.Name == "RagdollConstraint" then
			v:Destroy()
		end
	end
end

-- Enables collision parts
local function toggleCollisionParts(char : Model, enabled : boolean)
	for _, v in pairs(char:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			if not v:FindFirstChild("_collide") then continue end
			v.CanCollide = not enabled
			v._collide.CanCollide = enabled
		end
	end
end

-- Toggles ragdoll
function Ragdolls.toggleRagdoll(char : Model, isragdolled : boolean)
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, isragdolled)
	if not isragdolled then
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	if isragdolled then
		buildJoints(char)
	else
		destroyJoints(char)
	end

	-- Motor6Ds
	for _, m in pairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and not table.find(BL_M6D, m.Name) and not m:FindFirstAncestor("Head") then
			m.Enabled = not isragdolled
		elseif m:IsA("BasePart") then
			m.CollisionGroup = isragdolled and "Default" or "PlayerChars"
		end
	end

	toggleCollisionParts(char, isragdolled)
end

-- Preps character
local function prepChar(char : Model)
	for _, part in pairs(char:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local P = part:Clone()
			P.Parent = part
			P.CanCollide = false
			P.Massless = true
			P.Size = Vector3.one
			P.Name = "_collide"
			P.Transparency = 1
			P:ClearAllChildren()

			local Weld = Instance.new("Weld")
			Weld.Parent = P
			Weld.Part0 = part
			Weld.Part1 = P
		end
	end
end

-- Manages character
local function manageChar(char : Model)
	-- wait (bounded) for the Humanoid to replicate in; a rig that is destroyed or
	-- never gains one must not yield this thread forever
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	local WaitStart = os.clock()

	while not Humanoid and char.Parent and os.clock() < WaitStart + REPL_WAIT do
		task.wait()
		Humanoid = char:FindFirstChildOfClass("Humanoid")
	end

	if not (Humanoid and char.Parent) then
		return
	end

	Humanoid.BreakJointsOnDeath = false
	Humanoid.RequiresNeck = false

	prepChar(char)

	-- On ragdoll
    char:GetAttributeChangedSignal("isRagdolled"):Connect(function()
        Ragdolls.toggleRagdoll(char, char:GetAttribute("isRagdolled"))
    end)

	-- Death
	Humanoid.Died:Connect(function()
		char.Archivable = true
        local DeathType = char:GetAttribute("DeathType")

		local NewChar = char:Clone()
		NewChar.Parent = Corpses

		for att, val in char:GetAttributes() do
			NewChar:SetAttribute(att, val)
		end

		for _, part in char:GetChildren() do
			if part:IsA("BasePart") then
				local NewPart = NewChar:FindFirstChild(part.Name)
				if NewPart then
					for att, val in part:GetAttributes() do
						NewPart:SetAttribute(att, val)
					end
				end
			end
		end

		-- the corpse must not keep emitting looping movement sounds (footsteps,
		-- breathing, etc.): stop every sound that was playing when it died
		for _, desc in NewChar:GetDescendants() do
			if desc:IsA("Sound") and desc.IsPlaying then
				desc:Stop()
			end
		end

		char:Destroy()

		local NewHRP = NewChar:FindFirstChild("HumanoidRootPart")
		if NewHRP then
			local BBGui = NewHRP:FindFirstChildOfClass("BillboardGui")
			if BBGui then
				BBGui:Destroy()
			end

			for _, vel : VectorForce in NewHRP:GetChildren() do
				if vel:IsA("VectorForce") then
					Debris:AddItem(vel, 1/2)
				end
			end
		end

		local Hum : Humanoid = NewChar:FindFirstChildOfClass("Humanoid")
		if Hum then
			-- the corpse must never keep animating: stop every track still playing on it
			local Animator = Hum:FindFirstChildOfClass("Animator")
			if Animator then
				for _, track in Animator:GetPlayingAnimationTracks() do
					track:Stop(0)
				end
			end

			Hum.PlatformStand = true
			Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)

			Ragdolls.toggleRagdoll(NewChar, true)
		end

		if DeathTypes[DeathType] then
			DeathTypes[DeathType](NewChar)
		end

		local CorpseInit = os.clock()
		CorpseCount += 1
		local CorpseNumber = CorpseCount

		repeat task.wait() until os.clock() >= CorpseInit + 120 or CorpseCount >= CorpseNumber + MAX_CORPSES or not (NewChar and NewChar:FindFirstAncestor("Workspace"))

		if NewChar and NewChar.Parent then
			NewChar:Destroy()
		end
	end)
end

-- Manages player
local function managePlayer(player : Player)
	if player.Team ~= game.Teams.Spectators then
		manageChar(player.Character or player.CharacterAdded:Wait())
	end

    player.Changed:Connect(function()
        if player.Team ~= game.Teams.Spectators then
            manageChar(player.Character or player.CharacterAdded:Wait())
        end
    end)
end

local function manageEntity(entity)
	-- the isNPC attribute replicates in after the model itself; if it hasn't arrived
	-- yet, wait (bounded) for it instead of skipping the entity entirely
	if entity:GetAttribute("isNPC") == nil then
		local WaitStart = os.clock()
		repeat task.wait() until entity:GetAttribute("isNPC") ~= nil or not entity.Parent or os.clock() >= WaitStart + REPL_WAIT
	end

	if entity.Parent and entity:GetAttribute("isNPC") then
		manageChar(entity)
	end
end

-- Main function
function Ragdolls.Function()
	-- Manages entities
	for _, plr in pairs(Players:GetPlayers()) do
		managePlayer(plr)
	end

	Players.PlayerAdded:Connect(function(player)
		managePlayer(player)
	end)

	for _, entity in pairs(Characters:GetChildren()) do
		task.spawn(manageEntity, entity)
	end

	Characters.ChildAdded:Connect(function(entity)
		task.spawn(manageEntity, entity)
	end)
end

return Ragdolls
