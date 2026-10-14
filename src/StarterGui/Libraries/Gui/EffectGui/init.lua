local EffectGui      = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Queue          = TheGui.Frame.Queue

local EffectIDs      = require(script.EffectIDs)
local Effects        = {}

-- Vars and consts
local POSITIVITIES   = {
    ["Good"]	 = Color3.fromRGB(0, 255, 100),
    ["Neutral"]	 = Color3.fromRGB(255, 255, 255),
    ["Bad"]		 = Color3.fromRGB(255, 0, 0)
}

-- [[ funcs ]] --

-- Updates UI
local function updateUI(effects)
    for _, effect in Queue:GetChildren() do
        if effect:IsA("Frame") and (not effects[effect.Name] or effects[effect.Name][1] < os.clock()) then
            effect:Destroy()
        end
    end

    for effect, _ in effects do
        local FoundFrame = Queue:FindFirstChild(effect)
        if not FoundFrame then
            local NewFrame = Queue.UIListLayout.Effect:Clone()
            NewFrame.Name = effect

            local EffectInfo = EffectIDs[effect]
            NewFrame.EffectName.Text = string.upper(effect)
            NewFrame.EffectName.TextColor3 = POSITIVITIES[EffectInfo["Positivity"]]

            NewFrame.ImageLabel.Image = "rbxassetid://"..EffectInfo["Image"]
            NewFrame.ImageLabel.ImageColor3 = EffectInfo["Colors"]["Primary"]
            NewFrame.ImageLabel.UIStroke.Color = EffectInfo["Colors"]["Primary"]
            NewFrame.ImageLabel.BackgroundColor3 = EffectInfo["Colors"]["Secondary"]

            NewFrame.Parent = Queue
        end
    end
end

-- Main function
function EffectGui.Function()
    _G.Knit.GetService("EffectService").EffectUpdate:Connect(function(effects)
        Effects = effects
        updateUI(effects)
    end)

    RunService.PreRender:Connect(function(dt)
        for _, frame in TheGui.Frame.Queue:GetChildren() do
            local EffectInfo = Effects[frame.Name]
            if EffectInfo then
                local TimeLeft = EffectInfo[1] - os.clock()
                if TimeLeft > 0 then
                    if TimeLeft < 3600 then
                        frame.Timer.Text = math.floor(TimeLeft)..":"..string.format("%.2i", math.floor(60 * (TimeLeft % 1)))
                    else
                        frame.Timer.Text = ""
                    end
                else
                    frame:Destroy()
                end
            end
        end
    end)
end

return EffectGui