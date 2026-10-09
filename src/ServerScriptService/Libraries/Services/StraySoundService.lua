-- Services
local Players            = game:GetService("Players")
local RepStorage         = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit               = require(RepStorage.Packages.Knit)

local StraySoundService  = Knit.CreateService({
    Name = "StraySoundService",
    Client = {
        SoundRequest     = Knit.CreateSignal()
    }
})

-- [[ funcs ]] --

-- Plays sound for player
function StraySoundService:PlaySound(player : Player, soundName : string) : ()
    StraySoundService.Client.SoundRequest:Fire(player, soundName)
end

-- Plays sound for all players
function StraySoundService:GlobalSound(soundName : string) : ()
    for _, player in Players:GetPlayers() do
        self:PlaySound(player, soundName)
    end
end

-- Stops sound for player
function StraySoundService:StopSound(player : Player, soundName : string) : ()
    StraySoundService.Client.SoundRequest:Fire(player, soundName, true)
end

-- Stops sound for all players
function StraySoundService:GlobalStop(soundName : string) : ()
    for _, player in Players:GetPlayers() do
        self:StopSound(player, soundName, true)
    end
end

return StraySoundService
