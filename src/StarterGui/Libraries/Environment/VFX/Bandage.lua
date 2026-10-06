-- Services
local Rand         = Random.new()
local TweenService = game:GetService("TweenService")

-- Vars and consts
local THICKNESS    = 1/16   -- how much thicker than the body part the bandage is
local LIFETIME     = 60 * 5 -- time before the bandage starts fading
local FADE_TIME    = 60     -- time the bandage takes to tween into invisibility

local BandageMod   = {

    ["Apply"]      = {

        ["RENDER_DISTANCE"] = 2 ^ 10,
        ["Function"]        = function(args)
            local Character    = args[1]
            local BandageColor = args[2]

            if not (Character and Character.Parent) then return end

            -- Collects the character's limbs and torso (direct BasePart children,
            -- excluding the head, root part, and anything nested in tools/accessories)
            local BodyParts = {}
            for _, part in Character:GetChildren() do
                if part:IsA("BasePart") and part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
                    table.insert(BodyParts, part)
                end
            end
            if #BodyParts == 0 then return end

            local ChosenPart = BodyParts[Rand:NextInteger(1, #BodyParts)]
            local Height = Rand:NextNumber(1/8, 1/2)

            -- Creates the bandage: slightly thicker than the chosen body part
            local Bandage = Instance.new("Part")
            Bandage.Name = "Bandage"
            Bandage.Color = BandageColor
            Bandage.Material = Enum.Material.Fabric
            Bandage.Size = Vector3.new(ChosenPart.Size.X + THICKNESS, Height, ChosenPart.Size.Z + THICKNESS)
            Bandage.CanCollide = false
            Bandage.CanQuery = false
            Bandage.CanTouch = false
            Bandage.Massless = true
            Bandage.CastShadow = false

            -- Wraps the bandage around a random point along the body part
            local MaxOffset = math.max((ChosenPart.Size.Y - Height) / 2, 0)
            Bandage.CFrame = ChosenPart.CFrame * CFrame.new(0, Rand:NextNumber(-MaxOffset, MaxOffset), 0)
            Bandage.Parent = Character

            local Weld = Instance.new("WeldConstraint")
            Weld.Part0 = Bandage
            Weld.Part1 = ChosenPart
            Weld.Parent = Bandage

            -- After five minutes, fades into invisibility over one minute, then unloads
            task.delay(LIFETIME, function()
                if not Bandage.Parent then return end

                local Fade = TweenService:Create(Bandage, TweenInfo.new(FADE_TIME), {Transparency = 1})
                Fade:Play()
                Fade.Completed:Wait()
                Bandage:Destroy()
            end)
        end,

    },

}

return BandageMod
