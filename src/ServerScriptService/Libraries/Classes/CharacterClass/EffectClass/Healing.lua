local Healing     = {}

function Healing.onStart(charclass)
    -- This function is called when the effect class is started
end

function Healing.onUpdate(charclass, dt, strength)
    -- This function is called every frame while the effect class is active
    charclass.HealthClass:Increment(dt * 5 * strength, true)
end

function Healing.onEnd(charclass)
    -- This function is called when the effect class is destroyed
end

return Healing