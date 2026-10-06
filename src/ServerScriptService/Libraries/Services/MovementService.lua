-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local MovementService = Knit.CreateService({
    Name = "MovementService",
    Client = {
        LeanUpdate = Knit.CreateSignal()
    }
})

local CharService     = nil
local CommsService    = nil
local MovementRequest = require(RepStorage.Remotes.MovementRequest):Server()

-- Modules and objects
local MMT_SETTINGS    = require(RepStorage.Modules.Data.MovementSettings)

-- [[ funcs ]] --

-- Determines if player can get up at current location
local function canGetUp(char, mmt, desiredmmt)
	local CurrentInfo = MMT_SETTINGS[mmt]

	if CurrentInfo["crouchMMT"] and desiredmmt ~= "CRAWL" then
		local YVector = desiredmmt == "CROUCH" and 2.5 or 4
		local RayParams = RaycastParams.new()
		RayParams.FilterDescendantsInstances = {char, game.Workspace:WaitForChild("Characters")}
		RayParams.FilterType = Enum.RaycastFilterType.Exclude

		local Direction = Vector3.new(0, YVector, 0)
		local TheRay = game.Workspace:Raycast(char.Head.CFrame.Position, Direction, RayParams)
		
		return TheRay == nil or TheRay.Instance == nil
	end

    return true
end

-- On knit init completion
function MovementService:KnitInit() : ()
    CharService = Knit.GetService("CharService")
    CommsService = Knit.GetService("CommsService")

    -- On movement request
    MovementRequest:On(function(player, mmt)
        if player.Team ~= game.Teams.Spectators then
            local Character = player.Character or player.CharacterAdded:Wait()
            local CharClass = CharService:GetCharacterClass(Character)

            local StamClass = CharClass.StaminaClass

            if mmt ~= "JUMP" then
                if CharClass and (mmt ~= "RUN" or Character:GetAttribute("isAiming") ~= true) and not Character:GetAttribute("isDowned") then
                    if StamClass:CanDoAction(mmt) then
                        if canGetUp(Character, Character:GetAttribute("MovementType"), mmt) then
                            Character:SetAttribute("MovementType", mmt)
                            Character:SetAttribute("CheckpointID", 0)
                        else
                            CommsService:SendSubtitle(player, player, "Cannot get up here", "Red")
                        end
                    else
                        CommsService:SendSubtitle(player, player, string.format("Too tired to %s", mmt), "Red")
                    end
                end
            else
                if not StamClass:CanDoAction(mmt) then
                    CommsService:SendSubtitle(player, player, string.format("Too tired to %s", mmt), "Red")
                end
            end
        end
    end)

    -- Leaning
    self.Client.LeanUpdate:Connect(function(player, start, dir)
        if player.Team ~= game.Teams.Spectators then
            local Character = player.Character or player.CharacterAdded:Wait()
            local CharClass = CharService:GetCharacterClass(Character)

            if CharClass then
                local LeanClass = CharClass.LeanClass
                if LeanClass then
                    LeanClass:Lean(start, dir)
                end
            end
        end
    end)
end

return MovementService