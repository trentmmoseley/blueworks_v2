local Psychophase     = {}

-- Services
local Players 		  = game:GetService("Players")
local Rand 			  = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local Workspace       = game:GetService("Workspace")

-- Modules and objects
local EffectService   = _G.Knit.GetService("EffectService")
local VFXService      = _G.Knit.GetService("VFXService")

local FastCast	      = require(RepStorage.Modules.Environment.FastCastRedux)

local ZBObjects  	  = Instance.new("Folder")
ZBObjects.Name   	  = "ZipBombs"
ZBObjects.Parent 	  = game.Workspace

local Caster     	  = FastCast.new()

-- Vars and consts
Psychophase.MIN_PROGRESS = 3/4

-- [[ funcs ]] --

local function onLengthChanged(cast, lastpoint, dir, len, vel, bullet)
	if bullet then
		local BulletLength = bullet.Size.Z / 2
		local Offset = CFrame.new(0, 0, -(len - BulletLength))
		bullet.CFrame = CFrame.lookAt(lastpoint, lastpoint + dir):ToWorldSpace(Offset)

		local Trail = bullet:FindFirstChildOfClass("Trail", true)
		if Trail then
			Trail.Enabled = true
		end

		if not bullet.PulseSound.Playing then
			bullet.PulseSound:Play()
			bullet.Init:Play()
			bullet.Throw:Play()
		end

		bullet.CFrame *= CFrame.new(Rand:NextNumber(-1, 1) / 2, Rand:NextNumber(-1, 1) / 2, Rand:NextNumber(-1, 1) / 2)
	end
end

-- Creates zip bomb
local function createZB(thrower : Player | Model)
	local Template = RepStorage.VFX.Tethered.ZB:Clone()

	local Thrower = Instance.new("ObjectValue")
	Thrower.Name = "Thrower"
	Thrower.Value = thrower
	Thrower.Parent = Template

	return Template
end

local function onRayHit(cast, result, velocity, bullet)
	for _, part in pairs(bullet:GetChildren()) do
		if part:IsA("ParticleEmitter") then
			part.Enabled = false
		elseif part:IsA("Sound") then
			part:Stop()
		end
	end

	-- On collide
	VFXService:GlobalVFX("ZipBomb", "Explosion", CFrame.new(result.Position), CFrame.new(result.Position))
	
	for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
		if char:IsA("Model") and char:FindFirstChild("HumanoidRootPart") and char:GetAttribute("Team") ~= "ENTITIES" then
			local HRP = char.HumanoidRootPart
			local Dist = (HRP.Position - result.Position).Magnitude

			local Player = Players:GetPlayerFromCharacter(char)

			if Dist <= 10 then
				EffectService:Add(char, "Confusion", 45)
				EffectService:Add(char, "Delirium", 45)

				VFXService:PlayVFX(Player, "ZipBomb", "Distortion", CFrame.new(result.Position))
			end
		end
	end

	bullet:Destroy()
end

Caster.LengthChanged:Connect(onLengthChanged)
Caster.RayHit:Connect(onRayHit)

-- Main function
function Psychophase.Function(rig : Model, target : Model)
	task.spawn(function()
		VFXService:GlobalVFX("ZipBomb", "Prep", rig.PrimaryPart.CFrame, rig.PrimaryPart.CFrame, rig)
		task.wait(1)

		-- Throws zip bomb
		local Origin = rig.PrimaryPart.Position
		local Direction = (target.PrimaryPart.Position - Origin).Unit

		local CastParams = RaycastParams.new()
		CastParams.FilterType = Enum.RaycastFilterType.Exclude
		CastParams.FilterDescendantsInstances = {rig}

		local CastBehavior = FastCast.newBehavior()
		CastBehavior.RaycastParams = CastParams
		CastBehavior.CosmeticBulletTemplate = createZB(rig)
		CastBehavior.CosmeticBulletContainer = ZBObjects
		CastBehavior.Acceleration = Vector3.zero
		CastBehavior.MaxDistance = math.huge

		Caster:Fire(Origin, Direction, 40, CastBehavior)
	end)
end

return Psychophase