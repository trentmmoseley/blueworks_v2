-- Services
local Players     = game:GetService("Players")

-- Player
local Player      = Players.LocalPlayer

-- Modules and objects
local Libraries   = script.Parent:WaitForChild("Libraries")
repeat task.wait() until Player:GetAttribute("Device") and _G.Knit
for _, mod : ModuleScript in Libraries:GetChildren() do
    require(mod).Function()
end