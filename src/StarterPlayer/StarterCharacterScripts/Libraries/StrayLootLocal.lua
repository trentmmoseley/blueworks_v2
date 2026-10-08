local SL2          = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")

local SLService    = _G.Knit.GetService("StrayLootService")

-- Modules and objects
local ItemDisplays = RepStorage:WaitForChild("ItemDisplays")
local StrayLoot    = RepStorage:WaitForChild("StrayLoot")

local GunAttach    = require(RepStorage.Modules.Util.GunAttach)

local DisplayList  = {}

local SLWorkspace  = Instance.new("Folder")
SLWorkspace.Name   = "StrayLoot"
SLWorkspace.Parent = game.Workspace

local TrigWave     = require(RepStorage.Modules.Util.Math.TrigWave)
local TierRep      = require(RepStorage.Modules.Data.Tiers)

-- [[ funcs ]] --

-- Manages loot
local function manageLoot(loot : Vector3Value) : ()
    if not loot:IsA("Vector3Value") then return end
    local NewDisplay = ItemDisplays:FindFirstChild(loot:GetAttribute("Name")):Clone()
    DisplayList[loot] = NewDisplay
    NewDisplay:PivotTo(CFrame.new(loot.Value))
    NewDisplay.Parent = SLWorkspace

    -- Attachments for gun
    local Atts = {}
    for att, val in loot:GetAttributes() do
        if string.sub(att, 1, 1) == "_" then
            Atts[att] = val
        end
    end

    if #Atts > 0 then
        GunAttach(NewDisplay, Atts)
    end

    for _, part in NewDisplay:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
        end
    end

    NewDisplay:SetAttribute("Velocity", 0)

    -- Prox. prompt
    local Prox : ProximityPrompt = Instance.new("ProximityPrompt")
    Prox.ObjectText = loot:GetAttribute("Name")
    Prox.ActionText = "Collect"
    Prox.KeyboardKeyCode = Enum.KeyCode.F
    Prox.HoldDuration = 1/2
    Prox.MaxActivationDistance = 7.5
    Prox.Style = Enum.ProximityPromptStyle.Custom
    Prox.Parent = NewDisplay

    Prox.Triggered:Connect(function(player)
        SLService.CollectLoot:Fire(loot)
    end)

    -- On loot destroy
    loot.Destroying:Connect(function()
        if DisplayList[loot] then
            DisplayList[loot]:Destroy()
            DisplayList[loot] = nil
        end
    end)
end

-- Main function
function SL2.Function()
    for _, loot in StrayLoot:GetChildren() do
        manageLoot(loot)
    end

    StrayLoot.ChildAdded:Connect(manageLoot)

    -- Manages positions
    RunService.PreRender:Connect(function(dt)
        for loot, display in DisplayList do
            local Velocity = display:GetAttribute("Velocity") or 0
            Velocity += game.Workspace.Gravity * dt

            local DesiredPos = loot.Value + Vector3.new(0, -Velocity * dt, 0)
            loot.Value = Vector3.new(loot.Value.X, math.max(DesiredPos.Y, loot:GetAttribute("GroundPosition").Y + 1), loot.Value.Z)
            display:PivotTo(CFrame.new(loot.Value) * CFrame.Angles(0, math.rad(45 * os.clock() % 360), math.rad(display:GetAttribute("DisplayTilt"))))

            -- Hovering effect if on ground
            if loot.Value.Y <= loot:GetAttribute("GroundPosition").Y + 1 then
                display:PivotTo(display.PrimaryPart.CFrame * CFrame.new(0, TrigWave("sin", 1/4, 5, os.clock() + loot.Value.X, loot.Value.Z, 0), 0))
            end

            display:SetAttribute("Velocity", Velocity)
        end
    end)
end

return SL2