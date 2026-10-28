-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Teams           = game:GetService("Teams")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local TeamService     = Knit.CreateService({
    Name = "TeamService",
    Client = {},
    Teams = {},
    Tracked = {}
})

-- [[ funcs ]] --

-- Determines if character is loaded
function TeamService:CharIsLoaded(character : Model | Player) : boolean
    local Player = character:IsA("Player") and character or Players:GetPlayerFromCharacter(character)
    local Character = not Player and character or Player.Character

    return Character:GetAttribute("Team") ~= "Spectators"
end

-- Determines if player is in-game
function TeamService:IsInGame(player : Model | Player) : boolean
    local Player = player:IsA("Player") and player or (Players:GetPlayerFromCharacter(player) or player)
    return Player:GetAttribute("inGame") == true
end

-- Determines if two entites are teammates
function TeamService:AreTeammates(entity1 : Model | Player, entity2 : Model | Player) : boolean
    local Player1 = entity1:IsA("Player") and entity1 or (Players:GetPlayerFromCharacter(entity1) or entity1)
    local Player2 = entity2:IsA("Player") and entity2 or (Players:GetPlayerFromCharacter(entity2) or entity2)

    if not Player1 or not Player2 then return false end

    return Player1:GetAttribute("Team") == Player2:GetAttribute("Team")
end

-- Gets player's teammates
function TeamService:GetTeammates(player : Model | Player) : {Model | Player}
    local Player = player:IsA("Player") and player or (Players:GetPlayerFromCharacter(player) or player)
    local Teammates = {}

    if not Player then return Teammates end

    for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
        if self:AreTeammates(Player, char) and not self.CharService:AreCharsSame(Player, char) then
            table.insert(Teammates, char)
        end
    end

    return Teammates
end

-- Gets player's enemies
function TeamService:GetEnemies(player : Model | Player) : {Model | Player}
    local Player = player:IsA("Player") and player or (Players:GetPlayerFromCharacter(player) or player)
    local Enemies = {}

    if not Player then return Enemies end

    for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
        if not self:AreTeammates(Player, char) and not self.CharService:AreCharsSame(Player, char) then
            table.insert(Enemies, char)
        end
    end

    return Enemies
end

-- Gets player's team
function TeamService:GetTeam(player : Model | Player) : string
    local Player = player:IsA("Player") and player or (Players:GetPlayerFromCharacter(player) or player)
    if not Player then return "Spectators" end
    return Player:GetAttribute("Team")
end

-- Gets all members of team
function TeamService:GetTeamMembers(team : string) : {}
    return self.Teams[team]
end

-- Registers character in its team's member list and keeps membership updated
function TeamService:TrackCharacter(character : Model) : ()
    if self.Tracked[character] then return end

    local Record = {Team = nil, Connections = {}}
    self.Tracked[character] = Record

    -- Moves character between team lists
    local function moveToTeam(newTeam : string?) : ()
        if Record.Team and self.Teams[Record.Team] then
            local Index = table.find(self.Teams[Record.Team], character)
            if Index then
                table.remove(self.Teams[Record.Team], Index)
            end
            Record.Team = nil
        end

        if newTeam then
            if not self.Teams[newTeam] then
                self.Teams[newTeam] = {}
            end
            table.insert(self.Teams[newTeam], character)
            Record.Team = newTeam
        end
    end

    moveToTeam(character:GetAttribute("Team"))

    -- Moves character if its team changes
    table.insert(Record.Connections, character:GetAttributeChangedSignal("Team"):Connect(function()
        moveToTeam(character:GetAttribute("Team"))
    end))

    -- Removes character once it leaves the game
    table.insert(Record.Connections, character.AncestryChanged:Connect(function(_, parent)
        if parent then return end

        moveToTeam(nil)

        for _, conn in Record.Connections do
            conn:Disconnect()
        end

        self.Tracked[character] = nil
    end))
end

-- On knit init
function TeamService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")

    -- Registers a member list for every current and future team
    for _, team in Teams:GetChildren() do
        self.Teams[team.Name] = {}
    end

    Teams.ChildAdded:Connect(function(team : Team)
        self.Teams[team.Name] = self.Teams[team.Name] or {}
    end)

    Teams.ChildRemoved:Connect(function(team : Team)
        self.Teams[team.Name] = nil
    end)

    -- Tracks all current and future characters
    for character in self.CharService:GetAllCharClasses() do
        self:TrackCharacter(character)
    end

    self.CharService.ClassAdded:Connect(function(charClass : {})
        self:TrackCharacter(charClass.Character)
    end)
end

return TeamService