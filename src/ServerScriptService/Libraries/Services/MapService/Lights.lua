local Lights       = {}

-- Vars and consts
local CD_LIGHT_INT = 30

-- Main function
function Lights.Init(map)
	for _, system in pairs(map.Interactables.LightSystems:GetChildren()) do
		-- Inits system
		local Switches = system:FindFirstChild("Switches") or system:FindFirstChild("Switch")
		local Config = system:FindFirstChild("Configuration")
		if not Config then
			Config = Instance.new("Configuration")
			Config.Name = "Configuration"
			Config.Parent = system

			local isOn = Instance.new("BoolValue")
			isOn.Name = "isOn"
			isOn.Parent = Config
		end

		local isOn = Config.isOn

		-- Switches
		for _, switch in pairs(Switches:GetChildren()) do
			local Flip = switch:FindFirstChild("Switch")

			local ProxPrompt = Instance.new("ProximityPrompt")
			ProxPrompt.Parent = switch
			ProxPrompt.ActionText = string.format("Turn o%s", isOn.Value == true and "ff" or "n")
			ProxPrompt.MaxActivationDistance = 6
			ProxPrompt.HoldDuration = 0.25

			local OnSound = Instance.new("Sound")
			OnSound.Parent = switch.PrimaryPart
			OnSound.Name = "On"
			OnSound.SoundId = "rbxassetid://6593041544"

			local OffSound = Instance.new("Sound")
			OffSound.Parent = switch.PrimaryPart
			OffSound.Name = "Off"
			OffSound.SoundId = "rbxassetid://6593042054"

			ProxPrompt.Triggered:Connect(function()
				isOn.Value = not isOn.Value

				if isOn.Value == true then
					OnSound:Play()
				else
					OffSound:Play()
				end

				if Flip then
					Flip.CFrame *= CFrame.Angles(0, 0, math.pi)
				end
			end)

			isOn.Changed:Connect(function(new)
				ProxPrompt.ActionText = string.format("Turn o%s", new == true and "ff" or "n")
				ProxPrompt.Enabled = false
				task.wait(#system.Lights:GetChildren() / CD_LIGHT_INT)
				ProxPrompt.Enabled = true
			end)
		end
	end
end

return Lights
