-- Services
local Debris          = game:GetService("Debris")
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local HealthService   = Knit.CreateService({
    Name = "HealthService",
    Client = {
        Death         = Knit.CreateSignal(),
    },

    CharService       = nil,
    Death             = _G.Signal.new()
})

local SelfDestruct    = require(RepStorage.Remotes.SelfDestruct):Server()

-- [[ funcs ]] --

-- Heals character
function HealthService:Heal(char : Model, health : number) : ()
    local Class = self.CharService:GetCharacterClass(char)
    Class.HealthClass:Increment(health)
end

-- Damages character
function HealthService:Damage(char : Model, amount : number) : ()
    local Class = self.CharService:GetCharacterClass(char)
    Class.HealthClass:Damage(amount)
end

-- Manages class
function HealthService:ManageClass(class : {}) : ()
    local Rig = class.Character
    local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
    local Health = Rig:GetAttribute("Health")

    local Player = Players:GetPlayerFromCharacter(Rig)

    Rig:GetAttributeChangedSignal("Health"):Connect(function()
        Health = Rig:GetAttribute("Health")
        if Health == 0 and class.HealthClass.humanoidDiesOnZero then
            -- NPCs skip the downed state entirely: they die (and ragdoll) immediately
            if Rig:GetAttribute("isNPC") then
                class.HealthClass:InstaKill()
                return
            end

            -- Code for PLAYERS + allies
            local Teammates = class.TeamClass:GetTeammates()
            if true and Rig:GetAttribute("beingBrainwashed") ~= true then
                class.HealthClass:DownPlayer()
            else
                if Rig:GetAttribute("beingBrainwashed") then
                    Rig:SetAttribute("CauseOfDeath", "BRAINWASHED")
                end
                class.HealthClass:InstaKill()
            end

        end
    end)

    Humanoid.Died:Connect(function()
        self.Death:Fire(class)
        self.Client.Death:FireAll(Rig)
        print(Rig.Name.."'s Health has dropped to zero (0)")

        if Player then
            Player.Team = game.Teams.Spectators
        elseif Rig:GetAttribute("isNPC") then
            -- the server-side rig is replaced by a client-local ragdoll corpse; clean
            -- it up once clients have processed the death so no one (e.g. a late
            -- joiner) ever sees a stiff, still-standing corpse
            Debris:AddItem(Rig, 30)
        end
    end)

    -- Insta-kill parts: touching any part named "_instakill" kills the character
    for _, part in Rig:GetDescendants() do
        if part:IsA("BasePart") then
            part.Touched:Connect(function(otherpart)
                if otherpart.Name == "_instakill" and Humanoid.Health > 0 then
                    Rig:SetAttribute("CauseOfDeath", "FALL_DAMAGE")
                    class.HealthClass:InstaKill()
                end
            end)
        end
    end
end

-- On knit init completion
function HealthService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")

    -- Manages chars
    for _, class in self.CharService:GetAllCharClasses() do
        self:ManageClass(class)
    end

    self.CharService.ClassAdded:Connect(function(class)
        self:ManageClass(class)
    end)

    -- Self-destruct requests are only honored while the power is out
    SelfDestruct:On(function(player : Player, cod : string)
        local Character = player.Character
        if not Character then return end
        local Class = self.CharService:GetCharacterClass(Character)
        if not Class then return end

        Character:SetAttribute("CauseOfDeath", cod)
        Class.HealthClass:InstaKill()
    end)
end

return HealthService