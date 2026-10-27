local CheckpointKeypad = {}

-- Services
local RepStorage       = game:GetService("ReplicatedStorage")

local CheckpointS      = _G.Knit.GetService("CheckpointService")
local CommsService     = _G.Knit.GetService("CommsService")

-- Modules and objects
local ButtonPress      = require(RepStorage.Remotes.ButtonPress):Server()
local GameValues       = RepStorage.GameValues

-- Vars and consts
local MAX_DIGITS       = 6

local COUNTDOWN_BLURBS = {
    [45] = "All Checkpoint Codes have been entered. Remainder of map unlocks in %i seconds",
    [30] = "Remainder of map unlocks in %i seconds",
    [15] = "%i seconds",
    [10] = "%i seconds",
    [5]  = "%i",
    [4]  = "%i",
    [3]  = "%i",
    [2]  = "%i",
    [1]  = "%i",
}

-- [[ funcs ]] --

-- Renders the typed code onto the node's status screen
local function renderCode(node : Model, input : string) : ()
    node.StatusScreen.SurfaceGui.TextLabel.Text = #input > 0 and input or "ENTER CODE"
end

-- Input starts as an empty code
function CheckpointKeypad.GenerateInput(node : Model, rand : Random) : string
    return ""
end

-- Solution is the node's generated code; validation comes with ButtonEnter
function CheckpointKeypad.GenerateSolution(node : Model, rand : Random) : number?
    return node:GetAttribute("Code")
end

-- Wires the keypad's digit and backspace buttons; ButtonEnter stays unwired for now
function CheckpointKeypad.WireButtons(node : Model, data : {Input : string}, ID : number) : ()
    local Buttons = node._puzzle:FindFirstChild("Buttons")
    if not Buttons then return end

    for _, button : Model in Buttons:GetChildren() do
        local Key        = string.sub(button.Name, #"Button" + 1)
        local ButtonPart = button:FindFirstChild("Button")
        if not ButtonPart then continue end

        local isDigit = tonumber(Key) ~= nil
        local acceptInput = true

        -- Click detection
        local ClickDetector                 = Instance.new("ClickDetector")
        ClickDetector.MaxActivationDistance = 32
        ClickDetector.Parent                = ButtonPart

        ClickDetector.MouseClick:Connect(function(player : Player)
            if not acceptInput then return end

            local Character = player.Character
            if not Character or Character:GetAttribute("NodeID") ~= ID then return end

            if isDigit then
                if #data.Input < MAX_DIGITS then
                    data.Input ..= Key
                end
            else
                if Key == "Backspace" then
                    data.Input = string.sub(data.Input, 1, -2)
                elseif Key == "Enter" then
                    acceptInput = false
                    local Input = tonumber(data.Input)
                    local codeValid = CheckpointS:CheckForCode(Input)
                    node._puzzle.Base[codeValid and "Accept" or "Reject"]:Play()

                    node.StatusScreen.SurfaceGui.TextLabel.TextColor3 = Color3.fromHSV(1 / (codeValid and 3 or 1), 1, 1)

                    -- Deregisters code if valid
                    if codeValid then
                        task.defer(function()
                            CheckpointS:DeregisterCode(Input)
                        
                            -- Unlocks map if all codes entered
                            local CodesLeft = CheckpointS:CountCodes()
                            if CodesLeft == 0 then
                                local openMap = true

                                if GameValues.Numbers.TimeLeft.Value > 45 then
                                    _G.Knit.GetService("StraySoundService"):GlobalSound("GlobalAnn")
                                    for i = 45, 1, -1 do
                                        if COUNTDOWN_BLURBS[i] then
                                            CommsService:GlobalSubtitle(string.format(COUNTDOWN_BLURBS[i], i), Color3.fromRGB(0, 255, 0), true)
                                        end

                                        if not GameValues.Bools.inGame.Value then
                                            openMap = false
                                        end

                                        if not openMap then
                                            break
                                        end

                                        task.wait(1)
                                    end
                                end

                                if openMap then
                                    CommsService:GlobalSubtitle("Remainder of map unlocked", Color3.fromRGB(0, 255, 0), true)
                                    _G.Knit.GetService("StraySoundService"):GlobalSound("GlobalAnn")
                                    _G.Knit.GetService("StraySoundService"):GlobalSound("MapUnlocked")
                                    GameValues.Bools.mapUnlocked.Value = true
                                end
                            else
                                CommsService:GlobalSubtitle("%i code%s remain%s", CodesLeft, CodesLeft > 1 and "s" or "", CodesLeft > 1 and "" or "s", Color3.fromRGB(100, 255, 100), true)
                            end
                        end)
                    end

                    for i = 1, 3 do
                        node.StatusScreen.SurfaceGui.TextLabel.Text = codeValid and "ACCEPTED" or "REJECTED"
                        task.wait(1/10)
                        node.StatusScreen.SurfaceGui.TextLabel.Text = ""
                        task.wait(1/10)
                    end

                    node.StatusScreen.SurfaceGui.TextLabel.TextColor3 = Color3.fromHSV(1, 0, 1)
                    data.Input = ""
                    acceptInput = true
                end
            end

            renderCode(node, data.Input)
            ButtonPress:FireAll(ButtonPart)
        end)
    end
end

return CheckpointKeypad
