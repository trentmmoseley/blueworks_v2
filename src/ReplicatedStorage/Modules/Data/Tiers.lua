local Tiers = {
    ["Tiers"] = {
        {
            Name = "0",
            Color = Color3.fromRGB(255, 255, 255),
            Chance = 100,
        },
        {
            Name = "I",
            Color = Color3.fromRGB(0, 255, 255),
            Chance = 30,
        },
        {
            Name = "II",
            Color = Color3.fromRGB(0, 0, 255),
        },
        {
            Name = "III",
            Color = Color3.fromRGB(100, 0, 255),
        },
        {
            Name = "IV",
            Color = Color3.fromRGB(255, 175, 0),
        },
        {
            Name = "V",
            Color = Color3.fromRGB(255, 0, 0),
        },
    }
}

-- Chooses random Tier
function Tiers.getRandomTier(min : number?, max : number?, r : Random)
    assert(max >= min, "Maxmmum value must be greater than minimum!")

    -- Compiles rarities
	local Weight = 0
	for i = min, max do
		local Tier = Tiers.Tiers[i]
		if Tier.Chance then
            Weight += Tier.Chance
        end
	end

    -- Generates random number to compare rarities with
	local RandNumber = r:NextNumber(0, Weight)
	Weight = 0

    -- Chooses Prestige based on random number
	for i = min, max do
		local Tier = Tiers.Tiers[i]
		if Tier.Chance then
            Weight += Tier.Chance
		
            if RandNumber <= Weight then
                return i
            end
        end
	end

    return Tiers.Tiers[1]
end

return Tiers