-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local _tpClass        = {}
_tpClass.__index      = _tpClass

-- Constructor
function _tpClass.new(charclass : {}) : {}
    local Self = setmetatable({}, _tpClass)
    Self.CharacterClass = charclass

    Self.ClassName = "_tpClass"
    Self.Classes = {}

    return Self
end

-- Starts class
function _tpClass:Start()
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
function _tpClass:Destroy() : ()
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

return _tpClass