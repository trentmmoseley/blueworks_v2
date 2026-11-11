local Foliage      = {}

-- Services
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")

-- Modules and objects
local GameStats    = RepStorage.GameValues
local ServerStats  = RepStorage.ServerStats

local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local Progress     = require(RepStorage.Modules.Util.Math.Progress)

-- Vars and consts
local ColorParts   = {"LeafPartADV", "Grass", "_grass"}
local LEAF_COLORS  = {
	Regular	   = {
		Color3.fromRGB(61, 104, 71),
		Color3.fromRGB(150, 177, 116),
	},
	Fall	   = {
		Color3.fromRGB(213, 115, 61),
		Color3.fromRGB(190, 104, 98),
		Color3.fromRGB(248, 217, 109),
		Color3.fromRGB(160, 132, 79),
		Color3.fromRGB(163, 75, 75),
	}
}

local RESOLUTION    = 10
local FREQUENCY		= 30

-- [[ funcs ]] --

-- Main function
function Foliage.Init(map)
    -- Regular colors
	local WarmColor = LEAF_COLORS["Regular"][2]
	local ColdColor = LEAF_COLORS["Regular"][1]
	
    local NoiseMap = {}

	-- Preps trees
	local LargestNoise, SmallestNoise = -math.huge, math.huge
	
	for _, folder in pairs(map.Nature:GetChildren()) do
		for _, plant in pairs(folder:GetChildren()) do
			local P = plant:IsA("BasePart") and plant or (plant.MainPart or plant:FindFirstChildOfClass("BasePart"))
			NoiseMap[plant] = {Noise = math.noise(P.Position.X / RESOLUTION * FREQUENCY, P.Position.Z / RESOLUTION * FREQUENCY), Part = P}
			
			if NoiseMap[plant].Noise > LargestNoise then
				LargestNoise = NoiseMap[plant].Noise
			end
			
			if NoiseMap[plant].Noise < SmallestNoise then
				SmallestNoise = NoiseMap[plant].Noise
			end
		end
	end

    for _, folder in pairs(map.Nature:GetChildren()) do
		for _, plant in pairs(folder:GetChildren()) do
			local RegNoise = NoiseMap[plant].Noise or Lerp(SmallestNoise, LargestNoise, 1/2)
			NoiseMap[plant].Noise = Progress(RegNoise, SmallestNoise, LargestNoise)

            local Parts = (plant:IsA("BasePart") or plant:IsA("MeshPart")) and {plant} or plant.Leaves:GetChildren()
			local PlantColor = LEAF_COLORS.Fall[math.random(1, #LEAF_COLORS.Fall)]
			
			for _, part in pairs(Parts) do
				if #Parts > 1 then
					part.Material = GameStats.Bools.doSnow.Value and Enum.Material.Snow or Enum.Material.Grass
					part.Color = part.Material == Enum.Material.Snow and Color3.fromHSV(0, 0, 1) or ColdColor:Lerp(WarmColor, RegNoise * Lerp(0.5, 1, GameStats.Numbers.Temperature.Value))
				else
					part.Material = GameStats.Bools.doSnow.Value and Enum.Material.Snow or Enum.Material.Grass
					part.Color = part.Material == Enum.Material.Snow and Color3.fromHSV(0, 0, 1) or WarmColor:Lerp(ColdColor, 1/2)
				end
				
				if GameStats.Numbers.Temperature.Value <= 1/2 and part.Material ~= Enum.Material.Snow and table.find({1, 4}, ServerStats.Date.Season.Value) then
					part.Color = #Parts == 1 and Color3.fromRGB(160, 132, 79) or PlantColor
				end

				-- Colors decals, too
				local Decal = part:FindFirstChildOfClass("Decal")
				if Decal then
					Decal.Color3 = part.Color
				end
			end
		end
	end
end

return Foliage