local VFX       = {}

-- Services
local Players   = game:GetService("Players")
local Player    = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

-- Main function
function VFX.Function()
    _G.Knit.GetService("VFXService").VFXRequest:Connect(function(module, vfx, cf, ...)
        local Args = {...}
		
		local Module = require(script[module])
		local FoundFunction = Module[vfx]

        local RefPoint = (typeof(cf) == typeof(CFrame.new()) and cf.Position or cf)
		local CharDistance = (Character ~= nil and Character.Parent ~= nil) and (RefPoint - Character.PrimaryPart.Position).Magnitude or math.huge
		local CamDistance = (RefPoint - game.Workspace.CurrentCamera.CFrame.Position).Magnitude
		
		if CamDistance <= FoundFunction["RENDER_DISTANCE"] or CharDistance <= FoundFunction["RENDER_DISTANCE"] then
			FoundFunction["Function"](Args)
		end
    end)
end

-- Plays via client
function VFX.Play(module, vfx, cf, ...)
	local Args = {...}
	local Module = require(script[module])
	local FoundFunction = Module[vfx]
	FoundFunction.Function(cf, Args)
end

return VFX