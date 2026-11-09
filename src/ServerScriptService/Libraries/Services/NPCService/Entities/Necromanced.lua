-- Services
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

local CharService     = _G.Knit.GetService("CharService")
local CombatService   = _G.Knit.GetService("CombatService")
local DetectService   = _G.Knit.GetService("DetectionService")

-- Modules and objects
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)
local SimplePath      = require(RepStorage.Modules.Util.SimplePath)

-- Vars and consts
local ANIMS         = {
    ["Idle"]        = {88621504256286, Enum.AnimationPriority.Idle},
    ["Follow"]      = {89637238529940, Enum.AnimationPriority.Movement},
    ["Chase"]       = {121987424972667, Enum.AnimationPriority.Movement},
    ["Spawn"]       = {125353215139142, Enum.AnimationPriority.Action4},
}

local ATTACK_ANIMS  = {14155745294, 14155752551}

local AGGRO_SOUNDS  = {131138832, 131138835, 131138848, 131060145}
local DEATH_SOUNDS  = {131138839, 131138845, 131138850}
local ATTACK_SOUND  = 6884257732

local SPEEDS        = {
    FOLLOW          = 16,
    CHASE           = 32,
}

local MAX_HEALTH    = 80

-- Sensing is radial: any hostile within AGGRO_RANGE is detected instantly, even
-- through walls; the chase holds until the target escapes past LEASH_RANGE.
-- Both limits are ignored once every Node is calibrated: he then senses and runs
-- down the nearest target no matter where they are
local AGGRO_RANGE   = 40
local LEASH_RANGE   = 120

local ATTACK_RANGE    = 6
local ATTACK_INTERVAL = 2/3

-- Idle patrol: hovers around a slowly re-rolled offset from the Proxy; unlike the
-- Proxy he never teleports when left behind, and just paths back on his own
local MIN_OFFSET      = 5
local MAX_OFFSET      = 20
local OFFSET_MIN_TIME = 5   -- shortest time between patrol offset re-rolls
local OFFSET_MAX_TIME = 20  -- longest time between patrol offset re-rolls

-- Anti-softlock: landing no attack for this long while chasing (without closing
-- in) drops the target so the Necromanced returns to its Proxy instead of wedging
local CHASE_TIMEOUT   = 15

local UPDATE_INTERVAL = 1/4 -- seconds between path re-runs and movement checks

-- [[ funcs ]] --

-- A target only counts while it is alive, still in the world, and not grabbed
local function isValidTarget(char : Model?) : boolean
    if not char or not char.Parent or not char.PrimaryPart or char:GetAttribute("isGrabbed") == true then
        return false
    end

    local Hum = char:FindFirstChildOfClass("Humanoid")
    return Hum ~= nil and Hum.Health > 0 and (char:GetAttribute("Health") or 0) > 0
end

-- Picks a random point on the ring between MIN_OFFSET and MAX_OFFSET studs out
local function pickOffset() : Vector3
    local function axis() : number
        return math.max(Rand:NextNumber(0, MAX_OFFSET), MIN_OFFSET) * (Rand:NextInteger(0, 1) == 1 and 1 or -1)
    end

    return Vector3.new(axis(), 0, axis())
end

return function(rig : Model)
    task.spawn(function()
        -- Vars and consts
        local AttackCount = 0
        local ChaseAnchorDistance : number? = nil -- distance to the target when the current timeout window began
        local CurrentState = "FOLLOW"
        local CurrentTarget : Model? = nil
        local FollowAnchor : Model? = nil -- the living Proxy this Necromanced is bound to
        local LastAttack = os.clock()
        local LastDetectedTarget : Model? = nil -- target currently shown a detection indicator
        local LastPosition : Vector3 = rig.PrimaryPart.CFrame.Position
        local NextAttack = 0
        local NextMoveCheck = 0
        local NextOffsetRoll = 0
        local NextPathRun = 0
        local PreferredOffset = pickOffset()

        -- Sets stuff up
        local LifeConn : RBXScriptConnection
        local Path = SimplePath.new(rig)

        local NodesLeft = RepStorage.GameValues.Numbers.NodesLeft

        local RigClass = CharService:GetCharacterClass(rig)

        rig:SetAttribute("MaxHealth", MAX_HEALTH)
        rig:SetAttribute("Health", MAX_HEALTH)

        local Humanoid : Humanoid = rig:FindFirstChildOfClass("Humanoid")

        local LoadedAnims  = {}
        for tag, info in ANIMS do
            local Animation = Instance.new("Animation")
            Animation.AnimationId = "rbxassetid://"..info[1]
            local LoadedAnim : AnimationTrack = Humanoid.Animator:LoadAnimation(Animation)
            LoadedAnim.Priority = info[2]
            LoadedAnim.Looped = tag ~= "Spawn"
            LoadedAnims[tag] = LoadedAnim
            Animation:Destroy()
        end

        local AttackAnims = {}
        for _, id in ATTACK_ANIMS do
            local Animation = Instance.new("Animation")
            Animation.AnimationId = "rbxassetid://"..id
            local LoadedAnim = Humanoid.Animator:LoadAnimation(Animation)
            LoadedAnim.Priority = Enum.AnimationPriority.Action4
            LoadedAnim.Looped = false
            Animation:Destroy()

            table.insert(AttackAnims, LoadedAnim)
        end

        local Breathing = Instance.new("Sound")
        Breathing.Name = "Breathing"
        Breathing.SoundId = "rbxassetid://905282283"
        Breathing.Looped = true
        Breathing.Parent = rig.PrimaryPart

        -- Finds the living Proxy this Necromanced follows; wanders in place while none exists
        local function findProxy() : Model?
            if FollowAnchor and FollowAnchor.Parent and FollowAnchor.PrimaryPart then
                local AnchorHumanoid = FollowAnchor:FindFirstChildOfClass("Humanoid")
                if AnchorHumanoid and AnchorHumanoid.Health > 0 then
                    return FollowAnchor
                end
            end

            FollowAnchor = nil
            local Characters = game.Workspace:FindFirstChild("Characters")
            local ProxyRig = Characters and Characters:FindFirstChild("Proxy")
            if ProxyRig and ProxyRig.PrimaryPart then
                local AnchorHumanoid = ProxyRig:FindFirstChildOfClass("Humanoid")
                if AnchorHumanoid and AnchorHumanoid.Health > 0 then
                    FollowAnchor = ProxyRig
                end
            end

            return FollowAnchor
        end

        -- Senses the nearest hostile character; purely radial, so neither walls
        -- nor facing hide anyone within range
        local function senseTarget() : (Model?, number)
            local Origin = rig.PrimaryPart.CFrame.Position
            local NearestTarget = nil
            local NearestDistance = math.huge

            for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
                if char ~= rig and char:GetAttribute("Team") ~= rig:GetAttribute("Team") and isValidTarget(char) then
                    local Distance = (char.PrimaryPart.CFrame.Position - Origin).Magnitude
                    if Distance < NearestDistance then
                        NearestTarget = char
                        NearestDistance = Distance
                    end
                end
            end

            return NearestTarget, NearestDistance
        end

        -- [[ Main life cycle ]] --

        -- Alerts players of detection: full level while chased, cleared when the
        -- target is dropped or the Necromanced dies
        local function updateDetection(Target : Model?)
            if Target == LastDetectedTarget then
                return
            end

            if LastDetectedTarget and LastDetectedTarget.Parent then
                DetectService:DetectPlayer(rig, LastDetectedTarget, 0)
            end

            if Target then
                DetectService:DetectPlayer(rig, Target, 3)
            end

            LastDetectedTarget = Target
        end

        -- Patrols within close vicinity of the Proxy, watching for targets
        local function follow()
            if os.clock() >= NextOffsetRoll then
                NextOffsetRoll = os.clock() + Rand:NextNumber(OFFSET_MIN_TIME, OFFSET_MAX_TIME)
                PreferredOffset = pickOffset()
            end

            local ProxyRig = findProxy()
            local AnchorPosition = ProxyRig and ProxyRig.PrimaryPart.CFrame.Position or rig.PrimaryPart.CFrame.Position
            local IdealPosition = AnchorPosition + PreferredOffset

            if os.clock() >= NextPathRun then
                NextPathRun = os.clock() + UPDATE_INTERVAL
                Path:Run(IdealPosition)
                -- Path:Run yields; bail out if sensing below already switched the state
                if CurrentState ~= "FOLLOW" then
                    return
                end
            end

            -- Switches to chase when a hostile wanders into sensing range; with
            -- every Node calibrated he locks onto the nearest one at any distance
            local Target, Distance = senseTarget()
            if Target and (NodesLeft.Value == 0 or Distance < AGGRO_RANGE) then
                CurrentTarget = Target
                CurrentState = "CHASE"
                ChaseAnchorDistance = nil
                LastAttack = os.clock()
                NextPathRun = 0
                updateDetection(Target)

                PlaySound(AGGRO_SOUNDS[Rand:NextInteger(1, #AGGRO_SOUNDS)], "Aggro", rig.PrimaryPart, nil, 1.25, Rand:NextNumber(0.95, 1.05))
            end
        end

        -- Runs down and attacks the sensed target until it dies or escapes
        local function chase()
            -- Dead, removed, or escaped targets are dropped so the Necromanced
            -- returns to its Proxy instead of attacking a corpse
            local Distance = isValidTarget(CurrentTarget)
                and (CurrentTarget.PrimaryPart.CFrame.Position - rig.PrimaryPart.CFrame.Position).Magnitude
                or math.huge

            -- The leash only applies while Nodes remain: with every Node calibrated
            -- he never lets a living target go
            if not isValidTarget(CurrentTarget) or (NodesLeft.Value > 0 and Distance >= LEASH_RANGE) then
                CurrentTarget = nil
                CurrentState = "FOLLOW"
                updateDetection(nil)
                return
            end

            -- Anti-softlock: if he has landed no attack for too long while chasing,
            -- he drops the target and re-paths instead of staying stuck on the map
            ChaseAnchorDistance = ChaseAnchorDistance or Distance
            if os.clock() - LastAttack >= CHASE_TIMEOUT then
                -- Closing in on the target is progress, not a softlock: re-anchor
                -- the distance and grant another full window instead of giving up
                if Distance < ChaseAnchorDistance then
                    ChaseAnchorDistance = Distance
                    LastAttack = os.clock()
                else
                    CurrentTarget = nil
                    CurrentState = "FOLLOW"
                    updateDetection(nil)
                    return
                end
            end

            if os.clock() >= NextPathRun then
                NextPathRun = os.clock() + UPDATE_INTERVAL
                Path:Run(CurrentTarget.PrimaryPart.CFrame.Position)
                -- Path:Run yields; bail out if the target was dropped while it ran
                if CurrentState ~= "CHASE" or not isValidTarget(CurrentTarget) then
                    return
                end
            end

            -- Attacking
            if Distance < ATTACK_RANGE and os.clock() >= NextAttack then
                NextAttack = os.clock() + ATTACK_INTERVAL
                LastAttack = os.clock()
                ChaseAnchorDistance = nil -- re-anchors at the post-attack distance on the next tick
                AttackCount += 1

                AttackAnims[(AttackCount % #AttackAnims) + 1]:Play()
                PlaySound(ATTACK_SOUND, "Attack", CurrentTarget.PrimaryPart, nil, 1.25, Rand:NextNumber(0.95, 1.05))
                CombatService:Damage(rig, CurrentTarget, math.random(15, 20), "NECROMANCED", "DEFAULT", true, CurrentTarget:FindFirstChild("Torso"), nil)
            end
        end

        -- Spawn intro: plays once while the Necromanced cannot be hurt
        RigClass.HealthClass.canBeAttacked = false
        LoadedAnims.Spawn:Play()
        Breathing:Play()
        task.wait(5)
        LoadedAnims.Spawn:Stop()
        RigClass.HealthClass.canBeAttacked = true
        LoadedAnims.Idle:Play()

        -- [[ Main loop ]] --

        LifeConn = RunService.PreSimulation:Connect(function()
            if not rig or not rig.Parent then
                updateDetection(nil)
                LifeConn:Disconnect()
                LifeConn = nil
                return
            end

            -- Dead: HealthService replaces the rig with a client ragdoll and cleans
            -- it up, so the behavior just stops here
            if Humanoid.Health <= 0 or (rig:GetAttribute("Health") or 0) <= 0 then
                for _, anim in LoadedAnims do
                    anim:Stop()
                end

                updateDetection(nil)
                Breathing:Stop()
                LifeConn:Disconnect()
                LifeConn = nil
                return
            end

            Humanoid.WalkSpeed = SPEEDS[CurrentState]

            if CurrentState == "FOLLOW" then
                follow()
            elseif CurrentState == "CHASE" then
                chase()
            end

            -- Movement anims: plays the state's gait while moving, idles otherwise
            if os.clock() >= NextMoveCheck then
                NextMoveCheck = os.clock() + UPDATE_INTERVAL

                local MoveAnim = CurrentState == "CHASE" and "Chase" or "Follow"
                local OtherAnim = MoveAnim == "Chase" and "Follow" or "Chase"
                local DistanceRan = (rig.PrimaryPart.CFrame.Position - LastPosition).Magnitude
                LastPosition = rig.PrimaryPart.CFrame.Position

                if DistanceRan > 1 then
                    if not LoadedAnims[MoveAnim].IsPlaying then
                        LoadedAnims[MoveAnim]:Play()
                        LoadedAnims.Idle:Stop()
                    end

                    -- Stops the stale gait left over from the other state
                    if LoadedAnims[OtherAnim].IsPlaying then
                        LoadedAnims[OtherAnim]:Stop()
                    end
                else
                    if LoadedAnims.Follow.IsPlaying or LoadedAnims.Chase.IsPlaying then
                        LoadedAnims.Follow:Stop()
                        LoadedAnims.Chase:Stop()
                        LoadedAnims.Idle:Play()
                    end
                end
            end
        end)

        Humanoid.Died:Connect(function()
            Breathing:Stop()
            PlaySound(DEATH_SOUNDS[Rand:NextInteger(1, #DEATH_SOUNDS)], "Death", rig.PrimaryPart, nil, 1.25, Rand:NextNumber(0.95, 1.05))
        end)

        repeat task.wait() until not LifeConn
    end)
end
