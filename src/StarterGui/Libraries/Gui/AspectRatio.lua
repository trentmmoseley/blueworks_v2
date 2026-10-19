local AspectRatio    = {}

-- Services
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)

-- Main function
function AspectRatio.Function()
    RunService.PreRender:Connect(function(dt)
        TheGui.Enabled = not (Character and Character.Parent)
    end)
end

return AspectRatio