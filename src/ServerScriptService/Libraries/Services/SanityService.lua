-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local SanityService   = Knit.CreateService({
    Name = "SanityService",
    Client = {}
})

local BWPaths         = game.Workspace:WaitForChild("Cutscenes"):WaitForChild("BWPaths")

-- [[ funcs ]] --

-- Mutes or unmutes a player in every TextChatService channel
function SanityService:SetChatMuted(player : Player, muted : boolean) : ()
    local Channels = TextChatService:FindFirstChild("TextChannels")
    if not Channels then return end

    for _, channel in Channels:GetChildren() do
        if channel:IsA("TextChannel") then
            for _, source in channel:GetChildren() do
                if source:IsA("TextSource") and source.UserId == player.UserId then
                    source.CanSend = not muted
                end
            end
        end
    end
end

-- Manages class
function SanityService:ManageClass(class : {}) : ()
    local Rig = class.Character
    local Player = class.Player
    local Sanity = Rig:GetAttribute("Sanity")

    Rig:GetAttributeChangedSignal("Sanity"):Connect(function()
        Sanity = Rig:GetAttribute("Sanity")
    end)

    -- Brainwashed players cannot chat; Lost players stay muted even after escaping
    if Player then
        Rig:GetAttributeChangedSignal("beingBrainwashed"):Connect(function()
            local beingBrainwashed = Rig:GetAttribute("beingBrainwashed") == true

            if beingBrainwashed or not self.SequenceService:IsLost(Player) then
                self:SetChatMuted(Player, beingBrainwashed)
            end
        end)
    end
end

-- On knit init completion
function SanityService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
    self.SequenceService = _G.Knit.GetService("SequenceService")

    -- Manages chars
    for _, class in self.CharService:GetAllCharClasses() do
        self:ManageClass(class)
    end

    self.CharService.ClassAdded:Connect(function(class)
        self:ManageClass(class)
    end)

    -- Brainwashing paths
    local CharDebounce = {}

    for _, exit in BWPaths.Exits:GetChildren() do
        exit.Touched:Connect(function(otherpart)
            local Char = otherpart.Parent.Parent
            local Player = Players:GetPlayerFromCharacter(Char)
            local Class = self.CharService:GetCharacterClass(Char)
            Char:SetAttribute("beingBrainwashed", false)

            if Player then
                local plrSurvives = math.random(1, 4) == 1

                if not CharDebounce[Char] or os.clock() >= CharDebounce[Char] then
                    CharDebounce[Char] = os.clock() + 1
                    if plrSurvives then
                        Class.SanityClass:Unbrainwash()
                        _G.Knit.GetService("ScoreService"):AwardScore(Char, 100, "Escaped PNDR-0770", true)
                    else
                        Class.HealthClass:InstaKill()
                    end
                end
            end
        end)
    end

    BWPaths._kill.Touched:Connect(function(otherpart)
        local Char = otherpart.Parent.Parent
        local Player = Players:GetPlayerFromCharacter(Char)
        local Class = self.CharService:GetCharacterClass(Char)

        if Player then
            Class.HealthClass:InstaKill()
        end
    end)
end

return SanityService
