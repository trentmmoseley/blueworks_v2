-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local MapService      = Knit.CreateService({
    Name = "MapService",
    Client = {},
    Map = game.Workspace:FindFirstChild("Playspace")
})

-- [[ funcs ]] --

-- Manages map
function MapService:Interactables()
    for _, module in script:GetChildren() do
        print(module)
        require(module).Init(self.Map)
    end
end

return MapService