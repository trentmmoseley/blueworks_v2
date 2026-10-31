local Template = {}

local InvService = _G.Knit.GetService("InventoryService")

-- Services
local Players 	 = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")

-- Modules and objects
local _general   = require(script.Parent._general)
local VMAnim 	 = require(RepStorage.Remotes.VMAnim):Server()

-- Inits item
function Template.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	local UsingPlayer = Players:GetPlayerFromCharacter(char)

	-- Loads the third-person use animation onto the character (Action4 so it plays over Hold)
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	local UseAnim = Humanoid and Humanoid:LoadAnimation(item.Configuration.Anims.Char.Use)
	if UseAnim then
		UseAnim.Priority = Enum.AnimationPriority.Action4
		UseAnim.Looped = true
	end

	local UseAnimID = item.Configuration.Anims.VM.Use.AnimationId

	local Anims = {}
	for _, anim in pairs(item.Configuration.Anims.Char:GetChildren()) do
		local LoadedAnim = Humanoid:LoadAnimation(anim)
		LoadedAnim.Priority = Enum.AnimationPriority[table.find({"Run", "Hold"}, anim.Name) and "Action" or "Action4"]
		Anims[anim.Name] = LoadedAnim
	end

	local isHolding = false

	-- Toggles isHolding
	local function toggleHolding(on : boolean)
		isHolding = on
		char:SetAttribute("useRiotShield", isHolding)

		if UseAnim then
			if isHolding then
				UseAnim:Play()
			else
				UseAnim:Stop()
			end
		end

		if UsingPlayer then
			if isHolding then
				VMAnim:Fire(UsingPlayer, "START", UseAnimID, true)
			else
				VMAnim:Fire(UsingPlayer, "STOP", UseAnimID)
			end
		end
	end
	
	table.insert(BaseItem["Functions"]["Equip"], function()
		toggleHolding(false)

		-- Loads durability
		if not item:GetAttribute("Durability") then
			item:SetAttribute("Durability", 100)
		end
	end)
	
	table.insert(BaseItem["Functions"]["Unequip"], function()
		toggleHolding(false)
	end)
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		toggleHolding(true)
	end)
	
	table.insert(BaseItem["Functions"]["Deactivate"], function()
		toggleHolding(false)
	end)

	-- Destroys item if durability is depleted
	local LastDurability = item:GetAttribute("Durability") or 100
	item:GetAttributeChangedSignal("Durability"):Connect(function()
		local Durability = item:GetAttribute("Durability")
		if Durability == 0 then
			item:SetAttribute("Stack", 0)
		else
			Anims.Block:Play()
			VMAnim:Fire(UsingPlayer, "START", item.Configuration.Anims.VM.Block.AnimationId)
		end

		-- Plays the Hit sound if the shield is still usable, or the Break sound if
		-- destroyed, for every client (including the user). Sourced from ItemDisplays
		-- on each client because the owner's client strips the equipped tool's
		-- Handle (see MeleeLocal)
		if Durability < LastDurability then
			local SoundName = Durability == 0 and "Break" or "Hit"
			if item.Handle and item.Handle:FindFirstChild(SoundName) then
				InvService.Client.ActionRequest:FireAll("PLAY_SOUND", char, item.Name, SoundName)
			end
		end

		LastDurability = Durability
	end)
	
	return BaseItem
end

return Template