-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

-- Modules and objects
local BulletInfo      = require(RepStorage.Modules.Data.BulletInfo)
local Knit            = require(RepStorage.Packages.Knit)

local AmmoClass       = {}
AmmoClass.__index     = AmmoClass

-- Constructor
function AmmoClass.new(charclass : {}) : {}
    local Self = setmetatable({}, AmmoClass)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character

    Self.ClassName = "AmmoClass"
    Self.Classes = {}

    return Self
end

-- Starts class
function AmmoClass:Start()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    for bullet, _ in BulletInfo do
        self.Rig:SetAttribute("Ammo_"..bullet, 10000)
    end
end

-- Destructor + stops class
function AmmoClass:Destroy() : ()
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

return AmmoClass