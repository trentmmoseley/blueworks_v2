-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local EffectService   = Knit.CreateService({
    Name = "EffectService",
    Client = {
        EffectUpdate  = Knit.CreateSignal(),
    }
})

-- [[ funcs ]] --

local function getClass(char : Model)
    return _G.Knit.GetService("CharService"):GetCharacterClass(char).EffectClass
end

local function updatePlayer(char : Model)
    local Player = Players:GetPlayerFromCharacter(char)
    if Player then
        EffectService.Client.EffectUpdate:Fire(Player, getClass(char).Effects)
    end
end

-- Adds effect
function EffectService:Add(char : Model, effect : string, duration : number?, strength : number?)
    getClass(char):Add(effect, duration, strength)
    updatePlayer(char)
end

-- Removes effect
function EffectService:Remove(char : Model, effect : string)
    getClass(char):Remove(effect)
    updatePlayer(char)
end

-- Checks for effect
function EffectService:Check(char : Model, effect : string)
    local Class = getClass(char)

    if Class and Class.Effects[effect] and Class.Effects[effect][1] > os.clock() then
        return true, Class.Effects[effect][1]
    end
end

return EffectService