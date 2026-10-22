local Nodes        = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local S2           = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local CheckpointS  = _G.Knit.GetService("CheckpointService")

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local PlaySound    = require(RepStorage.Modules.Util.PlaySound)
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

	CheckpointS:RegisterNode(Node)

	local hasOpened = false

	-- Welds all parts parented to Hinge part of Door model
	for _, part : BasePart in Node:WaitForChild("Door"):GetDescendants() do
		if part:IsA("BasePart") and part ~= Node.Door.Hinge then
			part.Anchored = false
			local Weld = Instance.new("WeldConstraint")
			Weld.Part0 = Node.Door.Hinge
			Weld.Part1 = part
			Weld.Parent = Node.Door.Hinge
		end
	end

	Node.StatusScreen.SurfaceGui.TextLabel.Text = isCheckpoint and "ENTER CODE" or "SET ALL TO GREEN"

	Node.ProximityPrompt.Triggered:Connect(function()
		if hasOpened then return end
		hasOpened = true
		TweenService:Create(Node.Door.Hinge, TweenInfo.new(1), {CFrame = Node.Door.Hinge.CFrame * CFrame.Angles(0, math.rad(-135), 0)}):Play()
		PlaySound(107243281689304, "Door", nil, Node.Door.Hinge.Position, 1, math.random(0.95, 1.05))
	end)

	-- Puzzle
	local puzzle  = Puzzles[isCheckpoint and "_checkpoint" or "_switch"]:Clone()
	puzzle.Name   = "_puzzle"
	puzzle:SetAttribute("PuzzleType", puzzle.Name)
	puzzle.Parent = Node
	puzzle:PivotTo(Node:WaitForChild("PuzzlePart").CFrame)
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

	local CodedNodes = 0

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
		local isCoded = not (isBlockedOff or isCheckpoint) and CodedNodes < CodeCount

		if not isCheckpoint then
			CodedNodes += 1
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
	NodesLeft.Value = CodedNodes
	NodesLeft:SetAttribute("Init", CodedNodes)
end

return Nodes
