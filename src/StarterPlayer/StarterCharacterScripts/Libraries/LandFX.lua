local LandFX      	  = {}

-- Services
local Debris		  = game:GetService("Debris")
local Rand			  = Random.new()
local RepStorage  	  = game:GetService("ReplicatedStorage")

-- Modules and objects
local Camera		  = game.Workspace.CurrentCamera
local LandVFX		  = RepStorage.VFX.Landing

local Characters      = game.Workspace:WaitForChild("Characters")
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local LAND_SOUNDS 	  = {268933841, 268933900, 268933974, 268934012}

-- [[ funcs ]] --

-- Manages character
local function manageCharacter(char : Model)
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	
	-- On land
	Humanoid.StateChanged:Connect(function(old, new)
		local Distance = (Camera.CFrame.Position - char.PrimaryPart.CFrame.Position).Magnitude
		if new == Enum.HumanoidStateType.Landed and Distance <= 35 then
			local YVel = -char.PrimaryPart.AssemblyLinearVelocity.Y
			
			if YVel > 20 then
				local NewFX = LandVFX.Part:Clone()
				NewFX.Parent = game.Workspace
				
				-- Places part
				local RayParams = RaycastParams.new()
				RayParams.FilterType = Enum.RaycastFilterType.Exclude
				RayParams.FilterDescendantsInstances = {char}
				
				local Raycast = game.Workspace:Raycast(char.PrimaryPart.Position, Vector3.new(0, -6, 0), RayParams)
				if Raycast and Raycast.Instance then
					NewFX.Position = Raycast.Position + Vector3.new(0, 1/8, 0)
				else
					NewFX.Position = char.PrimaryPart.CFrame.Position - Vector3.new(0, 2.5, 0)
				end

				for _, fx : ParticleEmitter in pairs(NewFX:GetChildren()) do
					fx:Emit(2)
				end

				Debris:AddItem(NewFX, 1)
			end
			
			PlaySound(LAND_SOUNDS[math.random(1, #LAND_SOUNDS)], "Land", char.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))
		end
	end)
end

-- Main function
function LandFX.Function()
	-- Manages players
	for _, character in Characters:GetChildren() do
        manageCharacter(character)
    end

    Characters.ChildAdded:Connect(manageCharacter)
end

return LandFX