-- Services
local Rand          = Random.new()
local Players       = game:GetService("Players")
local RepStorage    = game:GetService("ReplicatedStorage")
local RunService    = game:GetService("RunService")

local CharService   = _G.Knit.GetService("CharService")
local CommsService  = _G.Knit.GetService("CommsService")
local DetectService = _G.Knit.GetService("DetectionService")
local HealthService = _G.Knit.GetService("HealthService")
local RoundService  = _G.Knit.GetService("RoundService")
local VFXService    = _G.Knit.GetService("VFXService")

-- Modules and objects
local GameValues    =  RepStorage.GameValues
local Characters    = game.Workspace:WaitForChild("Characters")

local Dialog        = require(RepStorage.Modules.Data.Dialog.Tethered)
local Lerp          = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame   = require(RepStorage.Modules.Util.Math.LerpByFrame)
local SimplePath    = require(RepStorage.Modules.Util.SimplePath)

-- Vars and consts
local PHASE_IN_DIST  = 10
local PHASE_OUT_T    = 5
local MAX_DIST       = 30
local FALL_BUFFER    = 100
local SPAWN_TRIES    = 8
local MAX_SPAWN_DROP = 12

local FLASH_TYPES   = {"Flash1", "Discrete"}
local ANIMS         = {
    ["Idle"]        = {86871235948728, Enum.AnimationPriority.Idle},
    ["Run"]         = {97783720585290, Enum.AnimationPriority.Movement},
    ["Jump"]        = {71398235857727, Enum.AnimationPriority.Action2},
    ["Fall"]        = {105568355181009, Enum.AnimationPriority.Action},
    ["Land"]        = {122409291534052, Enum.AnimationPriority.Action2},
    ["Spawn"]       = {86888313607414, Enum.AnimationPriority.Action2},
}

local PUNCH_ANIMS   = {

	81455214024590,
	70601337072818,

}

-- [[ funcs ]] --

-- Generates random vector
local function randomVector()
    return Vector3.new(Rand:NextNumber(-1, 1), Rand:NextNumber(-1, 1), Rand:NextNumber(-1, 1)) * 200
end

-- Broadcasts message
local function broadcastMessage(context : string)
    local Table = Dialog[context]
    local ChosenMessage = Table[math.random(1, #Table)]
    return ChosenMessage
end

-- Counts viable players
local function getViablePlayers()
    local ViableChars = {}

    for _, char in game.Workspace:WaitForChild("Characters"):GetChildren() do
        local Plr = Players:GetPlayerFromCharacter(char)
        if char.PrimaryPart and not char:GetAttribute("beingBrainwashed") and char:GetAttribute("Team") == "Squadmates" and char:GetAttribute("isDowned") ~= true and not (Plr and Plr.Team ~= game.Teams.Squadmates) then
            table.insert(ViableChars, char)
        end
    end

    return ViableChars
end

-- Gets random target to orbit
local function getRandomTarget()
    local Chars = getViablePlayers()
    if #Chars > 0 then
        return Chars[math.random(1, #Chars)]
    end
    return nil
end

-- Finds a spot near the target with a floor beneath it; falls back to right over the target
local function findSpawnCFrame(TargetPart : BasePart) : CFrame
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Characters}

    local Origin = TargetPart.CFrame.Position

    for _ = 1, SPAWN_TRIES do
        local CFAtAngle = TargetPart.CFrame * CFrame.Angles(0, math.rad(Rand:NextNumber() * 360), 0)
        local SpawnPoint = Origin + CFAtAngle.LookVector * PHASE_IN_DIST

        -- Clamps to any wall between the target and the spot
        local WallRay = game.Workspace:Raycast(Origin, CFAtAngle.LookVector * PHASE_IN_DIST, RayParams)
        if WallRay then
            SpawnPoint = Origin:Lerp(WallRay.Position, 0.9)
        end

        -- Skips spots with no floor below (e.g. walls over deep drops)
        if game.Workspace:Raycast(SpawnPoint, Vector3.new(0, -MAX_SPAWN_DROP, 0), RayParams) then
            return CFrame.lookAt(SpawnPoint, Origin)
        end
    end

    -- No floor found nearby: spawns right over the target
    return CFrame.new(Origin) * CFrame.Angles(0, math.rad(Rand:NextNumber() * 360), 0)
end

-- Main function
return function(rig : Model)
    local Humanoid = rig:WaitForChild("Humanoid")

    local Class = CharService:GetCharacterClass(rig)
    Class.TeamClass:SetTeam("ENTITIES")

    -- Modules and objects
    local TetheredStats = Instance.new("Vector3Value")
    TetheredStats.Name = string.format("TetheredStats%.9i", math.random(0, 999999999))
    TetheredStats:SetAttribute("isPhasedIn", false)
    TetheredStats.Parent = RepStorage

    local Path = SimplePath.new(rig)
    local Class = CharService:GetCharacterClass(rig)
    Class.HealthClass.humanoidDiesOnZero = false

    -- Vars and consts
    local AggroLevel = 0
    local AttackCounter = 0
    local CurrentState = "PATROL"
    local CurrentPhasePos = Vector3.zero
    local CurrentPatrolTarget = nil
    local DamageLimit = 65
    local DamageSustained = 0
    local DetectionRadius = 0
    local DetectionLevel = 0
    local DownedTill = os.clock()
    local foundTarget = false
    local LastPosition = rig.PrimaryPart.Position
    local NextAbility = 0
    local NextAttack = 0
    local NextPathRun = 0
    local NextPhaseOut = 0
    local NextPositionCheck = os.clock()
    local NextStateChange = 0
    local PhaseSpeed = 0
    local surprisePlayer = false
    local TotalDamageSustained = 0

    local ChaseFails = 0

    local TargetPhasePos = randomVector()

    local LoadedAnims  = {}
    for tag, id in ANIMS do
        local Animation = Instance.new("Animation")
        Animation.AnimationId = "rbxassetid://"..id[1]
        local LoadedAnim : AnimationTrack = rig:WaitForChild("Humanoid").Animator:LoadAnimation(Animation)
        LoadedAnim.Looped = not table.find({"Jump", "Land", "Spawn"}, tag)
        LoadedAnim.Priority = id[2]
        LoadedAnims[tag] = LoadedAnim
    end

    local PunchingAnims = {}
	for _, anim in pairs(PUNCH_ANIMS) do
		local ThisAnim = Instance.new("Animation")
		ThisAnim.AnimationId = "rbxassetid://"..anim
		local LoadedAnim = rig.Humanoid.Animator:LoadAnimation(ThisAnim)
        LoadedAnim.Priority = Enum.AnimationPriority.Action4
        LoadedAnim.Looped = false
		ThisAnim:Destroy()

		table.insert(PunchingAnims, LoadedAnim)
	end

    -- Landing animation
    Humanoid.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Landed then
            LoadedAnims.Land:Play()
        end
    end)

    -- [[ funcs ]] --

    -- Calculates aggro level
    local function aggroLevel() : number
        return 1 + ((ChaseFails / 15) + (TotalDamageSustained / 1500)) / 2
    end

    -- Floating toward target
    local function floatTowardTarget(dt)
        CurrentPhasePos -= (CurrentPhasePos - TargetPhasePos).Unit * PhaseSpeed * dt
        TetheredStats.Value = CurrentPhasePos
    end

    -- Determines if having reached target
    local function hasReachedTarget(callback : () -> ())
        local Distance = (CurrentPhasePos - TargetPhasePos).Magnitude
        if Distance < 1 then
            callback()
        end
    end

    -- Resets ability interval
    local function abilityInterval()
        local NodeProgress = RoundService:NodeProgress()
        NextAbility = os.clock() + Rand:NextNumber(
            Lerp(1.5, 5, NodeProgress),
            Lerp(15, 60, NodeProgress)
        )
    end

    -- Patrolling
    local function patrol(dt)
        if os.clock() < DownedTill then return end
        NextAbility += dt

        if not TargetPhasePos then
            local Target = getRandomTarget()
            if not Target then return end -- no viable players to orbit right now
            TargetPhasePos = Target.PrimaryPart.CFrame.Position + randomVector()
        end

        -- Movement
        floatTowardTarget(dt)
        hasReachedTarget(function()
            local Target = getRandomTarget()
            if Target then
                TargetPhasePos = Target.PrimaryPart.CFrame.Position + randomVector()
            end
        end)

        -- Scans for targets
        DetectionRadius += dt * (6 + AggroLevel * 3)
        PhaseSpeed = math.min(PhaseSpeed + dt * (1/4) * (AggroLevel * 4), 100)

        local Chars = Characters:GetChildren()
        for _, plr in game.Teams.Squadmates:GetPlayers() do
            table.insert(Chars, plr.Character or plr.CharacterAdded:Wait())
        end

        for _, char : Model in Chars do
            local PrimaryPart = char.PrimaryPart
            if not PrimaryPart then continue end -- character mid-unload (e.g. corpse fell out of the world)

            if char:GetAttribute("Team") ~= rig:GetAttribute("Team") then
                local Distance = (PrimaryPart.Position - CurrentPhasePos).Magnitude
                local Noise = char:GetAttribute("Noise")

                if Noise ~= nil and (Noise >= Distance or (DetectionRadius >= Distance and Noise > 1)) then
                    DetectionLevel += dt * (1 + ((AggroLevel - 1) / 5))
                    if DetectionLevel >= 1 and os.clock() >= NextStateChange and not foundTarget then
                        foundTarget = true
                        NextStateChange = os.clock() + 1/4
                        CurrentState = "STALK"
                        CurrentPatrolTarget = char
                        
                        surprisePlayer = Rand:NextNumber(0, 1) <= 0.1 + AggroLevel / 12.5
                        local FoundPlayer = Players:GetPlayerFromCharacter(char)

                        if not surprisePlayer and FoundPlayer then
                            local Message = broadcastMessage("PATROL_SPOT")
                            VFXService:PlayVFX(FoundPlayer, "Tethered", FLASH_TYPES[math.random(1, #FLASH_TYPES)], CurrentPhasePos, Message, CurrentPhasePos)
                            -- DetectService:DetectPlayer(rig, char, 2)
                        end
                    end
                end
            end
        end

        if not foundTarget then
            DetectionLevel = math.max(DetectionLevel - dt / 2, 0)
        end
    end

    -- Stalking
    local function stalk(dt)
        local TargetPart = CurrentPatrolTarget and CurrentPatrolTarget:FindFirstAncestor("Characters") and CurrentPatrolTarget.PrimaryPart
        NextAbility += dt

        if TargetPart then
            PhaseSpeed = Lerp(PhaseSpeed, 30, LerpByFrame(1/400, dt))

            TargetPhasePos = TargetPart.CFrame.Position
            floatTowardTarget(dt)
            hasReachedTarget(function()
                rig.Parent = Characters

                -- Finds spot around character to teleport (with a floor beneath it)
                local SpawnCFrame = findSpawnCFrame(TargetPart)

                for i = 1, 10 do
                    rig:PivotTo(SpawnCFrame)
                end

                VFXService:GlobalVFX("Tethered", "Phase", rig.PrimaryPart.CFrame, rig, rig.PrimaryPart.CFrame)

                NextPhaseOut = os.clock() + PHASE_OUT_T
                local Message = broadcastMessage("ATTACK_INIT")
                
                if surprisePlayer then
                    DetectService:DetectPlayer(rig, CurrentPatrolTarget, 3)
                    local Player = Players:GetPlayerFromCharacter(CurrentPatrolTarget)
                    if Player then
                        VFXService:PlayVFX(Player, "Tethered", "Surprise", rig.PrimaryPart.CFrame.Position or CurrentPhasePos or Vector3.zero, rig, Message)
                    end
                end

                TetheredStats:SetAttribute("isPhasedIn", true)
                DamageSustained = 0
                CurrentState = "ATTACK"
                
                if NextAbility == 0 then
                    abilityInterval()
                end

                LoadedAnims.Run:Play()
                LoadedAnims.Spawn:Play()
            end)
        else
            CurrentPatrolTarget = nil
            CurrentState = "PATROL"
        end
    end

    -- Attacking
    local function attack(dt)
        Humanoid.WalkSpeed = (20 + (1.5 * (AggroLevel - 1))) * (LoadedAnims.Spawn.IsPlaying and 0.1 or 1)

        -- Finds enemy to attack
        local Chars = Characters:GetChildren()
        for _, plr in game.Teams.Squadmates:GetPlayers() do
            table.insert(Chars, plr.Character or plr.CharacterAdded:Wait())
        end

        local ClosestChar, ClosestDistance = nil, math.huge
        for _, char : Model in Chars do
            local PrimaryPart = char.PrimaryPart
            if not PrimaryPart then continue end -- character mid-unload (e.g. corpse fell out of the world)

            if char:GetAttribute("Team") ~= rig:GetAttribute("Team") then
                local Distance = (PrimaryPart.Position - rig.PrimaryPart.CFrame.Position).Magnitude
                if Distance < ClosestDistance then
                    ClosestChar = char
                    ClosestDistance = Distance
                end
            end
        end

        if ClosestChar and ClosestChar.PrimaryPart and os.clock() >= NextPathRun then
            NextPathRun = os.clock() + 2/3
            Path:Run(ClosestChar.PrimaryPart.CFrame.Position)

            -- Detection statuses
            for _, char in Characters:GetChildren() do
                DetectService:DetectPlayer(rig, char, char == ClosestChar and 3 or 0)
            end

            -- Delays phase-out if close enough
            if ClosestDistance <= MAX_DIST then
                NextPhaseOut = os.clock() + PHASE_OUT_T
            end
        end

        -- Attcks target if close enough
        if ClosestChar and ClosestDistance <= 6 and os.clock() >= NextAttack then
            NextAttack = os.clock() + 1/2
            AttackCounter += 1

            local ChosenAnim = PunchingAnims[(AttackCounter % 2) + 1]
            ChosenAnim:Play()

            local TargetClass = CharService:GetCharacterClass(ClosestChar)
            TargetClass.SanityClass:Damage(Rand:NextNumber(5, 22))
        end

        -- Running animation
        if os.clock() >= NextPositionCheck then
            NextPositionCheck = os.clock() + 1/4
            local DistanceRan = (rig.PrimaryPart.Position - LastPosition).Magnitude
            
            if DistanceRan > 1 then
                if not LoadedAnims.Run.IsPlaying then
                    LoadedAnims.Run:Play()
                    LoadedAnims.Idle:Stop()
                end
            else
                if LoadedAnims.Run.IsPlaying then
                    LoadedAnims.Run:Stop()
                    LoadedAnims.Idle:Play()
                end
            end

            LastPosition = rig.PrimaryPart.Position
        end

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

        local healthZero = rig:GetAttribute("Health") == 0
        local limitReached = DamageSustained >= DamageLimit or healthZero
        local tooFarAway = ClosestDistance > MAX_DIST and os.clock() >= NextPhaseOut

        -- Ability
        local NodeProgress = RoundService:NodeProgress()
        if NodeProgress > 0 and os.clock() >= NextAbility then
            abilityInterval()

            -- picks ability
            local Abilities = {}
            for _, ability in script:GetChildren() do
                local AbilityModule = require(ability)
                if NodeProgress >= AbilityModule.MIN_PROGRESS then
                    table.insert(Abilities, ability)
                end
            end

            -- Picks ability
            if #Abilities > 0 then
                local ChosenAbility = Abilities[math.random(1, #Abilities)]
                require(ChosenAbility).Function(rig, ClosestChar)
            end
        end

        -- Falls at least 100 studs below the closest target
        local fellBelow = ClosestChar and ClosestChar.PrimaryPart
            and (ClosestChar.PrimaryPart.Position.Y - rig.PrimaryPart.Position.Y) > 100

        -- Phases out if condition met
        if #getViablePlayers() == 0 or fellBelow or ((limitReached or tooFarAway) and os.clock() >= NextStateChange) then
            NextStateChange = os.clock() + 1/4
            rig.Parent = RepStorage
            ChaseFails += 1
            DetectionRadius = 0
            PhaseSpeed = 0
            CurrentPhasePos = randomVector()
            
            local NewTarget = getRandomTarget()
            if NewTarget then
                TargetPhasePos = NewTarget.PrimaryPart.CFrame.Position + randomVector()
            else
                TargetPhasePos = nil
            end

            CurrentPatrolTarget = nil
            foundTarget = false
            surprisePlayer = false
            CurrentState = "PATROL"
            TetheredStats:SetAttribute("isPhasedIn", false)

            local Message = broadcastMessage(limitReached and "PHASE_OUT_HURT" or "PHASE_OUT_FAR")
            local PrevAggroLevel = math.floor(AggroLevel)
            AggroLevel += DamageSustained / 1000
            DamageLimit += DamageSustained / 4
            local NewAggroLevel = math.floor(AggroLevel)
            local AggroMessage = broadcastMessage("AGGRO_LEVEL_RAISE")

            if healthZero then
                AggroLevel += 0.175
                rig:SetAttribute("MaxHealth", rig:GetAttribute("MaxHealth") + DamageSustained / 3)
                HealthService:Heal(rig, DamageSustained / 2)

                DownedTill = os.clock() + 30
                VFXService:GlobalVFX("Tethered", "Phase", rig.PrimaryPart.CFrame, rig, rig.PrimaryPart.CFrame)
                for _, plr in game.Teams.Squadmates:GetPlayers() do
                    CommsService:SendSubtitle(nil, plr, "PNDR-0770 has retreated for 30 seconds", Color3.fromRGB(105, 115, 255))
                end
                TetheredStats:SetAttribute("isPhasedIn", true)
                task.delay(30, function()
                    TetheredStats:SetAttribute("isPhasedIn", false)
                end)
            end

            if NewAggroLevel > PrevAggroLevel then
                print("WARNING: Tethered's Aggro Level has risen to Level", NewAggroLevel)
            end

            for _, char in Characters:GetChildren() do
                DetectService:DetectPlayer(rig, char, 0, true)
                local Player = Players:GetPlayerFromCharacter(char)
                if Player then
                    VFXService:PlayVFX(Player, "Tethered", "Flash1", rig.PrimaryPart.CFrame.Position or CurrentPhasePos or Vector3.zero, Message)

                    task.spawn(function() -- warns players that Tethered's aggro level has risen
                        if NewAggroLevel > PrevAggroLevel then
                            task.wait(Rand:NextNumber(1, 3))
                            VFXService:PlayVFX(Player, "Tethered", "Flash1", rig.PrimaryPart.CFrame.Position or CurrentPhasePos or Vector3.zero, AggroMessage)
                        end
                    end)
                end

                task.delay(1/4, function()
                    DetectService:DetectPlayer(rig, char, 0, true)
                end)
            end
        end
    end

    -- Main behavior
    task.spawn(function()
        repeat task.wait() until _G.Knit.Loaded

        rig:SetAttribute("Health", 150)
        rig:SetAttribute("MaxHealth", 150)

        -- Places in rep. storage
        repeat
            rig.Parent = RepStorage
            RunService.PreSimulation:Wait()
        until rig.Parent == RepStorage and #game.Teams.Squadmates:GetPlayers() > 0

        -- Toggles can-collide
        for _, part in rig:GetDescendants() do
            if part:IsA("BasePart") and not part:FindFirstAncestor("Hitbox") then
                part.CanCollide = false
                part.CanQuery = part.Name == "HumanoidRootPart"
                part.CanTouch = part.CanQuery
                part.AudioCanCollide = false
            end
        end

        -- Damage
        local PrevHealth = rig:GetAttribute("Health")
        local DamageEvent = rig:GetAttributeChangedSignal("Health"):Connect(function()
            local Health = rig:GetAttribute("Health")
            if Health < PrevHealth then
                local DS = PrevHealth - Health
                DamageSustained += DS
                TotalDamageSustained += DS
            end

            PrevHealth = rig:GetAttribute("Health")
        end)

        local LifeConn : RBXScriptSignal = nil
        LifeConn = RunService.PreSimulation:Connect(function(dt)
            -- Rig destroyed or parts unloaded (e.g. fell out of the world): stop cleanly
            if not rig.Parent or not rig.PrimaryPart then
                LifeConn:Disconnect()
                LifeConn = nil
                return
            end

            -- Recovers before parts fall below the destroy height
            if rig.PrimaryPart.Position.Y < game.Workspace.FallenPartsDestroyHeight + FALL_BUFFER then
                rig:PivotTo(CFrame.new(LastPosition + Vector3.yAxis * 5))
                rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            end

            if #getViablePlayers() > 0 and GameValues.Numbers.TimeLeft.Value > 0 then
                AggroLevel = aggroLevel()
                rig:SetAttribute("AggroLevel", AggroLevel)

                if CurrentState ~= "ATTACK" then
                    HealthService:Heal(rig, dt * 9/8 * Lerp(1, AggroLevel, 1/2))
                end

                if CurrentState == "PATROL" then
                    patrol(dt)
                elseif CurrentState == "STALK" then
                    stalk(dt)
                elseif CurrentState == "ATTACK" then
                    attack(dt)
                end 
            else
                if #game.Teams.Squadmates:GetPlayers() == 0 then
                    LifeConn:Disconnect()
                    LifeConn = nil
                end
            end
        end)

        repeat task.wait() until not LifeConn

        -- Broadcasts goodbye message
        if #game.Teams.Squadmates:GetPlayers() == 0 then
            print(broadcastMessage("NO_MORE_PLAYERS"))
        end

        TetheredStats:Destroy()
        rig:Destroy()
    end)
end