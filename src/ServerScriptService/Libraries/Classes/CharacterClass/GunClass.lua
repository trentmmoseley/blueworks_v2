-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local GunClass        = {}
GunClass.__index      = GunClass

-- Constructor
function GunClass.new(charclass : {}) : {}
    local Self = setmetatable({}, GunClass)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character

    Self.ClassName = "GunClass"
    Self.Classes = {}

    return Self
end

-- Starts class
function GunClass:Start()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- Establishes gun attributes
    self.Rig:SetAttribute("isAiming", false)
    self.Rig:SetAttribute("isFiring", false)
    self.Rig:SetAttribute("isReloading", false)
    self.Rig:SetAttribute("ShotsFired", 0)
end

-- Toggles aiming
function GunClass:ToggleAiming(toggle : boolean) : ()
    self.Rig:SetAttribute("isAiming", toggle)
end

-- Toggles reloading
function GunClass:ToggleReloading(toggle : boolean) : ()
    self.Rig:SetAttribute("isReloading", toggle)
end

-- Destructor + stops class
function GunClass:Destroy() : ()
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

return GunClass