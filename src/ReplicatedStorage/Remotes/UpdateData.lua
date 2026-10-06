local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event(script.Name, function(player, path, value)
	return Guard.Instance(player), Guard.String(path), Guard.Any(value)
end)
