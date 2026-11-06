-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local ScoreService    = Knit.CreateService({
    Name = "ScoreService",
    Client = {
        Scores = {},
        Profiles = Knit.CreateProperty({}),
    },

    Scores = {},
    Profiles = {},
})

-- Vars and consts
local GameValues      = RepStorage.GameValues
local RoundStatus     = GameValues.Strings.Status

local PLAYABLE_TEAMS  = {
    Squadmates = true,
    Subjects = true,
}

-- Registry of primary PNDR entities (by rig name) counted in the leaderboard even though they are NPCs
local TRACKED_ENTITIES = {
    Proxy = true,
    Tethered = true,
}

-- [[ funcs ]] --

-- Pushes the current match profiles to all clients
function ScoreService:PushProfiles() : ()
    self.Client.Profiles:Set(self.Profiles)
end

-- Awards score to player
function ScoreService:AwardScore(char : Model, amount : number, reason : string, notify : boolean?)
    local Player = Players:GetPlayerFromCharacter(char)
    if not Player then return end

    self.Scores[Player.UserId][reason] = (self.Scores[Player.UserId][reason] or 0) + amount
    if notify then
        self.CommsService:SendSubtitle(nil, Player, string.format("%s%i PT%s. (%s)", amount > 0 and "+" or "-", math.abs(math.floor(amount)), math.abs(amount) ~= 1 and "S" or "", reason), Color3.fromHSV(1, amount > 0 and 0 or 1, 1))
    end

    self.Client.Scores[Player.UserId] = self.Scores[Player.UserId]

    -- Keeps the player's match profile in sync
    local Profile = self.Profiles[Player.UserId]
    if Profile then
        Profile.Score += amount
        self:PushProfiles()
    end
end

-- Updates the match profile of a player or tracked entity when it spawns into a playable team
function ScoreService:TrackCharacter(class : {}) : ()
    local Character = class.Character
    local Player = class.Player

    -- Only players and registered primary entities are tracked
    local Key = Player and Player.UserId or (TRACKED_ENTITIES[Character.Name] and Character.Name)
    if not Key then return end

    -- Spectator spawns leave the profile untouched
    local Team = Character:GetAttribute("Team")
    if not PLAYABLE_TEAMS[Team] then return end

    -- NPCs have no join event, so their profile is created on first spawn
    local Profile = self.Profiles[Key]
    if not Profile then
        Profile = {
            Score = 0,
            Status = "SURVIVED",
            Team = Team,
        }
        self.Profiles[Key] = Profile
    end

    Profile.Team = Team
    if Profile.Status ~= "DEAD" then
        Profile.Status = "SURVIVED"
    end

    self:PushProfiles()
end

-- Marks the profile of a player or tracked entity as dead; team and score are preserved for the results
function ScoreService:OnDeath(class : {}) : ()
    local Character = class.Character
    local Player = class.Player

    local Key = Player and Player.UserId or (TRACKED_ENTITIES[Character.Name] and Character.Name)
    if not Key then return end

    local Profile = self.Profiles[Key]
    if not Profile then return end

    Profile.Status = "DEAD"
    self:PushProfiles()
end

-- Manages player
function ScoreService:ManagePlayer(player : Player)
    self:ResetPlayer(player)
end

-- Resets player (join only: the profile persists across respawns until the match ends)
function ScoreService:ResetPlayer(player : Player)
    self.Scores[player.UserId] = {}
    self.Client.Scores[player.UserId] = {}

    self.Profiles[player.UserId] = {
        Score = 0,
        Status = "SURVIVED",
        Team = "???",
    }
    self:PushProfiles()
end

-- Compiles leaderboard
function ScoreService:CompileLeaderboard() : {{}}
    local Leaderboard = {["SURVIVED"] = {}, ["DEAD"] = {}}

    -- Iterates all profiles so players who left mid-round and tracked entities still appear
    for id, profile in self.Profiles do
        if Leaderboard[profile.Status] then
            -- Player profiles are keyed by UserId; entity profiles are keyed by rig name
            profile.Username = type(id) == "number" and Players:GetNameFromUserIdAsync(id) or id
            table.insert(Leaderboard[profile.Status], profile)
        end
    end

    local FinalLeaderboard = {}

    for _, profiles in Leaderboard do
        table.sort(profiles, function(a, b)
            return a.Score > b.Score
        end)
    end

    -- Inserts all profiles into FinalLeaderboard (survived players always come first)
    for _, status in {"SURVIVED", "DEAD"} do
        for _, profile in ipairs(Leaderboard[status]) do
            table.insert(FinalLeaderboard, profile)
        end
    end

    return FinalLeaderboard
end

-- Client-callable wrapper (Client methods receive the Client table as self; self.Server is the service)
function ScoreService.Client:CompileLeaderboard(_player : Player) : {{}}
    return self.Server:CompileLeaderboard()
end

-- Gets score of player
function ScoreService.Client:GetScore(player : Player) : number
    local Scores = self.Server.Scores[player.UserId]
    if Scores then
        local Sum = 0
        for _, amount in Scores do
            Sum += amount
        end
        return Sum
    end
    return 0
end

-- On knit init
function ScoreService:KnitInit() : ()
    self.CommsService = _G.Knit.GetService("CommsService")
    self.CharService = _G.Knit.GetService("CharService")
    self.HealthService = _G.Knit.GetService("HealthService")

    -- Manages players
    for _, player in Players:GetPlayers() do
        self:ManagePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:ManagePlayer(player)
    end)

    -- Handles a player leaving: in-game players who leave mid-round count as dead
    Players.PlayerRemoving:Connect(function(player : Player)
        self.Scores[player.UserId] = nil
        self.Client.Scores[player.UserId] = nil

        local Profile = self.Profiles[player.UserId]
        if Profile and PLAYABLE_TEAMS[Profile.Team] and RoundStatus.Value ~= "Mission over" then
            -- Keeps the profile for the leaderboard, marked as dead
            Profile.Status = "DEAD"
        else
            self.Profiles[player.UserId] = nil
        end

        self:PushProfiles()
    end)

    -- Updates profiles when players spawn into a playable team
    for _, class in self.CharService:GetAllCharClasses() do
        self:TrackCharacter(class)
    end

    self.CharService.ClassAdded:Connect(function(class : {})
        self:TrackCharacter(class)
    end)

    -- Marks profiles as dead on death
    self.HealthService.Death:Connect(function(class : {})
        self:OnDeath(class)
    end)
end

return ScoreService
