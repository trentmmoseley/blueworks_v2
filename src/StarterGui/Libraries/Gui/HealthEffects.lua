local HEALTHEffects  = {}

-- Services
local Lighting       = game:GetService("Lighting")
local Players 		 = game:GetService("Players")
local Rand           = Random.new()
local RepStorage	 = game:GetService("ReplicatedStorage")
local RunService	 = game:GetService("RunService")

-- Player
local Player  		 = Players.LocalPlayer
local PlayerGui		 = Player.PlayerGui
local Sounds         = PlayerGui.Sounds.Health

local Character     = Player.Character or Player.CharacterAdded:Wait()
local Humanoid      = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local TheGui		 = PlayerGui:WaitForChild(script.Name)
local Camera         = game.Workspace.CurrentCamera

local DmgPointer     = require(RepStorage.Remotes.DamagePointer):Client()
local Lerp           = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress       = require(RepStorage.Modules.Util.Math.Progress)
local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)

-- Vars and consts
local HEALTHTilt     = 0

-- Gets center CF of camera
local function getCenterCF(object)
	local InstanceCF = object.CFrame
	local Pos = InstanceCF.Position
	
	local LookAt = InstanceCF.LookVector * Vector3.new(1, 0, 1)
	local CenterCF = CFrame.new(Pos, Pos + LookAt)
	
	return CenterCF
end

-- Calculates angle of damage crosshair
local function calculateAngle(center, point)
	local DamageDirection = center:PointToObjectSpace(point)
	local Theta = math.atan2(DamageDirection.Z, DamageDirection.X)
	local Angle = math.deg(Theta) + 90
	
	return Angle
end

-- Main function
function HEALTHEffects.Function()
	local HealthCC = Lighting:FindFirstChild("HealthCC")
    if not HealthCC then
        HealthCC = Instance.new("ColorCorrectionEffect")
        HealthCC.Name = "HealthCC"
        HealthCC.Parent = Lighting
    end

    local HealthDOF = Lighting:FindFirstChild("HealthDOF")
    if not HealthDOF then
        HealthDOF = Instance.new("DepthOfFieldEffect")
        HealthDOF.Name = "HealthDOF"
        HealthDOF.Parent = Lighting
    end
    HealthDOF.FarIntensity = 0
    HealthDOF.InFocusRadius = 500

    -- Damage crosshair
    DmgPointer:On(function(vec : Vector3, damage : number)
        local Indicator = TheGui.Frame.DamageCrosshair.Indicator:Clone()
        Indicator.Name = "_i"
        Indicator.Origin.Value = vec
        Indicator.Init.Value = os.clock()
        Indicator.Visible = true
        Indicator.Parent = TheGui.Frame.DamageCrosshair
    end)

    -- [[ RUN SERVICE ]] --
    TheGui.Enabled = Player.Team ~= game.Teams.Spectators
    if TheGui.Enabled then
        local RunConn = RunService.PreRender:Connect(function(dt)
            local QuarterLerp = LerpByFrame(1/4, dt)
            local Percentage = Character:GetAttribute("Health") / Character:GetAttribute("MaxHealth")

            -- Indicators
            for _, ind in pairs(TheGui.Frame.DamageCrosshair:GetChildren()) do
                if ind.Name == "_i" then
                    local CenterCF = getCenterCF(Camera)
                    local Angle = calculateAngle(CenterCF, ind.Origin.Value)
                    
                    ind.Rotation = Angle

                    -- Fades away
                    if os.clock() >= ind.Init.Value + 10 then
                        ind.Effect.UIStroke.Transparency = Lerp(ind.Effect.UIStroke.Transparency, 1, QuarterLerp / 5)
                        ind.Effect.BackgroundTransparency = Lerp(ind.Effect.UIStroke.Transparency, 1, 1/2)

                        if ind.Effect.UIStroke.Transparency >= 0.995 then
                            ind:Destroy()
                        end
                    end
                end
            end

            -- Health flash
            TheGui.Frame.HEALTHEffect.ImageTransparency = TrigWave("sin", (1 - Percentage) / 4, 1/2, os.clock(), 0, 1/2 + 0.6 * Percentage)
            Sounds.Heartbeat.Volume = (1 - Percentage) ^ 3
            Sounds.Heartbeat.PlaybackSpeed = Lerp(5/4, 1/2, Percentage)

            HEALTHTilt = Lerp(HEALTHTilt, TrigWave("sin", (1 - Percentage) ^ 4 * 12.5 * dt, 20, os.clock(), 0, 0), QuarterLerp / 5)

            Camera.CFrame *= CFrame.Angles(0, 0, math.rad(Sounds.Heartbeat.PlaybackLoudness * Sounds.Heartbeat.Volume * dt) * 2 + HEALTHTilt)

            local ShakeStrength = (1 - Percentage) ^ 4 / 10
            Camera.CFrame *= CFrame.Angles(math.rad(Rand:NextNumber(-1, 1)) * ShakeStrength, math.rad(Rand:NextNumber(-1, 1)) * ShakeStrength, math.rad(Rand:NextNumber(-1, 1)) * ShakeStrength)

            HealthCC.TintColor = Color3.fromHSV(1, Sounds.Heartbeat.PlaybackLoudness * Sounds.Heartbeat.Volume / 1000 + (1 - Percentage) / 5, 1)
            HealthCC.Contrast = Lerp(0, 3/8, 1 - Percentage)
            HealthCC.Saturation = Lerp(0, -1, Progress(Humanoid.Health, Humanoid.MaxHealth, 0))

            HealthDOF.FarIntensity = (1 - Humanoid.Health / Humanoid.MaxHealth)
            HealthDOF.InFocusRadius = 500 * (1 - HealthDOF.FarIntensity) ^ 6

            local StaticTransparency = Lerp(1, 0.9, (1 - Percentage) ^ 4)
            TheGui.Frame._static.ImageTransparency = StaticTransparency

            -- Ear ringing
            Sounds.EarRinging.Volume = Lerp(Sounds.EarRinging.Volume, 0, QuarterLerp / 10)
        end)

        -- Damage
        local PrevHealth = Character:GetAttribute("Health")
        Character:GetAttributeChangedSignal("Health"):Connect(function()
            local Damage = math.max(PrevHealth - Character:GetAttribute("Health"), 0)
            Sounds.EarRinging.Volume += ((Damage / 50) / 2) ^ 3

            PrevHealth = Character:GetAttribute("Health")
        end)

        -- Turns off GUI on death
        Player.Changed:Connect(function(new)
            if Player.Team == game.Teams.Spectators then
                RunConn:Disconnect()
                TheGui.Enabled = false
                HealthCC:Destroy()
            end
        end)
    end
end

return HEALTHEffects