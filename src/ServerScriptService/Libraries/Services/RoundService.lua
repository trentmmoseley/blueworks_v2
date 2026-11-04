-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local RoundService    = Knit.CreateService({
    Name = "RoundService",
    Client = {},
})

local GameValues      = RepStorage.GameValues
local NodesLeft       = GameValues.Numbers.NodesLeft
local Status          = GameValues.Strings.Status
local TimeLeft        = GameValues.Numbers.TimeLeft

local ResultsScreen   = require(RepStorage.Remotes.ResultsScreen):Server()

-- Vars and consts
local TIME_LIMITS     = {
    Classic           = 60 * 15
}

local RESULT_MSGS     = {
    Squadmates        = {
        Color = Color3.fromRGB(0, 255, 0),
        Messages = {
            "All P.N.D.R. Subjects neutralized",
            "The area has been declared safe",
            {
                "Good job.",
                "Great work.",
                "A job well done.",
                "Mission accomplished.",
                "Mission complete.",
                "Excellent work.",
                "We have a great team here.",
                "Operation completion.",
                "You are now clear for extraction.",
                "Extraction arrives soon.",
                "Report to perimeter for extraction.",
                "Commence recontainment efforts.",
                "Well done, y'all.",
                "Good work, team.",
                "Good work, everyone.",
                "Great job.",
                "Excellent job.",
                "Begin recontainment.",
                "We did it, y'all.",
                "You did good.",
                "Mission completion.",
                "Mission success."
.            }
        }
    },
    Subjects         = {
        Color = Color3.fromRGB(255, 0, 0),
        Messages = {
            "Contact with all Squadmates lost",
            "Presence of P.N.D.R. Subjects reconfirmed",
            {
                "Lockdown for all citizens within twenty-five mile radius initiated.",
				"Shelter-in-place order for state declared.",
                "Area of interest expanded by twenty-five miles.",
                "Mission aborted.",
                "Mission has been declared a failure.",
                "Mission failed.",
                "Mission failure.",
                "Operation failure.",
                "Operation aborted.",
                "Operation has been declared a failure.",
            },
        }
    }
}

-- [[ funcs ]] --

-- Calculates Node progress
function RoundService:NodeProgress() : number
    return 1 - GameValues.Numbers.NodesLeft.Value / math.max(GameValues.Numbers.NodesLeft:GetAttribute("Init"), 1)
end

-- Main round loop
function RoundService:Classic() : (string, string)
    Status.Value = "Mission in progress"
    local Winner, Outcome = "", ""

    local TimeElapsed = 0
    local SubjectsSeen = false -- only counts a purge after Subjects entities were actually present
    TimeLeft.Value = TIME_LIMITS.Classic
    TimeLeft:SetAttribute("Init", TimeLeft.Value)

    local MainConn : RBXScriptConnection = nil
    MainConn = RunService.PreSimulation:Connect(function(dt)
        TimeElapsed += dt
        if NodesLeft.Value > 0 then -- timer does not go down if all nodes captured
            TimeLeft.Value = math.max(TimeLeft.Value - dt, 0)
        end
        TimeLeft:SetAttribute("TimeElapsed", TimeElapsed)

        -- Time up
        if TimeLeft.Value == 0 then
            Winner = "Subjects"
            Outcome = "TIME_UP"
        end

        -- Squadmates wiped out
        if #self.TeamService:GetTeamMembers("Squadmates") == 0 then
            Winner = "Subjects"
            Outcome = "SQUADMATES_WIPED"
        end

        -- Subject(s) purged: every Subjects entity (e.g. the Proxy) is dead or gone
        local Subjects = self.TeamService:GetTeamMembers("Subjects")
        local SubjectsAlive = 0

        if Subjects then
            for _, char in Subjects do
                local Hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
                if Hum and Hum.Health > 0 then
                    SubjectsAlive += 1
                end
            end
        end

        if SubjectsAlive > 0 then
            SubjectsSeen = true
        elseif SubjectsSeen then
            Winner = "Squadmates"
            Outcome = "SUBJECTS_PURGED"
        end

        -- End of game
        if Winner ~= "" then
            MainConn:Disconnect()
            MainConn = nil
        end
    end)

    repeat task.wait() until not MainConn

    -- Announces result
	if RESULT_MSGS[Winner] then
		self.StraySoundService:GlobalSound("GlobalAnn")
		for i, msg in ipairs(RESULT_MSGS[Winner]["Messages"]) do
			local UsedMsg = i < 3 and msg or msg[math.random(1, #msg)]
			local UsedColor = i < 3 and Color3.fromHSV(0, 0, 1) or RESULT_MSGS[Winner]["Color"]

			for _, plr in pairs(Players:GetPlayers()) do
				if plr.Team ~= game.Teams.Spectators and (plr.Team == game.Teams.Subjects or TimeLeft.Value > 0) then
					self.CommsService:SendSubtitle(nil, plr, UsedMsg, UsedColor)
				end
			end

			task.wait(1)
		end
	end

    Status.Value = "Mission over"

    -- Prepares players for the results screen: freezes them, disables NV and clears effects
    for _, plr in Players:GetPlayers() do
        if plr.Team ~= game.Teams.Spectators then
            plr:SetAttribute("ResultsActive", true)

            local Character = plr.Character
            local CharClass = Character and self.CharService:GetCharacterClass(Character)

            if CharClass then
                local NVClass = CharClass.NVClass
                if NVClass and NVClass.doNightVision then
                    NVClass:Toggle(false)
                end

                if CharClass.EffectClass then
                    for effect, _ in CharClass.EffectClass.Effects do
                        self.EffectService:Remove(Character, effect)
                    end
                end
            end
        end
    end

    ResultsScreen:FireAll(Winner, Outcome)
    return Winner, Outcome
end

function RoundService:KnitInit()
    self.TeamService = _G.Knit.GetService("TeamService")
    self.CommsService = _G.Knit.GetService("CommsService")
    self.StraySoundService = _G.Knit.GetService("StraySoundService")
    self.CharService = _G.Knit.GetService("CharService")
    self.EffectService = _G.Knit.GetService("EffectService")

    -- Results state ends when the character is reloaded
    local function watchPlayer(plr : Player)
        plr.CharacterAdded:Connect(function()
            plr:SetAttribute("ResultsActive", false)
        end)
    end

    Players.PlayerAdded:Connect(watchPlayer)
    for _, plr in Players:GetPlayers() do
        watchPlayer(plr)
    end
end

return RoundService