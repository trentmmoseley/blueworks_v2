local SupplyCache  = {}

-- Services
local S2           = game:GetService("ServerStorage")

-- Vars and consts
local SPAWN_CHANCE = 1/3 -- chance a cache spawn is chosen

-- [[ funcs ]] --

-- Cache set-up
local function setupCache(cachespawn : Part, SCFolder : Folder)
	local Cache = S2.Game.SupplyCaches.SupplyCache:Clone()
	Cache.Parent = SCFolder
	Cache:PivotTo(cachespawn.CFrame)
end

-- Main function
function SupplyCache.Init(map)
	local SCFolder = map.Interactables:FindFirstChild("SupplyCaches")
	if not SCFolder then
		SCFolder = Instance.new("Folder")
		SCFolder.Name = "SupplyCaches"
		SCFolder.Parent = map.Interactables
	end

	-- Manages supply caches; only a fraction of spawns are chosen each round
	for _, cache in pairs(map.Spawns.Structures.SupplyCaches:GetChildren()) do
		if math.random() <= SPAWN_CHANCE then
			setupCache(cache, SCFolder)
		end
		cache:Destroy()
	end
end

return SupplyCache
