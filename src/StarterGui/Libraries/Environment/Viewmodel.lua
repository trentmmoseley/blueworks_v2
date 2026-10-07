local Viewmodel      = {}

-- Services
local CAS            = game:GetService("ContextActionService")
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local UIS            = game:GetService("UserInputService")

local DataController = _G.Knit.GetController("DataController")
local GunService     = _G.Knit.GetService("GunService")
local InvService     = _G.Knit.GetService("InventoryService")
local MmtService     = _G.Knit.GetService("MovementService")

-- Player
local Player         = Players.LocalPlayer
local PlayerGui      = Player:WaitForChild("PlayerGui")
local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")

local MobileButtons  = PlayerGui:WaitForChild("MobileButtons")

-- Modules and objects
local ItemDisplays   = RepStorage:WaitForChild("ItemDisplays")
local PlayerObjs     = RepStorage.PlayerRep
local VMTemp         = PlayerObjs.Viewmodel

local TheVM          : Model = nil
local Camera         = game.Workspace.CurrentCamera

local BulletEnv      = require(PlayerGui.Libraries.Environment.Guns.Bullets)
local BulletSpread   = require(RepStorage.Modules.Util.BulletSpread)
local GunAttach      = require(RepStorage.Modules.Util.GunAttach)
local Lerp           = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)
local MMT_SETTINGS   = require(RepStorage.Modules.Data.MovementSettings)
local PlaySound      = require(RepStorage.Modules.Util.PlaySound)
local Spring	     = require(RepStorage.Modules.Util.Spring)
local ShapecastHBX   = require(RepStorage.Modules.ShapecastHitbox)
local WeldPiece      = require(RepStorage.Modules.Util.WeldPiece)

local GunRequest     = require(RepStorage.Remotes.GunRequest):Client()
local MeleeRequest   = require(RepStorage.Remotes.MeleeRequest):Client()
local PunchRequest   = require(RepStorage.Remotes.PunchRequest):Client()
local VMAnim         = require(RepStorage.Remotes.VMAnim):Client()

local DisplayingTool : Model = nil
local TrackingTool   : Tool? = nil

_G.CurrentI2         = nil

-- Vars and consts
local MAX_SURF_DIFF  = 3
local TWSCF			 = CFrame.new(0, 0, 0) -- to-world-space cframe

local EquipDiff		 = 0
local GunshotDiff	 = 0
local PointAimLerp   = 0
local RunDepth		 = 0
local SurfaceDiff	 = 0

local MAX_TUR_ANGLE  = 15
local TurnAngle	     = 0
local ThisAimAlpha	 = 0

local NextGunFire    = 0

local HoldAnimID	 = "rbxassetid://12771499807"
local HoldAnim		 = nil

local ReloadAnimID   = "rbxassetid://12971051248"
local ReloadAnim     = nil

local FireAnim       = nil

local EquipAnim      = nil

local firingGun        = false
local gunDetected	   = false
local isPointAiming    = false
local jumpChanged	   = false
local usingMelee       = false

local LastLeanVal	   = nil
local prevGunDetected  = false

local NextPunch        = 0

local Anims          = {
    ["IDLE"] 	     = {
        ["ID"]       = "rbxassetid://12380928169",
        ["isMoving"] = false,
        ["inAir"]    = false,
        ["Looped"]   = true,
        ["Speed"]    = 1,
        ["Priority"] = Enum.AnimationPriority.Core
    },
    ["RUN"] 	     = {
        ["ID"]       = "rbxassetid://128388099366231",
        ["MmtType"]  = "RUN",
        ["isMoving"] = true,
        ["inAir"]    = false,
        ["Looped"]   = true,
        ["Speed"]    = 1,
        ["Priority"] = Enum.AnimationPriority.Movement
    },
    ["CROUCH"] 	     = {
        ["ID"]       = "rbxassetid://12381062018",
        ["MmtType"]  = "CROUCH",
        ["inAir"]    = false,
        ["Looped"]   = true,
        ["Speed"]    = 1,
        ["Priority"] = Enum.AnimationPriority.Idle
    },
    ["CRAWL"] 	     = {
        ["ID"]       = "rbxassetid://107972911018988",
        ["MmtType"]  = "CRAWL",
        ["inAir"]    = false,
        ["Looped"]   = true,
        ["Speed"]    = 1/2,
        ["Priority"] = Enum.AnimationPriority.Idle,
        ["freezeOnIdle"] = true,
    },
    ["FALL"] 	     = {
        ["ID"]       = "rbxassetid://121223757535009",
        ["inAir"]    = true,
        ["Looped"]   = true,
        ["Speed"]    = 1,
        ["Priority"] = Enum.AnimationPriority.Idle,
        ["freezeOnIdle"] = true,
    },
}

local PUNCH_ANIMS    = {
    "rbxassetid://12785206668",
	"rbxassetid://12785245195",
}

local CoreVMAnims	 = {}
local VMAnimTracks	 = {} -- Tracks started via the VMAnim remote, keyed by animation ID
local PunchTracks    = {}

local LEAN_LEFT_KEYBOARD, LEAN_RIGHT_KEYBOARD
local LEAN_LEFT_GAMEPAD, LEAN_RIGHT_GAMEPAD
local POINT_AIM_GAMEPAD, POINT_AIM_KEYBOARD
local RELOAD_GAMEPAD, RELOAD_KEYBOARD

local MeleeHitbox                   = nil
local PunchHitboxes                 = {}

local PUNCH_ANIMS_CHAR              = {
    12785295196,
    12785291593
}

-- [[ funcs ]] --

-- Leaning
local function toggleLean(actionname, inputstate)
	local ValName = string.format("lean%s", string.sub(actionname, 5))
    local leanInit = inputstate == Enum.UserInputState.Begin
    LastLeanVal = leanInit and string.sub(string.gsub(ValName, "lean", ""), 1, 1) or nil
	MmtService.LeanUpdate:Fire(leanInit, LastLeanVal)
end

-- Toggles point aim
local function togglePointAim(actionname, inputstate)
	if actionname == "PointAimTog" and inputstate == Enum.UserInputState.Begin then
		isPointAiming = not isPointAiming
	end
end

-- Clears viewmodel
local function clearViewmodel(toolclass)
    if DisplayingTool and DisplayingTool.Parent then
        DisplayingTool:Destroy()
        DisplayingTool = nil
    end

    TheVM["Right Arm"].ItemPart:ClearAllChildren()

    if HoldAnim then
        HoldAnim:Stop()
    end
    HoldAnim = nil

    if ReloadAnim then
        ReloadAnim:Stop()
    end
    ReloadAnim = nil

    if FireAnim then
        FireAnim:Stop()
    end
    FireAnim = nil

    if EquipAnim then
        EquipAnim:Stop()
    end
    EquipAnim = nil

    TrackingTool = nil
    gunDetected = false

    -- Clears the stored item info so clicks route back to punch() while
    -- unarmed; guarded by name in case a swap already replaced it with the
    -- newly equipped item's info
    if _G.CurrentI2 and toolclass and _G.CurrentI2.Name == toolclass.Name then
        _G.CurrentI2 = nil
    end
end

-- Fires gun
local function fireGun(recoil)
    if os.clock() >= NextGunFire then
        NextGunFire = os.clock() + _G.CurrentI2.FireRate
        local isAiming = Character:GetAttribute("isAiming")
        local Barrel = DisplayingTool.Handle._attachments._barrel

        -- Stops firing if not full-auto
        if _G.CurrentI2.FireType == 2 then
            firingGun = false
        end

        -- Guns with repeatReloadTillFull can be fired mid-reload, interrupting it
        if TrackingTool:GetAttribute("Ammo") > 0 and (not Character:GetAttribute("isReloading") or _G.CurrentI2.repeatReloadTillFull == true) then
            -- Loads/plays fire animation
            if not FireAnim then
                FireAnim = TheVM.Animator:LoadAnimation(DisplayingTool.Configuration.Anims.VM.Fire)
                FireAnim.Priority = Enum.AnimationPriority.Action4
            end

            local NewRecoil = Vector3.new(_G.CurrentI2.CamRecoil, Rand:NextNumber(-1, 1) / 2, 3)
            if isAiming == true then
                NewRecoil = NewRecoil:Lerp(Vector3.zero, 0.5) * Lerp(1, 1 - _G.CurrentI2.RecoilAimDampen or 1, ThisAimAlpha)
            end
            recoil:shove(NewRecoil)
            GunshotDiff = _G.CurrentI2.Recoil / (isAiming == false and 1 or 3)
            FireAnim:Play()

            local BuilletNumber = math.round(Rand:NextNumber(0, 1) * 10 ^ 7)
            local Position = UIS:GetMouseLocation()
            local TheRay = Player:GetAttribute("Device") == "Desktop" and Camera:ViewportPointToRay(Position.X, Position.Y) or Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local Angle = BulletSpread(_G.CurrentI2, Character:GetAttribute("MovementType"), Character:GetAttribute("isAiming"), Character:GetAttribute("isLeaning"))
            GunRequest:Fire("FIRE", TheRay.Origin, TheRay.Direction, Angle, BuilletNumber)

            -- Fires one bullet per ShotsPerFire (defaults to 1), each with its own
            -- spread angle; extra pellets skip the fire sound/flash/casing
            local ShotsPerFire = _G.CurrentI2.ShotsPerFire or 1
            for i = 1, ShotsPerFire do
                local PelletAngle = Rand:NextNumber(-Angle, Angle)
                BulletEnv.fireBullet(Character, TheRay.Origin, TheRay.Direction, _G.CurrentI2.AmmoType, _G.CurrentI2.Name, _G.CurrentI2.Tier, PelletAngle, `{BuilletNumber}_{i}`, DisplayingTool, i > 1)
            end
        else
            recoil:shove(Vector3.new(0, 0, -1))
            PlaySound(PlayerGui.Sounds.Guns.NoAmmo.SoundId, "NoAmmo", Camera, nil, 1, Rand:NextNumber(0.95, 1.05))
        end
    end
end

-- On melee hit
local function onMeleeHit(rayres : RaycastResult?)
    MeleeRequest:Fire(rayres.Instance)
    
    if MeleeHitbox and rayres.Instance:FindFirstAncestor("Hitbox") then
        MeleeHitbox:Destroy()
        MeleeHitbox = nil
    end
end

-- Uses melee weapon
local function meleeWeapon()
    -- DisplayingTool can be nil here: _G.CurrentI2 is set before the display
    -- model finishes equipping
    if not usingMelee and DisplayingTool then
        usingMelee = true

        -- Plays a random attack animation
        local Attacks = DisplayingTool.Configuration.Anims.VM.Attacks:GetChildren()
        if #Attacks > 0 then
            local AttackAnim = TheVM.Animator:LoadAnimation(Attacks[Rand:NextInteger(1, #Attacks)])
            AttackAnim.Priority = Enum.AnimationPriority.Action4
            AttackAnim:Play()
        end

        if MeleeHitbox then
            MeleeHitbox:Destroy()
        end

        -- Creates hitbox
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {Character, TheVM, Camera, DisplayingTool}

        MeleeHitbox = ShapecastHBX.new(DisplayingTool.Handle.Parts.DamagePart, RayParams)
        MeleeHitbox:HitStart(_G.CurrentI2.Opportunity):OnHit(onMeleeHit):OnStopped(function(cleanCallbacks)
            cleanCallbacks()
            if not MeleeHitbox then return end
            MeleeHitbox:Destroy()
            MeleeHitbox = nil
        end)

        task.wait(_G.CurrentI2.Debounce)
        usingMelee = false
    end
end

-- Punching
local function onPunchHit(rayres : RaycastResult?)
    PunchRequest:Fire(rayres.Instance)
end

local function punch()
    if Character:GetAttribute("isDowned") == true then return end
    local ChosenAnim = PunchTracks[math.random(1, #PunchTracks)]
    ChosenAnim:Play()
    PlaySound(121616358851209, "Swing", Camera, nil, 1, Rand:NextNumber(0.95, 1.05))

    -- Creates hitboxes
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Character, TheVM, Camera}

    local ChosenAnimID = PUNCH_ANIMS_CHAR[math.random(1, #PUNCH_ANIMS_CHAR)]

    local Anim = Instance.new("Animation")
    Anim.AnimationId = string.format("rbxassetid://%i", ChosenAnimID)

    local LoadedAnim = Humanoid.Animator:LoadAnimation(Anim)
    LoadedAnim:Play()

    for _, side in {"Right", "Left"} do
        local DamagePart = TheVM[side .. " Arm"]:FindFirstChild("DamagePart", true)
        if not DamagePart then continue end

        if PunchHitboxes[side] then
            PunchHitboxes[side]:Destroy()
            PunchHitboxes[side] = nil
        end

        local Hitbox = ShapecastHBX.new(DamagePart, RayParams)
        PunchHitboxes[side] = Hitbox
        Hitbox:HitStart(1):OnHit(onPunchHit):OnStopped(function(cleanCallbacks)
            cleanCallbacks()
            if PunchHitboxes[side] ~= Hitbox then return end
            PunchHitboxes[side] = nil
            Hitbox:Destroy()
        end)
    end
end

-- Stops any in-progress punch animations (viewmodel + character) with no fade
local function stopPunchAnims()
    for _, Track in PunchTracks do
        Track:Stop(0)
    end

    for _, Track in Humanoid.Animator:GetPlayingAnimationTracks() do
        local AnimId = Track.Animation and Track.Animation.AnimationId or ""
        local NumId = tonumber(string.match(AnimId, "%d+"))
        if NumId and table.find(PUNCH_ANIMS_CHAR, NumId) then
            Track:Stop(0)
        end
    end
end

-- Determines if anim is playing
local function animPlaying(id : string)
    local MovementType = Character:GetAttribute("MovementType")
    local ANIM_INFO = Anims[id]
    
    if ANIM_INFO["isMoving"] and ANIM_INFO["isMoving"] ~= Character:GetAttribute("isMoving") then
		return false, "Character moving"
	end

    if ANIM_INFO["MmtType"] and ANIM_INFO["MmtType"] ~= MovementType then
		return false, "Wrong movement type"
	end

    if ANIM_INFO["inAir"] ~= nil and ANIM_INFO["inAir"] ~= Character:GetAttribute("inAir") then
		return false, "Character not in air"
	end

    if string.find(id, "IDLE") and MovementType == "CROUCH" then
		return false, "Character crouching"
	end

    return true
end

-- Gets bobbing
local function getBobbing(addition)
	return math.sin(os.clock() * addition * 1.3) / 2
end

-- Frame-based update
local function update(dt : number, sway, bobble, recoil) : ()
    if not (Character and Character.Parent) then return end

    -- Vars and consts
    local inAir = Character:GetAttribute("inAir")
    local isMoving = Character:GetAttribute("rawInputDetected")
    local MovementType = Character:GetAttribute("MovementType")
    local MovementAmplitude = (MMT_SETTINGS[MovementType].Speed / 12)
    local QuarterLerp = LerpByFrame(1/4, dt) 

    ThisAimAlpha = Lerp(ThisAimAlpha, (Character:GetAttribute("isAiming") and Character:GetAttribute("isReloading") ~= true) and 1 or 0, QuarterLerp / 2.25 * (_G.CurrentI2 and _G.CurrentI2.LerpSpeed or 1))
    RunDepth = Lerp(RunDepth, (MovementType == "RUN" and isMoving) and -0.75 or 0, QuarterLerp * 0.275)
    EquipDiff = Lerp(EquipDiff, 0, QuarterLerp)
    PointAimLerp = Lerp(PointAimLerp, isPointAiming and 1 or 0, QuarterLerp * (2/3))

    -- Updates VM position
    TheVM:PivotTo(Camera.CFrame * (_G.CurrentI2 and (_G.CurrentI2.VMHoldMod or CFrame.new(0, 0, 0)) or CFrame.new(0, 0, 0)) * CFrame.new(0, TrigWave("sin", 0.05, 5, os.clock(), 0, 0) * (1 - ThisAimAlpha) - 0.8 + RunDepth - (EquipDiff * 2), (EquipDiff * 5)) + (Camera.CFrame.LookVector * 0.75))
    TheVM.Parent = (Player.CameraMode == Enum.CameraMode.LockFirstPerson and Character:GetAttribute("beingBrainwashed") ~= true) and Camera or RepStorage
    
    if MovementType == "CRAWL" then
        local CamCF = Camera.CFrame
        local _, yaw, _ = CamCF:ToEulerAnglesYXZ()
        local FlatCF = CFrame.new(CamCF.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
        -- Blend back to the normal camera-following pivot as the player aims,
        -- so aiming down sights while crawling locks on instead of clipping into the camera
        TheVM:PivotTo(FlatCF:Lerp(TheVM:GetPivot(), ThisAimAlpha))
    end

     -- Bobble
	local Bobble = Vector3.new(getBobbing(10 * MovementAmplitude), getBobbing(5 * MovementAmplitude), getBobbing(5 * MovementAmplitude)) * Vector3.new((1 - ThisAimAlpha), (1 - ThisAimAlpha), (1 - ThisAimAlpha))
	bobble:shove(Bobble / 10 * MMT_SETTINGS[MovementType].Speed / 12)
	local UpdatedBobSpring = bobble:update(dt)

	if isMoving and not inAir and Humanoid:GetState() ~= Enum.HumanoidStateType.Climbing and MovementType ~= "SLIDE" then
		TWSCF = TWSCF:Lerp(CFrame.new(UpdatedBobSpring.Y, UpdatedBobSpring.X, 0), QuarterLerp / 2)
	else
		TWSCF = TWSCF:Lerp(CFrame.new(0, 0, 0), QuarterLerp / 2)
	end
	
	TheVM.PrimaryPart.CFrame = TheVM.PrimaryPart.CFrame:ToWorldSpace(TWSCF)

    -- Sway
    local SwayLerp = 1

    local MouseDelta = game:GetService("UserInputService"):GetMouseDelta() * (MovementType == "RUN" and 3 or 1)
	sway:shove(Vector3.new(-MouseDelta.X / 100, MouseDelta.Y / 100 - (jumpChanged and 3 or 0), 0))
	local UpdatedSway = sway:update(dt) * (1 - ThisAimAlpha)
	TheVM.HumanoidRootPart.CFrame *= CFrame.new(UpdatedSway.X * SwayLerp, UpdatedSway.Y * SwayLerp, 0)

    -- Pushes viewmodel back if too close to surface
    local SmallestDist = math.huge
    for _, part in {TheVM, TheVM:FindFirstChild("ItemPart", true), Camera} do
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {Camera, Character, TheVM, DisplayingTool}

        local UsedPart = part:FindFirstChild("_barrel", true) or (part:IsA("Model") and part.PrimaryPart or part)
        -- Cast origin is pulled back past the sphere's radius: a shapecast ignores
        -- surfaces it starts inside of, so casting from the part itself misses any
        -- surface the camera/part has already clipped into
        local CastOrigin = UsedPart.CFrame.Position - UsedPart.CFrame.LookVector * (MAX_SURF_DIFF + 1)
        local Raycast = game.Workspace:Spherecast(CastOrigin, 1, UsedPart.CFrame.LookVector * (MAX_SURF_DIFF * 2 + 1), RayParams)
        local Distance = MAX_SURF_DIFF

        if Raycast and (not Raycast.Instance:IsA("Part") or Raycast.Instance.Transparency < 1) then
            SmallestDist = math.clamp((Raycast.Position - UsedPart.CFrame.Position).Magnitude, 0.25, MAX_SURF_DIFF)
            break
        end

        if SmallestDist > Distance then
            SmallestDist = Distance
        end
    end

    -- While running, the viewmodel is never pushed back from surfaces
    local SurfaceTarget = (MovementType == "RUN" and isMoving) and 0 or MAX_SURF_DIFF - (SmallestDist + 1/4)
    SurfaceDiff = Lerp(SurfaceDiff, SurfaceTarget, LerpByFrame(1/4, dt))
	TheVM.PrimaryPart.CFrame += TheVM.PrimaryPart.CFrame.LookVector * -(SurfaceDiff)

    local Direction = Character.PrimaryPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
	TurnAngle = Lerp(TurnAngle, Direction.X * MAX_TUR_ANGLE, QuarterLerp / 2)

    -- Recoil
	local UpdatedRecoilSpring = recoil:update(dt)
	TheVM.PrimaryPart.CFrame *= CFrame.Angles(math.rad(UpdatedRecoilSpring.X) * 10, math.rad(UpdatedRecoilSpring.Y) * 10, math.rad(UpdatedRecoilSpring.Z) * 10)
	Camera.CFrame *= CFrame.Angles(math.rad(UpdatedRecoilSpring.X * 0.8), 0, 0)
	GunshotDiff = Lerp(GunshotDiff, 0, QuarterLerp * 0.8)
	TheVM.PrimaryPart.CFrame *= CFrame.new(0, 0, GunshotDiff)

    -- Aiming
    if gunDetected == true and DisplayingTool then
		local Scope = DisplayingTool:FindFirstChild("_thisSCOPE", true)
        local Attachments = DisplayingTool:FindFirstChild("_attachments", true)
		if Attachments then
			local Sight = not Scope and Attachments._aimdown or Scope._scope
			Sight.CFrame = Sight.CFrame:Lerp((TheVM.CameraBone.CFrame * CFrame.new(0, 3/4, 0) * CFrame.Angles(0, 0, math.rad(-TurnAngle))) * CFrame.new(0, 0, 0):Lerp(CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(25)), PointAimLerp), ThisAimAlpha)
		end
	else
		if prevGunDetected then
			isPointAiming = false
		end
	end

    -- Animations
    for id, anim in pairs(CoreVMAnims) do
        local ANIM_INFO = Anims[id]
		local animPlaying, FailReason = animPlaying(id)

        if not anim.IsPlaying then
            anim:Play()
        end

        if animPlaying then
            anim:AdjustWeight(Lerp(anim.WeightCurrent, 1, QuarterLerp * 10))
            anim:AdjustSpeed(Lerp(anim.Speed, (not ANIM_INFO.freezeOnIdle or isMoving) and ANIM_INFO.Speed or 0, QuarterLerp / 2))
        else
            anim:AdjustWeight(Lerp(anim.WeightCurrent, 0, QuarterLerp * 20))
        end
    end

    -- Mobile buttons
    for _, button in MobileButtons.ButtonsHolder:GetChildren() do
        if table.find({"Reload", "Fire", "Aim"}, button.Name) then
            button.Visible = gunDetected
        end
    end

    -- Firing gun
    if firingGun then
        if _G.CurrentI2 then
            if gunDetected then
                fireGun(recoil)
            else
                if _G.CurrentI2.Class == "Melee" then
                    meleeWeapon()
                end

                firingGun = false
                InvService.ActionRequest:Fire("USE")
            end
        else
            if os.clock() >= NextPunch then
                NextPunch = os.clock() + 5/4
                punch()
            end
        end
    end

    -- Resets values
    jumpChanged = false
    prevGunDetected = gunDetected
end

-- Main function
function Viewmodel.Function()

    -- Clears game of old viewmodel
    TheVM = Camera:FindFirstChild(VMTemp.Name) or RepStorage:FindFirstChild(VMTemp.Name)
    if TheVM then
        TheVM:Destroy()
    end

    if Player.Team ~= game.Teams.Squadmates then warn("not squadmate") return end

    -- Fetches keycodes
    LEAN_LEFT_KEYBOARD = DataController:Get("Keybinds.LeanLeft.Keyboard")
    LEAN_RIGHT_KEYBOARD = DataController:Get("Keybinds.LeanRight.Keyboard")
    LEAN_LEFT_GAMEPAD = DataController:Get("Keybinds.LeanLeft.Gamepad")
    LEAN_RIGHT_GAMEPAD = DataController:Get("Keybinds.LeanRight.Gamepad")
    POINT_AIM_GAMEPAD = DataController:Get("Keybinds.PointAim.Gamepad")
    POINT_AIM_KEYBOARD = DataController:Get("Keybinds.PointAim.Keyboard")
    RELOAD_GAMEPAD = DataController:Get("Keybinds.Reload.Gamepad")
    RELOAD_KEYBOARD = DataController:Get("Keybinds.Reload.Keyboard")

    -- Creates new viewmodel
    TheVM = VMTemp:Clone()
    TheVM.Parent = Camera

    for _, part in TheVM:GetDescendants() do
        if part:IsA("BasePart") then
            part.CastShadow = false
        end
    end

    -- Loads anims
    for anim, info in pairs(Anims) do
        local NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = info.ID
        CoreVMAnims[anim] = TheVM:WaitForChild("Animator"):LoadAnimation(NewAnim)
        CoreVMAnims[anim].Priority = info.Priority
        NewAnim:Destroy()
    end

    for _, id in PUNCH_ANIMS do
        local NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = id
        local Track = TheVM:WaitForChild("Animator"):LoadAnimation(NewAnim)
        Track.Priority = Enum.AnimationPriority.Action4
        table.insert(PunchTracks, Track)
        NewAnim:Destroy()
    end

    -- VMAnim remote (plays/stops an animation based on action and ID)
    VMAnim:On(function(action : string, animID : string?)
        if not (TheVM and TheVM.Parent) then return end

        if action == "START" and animID then
            local Track = VMAnimTracks[animID]

            if Track then
                Track:Stop() -- Restart if already playing
            else
                local A = Instance.new("Animation")
                A.AnimationId = animID
                Track = TheVM.Animator:LoadAnimation(A)
                Track.Priority = Enum.AnimationPriority.Action4
                A:Destroy()
                VMAnimTracks[animID] = Track
            end

            Track:Play()
        elseif action == "STOP" then
            if animID then
                if VMAnimTracks[animID] then
                    VMAnimTracks[animID]:Stop()
                    VMAnimTracks[animID] = nil
                end
            else
                for id, track in VMAnimTracks do
                    track:Stop()
                    VMAnimTracks[id] = nil
                end
            end
        end
    end)

    -- Springs
    local BobbleSpring = Spring()
    local SwaySpring = Spring()
    local RecoilSpring = Spring()

    -- Update
    RunService.PreRender:Connect(function(dt)
        update(dt, SwaySpring, BobbleSpring, RecoilSpring)
    end)

    -- Jumping
    if Humanoid then
        Humanoid.StateChanged:Connect(function(old, new)
            if table.find({Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Landed}, new) then
                jumpChanged = true
            end
        end)
    end

    -- Equipping
    local EquipGen = 0

    InvService.ToolAdded:Connect(function(toolclass : {}, ...)
        EquipGen += 1
        local myGen = EquipGen

        -- Defensive cleanup: if ToolRemoved was lost/delayed, ensure we don't orphan the old model
        if DisplayingTool and DisplayingTool.Parent then
            DisplayingTool:Destroy()
        end
        DisplayingTool = nil
        TheVM["Right Arm"].ItemPart:ClearAllChildren()
        if HoldAnim then HoldAnim:Stop() HoldAnim = nil end
        if ReloadAnim then ReloadAnim:Stop() ReloadAnim = nil end
        if FireAnim then FireAnim:Stop() FireAnim = nil end
        if EquipAnim then EquipAnim:Stop() EquipAnim = nil end
        gunDetected = false
        TrackingTool = nil
        stopPunchAnims()

        local ToolModel = ItemDisplays:FindFirstChild(toolclass.Name)
        if not ToolModel then return end

        gunDetected = toolclass.Class == "Ranged"
        _G.CurrentI2 = require(ToolModel.Configuration.ItemInfo)
        NextGunFire = 0

        local EverythingElse = {...}

        local NewDisplay = ToolModel:Clone()
        NewDisplay.Parent = TheVM

        if gunDetected then
            GunAttach(NewDisplay, EverythingElse[1])
        end

        NewDisplay:ScaleTo(3/2)
        NewDisplay:PivotTo(TheVM["Right Arm"].ItemPart.CFrame)

        local ItemConfig = NewDisplay:WaitForChild("Configuration")
        local Welds = NewDisplay:FindFirstChild("Welds", true)
        local ItemPart = TheVM["Right Arm"].ItemPart
        WeldPiece(NewDisplay.PrimaryPart, ItemPart)

        local function alreadyJointed(part : BasePart) : boolean
            for _, inst in NewDisplay:GetDescendants() do
                if inst:IsA("JointInstance") and not (Welds and inst:IsDescendantOf(Welds)) then
                    local Other = inst.Part0 == part and inst.Part1 or inst.Part1 == part and inst.Part0 or nil
                    if Other and Other:IsDescendantOf(NewDisplay) then
                        return true
                    end
                end
            end
            return false
        end

        for _, part in NewDisplay:GetDescendants() do
            if part:IsA("BasePart") then
                local Weld = Welds and Welds:FindFirstChild(part.Name)
                if Weld and Weld:IsA("JointInstance") and Weld.Part1 == part then
                    local OldPart0 = Weld.Part0
                    if not OldPart0 or not OldPart0:IsDescendantOf(NewDisplay)
                        or OldPart0 == NewDisplay.PrimaryPart
                        or OldPart0.Name == "Handle" then
                        Weld.Part0 = ItemPart
                    end
                elseif not alreadyJointed(part) then
                    WeldPiece(part, ItemPart, true)
                end
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = false
                part.AudioCanCollide = false
                part.CastShadow = false
            end
        end

        -- Hold anim
        local A = Instance.new("Animation")
        local AnimName = (Character:GetAttribute("MovementType") == "RUN" and Character:GetAttribute("rawInputDetected")) and "Run" or "Hold"
        A.AnimationId = ItemConfig.Anims.VM:FindFirstChild(AnimName) and ItemConfig.Anims.VM:FindFirstChild(AnimName).AnimationId or HoldAnimID
        local NewHoldAnim = TheVM.Animator:LoadAnimation(A)

        if myGen ~= EquipGen then
            NewHoldAnim:Destroy()
            NewDisplay:Destroy()
            A:Destroy()
            return
        end

        NewHoldAnim.Priority = Enum.AnimationPriority.Action
        NewHoldAnim.Looped = true
        NewHoldAnim:Play()

        A.AnimationId = ItemConfig.Anims.VM:FindFirstChild("Reload") and ItemConfig.Anims.VM:FindFirstChild("Reload").AnimationId or HoldAnimID
        local NewReloadAnim = TheVM.Animator:LoadAnimation(A)
        A:Destroy()

        if myGen ~= EquipGen then
            NewReloadAnim:Destroy()
            NewHoldAnim:Stop()
            NewHoldAnim:Destroy()
            NewDisplay:Destroy()
            return
        end

        NewReloadAnim.Priority = Enum.AnimationPriority.Action4

        -- Only now commit to shared state
        DisplayingTool = NewDisplay
        HoldAnim = NewHoldAnim
        ReloadAnim = NewReloadAnim

        local Equip = NewDisplay:FindFirstChild("Equip", true)
        if Equip then Equip:Play() end
        EquipDiff += 1

        -- Guns with a GunEquip animation in the VM folder play it right after equipping;
        -- its Action4 priority lets it override the looping Hold anim until it ends
        local GunEquip = ItemConfig.Anims.VM:FindFirstChild("GunEquip")
        if GunEquip then
            local NewEquipAnim = TheVM.Animator:LoadAnimation(GunEquip)
            NewEquipAnim.Priority = Enum.AnimationPriority.Action4
            NewEquipAnim:Play()
            EquipAnim = NewEquipAnim
        end

        task.defer(function()
            local FoundCharTool = Character:FindFirstChildOfClass("Tool")
            if FoundCharTool and FoundCharTool.Name == toolclass.Name then
                FoundCharTool:ClearAllChildren()
                TrackingTool = FoundCharTool
            end
        end)
    end)

    -- Unequipping
    InvService.ToolRemoved:Connect(function(toolclass : {})
        clearViewmodel(toolclass)
    end)

    -- Server-triggered gun animations (e.g. equip replay after firing, per-round
    -- reload for incremental reloads, equip after a shell-by-shell reload finishes)
    GunService.PlayGunAnim:Connect(function(animName : string)
        if animName == "GunEquip" and EquipAnim then
            EquipAnim:Stop()
            EquipAnim:Play()

            -- Plays the equip sound every time the equip animation plays
            local EquipSound = DisplayingTool and DisplayingTool:FindFirstChild("Equip", true)
            if EquipSound then EquipSound:Play() end
        elseif animName == "Reload" and ReloadAnim then
            ReloadAnim:Stop()
            ReloadAnim:Play()

            if DisplayingTool and DisplayingTool:FindFirstChild("Handle") then
                DisplayingTool.Handle.Reload:Play()
            end
        end
    end)

    -- Reloading
    Character:GetAttributeChangedSignal("isReloading"):Connect(function()
        if Character:GetAttribute("isReloading") then
            if DisplayingTool and DisplayingTool:FindFirstChild("Handle") then
                DisplayingTool.Handle.Reload:Play()
            end
            if ReloadAnim then
                ReloadAnim:Play()
            end

            -- Guns that unload their chamber at reload eject one casing per
            -- vacant round here instead of ejecting on each shot
            if _G.CurrentI2 and _G.CurrentI2.unloadChamberAtReload and TrackingTool then
                local Vacant = _G.CurrentI2.Mag - (TrackingTool:GetAttribute("Ammo") or 0)
                if Vacant > 0 then
                    BulletEnv.ejectCasings(Character, _G.CurrentI2.AmmoType, Vacant)
                end
            end
        else
            if DisplayingTool and DisplayingTool:FindFirstChild("Handle") then
                DisplayingTool.Handle.Reload:Stop()
            end
            if ReloadAnim then
                ReloadAnim:Stop()
            end
        end
    end)

    -- Running anim for gun
    local wasRunning = Character:GetAttribute("MovementType") == "RUN" and Character:GetAttribute("rawInputDetected")

    local function toggleAnim()
        if DisplayingTool and HoldAnim then
            local isRunning = Character:GetAttribute("MovementType") == "RUN" and Character:GetAttribute("rawInputDetected")
            if isRunning ~= wasRunning then
                HoldAnim:Stop()

                local A = Instance.new("Animation")
                local AnimName = isRunning and "Run" or "Hold"

                A.AnimationId = DisplayingTool.Configuration.Anims.VM:FindFirstChild(AnimName) and DisplayingTool.Configuration.Anims.VM:FindFirstChild(AnimName).AnimationId or HoldAnimID
                HoldAnim = TheVM.Animator:LoadAnimation(A)
                HoldAnim.Priority = Enum.AnimationPriority.Action
                HoldAnim.Looped = true
                HoldAnim:Play()
                A:Destroy()
            end

            wasRunning = isRunning
        end
    end

    Character:GetAttributeChangedSignal("MovementType"):Connect(toggleAnim)
    Character:GetAttributeChangedSignal("rawInputDetected"):Connect(toggleAnim)

    -- Leaning
    CAS:BindAction("leanLeft", toggleLean, false, Enum.KeyCode[LEAN_LEFT_KEYBOARD], Enum.KeyCode[LEAN_LEFT_GAMEPAD])
	CAS:BindAction("leanRight", toggleLean, false, Enum.KeyCode[LEAN_RIGHT_KEYBOARD], Enum.KeyCode[LEAN_RIGHT_GAMEPAD])

    for _, button in MobileButtons.ButtonsHolder:GetChildren() do
        if string.find(button.Name, "Lean") then
            button.TextButton.MouseButton1Down:Connect(function()
                toggleLean(button.Name, Enum.UserInputState.Begin)
            end)

            button.TextButton.MouseButton1Up:Connect(function()
                toggleLean(button.Name, Enum.UserInputState.End)
            end)
        end
    end

    -- Aiming
    UIS.InputBegan:Connect(function(input, processed)
        if processed or Player:GetAttribute("isChatting") == true then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            if gunDetected then
                GunService.AimToggle:Fire(true)
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            firingGun = true
        end
    end)

    UIS.InputEnded:Connect(function(input, processed)
        if processed or Player:GetAttribute("isChatting") == true then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            GunService.AimToggle:Fire(false)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            firingGun = false
        end
    end)

    MobileButtons.ButtonsHolder.Aim.TextButton.MouseButton1Click:Connect(function()
        GunService.AimToggle:Fire(not Character:GetAttribute("isAiming"))
    end)

    MobileButtons.ButtonsHolder.Fire.TextButton.MouseButton1Click:Connect(function()
        firingGun = not firingGun
    end)

    CAS:BindAction("PointAimTog", togglePointAim, false, Enum.KeyCode[POINT_AIM_KEYBOARD], Enum.KeyCode[POINT_AIM_GAMEPAD])

    -- Reloading
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe or Player:GetAttribute("isChatting") == true then return end
        if table.find({Enum.KeyCode[RELOAD_GAMEPAD], Enum.KeyCode[RELOAD_KEYBOARD]}, input.KeyCode) then
            GunRequest:Fire("RELOAD")
        end
    end)

    MobileButtons.ButtonsHolder.Reload.TextButton.MouseButton1Click:Connect(function()
        GunRequest:Fire("RELOAD")
    end)
end

return Viewmodel