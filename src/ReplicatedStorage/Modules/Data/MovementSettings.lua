local MmtSettings = {
    CRAWL		  = {canJump = false,  crouchMMT = true,  Speed = 4,  MinStamina = 0,  Noise = 0,   StaminaRegen = 15},
    CROUCH		  = {canJump = false,  crouchMMT = true,  Speed = 6,  MinStamina = 0,  Noise = 0,   StaminaRegen = 10},
    RUN		 	  = {canJump = true,   crouchMMT = false, Speed = 24, MinStamina = 20, Noise = 2,   StaminaRegen = -5},
    SLIDE		  = {canJump = false,  crouchMMT = false, Speed = 26, MinStamina = 30, Noise = 1/8, StaminaRegen = -5},
	WALK		  = {canJump = true,   crouchMMT = false, Speed = 8, MinStamina = 0,  Noise = 1,   StaminaRegen = 5},
    DOWNED		  = {canJump = false,  crouchMMT = true,  Speed = 6,  MinStamina = 0,  Noise = 0,   StaminaRegen = 10},
}

return MmtSettings