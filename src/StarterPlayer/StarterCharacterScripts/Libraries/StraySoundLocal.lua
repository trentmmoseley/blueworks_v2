local SS2          = {}

-- Services
local Players      = game:GetService("Players")

local SSService    = _G.Knit.GetService("StraySoundService")

-- Player
local Player       = Players.LocalPlayer
local PlayerGui    = Player:WaitForChild("PlayerGui")
local Sounds       = PlayerGui:WaitForChild("Sounds")

-- Main function
function SS2.Function()
    SSService.SoundRequest:Connect(function(soundName : string, stop : boolean?)
        -- Finds first sound with the given name
        local FoundSound = nil
        for _, inst in Sounds:GetDescendants() do
            if inst:IsA("Sound") and inst.Name == soundName then
                FoundSound = inst
                break
            end
        end

        if FoundSound then
            if stop ~= true then
                FoundSound:Play()
            else
                FoundSound:Stop()
            end
        else
            warn(`StraySoundService: could not find sound "{soundName}" in PlayerGui.Sounds`)
        end
    end)
end

return SS2
