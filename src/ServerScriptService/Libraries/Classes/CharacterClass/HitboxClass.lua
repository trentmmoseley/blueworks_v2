-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

local HitboxClass     = {}
HitboxClass.__index   = HitboxClass

-- Modules and objects
local WeldPiece       = require(RepStorage.Modules.Util.WeldPiece)

-- Vars and consts
local PARTS           = {
    Head              = {
        Damage        = 1.5, -- multiplier
        Color         = Color3.fromHSV(1, 1/2, 1)
    },
    Torso             = {
        Damage        = 1,
        Color         = Color3.fromHSV(1/6, 1/2, 1)
    },
    Arm               = {
        Damage        = 0.75,
        Color         = Color3.fromHSV(1/3, 1/2, 1)
    },
    Leg               = {
        Damage        = 0.75,
        Color         = Color3.fromHSV(1/3, 1/2, 1)
    }
}

-- Constructor
function HitboxClass.new(charclass : {}) : {}
    local Self = setmetatable({}, HitboxClass)
    Self.CharacterClass = charclass

    Self.ClassName = "HitboxClass"
    Self.Classes = {}

    Self.Hitbox = {}
    Self.Character = charclass.Character

    return Self
end

-- Starts class
function HitboxClass:Start()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- Character
    local HitboxFolder = Instance.new("Folder")
    HitboxFolder.Name = "Hitbox"
    HitboxFolder.Parent = self.Character

    for _, part in self.Character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestor("Hitbox") then
            local NewPart = part:Clone()
            NewPart:ClearAllChildren()
            NewPart.Transparency = 1
            NewPart:SetAttribute("TrackingPart", part.Name)

            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.AudioCanCollide = false

            NewPart.CanCollide = false
            NewPart.CanQuery = true
            NewPart.CanTouch = true
            NewPart.AudioCanCollide = false

            local Info = PARTS.Arm
            for tag, info in PARTS do
                if string.find(part.Name, tag) then
                    Info = info
                    NewPart.Name = tag

                    if tag == "Head" then
                        NewPart.Size = Vector3.one
                    end

                    break
                end
            end

            NewPart.Size *= 5/4

            NewPart.Color = Info.Color
            NewPart.Parent = HitboxFolder
            self.Hitbox[part.Name] = NewPart

            WeldPiece(part, NewPart)
        end
    end
end

-- Gets damage multiplier
function HitboxClass:GetMultiplier(name : string) : number
    return PARTS[name].Damage or 1
end

-- Destructor + stops class
function HitboxClass:Destroy() : ()
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

return HitboxClass