-- Services
local GuiService  = game:GetService("GuiService")
local Players  	  = game:GetService("Players")
local RepStorage  = game:GetService("ReplicatedStorage")
local RunService  = game:GetService("RunService")
local SGUI        = game:GetService("StarterGui")
local UIS		  = game:GetService("UserInputService")

_G.Signal 		  = require(RepStorage.Packages._Index["sleitnick_signal@2.0.3"].signal)

_G.Knit        	  = require(RepStorage.Packages.Knit)
if not _G.Knit.Ready then
	_G.Knit.AddControllers(script.Parent:WaitForChild("Libraries"):WaitForChild("Controllers"))
end

_G.Knit.Start():andThen(function()
    print("Knit operational on client!")
    _G.Knit.Ready = true
end):catch(warn)

local CharService = _G.Knit.GetService("CharService")

-- Player
local Player	  = Players.LocalPlayer
local PlayerGui	  = Player.PlayerGui
local Mouse    	  = Player:GetMouse()

-- Modules and objects
local Libraries	  = PlayerGui:WaitForChild("Libraries")
local RemFuncs	  = RepStorage.RemFuncs

------------------------
-- [[ CLIENT LOGIC ]] --
------------------------

repeat task.wait() until _G.Knit.Ready

-- [[ DEACTIVATES CORE GUI / CHANGES RESET BUTTON CALLBACK FUNC ]] --
task.spawn(function()
	local Success, Err = false, nil

	repeat
		Success, Err = pcall(function()
			SGUI:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
			-- SGUI:SetCore("ResetButtonCallback", false)
		end)

		if not Success then
			warn(Err)
		end

		task.wait()
	until Success
end)

-- [[ DETERMINES PLATFORM ]] --
if GuiService:IsTenFootInterface() then -- are they on console?
	CharService.DeviceUpdate:Fire("Console")
else
	if UIS.TouchEnabled and not UIS.MouseEnabled then
		CharService.DeviceUpdate:Fire("Mobile")
	else
		CharService.DeviceUpdate:Fire("Desktop")
	end
end

-- [[ FPS + MOUSE ]] --
RunService.RenderStepped:Connect(function(dt)
	Mouse.Icon = "rbxassetid://68308747"
end)

-- [[ LOADS MODULES ]] --
repeat task.wait() until Player:GetAttribute("Device")
for _, mod in pairs(Libraries:GetDescendants()) do
	if mod:IsA("ModuleScript") and not table.find({"_template", "_mousetracking"}, mod.Name) and not mod.Parent:IsA("ModuleScript") and not mod:FindFirstAncestor("Controllers") then
		task.spawn(require(mod).Function)
	end
end

-- [[ PING CONFIRM ]] --
RemFuncs.getPingConfirm.OnClientInvoke = function()
	return true
end