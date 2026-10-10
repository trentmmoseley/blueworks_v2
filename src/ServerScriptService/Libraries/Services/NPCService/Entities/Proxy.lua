-- Services
local Players         = game:GetService("Players")
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

local CharService     = _G.Knit.GetService("CharService")
local CombatService   = _G.Knit.GetService("CombatService")
local DetectService   = _G.Knit.GetService("DetectionService")
local VFXService      = _G.Knit.GetService("VFXService")

-- Modules and objects
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)
local SimplePath      = require(RepStorage.Modules.Util.SimplePath)

-- Vars and consts
local PATROL_INTERVAL = 3

local ANIMS         = {
    ["Idle"]        = {91585323243859, Enum.AnimationPriority.Idle},
    ["Run"]         = {81207900885640, Enum.AnimationPriority.Action},
    ["Walk"]        = {89468869841055, Enum.AnimationPriority.Movement},
    ["Hold"]        = {96432749173875, Enum.AnimationPriority.Action3},
    ["Jump"]        = {116496690680898, Enum.AnimationPriority.Action2},
    ["Fall"]        = {119528283195927, Enum.AnimationPriority.Action},
    ["Land"]        = {70926104383734, Enum.AnimationPriority.Action2},
}

local ATTACK_ANIMS  = {97633645023236, 126985686457998, 123162586564812, 94060623091801}
local ATTACK_SOUNDS = {7801336419, 7801329626}
local HIT_SOUNDS    = {18512265986, 18512270266}

local SPEEDS        = {
    PATROL          = 8,
    CHASE           = 21
}

local SENSE_ADVANCE  = 1/4 -- seconds of sensing a player needed to raise one Awareness level
local SENSE_DECAY    = 5   -- seconds of sensing no one needed to drop one Awareness level
local CHASE_LEVEL    = 3   -- Awareness level at which the Brainwashed enters CHASE

local SIGHT_RANGE    = 1000 -- max distance in studs the Brainwashed can see
local SIGHT_FOV      = 0.5  -- minimum facing alignment (LookVector dot direction) needed to see a target

local UPDATE_INTERVAL = 1/4 -- seconds between awareness checks and path re-runs

local ATTACK_INTERVAL = 3/4

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

-- A target only counts while it is alive and still in the world; corpses and
-- removed rigs must never keep the Proxy's attention
local function isValidTarget(char : Model?) : boolean
    if not char or not char.Parent or not char.PrimaryPart then
        return false
    end

    local Hum = char:FindFirstChildOfClass("Humanoid")
    return Hum ~= nil and Hum.Health > 0 and (char:GetAttribute("Health") or 0) > 0
end

return function(rig : Model)
    -- Vars and consts
    local Awareness = 0 -- 0 = unaware, 1 = sensing, 2 = following, 3 = chase
    local CurrentPatrolCount = 0
    local CurrentPatrolTarget : Part? = pickPatrolPoint()
    local CurrentState = "PATROL"
    local NextAttack = 0
    local NextPathRun = 0
    local NextPositionCheck = 0
    local LastPosition : Vector3? = rig.PrimaryPart.CFrame.Position
    local LastTarget : Model? = nil
    local LastLevel = 0
    local PreviousPatrolTarget = nil
    local SensedTarget = nil
    local TimeSinceUpdate = 0

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

    -- [[ Main life cycle ]] --

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

        for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
            if char ~= rig and char:GetAttribute("Team") ~= rig:GetAttribute("Team") and isValidTarget(char) then
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

    local function patrol(dt)
        if not CurrentPatrolTarget then
           CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
           CurrentPatrolCount += 1
        end

        TimeSinceUpdate += dt

        if os.clock() >= NextPathRun then
            NextPathRun = os.clock() + 1/4
            Path:Run((Awareness < 2 or not isValidTarget(SensedTarget)) and CurrentPatrolTarget.CFrame.Position or SensedTarget.PrimaryPart.CFrame.Position)

            -- Choose new target if destination reached
            local Distance = (rig.PrimaryPart.CFrame.Position - CurrentPatrolTarget.CFrame.Position).Magnitude
            if Distance < 6 then
                PreviousPatrolTarget = CurrentPatrolTarget
                CurrentPatrolTarget = nil

                if CurrentPatrolCount >= 3 then
                    CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
                    rig:PivotTo(CurrentPatrolTarget.CFrame)
                    CurrentPatrolCount = 0
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
                local Intensity = 1
                local Distances = {50, 20}

                local DistanceFromTarget = (rig.PrimaryPart.CFrame.Position - SensedTarget.PrimaryPart.CFrame.Position).Magnitude
                for i, dist in Distances do
                    if DistanceFromTarget < dist then
                        Intensity += 1
                    end
                end

                VFXService:PlayVFX(ChasingPlayer, "Horror", "Horror", rig.PrimaryPart.CFrame, Intensity)
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

            -- Hit detection
            local RayParams = RaycastParams.new()
            RayParams.FilterType = Enum.RaycastFilterType.Exclude
            RayParams.FilterDescendantsInstances = {rig}

            PlaySound(HIT_SOUNDS[math.random(1, #HIT_SOUNDS)], "Hit", SensedTarget.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))
            CombatService:Damage(rig, SensedTarget, math.random(20, 25), "PROXY", "DEFAULT", true, SensedTarget.Torso, {})
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

    LoadedAnims.Hold:Play()

    LifeConn = RunService.PreSimulation:Connect(function(dt)
        if not rig or not rig.Parent then
            LifeConn:Disconnect()
            return
        end

        Humanoid.WalkSpeed = SPEEDS[CurrentState]
        if CurrentState == "PATROL" then
            patrol(dt)
        elseif CurrentState == "CHASE" then
            chase(dt)
        end

        -- Animations
        if os.clock() >= NextPositionCheck then
            local MoveAnim = CurrentState == "CHASE" and "Run" or "Walk"

            NextPositionCheck = os.clock() + 1/4
            local DistanceRan = (rig.PrimaryPart.Position - LastPosition).Magnitude
            
            if DistanceRan > 1 and not Humanoid.FloorMaterial ~= Enum.Material.Air then
                if not LoadedAnims[MoveAnim].IsPlaying then
                    LoadedAnims[MoveAnim]:Play()
                    LoadedAnims.Idle:Stop()
                end
            else
                if LoadedAnims[MoveAnim].IsPlaying then
                    LoadedAnims.Walk:Stop()
                    LoadedAnims.Run:Stop()
                    LoadedAnims.Idle:Play()
                end
            end

            LastPosition = rig.PrimaryPart.Position
        end
    end)

    -- Falling animation
    if Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        if not LoadedAnims.Fall.IsPlaying then
            LoadedAnims.Fall:Play()
        end
    else
        if LoadedAnims.Fall.IsPlaying then
            LoadedAnims.Fall:Stop()
        end
    end

    -- Landing animation
    Humanoid.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Landed then
            -- LoadedAnims.Land:Play()
        end
    end)

    -- Limit
    local PrevHealth = rig:GetAttribute("Health")
    rig:GetAttributeChangedSignal("Health"):Connect(function()
        local Health = rig:GetAttribute("Health")
        local DamageTaken = math.max(PrevHealth - Health, 0)
        Limit += DamageTaken

        -- Retreats if Limit is high enough
        if Limit >= MaxLimit then
            CurrentState = "PATROL"
            MaxLimit += (Limit - MaxLimit) * 4/3
            Limit = 0
            CurrentPatrolCount = 0
            CurrentPatrolTarget = pickPatrolPoint(PreviousPatrolTarget)
            SensedTarget = nil
            Awareness = 0
            rig:PivotTo(CurrentPatrolTarget.CFrame)
        end

        PrevHealth = Health
    end)

    repeat task.wait() until not LifeConn

    if rig then
        rig:Destroy()
    end
end