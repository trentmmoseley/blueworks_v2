local Chemlight  = {}

-- Services
local Players 	 = game:GetService("Players")
local Rand 		 = Random.new()
local RepStorage = game:GetService("ReplicatedStorage")

-- Modules and objects
local CMTemp 	 = RepStorage.VFX.Chemlights.Chemlight

local _general   = require(script.Parent._general)
local VMAnim 	 = require(RepStorage.Remotes.VMAnim):Server()

-- Inits item
function Chemlight.initItem(item, char)
	local BaseItem = _general.initItem(item, char)
	local ItemInfo = require(item.Configuration.ItemInfo)

	local UsingPlayer = Players:GetPlayerFromCharacter(char)

	local Humanoid = char:FindFirstChildOfClass("Humanoid")
	local UseSelfAnim = Humanoid and Humanoid:LoadAnimation(item.Configuration.Anims.Char.Use)
	if UseSelfAnim then
		UseSelfAnim.Priority = Enum.AnimationPriority.Action
	end
	
	table.insert(BaseItem["Functions"]["Activate"], function()
		item:SetAttribute("Stack", math.max(item:GetAttribute("Stack") - 1, 0))

		UseSelfAnim:Play()
		local AnimID = item.Configuration.Anims.VM.Use.AnimationId
		if UsingPlayer then
			VMAnim:Fire(UsingPlayer, "START", AnimID)
		end
		
		local FinalCF = char.PrimaryPart.CFrame + char.PrimaryPart.CFrame.LookVector * 2
		local RayParams = RaycastParams.new()
		RayParams.FilterDescendantsInstances = {game.Workspace:WaitForChild("Characters")}
		RayParams.FilterType = Enum.RaycastFilterType.Exclude

		local Direction = char.PrimaryPart.CFrame.LookVector.Unit
		local Raycast = game.Workspace:Raycast(char.PrimaryPart.CFrame.Position, Direction * 2, RayParams)
		if Raycast and Raycast.Instance then
			FinalCF = CFrame.new(Raycast.Position)
		end

		local NewCM = CMTemp:Clone()
		NewCM.Parent = game.Workspace
		NewCM:PivotTo(FinalCF * CFrame.Angles(
			Rand:NextNumber(0, 2 * math.pi),
			Rand:NextNumber(0, 2 * math.pi),
			Rand:NextNumber(0, 2 * math.pi)
		))

		NewCM.Container.Init:Play()
	end)
	
	return BaseItem
end

return Chemlight