local ProxPromptGui        = {}

-- Services
local Players        = game:GetService("Players")
local P2Service      = game:GetService("ProximityPromptService")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Frame          = TheGui:WaitForChild("Frame")

local Lerp           = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress       = require(RepStorage.Modules.Util.Math.Progress)
local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)
local InvRep         = require(RepStorage.Modules.Util.InvRep)
local TierRep        = require(RepStorage.Modules.Data.Tiers)

local HoldBar        = Frame:WaitForChild("HoldBar")
local Keybind        = Frame:WaitForChild("Keybind")
local ObjectText     = Frame:WaitForChild("ObjectText")
local ActionText     = Frame:WaitForChild("ActionText")

local Timer          = HoldBar:WaitForChild("Timer")
local Amount         = HoldBar:WaitForChild("Amount")

local PBTemp         = RepStorage.PlayerRep.ProxBeam

local Beam           : Beam?
local ProxBeam       : Folder?
local Highlight      : Highlight?
local CurrentPrompt  : ProximityPrompt? = nil

local ItemDisplays   = RepStorage:WaitForChild("ItemDisplays")

-- Vars and consts
local isHolding      = false

local BeamTP         = 1
local HoldStart      = 0
local HoldEnd        = math.huge

local DEFAULT_COLOR  = Color3.fromHSV(2/3, 0.5, 1)
local ProxColor      = DEFAULT_COLOR

-- [[ funcs ]] --

local function toggleVis()
    local promptVis = CurrentPrompt ~= nil
    local TI = TweenInfo.new(1/4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    for _, part : Frame | TextLabel | UIStroke in Frame:GetDescendants() do
        local partOfTimer = part.Name == Timer.Name or part.Name == HoldBar.Name or part:FindFirstAncestor(HoldBar.Name)
        local doVis = promptVis and (not partOfTimer or isHolding)

        if part:IsA("Frame") and table.find({"Amount", "Underline"}, part.Name) then
            TweenService:Create(part, TI, {BackgroundTransparency = doVis and 0 or 1}):Play()
        elseif part:IsA("TextLabel") or (part:IsA("TextButton") and part.Parent ~= Frame) then
            TweenService:Create(part, TI, {TextTransparency = doVis and 0 or 1, TextStrokeTransparency = doVis and 1/2 or 1}):Play()
        elseif part:IsA("UIStroke") then
            TweenService:Create(part, TI, {Transparency = doVis and 0 or 1}):Play()
        end
    end

    if promptVis and CurrentPrompt.Parent and Highlight.Parent then
        Highlight.Parent = CurrentPrompt.Parent
    end

    -- Keybind
    local TI2 = TweenInfo.new(isHolding and 1/4 or 1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    TweenService:Create(Keybind, TI2, {Position = UDim2.fromScale(isHolding and 0.5 or 0.44, 0.679), BackgroundTransparency = isHolding and 0 or 1}):Play()
    TweenService:Create(Keybind.TextButton, TI2, {TextColor3 = Color3.fromHSV(1, 0, isHolding and 0 or 1)}):Play()
    TweenService:Create(ActionText, TI, {TextTransparency = (isHolding or not CurrentPrompt) and 1 or 0, TextStrokeTransparency = (isHolding or not CurrentPrompt) and 1 or 1/2}):Play()
    TweenService:Create(ObjectText, TI, {TextTransparency = (isHolding or not CurrentPrompt) and 1 or 0, TextStrokeTransparency = (isHolding or not CurrentPrompt) and 1 or 1/2}):Play()
end

-- Determines if can hold
local function canHold() : string | boolean
    if ItemDisplays:FindFirstChild(CurrentPrompt and CurrentPrompt.Parent.Name or "") then
        return InvRep:CanPickUp(CurrentPrompt.Parent.Name, _G.ClientInv.Items, _G.ClientInv.MaxSlots)
    end

    return true
end

-- Main function
function ProxPromptGui.Function()
    local function updateEnabled()
        TheGui.Enabled = Player.Team ~= game.Teams.Squadmates
    end

    updateEnabled()
    Character:GetAttributeChangedSignal("CheckpointID"):Connect(updateEnabled)
    Player:GetAttributeChangedSignal("powerOut"):Connect(updateEnabled)

    -- Clears old prox. beam
    ProxBeam = game.Workspace:FindFirstChild(PBTemp.Name) or RepStorage:FindFirstChild(PBTemp.Name)
    if ProxBeam then
        ProxBeam:Destroy()
    end

    if TheGui.Enabled then
        ProxBeam = PBTemp:Clone()
        ProxBeam.Parent = game.Workspace
        Highlight = ProxBeam.Highlight
        Beam = ProxBeam.Beam

        toggleVis()
    end

    -- On prompt reveal
    P2Service.PromptShown:Connect(function(prompt)
        CurrentPrompt = prompt
        isHolding = false

        toggleVis()
    end)

    -- On prompt hide
    P2Service.PromptHidden:Connect(function()
        CurrentPrompt = nil
        isHolding = false
        toggleVis()
    end)

    -- On prompt hold
    P2Service.PromptButtonHoldBegan:Connect(function(prompt)
        if canHold() == true then
            HoldStart = os.clock()
            HoldEnd = os.clock() + prompt.HoldDuration
            isHolding = true
            toggleVis()
        end
    end)

    P2Service.PromptButtonHoldEnded:Connect(function(prompt)
        isHolding = false
        toggleVis()
    end)

    Frame.TextButton.MouseButton1Click:Connect(function()
        if CurrentPrompt then
            if not isHolding then
                isHolding = true
                CurrentPrompt:InputHoldBegin()
            else
                isHolding = false
                CurrentPrompt:InputHoldEnd()
            end
        end
    end)

    -- Run service
    local RunConn : RBXScriptConnection = RunService.PreRender:Connect(function(dt)
        local QuarterLerp = LerpByFrame(1/4, dt)
        local canUse = canHold() == true

        if not (ProxBeam and Character and Character.Parent) then return end
        ProxBeam.Part0.CFrame = Character.PrimaryPart.CFrame

         -- Positions prox. beam
        if CurrentPrompt then
            ProxBeam.Part1.CFrame = ProxBeam.Part1.CFrame:Lerp(CurrentPrompt.Parent:IsA("Model") and CurrentPrompt.Parent.PrimaryPart.CFrame or CurrentPrompt.Parent.CFrame, QuarterLerp)

            if not Highlight.Parent then
                Highlight = Highlight:Clone()
                Highlight.Parent = CurrentPrompt.Parent or RepStorage
            end

            ObjectText.Text = canUse and string.upper(CurrentPrompt.ObjectText) or ""
            ActionText.Text = canUse and string.upper(CurrentPrompt.ActionText) or string.upper(canHold())
            ActionText.TextColor3 = Color3.fromHSV(1, canUse and 0 or 1, 1)
            
            Keybind.UIStroke.Color = Color3.fromHSV(canUse and 2/3 or 1, 1, 1)
            Keybind.TextButton.Text = canUse and "F" or ""
        end

        -- Changes to tier color if tool
        if CurrentPrompt then
            if canUse then
                if ItemDisplays:FindFirstChild(CurrentPrompt.Parent.Name) then
                    local Tier = CurrentPrompt.Parent:GetAttribute("Tier") or 0
                    ProxColor = TierRep.Tiers[Tier + 1].Color:Lerp(Color3.fromHSV(1, 0, 1), TrigWave("sin", 1/2, 1, os.clock(), 0, 1/2))
                else
                    ProxColor = DEFAULT_COLOR
                end
            else
                ProxColor = Color3.fromRGB(105, 105, 105):Lerp(Color3.fromRGB(134, 46, 46), TrigWave("sin", 1/2, 1/12, os.clock(), 0, 1/2))
            end
        end

        Keybind.BackgroundColor3 = ProxColor
        Keybind.UIStroke.Color = ProxColor
        Frame.Underline.BackgroundColor3 = ProxColor

        Highlight.OutlineTransparency = Lerp(Highlight.OutlineTransparency, CurrentPrompt and 0 or 1, QuarterLerp)
        Highlight.OutlineColor = Highlight.OutlineColor:Lerp(ProxColor, QuarterLerp)

        BeamTP = Lerp(BeamTP, CurrentPrompt and 0 or 1, QuarterLerp)
        Beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, ProxColor), ColorSequenceKeypoint.new(1, ProxColor)})
        Beam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1/2, BeamTP), NumberSequenceKeypoint.new(1, 1)})

        -- Hold prog
        if isHolding then
            local HoldProg = math.min(Progress(os.clock(), HoldStart, HoldEnd), 1)
            local TimeLeft = math.max(HoldEnd - os.clock(), 0)
            Amount.Size = UDim2.fromScale(HoldProg, 1)
            Timer.Text = string.format("%.2i:%.2i", math.floor(TimeLeft), math.floor((TimeLeft % 1) * 60))

            local ProgColor = Color3.fromRGB(35, 26, 102):Lerp(Color3.fromRGB(255, 0, 85), HoldProg ^ 2)
            for _, part in HoldBar:GetDescendants() do
                if part:IsA("UIStroke") then
                    part.Color = ProgColor
                elseif part:IsA("Frame") then
                    part.BackgroundColor3 = ProgColor
                end
            end
        end
    end)

    -- Unloads everything if player dies
    Player.Changed:Connect(function()
        if Player.Team == game.Teams.Squadmates then
            RunConn:Disconnect()
            if ProxBeam then
                ProxBeam:Destroy()
            end
        end
    end)
end

return ProxPromptGui