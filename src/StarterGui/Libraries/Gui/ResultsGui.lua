local ResultsGui     = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local Character      = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Sounds         = PlayerGui.Sounds

local MissionOver    = TheGui.MissionOver
local Winner         = TheGui.Winner
local HowTheyWon     = TheGui.HowTheyWon

local Leaderboard    = TheGui.Leaderboard
local LBList         = Leaderboard.Leaderboard
local Stats          = LBList.Stats

local LBTemplate     = LBList.UIGridLayout.Frame

local ResultsScreen  = require(RepStorage.Remotes.ResultsScreen)
local _effects       = require(PlayerGui.Libraries.Gui._EFFECTS)

-- Vars and consts
local WINNER_INFO    = {
    Squadmates       = {
        WinnerMSG    = "SQUADMATES WIN",
        HowMSG       = "All P.N.D.R. Subjects neutralized",
        Color        = Color3.fromRGB(0, 0, 255),
    },
    Subjects         = {
        WinnerMSG    = "SUBJECTS WIN",
        HowMSG       = "Squadmates wiped out",
        Color        = Color3.fromRGB(255, 0, 0),
    },
}

-- [[ funcs ]] --

-- Main function
function ResultsGui.Function()
    ResultsScreen:On(function(winner : string, how : string)
        if Player.Team == game.Teams.Spectators then return end
        Sounds.GameEvents.GlobalAnn:Play()
        TweenService:Create(MissionOver, TweenInfo.new(1), {TextTransparency = 0, TextStrokeTransparency = 1/2}):Play()
        task.wait(1)
        TweenService:Create(MissionOver, TweenInfo.new(1), {Size = UDim2.new(0.345 / 3, 0.062 / 2), Position = UDim2.fromScale(0.5, 0.05)}):Play()
        task.wait(1)

        for _, part in {Winner, HowTheyWon, MissionOver, Leaderboard} do
            _effects.CreateBuffer(part, 1)
        end
    end)
end

return ResultsGui