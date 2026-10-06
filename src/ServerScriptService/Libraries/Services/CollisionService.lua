-- Services
local PhysicsService   = game:GetService("PhysicsService")
local RepStorage       = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)
local CollisionService = Knit.CreateService({
    Name = "CollisionService",
    Client = {}
})

-- Vars and consts
local CHAR_GROUP       = "Characters"
local TOOL_GROUP       = "Tools"

-- [[ funcs ]] --

-- Assigns a part to the right group: parts inside a Tool go to the Tools
-- group and are made Massless and non-colliding so they can't push the
-- character around, everything else goes to the Characters group
local function assignPart(part : BasePart)
    if part:FindFirstAncestorOfClass("Tool") then
        part.CollisionGroup = TOOL_GROUP
        part.CanCollide = false
        part.Massless = true
    else
        part.CollisionGroup = CHAR_GROUP
    end
end

-- Assigns collision groups to all current and future parts of a character
-- (future parts cover equipped Tools and anything else added at runtime)
local function watchCharacter(char : Model)
    for _, d in char:GetDescendants() do
        if d:IsA("BasePart") then
            assignPart(d)
        end
    end

    char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then
            assignPart(d)
        end
    end)
end

-- Prepares all of a Tool's parts before it is parented into a character.
-- DescendantAdded fires deferred, so without this a physics step could see
-- the parts in a colliding, massive state for a frame
function CollisionService:PrepareTool(tool : Tool) : ()
    for _, d in tool:GetDescendants() do
        if d:IsA("BasePart") then
            assignPart(d)
        end
    end
end

-- On knit init completion
function CollisionService:KnitInit() : ()
    -- RegisterCollisionGroup errors if the group is already registered
    pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, CHAR_GROUP)
    pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, TOOL_GROUP)

    -- Held tools must never physically push characters around
    PhysicsService:CollisionGroupSetCollidable(TOOL_GROUP, CHAR_GROUP, false)
end

-- On game start
function CollisionService:KnitStart() : ()
    -- Created by CharacterService during Knit.Init, so wait for it here
    local CharFolder = game.Workspace:WaitForChild("Characters")

    for _, char in CharFolder:GetChildren() do
        watchCharacter(char)
    end

    CharFolder.ChildAdded:Connect(watchCharacter)
end

return CollisionService
