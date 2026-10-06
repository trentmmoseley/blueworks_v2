local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Event(script.Name, function(mmt)
    return Guard.String(mmt)
end)