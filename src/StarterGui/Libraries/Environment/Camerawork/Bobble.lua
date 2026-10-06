local Bobble         = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage 	 = game:GetService("ReplicatedStorage")
local UIS 			 = game:GetService("UserInputService")

-- Player
local Player         = Players.LocalPlayer
local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local Camera   		 = game.Workspace.CurrentCamera

local FallDamage 	 = require(RepStorage.Remotes.FallDamage):Client()
local Lerp 		 	 = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame 	 = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress 		 = require(RepStorage.Modules.Util.Math.Progress)
local TrigWave 		 = require(RepStorage.Modules.Util.Math.TrigWave)
local Spring 		 = require(RepStorage.Modules.Util.Spring)

-- Vars and consts
local MMT_INFO		 = {
	
	["WALK"]		 = {
		
		["BobB"]	 = 0.5,
		["BobDepth"] = 0.3,
		["CamDepth"] = 0,
		["FOV"]		 = 80,
		["MaxAngle"] = 1,
		
	},
	
	["RUN"]		 	 = {
		
		["BobB"]	 = 1/3,
		["BobDepth"] = 3/8,
		["CamDepth"] = 0,
		["FOV"]		 = 90,
		["MaxAngle"] = 1.5,

	},

	["CROUCH"]		 = {
		
		["BobB"]	 = 2,
		["BobDepth"] = 0.5,
		["CamDepth"] = 1.5,
		["FOV"]		 = 60,
		["MaxAngle"] = 0.75,

	},

    ["CRAWL"]		 = {

		["BobB"]	 = 2,
		["BobDepth"] = 0,
		["CamDepth"] = 3.25,
		["FOV"]		 = 50,
		["MaxAngle"] = 0.75,

	},

	["DOWNED"]		 = {

		["BobB"]	 = 2,
		["BobDepth"] = 0,
		["CamDepth"] = 3.25,
		["FOV"]		 = 40,
		["MaxAngle"] = 0.75,

	},

	["SLIDE"]		 = {

		["BobB"]	 = math.huge,
		["BobDepth"] = 0,
		["CamDepth"] = 3.25,
		["FOV"]		 = 110,
		["MaxAngle"] = 0,

	},
	
}

local CameraTilt	 = CFrame.Angles(0, 0, 0)
local LastCF	     = Camera.CFrame

local CurrentBobble  = 0
local CurrentDepth	 = 0
local CurrentJump	 = 0

local JumpDepth		 = 0
local iAEventMade	 = false

local ORIG_SENS		 = UIS.MouseDeltaSensitivity

local FDSpring 		 = Spring() -- fall damage
FDSpring.Damping	 = 2

local PDSpring 		 = Spring() -- physical damage (getting hit)
PDSpring.Damping     = 2

-- Main function
function Bobble.Function(dt)
    local QuarterLerp = LerpByFrame(1/4,dt)

    -- Runs only if player is in-game
    if Player.Team ~= game.Teams.Spectators then
        local MovementType = Character:GetAttribute("MovementType")
        local inAir = Character:GetAttribute("inAir")
        local isMoving = Character:GetAttribute("rawInputDetected")
		local isAiming = Character:GetAttribute("isAiming") and Character:GetAttribute("isReloading") ~= true

        -- Gets movement info
        local MmtInfo = MMT_INFO[MovementType]
		if not isMoving and MovementType == "RUN" then
			MmtInfo = MMT_INFO["WALK"]
		end

        -- Camera tilt
		local RelativeCF = Camera.CFrame:Inverse() * LastCF
		local X, Y, Z = RelativeCF:ToEulerAnglesXYZ()
		X, Y, Z = math.deg(X), math.deg(Y), math.deg(Z)

		FDSpring:update(dt)
		PDSpring:update(dt)

        local Direction = Character:GetAttribute("MoveDirection")
		local LastLeanVal = Character:GetAttribute("isLeaning") and Character:GetAttribute("LeanDirection") or nil
		local HumanoidHealthTilt = Progress(Humanoid.Health, Humanoid.MaxHealth, 0)

        CameraTilt = CameraTilt:Lerp(CFrame.Angles(
			math.rad(FDSpring.Position.X) + math.rad(PDSpring.Position.X),
			math.rad(PDSpring.Position.Y), 
			math.rad(FDSpring.Position.Z) - math.rad(Direction.X  * 3) - math.rad(Direction.X * 4.5) + math.rad(LastLeanVal and 15 * (LastLeanVal == "L" and 1 or -1) or 0) + math.rad(TrigWave("sin", math.max(Character:GetAttribute("isDowned") and 10 or 0), 30, os.clock(), 0, 0)) + math.rad(HumanoidHealthTilt * 5)) * CFrame.new(LastLeanVal and 1.75 * (LastLeanVal == "L" and -1 or 1) or 0, 0, 0), QuarterLerp / 2)

        if isMoving then
            local BobLevel = TrigWave("sin", MmtInfo["MaxAngle"], MmtInfo["BobB"] * 2, os.clock(), 0, 0) * (inAir and 0 or 1/30)
            CameraTilt = CameraTilt:Lerp(CFrame.Angles(0, 0, BobLevel), QuarterLerp * 0.775)
        end

        -- Sets up values
		CurrentDepth = Lerp(CurrentDepth, (MMT_INFO[MovementType]["CamDepth"] or 0), QuarterLerp)
		CurrentBobble = Lerp(CurrentBobble, MmtInfo.BobDepth + math.abs(TrigWave("sin", MmtInfo.BobDepth * (inAir and 0 or 1), MmtInfo["BobB"], os.clock(), 0, MmtInfo["BobDepth"] * 0.5)) * (isMoving and 1 or 0), QuarterLerp)
		CurrentJump = Lerp(CurrentJump, JumpDepth, QuarterLerp)

        -- Field of view
        local NextFOV = not isAiming and MmtInfo["FOV"] or (_G.CurrentI2 and _G.CurrentI2.AimFOV or 60)
        Camera.FieldOfView = Lerp(Camera.FieldOfView, NextFOV, QuarterLerp / 2 * (_G.CurrentI2 and _G.CurrentI2.LerpSpeed or 1))

		-- Aiming
		if isAiming then
			UIS.MouseDeltaSensitivity = Lerp(UIS.MouseDeltaSensitivity, ORIG_SENS * ((_G.CurrentI2 and _G.CurrentI2["AimFOV"] or 60) / MMT_INFO["WALK"]["FOV"]), LerpByFrame(_G.CurrentI2 and _G.CurrentI2["LerpSpeed"] or 1, dt))
		else
			UIS.MouseDeltaSensitivity = Lerp(UIS.MouseDeltaSensitivity, ORIG_SENS, QuarterLerp / 2)
		end

        -- Humanoid
        Humanoid.CameraOffset = Vector3.new(0, -CurrentDepth - CurrentBobble - CurrentJump + 3/8, 0)

        -- Camera
        Camera.CFrame *= CameraTilt

		-- Resets values
		JumpDepth = Lerp(JumpDepth, 0, QuarterLerp / 2)
    end

	-- Jump depth
    if not iAEventMade then
		iAEventMade = true
		Humanoid.StateChanged:Connect(function(old, new)
			if new == Enum.HumanoidStateType.Landed then
				JumpDepth += math.log(math.abs(Character.PrimaryPart.AssemblyLinearVelocity.Y )) * (Character:GetAttribute("rawInputDetected") and 1 or 2.5 * (2/5))
			end
		end)

		FallDamage:On(function(velocity)
			FDSpring:shove(Vector3.new(-2, 0, 30) * Progress(velocity, 0, 30))
		end)
	end
end

return Bobble