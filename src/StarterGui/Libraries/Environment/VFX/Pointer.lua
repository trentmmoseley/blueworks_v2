-- Services
local Debris        = game:GetService("Debris")
local Players       = game:GetService("Players")
local RepStorage    = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")

-- Player
local Player        = Players.LocalPlayer

-- Modules and objects
local PointerBeam   = RepStorage.VFX.Pointer.PointerBeam
local WeldPiece     = require(RepStorage.Modules.Util.WeldPiece)

-- [[ funcs ]] --

-- Beam.Transparency is a NumberSequence and cannot be tweened directly,
-- so tween a proxy value and rebuild the sequence from it on each change
local function fadeBeam(beam : Beam, startFade : number, endFade : number, duration : number)
    -- Shape at maximum opacity: invisible at the ends, half transparent in the middle
    local Keypoints = {
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    }

    local function setFade(fade : number)
        local NewKeypoints = table.create(#Keypoints)
        for i, keypoint in Keypoints do
            NewKeypoints[i] = NumberSequenceKeypoint.new(keypoint.Time, 1 - (1 - keypoint.Value) * fade)
        end
        beam.Transparency = NumberSequence.new(NewKeypoints)
    end

    local Proxy = Instance.new("NumberValue")
    Proxy.Value = startFade
    setFade(startFade)

    local Connection = Proxy.Changed:Connect(setFade)
    local Tween = TweenService:Create(Proxy, TweenInfo.new(duration), {Value = endFade})
    Tween.Completed:Connect(function()
        Connection:Disconnect()
        Proxy:Destroy()
    end)
    Tween:Play()
end

local Pointer       = {

    ["Pointer"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Target : Model | Part = args[1]
            local TargetPart = Target:IsA("Model") and (Target.PrimaryPart or Target:FindFirstChildOfClass("BasePart")) or Target

            local Color = args[2]
            local Length = args[3]

            local Character = Player.Character
            if not Character then return end

            local NewPointer = PointerBeam:Clone()
            NewPointer.Parent = game.Workspace
            NewPointer.Part0.CFrame = Character.PrimaryPart.CFrame
            NewPointer.Part1.CFrame = TargetPart.CFrame
            WeldPiece(NewPointer.Part0, Character.PrimaryPart)
            WeldPiece(NewPointer.Part1, TargetPart)

            local Beam = NewPointer:WaitForChild("Beam")
            Beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color), ColorSequenceKeypoint.new(1, Color)})

            local Highlight = NewPointer:WaitForChild("Highlight")
            Highlight.Adornee = Target
            local FillTransparency = Highlight.FillTransparency
            local OutlineTransparency = Highlight.OutlineTransparency
            Highlight.FillTransparency = 1
            Highlight.OutlineTransparency = 1
            Highlight.OutlineColor = Color

            local FadeInInfo = TweenInfo.new(1/2)
            fadeBeam(Beam, 0, 1, 1/2)
            TweenService:Create(Highlight, FadeInInfo, {FillTransparency = FillTransparency, OutlineTransparency = OutlineTransparency}):Play()

            task.wait(Length)

            fadeBeam(Beam, 1, 0, 5)
            TweenService:Create(Highlight, TweenInfo.new(5), {FillTransparency = 1, OutlineTransparency = 1}):Play()
            Debris:AddItem(NewPointer, 5)
        end,

    },

}

return Pointer