-- Services
local CharService   = _G.Knit.GetService("CharService")
local CombatService = _G.Knit.GetService("CombatService")
local DetectService = _G.Knit.GetService("DetectionService")
local EffectService = _G.Knit.GetService("EffectService")
local Players       = game:GetService("Players")
local RepStorage    = game:GetService("ReplicatedStorage")
local RunService    = game:GetService("RunService")

-- Modules and objects
local Characters    = game.Workspace:WaitForChild("Characters")
local Playspace     = game.Workspace:WaitForChild("Playspace")

local DamageSway    = require(RepStorage.Remotes.DamageCamSway):Server()
local MmtSettings   = require(RepStorage.Modules.Data.MovementSettings)
local PlaySound     = require(RepStorage.Modules.Util.PlaySound)
local SimplePath    = require(RepStorage.Modules.Util.SimplePath)

-- Vars and consts
local ANIMS		    = {

	["PATROL"]      = "rbxassetid://89637238529940",
	["CHASE"]       = "rbxassetid://121987424972667",

}

local PUNCH_ANIMS   = {

	14155745294,
	14155752551,

}

local PATROL_SPEED  = MmtSettings.WALK.Speed * 4/5 -- patrols at 80% of the player's WALK speed
local CHASE_SPEED   = MmtSettings.RUN.Speed * 1.1  -- chases at 110% of the player's RUN speed

local ROAM_MIN      = 30  -- minimum seconds between patrol roams
local ROAM_MAX      = 60  -- maximum seconds between patrol roams
local FLOOR_RAY     = 100 -- studs raycast downward from a room's MainPart to find a floor
local FALL_BUFFER   = 100 -- studs above the destroy height at which the rig recovers to its last grounded position

local HEAR_ADVANCE  = 1/4 -- seconds of hearing a player needed to raise one Awareness level
local HEAR_DECAY    = 5   -- seconds of hearing no one needed to drop one Awareness level
local CHASE_LEVEL   = 3   -- Awareness level at which the Brainwashed enters CHASE

local UPDATE_INTERVAL = 1/4 -- seconds between awareness checks and path re-runs

return function(rig : Model)
    task.spawn(function()
        local Class = CharService:GetCharacterClass(rig)
        Class.TeamClass:SetTeam("ENTITIES")

        local NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = "rbxassetid://92258196181061"
        local CatatonicAnim = rig.Humanoid.Animator:LoadAnimation(NewAnim)
        CatatonicAnim.Looped = true

        NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = "rbxassetid://88621504256286"
        local IdleAnim = rig.Humanoid.Animator:LoadAnimation(NewAnim)
        IdleAnim.Looped = true

        -- [[ setup ]] --

        -- Breathing
        local NewBreathing : Sound? = nil
		task.defer(function()
            NewBreathing = Instance.new("Sound")
            NewBreathing.Name = "Breathing"
            NewBreathing.SoundId = "rbxassetid://905282283"
            NewBreathing.Looped = true
            NewBreathing.Parent = rig.PrimaryPart
            task.wait(Random.new():NextNumber(0, 1))
            NewBreathing:Play()
        end)

        -- Anims
        local LoadedAnims = {}
        for id, anim in pairs(ANIMS) do
            local Anim = Instance.new("Animation")
            Anim.AnimationId = anim
            LoadedAnims[id] = rig.Humanoid.Animator:LoadAnimation(Anim)
            LoadedAnims[id].Looped = true
            Anim:Destroy()
        end
        LoadedAnims.PATROL.Priority = Enum.AnimationPriority.Movement
        LoadedAnims.CHASE.Priority = Enum.AnimationPriority.Movement

        local PunchingAnims = {}
        for _, anim in pairs(PUNCH_ANIMS) do
            local ThisAnim = Instance.new("Animation")
            ThisAnim.AnimationId = "rbxassetid://"..anim
            local LoadedAnim = rig.Humanoid.Animator:LoadAnimation(ThisAnim)
            ThisAnim:Destroy()

            table.insert(PunchingAnims, LoadedAnim)
        end

        -- [[ main behavior ]] --

        local CurrentState = "PATROL"
        local trackingIDPresent = false

        local Rand = Random.new()
        local Path = SimplePath.new(rig)
        local NextRoam = os.clock() + Rand:NextNumber(ROAM_MIN, ROAM_MAX)

        local AttackCounter = 0
        local Awareness = 0 -- 0 = unaware, 1 = sensing, 2 = following, 3 = chase
        local HeardTarget : Model? = nil
        local HeardTime = 0
        local UnheardTime = 0
        local NextAttack = 0
        local NextPathRun = 0
        local TimeSinceUpdate = 0
        local LastTarget : Model? = nil
        local LastLevel = 0
        local LastGroundPos = rig.PrimaryPart.CFrame.Position

        CatatonicAnim:Play()
        IdleAnim:Play()

        rig.Humanoid.WalkSpeed = 0

        -- determines if tracking ID present
        local function scanChars()
            trackingIDPresent = false
            for _, char in Characters:GetChildren() do
                trackingIDPresent = char:GetAttribute("ID") == rig:GetAttribute("TrackingID")

                if trackingIDPresent then
                    break
                end
            end
        end

        local function catatonic(dt)
            if not CatatonicAnim.IsPlaying then
                CatatonicAnim:Play()
                IdleAnim:Stop()
                print("stop idle anim")
            end

            if not trackingIDPresent then
                CurrentState = "PATROL"
            end
        end

        -- Checks whether a point lies within a part's bounding box
        local function pointInPart(part : BasePart, point : Vector3) : boolean
            local localPoint = part.CFrame:PointToObjectSpace(point)
            local halfSize   = part.Size / 2

            return math.abs(localPoint.X) <= halfSize.X
                and math.abs(localPoint.Y) <= halfSize.Y
                and math.abs(localPoint.Z) <= halfSize.Z
        end

        -- Lists every generated room this Brainwashed may roam to: any room with a
        -- MainPart that isn't flagged "dontSpawnSubs" and doesn't already house it
        local function getValidRooms() : {Model}
            local roomsFolder = Playspace:FindFirstChild("Rooms")
            local rooms       = {}

            if roomsFolder then
                for _, room in roomsFolder:GetChildren() do
                    if room:IsA("Model")
                        and room.PrimaryPart
                        and room:GetAttribute("dontSpawnSubs") ~= true
                        and not (rig.PrimaryPart and pointInPart(room.PrimaryPart, rig.PrimaryPart.Position))
                    then
                        table.insert(rooms, room)
                    end
                end
            end

            return rooms
        end

        -- Raycasts straight down from a room's MainPart to find a floor to walk over
        local function getRoomFloor(room : Model) : Vector3?
            local RayParams                      = RaycastParams.new()
            RayParams.FilterType                 = Enum.RaycastFilterType.Exclude
            RayParams.FilterDescendantsInstances = {Characters}

            local Result = game.Workspace:Raycast(room.PrimaryPart.Position, Vector3.new(0, -FLOOR_RAY, 0), RayParams)

            return Result and Result.Position
        end

        -- Picks a random valid room and paths to its floor; every room is tried in
        -- random order so one unreachable or floorless room never ends the roam
        local function startRoam() : boolean
            local rooms = getValidRooms()

            for i = #rooms, 2, -1 do
                local j = Rand:NextInteger(1, i)
                rooms[i], rooms[j] = rooms[j], rooms[i]
            end

            for _, room in rooms do
                local floorPos = getRoomFloor(room)

                if floorPos then
                    if Path:Run(floorPos) then
                        return true
                    end

                    task.wait(1/10) -- let SimplePath's rate limiter cool down between attempts
                end
            end

            return false
        end

        -- Ends a roam: stops walking, plays the Idle animation, schedules the next roam
        local function endRoam()
            if LoadedAnims.PATROL.IsPlaying then
                LoadedAnims.PATROL:Stop()
            end

            rig.Humanoid.WalkSpeed = 0

            if CurrentState == "PATROL" and not CatatonicAnim.IsPlaying and not IdleAnim.IsPlaying then
                IdleAnim:Play()
            end

            NextRoam = os.clock() + Rand:NextNumber(ROAM_MIN, ROAM_MAX)
        end

        Path.Reached:Connect(endRoam)
        Path.Stopped:Connect(endRoam)
        Path.Error:Connect(function()
            -- AgentStuck fires while the path is still active (the rig jumps and keeps
            -- walking); only terminal errors leave the path idle
            if Path.Status == "Idle" then
                endRoam()
            end
        end)

        -- Returns the player character this Brainwashed hears best: it is blind, so a
        -- player is only heard when their Noise level exceeds their distance from it
        local function hearPlayer() : Model?
            if not rig.PrimaryPart then
                return nil
            end

            local BestChar, BestSignal = nil, 0

            for _, char in Characters:GetChildren() do
                if char ~= rig and char.PrimaryPart and char:GetAttribute("Team") == "Squadmates" and char.Humanoid.Health > 0 then
                    local Noise    = math.max(char:GetAttribute("Noise") or 0, 3)
                    local Distance = (char.PrimaryPart.Position - rig.PrimaryPart.Position).Magnitude
                    local Signal   = Noise - Distance

                    if Signal > BestSignal then
                        BestChar   = char
                        BestSignal = Signal
                    end
                end
            end

            return BestChar
        end

        -- Pushes the current Awareness level to the heard player's DetectionGui
        -- (1 = sensed, 2 = followed, 3 = chased); clears it when awareness is lost
        local function updateDetection()
            local Level  = (HeardTarget and HeardTarget.Parent and Awareness > 0) and Awareness or 0
            local Target = Level > 0 and HeardTarget or nil

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

        -- Hearing: gains one Awareness level per HEAR_ADVANCE seconds spent
        -- hearing a player, loses one per HEAR_DECAY seconds spent hearing no one
        local function updateAwareness(dt)
            local Heard = hearPlayer()

            if Heard then
                HeardTarget  = Heard
                HeardTime   += dt
                UnheardTime  = 0

                while HeardTime >= HEAR_ADVANCE and Awareness < CHASE_LEVEL do
                    HeardTime -= HEAR_ADVANCE
                    Awareness += 1
                end
            else
                HeardTime    = 0
                UnheardTime += dt

                if UnheardTime >= HEAR_DECAY then
                    UnheardTime -= HEAR_DECAY
                    Awareness    = math.max(Awareness - 1, 0)

                    if Awareness == 0 then
                        HeardTarget = nil
                    end
                end
            end

            updateDetection()
        end

        local function patrol(dt)
            -- Stops catatonic
            if CatatonicAnim.IsPlaying then
                CatatonicAnim:Stop()
                IdleAnim:Play()
                print("play idle anim")
            end

            if trackingIDPresent then
                CurrentState = "CATATONIC"

                if Path.Status == "Active" then
                    Path:Stop()
                end

                return
            end

            TimeSinceUpdate += dt

            if TimeSinceUpdate >= UPDATE_INTERVAL then
                updateAwareness(TimeSinceUpdate)
                TimeSinceUpdate = 0
            end

            -- Stage 3: enters CHASE
            if Awareness >= CHASE_LEVEL then
                CurrentState = "CHASE"
                return
            end

            -- Stage 2: walks toward the source of the sound
            if Awareness >= 2 then
                if HeardTarget and HeardTarget.PrimaryPart then
                    if os.clock() >= NextPathRun then
                        NextPathRun = os.clock() + UPDATE_INTERVAL
                        Path:Run(HeardTarget.PrimaryPart.Position)
                    end

                    if not LoadedAnims.PATROL.IsPlaying then
                        rig.Humanoid.WalkSpeed = PATROL_SPEED
                        IdleAnim:Stop()
                        LoadedAnims.PATROL:Play()
                    end
                elseif Path.Status == "Active" then
                    Path:Stop()
                end

                return
            end

            -- Roams to a random reachable room every ROAM_MIN-ROAM_MAX seconds
            if os.clock() >= NextRoam and Path.Status == "Idle" then
                if startRoam() then
                    rig.Humanoid.WalkSpeed = PATROL_SPEED
                    IdleAnim:Stop()
                    LoadedAnims.PATROL:Play()
                else
                    NextRoam = os.clock() + Rand:NextNumber(ROAM_MIN, ROAM_MAX)
                end
            end
        end

        -- Stage 3: runs toward the heard player; drops back to PATROL if awareness
        -- decays below the chase threshold
        local function chase(dt)
            -- Returns to catatonic if its tracking target reappears
            if trackingIDPresent then
                CurrentState = "CATATONIC"

                if Path.Status == "Active" then
                    Path:Stop()
                end

                if LoadedAnims.CHASE.IsPlaying then
                    LoadedAnims.CHASE:Stop()
                end

                return
            end

            TimeSinceUpdate += dt

            if TimeSinceUpdate >= UPDATE_INTERVAL then
                updateAwareness(TimeSinceUpdate)
                TimeSinceUpdate = 0
            end

            -- Lost the trail: back to following in PATROL
            if Awareness < CHASE_LEVEL then
                if LoadedAnims.CHASE.IsPlaying then
                    LoadedAnims.CHASE:Stop()
                end

                CurrentState = "PATROL"
                return
            end

            if HeardTarget and HeardTarget.PrimaryPart then
                rig.Humanoid.WalkSpeed = CHASE_SPEED

                if os.clock() >= NextPathRun then
                    NextPathRun = os.clock() + UPDATE_INTERVAL
                    Path:Run(HeardTarget.PrimaryPart.Position)
                end

                if not LoadedAnims.CHASE.IsPlaying then
                    IdleAnim:Stop()
                    LoadedAnims.PATROL:Stop()
                    LoadedAnims.CHASE:Play()
                end

                -- Attacks target
                local Distance = (rig.PrimaryPart.CFrame.Position - HeardTarget.PrimaryPart.CFrame.Position).Magnitude
                if Distance < 6 and os.clock() >= NextAttack then
                    NextAttack = os.clock() + 3/4
                    AttackCounter += 1

                    CombatService:Damage(rig, HeardTarget, math.random(20, 25), "BW_ATTACK", "DEFAULT", true, HeardTarget.Torso)
                    PunchingAnims[(AttackCounter % 2) + 1]:Play()
                    PlaySound(6884257732, "Damage", HeardTarget.PrimaryPart, nil, 1.25, Rand:NextNumber(0.95, 1.05))
                    
                    local Player = Players:GetPlayerFromCharacter(HeardTarget)
                    if Player then
                        DamageSway:Fire(Player, 5)
                    end

                    -- Effects
                    local doBleeding = Rand:NextNumber(0, 1) <= 0.1
                    if doBleeding then
                        EffectService:Add(HeardTarget, "Bleeding", 40)
                    end

                    local doABleeding = Rand:NextNumber(0, 1) <= 0.025
                    if doABleeding then
                        EffectService:Add(HeardTarget, "Arterial Bleeding", 99999)
                    end
                end
            elseif Path.Status == "Active" then
                Path:Stop()
            end
        end

        local Connection = nil
        Connection = RunService.PreSimulation:Connect(function(dt)
            -- Rig destroyed or parts unloaded (e.g. fell out of the world): stop cleanly
            local Unloaded = not rig:FindFirstAncestor("Workspace") or not rig.PrimaryPart
            local Dead = rig:GetAttribute("Health") and rig:GetAttribute("Health") <= 0

            if Unloaded or Dead then
                Connection:Disconnect()
                Connection = nil
            else
                -- Recovers before the rig falls below the destroy height
                if rig.PrimaryPart.Position.Y < game.Workspace.FallenPartsDestroyHeight + FALL_BUFFER then
                    rig:PivotTo(CFrame.new(LastGroundPos + Vector3.yAxis * 5))
                    rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                end

                local Humanoid = rig:FindFirstChildOfClass("Humanoid")
                if Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air then
                    LastGroundPos = rig.PrimaryPart.Position
                end

                if CurrentState == "CATATONIC" then
                    catatonic(dt)
                elseif CurrentState == "PATROL" then
                    patrol(dt)
                elseif CurrentState == "CHASE" then
                    chase(dt)
                end
            end
        end)

        -- Detects tracking ID char
        scanChars()
        local CharAdded = Characters.ChildAdded:Connect(scanChars)
        local CharRemoved = Characters.ChildRemoved:Connect(scanChars)
        rig:GetAttributeChangedSignal("TrackingID"):Connect(scanChars)

        repeat task.wait() until not Connection

        -- Clears this rig's detection status from the heard player's DetectionGui
        if LastTarget and LastTarget.Parent then
            DetectService:DetectPlayer(rig, LastTarget, 0)
        end

        -- Stop every animation the rig is playing (patrol/chase, catatonic, idle,
        -- punches) so a dying rig never keeps animating after its behavior ends
        local Humanoid = rig:FindFirstChildOfClass("Humanoid")
        local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
        if Animator then
            for _, track in Animator:GetPlayingAnimationTracks() do
                track:Stop(0)
            end
        end

        Path:Destroy()
        if NewBreathing then
            NewBreathing:Destroy()
        end
        CharAdded:Disconnect()
        CharRemoved:Disconnect()
    end)
end