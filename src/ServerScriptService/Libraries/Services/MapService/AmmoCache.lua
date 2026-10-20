local AmmoCache    = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CommsService = _G.Knit.GetService("CommsService")

-- Modules and objects
local AmmoPacks    = RepStorage.VFX.AmmoPacks

local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local Progress     = require(RepStorage.Modules.Util.Math.Progress)
local PlaySound    = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local AP_SIZES     = {

	["Medium"]     = {0.85,  {1, 12}},
	["Shells"]     = {0.625, {1, 8}},
	["Short"]      = {1,     {5, 15}},
	["Small"]      = {1,     {2, 12}}, -- weight, min/max rounds

}

local AMMO_SOUNDS  = {

	8391933427,
	8217058484,
	7405483764,
	8028186410,
	6829539267

}

local MAX_PACKS    = 4
local CACHE_CHANCE = 0.35 -- chance a cache spawn is chosen

-- [[ funcs ]] --

-- Gets random ammo type
local function getAmmoType(Rand : Random)
	local Weight = 0
	for _, info in pairs(AP_SIZES) do
		Weight += info[1]
	end

	local RandNumber = Rand:NextNumber(0, Weight)
	Weight = 0

	for ammo, info in pairs(AP_SIZES) do
		Weight += info[1]
		if Weight >= RandNumber then
			return ammo
		end
	end
end

-- Creates ammo pack
local function createAmmoPack(ammotype, parent, cf, Rand : Random)
	local AmmoPack = AmmoPacks[ammotype]:Clone()
	AmmoPack.Parent = parent
	AmmoPack:PivotTo(cf)

	-- Prevents parts from colliding with player
	for _, part in pairs(AmmoPack:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "AmmoPacks"
		end
	end

	local ProxPrompt = Instance.new("ProximityPrompt")
	ProxPrompt.ObjectText = string.format("%s Ammo", AmmoPack.Name)
	ProxPrompt.ActionText = "Collect"
	ProxPrompt.HoldDuration = 0.25
	ProxPrompt.Parent = AmmoPack

	PlaySound(AMMO_SOUNDS[math.random(1, #AMMO_SOUNDS)], "Equip", nil, AmmoPack.PrimaryPart.Position, 1, Rand:NextNumber(0.95, 1.05))

	-- When the player picks it up
	ProxPrompt.Triggered:Connect(function(plrwhotriggered)
		if plrwhotriggered.Team == game.Teams.Squadmates then
			local Char = plrwhotriggered.Character or plrwhotriggered.CharacterAdded:Wait()
			local AmmoRange = AP_SIZES[ammotype][2]
			local AmmoGiven = math.random(AmmoRange[1], AmmoRange[2])
			Char:SetAttribute("Ammo_"..ammotype, Char:GetAttribute("Ammo_"..ammotype) + AmmoGiven)

			PlaySound(AMMO_SOUNDS[math.random(1, #AMMO_SOUNDS)], "AmmoEquip", nil, AmmoPack.PrimaryPart.Position, 1, Rand:NextNumber(0.95, 1.05))
			AmmoPack:Destroy()

			CommsService:SendSubtitle(nil, plrwhotriggered, string.format("+%i %s", AmmoGiven, ammotype), "White")
		end
	end)

	return AmmoPack
end

-- Cache set-up
local function setupCache(cachespawn : Part, APFolder : Folder)
	local Cache = game.ServerStorage.Game.AmmoCaches.AmmoCache:Clone()
	Cache.Parent = APFolder
	Cache:PivotTo(cachespawn.CFrame)

	local ProxPrompt = Cache:WaitForChild("ProximityPrompt")

	local Rand = Random.new()

	ProxPrompt.Triggered:Connect(function()
		ProxPrompt:Destroy()

		local PackCount = Rand:NextInteger(1, MAX_PACKS)
		for i = 1, PackCount do
			local AmmoType = getAmmoType(Rand)
			createAmmoPack(AmmoType, APFolder, Cache.PrimaryPart.CFrame * CFrame.new(0, 2, 0) + (Cache.PrimaryPart.CFrame * CFrame.Angles(0, PackCount == 1 and 0 or math.rad(45 * Lerp(-1, 1, Progress(i, 1, PackCount))), 0)).LookVector * 2, Rand)

			TweenService:Create(Cache.Lid.Hinge, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), {CFrame = Cache.Lid.Hinge.CFrame * CFrame.Angles(math.rad(60), 0, 0)}):Play()
			TweenService:Create(Cache.Front.SurfaceGui, TweenInfo.new(10), {LightInfluence = 1}):Play()
		end

		-- Sound
		Cache.Front.Open:Play()
		task.wait(0.75)
		Cache.Front.Open:Stop()
	end)
end

-- Main function
function AmmoCache.Init(map)
	local APFolder = map:FindFirstChild("AmmoPacks")
	if not APFolder then
		APFolder = Instance.new("Folder")
		APFolder.Name = "AmmoPacks"
		APFolder.Parent = map.Interactables
	end

	-- Manages ammo caches; only a fraction of spawns are chosen each round
	for _, cache in pairs(map.Spawns.Structures.AmmoCaches:GetChildren()) do
		if math.random() <= CACHE_CHANCE then
			setupCache(cache, APFolder)
		end
		cache:Destroy()
	end
end

return AmmoCache
