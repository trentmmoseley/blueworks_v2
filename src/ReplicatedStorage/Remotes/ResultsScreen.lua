local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Event(script.Name, function(winner : string, how : string)
    return Guard.String(winner), Guard.String(how)
end)