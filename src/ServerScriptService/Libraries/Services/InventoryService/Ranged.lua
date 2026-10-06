local Ranged     = {}

-- Services
local Players    = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local S3   	     = game:GetService("ServerScriptService")

local GunService = _G.Knit.GetService("GunService")

-- Modules and objects
local _general   = require(script.Parent._general)

-- [[ funcs ]] --

-- Inits item
function Ranged.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	-- Player
	local Player = Players:GetPlayerFromCharacter(char)
	
	-- Modules and objects
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	local M6D = nil

	local GunAnimEvent = nil
	local MovementChangeEvent = nil

	-- Anims
	local Anims = {}
	for _, anim in pairs(item.Configuration.Anims.Char:GetChildren()) do
		local LoadedAnim = Humanoid:LoadAnimation(anim)
		LoadedAnim.Priority = Enum.AnimationPriority[table.find({"Run", "Hold"}, anim.Name) and "Action" or "Action4"]
		if anim.Name == "Hold" then
			LoadedAnim.Looped = true
		end
		Anims[anim.Name] = LoadedAnim
	end

	table.insert(BaseItem["Functions"]["Equip"], function()
		if not (item and item:FindFirstChild("Handle")) then return end

        -- Loads ammo
		if not item:GetAttribute("Ammo") then
			item:SetAttribute("Ammo", ItemInfo.Mag)
		end

		-- Anims and whatnot
		if not (item and item:FindFirstChild("Handle")) then return end
		item.Handle.Equip:Play()

		local RightArm = char["Right Arm"]
		local RightGrip = RightArm:WaitForChild("RightGrip")
		local C0, C1 = RightGrip.C0, RightGrip.C1

		M6D = Instance.new("Motor6D", RightArm)
		M6D.Name = "Handle"
		M6D.Part0 = RightArm
		M6D.Part1 = item.Handle
		M6D.C0 = C0
		M6D.C1 = C1
		
		RightGrip:Destroy()
		
		Anims[char:GetAttribute("MovementType") == "RUN" and "Run" or "Hold"]:Play()

		-- Guns with a GunEquip animation in the Char folder play it right after equipping
		if Anims.GunEquip then
			Anims.GunEquip:Play()
		end

		-- Gun fire
		GunAnimEvent = GunService.GunAnim:Connect(function(c : Model, anim : string, stop : boolean?)
			if char == c and Anims[anim] then
				-- Restarts the track so repeated plays (e.g. per-round reloads) replay
				Anims[anim]:Stop()
				if stop ~= true then
					Anims[anim]:Play()

					-- Plays the equip sound every time the equip animation plays
					if anim == "GunEquip" and item:FindFirstChild("Handle") then
						item.Handle.Equip:Play()
					end
				end
			end
		end)

		-- Movement change effect
		local Mmt = char:GetAttribute("MovementType")
		local wasRunning = Mmt == "RUN"
		MovementChangeEvent = char:GetAttributeChangedSignal("MovementType"):Connect(function()
			Mmt = char:GetAttribute("MovementType")
			local isRunning = Mmt == "RUN"
			if wasRunning ~= isRunning then
				Anims.Hold:Stop()
				Anims.Run:Stop()
				Anims[isRunning and "Run" or "Hold"]:Play()
			end

			wasRunning = Mmt == "RUN"
		end)
	end)
	
	table.insert(BaseItem["Functions"]["Unequip"], function()
		for _, anim in Anims do
			anim:Stop()
		end
		
		if M6D then
			M6D:Destroy()
		end

		if GunAnimEvent then
			GunAnimEvent:Disconnect()
			GunAnimEvent = nil
		end

		if MovementChangeEvent then
			MovementChangeEvent:Disconnect()
			MovementChangeEvent = nil
		end
	end)
	
	return BaseItem
end

return Ranged