local LightSystems   = {}

-- Vars and consts
local LIGHT_MAP      = {

	["CeilingLight"] = "Surface",
	["_point"]       = "Point",

}

-- [[ funcs ]] --

-- Manages map's lights
local function mapLights(map)
	for _, system in pairs(map.Interactables:WaitForChild("LightSystems"):GetChildren()) do
		local Config = system:WaitForChild("Configuration")
		local isOn = Config.isOn

		-- Inits lights
		for _, obj in pairs(system.Lights:GetChildren()) do
			obj:ClearAllChildren()
			local NewLight = Instance.new(LIGHT_MAP[obj.Name].."Light")
			NewLight.Name = "Light"
			NewLight.Color = Color3.fromRGB(197, 201, 255)
			NewLight.Parent = obj

			if not NewLight:IsA("PointLight") then
				NewLight.Face = "Bottom"
			end

			local RayParams = RaycastParams.new()
			RayParams.FilterType = Enum.RaycastFilterType.Exclude
			RayParams.FilterDescendantsInstances = {}

			local Direction = Vector3.new(0, -60, 0)
			local TheRay = game.Workspace:Raycast(obj.Position, Direction, RayParams)
			if TheRay and TheRay.Instance then
				NewLight.Range = (TheRay.Position - obj.Position).Magnitude * (9/8)
			else
				NewLight.Range = 60
			end

			NewLight.Enabled = isOn.Value
			isOn.Changed:Connect(function(new)
				NewLight.Enabled = new
				obj.Material = Enum.Material[new == true and "Neon" or "Glass"]
				obj.BrickColor = BrickColor.new(new == true and "Institutional white" or "Smoky grey")
			end)
		end
	end
end

-- Main function
function LightSystems.Function()
	local Map = game.Workspace:WaitForChild("Playspace")
	mapLights(Map)
end

return LightSystems
