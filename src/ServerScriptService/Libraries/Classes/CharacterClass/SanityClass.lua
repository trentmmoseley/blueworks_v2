-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local Rand            = Random.new()

local Knit            = require(RepStorage.Packages.Knit)
local BWSequence      = require(RepStorage.Remotes.BrainwashSequence):Server()

local SanityClass     = {}
SanityClass.__index   = SanityClass

-- Constructor
function SanityClass.new(charclass : {}) : {}
    local Self = setmetatable({}, SanityClass)

    Self.Player = Players:GetPlayerFromCharacter(charclass.Character)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character

    Self.ClassName = "SanityClass"
    Self.Classes = {}
    Self.HealConn = nil
    Self.HealthDecay = false

    Self.BrainwashedClone = nil
    Self.PrevCFrame = nil

    return Self
end

-- Sets Health
function SanityClass:Set(number : number) : ()
    self.Rig:SetAttribute("Sanity", math.clamp(number, 0, self.Rig:GetAttribute("MaxSanity")))
end

-- Increments Health
function SanityClass:Increment(number : number) : ()
    self:Set(self.Rig:GetAttribute("Sanity") + number)
end

-- Damages player
function SanityClass:Damage(amount  : number) : ()
    self:Increment(-amount)

    -- Heals Sanity if not zero
    if not self.HealConn and self.Rig:GetAttribute("Sanity") > 0 then
        self.HealConn = RunService.PreSimulation:Connect(function(dt)
            if not self.HealConn then return end
            if not (self.Rig and self.Rig:FindFirstAncestor("Characters")) or self.Rig:GetAttribute("Sanity") >= self.Rig:GetAttribute("MaxSanity") or self.Rig:GetAttribute("Sanity") == 0 then
                self.HealConn:Disconnect()
                self.HealConn = nil
            else
                self:Increment(dt)
            end
        end)
    else
        if self.Rig:GetAttribute("Sanity") == 0 and self.Player then
            local PrimaryPart = self.Rig.PrimaryPart
            local Head = self.Rig:FindFirstChild("Head")
            if not PrimaryPart or not Head then return end -- character mid-unload

            self.PrevCFrame = PrimaryPart.CFrame
            BWSequence:Fire(self.Player, Head.CFrame)
            self.Rig:SetAttribute("beingBrainwashed", true)

            self.BrainwashedClone = _G.Knit.GetService("NPCService"):CreateNPC("Brainwashed", self.PrevCFrame)
            self.BrainwashedClone:SetAttribute("TrackingID", self.Rig:GetAttribute("ID"))

            self.Rig:PivotTo(game.Workspace.Cutscenes.BWPaths.Spawnpoint.CFrame)
            self:Set(self.Rig:GetAttribute("MaxSanity"))

            task.delay(20, function()
                if self.Rig:GetAttribute("beingBrainwashed") and not self.HealthDecay then
                    self.HealthDecay = RunService.PreSimulation:Connect(function(dt)
                        if not (self.Rig and self.Rig:FindFirstAncestor("Workspace") and self.Rig:GetAttribute("Health") > 0 and self.Rig:GetAttribute("beingBrainwashed")) then
                            self.HealthDecay:Disconnect()
                            self.HealthDecay = nil
                        else
                            _G.Knit.GetService("CombatService"):Damage(nil, self.Rig, dt, "BRAINWASHED", "DEFAULT", false)
                        end
                    end)
                end
            end)
        end
    end
end

-- Unbrainwashes player
function SanityClass:Unbrainwash()
    self.Rig:SetAttribute("beingBrainwashed", false)
    self.Rig:PivotTo(self.PrevCFrame)

    if self.BrainwashedClone then
        self.BrainwashedClone:Destroy()
        self.BrainwashedClone = nil
    end
end

-- Starts class
function SanityClass:Start()
    self.Rig:SetAttribute("Sanity", 100)
    self.Rig:SetAttribute("MaxSanity", 100)
    self.Rig:SetAttribute("beingBrainwashed", false)
    
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
function SanityClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    if self.HealthDecay then
        self.HealthDecay:Disconnect()
        self.HealthDecay = nil
    end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return SanityClass