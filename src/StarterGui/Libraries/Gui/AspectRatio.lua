local AspectRatio    = {}

-- Services
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui          = PlayerGui:WaitForChild(script.Name)

-- The Proxy sequence's final shot, which also needs the AspectRatio frame
local ProxyFinalScene = PlayerGui:WaitForChild("TimeUpGui"):WaitForChild("Proxy"):WaitForChild("FinalScene")

-- Main function
function AspectRatio.Function()
    RunService.PreRender:Connect(function(dt)
        TheGui.Enabled = not (Character and Character.Parent) or ProxyFinalScene.Visible
    end)
end

return AspectRatio