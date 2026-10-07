local DetectionGui   = {}

-- Services
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

local DetectService  = _G.Knit.GetService("DetectionService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local VPF            = TheGui:WaitForChild("ViewportFrame")
local Eye            = VPF.WorldModel.Eye

local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)

-- Vars and consts
local COLORS         = {Color3.fromRGB(255, 225, 0), Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 0, 0)}
local UI_ORIG_POS    = UDim2.fromScale(0.68, 0.482)

local CurrentLevel   = 0

local DEFAULT_CF     : CFrame = Eye.PrimaryPart.CFrame

-- Main function
function DetectionGui.Function()
    -- On detect
    DetectService.DetectionUpdate:Connect(function(level)
        TheGui.Enabled = Player.Team == game.Teams.Squadmates and level > 0
        CurrentLevel = level

        if TheGui.Enabled then
            for _, part in TheGui:GetDescendants() do
                if part:IsA("UIStroke") or part.Name == "MainPart" then
                    part.Color = COLORS[level]
                elseif part:IsA("ViewportFrame") then
                    part.ImageColor3 = COLORS[level]
                end
            end

            Eye.Pupil.Size = Vector3.one * (level == 3 and 2.125 or 2.3)
        end
    end)

    RunService.PreRender:Connect(function(dt)
        local Factor = (CurrentLevel == 3 and 1 or 0) * 2.5
        VPF.Position = UI_ORIG_POS + UDim2.fromOffset(Rand:NextNumber(-1, 1) * Factor, Rand:NextNumber(-1, 1) * Factor)
        Eye:PivotTo(DEFAULT_CF * (CurrentLevel > 1 and CFrame.Angles(0, 0, 0) or CFrame.Angles(
            math.rad(TrigWave("sin", 22.5, 1/2, os.clock(), 0, 0)),
            math.rad(TrigWave("cos", 45, 1, os.clock(), 0, 0)),
            0
        )))
    end)
end

return DetectionGui