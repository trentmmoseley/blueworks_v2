local Battery      = {}

-- Services
local Players 	   = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")

local CommsService = _G.Knit.GetService("CommsService")

-- Modules and objects
local _general     = require(script.Parent._general)
local PlaySound    = require(RepStorage.Modules.Util.PlaySound)
local VMAnim 	   = require(RepStorage.Remotes.VMAnim):Server()

-- Inits item
function Battery.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	local UsingPlayer = Players:GetPlayerFromCharacter(char)
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		local Class = _G.Knit.GetService("CharService"):GetCharacterClass(char)
		local NVClass = Class.NVClass
		if NVClass then
			if char:GetAttribute("NVBattery") < char:GetAttribute("MaxNVBattery") then
				item:SetAttribute("Stack", math.max(item:GetAttribute("Stack") - 1, 0))
				CommsService:SendSubtitle(nil, Class.Player, "Replaced Goggles' batteries", "Green")
				PlaySound(116598892477316, "BatteryReplace", char.PrimaryPart, nil, 1, 1)
				NVClass:Replenish(50)

				local AnimID = item.Configuration.Anims.VM.Use.AnimationId
				if UsingPlayer then
					VMAnim:Fire(UsingPlayer, "START", AnimID)
				end
			else
				CommsService:SendSubtitle(nil, Class.Player, "Goggles' batteries already sufficient", "White")
			end
		end
	end)
	
	return BaseItem
end

return Battery