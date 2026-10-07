-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)

local CharacterClass   = {}
CharacterClass.__index = CharacterClass

local AmmoClass        = require(script.AmmoClass)
local EffectClass      = require(script.EffectClass)
local GunClass         = require(script.GunClass)
local HealthClass      = require(script.HealthClass)
local HitboxClass      = require(script.HitboxClass)
local InvClass         = require(script.InventoryClass)
local MovementClass    = require(script.MovementClass)
local NoiseClass       = require(script.NoiseClass)
local ScoreClass       = require(script.ScoreClass)
local StamClass        = require(script.StaminaClass)
local TeamClass        = require(script.TeamClass)

-- [[ funcs ]] --

-- Constructor
function CharacterClass.new(character : Model) : {}
    local Self = setmetatable({}, CharacterClass)

    Self.Character = character
    Self.Player = Players:GetPlayerFromCharacter(character)
    Self.isNPC = not Self.Player

    -- Sets up classes
    Self.Classes = {
        AmmoClass.new(Self),
        EffectClass.new(Self),
        GunClass.new(Self),
        HealthClass.new(Self),
        HitboxClass.new(Self),
        InvClass.new(Self),
        MovementClass.new(Self),
        NoiseClass.new(Self),
        ScoreClass.new(Self),
        StamClass.new(Self),
        TeamClass.new(Self),
    }
    Self.StepConn = nil

    for _, class in Self.Classes do
        Self[class.ClassName] = class
    end

    return Self
end

-- Starts class
function CharacterClass:Start() : ()
    for _, class in self.Classes do
        if class.Start then
            class:Start()
        end
    end

    -- Toggle char collisions
    for _, part : BasePart in self.Character:GetDescendants() do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Characters"
        end
    end

    -- Single per-step loop driving all sub-class step logic
    self.StepConn = RunService.PreSimulation:Connect(function(dt)
        if self.MovementClass and self.StaminaClass then
            self.MovementClass:Step(dt)
            self.StaminaClass:Step(dt)
        end
    end)

    print(`Started character class for character "{self.Character.Name}"`)
end

-- Pushes new classes to character
function CharacterClass:PushClasses() : ()
    for _, class in self.Classes do
        if not self[class.CllassName] then
            self[class.ClassName] = class
        end
    end
end

-- Destructor
function CharacterClass:Destroy() : ()
    print(`Removing character "{self.Character.Name}" from game...`)

    -- Unloads classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    -- Removes char. from game
    self.Character:Destroy()

    -- Erases own memory
    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return CharacterClass