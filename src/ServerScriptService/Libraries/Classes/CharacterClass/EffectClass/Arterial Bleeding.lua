-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local VFXService   = _G.Knit.GetService("VFXService")

-- Modules and objects
local AB           = {}
local TrigWave     = require(RepStorage.Modules.Util.Math.TrigWave)

function AB.onStart(charclass)
    -- This function is called when the effect class is started
end

function AB.onUpdate(charclass, dt)
    -- This function is called every frame while the effect class is active
    charclass.HealthClass:Damage(TrigWave("sin", 1/2, 6, os.clock(), 0, 1/2) ^ 10 / 50, true)

    local shedsBlood = math.random(0, 1000) == 0
    local PrimaryPart = charclass.Character.PrimaryPart
    if shedsBlood and PrimaryPart then
        VFXService:GlobalVFX("Blood", "Blood", PrimaryPart.CFrame, PrimaryPart.CFrame, math.random(5, 22), charclass.Character.Name)
    end
end

function AB.onEnd(charclass)
    -- This function is called when the effect class is destroyed
end

return AB