local DetectionGui   = {}

-- Services
local Players        = game:GetService("Players")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local DeathSeqs      = require(script.DeathSequences)

-- Main function
function DetectionGui.Function()
    Humanoid.Died:Connect(function()
        local Corpse = game.Workspace:WaitForChild("Corpses"):FindFirstChild(Player.Name)
        if Corpse then
            Corpse = Corpse:FindFirstChild("Head") and Corpse or nil 
        end

        -- Chooses death blurb
        local CauseOfDeath = Corpse and (Character:GetAttribute("CauseOfDeath") or "DEFAULT") or "NO_CORPSE"

        -- Death sequence
        if DeathSeqs[CauseOfDeath] then
            DeathSeqs[CauseOfDeath]()
        else -- default sequence if custom one unfound
            DeathSeqs.DEFAULT()
        end
    end)
end

return DetectionGui