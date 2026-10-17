local Doors		   = {}

-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local S3		   = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local CommsService = _G.Knit.GetService("CommsService")

-- Vars and consts
local DOOR_MSGS	   = {
	
	{"It's locked. You need a key", 		 	   Color3.fromRGB(255, 200, 0)},
	{"It's locked", 							   Color3.fromRGB(255, 0, 0)}
	
}

local DOOR_SOUNDS  = {
	
	["_blast"]	   = {18525177493, 18525177493},
	["_hinge"] 	   = {833871080, 7038967181},
	["_slide"]	   = {1910795334, 1910795334},
	
}

-- Door funcs
function Doors._blast(door, isopen)
	isopen.Value = true
	local OrigSize = door.Door.Size
	local OrigCF = door.Door.CFrame
	task.wait(1)
	TweenService:Create(door.Door, TweenInfo.new(5, Enum.EasingStyle.Sine), {CFrame = OrigCF + Vector3.new(0, OrigSize.Y / 2, 0), Size = Vector3.new(OrigSize.X, OrigSize.Y * 0.1, OrigSize.Z)}):Play()
	task.wait(9)
	door.PrimaryPart.CloseSound:Play()
	task.wait(1)
	TweenService:Create(door.Door, TweenInfo.new(5, Enum.EasingStyle.Sine), {CFrame = OrigCF, Size = OrigSize}):Play()
	task.wait(6.5)
	isopen.Value = false
end

function Doors._hinge(door, isopen)
	isopen.Value = not isopen.Value
	TweenService:Create(door.MainDoor.HingePart, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {CFrame = door.MainDoor.HingePart.CFrame * CFrame.Angles(0, math.rad(isopen.Value == true and -90 or 90), 0)}):Play()
	for _, part in pairs(door:GetDescendants()) do
		task.spawn(function()
			if part:IsA("BasePart") then
				part.CanCollide = false
				task.wait(1)
				if part.Name ~= "MainPart" then
					part.CanCollide = true
				end
			end
		end)
	end
end

function Doors._slide(door, isopen)
	isopen.Value = not isopen.Value
	TweenService:Create(door.Door, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {CFrame = door.Door.CFrame * CFrame.new(0, 0, isopen.Value == true and 5 or -5)}):Play()
end

-- Main function
function Doors.Init(map)
	-- Manages doors
	for _, door in pairs(map.Interactables.Doors:GetChildren()) do
		local Config = door:FindFirstChild("Configuration")
		if Config then
			local AccessLevel = Config.AccessLevel
			local ProxPrompt = Instance.new("ProximityPrompt")
            ProxPrompt.Parent = door
			ProxPrompt.ObjectText = "Door"
			ProxPrompt.ActionText = "Open"
			ProxPrompt.HoldDuration = 0.25
			
			local isOpen = Instance.new("BoolValue")
            isOpen.Parent = door
			isOpen.Name = "isOpen"
			
			local MainDoor = door:FindFirstChild("MainDoor") or door:FindFirstChild("Door")
			
			-- Unanchors door part
			if door.Name == "_hinge" then
				for _, part in pairs(MainDoor:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HingePart" then
						part.Anchored = false
					end
				end
			end
			
			for _, part in pairs(MainDoor:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Doors"
				end
			end
			
			local OpenSound = Instance.new("Sound")
            OpenSound.Parent = door.PrimaryPart
			OpenSound.Name = "OpenSound"
			OpenSound.SoundId = string.format("rbxassetid://%s", tostring(DOOR_SOUNDS[door.Name][1]))

			local CloseSound = Instance.new("Sound")
            CloseSound.Parent = door.PrimaryPart
			CloseSound.Name = "CloseSound"
			CloseSound.SoundId = string.format("rbxassetid://%s", tostring(DOOR_SOUNDS[door.Name][2]))
			
			-- Pathfinding modifiers
			for _, part in pairs(door:GetDescendants()) do
				if part:IsA("BasePart") then
					local PathfindingModifier = Instance.new("PathfindingModifier")
					PathfindingModifier.PassThrough = AccessLevel.Value == 1
                    PathfindingModifier.Parent = part

					AccessLevel.Changed:Connect(function(newvalue)
						PathfindingModifier.PassThrough = newvalue == 1
					end)

					if door.Name == "Door" then
						task.spawn(function()
							repeat task.wait() until door:FindFirstChild("isOpen")

							door:WaitForChild("isOpen").Changed:Connect(function(newvalue)
								PathfindingModifier.PassThrough = not door.isOpen.Value

								if part.Parent == door and part.Name ~= "MainPart" then
									part.CanCollide = not newvalue
								end
							end)
						end)
					end

					part.CollisionGroup = "Doors"
				end
			end
			
			-- Sounds
			isOpen.Changed:Connect(function(new)
				if new == true then
					OpenSound:Play()
				else
					if door.Name ~= "_blast" then
						CloseSound:Play()
					end
				end
				ProxPrompt.ActionText = new == true and "Close" or "Open"
			end)
			
			ProxPrompt.Triggered:Connect(function(plrwhotriggered)
				local Character = plrwhotriggered.Character
				if Character and Character:GetAttribute("isGrabbed") == true then return end

				if AccessLevel.Value == 1 then
					-- Logic
					task.spawn(function()
						Doors[door.Name](door, isOpen)
					end)
					ProxPrompt.Enabled = false
					if door.Name ~= "_blast" then
						task.wait(1)
					else
						repeat task.wait() until isOpen.Value == false
					end
					ProxPrompt.Enabled = true
				else
					local DoorMsgInfo = DOOR_MSGS[AccessLevel.Value - 1]
					CommsService:SendSubtitle(plrwhotriggered, DoorMsgInfo[1], DoorMsgInfo[2])
				end
			end)
			
			-- Jiggle sound if applicable
			local Jiggle = nil
			if door.Name ~= "_blast" then
				Jiggle = Instance.new("Sound")
				Jiggle.Name = "Jiggle"
				Jiggle.Volume = 3
				Jiggle.SoundId = "rbxassetid://6814495006"
                Jiggle.Parent = door.PrimaryPart

				ProxPrompt.PromptButtonHoldBegan:Connect(function()
					Jiggle:Play()
				end)
			end
			
			-- Entity stuff
			local onEntityTryCooldown = false
			door.PrimaryPart.Touched:Connect(function(otherpart)
				local Char = otherpart:FindFirstAncestor("Characters") and otherpart:FindFirstAncestorOfClass("Model") or nil
				if Char and Char:GetAttribute("isNPC") == true and onEntityTryCooldown == false and AccessLevel.Value == 1 and ProxPrompt.Enabled == true then
					onEntityTryCooldown = true
					
					if Jiggle then
						Jiggle:Play()
					end
					
					task.wait(0.75)
					task.spawn(function()
						Doors[door.Name](door, isOpen)
					end)
					task.wait(0.5)
					onEntityTryCooldown = false
				end
			end)
		else
			door:Destroy()
		end
	end
end

return Doors