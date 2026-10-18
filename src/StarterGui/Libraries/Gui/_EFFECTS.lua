local GuiEffects 	 = {}

-- Services
local Players        = game:GetService("Players")
local Rand			 = Random.new()
local RepStorage	 = game:GetService("ReplicatedStorage")
local RunService	 = game:GetService("RunService")

-- Player stuff
local Player 		 = Players.LocalPlayer
local PlayerGui		 = Player.PlayerGui

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame  = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- Vars and consts
local EffectObjs	 = {
	
	["Buffer"]		 = {
		
		["Objs"]	 = {},
		["Func"]	 = function(item, dt)
			local OrigX = item:FindFirstChild("OrigX")
			local OrigColor = item:FindFirstChild("OrigColor")
			
			if not OrigX then
				OrigX = Instance.new("NumberValue")
				OrigX.Name = "OrigX"
				OrigX.Value = item.Position.X.Scale
				OrigX.Parent = item
			end
			
			if not OrigColor then
				OrigColor = Instance.new("Color3Value")
				OrigColor.Name = "OrigColor"
				OrigColor.Value = item.TextColor3
				OrigColor.Parent = item
			end
			
			local doBuffer = Rand:NextNumber(0, 1) < LerpByFrame(0.015, dt)
			item.Position = UDim2.fromScale(OrigX.Value, item.Position.Y.Scale)
			
			if doBuffer == true then
				item.Position += UDim2.fromScale(Rand:NextNumber(-0.25, 0.25), 0)
				item.TextColor3 = Color3.fromRGB(Rand:NextNumber(0, 255), Rand:NextNumber(0, 255), Rand:NextNumber(0, 255))
			else
				item.Position += UDim2.fromScale(Rand:NextNumber(-0.001, 0.001), 0)
				item.TextColor3 = OrigColor.Value
			end
		end,
		
	},
	
	["BufferV"]		 = {
		
		["Objs"]	 = {},
		["Func"]	 = function(item, dt)
			local OrigY = item:FindFirstChild("OrigY")

			if not OrigY then
				OrigY = Instance.new("NumberValue")
				OrigY.Name = "OrigY"
				OrigY.Value = item.Position.Y.Scale
				OrigY.Parent = item
			end
			
			if item:FindFirstChild("_effect", true) then
				item._effect:SetAttribute("Val", Lerp(item._effect:GetAttribute("Val"), 0, LerpByFrame(0.2, dt)))
				item.Position = UDim2.fromScale(item.Position.X.Scale, OrigY.Value)
				item.Position += UDim2.fromScale(0, Rand:NextNumber(-item._effect:GetAttribute("Val") * 0.5, item._effect:GetAttribute("Val")) * 0.75)
			end
		end,
		
	}
	
}

local function compilePart(part)
	local Effect = part:FindFirstChild("_effect")
	if Effect then
		if not table.find(EffectObjs[Effect.Value]["Objs"], part) then
			table.insert(EffectObjs[Effect.Value]["Objs"], part)
		end
	else
		for _, tbl in pairs(EffectObjs) do
			if table.find(tbl["Objs"], part) then
				table.remove(tbl["Objs"], part)
			end
		end
	end
end

-- Creates buffer
function GuiEffects:CreateBuffer(part : BasePlayerGui, intensity : number)
    local BufferV1 = Instance.new("StringValue")
    BufferV1.Name = "_effect"
    BufferV1.Value = "BufferV"
    BufferV1:SetAttribute("Val", intensity)
    BufferV1.Parent = part
end

-- Main function
function GuiEffects.Function()
	-- Compiled objects
	for _, part in pairs(PlayerGui:GetDescendants()) do
		compilePart(part)
	end
	
	PlayerGui.DescendantAdded:Connect(function(part)
		if not part:IsA("StringValue") then
			compilePart(part)
		else
			compilePart(part.Parent)
		end
	end)
	
	RunService.RenderStepped:Connect(function(dt)
		for _, tbl in pairs(EffectObjs) do
			for _, obj in pairs(tbl["Objs"]) do
				tbl["Func"](obj, dt)
			end
		end
	end)
end

return GuiEffects