local Bullets             = {}

-- Services
local Debris              = game:GetService("Debris")
local Players             = game:GetService("Players")
local Rand                = Random.new()
local RepStorage          = game:GetService("ReplicatedStorage")

local GunService          = _G.Knit.GetService("GunService")

-- Player
local Player              = Players.LocalPlayer
local PlayerGui           = Player.PlayerGui
local Character           = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local BulletTemps         = RepStorage.VFX.Bullets
local Camera              = game.Workspace.CurrentCamera

local BulletInfo          = require(RepStorage.Modules.Data.BulletInfo)
local FastCast            = require(RepStorage.Modules.Environment.FastCastRedux)
local PlaySound           = require(RepStorage.Modules.Util.PlaySound)

local VFXFolder           = RepStorage.VFX
local VFX                 = require(PlayerGui.Libraries.Environment.VFX)

local Caster              = FastCast.new()

local HitDetection        = require(RepStorage.Remotes.HitDetection):Client()

local Projectiles         = game.Workspace:FindFirstChild("Projectiles")
if not Projectiles then
    Projectiles = Instance.new("Folder")
    Projectiles.Name = "Projectiles"
    Projectiles.Parent = game.Workspace
end

-- Vars and consts
local BulletCount 	      = 0
local MAX_BULLET_DIST     = 10000 -- will store this in a better way sometime in the future

-- [[ funcs ]] --

-- Creates bullet
local function createBullet(shooter : Model, origin : Vector3, ammotype : string, gunname : string, tier : number, shotcount : number | string, tool : Tool | Model, skipEffects : boolean?) : Part
    local Bullet = (BulletTemps:FindFirstChild(ammotype) or BulletTemps.Bullet):Clone()
    Bullet.Name = shooter:GetAttribute("ID").."_"..shotcount
	BulletCount += 1

    local VM = game.Workspace.CurrentCamera:FindFirstChild("Viewmodel")
    local Barrel = shooter:FindFirstChild("_barrel", true) or ((shooter == Character and VM ~= nil) and VM:FindFirstChild("_barrel", true) or nil)

    -- Light effects
    local Suppressor = tool:FindFirstChild("_suppressor", true)

    if Suppressor then
        Barrel = Suppressor:FindFirstChild("_barrel", true)
    end

    -- Extra pellets from one trigger pull (ShotsPerFire) skip the sound, flash and
    -- casing so a multi-shot gun only produces them once per shot
    if not skipEffects then
        local FireSound = tool.Handle:FindFirstChild(string.format("Fire%s", Suppressor ~= nil and "Quiet" or ""))
        PlaySound(FireSound.SoundId, "Fire", Camera, nil, 1, Rand:NextNumber(0.95, 1.05))

        -- Effects
        task.spawn(function()
            local MuzzleFlash = VFXFolder.MuzzleFlashes:FindFirstChild(not Suppressor and "MuzzleFlash" or "MuzzleFlashSUP"):Clone()
            MuzzleFlash.Parent = Barrel

            local SpotLight = Instance.new("SpotLight", Barrel)
            SpotLight.Color = Color3.fromRGB(255, 222, 176)
            SpotLight.Angle = 90
            SpotLight.Range = not Suppressor and 48 or 12
            SpotLight.Brightness = not Suppressor and 1 or 0.75
            SpotLight.Face = "Back"

            MuzzleFlash:Emit()
            SpotLight.Enabled = true
            game:GetService("Debris"):AddItem(SpotLight, 0.05)
            game:GetService("Debris"):AddItem(MuzzleFlash, 0.25)
        end)

        -- Guns that unload their chamber at reload don't eject casings per shot;
        -- the spent casings are ejected at reload instead (see ejectCasings)
        local ItemConfig = tool:FindFirstChild("Configuration")
        local ItemInfo = ItemConfig and require(ItemConfig.ItemInfo)
        if not (ItemInfo and ItemInfo.unloadChamberAtReload) then
            VFX.Play("BulletCasings", "Casing", Camera.CFrame, shooter, ammotype)
        end
    end

    Bullet:SetAttribute("ShooterID", shooter:GetAttribute("ID"))
    Bullet:SetAttribute("Origin", Barrel ~= nil and Barrel.CFrame.Position or origin)
    Bullet:SetAttribute("Gun", gunname)
    Bullet:SetAttribute("Tier", tier)
    Bullet:SetAttribute("BarrelToPelletLerp", Barrel and 0 or 1)
    Bullet:SetAttribute("BulletID", Bullet.Name)

    Bullet.Transparency = 1
	Bullet.Trail.Transparency = NumberSequence.new(1, 1)

    return Bullet
end

-- Fires bullet
function Bullets.fireBullet(shooter : Model, origin : Vector3, direction : Vector3, ammotype : string, gunname : string, tier : number, angle : number, shotcount : number | string, tool : Tool | Model, skipEffects : boolean?) : ()
    -- Bullet information
    local CastParams = RaycastParams.new()
    CastParams.FilterType = Enum.RaycastFilterType.Exclude

    local Filter = {Camera, shooter}
    local Corpses = game.Workspace:FindFirstChild("Corpses")
    if Corpses then
        table.insert(Filter, Corpses)
    end
    CastParams.FilterDescendantsInstances = Filter

    local BulletTemplate = createBullet(shooter, origin, ammotype, gunname, tier, shotcount, tool, skipEffects)

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.Acceleration = Vector3.new(0, -game.Workspace.Gravity * BulletInfo[ammotype].Weight, 0)
    CastBehavior.AutoIgnoreContainer = false
    CastBehavior.CosmeticBulletContainer = Projectiles
    CastBehavior.CosmeticBulletTemplate = BulletTemplate
    CastBehavior.MaxDistance = MAX_BULLET_DIST
    CastBehavior.RaycastParams = CastParams

    -- Calculates direction
    local Origin, Direction = origin, direction * MAX_BULLET_DIST

    local Result = game.Workspace:Raycast(Origin, Direction, CastParams)
    Result = Result or Origin + Direction
    local HitPos = typeof(Result) == "Vector3" and Result or Result.Position
    Result = (Origin - HitPos).Unit

    local DirectionCF = CFrame.new(Vector3.new(), Result)
    local SpreadDirection = CFrame.fromOrientation(0, 0, math.random(0, math.pi * 2))
    local SpreadAngle = CFrame.fromOrientation(math.rad(angle), 0, 0)
    local FinalDirection = (DirectionCF * SpreadDirection * SpreadAngle)

    Caster:Fire(Origin, -FinalDirection.LookVector, BulletInfo[ammotype].Speed, CastBehavior)
end

-- Ejects spent casings for guns that unload their chamber at reload
function Bullets.ejectCasings(shooter : Model, ammotype : string, count : number) : ()
    task.spawn(function()
        for _ = 1, count do
            VFX.Play("BulletCasings", "Casing", Camera.CFrame, shooter, ammotype)
            task.wait(0.05)
        end
    end)
end

-- Main function
function Bullets.Function()
    -- Caster physics
    Caster.LengthChanged:Connect(function(cast, lastpoint, direction, displacement, segvel, pellet)
        local Vector = pellet:GetAttribute("Origin"):Lerp(lastpoint + (direction * displacement), pellet:GetAttribute("BarrelToPelletLerp"))
        pellet.CFrame = CFrame.lookAt(Vector, lastpoint) * CFrame.Angles(0, math.rad(90), 0)
        pellet:SetAttribute("BarrelToPelletLerp", math.min(pellet:GetAttribute("BarrelToPelletLerp") + 1/4, 1))

        if (pellet:GetAttribute("Origin") - pellet.CFrame.Position).Magnitude > 5 then
            pellet.Transparency = 0
	        pellet.Trail.Transparency = NumberSequence.new(0, 1)
        end
    end)

    Caster.RayHit:Connect(function(cast, result, segvel, pellet)
        if pellet then
            pellet.Transparency = 1
            pellet.Trail.Transparency = NumberSequence.new(1, 1)
            Debris:AddItem(pellet, Rand:NextNumber(3, 15))
        end

        if Character and Character:GetAttribute("ID") == pellet:GetAttribute("ShooterID") then -- only perform hit detection on own bullets
            local Hit = result.Instance
            local Hitbox = Hit:FindFirstAncestor("Hitbox")

            HitDetection:Fire({
                BulletID = pellet:GetAttribute("BulletID"),
                HitInstance = Hit,
                HitCharacter = Hitbox and Hitbox.Parent or nil,
                Position = result.Position,
                Normal = result.Normal
            })
        end
    end)

    -- On bullet shoot
    GunService.BulletShot:Connect(function(bn : {})
        if bn.Shooter ~= Character then
            Bullets.fireBullet(bn.Shooter, bn.Origin, bn.Direction, bn.AmmoType, bn.Gun, bn.Tier, bn.Angle, bn.ShotCount, bn.Tool, bn.SkipEffects)
        end
    end)
end

return Bullets