-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

local StamClass       = {}
StamClass.__index     = StamClass

-- Modules and objects
local MMT_SETTINGS    = require(RepStorage.Modules.Data.MovementSettings)

-- Vars and consts
local DEFAULT_MAX     = 100
local STAM_EPSILON    = 1/60 -- stamina at or below this counts as exhausted

-- Constructor
function StamClass.new(charclass : {}) : {}
    local Self = setmetatable({}, StamClass)
    Self.CharacterClass = charclass

    Self.ClassName = "StaminaClass"
    Self.Classes = {}

    Self.Character = charclass.Character
    Self.Stamina = DEFAULT_MAX
    Self.MaxStamina = DEFAULT_MAX

    return Self
end

-- Determines if character can run
function StamClass:CanDoAction(action : string) : boolean
    return self.Stamina >= (MMT_SETTINGS[action] or MMT_SETTINGS["RUN"]).MinStamina
end

-- Replicates stamina to clients in whole-unit steps (called after every change)
function StamClass:Sync()
    local Floored = math.floor(self.Stamina)
    if Floored ~= self._lastSynced then
        self._lastSynced = Floored
        self.Character:SetAttribute("Stamina", Floored)
    end
end

-- Sets player Stamina
function StamClass:SetStamina(amount : number, interval : boolean)
    self.Stamina = math.clamp(interval and self.Stamina + amount or amount, 0, self.MaxStamina)
    self:Sync()
end

-- Starts class
function StamClass:Start()
    if self.CharacterClass.Player and self.CharacterClass.Player.Team == game.Teams.Spectators then return end

    -- Sets up character
    self.Stamina = DEFAULT_MAX
    self.MaxStamina = DEFAULT_MAX
    self._lastSynced = nil
    self.Character:SetAttribute("Stamina", self.Stamina)
    self.Character:SetAttribute("MaxStamina", self.MaxStamina)
    self:Sync()

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

-- Per-step stamina regen (called from CharClass)
function StamClass:Step(dt)
    -- Stamina regen
    local isMoving = self.CharacterClass.MovementClass:IsMoving()
    local MovementType = self.Character:GetAttribute("MovementType")

    local MmtInfo = MMT_SETTINGS[(not isMoving and MovementType == "RUN") and "WALK" or MovementType]

    self:SetStamina(MmtInfo.StaminaRegen * dt * (not isMoving and 1.25 or 1), true)
    if MovementType ~= "WALK" and (self.Stamina <= STAM_EPSILON or (MovementType == "RUN" and self.Character:GetAttribute("isAiming"))) then
        self.Character:SetAttribute("MovementType", "WALK")
    end
end

-- Destructor + stops class
function StamClass:Destroy() : ()
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

return StamClass
