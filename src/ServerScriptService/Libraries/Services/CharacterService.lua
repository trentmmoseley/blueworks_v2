-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")
local S2               = game:GetService("ServerStorage")
local S3               = game:GetService("ServerScriptService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local TheService      = Knit.CreateService({
    Name = "_tpService",
    Client = {}
})

-- [[ funcs ]] --
-- On knit init completion
function TheService:KnitInit() : ()
    
end

return TheService