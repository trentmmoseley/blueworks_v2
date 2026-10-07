-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local ScoreClass      = {}
ScoreClass.__index    = ScoreClass

-- Constructor
function ScoreClass.new(charclass : {}) : {}
    local Self = setmetatable({}, ScoreClass)
    Self.CharacterClass = charclass

    Self.ClassName = "ScoreClass"
    Self.Classes = {}
    Self.Scores = {}

    return Self
end

-- Starts class
function ScoreClass:Start()
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
function ScoreClass:Destroy() : ()
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

return ScoreClass