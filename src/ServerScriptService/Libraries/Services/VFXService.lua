-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)

local VFXService      = Knit.CreateService({
    Name = "VFXService",
    Client = {
        VFXRequest    = Knit.CreateSignal()
    }
})

-- [[ funcs ]] --

-- Plays VFX for player
function VFXService:PlayVFX(player : Player, module : string, vfx : string, origin : CFrame | Vector3, ...) : ()
    VFXService.Client.VFXRequest:Fire(player, module, vfx, origin, ...)
end

-- Plays VFX for all players
function VFXService:GlobalVFX(module : string, vfx : string, origin : CFrame | Vector3, ...) : ()
    for _, player in Players:GetPlayers() do
        self:PlayVFX(player, module, vfx, origin, ...)
    end
end

return VFXService