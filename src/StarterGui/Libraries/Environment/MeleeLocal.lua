local MeleeLocal   = {}

-- Services
local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")

local InvService   = _G.Knit.GetService("InventoryService")

-- Main function
function MeleeLocal.Function()
    local ItemDisplays = RepStorage:WaitForChild("ItemDisplays")

    -- Server-triggered melee sound: plays a Use sound from the character's tool
    -- for every client. The sound is sourced from the replicated ItemDisplays
    -- copy because the owner's client strips the equipped tool's children (Viewmodel)
    InvService.ActionRequest:Connect(function(action : string, char : Model, toolName : string, soundName : string)
        if action ~= "PLAY_SOUND" then return end
        if not (char and char.Parent) then return end

        local Display = ItemDisplays:FindFirstChild(toolName)
        local Source  = Display and Display.Handle:FindFirstChild(soundName)
        local Parent  = char.PrimaryPart

        if not (Source and Parent) then return end

        local Sound = Source:Clone()
        Sound.Parent = Parent
        Sound:Play()

        Sound.Ended:Connect(function()
            Sound:Destroy()
        end)
    end)
end

return MeleeLocal
