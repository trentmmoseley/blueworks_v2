-- Services
local Debris         = game:GetService("Debris")
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

-- Player stuff
local Player 	 	 = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local MuffleSG       = PlayerGui.Objects.SoundGroups.Muffle
local ZBSounds       = PlayerGui.Sounds.ZipBomb

-- Modules and objects
local Camera         = game.Workspace.CurrentCamera

local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)

-- Vars and consts
local MESH_SIZES     = {

    ["Inner"]        = 10,
    ["Center"]       = 20,
    ["Outer"]        = 40,

}

local ZipBomb     = {

    ["Prep"]      = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local CF = args[1]
            local Char = args[2]
            local Humanoid = Char:FindFirstChildOfClass("Humanoid")
            
            local NewAnim = Instance.new("Animation")
            NewAnim.AnimationId = "rbxassetid://138031300981376"
            local LoadedAnim : AnimationTrack = Humanoid.Animator:LoadAnimation(NewAnim)
			LoadedAnim.Looped = false
			LoadedAnim.Priority = Enum.AnimationPriority.Action4
            LoadedAnim:Play()
        end

    },

    ["Pulse"]       = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local CF = args[3]
            local Bullet = args[4]

            local LastRun = os.clock()
            task.spawn(function()
                while Bullet and Bullet.Parent do
                    local Time = os.clock()
                    local dt = Time - LastRun
                    LastRun = Time

                    if Bullet and Bullet.Parent then
                        local QuarterLerp = LerpByFrame(1/4, dt)
                        Bullet.Pulse.Mesh.Scale = Bullet.Pulse.Mesh.Scale:Lerp(Vector3.one * 2, QuarterLerp / 2)
                        Bullet.Transparency = Bullet.Pulse.Mesh.Scale.Magnitude / (Vector3.one * 2).Magnitude
                        if Bullet.Pulse.Mesh.Scale.Magnitude >= (Vector3.one * 2).Magnitude * 0.999 then
                            Bullet.Pulse.Mesh.Scale = Vector3.zero
                        end
                    end

                    task.wait()
                end
            end)
        end

    },

    ["Explosion"]    = {

        ["RENDER_DISTANCE"] = 2 ^ 10,
        ["Function"]        = function(args)
            local CF = args[1]
            local NewExp = RepStorage.VFX.Tethered.Explosion:Clone()
            NewExp.Parent = game.Workspace

            for _, part in pairs(NewExp:GetChildren()) do
                part.Mesh.Scale = Vector3.zero
                if part.Name == "Ring" then
                    for i = 1, Rand:NextInteger(1, 2) do
                        local NewPart = part:Clone()
                        NewPart.Name = "_ring"
                        NewPart.Parent = part.Parent
                    end
                end
            end

            NewExp:PivotTo(CF)

            for _, part in pairs(NewExp:GetChildren()) do
                local TI = TweenInfo.new(3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
                if MESH_SIZES[part.Name] then
                    TweenService:Create(part.Mesh, TI, {Scale = Vector3.one * MESH_SIZES[part.Name]}):Play()
                else
                    part.CFrame *= CFrame.Angles(Rand:NextNumber(0, 1) * 2 * math.pi, Rand:NextNumber(0, 1) * 2 * math.pi, Rand:NextNumber(0, 1) * 2 * math.pi)
                    TweenService:Create(part.Mesh, TweenInfo.new(3), {Scale = Vector3.new(1, 1, 0.1) * Rand:NextNumber(80, 120)}):Play()
                end
                TweenService:Create(part, TI, {Transparency = 1}):Play()
            end

            for _, part in pairs(NewExp:GetDescendants()) do
                if part:IsA("ParticleEmitter") then
                    part:Emit()
                elseif part:IsA("Sound") then
                    part:Play()
                end
            end
            
            -- Cam shake
            local Distance = (Camera.CFrame.Position - CF.Position).Magnitude
            if Distance <= 100 then
                local Strength = (1 - (Distance / 80)) * 3
                warn("shake cam")
            end

            task.wait(5)

            NewExp:Destroy()
        end

    },

    ["Distortion"]    = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local DistortionCC = Instance.new("ColorCorrectionEffect")
            DistortionCC.Parent = Lighting
            DistortionCC.TintColor = Color3.fromHSV(2/3, 1, 1)
            DistortionCC.Saturation = 3

            ZBSounds.Buzzing.Volume = 10

            -- Manages sounds
            local AllSounds = {}
            for _, sound in pairs(game.Workspace:GetDescendants()) do
                if sound:IsA("Sound") then
                    sound.SoundGroup = MuffleSG
                    table.insert(AllSounds, sound)
                end
            end

            local SoundConn = game.Workspace.DescendantAdded:Connect(function(sound)
                if sound:IsA("Sound") then
                    sound.SoundGroup = MuffleSG
                    table.insert(AllSounds, sound)
                end
            end)

            local Blur = Instance.new("BlurEffect")
            Blur.Parent = Lighting
            TweenService:Create(Blur, TweenInfo.new(1/4), {Size = 14}):Play()

            local Start = tick()
            local RunConn = nil
            RunConn = RunService.PreRender:Connect(function(dt)
                local TimeDiff = tick() - Start
                DistortionCC.Contrast = TrigWave("sin", 10 / TimeDiff, 2, TimeDiff, 0, 3)

                if TimeDiff >= 12 then
                    RunConn:Disconnect()
                    RunConn = nil
                end

                Camera.CFrame *= CFrame.Angles(

                    math.rad(TrigWave("cos", 45, 4, tick(), 0, 0) * dt),
                    math.rad(TrigWave("sin", 45, 2, tick(), 0, 0) * dt),
                    0

                )
            end)

            repeat task.wait() until not RunConn

            TweenService:Create(DistortionCC, TweenInfo.new(3), {Contrast = 0, TintColor = Color3.fromHSV(1, 0, 1), Saturation = 0}):Play()
            TweenService:Create(Blur, TweenInfo.new(3), {Size = 0}):Play()
            Debris:AddItem(DistortionCC, 3)
            Debris:AddItem(Blur, 3)

            SoundConn:Disconnect()
            for _, sound in pairs(AllSounds) do
                sound.SoundGroup = nil
            end

            TweenService:Create(ZBSounds.Buzzing, TweenInfo.new(5), {Volume = 0}):Play()
        end

    },

}

return ZipBomb