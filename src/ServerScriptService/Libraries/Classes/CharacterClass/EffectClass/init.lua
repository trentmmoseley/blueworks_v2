-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local EffectClass     = {}
EffectClass.__index   = EffectClass

-- Constructor
function EffectClass.new(charclass : {}) : {}
    local Self = setmetatable({}, EffectClass)
    Self.CharacterClass = charclass

    Self.ClassName = "EffectClass"
    Self.Classes = {}
    Self.Effects = {}

    return Self
end

-- Checks if effect exists
function EffectClass:Check(effect : string) : boolean
    return self.Effects[effect] ~= nil and workspace:GetServerTimeNow() < self.Effects[effect][1]
end

-- Gets effect info
function EffectClass:Get(effect : string) : {}?
    return self.Effects[effect]
end

-- Adds effect
function EffectClass:Add(effect : string, duration : number?, strength : number?)
    strength = strength or 1

    -- Stacks onto an active effect: extends its remaining time and boosts its strength
    if self:Check(effect) then
        self.Effects[effect][1] += duration
        self.Effects[effect][2] = math.max(self.Effects[effect][2], strength)
        return
    end

    self.Effects[effect] = {workspace:GetServerTimeNow() + duration, strength} -- expiry time, strength
    local EffectModule = script:FindFirstChild(effect)

    if EffectModule then
        local EffectClass = require(EffectModule)
        EffectClass.onStart(self.CharacterClass)

        local Connection = nil
        Connection = RunService.PreSimulation:Connect(function(dt)
            if not (self.CharacterClass and self.CharacterClass.Character and self.CharacterClass.Character:FindFirstAncestor("Workspace") and script:FindFirstChild(effect) and self.Effects[effect]) or workspace:GetServerTimeNow() >= self.Effects[effect][1] then
                EffectClass.onEnd(self.CharacterClass)
                
                if self and self.Remove then
                    self:Remove(effect)
                end

                Connection:Disconnect()
                Connection = nil
            else
                EffectClass.onUpdate(self.CharacterClass, dt, self.Effects[effect][2])
            end
        end)
    end
end

-- Removes effect
function EffectClass:Remove(effect : string)
    self.Effects[effect] = nil
end

-- Starts class
function EffectClass:Start()
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
function EffectClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    for effect, _ in self.Effects do
        self:Remove(effect)
    end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return EffectClass