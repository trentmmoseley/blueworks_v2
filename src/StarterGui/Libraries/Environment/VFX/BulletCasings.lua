-- Services
local Collection	= game:GetService("CollectionService")
local RepStorage	= game:GetService("ReplicatedStorage")

-- Modules and objects
local Camera		= game.Workspace.CurrentCamera
local VFXStorage  	= RepStorage.VFX.BulletCasings

-- Vars and consts
local DropSounds	= {
	
	9113630931,
	9113630798,
	9113630797,
	9113630658,
	
}

local CASE_TAG	    = "BULLET_CASE"

local BulletCasings = {
	
	["Casing"]		= {
		
		["RENDER_DISTANCE"] = 60,
		["Function"]		= function(cf, args)
			local Char = args[1]
			local AmmoType = args[2]
			
			local CaseOrigin = nil
			
			if Char.Name == game.Players.LocalPlayer.Name then
				CaseOrigin = Camera:WaitForChild("Viewmodel"):FindFirstChild("_attachments", true)._casingeject
			else
				CaseOrigin = Char:FindFirstChildOfClass("Tool"):FindFirstChild("_attachments", true)._casingeject
			end
			
			local Casing = VFXStorage:FindFirstChild(AmmoType) or VFXStorage.BulletCasing
			local NewCasing = Casing:Clone()
			NewCasing.Parent = workspace
			NewCasing.CFrame = CaseOrigin.CFrame
			NewCasing.AssemblyLinearVelocity = CaseOrigin.CFrame.LookVector * 20
			Collection:AddTag(NewCasing, CASE_TAG)
			
			task.spawn(function()
				task.wait(0.5)

				NewCasing.Touched:Connect(function()
					if not NewCasing:FindFirstChildOfClass("Sound") then
						local NewSound = Instance.new("Sound", NewCasing)
						NewSound.SoundId = "rbxassetid://"..DropSounds[math.random(1, #DropSounds)]
						NewSound.Volume = 1
						NewSound:Play()
					end
				end)
			end)
			
			game:GetService("Debris"):AddItem(NewCasing, 10)
		end,
		
	}
	
}

return BulletCasings