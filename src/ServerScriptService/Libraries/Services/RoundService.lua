-- Services
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local RoundService    = Knit.CreateService({
    Name = "RoundService",
    Client = {}
})

local GameValues      = RepStorage.GameValues
local NodesLeft       = GameValues.Numbers.NodesLeft
local TimeLeft        = GameValues.Numbers.TimeLeft

-- Vars and consts
local TIME_LIMITS     = {
    Classic           = 60 * 15
}

-- [[ funcs ]] --

-- Calculates Node progress
function RoundService:NodeProgress() : number
    return 1 - GameValues.Numbers.NodesLeft.Value / math.max(GameValues.Numbers.NodesLeft:GetAttribute("Init"), 1)
end

-- Main round loop
function RoundService:Classic() : (string, string)
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

    return Winner, Outcome
end

function RoundService:KnitInit()
    self.TeamService = _G.Knit.GetService("TeamService")
end

return RoundService