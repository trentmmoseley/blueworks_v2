-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local SequenceService = Knit.CreateService({
    Name = "SequenceService",
    Client = {},

    -- Players currently undergoing a sequence (e.g. the Time Up sequence) and
    -- therefore out of the round; future sequence types should track their
    -- state here too so gameplay systems can opt out through InSequence()
    Lost = {},
})

SequenceService.PlayerLost = _G.Signal.new()

local TimeUpEvent     = require(RepStorage.Remotes.TimeUp):Server()

-- [[ funcs ]] --

-- Determines if a player is Lost (ran out the round timer as a Squadmate)
function SequenceService:IsLost(entity : Model | Player) : boolean
    local Player = entity:IsA("Player") and entity or Players:GetPlayerFromCharacter(entity)
    return Player ~= nil and self.Lost[Player] == true
end

-- Determines if a player is undergoing any sequence at all
function SequenceService:InSequence(player : Player) : boolean
    return self:IsLost(player)
end

-- Mutes a player in every TextChatService channel, present and future
function SequenceService:MuteChat(player : Player) : ()
    local Channels = TextChatService:FindFirstChild("TextChannels")
    if not Channels then return end

    local function muteSource(source : Instance) : ()
        if source:IsA("TextSource") and source.UserId == player.UserId then
            source.CanSend = false
        end
    end

    local function watchChannel(channel : Instance) : ()
        if not channel:IsA("TextChannel") then return end

        for _, source in channel:GetChildren() do
            muteSource(source)
        end

        channel.ChildAdded:Connect(muteSource)
    end

    for _, channel in Channels:GetChildren() do
        watchChannel(channel)
    end

    Channels.ChildAdded:Connect(watchChannel)
end

-- Marks a player as Lost: the round no longer counts them, their leaderboard
-- status becomes DEAD, and their client is told to start the Time Up sequence.
-- entity is the PNDR subject code (from RoundService.Subjects) that the client's
-- sequence should use
function SequenceService:MarkLost(player : Player, entity : number?) : ()
    if not player or self.Lost[player] then return end

    self.Lost[player] = true
    player:SetAttribute("Lost", true)

    self:MuteChat(player)

    -- Counts as dead on the results screen even though the sequence kills them later
    self.ScoreService:MarkPlayerDead(player)

    -- Night vision dies with the lights (direct table lookup: GetCharacterClass
    -- yields when the class is missing, and MarkLost can run inside the round loop)
    local Character = player.Character
    local CharClass = Character and self.CharService.Characters[Character]
    local NVClass = CharClass and CharClass.NVClass
    if NVClass and NVClass.doNightVision then
        NVClass:Toggle(false)
    end

    TimeUpEvent:Fire(player, entity or 0)

    self.PlayerLost:Fire(player, Character, entity)
end

-- On knit init completion
function SequenceService:KnitInit() : ()
    self.ScoreService = _G.Knit.GetService("ScoreService")
    self.CharService = _G.Knit.GetService("CharService")

    Players.PlayerRemoving:Connect(function(player : Player)
        self.Lost[player] = nil
    end)
end

return SequenceService
