-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)

local CharacterClass   = {}
CharacterClass.__index = CharacterClass

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
        TeamClass.new(Self),
    }

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