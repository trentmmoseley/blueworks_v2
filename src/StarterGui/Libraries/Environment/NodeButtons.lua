local NodeButtons        = {}

-- Services
local Players            = game:GetService("Players")
local Rand               = Random.new()
local RepStorage         = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")

-- Player stuff
local Player             = Players.LocalPlayer
local Character          = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local ButtonPress        = require(RepStorage.Remotes.ButtonPress):Client()
local PlaySound          = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local PRESS_DEPTH        = 1/16
local PRESS_TIME         = 1/10
local ACTIVATION_DIST    = 32
local RestCFrames        = {}
local Detectors          = {}

-- [[ funcs ]] --

-- Finds the node an instance belongs to via its NodeID attribute
local function getNodeFrom(inst : Instance) : Model?
	local Current = inst.Parent
	while Current and Current ~= game.Workspace do
		if Current:IsA("Model") and Current:GetAttribute("NodeID") ~= nil then
			return Current
		end
		Current = Current.Parent
	end
end

-- Hides a node's click detector unless the character rests at that node
local function refreshDetector(detector : ClickDetector) : ()
    local Node    = getNodeFrom(detector)
    local Visible = Node ~= nil
        and Character
        and Node:GetAttribute("NodeID") == Character:GetAttribute("NodeID")

    detector.MaxActivationDistance = Visible and ACTIVATION_DIST or 0
end

-- Tracks a node button's click detector
local function trackDetector(detector : ClickDetector) : ()
    if Detectors[detector] then return end
    Detectors[detector] = true

    local Node = getNodeFrom(detector)
    if Node then
        Node:GetAttributeChangedSignal("NodeID"):Connect(function()
            refreshDetector(detector)
        end)
    end

    detector.Destroying:Connect(function()
        Detectors[detector] = nil
    end)

    refreshDetector(detector)
end

-- Refreshes all tracked detectors
local function refreshDetectors() : ()
    for detector in Detectors do
        refreshDetector(detector)
    end
end

-- Main function
function NodeButtons.Function()
    local Playspace = game.Workspace:WaitForChild("Playspace")

    -- Tracks existing and future node click detectors
    for _, inst in Playspace:GetDescendants() do
        if inst:IsA("ClickDetector") and getNodeFrom(inst) then
            trackDetector(inst)
        end
    end

    Playspace.DescendantAdded:Connect(function(inst : Instance)
        task.defer(function()
            if inst:IsA("ClickDetector") and getNodeFrom(inst) then
                trackDetector(inst)
            end
        end)
    end)

    -- Rebinds character on respawn
    local function bindCharacter(char : Model)
        Character = char
        char:GetAttributeChangedSignal("NodeID"):Connect(refreshDetectors)
        refreshDetectors()
    end

    bindCharacter(Character)
    Player.CharacterAdded:Connect(bindCharacter)

    -- Press animation for node puzzle buttons
    ButtonPress:On(function(ButtonPart : BasePart)
        if not (ButtonPart and ButtonPart.Parent) then return end

        -- Caches resting CFrame
        if not RestCFrames[ButtonPart] then
            RestCFrames[ButtonPart] = ButtonPart.CFrame
            ButtonPart.Destroying:Connect(function()
                RestCFrames[ButtonPart] = nil
            end)
        end

        local RestCFrame = RestCFrames[ButtonPart]
        PlaySound(136512283509258, "Button", nil, ButtonPart.Position, 1, Rand:NextNumber(0.95, 1.05))
        TweenService:Create(ButtonPart, TweenInfo.new(PRESS_TIME), {CFrame = RestCFrame * CFrame.new(0, 0, -PRESS_DEPTH)}):Play()
        task.wait(PRESS_TIME)
        TweenService:Create(ButtonPart, TweenInfo.new(PRESS_TIME), {CFrame = RestCFrame}):Play()
    end)
end

return NodeButtons
