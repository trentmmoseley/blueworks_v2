-- Services
local RepStorage      = game:GetService("ReplicatedStorage")
local S2              = game:GetService("ServerStorage")
local Rand            = Random.new()

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local MeleeService    = Knit.CreateService({
    Name = "MeleeService",
    Client = {}
})

local MeleeRequest    = require(RepStorage.Remotes.MeleeRequest):Server()

-- Vars and consts
local NEXT_MELEE_USE  = {}
local EFFECT_DURATION = 30

-- [[ funcs ]] --

-- On knit init completion
function MeleeService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
    self.CombatService = _G.Knit.GetService("CombatService")
    self.EffectService = _G.Knit.GetService("EffectService")
    self.InvService = _G.Knit.GetService("InventoryService")

    MeleeRequest:On(function(player : Player, hit : Instance)
        if player.Team ~= game.Teams.Squadmates then return end
        local Character = player.Character or player.CharacterAdded:Wait()
        if not Character then return end
        local MeleeTool = Character:FindFirstChildOfClass("Tool")
        if not MeleeTool or MeleeTool:GetAttribute("Class") ~= "Melee" then return end
        local ItemInfo = require(S2:FindFirstChild(MeleeTool.Name, true).Configuration.ItemInfo)

        -- Distance check to ensure hit was valid
        local Distance = (hit.Position - Character.PrimaryPart.Position).Magnitude
        if Distance > ItemInfo.Range then return end

        local CharClass = self.CharService:GetCharacterClass(Character)

        local Hitbox = hit:FindFirstAncestor("Hitbox")
        if not Hitbox then return end

        -- Melee cooldown
        local NextUse = NEXT_MELEE_USE[player.UserId] or 0
        if NextUse > os.clock() then return end
        NEXT_MELEE_USE[player.UserId] = os.clock() + ItemInfo.Debounce

        local HitChar = Hitbox.Parent
        local Damaged = self.CombatService:Damage(Character, HitChar, ItemInfo.Damage, "STABBED", "DEFAULT", true, hit, nil)

        -- Plays the tool's Hit sound for every client (including the attacker).
        -- Sourced from ItemDisplays on each client because the attacker's own
        -- client strips the equipped tool's Handle (see Viewmodel)
        if MeleeTool.Handle and MeleeTool.Handle:FindFirstChild("Hit") then
            self.InvService.Client.ActionRequest:FireAll("PLAY_SOUND", Character, MeleeTool.Name, "Hit")
        end

        -- Rolls the weapon's EffectChances; each positive roll afflicts the
        -- target with that effect for EFFECT_DURATION seconds
        if Damaged and ItemInfo.EffectChances then
            for effect, chance in ItemInfo.EffectChances do
                if Rand:NextNumber() <= chance then
                    self.EffectService:Add(HitChar, effect, EFFECT_DURATION)
                end
            end
        end
    end)
end

return MeleeService