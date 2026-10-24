local GrainEffect 	  = {}

-- Player stuff
local Player 		  = game.Players.LocalPlayer
local Character		  = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui		  = Player.PlayerGui

-- Services
local Rand			  = Random.new()
local RunService 	  = game:GetService("RunService")

-- Modules and objects
local TheGui		  = PlayerGui:WaitForChild(script.Name)
local TheStatic		  = TheGui.Frame._static

-- Vars and consts
local MIN_PART_CD	  = .5
local MAX_PART_CD	  = 10

local NextDP		  = tick() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD) -- dead pixel
local NextTB		  = tick() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD) -- track break

-- Main function
function GrainEffect.Function()
    TheStatic.ImageTransparency = 0.925

	RunService.RenderStepped:Connect(function(dt)
		-- Dead pixel
		if tick() >= NextDP then
			NextDP = tick() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD)
			
			for i = 1, math.random(1, 6) do
				task.spawn(function()
					task.wait(Rand:NextNumber(0, .5))
					local NewDP = TheStatic.DeadPixel:Clone()
					NewDP.Parent = TheStatic
					NewDP.Position = UDim2.fromScale(Rand:NextNumber(0, 1), Rand:NextNumber(0, 1))
					NewDP.Visible = true
					task.wait(Rand:NextNumber(0, .05))
					NewDP:Destroy()
				end)
			end
		end
		
		-- Track break
		if tick() >= NextTB	 then
			NextTB = tick() + Rand:NextNumber(MIN_PART_CD, MAX_PART_CD)
			for i = 1, 3 do
				task.spawn(function()
					task.wait(Rand:NextNumber(0, .5))
					local NewTB = TheStatic.TrackBreak:Clone()
					NewTB.Parent = TheStatic
					NewTB.Position = UDim2.fromScale(Rand:NextNumber(0, 1), 0)
					NewTB.Visible = true
					task.wait(Rand:NextNumber(0, .05))
					NewTB:Destroy()
				end)
			end
		end
	end)
end

return GrainEffect