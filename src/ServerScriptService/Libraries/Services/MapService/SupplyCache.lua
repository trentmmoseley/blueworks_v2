local SupplyCache  = {}

-- Services
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")
local S2           = game:GetService("ServerStorage")

local InvService   = _G.Knit.GetService("InventoryService")
local StrayLoot    = _G.Knit.GetService("StrayLootService")

-- Modules and objects
local WeaponCache  = {}

local Items        = S2:WaitForChild("Tools")
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local Progress     = require(RepStorage.Modules.Util.Math.Progress)
local PlaySound    = require(RepStorage.Modules.Util.PlaySound)
local Tiers        = require(RepStorage.Modules.Data.Tiers)


-- Vars and consts
local SPAWN_CHANCE = 0.5 -- chance a cache spawn is chosen

local ITEM_CHANCES = {
	Ranged		   = 1.375,
	Healer		   = 1.75,
	Melee 		   = 1.15,
	Chemlight	   = 0.85,
	Battery 	   = 0.75,
}

-- [[ funcs ]] --

-- Gets random item type
local function getItemType()
	local Weight = 0
	for _, chance in pairs(ITEM_CHANCES) do
		Weight += chance
	end

	local RandNumber = Rand:NextNumber(0, Weight)
	Weight = 0

	for t, chance in pairs(ITEM_CHANCES) do
		Weight += chance
		if Weight >= RandNumber then
			return t
		end
	end
end

-- Compiles items of type
local function compileItems(t)
	local TypeItems = {}
	
	for _, item in pairs(Items:GetDescendants()) do
		if item:IsA("Tool") then
			local ItemInfo = require(item.Configuration.ItemInfo)
			if ItemInfo.Class == t then
				table.insert(TypeItems, item)
			end
		end
	end
	
	return TypeItems
end

-- Chooses item based on Prestige
local function chooseItem(items, tier)
	local ValidItems = {}
	for _, item in pairs(items) do
		if require(item.Configuration.ItemInfo).Tier == tier then
			table.insert(ValidItems, item)
		end
	end
	
	local UsedTable = #ValidItems > 0 and ValidItems or items
	return UsedTable[Rand:NextInteger(1, #UsedTable)]
end

-- Cache set-up
local function setupCache(cachespawn : Part, SCFolder : Folder)
	local Cache = S2.Game.SupplyCaches.SupplyCache:Clone()
	Cache.Parent = SCFolder
	Cache:PivotTo(cachespawn.CFrame)

	Cache.ProximityPrompt.Triggered:Connect(function(plrwhotriggered)
		if plrwhotriggered.Team == game.Teams.Squadmates then
			Cache.ProximityPrompt.Enabled = false
			Cache.MainPart.Open.TimePosition = 0.2
			Cache.MainPart.Open:Play()
			Cache.MainPart.SMOKE:Emit()

			task.defer(function()
				for _, part : BasePart in Cache:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
					end
				end
			end)

			local ToolCount = Rand:NextInteger(1, 3)
            for i = 1, ToolCount do
                local Tier = Tiers.getRandomTier(1, 6)
                local ItemType = getItemType()
                local CompiledItems = compileItems(ItemType)

                repeat
                    Tier = Tiers.getRandomTier(1, 6)
                    ItemType = getItemType()
                    CompiledItems = compileItems(ItemType)
                until #CompiledItems > 0

                local ChosenItem = chooseItem(CompiledItems, Tier)

                local CompiledTool = InvService:CompileTool(ChosenItem)
                StrayLoot:AddLoot(CompiledTool, ((Cache.PrimaryPart.CFrame + Vector3.new(0, 1, 0)) * CFrame.new(Lerp(-1, 1, ToolCount == 1 and 0.5 or Progress(i, 1, ToolCount)) * 4, 0, 0)).Position)
            end
		end
	end)
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
