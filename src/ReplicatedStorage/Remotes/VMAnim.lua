local RepStorage = game:GetService("ReplicatedStorage")
local Guard      = require(RepStorage.Packages.Guard)
local Red        = require(RepStorage.Packages.Red)

return Red.Event(script.Name, function(action, anim : string?)
    if anim then
        return Guard.String(action), Guard.String(anim)
    end
    return Guard.String(action)
end)