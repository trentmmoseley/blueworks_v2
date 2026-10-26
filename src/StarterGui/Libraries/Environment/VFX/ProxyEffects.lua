-- Services
local RepStorage      = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

-- Modules and objects
local StageObjs       = RepStorage.Rigs.Proxy.Skins._default.StageObjs
local NodesLeft       = RepStorage.GameValues.Numbers.NodesLeft

local WeldPiece       = require(RepStorage.Modules.Util.WeldPiece)

-- Vars and consts
local GROW_DELAY      = 1/2 -- seconds before a new appendage starts growing
local GROW_TIME       = 10  -- seconds a new appendage takes to reach full size

-- Appendages the Proxy grows as more Nodes are calibrated
local APPENDAGES      = {
    {Progress = 1/4, Name = "Tail",        Part = "Torso"},
    {Progress = 2/4, Name = "Wings",       Part = "Torso"},
    {Progress = 3/4, Name = "TendrilHead", Part = "Head"},
}

-- [[ funcs ]] --

-- Calculates Node progress (mirrors RoundService:NodeProgress)
local function nodeProgress() : number
    return 1 - NodesLeft.Value / math.max(NodesLeft:GetAttribute("Init"), 1)
end

-- Clones an appendage onto the rig and tweens it from nothing to full size
local function growAppendage(rig : Model, info)
    if rig:FindFirstChild(info.Name) then
        return
    end

    local AttachPart = rig:FindFirstChild(info.Part)
    local Template   = StageObjs:FindFirstChild(info.Name)
    if not AttachPart or not Template then
        return
    end

    local Appendage = Template:Clone()
    Appendage.Parent = rig
    Appendage:PivotTo(AttachPart.CFrame)

    local Root = nil
    for _, part in Appendage:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch   = false
            part.Massless   = true

            if part.Name == "RootPart" then
                Root = part
            else
                task.spawn(function()
                    local FullSize = part.Size
                    part.Size = Vector3.zero
                    task.wait(GROW_DELAY)
                    if part.Parent then
                        TweenService:Create(part, TweenInfo.new(GROW_TIME), {Size = FullSize}):Play()
                    end
                end)
            end
        end
    end

    if Root then
        WeldPiece(Root, AttachPart)
    end
end

local ProxyEffects   = {

    -- Grows every appendage the current Node progress entitles the Proxy to;
    -- idempotent, so it can be replayed for players who join mid-round
    ["Grow"]          = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Rig      = args[1]
            local Progress = nodeProgress()

            for _, info in APPENDAGES do
                if Progress >= info.Progress then
                    growAppendage(Rig, info)
                end
            end
        end,

    },

}

return ProxyEffects
