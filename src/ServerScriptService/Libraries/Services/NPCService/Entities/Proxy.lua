-- Services
local Players         = game:GetService("Players")
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

local CharService     = _G.Knit.GetService("CharService")
local CombatService   = _G.Knit.GetService("CombatService")
local CommsService    = _G.Knit.GetService("CommsService")
local DetectService   = _G.Knit.GetService("DetectionService")
local EffectService   = _G.Knit.GetService("EffectService")
local NPCService      = _G.Knit.GetService("NPCService")
local RoundService    = _G.Knit.GetService("RoundService")
local ScoreService    = _G.Knit.GetService("ScoreService")
local VFXService      = _G.Knit.GetService("VFXService")

-- Modules and objects
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)
local ProxyGrabSettings = require(RepStorage.Modules.Data.ProxyGrabSettings)
local SimplePath      = require(RepStorage.Modules.Util.SimplePath)
local WeldPiece       = require(RepStorage.Modules.Util.WeldPiece)

-- Vars and consts
local PATROL_INTERVAL = 3
local PATROL_TIMEOUT  = 30 -- seconds before an unreachable patrol point is skipped

local ANIMS         = {
    ["Idle"]        = {91585323243859, Enum.AnimationPriority.Idle},
    ["Run"]         = {81207900885640, Enum.AnimationPriority.Action},
    ["Walk"]        = {89468869841055, Enum.AnimationPriority.Movement},
    ["Hold"]        = {96432749173875, Enum.AnimationPriority.Action3},
    ["Jump"]        = {116496690680898, Enum.AnimationPriority.Action2},
    ["Fall"]        = {119528283195927, Enum.AnimationPriority.Action3},
    ["Land"]        = {70926104383734, Enum.AnimationPriority.Action2},
    ["Cloak"]       = {95947585478349, Enum.AnimationPriority.Action4},
    ["Grab"]        = {88986754999227, Enum.AnimationPriority.Action4}
}

local ANIM_GRAB_VICTIM = 121534838798001

local ATTACK_ANIMS  = {97633645023236, 126985686457998, 123162586564812, 94060623091801}
local ATTACK_SOUNDS = {7801336419, 7801329626}
local HIT_SOUNDS    = {18512265986, 18512270266}

local SPEEDS        = {
    PATROL          = 8,
    CHASE           = 21,
    STALK           = 1,
    GRAB            = 21,
    CARRY           = 4,
    RETREAT         = 40,
}

local HEAL_RATES    = {
    PATROL          = 5,
    CHASE           = 0,
    STALK           = 0,
    GRAB            = 0,
    CARRY           = 0,
    RETREAT         = 25,
}

local GRAB_WINDUP = 1/2

local STALK_NODE_PROGRESS       = 0.25
local STALK_CHANCE              = 1
local STALK_DURATION            = 20
local STALK_REVEAL_DISTANCE     = 6
local STALK_ABORT_DISTANCE      = 30
local STALK_TELEPORT_DELAY      = 1/2
local STALK_TELEPORT_RANGE      = 15
local STALK_TELEPORT_CLEARANCE  = 2
local STALK_TELEPORT_ATTEMPTS   = 12

local SENSE_ADVANCE  = 1/4 -- seconds of sensing a player needed to raise one Awareness level
local SENSE_DECAY    = 5   -- seconds of sensing no one needed to drop one Awareness level
local CHASE_LEVEL    = 3   -- Awareness level at which the Brainwashed enters CHASE

local SIGHT_RANGE    = 1000 -- max distance in studs the Brainwashed can see
local SIGHT_FOV      = 0.5  -- minimum facing alignment (LookVector dot direction) needed to see a target

local UPDATE_INTERVAL = 1/4 -- seconds between awareness checks and path re-runs

local ATTACK_INTERVAL = 3/4

local INVIS_LENGTH   = 0         -- 0 keeps the Proxy invisible until he is forced to phase back in
local INVIS_STRENGTH = math.huge -- completely invisible (parts, decals, beams, particles, lights, GUIs)

local RETREAT_TIMEOUT = 15 -- seconds before a stuck retreat phases back in anyway

local MIN_FALL_TIME  = 1/5 -- seconds airborne before a landing counts as a real fall
local MIN_FALL_DIST  = 4   -- studs dropped before a landing counts as a real fall

-- [[ funcs ]] --

-- Picks random patrol point
local function pickPatrolPoint(currentspawn : Part?) : Part
    local Playspace = game.Workspace:WaitForChild("Playspace")
    local Spawns = Playspace.Spawns.Characters.Subjects:GetChildren()

    local ChosenSpawn : Part? = currentspawn
    while ChosenSpawn == currentspawn do
        ChosenSpawn = Spawns[math.random(1, #Spawns)]
    end

    return ChosenSpawn
end

-- A target only counts while it is alive, still in the world, and not grabbed
local function isValidTarget(char : Model?) : boolean
    if not char or not char.Parent or not char.PrimaryPart or char:GetAttribute("isGrabbed") == true then
        return false
    end

    local Hum = char:FindFirstChildOfClass("Humanoid")
    return Hum ~= nil and Hum.Health > 0 and (char:GetAttribute("Health") or 0) > 0
end

return function(rig : Model)
    -- Vars and consts
    local Awareness = 0 -- 0 = unaware, 1 = sensing, 2 = following, 3 = chase
    local CurrentPatrolCount = 2
    local CurrentPatrolTarget : Part? = pickPatrolPoint()
    local PatrolTargetStart = os.clock() -- when the current patrol target was picked
    local CurrentState = "PATROL"
    local GrabTarget : Model? = nil
    local GrabStart = 0
    local GrabProgress = 0
    local GrabDrainRate = 0
    local GrabKey = ""
    local GrabInputSerial = 0
    local GrabbedVictim : Model? = nil
    local GrabWeld : Weld? = nil
    local GrabVictimTrack : AnimationTrack? = nil
    local GrabbedCanAttack = true
    local GrabDiedConn : RBXScriptConnection? = nil
    local GrabDestroyingConn : RBXScriptConnection? = nil
    local NextAttack = 0
    local NextPathRun = 0
    local NextPositionCheck = 0
    local NextRetreatExit = 0
    local RetreatStart = 0
    local LastPosition : Vector3? = rig.PrimaryPart.CFrame.Position
    local LastTarget : Model? = nil
    local LastLevel = 0
    local PreviousPatrolTarget = nil
    local SensedTarget = nil
    local StalkStart = 0
    local StalkTeleportCFrame : CFrame? = nil
    local StalkDetectedTargets = {}
    local TimeSinceUpdate = 0
    local TotalDamage = 0

    local HeardTime = 0
    local UnheardTime = 0

    local Limit = 0
    local MaxLimit = 60 -- how much limit must accumulate before retreating

    -- Sets stuff up
    local LifeConn : RBXScriptConnection
    local Path = SimplePath.new(rig)

    local RigClass = CharService:GetCharacterClass(rig)
    RigClass.HealthClass.humanoidDiesOnZero = false

    rig:SetAttribute("MaxHealth", 600)
    rig:SetAttribute("Health", 600)

    local Humanoid : Humanoid = rig:FindFirstChildOfClass("Humanoid")

    local LoadedAnims  = {}
    for tag, id in ANIMS do
        local Animation = Instance.new("Animation")
        Animation.AnimationId = "rbxassetid://"..id[1]
        local LoadedAnim : AnimationTrack = rig:WaitForChild("Humanoid").Animator:LoadAnimation(Animation)
        LoadedAnim.Looped = not table.find({"Jump", "Land", "Spawn"}, tag)
        LoadedAnim.Priority = id[2]
        LoadedAnims[tag] = LoadedAnim
    end

    local AttackAnims = {}
	for _, anim in pairs(ATTACK_ANIMS) do
		local ThisAnim = Instance.new("Animation")
		ThisAnim.AnimationId = "rbxassetid://"..anim
		local LoadedAnim = rig.Humanoid.Animator:LoadAnimation(ThisAnim)
        LoadedAnim.Priority = Enum.AnimationPriority.Action4
        LoadedAnim.Looped = false
		ThisAnim:Destroy()

		table.insert(AttackAnims, LoadedAnim)
	end

    local CloakAmbience = Instance.new("Sound")
    CloakAmbience.SoundId = "rbxassetid://9120275030"
    CloakAmbience.Looped = true
    CloakAmbience.Parent = rig.PrimaryPart
    CloakAmbience.Volume = 0
    CloakAmbience:Play()

    -- [[ Main life cycle ]] --

    -- Calculates aggression level
    local function aggroLevel() : number
        return 1 + (RoundService:NodeProgress() * 0.75) + TotalDamage / 1600
    end

    local function getValidTargets() : {Model}
        local Targets = {}

        for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
            if char ~= rig and char:GetAttribute("Team") ~= rig:GetAttribute("Team") and isValidTarget(char) then
                table.insert(Targets, char)
            end
        end

        return Targets
    end

    local function getNearestTarget(Targets : {Model}, Origin : Vector3) : (Model?, number)
        local NearestTarget = nil
        local NearestDistance = math.huge

        for _, char in Targets do
            local Distance = (char.PrimaryPart.CFrame.Position - Origin).Magnitude
            if Distance < NearestDistance then
                NearestTarget = char
                NearestDistance = Distance
            end
        end

        return NearestTarget, NearestDistance
    end

    -- Detecting player via Noise and Sight
    local function hearPlayer() : Model?
        if not rig.PrimaryPart then
            return nil
        end

        local BestChar, BestSignal = nil, 0
        local SeenChar, SeenDistance = nil, SIGHT_RANGE

        local EyePosition = rig.PrimaryPart.CFrame.Position
        local LookVector  = rig.PrimaryPart.CFrame.LookVector

        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {rig}

        for _, char in getValidTargets() do
            local Offset   = char.PrimaryPart.Position - EyePosition
            local Distance = Offset.Magnitude

            -- Sight: needs to be in front of self with an unobstructed line to the target
            if Distance < SIGHT_RANGE and (Distance < 1 or Offset.Unit:Dot(LookVector) > SIGHT_FOV) then
                local Raycast = game.Workspace:Raycast(EyePosition, Offset, RayParams)

                if Raycast and Raycast.Instance:IsDescendantOf(char) and Distance < SeenDistance then
                    SeenChar     = char
                    SeenDistance = Distance
                end
            end

            -- Noise
            local Noise  = math.max(char:GetAttribute("Noise") or 0, 3)
            local Signal = Noise - Distance

            if Signal > BestSignal then
                BestChar   = char
                BestSignal = Signal
            end
        end

        return SeenChar or BestChar
    end

    -- Alerts players of detection
    local function updateDetection()
        local Level  = (SensedTarget and SensedTarget.Parent and Awareness > 0) and Awareness or 0
        local Target = Level > 0 and SensedTarget or nil

        if Target ~= LastTarget or Level ~= LastLevel then
            if LastTarget and LastTarget.Parent and LastLevel > 0 then
                DetectService:DetectPlayer(rig, LastTarget, 0)
            end

            if Target then
                DetectService:DetectPlayer(rig, Target, Level)
            end

            LastTarget = Target
            LastLevel  = Level
        end
    end

    local function clearStalkDetection()
        for Target in StalkDetectedTargets do
            DetectService:DetectPlayer(rig, Target, 0)
        end

        table.clear(StalkDetectedTargets)
    end

    local function resetAwareness()
        SensedTarget = nil
        Awareness = 0
        HeardTime = 0
        UnheardTime = 0
        updateDetection()
    end

    local function syncStalkDetection(Targets : {Model})
        local ValidTargets = {}

        for _, Target in Targets do
            ValidTargets[Target] = true
            if not StalkDetectedTargets[Target] then
                DetectService:DetectPlayer(rig, Target, 3)
                StalkDetectedTargets[Target] = true
            end
        end

        for Target in StalkDetectedTargets do
            if not ValidTargets[Target] then
                DetectService:DetectPlayer(rig, Target, 0)
                StalkDetectedTargets[Target] = nil
            end
        end
    end

    -- Updates awareness
    local function updateAwareness(dt)
        -- Drops targets that died or were removed while sensed
        if SensedTarget and not isValidTarget(SensedTarget) then
            SensedTarget = nil
        end

        local Heard = hearPlayer()

        if Heard then
            SensedTarget  = Heard
            HeardTime   += dt
            UnheardTime  = 0

            while HeardTime >= SENSE_ADVANCE and Awareness < CHASE_LEVEL do
                HeardTime -= SENSE_ADVANCE
                Awareness += 1
            end
        else
            HeardTime    = 0
            UnheardTime += dt

            if UnheardTime >= SENSE_DECAY then
                UnheardTime -= SENSE_DECAY
                Awareness    = math.max(Awareness - 1, 0)

                if Awareness == 0 then
                    SensedTarget = nil
                end
            end
        end

        updateDetection()
    end

    local function getStalkTeleportCFrame(Target : Model) : CFrame?
        local Origin = Target.PrimaryPart.CFrame.Position
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {rig, Target}

        for _ = 1, STALK_TELEPORT_ATTEMPTS do
            local Angle = Rand:NextNumber(0, math.pi * 2)
            local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
            local Hit = game.Workspace:Raycast(Origin, Direction * STALK_TELEPORT_RANGE, RayParams)
            local Distance = Hit and Hit.Distance - STALK_TELEPORT_CLEARANCE or STALK_TELEPORT_RANGE

            if Distance > STALK_TELEPORT_CLEARANCE then
                local Position = Origin + Direction * Distance
                return CFrame.lookAt(Position, Vector3.new(Origin.X, Position.Y, Origin.Z))
            end
        end

        return nil
    end

    local function startStalk() : boolean
        local Targets = getValidTargets()
        if #Targets == 0 then
            return false
        end

        local ChosenTarget = Targets[Rand:NextInteger(1, #Targets)]
        local TeleportCFrame = getStalkTeleportCFrame(ChosenTarget)
        if not TeleportCFrame then
            return false
        end

        resetAwareness()
        clearStalkDetection()
        CurrentState = "STALK"
        StalkStart = os.clock()
        StalkTeleportCFrame = TeleportCFrame
        NextPathRun = 0
        TimeSinceUpdate = 0

        rig:SetAttribute("Invisible", true)
        VFXService:GlobalVFX("Invisibility", "Effect", rig.PrimaryPart.CFrame, rig, INVIS_LENGTH, INVIS_STRENGTH)

        LoadedAnims.Cloak:Play()
        CloakAmbience.Volume = 0
        syncStalkDetection(Targets)

        return true
    end

    local function endStalk(playEndSound : boolean?)
        clearStalkDetection()
        StalkStart = 0
        StalkTeleportCFrame = nil

        rig:SetAttribute("Invisible", false)
        VFXService:GlobalVFX("Invisibility", "End", rig.PrimaryPart.CFrame, rig)
        LoadedAnims.Cloak:Stop()
        if playEndSound ~= false then
            PlaySound(9126228629, "End", rig.PrimaryPart, nil, 1, 1)
        end
        CloakAmbience.Volume = 0
    end

    local function setGrabKey(Target : Model)
        local Keybinds = ProxyGrabSettings.KEYBINDS
        local Index = Rand:NextInteger(1, #Keybinds)

        if GrabKey ~= "" then
            repeat
                Index = Rand:NextInteger(1, #Keybinds)
            until Keybinds[Index][1].Name ~= GrabKey
        end

        GrabKey = Keybinds[Index][1].Name
        Target:SetAttribute("ProxyGrabKey", GrabKey)
    end

    local function enterRetreat()
        CurrentState = "RETREAT"
        RetreatStart = os.clock()
        NextRetreatExit = os.clock()
        CurrentPatrolCount = 0
        CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
        NextPathRun = 0
        resetAwareness()

        RigClass.HealthClass.canBeAttacked = false
        rig:SetAttribute("Invisible", true)
        VFXService:GlobalVFX("Invisibility", "Effect", rig.PrimaryPart.CFrame, rig, INVIS_LENGTH, INVIS_STRENGTH)
    end

    local function releaseGrab()
        local Victim = GrabbedVictim
        if not Victim then
            return
        end

        GrabbedVictim = nil

        local Weld = GrabWeld
        local VictimTrack = GrabVictimTrack
        local CanAttack = GrabbedCanAttack
        local DiedConn = GrabDiedConn
        local DestroyingConn = GrabDestroyingConn

        GrabWeld = nil
        GrabVictimTrack = nil
        GrabDiedConn = nil
        GrabDestroyingConn = nil

        if DiedConn then
            DiedConn:Disconnect()
        end
        if DestroyingConn then
            DestroyingConn:Disconnect()
        end
        if Weld then
            Weld:Destroy()
        end
        if VictimTrack then
            VictimTrack:Stop()
            VictimTrack:Destroy()
        end

        LoadedAnims.Grab:Stop()

        if Victim.Parent then
            Victim:SetAttribute("isGrabbed", false)

            local VictimClass = CharService:GetCharacterClass(Victim)
            if VictimClass and VictimClass.HealthClass then
                VictimClass.HealthClass.canAttack = CanAttack
            end

            local VictimHumanoid = Victim:FindFirstChildOfClass("Humanoid")
            if VictimHumanoid then
                VictimHumanoid.AutoRotate = true
            end
        end

        if Victim.PrimaryPart then
            Victim.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            Victim.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
            pcall(function()
                Victim.PrimaryPart:SetNetworkOwnershipAuto()
            end)
        end

        if rig.PrimaryPart then
            rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            rig.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
            pcall(function()
                rig.PrimaryPart:SetNetworkOwnershipAuto()
            end)
        end
    end

    local function endCarry()
        if CurrentState ~= "CARRY" then
            return
        end

        releaseGrab()
        resetAwareness()
        CurrentPatrolCount = 0
        CurrentPatrolTarget = pickPatrolPoint(CurrentPatrolTarget or PreviousPatrolTarget)
        PatrolTargetStart = os.clock()
        CurrentState = "PATROL"
        NextPathRun = 0
        TimeSinceUpdate = 0
        LastPosition = rig.PrimaryPart and rig.PrimaryPart.CFrame.Position or LastPosition
    end

    local function resolveGrab(PlayerWon : boolean)
        local Victim = GrabbedVictim
        if not Victim then
            return
        end

        if PlayerWon then
            Victim:SetAttribute("ProxyGrabResult", "ESCAPED")
            releaseGrab()
            enterRetreat()
            ScoreService:AwardScore(Victim, 40, "Escaped PNDR-4075", true)
            return
        end

        Victim:SetAttribute("ProxyGrabResult", "KILLED")
        local VictimClass = CharService:GetCharacterClass(Victim)
        CombatService:Damage(rig, Victim, Victim:GetAttribute("MaxHealth") + 1, "PROXY_2", "DEFAULT", true, nil, nil)

        if VictimClass and VictimClass.HealthClass then
            VictimClass.HealthClass:InstaKill()
        else
            local VictimHumanoid = Victim:FindFirstChildOfClass("Humanoid")
            if VictimHumanoid then
                VictimHumanoid.Health = 0
            end
        end

        endCarry()
    end

    local function handleGrabInput(Player : Player, Key : string)
        local Victim = GrabbedVictim
        if CurrentState ~= "CARRY" or not Victim or Players:GetPlayerFromCharacter(Victim) ~= Player or type(Key) ~= "string" then
            return
        end

        local Result = Victim:GetAttribute("ProxyGrabResult")
        if Result ~= nil and Result ~= "" then
            return
        end

        local ValidKey = false
        for _, Info in ProxyGrabSettings.KEYBINDS do
            if Info[1].Name == Key then
                ValidKey = true
                break
            end
        end

        if not ValidKey then
            return
        end

        local Good = Key == GrabKey
        local Change = Good and (ProxyGrabSettings.GOOD_BONUS * GrabDrainRate / ProxyGrabSettings.DRAIN_RATE) or -ProxyGrabSettings.BAD_PENALTY
        GrabProgress = math.clamp(GrabProgress + Change, 0, 100)

        setGrabKey(Victim)
        GrabInputSerial += 1
        Victim:SetAttribute("ProxyGrabProgress", GrabProgress)
        Victim:SetAttribute("ProxyGrabFeedback", Good and "Good" or "Bad")
        Victim:SetAttribute("ProxyGrabInputSerial", GrabInputSerial)

        if GrabProgress >= 100 then
            resolveGrab(true)
        elseif GrabProgress <= 0 then
            resolveGrab(false)
        end
    end

    local function startGrab(Target : Model) : boolean
        if GrabbedVictim or not Players:GetPlayerFromCharacter(Target) or not isValidTarget(Target) then
            return false
        end

        local VictimClass = CharService:GetCharacterClass(Target)
        local VictimHumanoid = Target:FindFirstChildOfClass("Humanoid")
        local VictimAnimator = VictimHumanoid and VictimHumanoid:FindFirstChildOfClass("Animator")
        if not VictimClass or not VictimClass.HealthClass or not VictimHumanoid or not VictimAnimator then
            return false
        end

        if Path.Status == SimplePath.StatusType.Active then
            Path:Stop()
        end

        local GrabPosition = rig.PrimaryPart.CFrame.Position
        resetAwareness()
        GrabTarget = nil
        GrabStart = 0
        CurrentState = "CARRY"
        NextPathRun = 0
        TimeSinceUpdate = 0

        GrabbedVictim = Target
        GrabbedCanAttack = VictimClass.HealthClass.canAttack
        VictimClass.HealthClass.canAttack = false

        Target:SetAttribute("isFiring", false)
        Target:SetAttribute("isAiming", false)
        Target:SetAttribute("isReloading", false)
        Target:SetAttribute("isLeaning", false)
        Target:SetAttribute("MovementType", "WALK")

        GrabProgress = ProxyGrabSettings.INITIAL_PROGRESS
        GrabDrainRate = ProxyGrabSettings.DRAIN_RATE
        GrabKey = ""
        GrabInputSerial = 0
        Target:SetAttribute("ProxyGrabProgress", GrabProgress)
        Target:SetAttribute("ProxyGrabFeedback", "")
        Target:SetAttribute("ProxyGrabInputSerial", GrabInputSerial)
        Target:SetAttribute("ProxyGrabResult", "")
        setGrabKey(Target)
        Target:SetAttribute("isGrabbed", true)

        local GrabbedPlayer = Players:GetPlayerFromCharacter(Target)
        if GrabbedPlayer then
            VFXService:PlayVFX(GrabbedPlayer, "Horror", "Horror", rig.PrimaryPart.CFrame, rig, 3, true)
        end

        for _, Root in {rig.PrimaryPart, Target.PrimaryPart} do
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
            pcall(function()
                Root:SetNetworkOwner(nil)
            end)
        end

        VictimHumanoid.AutoRotate = false
        Target:PivotTo(rig.PrimaryPart.CFrame * CFrame.new(0, 0, -1.25))
        GrabWeld = WeldPiece(rig.PrimaryPart, Target.PrimaryPart)

        local VictimAnimation = Instance.new("Animation")
        VictimAnimation.AnimationId = "rbxassetid://"..ANIM_GRAB_VICTIM
        local VictimTrack = VictimAnimator:LoadAnimation(VictimAnimation)
        VictimAnimation:Destroy()
        VictimTrack.Looped = true
        VictimTrack.Priority = Enum.AnimationPriority.Action4
        GrabVictimTrack = VictimTrack

        LoadedAnims.Grab:Play()
        VictimTrack:Play()
        PlaySound(9120769331, "Init", nil, GrabPosition, 1, 1)
        PlaySound(106447205440153, "Grab", nil, GrabPosition, 1, 1)

        GrabDiedConn = VictimHumanoid.Died:Connect(endCarry)
        GrabDestroyingConn = Target.Destroying:Connect(endCarry)

        local FirstPatrolPoint = pickPatrolPoint(PreviousPatrolTarget)
        local SecondPatrolPoint = pickPatrolPoint(FirstPatrolPoint)
        PreviousPatrolTarget = FirstPatrolPoint
        CurrentPatrolTarget = SecondPatrolPoint
        PatrolTargetStart = os.clock()

        rig:PivotTo(FirstPatrolPoint.CFrame)
        LastPosition = rig.PrimaryPart.CFrame.Position

        return true
    end

    local function beginGrab(Target : Model) : boolean
        if not Players:GetPlayerFromCharacter(Target) or not isValidTarget(Target) then
            return false
        end

        endStalk(false)
        resetAwareness()
        GrabTarget = Target
        GrabStart = os.clock()
        CurrentState = "GRAB"
        NextPathRun = 0
        TimeSinceUpdate = 0

        return true
    end

    local function grabWindup()
        local Target = GrabTarget
        if not Target or not Players:GetPlayerFromCharacter(Target) or not isValidTarget(Target) then
            GrabTarget = nil
            GrabStart = 0
            CurrentState = "PATROL"
            NextPathRun = 0
            return
        end

        if os.clock() - GrabStart >= GRAB_WINDUP then
            if not startGrab(Target) then
                GrabTarget = nil
                GrabStart = 0
                CurrentState = "PATROL"
                NextPathRun = 0
            end
            return
        end

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + UPDATE_INTERVAL
            Path:Run(Target.PrimaryPart.CFrame.Position)
        end
    end

    local function carry(dt)
        local Victim = GrabbedVictim
        if not Victim or not Victim.Parent then
            endCarry()
            return
        end

        GrabDrainRate += ProxyGrabSettings.DRAIN_ACCELERATION * dt
        GrabProgress = math.max(0, GrabProgress - GrabDrainRate * dt)
        Victim:SetAttribute("ProxyGrabProgress", GrabProgress)
        if GrabProgress <= 0 then
            resolveGrab(false)
            return
        end

        if not CurrentPatrolTarget then
            return
        end

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + UPDATE_INTERVAL

            local CarryTarget = CurrentPatrolTarget
            Path:Run(CarryTarget.CFrame.Position)
            if CurrentState ~= "CARRY" or CurrentPatrolTarget ~= CarryTarget then
                return
            end

            local Distance = (rig.PrimaryPart.CFrame.Position - CarryTarget.CFrame.Position).Magnitude
            if Distance < 6 or os.clock() - PatrolTargetStart >= PATROL_TIMEOUT then
                if Path.Status == SimplePath.StatusType.Active then
                    Path:Stop()
                end

                Humanoid:MoveTo(rig.PrimaryPart.CFrame.Position)
                PreviousPatrolTarget = CarryTarget
                CurrentPatrolTarget = nil
            end
        end
    end

    local function finishStalk(Target : Model)
        endStalk()
        SensedTarget = Target
        Awareness = CHASE_LEVEL
        HeardTime = 0
        UnheardTime = 0
        CurrentState = "CHASE"
        NextPathRun = 0
        TimeSinceUpdate = 0
        updateDetection()

        local ChasingPlayer = Players:GetPlayerFromCharacter(Target)
        if ChasingPlayer then
            VFXService:PlayVFX(ChasingPlayer, "Horror", "Horror", rig.PrimaryPart.CFrame, rig, Awareness)
        end
    end

    local function abortStalk()
        endStalk()
        resetAwareness()
        CurrentPatrolCount = 0
        CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
        PatrolTargetStart = os.clock()
        CurrentState = "PATROL"
        NextPathRun = 0
        TimeSinceUpdate = 0

        rig:PivotTo(CurrentPatrolTarget.CFrame)
        LastPosition = rig.PrimaryPart.CFrame.Position
    end

    local function stalk(dt)
        local TeleportCFrame = StalkTeleportCFrame
        if TeleportCFrame then
            if os.clock() - StalkStart < STALK_TELEPORT_DELAY then
                return
            end

            StalkTeleportCFrame = nil
            rig:PivotTo(TeleportCFrame)
            LastPosition = TeleportCFrame.Position
            NextPathRun = 0
        end

        local Targets = getValidTargets()
        local Target, Distance = getNearestTarget(Targets, rig.PrimaryPart.CFrame.Position)

        if Target and Distance < STALK_REVEAL_DISTANCE then
            if Players:GetPlayerFromCharacter(Target) then
                if not beginGrab(Target) then
                    finishStalk(Target)
                end
            else
                finishStalk(Target)
            end
            return
        end

        if not Target or Distance >= STALK_ABORT_DISTANCE or os.clock() - StalkStart >= STALK_DURATION then
            abortStalk()
            return
        end

        TimeSinceUpdate += dt
        if TimeSinceUpdate >= UPDATE_INTERVAL then
            syncStalkDetection(Targets)
            TimeSinceUpdate = 0
        end

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + UPDATE_INTERVAL
            Path:Run(Target.PrimaryPart.CFrame.Position)
        end
    end

    local function patrol(dt)
        if not CurrentPatrolTarget then
           CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
           PatrolTargetStart = os.clock()
        end

        TimeSinceUpdate += dt

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + 1/4
            Path:Run((Awareness < 2 or not isValidTarget(SensedTarget)) and CurrentPatrolTarget.CFrame.Position or SensedTarget.PrimaryPart.CFrame.Position)
            if CurrentState ~= "PATROL" then
                return
            end

            -- Choose new target if destination reached; if it cannot be reached within
            -- thirty seconds, move on to the next as if it had been reached
            local Distance = (rig.PrimaryPart.CFrame.Position - CurrentPatrolTarget.CFrame.Position).Magnitude
            local ReachedPatrolPoint = Distance < 6
            if ReachedPatrolPoint or os.clock() - PatrolTargetStart >= PATROL_TIMEOUT then
                PreviousPatrolTarget = CurrentPatrolTarget
                CurrentPatrolTarget = nil
                CurrentPatrolCount += 1

                if CurrentPatrolCount >= 3 then
                    CurrentPatrolCount = 0

                    if ReachedPatrolPoint and RoundService:NodeProgress() >= STALK_NODE_PROGRESS
                        and Rand:NextNumber() < STALK_CHANCE and startStalk() then
                        return
                    end

                    CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
                    PatrolTargetStart = os.clock()
                    rig:PivotTo(CurrentPatrolTarget.CFrame)
                    LastPosition = rig.PrimaryPart.CFrame.Position
                end
            end

            updateAwareness(TimeSinceUpdate)
            TimeSinceUpdate = 0
        end

        -- Moves to chase if awareness > 2
        if Awareness > 2 and SensedTarget then
            CurrentState = "CHASE"

            local ChasingPlayer = Players:GetPlayerFromCharacter(SensedTarget)
            if ChasingPlayer then
                -- Jumpscares player
                VFXService:PlayVFX(ChasingPlayer, "Horror", "Horror", rig.PrimaryPart.CFrame, rig, Awareness)
            end
        end
    end

    local function chase(dt)
        -- Dead or removed targets are dropped immediately so the Proxy reverts to
        -- patrol (or picks up a new living target) instead of attacking the corpse
        if not isValidTarget(SensedTarget) then
            SensedTarget = nil
            Awareness    = 0
            HeardTime    = 0
            UnheardTime  = 0
            CurrentState = "PATROL"
            updateDetection()
            return
        end

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + 1/4
            Path:Run(SensedTarget.PrimaryPart.CFrame.Position)
        end

        -- Attacking
        local DistanceFromTarget = (SensedTarget.PrimaryPart.CFrame.Position - rig.PrimaryPart.CFrame.Position).Magnitude
        if DistanceFromTarget < 6 and os.clock() >= NextAttack then
            NextAttack = os.clock() + ATTACK_INTERVAL
            AttackAnims[math.random(1, #AttackAnims)]:Play()
            PlaySound(ATTACK_SOUNDS[math.random(1, #ATTACK_SOUNDS)], "Attack", rig.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))

            -- Hit detection: swings through everything within reach in a 180 degree
            -- frontal arc, not just the chased target
            local AttackPosition = rig.PrimaryPart.CFrame.Position
            local LookVector     = rig.PrimaryPart.CFrame.LookVector

            for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
                if char ~= rig and char:GetAttribute("Team") ~= rig:GetAttribute("Team") and isValidTarget(char) then
                    local Offset = char.PrimaryPart.Position - AttackPosition

                    -- Dot >= 0 means the target is within 90 degrees of either side of
                    -- the LookVector, i.e. anywhere in the 180 degree arc in front
                    if Offset.Magnitude < 6 and Offset.Unit:Dot(LookVector) >= 0 then
                        PlaySound(HIT_SOUNDS[math.random(1, #HIT_SOUNDS)], "Hit", char.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))
                        CombatService:Damage(rig, char, math.random(20, 25) * Lerp(1, aggroLevel(), 1/2.5), "PROXY_1", "DEFAULT", true, char.Torso, {})

                        if Rand:NextNumber() < 0.05 then
                            EffectService:Add(char, "Bleeding", 30)
                        end

                        if Rand:NextNumber() < 0.025 then
                            EffectService:Add(char, "Arterial Bleeding", 30)
                        end
                    end
                end
            end
        end

        TimeSinceUpdate += dt
        if TimeSinceUpdate >= UPDATE_INTERVAL then
            updateAwareness(TimeSinceUpdate)

            -- Exits Chase if awareness < 3
            if Awareness < 3 or not SensedTarget then
                CurrentState = "PATROL"
            end

            TimeSinceUpdate = 0
        end
    end

    -- Ends the retreat: phases back into visibility and becomes vulnerable again
    local function endRetreat()
        PreviousPatrolTarget = CurrentPatrolTarget
        CurrentPatrolTarget  = nil
        CurrentState         = "PATROL"

        RigClass.HealthClass.canBeAttacked = true
        rig:SetAttribute("Invisible", false)
        VFXService:GlobalVFX("Invisibility", "End", rig.PrimaryPart.CFrame, rig)

        LoadedAnims.Cloak:Stop()

        PlaySound(9126228629, "End", rig.PrimaryPart, nil, 1, 1)
        CloakAmbience.Volume = 0
    end

    -- Runs to a random patrol point like patrol mode, but stays invisible and
    -- does not look for new targets until he phases back into visibility
    local function retreat()
        if not CurrentPatrolTarget then
            CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
        end

        -- Failsafe: phases back in with or without reaching the patrol point, so a
        -- pathfinding softlock can never trap him in Retreat (a health-zero retreat
        -- still lasts its full thirty seconds)
        if os.clock() >= math.max(NextRetreatExit, RetreatStart + RETREAT_TIMEOUT) then
            endRetreat()
            return
        end

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + 1/4
            Path:Run(CurrentPatrolTarget.CFrame.Position)

            -- Phases back in once the patrol point is reached
            local Distance = (rig.PrimaryPart.CFrame.Position - CurrentPatrolTarget.CFrame.Position).Magnitude
            if Distance < 6 and os.clock() >= NextRetreatExit then
                -- Returns immediately so the cloak is not restarted below on the same tick
                endRetreat()
                return
            end
        end

        if not LoadedAnims.Cloak.IsPlaying then
            PlaySound(9120769331, "Init", rig.PrimaryPart, nil, 1, 1)
            LoadedAnims.Cloak:Play()
        end

        CloakAmbience.Volume = os.clock() >= NextRetreatExit and 1/2 or 0
    end

    LoadedAnims.Hold:Play()

    -- Initial spawning
    rig:PivotTo(pickPatrolPoint().CFrame)

    LifeConn = RunService.PreSimulation:Connect(function(dt)
        local AggroLevel = aggroLevel()

        if not rig or not rig.Parent then
            clearStalkDetection()
            releaseGrab()
            LifeConn:Disconnect()
            return
        end

        if CurrentState == "STALK" or CurrentState == "CARRY" then
            Humanoid.WalkSpeed = SPEEDS[CurrentState]
        else
            Humanoid.WalkSpeed = SPEEDS[CurrentState] * Lerp(1, AggroLevel, 1/2)
        end

        if CurrentState == "PATROL" then
            patrol(dt)
        elseif CurrentState == "CHASE" then
            chase(dt)
        elseif CurrentState == "STALK" then
            stalk(dt)
        elseif CurrentState == "GRAB" then
            grabWindup()
        elseif CurrentState == "CARRY" then
            carry(dt)
        elseif CurrentState == "RETREAT" then
            retreat()
        end

        -- Healing
        RigClass.HealthClass:Increment(dt * HEAL_RATES[CurrentState])

        -- Animations
        if CurrentState == "CARRY" then
            if LoadedAnims.Hold.IsPlaying then
                LoadedAnims.Hold:Stop()
            end
        elseif not LoadedAnims.Hold.IsPlaying then
            LoadedAnims.Hold:Play()
        end

        if os.clock() >= NextPositionCheck then
            local MoveAnim = (CurrentState == "CHASE" or CurrentState == "GRAB" or CurrentState == "RETREAT") and "Run" or "Walk"
            local OtherAnim = MoveAnim == "Run" and "Walk" or "Run"
            local MoveThreshold = (CurrentState == "STALK" or CurrentState == "CARRY") and 0.05 or 1

            NextPositionCheck = os.clock() + 1/4
            local DistanceRan = (rig.PrimaryPart.Position - LastPosition).Magnitude

            if DistanceRan > MoveThreshold and not Humanoid.FloorMaterial ~= Enum.Material.Air then
                if not LoadedAnims[MoveAnim].IsPlaying then
                    LoadedAnims[MoveAnim]:Play()
                    LoadedAnims.Idle:Stop()
                end

                -- Stops the stale movement anim left over from a previous state
                if LoadedAnims[OtherAnim].IsPlaying then
                    LoadedAnims[OtherAnim]:Stop()
                end
            else
                if LoadedAnims.Walk.IsPlaying or LoadedAnims.Run.IsPlaying then
                    LoadedAnims.Walk:Stop()
                    LoadedAnims.Run:Stop()
                    LoadedAnims.Idle:Play()
                end
            end

            LastPosition = rig.PrimaryPart.Position
        end
    end)

    -- Falling + landing animations
    local FallStart = 0
    local FallStartY : number? = nil
    Humanoid.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Freefall then
            FallStart = os.clock()
            FallStartY = FallStartY or rig.PrimaryPart.CFrame.Position.Y

            if not LoadedAnims.Fall.IsPlaying then
                LoadedAnims.Fall:Play()
            end
        else
            if LoadedAnims.Fall.IsPlaying then
                LoadedAnims.Fall:Stop()
            end

            -- Land only plays after a real fall: hopping in place when the pathfinding
            -- is stuck barely drops the rig, so those landings never retrigger it
            if new == Enum.HumanoidStateType.Landed
                and old == Enum.HumanoidStateType.Freefall
                and os.clock() - FallStart >= MIN_FALL_TIME
                and FallStartY ~= nil and FallStartY - rig.PrimaryPart.CFrame.Position.Y >= MIN_FALL_DIST
                and not LoadedAnims.Land.IsPlaying then
                -- LoadedAnims.Land:Play()
            end

            FallStartY = nil
        end
    end)

    NPCService.Client.ProxyGrabInput:Connect(handleGrabInput)

    -- Locks onto attacker whenever attacked
    CombatService.CharacterAttacked:Connect(function(attacker : Model | Player, target)
        if attacker and target == rig and CurrentState == "PATROL" then
            SensedTarget = attacker
            Awareness = 3
            updateDetection()
        end
    end)

    -- Limit
    local PrevHealth = rig:GetAttribute("Health")
    rig:GetAttributeChangedSignal("Health"):Connect(function()
        local Health = rig:GetAttribute("Health")
        local DamageTaken = math.max(PrevHealth - Health, 0)
        Limit += DamageTaken
        TotalDamage += DamageTaken

        -- Retreats if Limit is high enough
        if (Limit >= MaxLimit or Health == 0) and CurrentState ~= "RETREAT" then
            if CurrentState == "STALK" then
                StalkStart = 0
                StalkTeleportCFrame = nil
                clearStalkDetection()
            elseif CurrentState == "GRAB" then
                GrabTarget = nil
                GrabStart = 0
            elseif CurrentState == "CARRY" then
                releaseGrab()
            end

            CurrentState = "RETREAT"
            RetreatStart = os.clock()
            MaxLimit += (Limit - MaxLimit) * 4/3
            Limit = 0
            CurrentPatrolCount = 0
            CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
            resetAwareness()

            -- Phases out: invisible and immune to damage until the patrol point is reached
            RigClass.HealthClass.canBeAttacked = false
            rig:SetAttribute("Invisible", true)
            VFXService:GlobalVFX("Invisibility", "Effect", rig.PrimaryPart.CFrame, rig, INVIS_LENGTH, INVIS_STRENGTH)

            -- If health has dropped to zero
            if Health == 0 then
                NextRetreatExit = os.clock() + 30
                rig:SetAttribute("MaxHealth", rig:GetAttribute("MaxHealth") * 5/4 + (Limit - MaxLimit))
                rig:SetAttribute("Health", rig:GetAttribute("MaxHealth"))
                MaxLimit *= 0.85
                CommsService:GlobalSubtitle("PNDR-4075 has retreated for 30 seconds", Color3.fromRGB(87, 140, 84), true)
            end
        end

        PrevHealth = Health
    end)

    repeat task.wait() until not LifeConn

    if rig then
        rig:Destroy()
    end
end