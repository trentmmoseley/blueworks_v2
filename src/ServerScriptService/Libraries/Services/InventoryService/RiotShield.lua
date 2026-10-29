local Template = {}

local _general = require(script.Parent._general)

-- Inits item
function Template.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)
	
	table.insert(BaseItem["Functions"]["Equip"], function()
		print("works")
	end)
	
	table.insert(BaseItem["Functions"]["Unequip"], function()
		print("also works")
	end)
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		print("a;slkdfas;ldfkjasd;lkfj works")
	end)
	
	table.insert(BaseItem["Functions"]["Deactivate"], function()
		print("asdffsdasdfasdfafsadfsda works sdf sdfdsfsdfsd")
	end)
	
	return BaseItem
end

return Template