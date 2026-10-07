-- Services
local Debris         = game:GetService("Debris")
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local DataController = _G.Knit.GetController("DataController")

-- Player
local Player         = Players.LocalPlayer

-- Modules and objects
local BloodVFX       = RepStorage.VFX.Blood
local Lerp           = require(RepStorage.Modules.Util.Math.Lerp)
local Progress       = require(RepStorage.Modules.Util.Math.Progress)
local PlaySound      = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local bfInit         = false
local HP_PER_SPLAT   = 0.5
local BLOOD_SPLATS   = 10

local BLOOD_SOUNDS   = {

    9113464573,
    9113464462,
    9113464550,
    9126067191,

}

local BloodMod       = {

    ["Blood"]        = {

        ["RENDER_DISTANCE"] = 2 ^ 9,
        ["Function"]        = function(args)
            local BloodMultiplier = DataController:Get("Client.Blood")
            if BloodMultiplier > 0 then
                local CF = args[1]
                local Damage = args[2]
                local BloodType = args[3]

                local ParticleCount = BLOOD_SPLATS * (1 + BloodMultiplier / 2)

                if ParticleCount > 0 then
                    -- Creates blood folder
                    local BloodFolder = game.Workspace:FindFirstChild("Blood")
                    if not BloodFolder then
                        BloodFolder = Instance.new("Folder")
                        BloodFolder.Name = "Blood"
                        BloodFolder.Parent = game.Workspace
                    end
                    
                    if not bfInit then
                        bfInit = true
                        BloodFolder:ClearAllChildren()
                    end

                    for i = 1, ParticleCount do
                        task.spawn(function()
                            -- Determines position
                            local RayParams = RaycastParams.new()
                            RayParams.FilterType = Enum.RaycastFilterType.Exclude
                            RayParams.FilterDescendantsInstances = {game.Workspace:WaitForChild("Characters"), game.Workspace.CurrentCamera, BloodFolder}

                            local Direction = Vector3.new(Rand:NextNumber(-1, 1) * 7, Rand:NextNumber(-1, 1) * 7, Rand:NextNumber(-1, 1) * 7)
                            local Raycast = game.Workspace:Raycast(CF.Position, Direction, RayParams)

                            if Raycast and Raycast.Instance then
                                local ChosenParticle = BloodVFX:FindFirstChild(BloodType) or BloodVFX.Blood
                                local NewParticle = ChosenParticle:Clone()
                                local OrigSize = NewParticle.Size * Rand:NextNumber(0.5, Lerp(0.25, 1, Progress(Damage, 5, 50)))
                                NewParticle.Size = Vector3.one / 100

                                NewParticle.Parent = BloodFolder
                                NewParticle.CFrame = CFrame.new(Raycast.Position, Raycast.Position - Raycast.Normal) * CFrame.Angles(math.rad(90), 0, math.rad(90))

                                TweenService:Create(NewParticle, TweenInfo.new(1/2), {Size = OrigSize}):Play()
                                PlaySound(BLOOD_SOUNDS[math.random(1, #BLOOD_SOUNDS)], "Ouch", NewParticle, nil, 1, Rand:NextNumber(0.9, 1.1))

                                task.wait(Lerp(30, 150, Damage / 100))

                                TweenService:Create(NewParticle, TweenInfo.new(10), {Size = Vector3.zero}):Play()
                                Debris:AddItem(NewParticle, 10)
                            end
                        end)
                    end
                end
            end
        end

    },

}

return BloodMod