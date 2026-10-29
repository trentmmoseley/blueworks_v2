-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local ButtonPress       = require(RepStorage.Remotes.ButtonPress):Server()
local CheckpointService = Knit.CreateService({
    Name = "CheckpointService",
    Client = {},
    Codes = {},
    Nodes = {},
})

local PlaySound         = require(RepStorage.Modules.Util.PlaySound)
local PluralString      = require(RepStorage.Modules.Util.PluralString)

local NodeAnn           = require(RepStorage.Remotes.NodeAnnouncement):Server()

local GameValues        = RepStorage.GameValues

-- Vars and consts
local BUTTON_TWEEN      = TweenInfo.new(1/4)
local BUTTON_STATES     = {
    On  = {Color = Color3.fromRGB(0, 255, 0), Material = Enum.Material.Neon},
    Off = {Color = Color3.fromRGB(139, 0, 0), Material = Enum.Material.Neon}
}

local PUZZLE_PROMPTS   = {
    _puzzle            = "SET ALL TO GREEN",
}

-- [[ funcs ]] --

-- Renders a button's appearance from its boolean state
local function renderButton(buttonPart : BasePart, state : boolean, animate : boolean) : ()
    local State = state and BUTTON_STATES.On or BUTTON_STATES.Off
    buttonPart.Material = State.Material

    if animate then
        TweenService:Create(buttonPart, BUTTON_TWEEN, {Color = State.Color}):Play()
    else
        buttonPart.Color = State.Color
    end
end

-- Gets the NodesLeft counter (created by MapService's Nodes module)
local function getNodesLeft() : NumberValue?
    return GameValues.Numbers:FindFirstChild("NodesLeft")
end

-- Gets input for node
function CheckpointService.Client:GetInput(node : Model) : {boolean}?
    local ID = node:GetAttribute("NodeID")
    if ID and self.Nodes[ID] then
        return self.Nodes[ID].Input
    end
end

-- Resets Codes
function CheckpointService:ResetCodes() : ()
    self.Codes = {}
end

-- Checks if code exists
function CheckpointService:CheckForCode(code : number) : boolean
    return table.find(self.Codes, code) ~= nil
end

-- Registers code for Node to store
function CheckpointService:RegisterCode() : number
    local Number = math.random(0, 999999)
    table.insert(self.Codes, Number)
    return Number
end

-- Deregisters code
function CheckpointService:DeregisterCode(id : number) : ()
    local Code = table.find(self.Codes, id)
    if Code then
        table.remove(self.Codes, table.find(self.Codes, id))
    end
end

-- Counts codes
function CheckpointService:CountCodes() : number
    return #self.Codes
end

-- Deregisters Node
function CheckpointService:DeregisterNode(id : number) : ()
    self.Nodes[id] = nil
end

-- Stops all players from interacting with node
function CheckpointService:DisableNode(node : Model) : ()
    local ID = node:GetAttribute("NodeID")
    if ID and self.Nodes[ID] then
        for _, player in Players:GetPlayers() do
            if player.Character and player.Character:GetAttribute("NodeID") == ID then
                player.Character:SetAttribute("NodeID", 0)
            end
        end
    end
end

-- Manages node
function CheckpointService:ManageNode(node : Model) : ()
    task.spawn(function()
        local Puzzle = node:FindFirstChild("_puzzle")
        repeat Puzzle = node:FindFirstChild("_puzzle") task.wait() until Puzzle or not node.Parent
        if not node.Parent then return end

        -- Seeded RNG from the puzzle seed stamped during map setup
        local Rand = Random.new(node:GetAttribute("PuzzleSeed") or 0)

        -- Tracks node via ID
        local ID = Rand:NextInteger(1, 9999999)
        node:SetAttribute("NodeID", ID)
        self.Nodes[ID] = {Model = node}

        -- On node removal
        node.AncestryChanged:Connect(function(_, parent)
            if not parent then
                self.Nodes[ID] = nil
            end
        end)

        local hasOpened = false

        -- Welds all parts parented to Hinge part of Door model
        for _, part : BasePart in node:WaitForChild("Door"):GetDescendants() do
            if part:IsA("BasePart") and part ~= node.Door.Hinge then
                part.Anchored = false
                local Weld = Instance.new("WeldConstraint")
                Weld.Part0 = node.Door.Hinge
                Weld.Part1 = part
                Weld.Parent = node.Door.Hinge
            end
        end

        node.StatusScreen.SurfaceGui.TextLabel.Text = PUZZLE_PROMPTS[Puzzle:GetAttribute("PuzzleType")]
            or (Puzzle:GetAttribute("PuzzleType") == "_checkpoint" and "ENTER CODE" or "CALIBRATE")

        -- Opens the door once
        node.ProximityPrompt.Triggered:Connect(function()
            if hasOpened then return end
            hasOpened = true
            TweenService:Create(node.Door.Hinge, TweenInfo.new(1), {CFrame = node.Door.Hinge.CFrame * CFrame.Angles(0, math.rad(-135), 0)}):Play()
            PlaySound(107243281689304, "Door", nil, node.Door.Hinge.Position, 1, math.random(0.95, 1.05))
        end)

        -- Seats the player at the node until they move
        node.ProximityPrompt.Triggered:Connect(function(player : Player)
            if player.Team ~= game.Teams.Squadmates then return end

            local Character = player.Character or player.CharacterAdded:Wait()
            local Class = self.CharService:GetCharacterClass(Character)
            if Class and Class.NodeClass then
                Class.NodeClass:SetNode(ID)

                local MmtChange = nil
                MmtChange = Character:GetAttributeChangedSignal("isMoving"):Connect(function()
                    if Character:GetAttribute("isMoving") == true then
                        Class.NodeClass:RemoveNode()
                        MmtChange:Disconnect()
                    end
                end)
            end
        end)

        -- Manages solution; nodes without a matching puzzle module stay unsolvable
        for _, mod : ModuleScript in script:GetChildren() do
            if string.find(Puzzle:GetAttribute("PuzzleType"), mod.Name) then
                local M = require(mod)
                self.Nodes[ID] = {Input = M.GenerateInput(node, Rand), Model = node, Module = M, Solution = M.GenerateSolution(node, Rand)}
            end
        end

        self:WireButtons(node, ID)
    end)
end

-- Registers Node
function CheckpointService:RegisterNode(node : Model) : ()
    self:ManageNode(node)
end

-- Wires a node's puzzle buttons to its input
function CheckpointService:WireButtons(node : Model, ID : number) : ()
    local Data    = self.Nodes[ID]
    local Buttons = node._puzzle:FindFirstChild("Buttons")
    if not (Data and Data.Input and Buttons) then return end

    -- Puzzle modules may wire their own buttons (e.g. the checkpoint keypad)
    if Data.Module and Data.Module.WireButtons then
        Data.Module.WireButtons(node, Data, ID)
        return
    end

    for _, button : Model in Buttons:GetChildren() do
        local Index      = tonumber(string.sub(button.Name, #button.Name))
        local ButtonPart = button:FindFirstChild("Button")
        if not (Index and ButtonPart) then continue end

        -- Initial appearance
        renderButton(ButtonPart, Data.Input[Index], false)

        -- Click detection
        local ClickDetector                 = Instance.new("ClickDetector")
        ClickDetector.MaxActivationDistance = 32
        ClickDetector.Parent                = ButtonPart

        ClickDetector.MouseClick:Connect(function(player : Player)
            local Character = player.Character
            if not Character or Character:GetAttribute("NodeID") ~= ID then return end

            -- Renders a button by its input index (puzzle modules call this for any button they change)
            local function Render(index : number) : ()
                local Button = Buttons:FindFirstChild("Button"..tostring(index))
                local Part   = Button and Button:FindFirstChild("Button")
                if Part then
                    renderButton(Part, Data.Input[index], true)
                end
            end

            -- Input handling is customized per puzzle module via HandleInput
            if Data.Module and Data.Module.HandleInput then
                Data.Module.HandleInput(Data, Index, Render)
            else
                Data.Input[Index] = not Data.Input[Index]
                Render(Index)
            end

            ButtonPress:FireAll(ButtonPart)

            -- Compares input to solution
            local isSolved = true
            for i, v in pairs(Data.Input) do
                if v ~= Data.Solution[i] then
                    isSolved = false
                    break
                end
            end

            if isSolved then
                node.ProximityPrompt.Enabled = false
                self:DisableNode(node)

                -- Reverses door tween
                PlaySound(127997181362733, "Beep", nil, node.Door.Hinge.Position, 1, 1)
                PlaySound(9116742681, "Door", nil, node.Door.Hinge.Position, 1, math.random(0.95, 1.05))

                -- Tweens Screen and Screen.SurfaceGui.ImageLabel to green colors like Doors
                TweenService:Create(node.Door.Screen, TweenInfo.new(1), {Color = Color3.fromRGB(18, 33, 21)}):Play()
                TweenService:Create(node.Door.Screen.SurfaceGui.ImageLabel, TweenInfo.new(1), {ImageColor3 = Color3.fromHSV(1/3, 1, 1)}):Play()
                Knit.GetService("ScoreService"):AwardScore(player.Character, 20, "Calibrated Node", true)

                -- Subtracts from Node counter
                local NodesLeft = getNodesLeft()
                if not NodesLeft then return end
                NodesLeft.Value = math.max(NodesLeft.Value - 1, 0)

                NodeAnn:FireAll()
                self.S3:GlobalSound("GlobalAnn")

                -- Displays code if applicable
                local Code = node:GetAttribute("Code")
                if Code then
                    task.defer(function()
                        while node and node:FindFirstAncestor("Workspace") do
                            node.StatusScreen.SurfaceGui.TextLabel.Text = Code
                            task.wait(3/4)
                            node.StatusScreen.SurfaceGui.TextLabel.Text = ""
                            task.wait(1/4)
                        end
                    end)
                else
                    TweenService:Create(node.Door.Hinge, TweenInfo.new(1), {CFrame = node.Door.Hinge.CFrame * CFrame.Angles(0, math.rad(135), 0)}):Play()
                end
            end
        end)
    end
end

-- On knit init completion
function CheckpointService:KnitInit() : ()
    self.S3 = _G.Knit.GetService("StraySoundService")
    self.CommsService = _G.Knit.GetService("CommsService")
    self.CharService = _G.Knit.GetService("CharService")
    self:ResetCodes()
end

return CheckpointService
