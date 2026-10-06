-- Services
local Players  	 	 = game:GetService("Players")
local RepStorage	 = game:GetService("ReplicatedStorage")
local RunService	 = game:GetService("RunService")

local Knit           = _G.Knit

-- Player
local Player 		 = Players.LocalPlayer

local Character		 = Player.Character or Player.CharacterAdded:Wait()
local Humanoid		 = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local Lerp        = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame = require(RepStorage.Modules.Util.Math.LerpByFrame)
local MMT_SETTINGS 	 = require(RepStorage.Modules.Data.MovementSettings)

-- Vars and consts
local Anims		 	 = {
	
	["IDLE"]		 = {
		
		["ID"]		 = 81665555025997,
		["isMoving"] = false,
		["inAir"]	 = false,
		["Looped"]	 = true,
		["Speed"]	 = 1/6,
		["Priority"] = Enum.AnimationPriority.Idle,
		
	},

	["IDLE_STUNNED"]		 = {
		
		["ID"]		 = 122410086598709,
		["isMoving"] = false,
		["inAir"]	 = false,
		["Looped"]	 = true,
		["Speed"]	 = 1/6,
		["Priority"] = Enum.AnimationPriority.Idle,
		
	},
	
	["WALK"]		 = {

		["ID"]		 = 89468869841055,
		["isMoving"] = true,
		["inAir"]	 = false,
		["MmtType"]  = "WALK",
		["Looped"]	 = true,
		["Speed"]	 = 5/4,
		["Priority"] = Enum.AnimationPriority.Movement,

	},

	["CHARGE_1"]		 = {

		["ID"]		 = 89468869841055,
		["isMoving"] = true,
		["inAir"]	 = false,
		["MmtType"]  = "CHARGE_1",
		["Looped"]	 = true,
		["Speed"]	 = 5/4,
		["Priority"] = Enum.AnimationPriority.Movement,

	},

	["CHARGE_2"]		 = {

		["ID"]		 = 98924964685899,
		["isMoving"] = true,
		["inAir"]	 = false,
		["MmtType"]  = "CHARGE_2",
		["Looped"]	 = true,
		["Speed"]	 = 5/4,
		["Priority"] = Enum.AnimationPriority.Movement,

	},
	
	["RUN"]		 	 = {

		["ID"]		 = 81207900885640,
		["isMoving"] = true,
		["inAir"]	 = false,
		["MmtType"]  = "RUN",
		["Looped"]	 = true,
		["Speed"]	 = 1.25,
		["Priority"] = Enum.AnimationPriority.Movement,

	},
	
	["CROUCH"]		 = {
		
		["freezeOnIdle"] = true, 
		["ID"]		 	 = 126343208450239,
		["inAir"]	 	 = false,
		["MmtType"]  	 = "CROUCH",
		["Looped"]	 	 = true,
		["Speed"]	 	 = 1,
		["Priority"] = Enum.AnimationPriority.Action4,
		
	},

	["CRAWL"]	    	 = {
		
		["freezeOnIdle"] = true, 
		["ID"]		 	 = 12341908699,
		["inAir"]	 	 = false,
		["MmtType"]  	 = "CRAWL",
		["Looped"]	 	 = true,
		["Speed"]	 	 = 1,
		["Priority"] = Enum.AnimationPriority.Action4,
		
	},
	
	["JUMP"]		 = {

		["ID"]		 = 116496690680898,
		["Looped"]	 = false,
		["Speed"]	 = 2.5,
		["Priority"] = Enum.AnimationPriority.Action4,

	},
	
	["FALL"]		 = {

		["ID"]		 = 119528283195927,
		["inAir"]	 = true,
		["Looped"]	 = true,
		["Speed"]	 = 1,
		["Priority"] = Enum.AnimationPriority.Movement,

	},
	
	["LAND"]	     = {
		
		["ID"]		 = 70926104383734,
		["inAir"]	 = false,
		["Looped"]	 = false,
		["Speed"]	 = 1,
		["Priority"] = Enum.AnimationPriority.Movement,
		
	},
	
	["SLIDE"]	     = {

		["ID"]		 = 119136181806146,
		["isMoving"] = true,
		["inAir"]	 = false,
		["MmtType"]  = "SLIDE",
		["Looped"]	 = true,
		["Speed"]	 = 1,
		["Priority"] = Enum.AnimationPriority.Action4,

	},
	
	["DOWNED"]		 = {

		["freezeOnIdle"] = true, 
		["ID"]		 	 = 124560450325762,
		["inAir"]	 	 = false,
		["MmtType"]  	 = "DOWNED",
		["Looped"]	 	 = true,
		["Speed"]	 	 = 1,
		["Priority"]     = Enum.AnimationPriority.Action4,

	},
	
	["FLY_IDLE"]	 = {
		
		["ID"]		 = 129780555846090,
		["isMoving"] = false,
		["Looped"]	 = true,
		["Speed"]	 = 1,
		["Priority"] = Enum.AnimationPriority.Idle,
		
	},
	
	["FLY"]		     = {

		["ID"]		 = 130173031504106,
		["isMoving"] = true,
		["Looped"]	 = true,
		["Speed"]	 = 1,
		["Priority"] = Enum.AnimationPriority.Movement,

	},
	
}

local LoadedAnims	 = {}
local EVENT_ANIMS	 = {"JUMP", "LAND", "DODGE_LEFT", "DODGE_RIGHT"}

local PunchCounter	  = 0

-- Determines if anim is playing
local function animIsPlaying(id)
    local MovementType = Character:GetAttribute("MovementType")

	local ANIM_INFO = Anims[id]
	if ANIM_INFO["isMoving"] and ANIM_INFO["isMoving"] ~= Character:GetAttribute("isMoving") then
		return false, "Character moving"
	end
	
	if ANIM_INFO["MmtType"] and ANIM_INFO["MmtType"] ~= MovementType then
		return false, "Wrong movement type"
	end
	
	if ANIM_INFO["inAir"] ~= nil and ANIM_INFO["inAir"] ~= Character:GetAttribute("inAir") then
		return false, "Character not in air"
	end
	
	if string.find(id, "IDLE") and MovementType == "CROUCH" then
		return false, "Character crouching"
	end
	
	if (string.find(id, "FLY") and MovementType ~= "FLY") or (not string.find(id, "FLY") and MovementType == "FLY") then
		return false, "Character flying"
	end
	
	if table.find(EVENT_ANIMS, id) then
		return false, "Event anim"
	end

	if string.find(id, "IDLE") then
		local isLH = string.find(id, "LH") ~= nil
		local isStunned = string.find(id, "STUNNED") ~= nil

		if isStunned and MovementType ~= "STUNNED" then
			return false, "Low health"
		end
	end
	
	return not Character:GetAttribute("isRagdolled")
end

-- [[ LOADS ANIMS ]] --
local Animator : Animator = Humanoid:WaitForChild("Animator")

for id, info in pairs(Anims) do
	local NewAnim = Instance.new("Animation")
	NewAnim.AnimationId = "rbxassetid://"..info["ID"]
	local LoadedAnim = Animator:LoadAnimation(NewAnim)
	LoadedAnim.Looped = info["Looped"]
	LoadedAnim.Priority = info["Priority"]
	LoadedAnims[id] = LoadedAnim
	NewAnim:Destroy()
end

-- [[ MANAGES ANIMS ]] --
RunService.PreRender:Connect(function(dt)
    local QuarterLerp = LerpByFrame(1/4, dt)

	local isMoving = Character:GetAttribute("isMoving")
	
	for id, anim in pairs(LoadedAnims) do
		local ANIM_INFO = Anims[id]
		local animPlaying, FailReason = animIsPlaying(id)
        
		if animPlaying then
			if ANIM_INFO["Looped"] and not anim.IsPlaying then
				anim:Play()
			end

			anim:AdjustSpeed(Lerp(anim.Speed, (not ANIM_INFO.freezeOnIdle or isMoving) and ANIM_INFO.Speed or 0, QuarterLerp))

			if ANIM_INFO.isMoving then
				anim:AdjustWeight(ANIM_INFO.isMoving and Humanoid.WalkSpeed / MMT_SETTINGS[Character:GetAttribute("MovementType")].Speed or 1)
			end
		else
			if ANIM_INFO["Looped"] and anim.IsPlaying then
				anim:Stop()
			end
		end
	end
end)

-- Jumping / landing
Character:GetAttributeChangedSignal("inAir"):Connect(function()
	if Character:GetAttribute("inAir") then
		LoadedAnims.JUMP:Play()
		LoadedAnims.JUMP:AdjustWeight(1)
	else
		LoadedAnims.LAND:Play()
		LoadedAnims.LAND:AdjustWeight(Character:GetAttribute("isMoving") and 3 or 1)
	end
end)