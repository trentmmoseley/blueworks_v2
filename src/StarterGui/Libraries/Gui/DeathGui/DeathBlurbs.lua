local DeathBlurbs = {}

local BLURBS      = {
    DEFAULT       = "Sudden cessation of all bodily functions without any clear cause. Cause of Subject #user_id's death remains a mystery to this day.",

    FALL_DAMAGE   = "Major bone fractures and lacerations detected throughout Subject #user_id's lower body. Injuries and setting imply a fall from a great height.",
    NO_CORPSE     = "Unit #user_id has been declared missing after vanishing without a trace during his mission out in [REDACTED]. A search-and-rescue task force is currently working to recover pronoun_object.",
    PROXY_1       = "Multiple deep lacerations found across Unit #user_id's dead body. Bodycam footage confirms death by PNDR-4075.",
    PROXY_2       = "Unit #user_id found dead with a large pool of blood around and under pronoun_possessive throat area. Surveillance tapes confirm death by PNDR-4075.",
    PROXY_3       = "Bits and pieces of Unit #user_id found as far as one (1) km. away from the site of pronoun_possessive last mission. Presumably killed in a particularly violent encounter with PNDR-4075."
}

-- Fetches blurb
function DeathBlurbs.getBlurb(cod)
    return BLURBS[cod]
end

return DeathBlurbs