-- Services
local Lighting	 = game:GetService("Lighting")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules and objects
local Camera	 = game.Workspace.CurrentCamera
local Lerp       = require(RepStorage.Modules.Util.Math.Lerp)

local HealEffect = {
	
	["Heal"]	 = {
		
		["RENDER_DISTANCE"] = math.huge,
		["Function"]		= function(args)
			local Color = args[1]
			
			local HealCC = Instance.new("ColorCorrectionEffect", Lighting)
			HealCC.Name = "HealCC"
			HealCC.Saturation = -1
			HealCC.TintColor = Color
			
			Camera.FieldOfView += 15
			
			local Connection = nil
			Connection = RunService.RenderStepped:Connect(function(dt)
				HealCC.Saturation = Lerp(HealCC.Saturation, 0, 0.05)
				HealCC.TintColor = HealCC.TintColor:Lerp(Color3.fromRGB(255, 255, 255), 0.025)
				
				if HealCC.TintColor == Color3.fromRGB(255, 255, 255) then
					Connection:Disconnect()
					Connection = nil
				end
			end)
			
			repeat task.wait() until not Connection
			HealCC:Destroy()
		end,
		
	},
	
}

return HealEffect