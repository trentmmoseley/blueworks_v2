-- Services
local Debris       = game:GetService("Debris")
local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Player stuff
local Player 	   = Players.LocalPlayer
local PlayerGui	   = Player.PlayerGui

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local PlaySound    = require(RepStorage.Modules.Util.PlaySound)

local Camera	   = game.Workspace.CurrentCamera
local DecoyCC	   = Lighting:FindFirstChild("DecoyCC")
if DecoyCC then
	DecoyCC:Destroy()
end

local DecoyAggro    = PlayerGui.Sounds.Characters.Tethered.DecoyAggro
local DecoyJS		= RepStorage.VFX.Decoy.DecoyJS

local Decoy        = {

    ["Reveal"]     = {

        ["RENDER_DISTANCE"] = 2 ^ 10,
        ["Function"]        = function(args)
            local Char = args[4]
            PlaySound(5405814864, "Decoy1", Char.PrimaryPart, nil, 0.25, Rand:NextNumber(.9, 1.1))
            PlaySound(9810776841, "Decoy2", Char.PrimaryPart, nil, 1, Rand:NextNumber(.9, 1.1))
            TweenService:Create(Char.PrimaryPart:WaitForChild("Decoy2"), TweenInfo.new(1), {Volume = 0}):Play()
        end,

    },

    ["Disappear"]  = {

        ["RENDER_DISTANCE"] = 2 ^ 9,
        ["Function"]        = function(args)
            local Skin = args[4]
            local Char = args[5]

            local PsyRig = RepStorage.VFX.Tethered.PsyRig:Clone()
            PsyRig.Parent = game.Workspace

            -- Positions parts
            for _, part in pairs(PsyRig:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CFrame = Char[part.Name].CFrame
                end
            end

            task.wait(20)

            for _, part in pairs(PsyRig:GetDescendants()) do
                if part:IsA("BasePart") then
                    TweenService:Create(part, TweenInfo.new(20), {Transparency = 1, Color = Color3.fromHSV(2/3, 1, 1)}):Play()
                end
            end
            
            Debris:AddItem(PsyRig, 20)
        end

    },

    ["Aggro"]		= {

		["RENDER_DISTANCE"] = math.huge,
		["Function"]		= function(args)
            local CF = args[1]
			DecoyCC = Instance.new("ColorCorrectionEffect")
			DecoyCC.Name = "DecoyCC"
			DecoyCC.Saturation = -2
			DecoyCC.Parent = Lighting
			
			local DJS = DecoyJS:Clone()
			DJS.Enabled = true
			DJS.ViewportFrame.CurrentCamera = Camera
			local Rig = DJS.ViewportFrame.WorldModel.Tethered
			Rig:PivotTo(CF)
			DJS.Parent = PlayerGui
			
			for _, static in pairs(DJS:GetChildren()) do
				if static.Name == "_static" then
					if static:FindFirstChild("doDistort") then
						static.ImageColor3 = Color3.fromHSV(2/3, 1, 1)
						static.Size = UDim2.fromScale(1, Rand:NextNumber(0, 0.5))
						static.Position = UDim2.fromScale(0, Rand:NextNumber(0, 1 - static.Size.Y.Scale))
					end
				end
			end
			
			local Connection = nil
			local JSInit = tick()
			Connection = RunService.RenderStepped:Connect(function(dt)
				Rig:PivotTo(CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position), 0)
				
				local TP = 0
				for _, static in pairs(DJS:GetChildren()) do
					if static.Name == "_static" and not static:FindFirstChild("doDistort") then
						static.ImageTransparency = Lerp(DJS._static.ImageTransparency, 1, 0.025)
						TP = static.ImageTransparency
					end
				end
				
				if (Rig.PrimaryPart.Position - Camera.CFrame.Position).Magnitude <= 1 or tick() >= JSInit + 10 then
					DJS:Destroy()
					Connection:Disconnect()
					Connection = nil
				end
			end)
			
			--[[local Anim = Instance.new("Animation")
			Anim.AnimationId = "rbxassetid://12360466866"
			local LoadedAnim = Rig.Humanoid.Animator:LoadAnimation(Anim)
			Anim:Destroy()
			LoadedAnim.Looped = true
			LoadedAnim:Play()]]--

			DecoyAggro.Aggro1.PlaybackSpeed = Rand:NextNumber(.9, 1.1)
			DecoyAggro.Aggro1:Play()
			task.wait(.125)
			DecoyAggro.Aggro1:Stop()
			DecoyAggro.Aggro2.Volume = 1
			TweenService:Create(DecoyAggro.Aggro2, TweenInfo.new(1), {Volume = 0}):Play()
			
			for i = 1, 10 do
				DecoyCC.Saturation = i % 2 == 0 and -2 or 0
				task.wait(0.05)
			end
			
			task.wait(15)
			
			TweenService:Create(DecoyCC, TweenInfo.new(10), {Saturation = 0}):Play()
			Debris:AddTag(DecoyCC, 15)
		end,

	},

}

return Decoy