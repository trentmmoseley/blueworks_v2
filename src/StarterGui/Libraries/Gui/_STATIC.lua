local _STATIC 	  	  = {}

-- Services
local Players		  = game:GetService("Players")
local Rand			  = Random.new()
local RunService 	  = game:GetService("RunService")

-- Player stuff
local Player 		  = Players.LocalPlayer
local PlayerGui		  = Player.PlayerGui

-- Vars and consts
local MIN_GRAIN_SIZE  = .4
local MAX_GRAIN_SIZE  = .6

local StaticParts	  = {}

-- Compiles static
local function compileStatic(static)
	if (static:IsA("ImageLabel") or static:IsA("ImageButton")) and static.Name == "_static" then
		table.insert(StaticParts, {static, static:FindFirstAncestorOfClass("ScreenGui")})
	end
end

-- Main function
function _STATIC.Function()
	-- Inits pre-existing static parts
	for _, static in pairs(PlayerGui:GetDescendants()) do
		compileStatic(static)
	end
	
	PlayerGui.DescendantAdded:Connect(function(static)
		compileStatic(static)
	end)
	
	RunService.RenderStepped:Connect(function(dt)
		for _, static in pairs(StaticParts) do
			if static[1].ImageTransparency < 0.995 and (not static[2] or static[2].Enabled) and static[1].Visible then
				static[1].TileSize = UDim2.fromScale(Rand:NextNumber(MIN_GRAIN_SIZE, MAX_GRAIN_SIZE), Rand:NextNumber(MIN_GRAIN_SIZE, MAX_GRAIN_SIZE))
			end
		end
	end)
end

return _STATIC