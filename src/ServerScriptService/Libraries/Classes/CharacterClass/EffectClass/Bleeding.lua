-- Services
local VFXService   = _G.Knit.GetService("VFXService")

-- Modules and objects
local Bleeding     = {}

function Bleeding.onStart(charclass)
    -- This function is called when the effect class is started
end

function Bleeding.onUpdate(charclass, dt)
    -- This function is called every frame while the effect class is active
    charclass.HealthClass:Damage(dt, true)

    local shedsBlood = math.random(0, 2000) == 0
    local PrimaryPart = charclass.Character.PrimaryPart
    if shedsBlood and PrimaryPart then
        VFXService:GlobalVFX("Blood", "Blood", PrimaryPart.CFrame, PrimaryPart.CFrame, math.random(5, 22), charclass.Character.Name)
    end
end

function Bleeding.onEnd(charclass)
    -- This function is called when the effect class is destroyed
end

return Bleeding