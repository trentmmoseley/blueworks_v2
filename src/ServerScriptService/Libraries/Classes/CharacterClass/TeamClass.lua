-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local TeamClass       = {}
TeamClass.__index     = TeamClass

-- Constructor
function TeamClass.new(charclass : {}) : {}
    local Self = setmetatable({}, TeamClass)
    Self.CharacterClass = charclass

    Self.ClassName = "TeamClass"
    Self.TeamName = "Spectators"
    
    Self.Classes = {}

    return Self
end

-- Gets player team
function TeamClass:GetTeam() : string
    return self.TeamName
end

-- Sets team
function TeamClass:SetTeam(teamname : string) : ()
    self.TeamName = teamname
    self.CharacterClass.Character:SetAttribute("Team", teamname)
end

-- Starts class
function TeamClass:Start()
    -- Sets team automatically if player
    if self.CharacterClass.Player then
        self:SetTeam(self.CharacterClass.Player.Team.Name)
    else
        self:SetTeam("Subjects")
    end

    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end
end

-- Destructor + stops class
function TeamClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return TeamClass