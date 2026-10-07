-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local EntityBehavior  = script.Entities

local NPCService      = Knit.CreateService({
    Name = "NPCService",

    -- Objects
    NPCs = {},

    -- Signals
    NPCSpawned = _G.Signal.new(),
    
    -- Client exposure
    Client = {
        NPCSpawned = Knit.CreateSignal()
    },
})

local Rigs           = RepStorage.Rigs

-- [[ funcs ]] --

-- Creates NPC
function NPCService:CreateNPC(name : string, cf : CFrame) : Model
    local Rig = Rigs[name].Skins._default._rig:Clone()
    Rig.Name = name
    Rig:SetPrimaryPartCFrame(cf)

    -- Creates new animator in humanoid
    local Humanoid = Rig:FindFirstChildWhichIsA("Humanoid")
    local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
    if Animator then
        Animator:Destroy()
    end
    Animator = Instance.new("Animator")
    Animator.Parent = Humanoid

    Rig.Parent = game.Workspace:WaitForChild("Characters")

    self.NPCs[Rig] = true
    Rig.Destroying:Connect(function()
        self.NPCs[Rig] = nil
    end)

    -- Establishes behavior
    local Module = EntityBehavior:FindFirstChild(name)
    if Module then
        require(Module)(Rig)
    end

    return Rig
end

-- On Knit ready
function NPCService:KnitInit() : ()
    local CharFolder      = game.Workspace:WaitForChild("Characters")

    -- On NPC spawn
    CharFolder.ChildAdded:Connect(function(char : Model)
        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            self.NPCSpawned:Fire(char)
            self.Client.NPCSpawned:FireAll(char)
        end
    end)
end

return NPCService