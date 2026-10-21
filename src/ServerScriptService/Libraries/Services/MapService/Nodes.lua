local Nodes        = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local S2           = game:GetService("ServerStorage")

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local Progress     = require(RepStorage.Modules.Util.Math.Progress)

-- Vars and consts
local MIN_NODES    = 2
local MAX_NODES    = 16
local EXTRA_NODES  = 2

local MIN_SQUAD    = 1
local MAX_SQUAD    = 16

-- [[ funcs ]] --

-- Node set-up
local function setupNode(nodespawn : Part, NodesFolder : Folder)
	local Node = S2.Game.Nodes.Node:Clone()
	Node.Parent = NodesFolder
	Node:PivotTo(nodespawn.CFrame)

	for _, part in Node:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

-- Main function
function Nodes.Init(map)
	local NodesFolder = map.Interactables:FindFirstChild("Nodes")
	if not NodesFolder then
		NodesFolder = Instance.new("Folder")
		NodesFolder.Name = "Nodes"
		NodesFolder.Parent = map.Interactables
	end

	-- Node count scales with squad size
	local SquadCount = #game.Teams.Squadmates:GetPlayers()
	local NodeCount = math.ceil(Lerp(MIN_NODES, MAX_NODES, math.clamp(Progress(SquadCount, MIN_SQUAD, MAX_SQUAD), 0, 1))) + EXTRA_NODES

	-- Manages nodes; a fixed number of spawns are chosen each round
	local Spawns = map.Spawns.Structures.Nodes:GetChildren()
	NodeCount = math.min(NodeCount, #Spawns)

	for i = 1, NodeCount do
		local ChosenSpawn = Spawns[math.random(1, #Spawns)]
		setupNode(ChosenSpawn, NodesFolder)
		table.remove(Spawns, table.find(Spawns, ChosenSpawn))
		ChosenSpawn:Destroy()
	end

	-- Clears leftover spawn points
	for _, spawn in Spawns do
		spawn:Destroy()
	end

	-- Tracks nodes for round progress
	local NodesLeft = RepStorage.GameValues.Numbers:FindFirstChild("NodesLeft")
	if not NodesLeft then
		NodesLeft = Instance.new("NumberValue")
		NodesLeft.Name = "NodesLeft"
		NodesLeft.Parent = RepStorage.GameValues.Numbers
	end
	NodesLeft.Value = NodeCount
	NodesLeft:SetAttribute("Init", NodeCount)
end

return Nodes
