-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local TheService      = Knit.CreateService({
    Name = "_tpService",
    Client = {}
})

TheService.TestSignal = _G.Signal.new()

-- Vars and consts
TheService.ThisValue  = "abcde"

-- [[ funcs ]] --

function TheService.Client:HelloWorld() : ()
    print("Hello world!")
end

function TheService:GetRandomValue() : number
    return math.random(0, 1)
end

-- On knit init completion
function TheService:KnitInit() : ()
    
end

-- On game start
function TheService:KnitStart() : ()
    
end

return TheService