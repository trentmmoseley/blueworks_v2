local Psychophase     = {}

-- Services
local Workspace       = game:GetService("Workspace")

-- Modules and objects
local VFXService      = _G.Knit.GetService("VFXService")
local RoundService    = _G.Knit.GetService("RoundService")

-- Vars and consts
Psychophase.MIN_PROGRESS = 1/4
local PHASE_IN_DIST   = 10
local Characters      = Workspace:WaitForChild("Characters")
local Rand            = Random.new()

-- [[ funcs ]] --

-- Main function
function Psychophase.Function(rig : Model, target : Model)
	-- Teleport count scales with Node progress: +1 teleport per quarter of progress past 25%
	local StageOffset   = math.clamp(math.floor((RoundService:NodeProgress() - 1/4) / 1/4), 0, 2)
	local TeleportCount = Rand:NextInteger(2 + StageOffset, 4 + StageOffset)

	task.spawn(function()
		for i = 1, TeleportCount do
			if not rig or not rig.Parent or not target or not target:FindFirstAncestor("Characters") or not target.PrimaryPart then
				return
			end

			-- Teleports to a random position around the target, same as STALK -> ATTACK
			local RayParams = RaycastParams.new()
			RayParams.FilterType = Enum.RaycastFilterType.Exclude
			RayParams.FilterDescendantsInstances = {Characters}

			local Origin      = target.PrimaryPart.CFrame.Position
			local CFAtAngle   = target.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(Rand:NextNumber() * 360), 0)
			local SpawnPoint  = Origin + CFAtAngle.LookVector * PHASE_IN_DIST

			local TheRay = Workspace:Raycast(Origin, CFAtAngle.LookVector * PHASE_IN_DIST, RayParams)
			if TheRay and TheRay.Distance then
				SpawnPoint = TheRay.Position
			end

			for j = 1, 10 do
				rig:PivotTo(CFrame.lookAt(SpawnPoint, target.PrimaryPart.Position))
			end

			-- Same visual effects and sounds as the phase-in, without Spawn animation slowness
			VFXService:GlobalVFX("Tethered", "Phase", rig.PrimaryPart.CFrame, rig, rig.PrimaryPart.CFrame)

			-- Delay between teleportations (not after the final one)
			if i < TeleportCount then
				task.wait(Rand:NextNumber(1/4, 1/2))
			end
		end
	end)
end

return Psychophase