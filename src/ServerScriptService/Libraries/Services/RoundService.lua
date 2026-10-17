-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local RoundService    = Knit.CreateService({
    Name = "RoundService",
    Client = {}
})

local GameValues      = RepStorage.GameValues

-- [[ funcs ]] --

-- Calculates Node progress
function RoundService:NodeProgress() : number
    return 1 - GameValues.Numbers.NodesLeft.Value / math.max(GameValues.Numbers.NodesLeft:GetAttribute("Init"), 1)
end

return RoundService