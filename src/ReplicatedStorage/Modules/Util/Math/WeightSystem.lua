-- Services
local Rand = Random.new()

-- [[ funcs ]] --

-- Main function
return function(tbl)
    -- Calculates table weight
	local Weight = 0
	for _, chance in pairs(tbl) do
		Weight += chance
	end
	
	-- Sets bar to reach
	local RandNumber = Rand:NextNumber(0, Weight)
	Weight = 0
	
	-- Chooses item
	for item, chance in pairs(tbl) do
		Weight += chance
		if Weight >= RandNumber then
			return item
		end
	end
	
	return tbl[1]
end