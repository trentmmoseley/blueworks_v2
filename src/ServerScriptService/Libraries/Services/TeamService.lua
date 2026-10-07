-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local TeamService     = Knit.CreateService({
    Name = "TeamService",
    Client = {}
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

-- On knit init
function TeamService:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")
end

return TeamService