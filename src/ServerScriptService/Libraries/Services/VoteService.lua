-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local VoteService     = Knit.CreateService({
    Name = "VoteService",
    Client = {
        Votes = {},
        VoteStarted = Knit.CreateSignal(),
        VoteUpdated = Knit.CreateSignal(),
        VoteEnded = Knit.CreateSignal(),
    },
    Votes = {},
})

local VoteRequest     = require(RepStorage.Remotes.VoteRequest):Server()

-- [[ funcs ]] --

-- Fires a client signal to members of the voting team only
local function fireToTeam(signal : any, votingteam : string, ...) : ()
    signal:FireFilter(function(player : Player)
        return player.Team and player.Team.Name == votingteam
    end, ...)
end

-- Determines winner of vote
function VoteService:GetWinner(name : string) : any
    local Vote = self.Votes[name]
    if not Vote then return nil end

    local Winners, WinnerCount = {}, 0
    for choice, voters in pairs(Vote.Choices) do
        if #voters > WinnerCount then
            Winners = {choice}
            WinnerCount = #voters
        elseif #voters == WinnerCount then
            table.insert(Winners, choice)
        end
    end

    return Winners[math.random(1, #Winners)]
end

-- Starts vote; blocks until it ends and returns the winning choice
function VoteService:Vote(name : string, choices : {string}, duration : number, votingteam : string) : any
    local VoteInfo = {
        Choices = {},
        EndTime = workspace:GetServerTimeNow() + duration,
        VotingTeam = votingteam
    }

    -- Registers vote pools for choices
    for _, choice in pairs(choices) do
        VoteInfo.Choices[choice] = {}
    end

    self.Votes[name] = VoteInfo
    self.Client.Votes[name] = VoteInfo
    fireToTeam(self.Client.VoteStarted, votingteam, name, VoteInfo)

    task.wait(duration)

    local Winner = self:GetWinner(name)
    self:TerminateVote(name, Winner)
    return Winner
end

-- Gets vote info
function VoteService.Client:GetVoteInfo(player : Player, name : string) : any
    local VoteInfo = self.Votes[name]
    if VoteInfo and player.Team and player.Team.Name == VoteInfo.VotingTeam then
        return VoteInfo
    end

    return nil
end

-- Locks the player out of gameplay while their team's vote is running
function VoteService.Client:BeginInitiation(player : Player) : ()
    local TeamName = player.Team and player.Team.Name
    if TeamName and self.Votes[TeamName.."Spawn"] then
        player:SetAttribute("InitiationActive", true)
    end
end

-- Unlocks the player once their initiation sequence ends; only allowed once no vote is running
function VoteService.Client:FinishInitiation(player : Player) : ()
    local TeamName = player.Team and player.Team.Name
    if not TeamName or not self.Votes[TeamName.."Spawn"] then
        player:SetAttribute("InitiationActive", false)
    end
end

-- On knit init
function VoteService:KnitInit() : ()
    VoteRequest:On(function(player : Player, vote : string, choice : any)
        local VoteInfo = self.Votes[vote]
        if not VoteInfo or not player.Team or player.Team.Name ~= VoteInfo.VotingTeam then return end

        -- Removes player from all choices
        for _, voters in pairs(VoteInfo.Choices) do
            for i, voter in pairs(voters) do
                if voter == player then
                    table.remove(voters, i)
                    break
                end
            end
        end

        -- Adds player to new choice
        local Voters = typeof(choice) == "string" and VoteInfo.Choices[choice] or nil
        if not Voters then return end

        table.insert(Voters, player)

        self.Client.Votes[vote] = VoteInfo
        fireToTeam(self.Client.VoteUpdated, VoteInfo.VotingTeam, vote, VoteInfo)
    end)
end

-- Terminates vote
function VoteService:TerminateVote(name : string, winner : any) : ()
    local VoteInfo = self.Votes[name]

    self.Votes[name] = nil
    self.Client.Votes[name] = nil

    if VoteInfo then
        fireToTeam(self.Client.VoteEnded, VoteInfo.VotingTeam, name, winner)
    end
end

return VoteService
