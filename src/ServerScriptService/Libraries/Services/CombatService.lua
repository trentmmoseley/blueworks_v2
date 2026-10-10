-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local CombatService   = Knit.CreateService({
    Name = "CombatService",
    Client = {},
    
    Attackers = {}, -- records time of last attack
    CharService = nil,
    HealthService = nil
})

local DamageCrosshair = require(RepStorage.Remotes.DamageCrosshair):Server()
local DamagePointer   = require(RepStorage.Remotes.DamagePointer):Server()
local Respawn         = require(RepStorage.Remotes.Respawn):Server()

local GameValues      = RepStorage.GameValues

CombatService.CharacterAttacked = _G.Signal.new()

-- [[ funcs ]] --

-- Damages entity
function CombatService:Damage(attacker : Model?, target : Model, damage : number, method : string, deathid : string, shedblood : boolean, hitpart : BasePart, otherhitparts : {}?) : boolean
    local attackerPresent = attacker ~= nil

    local AttackerClass = attackerPresent and self.CharService:GetCharacterClass(attacker) or nil
    local TargetClass = self.CharService:GetCharacterClass(target)

    local AttackerPlayer = attackerPresent and Players:GetPlayerFromCharacter(AttackerClass.Character) or nil
    local TargetPlayer = Players:GetPlayerFromCharacter(TargetClass.Character)

    local TargetHumanoid : Humanoid? = target:FindFirstChildOfClass("Humanoid")

    local AttackerID = attackerPresent and attacker:GetAttribute("ID") or nil
    local TargetID = target:GetAttribute("ID")

    local doesDamage = (not attackerPresent or (not self.TeamService:AreTeammates(attacker, target) and AttackerClass.HealthClass.canAttack)) and TargetClass.HealthClass.canBeAttacked
    if doesDamage then
        -- Records attackers
        if attackerPresent then
            if not self.Attackers[TargetID] then
                self.Attackers[TargetID] = {}
            end
            
            local foundInfo = false
            for _, attacker in self.Attackers[TargetID] do
                if attacker[1] == AttackerID then
                    attacker[2] += damage
                    foundInfo = true
                    break
                end            
            end

            if not foundInfo then
                table.insert(self.Attackers[TargetID], {AttackerID, os.clock()})
            end

            for _, attacker in self.Attackers[TargetID] do
                if attacker[1] ~= AttackerID then
                    attacker[2] -= 5
                end
            end
        end

        -- Boosts damage depending on hit part
        if hitpart then
            damage *= TargetClass.HitboxClass:GetMultiplier(hitpart.Name)
            hitpart:SetAttribute("_dmg", (hitpart:GetAttribute("_dmg") or 0) + damage)
        end
        self.HealthService:Damage(target, damage)

        -- Attacks Humanoid if downed
        if target:GetAttribute("isDowned") == true and TargetHumanoid then
            damage *= 3/5
            TargetHumanoid:TakeDamage(damage)
        end

        -- Other hit parts (for death screen)
        if otherhitparts then
            for _, part in target.Hitbox:GetChildren() do
                if table.find(otherhitparts, part.Name) then
                   part:SetAttribute("_dmg", (part:GetAttribute("_dmg") or 0) + damage)
                end
            end
        end
        
        -- Crosshairs + score + damage counter
        if AttackerPlayer then
            DamageCrosshair:Fire(AttackerPlayer)
            self.ScoreService:AwardScore(attacker, damage, "Enemy contact", false)
            self.VFXService:PlayVFX(AttackerPlayer, "DamageIndicator", "Indicator", target.PrimaryPart.CFrame, -damage, target.PrimaryPart.CFrame)
        end

        -- Damage indicator for target player
        if TargetPlayer and attackerPresent then
            DamagePointer:Fire(TargetPlayer, attacker.PrimaryPart.CFrame.Position)
        end

        -- Cause of death
        target:SetAttribute("CauseOfDeath", method)
        target:SetAttribute("DeathType", deathid)

        -- Bloodshed
        if shedblood then
            self.VFXService:GlobalVFX("Blood", "Blood", target.PrimaryPart.CFrame, target.PrimaryPart.CFrame, damage, target.Name)
        end

        self.CharacterAttacked:Fire(AttackerClass.Character, target)
    end

    return doesDamage
end

-- On knit init completion
function CombatService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
    self.HealthService = _G.Knit.GetService("HealthService")
    self.ScoreService = _G.Knit.GetService("ScoreService")
    self.TeamService = _G.Knit.GetService("TeamService")
    self.VFXService = _G.Knit.GetService("VFXService")

    -- Respawning
    Respawn:On(function(player)
        if player.Team == game.Teams.Spectators then
            player:LoadCharacterAsync()
        end
    end)
end

-- Compiles a target's attackers from most to least recent, pruning expired entries
function CombatService:GetAttackers(target : Model) : {}
    local TargetID = target:GetAttribute("ID")
    local attackers = self.Attackers[TargetID]
    if not attackers then
        return {}
    end

    -- Removes expired attackers
    local now = os.clock()
    for i = #attackers, 1, -1 do
        if attackers[i][2] < now then
            table.remove(attackers, i)
        end
    end

    -- Sorts from most to least recent
    table.sort(attackers, function(a, b)
        return a[2] > b[2]
    end)

    return attackers
end

-- Determines if two entities can hurt each other
function CombatService:CanHurt(entity1 : Model | Player, entity2 : Model | Player) : boolean
    local Player1 = entity1:IsA("Player") and entity1 or (Players:GetPlayerFromCharacter(entity1) or entity1)
    local Player2 = entity2:IsA("Player") and entity2 or (Players:GetPlayerFromCharacter(entity2) or entity2)

    if not Player1 or not Player2 then return false end

    return not self.TeamService:AreTeammates(Player1, Player2) or GameValues.Bools.doFriendlyFire.Value
end

return CombatService