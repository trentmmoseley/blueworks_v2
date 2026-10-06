-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)
local InvRep          = require(RepStorage.Modules.Util.InvRep)

local InvClass        = {}
InvClass.__index      = InvClass

-- Constructor
function InvClass.new(charclass : {}) : {}
    local Self = setmetatable({}, InvClass)
    Self.CharacterClass = charclass

    Self.ClassName = "InventoryClass"
    Self.Classes = {}

    Self.Items = {}
    Self.CurrentSlot = 0
    Self.MaxSlots = 6

    return Self
end

-- Gets item in inventory
function InvClass:GetItemOfName(name : string) : {}?
    return InvRep:GetItemOfName(self.Items, name)
end

-- Gets index of item in inventory
function InvClass:GetItemIndexOfName(name : string) : number?
    return InvRep:GetItemIndexOfName(self.Items, name)
end

-- Gets next available slot of inventory
function InvClass:GetNextAvailableSlot() : number?
    return InvRep:GetNextAvailableSlot(self.Items, self.MaxSlots)
end

-- Determines if player can pick up item
function InvClass:CanPickUp(name : string) : boolean | string
    return InvRep:CanPickUp(name, self.Items, self.MaxSlots)
end

-- Starts class
function InvClass:Start()
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
function InvClass:Destroy() : ()
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

return InvClass