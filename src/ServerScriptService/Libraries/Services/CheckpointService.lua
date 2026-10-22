-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local CheckpointService = Knit.CreateService({
    Name = "CheckpointService",
    Client = {},
    Codes = {},
    Nodes = {},
})

CheckpointService.TestSignal = _G.Signal.new()

-- Vars and consts
CheckpointService.ThisValue  = "abcde"

-- [[ funcs ]] --

-- Resets Codes
function CheckpointService:ResetCodes() : ()
    self.Codes = {}
end

-- Checks if code exists
function CheckpointService:CheckForCode(code : number) : boolean
    return table.find(self.Codes, code) ~= nil
end

-- Registers code for Node to store
function CheckpointService:RegisterCode() : number
    local Number = math.random(0, 999999)
    table.insert(self.Codes, Number)
    return Number
end

-- Registers Node
function CheckpointService:RegisterNode(node : Model) : ()
    -- Tracks checkpoint via ID
    local ID = math.random(1, 9999999)
    node:SetAttribute("ID", ID)
    CheckpointService.Nodes[ID] = {Model = node}
end

-- Deregisters Node
function CheckpointService:DeregisterNode(id : number) : ()
    CheckpointService.Nodes[id] = nil
end

-- On knit init completion
function CheckpointService:KnitInit() : ()
    self:ResetCodes()
end

return CheckpointService