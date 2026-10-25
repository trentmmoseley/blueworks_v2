local Nodes        = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local S2           = game:GetService("ServerStorage")

local CheckpointS  = _G.Knit.GetService("CheckpointService")

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local Progress     = require(RepStorage.Modules.Util.Math.Progress)

local Puzzles      = S2.Game:WaitForChild("Puzzles")

-- Vars and consts
local MIN_NODES    = 2
local MAX_NODES    = 16
local EXTRA_NODES  = 2

local MIN_SQUAD    = 1
local MAX_SQUAD    = 16

-- [[ funcs ]] --

-- Node set-up
local function setupNode(nodespawn : Part, NodesFolder : Folder, isCheckpoint : boolean, isBlocked : boolean, isCoded : boolean)
	local Node = S2.Game.Nodes.Node:Clone()
	Node.Parent = NodesFolder
	Node:PivotTo(nodespawn.CFrame)

	for _, part in Node:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Defines role
	Node.Name = (not isCheckpoint and "Node" or "Checkpoint")..(isBlocked and "2" or "1")
	if isCheckpoint == true then
		Node.Door.Screen.BrickColor = BrickColor.new("Bright blue")
	end

	if isCoded == true then
		Node:SetAttribute("Code", CheckpointS:RegisterCode())
	end

	-- Per-node seed consumed by CheckpointService for the puzzle's input/solution
	Node:SetAttribute("PuzzleSeed", Random.new():NextInteger(1, 999999999))

	-- Puzzle
	local puzzle  = Puzzles[isCheckpoint and "_checkpoint" or "_puzzle"]:Clone()
	puzzle.Name   = "_puzzle"
	puzzle:SetAttribute("PuzzleType", isCheckpoint and "_checkpoint" or "_puzzle")
	puzzle.Parent = Node
	puzzle:PivotTo(Node:WaitForChild("PuzzlePart").CFrame)

	CheckpointS:RegisterNode(Node)
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
	local CodeCount = math.round(Lerp(1, 3, math.clamp(Progress(SquadCount, MIN_SQUAD, MAX_SQUAD), 0, 1)))

	local PuzzleNodes = 0

	-- Manages nodes; a fixed number of spawns are chosen each round
	local Spawns = map.Spawns.Structures.Nodes:GetChildren()
	local CompiledSpawns = {{}, {}} -- free kiosks, blocked-off kiosks
	for _, sp in Spawns do
		table.insert(CompiledSpawns[sp:GetAttribute("blockedOff") == true and 2 or 1], sp)
	end

	NodeCount = math.min(NodeCount, #Spawns)

	for i = 1, NodeCount do
		local isCheckpoint = i < 3
		local isBlockedOff = not isCheckpoint and (i % 2) + 1 == 2
		local isCoded = not (isBlockedOff or isCheckpoint) and PuzzleNodes < CodeCount

		if not isCheckpoint then
			PuzzleNodes += 1
		end

		local ChosenTable = CompiledSpawns[isBlockedOff and 2 or 1]
		local ChosenSpawn = ChosenTable[math.random(1, #ChosenTable)]

		setupNode(ChosenSpawn, NodesFolder, isCheckpoint, isBlockedOff, isCoded)
		table.remove(ChosenTable, table.find(ChosenTable, ChosenSpawn))
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
	NodesLeft.Value = PuzzleNodes
	NodesLeft:SetAttribute("Init", PuzzleNodes)
end

return Nodes
