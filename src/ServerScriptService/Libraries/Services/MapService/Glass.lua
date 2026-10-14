local Glass		   = {}

-- Services
local Debris	   = game:GetService("Debris")
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lerp		   = require(RepStorage.Modules.Util.Math.Lerp)
local PlaySound	   = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local Wedge = Instance.new("WedgePart")
Wedge.Anchored = true
Wedge.TopSurface = Enum.SurfaceType.Smooth
Wedge.BottomSurface = Enum.SurfaceType.Smooth

local GlassShatter = Instance.new("ParticleEmitter")
GlassShatter.Name = "GlassShatter"
GlassShatter.Lifetime = NumberRange.new(0.25, 1)
GlassShatter.Speed = NumberRange.new(5, 15)
GlassShatter.SpreadAngle = Vector2.new(180, 180)
GlassShatter.Acceleration = Vector3.new(0, -game.Workspace.Gravity, 0)
GlassShatter.Size = NumberSequence.new(0.25, 0)

-- Draws 3D triangle (math taken from a tutorial by @Kriko_YT)
local function draw3dTriangle(a, b, c, parent, w1, w2)
	-- Math
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)

	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end

	local Right = ac:Cross(ab).Unit
	local Up = bc:Cross(Right).Unit
	local Back = bc.Unit

	local Height = math.abs(ab:Dot(Up))

	-- Draws wedge
	w1 = w1 or Wedge:Clone()
	w1.Size = Vector3.new(0, Height, math.abs(ab:Dot(Back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, Right, Up, Back)
	w1.Parent = parent

	w2 = w2 or Wedge:Clone()
	w2.Size = Vector3.new(0, Height, math.abs(ab:Dot(Back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -Right, Up, -Back)
	w2.Parent = parent

	return w1, w2
end

local function Break(part, center)
	local CS, CF = part.Size, part.CFrame

	local Points = {
		CF * CFrame.new(CS.X * .5, CS.Y * .5, 0),
		CF * CFrame.new(0, CS.Y * .5, 0),
		CF * CFrame.new(-CS.X * .5, CS.Y * .5, 0),
		CF * CFrame.new(-CS.X * .5, 0, 0),
		CF * CFrame.new(-CS.X * .5, -CS.Y * .5, 0),
		CF * CFrame.new(0, -CS.Y * .5, 0),
		CF * CFrame.new(CS.X * .5, -CS.Y * .5, 0),
		CF * CFrame.new(CS.X * .5, 0, 0)
	}

	-- Clears all children
	for _, p in pairs(part:GetChildren()) do
		task.spawn(function()
			if p:IsA("Light") then
				p.Brightness *= 10
				p.Range *= 4
				TweenService:Create(p, TweenInfo.new(0.125, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Brightness = 0}):Play()
				task.wait(0.125)
			end

			p:Destroy()
		end)
	end

	if part.Name ~= "_light" then
		part:Destroy()
	else
		part.Color = Color3.fromRGB(25, 35, 49)
	end

	for i, v in pairs(Points) do
		local Next = Points[i + 1]
		if not Next then
			Next = Points[1]
		end
		local W0, W1 = draw3dTriangle(v.p, Next.p, center, game.Workspace)
		W0.Anchored = false
		W1.Anchored = false

		W0.Transparency = part.Transparency
		W1.Transparency = part.Transparency

		W0.Color = part.Color
		W1.Color = part.Color

		W0.Material = part.Material
		W1.Material = part.Material

		-- Determines size of shard
		local SmallestSize = math.huge
		local Sizes = {part.Size.X, part.Size.Y, part.Size.Z}

		for _, s in pairs(Sizes) do
			if SmallestSize >= s then
				SmallestSize = s
			end
		end

		if part.Name ~= "_light" then
			part.Size = Vector3.new(SmallestSize, part.Size.Y, part.Size.Z)
		end

		local Parts = {W0, W1}
		for _, p in pairs(Parts) do
			local NewShatter = GlassShatter:Clone()
			NewShatter.Color = ColorSequence.new(part.Color)
			NewShatter.Parent = p
			task.defer(function()
				NewShatter.Enabled = true
				task.wait(1)
				NewShatter.Enabled = false
			end)
			Debris:AddItem(p, math.random(30, 120))
		end
	end
end

-----------------------------------

-- Main function
function Glass.Init(map)
	local LargestSize = -math.huge
	for _, part in pairs(map.Interactables.Glass:GetChildren()) do
		part.CollisionGroup = "Glass"

		-- Calculates size to use for sound/shattering
		if part:IsA("Part") then
			if part.Shape ~= Enum.PartType.Cylinder and part.Size.Z > part.Size.X then
				part.Size = Vector3.new(part.Size.Z, part.Size.Y, part.Size.X)
				part.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
			end
		end

		local Durability = Instance.new("NumberValue", part)
		Durability.Name = "Durability"
		Durability.Value = part.Size.Magnitude * 1.125

		if part.Size.Magnitude > LargestSize then
			LargestSize = part.Size.Magnitude
		end

		local StartingDurability = Durability.Value

		local Textures = {}
		local TextureOrder = {"Front", "Back", "Left", "Right", "Top", "Bottom"}

		for i = 1, 6 do
			local NewTexture = Instance.new("Texture", part)
			NewTexture.Face = TextureOrder[i]
			NewTexture.Texture = "http://www.roblox.com/asset/?id=1140807156"
			NewTexture.Color3 = Color3.fromRGB(0, 0, 0)
			NewTexture.Transparency = 1
			NewTexture.StudsPerTileU = 16
			NewTexture.StudsPerTileV = 16

			table.insert(Textures, NewTexture)
		end

		Durability.Changed:Connect(function(new)
			PlaySound(7140152893, "GlassCrack", part, nil, 1, Lerp(0.8, 1.2, new / StartingDurability))

			for _, texture in pairs(Textures) do
				texture.Transparency = math.clamp(new, 0, StartingDurability) / StartingDurability

				if new <= 0 then
					texture:Destroy()
				end
			end

			if new <= 0 then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Material = Enum.Material.Glass

				-- Effects + damage
				local DamagePart = Instance.new("Part")
				DamagePart.Size = part.Size * 1.25
				DamagePart.Transparency = 1
				DamagePart.CanCollide = false
				DamagePart.CanQuery = false
				DamagePart.Anchored = true
				DamagePart.Parent = game.Workspace
				DamagePart.CFrame = part.CFrame

				PlaySound(6737582037, "GlassShatter", nil, DamagePart.Position, 1, Lerp(1.2, 0.8, part.Size.Magnitude / LargestSize))

				local OpParams = OverlapParams.new()
				OpParams.FilterDescendantsInstances = {}
				OpParams.FilterType = Enum.RaycastFilterType.Exclude

				local HurtEntities = {}
				DamagePart.Touched:Connect(function(otherpart)
					local TouchingParts = game.Workspace:GetPartBoundsInBox(DamagePart.CFrame, DamagePart.Size * 1.25, OpParams)

					for _, p in pairs(TouchingParts) do
						local HitboxFolder = p:FindFirstAncestor("Hitbox")
						local HurtChar = HitboxFolder and HitboxFolder.Parent

						if HurtChar and not table.find(HurtEntities, HurtChar) then
							table.insert(HurtEntities, HurtChar)
							_G.Knit.GetService("CombatService"):Damage(nil, HurtChar, math.random(5, 8), "GLASS", "DEFAULT", true, p)
						end
					end
				end)

				-------------------

				Break(part, part.Position)

				-------------------

				task.wait(10)

				DamagePart:Destroy()
			end
		end)
	end
end

return Glass
