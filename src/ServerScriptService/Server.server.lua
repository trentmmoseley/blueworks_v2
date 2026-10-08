-- Services
local RepStorage = game:GetService("ReplicatedStorage")
local S3         = game:GetService("ServerScriptService")

_G.Signal 		 = require(RepStorage.Packages._Index["sleitnick_signal@2.0.3"].signal)
local Red        = require(game.ReplicatedStorage.Packages.Red) -- line must exist for red to work
local VMAnim 	 = require(RepStorage.Remotes.VMAnim):Server()  -- line must exist for viewmodel to work

-- Modules and objects
_G.Knit          = require(RepStorage.Packages.Knit)
_G.Knit.AddServices(S3.Libraries.Services)

_G.Knit.Start():andThen(function()
    print("Knit operational on server!")
    _G.Knit.Loaded   = true
end):catch(warn)

-- [[ PROX PROMPTS ]] --
local function handlePrompt(prompt : ProximityPrompt)
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Style = Enum.ProximityPromptStyle.Custom
end

for _, prompt in pairs(game.Workspace:GetDescendants()) do
	if prompt:IsA("ProximityPrompt") then
		handlePrompt(prompt)
	end
end

game.Workspace.DescendantAdded:Connect(function(prompt)
	if prompt:IsA("ProximityPrompt") then
		handlePrompt(prompt)
	end
end)

-- [[ Server logic ]] --
for i = 1, 8 do
	local Tethered = _G.Knit.GetService("NPCService"):CreateNPC("Human", CFrame.new(0, 10, i * 10))
end