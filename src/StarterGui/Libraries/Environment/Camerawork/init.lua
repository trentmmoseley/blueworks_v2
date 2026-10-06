local Camerawork = {}

-- Services
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Player
local Player     = Players.LocalPlayer

-- Main function
function Camerawork.Function()
    Player.CameraMaxZoomDistance = 10
    Player.CameraMinZoomDistance = 10

    RunService.PreRender:Connect(function(dt)
        for _, mod in script:GetChildren() do
            require(mod).Function(dt)
        end
    end)
end

return Camerawork