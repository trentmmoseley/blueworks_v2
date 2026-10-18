local _BUTTONS       = {}

-- Services
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")

-- Player stuff
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local ButtonSounds   = PlayerGui.Sounds.Button

-- Main function
function _BUTTONS.Function()
	-- Button noises
	local function manageButton(button)
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			local Parent = button.Parent
			local UIStroke = Parent:FindFirstChild("UIStroke")
			local TextLabel = Parent:FindFirstChild("TextLabel")
			
			local OrigUISColor = UIStroke and UIStroke.Color or nil
			local OrigTextColor = TextLabel and TextLabel.TextColor3 or nil
			local OrigTST = TextLabel and TextLabel.TextStrokeTransparency or nil
			
			if UIStroke then
				UIStroke.Changed:Connect(function()
					OrigUISColor = UIStroke.Color
				end)
			end
			
			if Player:GetAttribute("Device") == "Mobile" and TextLabel and UIStroke then
				button.Size = UDim2.fromScale(1.25, 1.25)
				button.Position = UDim2.fromScale(-1/8, -1/8)
			end
			
			button.MouseEnter:Connect(function()
				ButtonSounds.ButtonHover:Play()
				if Player.Team == game.Teams.Spectators then
					-- Effects
					if Parent and UIStroke and TextLabel then
						Parent.BackgroundColor3 = OrigUISColor
						TweenService:Create(Parent, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
						TweenService:Create(TextLabel, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 1,}):Play()
					end
				end
			end)
			
			button.MouseLeave:Connect(function()
				-- Effects
				if Parent and UIStroke and TextLabel then
					TweenService:Create(Parent, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					TweenService:Create(TextLabel, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = OrigTextColor, TextStrokeTransparency = OrigTST}):Play()
				end
			end)

			button.MouseButton1Click:Connect(function()
				if not button:IsA("TextButton") or (button.Text ~= "VOTED" and button.Text ~= "CHOSEN") then
					local Sounds = ButtonSounds.Press:GetChildren()
					local ChosenSound = Sounds[math.random(1, #Sounds)]
					ChosenSound:Play()
				end
			end)
		end
	end

	for _, button in pairs(PlayerGui:GetDescendants()) do
		manageButton(button)
	end

	PlayerGui.DescendantAdded:Connect(function(button)
		manageButton(button)
	end)
end

return _BUTTONS