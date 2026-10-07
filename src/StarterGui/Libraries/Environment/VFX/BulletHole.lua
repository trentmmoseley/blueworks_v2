-- Services
local Debris              = game:GetService("Debris")
local RepStorage          = game:GetService("ReplicatedStorage")
local TweenService        = game:GetService("TweenService")

-- Modules and objects
local GunEnv              = RepStorage.VFX.GunEnv
local BulletHoleTemp      = GunEnv.BulletHole

-- [[ funcs ]] --

local BulletHole          = {

    ["BulletHole"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Position = args[1]
            local Normal = args[2]
            local HitInstance = args[3]

            local Ricochet = RepStorage.VFX.GunEnv.Ricochet:Clone()
            Ricochet.Parent = game.Workspace
            Ricochet.Position = Position

            task.wait()
            Ricochet.PointLight.Enabled = true

            local Sound = Ricochet["Ricochet"..math.random(1, 2)]
            Sound:Play()

            task.delay(1/16, function()
                for _, p in pairs(Ricochet:GetChildren()) do
                    if p:IsA("ParticleEmitter") then
                        p:Emit()
                    end
                end
            end)

            Debris:AddItem(Ricochet.PointLight, 0.05)
            Debris:AddItem(Ricochet, 3)

            local Folder = game.Workspace:FindFirstChild("BulletHoles")
            if not Folder then
                Folder = Instance.new("Folder")
                Folder.Name = "BulletHoles"
                Folder.Parent = game.Workspace
            end

            local BulletHole = BulletHoleTemp:Clone()
            BulletHole.Parent = Folder
            BulletHole.CFrame = CFrame.new(Position, Position - Normal) * CFrame.Angles(math.rad(90), math.rad(math.random(0, 360)), 0)

            -- Weld to the landing part so the hole moves with it
            if HitInstance and HitInstance:IsA("BasePart") then
                BulletHole.Anchored = false
                local Weld = Instance.new("WeldConstraint")
                Weld.Part0 = BulletHole
                Weld.Part1 = HitInstance
                Weld.Parent = BulletHole
            end

            BulletHole.Debris:Emit()

            task.wait(30)
            if BulletHole and BulletHole.Parent ~= nil then
                TweenService:Create(BulletHole.Decal, TweenInfo.new(60, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
                Debris:AddItem(BulletHole, 60)
            end
        end,

    },

}

return BulletHole