-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local LeanClass        = {}
LeanClass.__index      = LeanClass

-- Constructor
function LeanClass.new(charclass : {}) : {}
    local Self = setmetatable({}, LeanClass)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character

    Self.ClassName = "LeanClass"
    Self.Classes = {}

    return Self
end

-- Starts class
function LeanClass:Start()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- Sets lean vals
    self.Rig:SetAttribute("isLeaning", false)
    self.Rig:SetAttribute("LeanDirection", "R")
end

-- Leaning
function LeanClass:Lean(start : boolean, dir : string?) : ()
    if start then
        self.Rig:SetAttribute("isLeaning", true)
        self.Rig:SetAttribute("LeanDirection", dir)
    else
        self.Rig:SetAttribute("isLeaning", false)
    end
end

-- Destructor + stops class
function LeanClass:Destroy() : ()
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

return LeanClass