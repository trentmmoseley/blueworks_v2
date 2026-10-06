-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local ScoreService    = Knit.CreateService({
    Name = "ScoreService",
    Client = {},

    Scores = {}
})

-- [[ funcs ]] --

-- Awards score to player
function ScoreService:AwardScore(char : Model, amount : number, reason : string, notify : boolean?)
    local Player = Players:GetPlayerFromCharacter(char)
    if not Player then return end
    
    self.Scores[Player.UserId][reason] = (self.Scores[Player.UserId][reason] or 0) + amount
    if notify then
        self.CommsService:SendSubtitle(nil, Player, string.format("%s%i PT%s. (%s)", amount > 0 and "+" or "-", math.abs(math.floor(amount)), math.abs(amount) ~= 1 and "S" or "", reason), Color3.fromHSV(1, amount > 0 and 0 or 1, 1))
    end
end

-- Manages player
function ScoreService:ManagePlayer(player : Player)
    self.Scores[player.UserId] = {}
end

-- Resets player
function ScoreService:ResetPlayer(player : Player)
    self.Scores[player.UserId] = {}
end

-- On knit init
function ScoreService:KnitInit() : ()
    self.CommsService = _G.Knit.GetService("CommsService")

    -- Manages players
    for _, player in Players:GetPlayers() do
        self:ManagePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:ManagePlayer(player)
    end)
end

return ScoreService