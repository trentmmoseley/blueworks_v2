-- Services
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

local Knit           = require(RepStorage.Packages.Knit)

local NVClass        = {}
NVClass.__index      = NVClass

-- Vars and consts
local NV_BATTERY_DEF = 100

-- Constructor
function NVClass.new(charclass : {}) : {}
    local Self = setmetatable({}, NVClass)
    Self.CharacterClass = charclass
    Self.Character = charclass.Character

    Self.ClassName = "NVClass"
    Self.NVType = "Standard"
    Self.BatteryDrainRate = 5/9
    Self.Classes = {}

    Self.doNightVision = false
    Self.NVConn = nil

    return Self
end

-- Toggles NV
function NVClass:Toggle(on : boolean?)
    local dNV = on or not self.doNightVision
    self.doNightVision = dNV
    self.Character:SetAttribute("doNightVision", self.doNightVision)

    if self.doNightVision == true then
        self.NVConn = RunService.PreSimulation:Connect(function(dt)
            local endConn = false
            self.Character:SetAttribute("NVBattery", math.clamp(self.Character:GetAttribute("NVBattery") - self.BatteryDrainRate * dt, 0, self.Character:GetAttribute("MaxNVBattery")))
            if self.Character:GetAttribute("NVBattery") < dt then
                NVClass:Toggle(false)
                endConn = true
            end

            if endConn then
                self.NVConn:Disconnect()
                self.NVConn = nil
            end
        end)
    else
        if self.NVConn then
            self.NVConn:Disconnect()
            self.NVConn = nil
        end
    end
end

-- Starts class
function NVClass:Start()
    -- Setup
    self.Character:SetAttribute("doNightVision", self.doNightVision)
    self.Character:SetAttribute("NVBattery", NV_BATTERY_DEF)
    self.Character:SetAttribute("MaxNVBattery", self.Character:GetAttribute("NVBattery"))
    self.Character:SetAttribute("NVType", self.NVType)

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
function NVClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    if self.NVConn then
        self.NVConn:Disconnect()
        self.NVConn = nil
    end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return NVClass