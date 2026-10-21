local DetectionGui   = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local DataController = _G.Knit.GetController("DataController")
local ScoreService   = _G.Knit.GetService("ScoreService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local DeathBlurbs    = require(script.DeathBlurbs)
local DeathSeqs      = require(script.DeathSequences)

local Pronouns       = require(RepStorage.Modules.Data.Pronouns)
local _effects       = require(PlayerGui.Libraries.Gui._EFFECTS)

local Camera         = game.Workspace.CurrentCamera

local MainFrame      = TheGui.MainFrame

local DeathBlurb     = MainFrame.DeathBlurb
local FinalScore     = MainFrame.Score

-- Vars and consts
local Gender         = DataController:Get("Character.Gender")

-- Main function
function DetectionGui.Function()
    Humanoid.Died:Connect(function()
        for _, sound in PlayerGui.Sounds:GetDescendants() do
            if sound:IsA("Sound") then
                if not table.find({"EarRinging", "Heartbeat"}, sound.Name) then
                    sound:Stop()
                else
                    TweenService:Create(sound, TweenInfo.new(10), {Volume = 0}):Play()
                end
            end
        end

        TheGui.Enabled = true
        local Corpse = game.Workspace:WaitForChild("Corpses"):FindFirstChild(Player.Name)
        if Corpse then
            Corpse = Corpse:FindFirstChild("Head") and Corpse or nil 
        end

        -- Chooses death blurb
        local CauseOfDeath = Corpse and (Character:GetAttribute("CauseOfDeath") or "DEFAULT") or "NO_CORPSE"
        local Blurb = DeathBlurbs.getBlurb(CauseOfDeath) or DeathBlurbs.getBlurb("DEFAULT")
        Blurb = Blurb:gsub("user_id", tostring(Player.UserId)):gsub("pronoun_possessive", Pronouns[Gender].Possessive):gsub("pronoun_object", Pronouns[Gender].Object)

        -- Death sequence
        if DeathSeqs[CauseOfDeath] then
            DeathSeqs[CauseOfDeath]()
        else -- default sequence if custom one unfound
            DeathSeqs.DEFAULT()
        end

        DeathBlurb.Text = string.format("\"%s\"", Blurb)
        MainFrame._static.ImageTransparency = 0

        ScoreService:GetScore(Player):andThen(function(val)
            FinalScore.Text = string.format("Final Score: <b>%i</b>", val)
        end)

        MainFrame.Visible = true
        _effects:CreateBuffer(MainFrame, 3)
        TweenService:Create(MainFrame._static, TweenInfo.new(1), {ImageTransparency = 0.5}):Play()
        PlayerGui.Sounds.Death.TurnOn:Play()
    end)
end

return DetectionGui