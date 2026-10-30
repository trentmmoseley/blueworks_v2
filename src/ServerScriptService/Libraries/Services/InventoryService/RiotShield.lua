local Template = {}

local _general = require(script.Parent._general)

-- Inits item
function Template.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	local isHolding = false
	
	table.insert(BaseItem["Functions"]["Equip"], function()
		print("works")
	end)
	
	table.insert(BaseItem["Functions"]["Unequip"], function()
		isHolding = false
	end)
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		isHolding = true
	end)
	
	table.insert(BaseItem["Functions"]["Deactivate"], function()
		isHolding = false
	end)
	
	return BaseItem
end

return Template