local HeadpieceNV = {}

-- Services
local Players	  = game:GetService("Players")
local Teams		  = game:GetService("Teams")

-- Player
local Player	  = Players.LocalPlayer

-- Vars and consts
local NV_ANIM_ID  = 140694729697859
local NV_COLOR	  = Color3.fromHSV(0.4, 1, 1) -- matches LightEnv's NV tint
local AnimCDs	  = {}
local Managed	  = {}
local HookedUp	  = false

-- [[ funcs ]] --

-- Manages a character's headpiece according to their doNightVision attribute
local function manageCharacter(plr : Player, Character : Model)
	if Managed[Character] then return end
	Managed[Character] = true

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return end

	local Headpiece = Character:WaitForChild("Headpiece", 10)
	local LensesFolder = Headpiece and Headpiece:FindFirstChild("_lenses", true)
	if not LensesFolder then return end
	local Lenses = LensesFolder:GetChildren()

	-- Animation
	local Anim = Instance.new("Animation")
	Anim.AnimationId = "rbxassetid://"..NV_ANIM_ID
	local LoadedAnim = Animator:LoadAnimation(Anim)
	LoadedAnim.Priority = Enum.AnimationPriority.Action4
	Anim:Destroy()

	-- Toggles headpiece according to NV
	local function updateLenses()
		if plr.Team ~= Teams.Squadmates then return end

		local doNV = Character:GetAttribute("doNightVision") == true
		if doNV and (not AnimCDs[plr.UserId] or os.clock() >= AnimCDs[plr.UserId] + 1) then
			AnimCDs[plr.UserId] = os.clock()
			LoadedAnim:Play()
		end

		task.wait(1/2)
		for _, lens in Lenses do
			lens.Material = Enum.Material[doNV and "Neon" or "Glass"]
			lens.Color = NV_COLOR:Lerp(Color3.fromHSV(0, 0, 0), doNV and 0 or 0.75)
		end
	end

	updateLenses()
	Character:GetAttributeChangedSignal("doNightVision"):Connect(updateLenses)
end

-- Manages player
local function managePlayer(plr)
	if plr == Player then return end

	if plr.Character then
		manageCharacter(plr, plr.Character)
	end

	plr.CharacterAdded:Connect(function(Character)
		manageCharacter(plr, Character)
	end)
end

-- Main function
function HeadpieceNV.Function()
	if HookedUp then return end
	HookedUp = true

	for _, plr in Teams.Squadmates:GetPlayers() do
		task.spawn(managePlayer, plr)
	end

	Teams.Squadmates.PlayerAdded:Connect(function(plr)
		task.spawn(managePlayer, plr)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		AnimCDs[plr.UserId] = nil
	end)
end

return HeadpieceNV
