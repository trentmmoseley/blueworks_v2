-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)

local NoiseClass      = {}
NoiseClass.__index    = NoiseClass

-- Modules and objects
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame   = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- Constructor
function NoiseClass.new(charclass : {}) : {}
    local Self = setmetatable({}, NoiseClass)
    Self.CharacterClass = charclass

    Self.ClassName = "NoiseClass"
    Self.Classes = {}
    Self.Rig = charclass.Character

    Self.NoiseConn = nil
    Self.Profile = {
        Chat     = 0,
        Gun      = 0,
        Movement = 0,
        Radio    = 0,
        Voice    = 0,
    }
    Self.Noise = 0

    return Self
end

-- Adds to Noise
function NoiseClass:SetNoise(t : string, noise : number, interval : boolean) : () -- type of noise, amount, interval or not
    if interval then
        self.Profile[t] += noise
    else
        self.Profile[t] = noise
    end
end

-- Starts class
function NoiseClass:Start()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- Starts connection
    self.NoiseConn = RunService.PreSimulation:Connect(function(dt)
        local TN = 0
        for tag, val in self.Profile do
            TN += val
            if tag == "Movement" then continue end
            if tag ~= "Radio" then
                self.Profile[tag] = Lerp(val, 0, LerpByFrame(tag ~= "Gun" and 1/12 or 1/6, dt))
            else
                self.Profile[tag] = math.max(val - dt, 0)
            end
        end
        self.Noise = TN
        self.Rig:SetAttribute("Noise", self.Noise)
    end)
end

-- Destructor + stops class
function NoiseClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    self.NoiseConn:Disconnect()
    self.NoiseConn = nil

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return NoiseClass