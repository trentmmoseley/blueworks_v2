local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Event(script.Name, function(action, anim : string?, loop : boolean?)
    if anim then
        return Guard.String(action), Guard.String(anim), Guard.Optional(Guard.Boolean)(loop)
    end
    return Guard.String(action)
end)