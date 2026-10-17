local DeathBlurbs = {}

local BLURBS      = {
    DEFAULT       = "Sudden cessation of all bodily functions without any clear trauma, illness, or infection. Cause of Subject #user_id's death remains a mystery to this day.",

    FALL_DAMAGE   = "Major bone fractures and lacerations detected throughout Subject #user_id's lower body. Injuries and setting have led us to assume a fall from a great height.",
    NO_CORPSE     = "Unit #user_id is among the hundreds of personnel who disappeared without a trace the night of BASE-████'s sitewide lockdown. Search and rescue teams are currently working to recover pronoun_object, dead or alive, amid what remains of the facility.",
    PROXY_1       = "Multiple deep lacerations found across Unit #user_id's dead body. Assumed to have been attacked by PNDR-4075.",
    PROXY_2       = "Unit #user_id found dead with a large pool of blood forming around pronoun_possessive throat area. Surveillance tapes confirm death by PNDR-4075.",
    TESLA_GATE    = "Unit #user_id was found dead near an active Tesla Gate checkpoint. Severe electrical burns throughout body indicate death by electrocution.",
}

-- Fetches blurb
function DeathBlurbs.getBlurb(cod)
    return BLURBS[cod]
end

return DeathBlurbs