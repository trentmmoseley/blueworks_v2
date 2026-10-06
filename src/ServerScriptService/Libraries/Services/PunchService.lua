-- Services
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local PunchService    = Knit.CreateService({
    Name = "PunchService",
    Client = {}
})

local PunchRequest    = require(RepStorage.Remotes.PunchRequest):Server()

local PlaySound       = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local NEXT_PUNCH      = {}

local PUNCH_SOUNDS    = {
    8646342913,
    9066673412,
    542443306,
}

-- [[ funcs ]] --

-- On knit init completion
function PunchService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
    self.CombatService = _G.Knit.GetService("CombatService")

    -- On punch
    PunchRequest:On(function(player : Player, hit : Instance)
        if player.Team ~= game.Teams.Squadmates then return end
        local Character = player.Character or player.CharacterAdded:Wait()
        if not Character then return end

        -- Distance check to ensure hit was valid
        local Distance = (hit.Position - Character.PrimaryPart.Position).Magnitude
        if Distance > 6 then return end

        local CharClass = self.CharService:GetCharacterClass(Character)

        local Hitbox = hit:FindFirstAncestor("Hitbox")
        if not Hitbox then return end

        -- Melee cooldown
        local NextUse = NEXT_PUNCH[player.UserId] or 0
        if NextUse > os.clock() then return end
        NEXT_PUNCH[player.UserId] = os.clock() + 5/4

        local HitChar = Hitbox.Parent
        PlaySound(PUNCH_SOUNDS[math.random(1, #PUNCH_SOUNDS)], "Hit", hit, nil, 1, Rand:NextNumber(0.95, 1.05))
        self.CombatService:Damage(Character, HitChar, math.random(20, 25), "BEATEN", "DEFAULT", true, hit, nil)
    end)
end

return PunchService