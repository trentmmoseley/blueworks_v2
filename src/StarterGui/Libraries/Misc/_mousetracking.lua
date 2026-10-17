local MouseTracking  = {}

-- Services
local Players		 = game:GetService("Players")
local RunService	 = game:GetService("RunService")

-- Player stuff
local Player		 = Players.LocalPlayer
local Mouse		 	 = Player:GetMouse()

-- Modules and objects
local Camera		 = game.Workspace.CurrentCamera

-- [[ funcs ]] --

-- Gets mouse position on screen
function MouseTracking.getPositionScale()
    local MouseX, MouseY = Mouse.X, Mouse.Y
	local MXRatio, MYRatio = MouseX / Camera.ViewportSize.X, MouseY / Camera.ViewportSize.Y

    return MXRatio * 2 - 1, MYRatio * 2 - 1
end

return MouseTracking