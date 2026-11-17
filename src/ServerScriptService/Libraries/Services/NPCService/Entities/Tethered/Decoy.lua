local Decoy     	  = {}

-- Services
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local Workspace       = game:GetService("Workspace")

local CombatService   = _G.Knit.GetService("CombatService")
local EffectService   = _G.Knit.GetService("EffectService")
local NPCService      = _G.Knit.GetService("NPCService")

-- Vars and consts
Decoy.MIN_PROGRESS    = 1/2
local Characters      = Workspace:WaitForChild("Characters")
local Rand            = Random.new()

-- [[ funcs ]] --

-- Main function
function Decoy.Function(rig : Model)
    EffectService:Add(rig, "Invisibility", 6, 3)
    local NewDecoy = NPCService:CreateNPC("Decoy", rig.PrimaryPart.CFrame)
end

return Decoy