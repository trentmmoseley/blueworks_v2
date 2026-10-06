local Healer        = {}

-- Services
local Players 	    = game:GetService("Players")
local RepStorage    = game:GetService("ReplicatedStorage")

local CAS 		    = _G.Knit.GetService("ChargedActionService")
local CharService   = _G.Knit.GetService("CharService")
local CommsService  = _G.Knit.GetService("CommsService")
local EffectService = _G.Knit.GetService("EffectService")
local ScoreService  = _G.Knit.GetService("ScoreService")
local SSService     = _G.Knit.GetService("StraySoundService")
local VFXService    = _G.Knit.GetService("VFXService")

-- Modules and objects
local _general      = require(script.Parent._general)
local PlaySound     = require(RepStorage.Modules.Util.PlaySound)
local VMAnim 	    = require(RepStorage.Remotes.VMAnim):Server()

-- Inits item
function Healer.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	local UsingPlayer = Players:GetPlayerFromCharacter(char)

	-- Loads the third-person use animation onto the character
	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	local UseSelfAnim = Humanoid and Humanoid:LoadAnimation(item.Configuration.Anims.Char.UseSelf)
	if UseSelfAnim then
		UseSelfAnim.Priority = Enum.AnimationPriority.Action
	end
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		local CharClass = CharService:GetCharacterClass(char)
		local StatClass = CharClass and CharClass[`{ItemInfo.HealStat}Class`]

		-- Checks if player contains stoppable effect
		local hasEffect = false
		if ItemInfo.Stops then
			for _, effect in pairs(ItemInfo.Stops) do
				if EffectService:Check(char, effect) then
					hasEffect = true
					break
				end
			end
		end

		-- Refuses to heal if the stat is already at its maximum
		if not StatClass or (char:GetAttribute(ItemInfo.HealStat) >= char:GetAttribute(`Max{ItemInfo.HealStat}`) and not hasEffect) then
			if UsingPlayer then
				CommsService:SendSubtitle(nil, UsingPlayer, `{ItemInfo.HealStat} is already stable`, "Red")
			end
			return
		end

		local AnimID = item.Configuration.Anims.VM.Use.AnimationId
		if UsingPlayer then
			VMAnim:Fire(UsingPlayer, "START", AnimID)
		end
		if UseSelfAnim then
			UseSelfAnim:Play()
		end

		-- Plays the use sound immediately, or after UseSoundDelay seconds if specified
		local UseSound
		local soundCancelled = false
		
		task.delay(ItemInfo.UseSoundDelay or 0, function()
			if not soundCancelled then
				UseSound = PlaySound(item.Handle.Use.SoundId, "Use", char.PrimaryPart, nil, 1, 1)
			end
		end)

		local useSuccess = CAS:ChargedAction(char, "HealerUse", ItemInfo.UseLength, function()
			return char:GetAttribute(ItemInfo.HealStat) < char:GetAttribute(`Max{ItemInfo.HealStat}`)
		end)

		-- The charged action has resolved (success or interruption): stop the char animation
		if UseSelfAnim then
			UseSelfAnim:Stop()
		end

		if UsingPlayer and not useSuccess then
			VMAnim:Fire(UsingPlayer, "STOP", AnimID)
		end

		if useSuccess then
			StatClass:Increment(ItemInfo.Potency)
			ScoreService:AwardScore(char, 10, "Healed self", true)

			if UsingPlayer then
				VFXService:PlayVFX(UsingPlayer, "HealEffect", "Heal", char.PrimaryPart.CFrame, Color3.fromRGB(100, 255, 100))
				SSService:PlaySound(UsingPlayer, item.Name)
			end

			if ItemInfo.simulateBandage then
				VFXService:GlobalVFX("Bandage", "Apply", char.PrimaryPart.CFrame, char, ItemInfo.BandageColor)
			end
			
			if ItemInfo.Stops then
				for _, effect in pairs(ItemInfo.Stops) do
					EffectService:Remove(char, effect)
				end
			end

			item:SetAttribute("Stack", math.max(item:GetAttribute("Stack") - 1, 0))
		else
			soundCancelled = true
			if UseSound then
				UseSound:Destroy()
			end
		end
	end)
	
	return BaseItem
end

return Healer