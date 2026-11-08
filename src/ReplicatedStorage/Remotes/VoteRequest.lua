local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Event(script.Name, function(vote : string, choice : any)
    return Guard.String(vote), choice
end)