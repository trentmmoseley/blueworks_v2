local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Function(script.Name, function()
	return true
end, function(data)
	return Guard.Any(data)
end)
