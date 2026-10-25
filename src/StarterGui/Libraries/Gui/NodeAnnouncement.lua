local StaminaBar     = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local TheText        = TheGui.TextLabel

local GameValues     = RepStorage.GameValues
local EventSounds    = PlayerGui.Sounds.GameEvents

local PluralString   = require(RepStorage.Modules.Util.PluralString)

-- Vars and consts
local isCrit         = false
local NextFadeOut    = 0

-- [[ funcs ]] --

-- Main function
function StaminaBar.Function()
    require(RepStorage.Remotes.NodeAnnouncement):Client():On(function()
        NextFadeOut = os.clock() + 5
        local NodesLeft = GameValues.Numbers.NodesLeft.Value
        TheText.Text = NodesLeft > 0 and string.format("%i %s %s", NodesLeft, PluralString(NodesLeft, "NODE", "NODES"), PluralString(NodesLeft, "REMAINS", "REMAIN")) or "CONTAIN THE SUBJECT"
        TheText.TextColor3 = Color3.fromHSV(1, NodesLeft > 1 and 0 or 1, 1)
        TheText.TextTransparency = 0
        TheText.TextStrokeTransparency = 1/2

        EventSounds.GlobalAnn:Play()
        if NodesLeft == 1 then
            EventSounds.HorrorSound:Play()
        end

        task.wait(5)

        if os.clock() >= NextFadeOut - 1 then
            TweenService:Create(TheText, TweenInfo.new(3), {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
        end
    end)
end

return StaminaBar