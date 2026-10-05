-- Services
local RepStorage = game:GetService("ReplicatedStorage")
local S3         = game:GetService("ServerScriptService")

_G.Signal 		 = require(RepStorage.Packages._Index["sleitnick_signal@2.0.3"].signal)

-- Modules and objects
_G.Knit          = require(RepStorage.Packages.Knit)
_G.Knit.AddServices(S3.Libraries.Services)

_G.Knit.Start():andThen(function()
    print("Knit operational on server!")
end):catch(warn)

_G.Knit.Loaded   = true