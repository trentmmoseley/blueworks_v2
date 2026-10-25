local NodeClass   = {}
NodeClass.__index = NodeClass

-- Constructor
function NodeClass.new(charclass : {}) : {}
    local Self = setmetatable({}, NodeClass)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character

    Self.ClassName = "NodeClass"

    return Self
end

-- Starts class
function NodeClass:Start() : ()
    self.Rig:SetAttribute("NodeID", 0)
end

-- Sets node ID
function NodeClass:SetNode(id : number) : ()
    self.Rig:SetAttribute("NodeID", id)
end

-- Removes node ID
function NodeClass:RemoveNode() : ()
    self.Rig:SetAttribute("NodeID", 0)
end

-- Destructor
function NodeClass:Destroy() : ()
    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return NodeClass
