-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)

local CharacterClass   = {}
CharacterClass.__index = CharacterClass

-- [[ funcs ]] --

-- Constructor
function CharacterClass.new(character : Model) : {}
    local Self = setmetatable({}, CharacterClass)

    Self.Rig = character
    Self.Player = Players:GetPlayerFromCharacter(character)
    Self.isNPC = not Self.Player

    -- Sets up classes
    Self.Classes = {}

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
    for _, part : BasePart in self.Rig:GetDescendants() do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Characters"
        end
    end

    print(`Started character class for character "{self.Rig.Name}"`)
end

return CharacterClass