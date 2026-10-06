local _general = {}

-- Inits item
function _general.initItem(item, char)
	local ItemMod 	  	   = {

		["Item"]	 	   = item,
		["Functions"] 	   = {

			["Equip"] 	   = {},
			["Unequip"]    = {},

			["Activate"]   = {},
			["Deactivate"] = {},
			

		},

		["Handle"]		   = item.Handle,

		["ItemConfig"]	   = item:FindFirstChild("Configuration"),
		["ItemInfo"]	   = require(item.Configuration.ItemInfo),

	}

	function ItemMod.onEquip(...)
		for _, func in pairs(ItemMod["Functions"]["Equip"]) do
			func(...)
		end
	end

	function ItemMod.onUnequip(...)
		for _, func in pairs(ItemMod["Functions"]["Unequip"]) do
			func(...)
		end
	end

	function ItemMod.onActivate(...)
		for _, func in pairs(ItemMod["Functions"]["Activate"]) do
			func(...)
		end
	end

	function ItemMod.onDeactivate(...)
		for _, func in pairs(ItemMod["Functions"]["Deactivate"]) do
			func(...)
		end
	end

	return ItemMod
end

return _general