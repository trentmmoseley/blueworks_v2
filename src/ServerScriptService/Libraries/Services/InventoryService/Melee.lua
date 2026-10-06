local Melee      = {}

local InvService = _G.Knit.GetService("InventoryService")

-- Modules and objects
local _general   = require(script.Parent._general)

-- Inits item
function Melee.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	-- Loads the third-person attack animations onto the character
	local Humanoid      = char:FindFirstChildOfClass("Humanoid")
	local AttacksFolder = item.Configuration.Anims.Char:FindFirstChild("Attacks")
	local AttackAnims   = {}

	-- Vars and consts
	local NextUse = 0

	if Humanoid and AttacksFolder then
		for _, anim in AttacksFolder:GetChildren() do
			local LoadedAnim = Humanoid:LoadAnimation(anim)
			LoadedAnim.Priority = Enum.AnimationPriority.Action4
			table.insert(AttackAnims, LoadedAnim)
		end
	end

	-- Collects the Handle's "Use<number>" sounds
	local UseSounds = {}
	for _, sound in item.Handle:GetChildren() do
		if sound:IsA("Sound") and string.match(sound.Name, "^Use%d+$") then
			table.insert(UseSounds, sound.Name)
		end
	end

	table.insert(BaseItem["Functions"]["Activate"], function()
		if os.clock() < NextUse then return end
		NextUse = os.clock() + ItemInfo.Debounce

		-- Plays a random third-person attack animation (replicates to all clients)
		if #AttackAnims > 0 then
			AttackAnims[math.random(1, #AttackAnims)]:Play()
		end

		-- Tells every client (including the user) to play a random Use sound
		if #UseSounds > 0 then
			InvService.Client.ActionRequest:FireAll("PLAY_SOUND", char, item.Name, UseSounds[math.random(1, #UseSounds)])
		end
	end)

	return BaseItem
end

return Melee
