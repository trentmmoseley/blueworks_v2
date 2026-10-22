-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local CheckpointService = Knit.CreateService({
    Name = "CheckpointService",
    Client = {},
    Codes = {}
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
    while self:CheckForCode(Number) do
        Number = math.random(0, 999999)
    end
    table.insert(self.Codes, Number)
    return Number
end

-- On knit init completion
function CheckpointService:KnitInit() : ()
    self:ResetCodes()
end

return CheckpointService