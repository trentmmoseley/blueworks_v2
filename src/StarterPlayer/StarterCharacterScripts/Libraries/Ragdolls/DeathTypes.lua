-- Services
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local DataController = _G.Knit.GetController("DataController")

-- Modules and objects
local BloodParts     = RepStorage.VFX.Blood

-- Vars and consts
local INIT_IDs   = {
    82176913611683,
    3781479909,
    124606578932734,
    8164951181,
    116489249551000,
}

local DeathTypes     = {

    EVISCERATE       = function(char : Model)
        -- Compiles limbs
        local Limbs = {}
        for _, limb in pairs(char:GetChildren()) do
            if limb:IsA("BasePart") and not table.find({"HumanoidRootPart", "Torso"}, limb.Name) then
                table.insert(Limbs, limb)
            end
        end

        -- Slices them off
        for i = 1, #Limbs do
            task.spawn(function()
                local ChosenLimb = Limbs[math.random(1, #Limbs)]
                table.remove(Limbs, table.find(Limbs, ChosenLimb))

                -- Spurt effect
                local Spurt = nil
                for _, joint in char.Torso:GetChildren() do
                    local IsMotor = joint:IsA("Motor6D") and joint.Part0 == char.Torso and joint.Part1 == ChosenLimb
                    local IsConstraint = joint:IsA("BallSocketConstraint")
                        and joint.Attachment0 ~= nil and joint.Attachment1 ~= nil
                        and joint.Attachment0.Parent == char.Torso and joint.Attachment1.Parent == ChosenLimb

                    if IsMotor or IsConstraint then
                        if not Spurt then
                            local JointCFrame = IsMotor and (joint.Part0.CFrame * joint.C0) or joint.Attachment0.WorldCFrame
                            local WeldC0 = IsMotor and joint.C0 or joint.Attachment0.CFrame

                            Spurt = BloodParts.Spurt:Clone()
                            Spurt.CFrame = JointCFrame
                            Spurt.Parent = char

                            local Weld = Instance.new("Weld")
                            Weld.Part0 = char.Torso
                            Weld.Part1 = Spurt
                            Weld.C0 = WeldC0
                            Weld.C1 = CFrame.new()
                            Weld.Parent = Spurt
                        end

                        joint:Destroy()
                    end
                end

               if Spurt then
                    Spurt:WaitForChild("Init").SoundId = "rbxassetid://"..INIT_IDs[math.random(1, #INIT_IDs)]
                    TweenService:Create(Spurt.Spew, TweenInfo.new(3/4), {Volume = 0.5}):Play()
                    Spurt.Init:Play()
                    Spurt.Spew:Play()
                    task.wait(8)

                    TweenService:Create(Spurt.Spew, TweenInfo.new(4), {Volume = 0}):Play()
                    for _, pe in Spurt:GetChildren() do
                        if pe:IsA("ParticleEmitter") then
                            TweenService:Create(pe, TweenInfo.new(4), {Rate = 0}):Play()
                        end
                    end

                    game:GetService("Debris"):AddItem(Spurt, 10)
               end
            end)
        end
    end,

}

return DeathTypes