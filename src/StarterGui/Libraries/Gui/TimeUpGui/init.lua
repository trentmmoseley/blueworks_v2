local TimeUpGui      = {}

-- Services
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Sounds         = PlayerGui.Sounds.OutOfTime

local PNDRSubjects   = require(RepStorage.Modules.Data.PNDRSubjects)
local TimeUpEvent    = require(RepStorage.Remotes.TimeUp):Client()

-- [[ funcs ]] --

-- Main function
function TimeUpGui.Function()
    TimeUpEvent:On(function(entity : number)
        TheGui.Enabled = true
        Sounds.Electricity:Play()
        task.wait(0.25)

        local Flash         = Instance.new("ColorCorrectionEffect")
        Flash.Name          = "OutOfTimeFlash"
        Flash.Brightness    = 10
        Flash.Contrast      = 15
        Flash.Saturation    = -1
        Flash.Parent        = Lighting

        Sounds.PowerOutage:Play()
        Sounds.PowerOutageBase:Play()

        task.wait(0.05)
        TweenService:Create(Flash, TweenInfo.new(1/2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Brightness = -1, Contrast = 0, Saturation = 0}):Play()

        task.wait(12)
        require(script[PNDRSubjects[entity].Name]).UI()
    end)
end

return TimeUpGui