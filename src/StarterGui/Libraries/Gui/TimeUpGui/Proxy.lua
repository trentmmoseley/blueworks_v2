local Proxy        = {}

-- Services
local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Players
local Player       = Players.LocalPlayer
local PlayerGui    = Player.PlayerGui

local Character    = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui       = PlayerGui:WaitForChild(script.Parent.Name):FindFirstChild(script.Name)
local Sounds       = PlayerGui.Sounds.OutOfTime.Proxy

local AttackVPF    = TheGui.AttackVPF
local BloodEffects = TheGui.BloodEffects
local FinalScene   = TheGui.FinalScene
local ProxyADialog = TheGui.ProxyADialog
local Camera       = game.Workspace.CurrentCamera

local VFX          = RepStorage.VFX.TimeUp.Proxy

local PlaySound    = require(RepStorage.Modules.Util.PlaySound)
local SelfDestruct = require(RepStorage.Remotes.SelfDestruct):Client()

-- Vars and consts
local ATTACK_ANIMS = {97633645023236, 126985686457998, 123162586564812, 94060623091801}
local APPARITION_ANIMS = {111063195083589, 105550397128337, 138405552391268}

-- Same swing/stab sound pools as the Proxy NPC
local SWING_SOUNDS = {7801336419, 7801329626}
local STAB_SOUNDS  = {18512265986, 18512270266}

local APPARITION_COUNT        = 30
local APPARITION_RADIUS       = 40 -- studs around the player an apparition may spawn within
local APPARITION_MIN_RADIUS   = 5  -- keeps apparitions from spawning inside the player
local APPARITION_FADE_TIME    = 20 -- seconds spent fading into view
local APPARITION_TRANSPARENCY = 1/4
local APPARITION_EXIT_FADE    = 1/2 -- seconds spent fading back out once the final line is written
local APPARITION_EXIT_SOUND   = 9126228629 -- the Proxy NPC's Exit Retreat sound

local PROXY_A_MSGS = {
    {
        "Who goes there?",
        "Do not answer that; I already know.",
        "He sent you here; I saw it.",
        "A very charming personality, is he not?",
        "Come, player_name, and face the door.",
    },
    {
        "Before we meet, take a look around you.",
        "Most humans are not meant to be here.",
        "But from this point forward, this is your home...",
        "...and I am your host.",
        "You are the latest of select souls I have deemed worthy...",
        "...to join me in eternal slumber.",
        "I generally do not acknowledge mortals, but your tenacity was frankly adorable.",
        "I have deemed you worthy enough for adoption in waiting for my time to arise...",
        "and devour your planet.",
        "The souls that surround you have been here for thousands, millions, if not billions of years,",
        "and shall wait a forever more here with me in my world.",
        "And you have just become one of them.",
        "I will teach you the essense of eternity --",
        "how it feels, and how it works.",
        "But first, I must show you how it looks.",
    },
    {
        "Look at me.",
    }
}

-- The souls line: the apparitions are summoned the moment it begins writing
local APPARITION_TRIGGER_MSG = PROXY_A_MSGS[2][10]

-- Seconds the second batch takes to write: each character takes 1/30s and each
-- message pauses for three seconds, matching the writing loop below
local BATCH_2_DURATION = 0
for _, msg in PROXY_A_MSGS[2] do
    BATCH_2_DURATION += #msg / 30 + 3
end

-- Every apparition currently summoned, so they can be dismissed together
local Apparitions = {}

-- Summons the apparitions: thirty ghosts (cloned from the Apparition templates
-- stored alongside Platform) ring the player, each playing a random looped
-- animation and fading into view over twenty seconds
local function summonApparitions()

    local CharRoot = Character.PrimaryPart
    if not CharRoot then
        return
    end
    local Center = CharRoot.CFrame.Position

    for _ = 1, APPARITION_COUNT do
        local Apparition = VFX.Apparition:Clone()

        local Angle    = Rand:NextNumber() * math.pi * 2
        local Distance = Rand:NextNumber(APPARITION_MIN_RADIUS, APPARITION_RADIUS) * (math.random(0, 1) == 0 and 1 or -1)
        local SpawnPos = Center + Vector3.new(math.cos(Angle) * Distance, 0, math.sin(Angle) * Distance)

        Apparition:PivotTo(CFrame.lookAt(SpawnPos, Vector3.new(Center.X, SpawnPos.Y, Center.Z)))

        for _, desc in Apparition:GetDescendants() do
            if desc:IsA("BasePart") then
                desc.Anchored = true
                desc.CanCollide = false
                desc.Transparency = 1
                if desc.Name ~= "HumanoidRootPart" and not desc.Parent.Name ~= "HolsterSystem" then
                    TweenService:Create(desc, TweenInfo.new(APPARITION_FADE_TIME), {Transparency = APPARITION_TRANSPARENCY}):Play()
                end
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 1
                TweenService:Create(desc, TweenInfo.new(APPARITION_FADE_TIME), {Transparency = APPARITION_TRANSPARENCY}):Play()
            end
        end

        Apparition.Parent = game.Workspace

        -- The rig must be in the DataModel before its track starts, or the
        -- animation never visually plays; ghost rigs may animate through a
        -- Humanoid or a bare AnimationController, so either hosts the Animator
        local AnimHost = Apparition:FindFirstChildOfClass("Humanoid") or Apparition:FindFirstChildOfClass("AnimationController")
        if AnimHost then
            local Animator = AnimHost:FindFirstChildOfClass("Animator")
            if not Animator then
                Animator = Instance.new("Animator")
                Animator.Parent = AnimHost
            end

            local Anim = Instance.new("Animation")
            Anim.AnimationId = "rbxassetid://"..APPARITION_ANIMS[Rand:NextInteger(1, #APPARITION_ANIMS)]

            local ApparitionTrack = Animator:LoadAnimation(Anim)
            ApparitionTrack.Priority = Enum.AnimationPriority.Action4
            ApparitionTrack.Looped = true
            Anim:Destroy()

            ApparitionTrack:Play()
        end

        table.insert(Apparitions, Apparition)
    end
end

-- Dismisses the apparitions: a quick half-second fade, then the rigs are removed
local function despawnApparitions()
    for _, Apparition in Apparitions do
        if Apparition.Parent then
            for _, desc in Apparition:GetDescendants() do
                if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
                    TweenService:Create(desc, TweenInfo.new(APPARITION_EXIT_FADE), {Transparency = 1}):Play()
                end
            end

            task.delay(APPARITION_EXIT_FADE, function()
                Apparition:Destroy()
            end)
        end
    end

    table.clear(Apparitions)
end

-- Main function
function Proxy.UI()
    -- Summons the Platform and places the player upon its Spawnpoint
    local Platform = VFX.Platform:Clone()
    Platform.Parent = game.Workspace
    
    -- Tendrils
    local TendrilSizes = {}
    for _, tendril in Platform.TendrilHead.Tendrils:GetChildren() do
        local Anim = Instance.new("Animation")
        Anim.AnimationId = "rbxassetid://123725938975640"
        local AnimController : AnimationController = tendril.AnimationController
        local LoadedAnim : AnimationTrack = AnimController:LoadAnimation(Anim)
        LoadedAnim:Play()
        LoadedAnim:AdjustSpeed(Random.new():NextNumber(1/16, 1/2))
        TendrilSizes[tendril] = tendril.Tendril1.Size
        tendril.Tendril1.Size = Vector3.zero
        tendril.Tendril1.Transparency = 1
    end

    Character:PivotTo(Platform.Spawnpoint.CFrame)

    local FlashEffect = Lighting:FindFirstChild("OutOfTimeFlash")
    Sounds.Footsteps:Play()
    task.wait(4)

    -- Waits till player looks at Proxy
    TheGui.AttackVPF.Visible = true
    TheGui.AttackVPF.CurrentCamera = Camera
    TheGui.AttackVPF.WorldModel._rig:PivotTo(Character.PrimaryPart.CFrame - Character.PrimaryPart.CFrame.LookVector * 3)

    local WaitInit = os.clock()
    local LerpSpeed = 0
    local LookConn = nil
    LookConn = RunService.PreRender:Connect(function(dt)
        -- Camera moves toward Proxy if enough time has passed
        if os.clock() >= WaitInit + 5 then
            LerpSpeed += dt ^ 2
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, TheGui.AttackVPF.WorldModel._rig.Head.CFrame.Position), LerpSpeed)
        end

        local LV1, LV2 = TheGui.AttackVPF.WorldModel._rig.PrimaryPart.CFrame.LookVector.Unit, Camera.CFrame.LookVector.Unit
        local DotProduct = LV1:Dot(LV2)
        if DotProduct < -0.75 then -- player facing ~22.5 degrees toward Proxy
            LookConn:Disconnect()
            LookConn = nil
        end
    end)

    repeat task.wait() until not LookConn

    -- Spotted: the Proxy strikes, mirroring its NPC counterpart's attack
    local Rig = TheGui.AttackVPF.WorldModel._rig
    local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
    local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
    if Humanoid and not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = Humanoid
    end

    if Animator then
        local Anim = Instance.new("Animation")
        Anim.AnimationId = "rbxassetid://"..ATTACK_ANIMS[math.random(1, #ATTACK_ANIMS)]

        local AttackTrack = Animator:LoadAnimation(Anim)
        AttackTrack.Priority = Enum.AnimationPriority.Action4
        AttackTrack.Looped = false
        Anim:Destroy()

        AttackTrack:Play()
    end

    -- A viewport rig cannot emit 3D sound, so the character's root emits instead
    PlaySound(SWING_SOUNDS[math.random(1, #SWING_SOUNDS)], "Swing", Character.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))
    PlaySound(STAB_SOUNDS[math.random(1, #STAB_SOUNDS)], "Stab", Character.PrimaryPart, nil, 1, Rand:NextNumber(0.95, 1.05))

    -- The stab takes its toll: health effects read as 25 HP from here on
    Character:SetAttribute("ApparentHealth", 25)

    Sounds.Captured1:Play()
    Sounds.Captured2:Play()
    Sounds.Captured3:Play()

    for _, image in BloodEffects:GetChildren() do
        TweenService:Create(image, TweenInfo.new(1/2), {ImageTransparency = image.Name ~= "Blood" and 0 or 0.5}):Play()
    end

    -- The Proxy stares the player down while they collapse
    local Head = Rig:FindFirstChild("Head")
    local Neck = nil
    for _, motor in Rig:GetDescendants() do
        if motor:IsA("Motor6D") and motor.Part1 == Head then
            Neck = motor
            break
        end
    end

    local StareTarget = Instance.new("Part")
    StareTarget.Name = "ProxyStareTarget"
    StareTarget.Anchored = true
    StareTarget.CanCollide = false
    StareTarget.CanQuery = false
    StareTarget.CanTouch = false
    StareTarget.Transparency = 1
    StareTarget.Size = Vector3.one
    StareTarget.CFrame = Camera.CFrame
    StareTarget.Parent = game.Workspace

    local StareAttachment = Instance.new("Attachment")
    StareAttachment.Parent = StareTarget

    if Head and Neck and Humanoid then
        local Stare = Instance.new("IKControl")
        Stare.Name = "Stare"
        Stare.Type = Enum.IKControlType.LookAt
        Stare.ChainRoot = Neck.Part0
        Stare.EndEffector = Head
        Stare.Target = StareAttachment
        Stare.Parent = Humanoid
    end

    -- The player falls backward onto the floor over six seconds. Driven here
    -- rather than TweenService because the default camera scripts fight over
    -- Camera.CFrame; the easing matches TweenInfo Exponential/In
    local FallStart = Camera.CFrame
    local FlatLook = Vector3.new(FallStart.LookVector.X, 0, FallStart.LookVector.Z).Unit
    local FallEndPos = FallStart.Position - FlatLook * 2 + Vector3.new(0, -2.5, 0)
    local FallEnd = CFrame.new(FallEndPos) * CFrame.lookAt(Vector3.zero, FlatLook) * CFrame.Angles(math.rad(80), 0, 0)

    local FallInit = os.clock()
    local FallConn = nil
    FallConn = RunService.PreRender:Connect(function()
        local Alpha = math.min((os.clock() - FallInit) / 6, 1)
        Camera.CFrame = FallStart:Lerp(FallEnd, Alpha > 0 and 2 ^ (10 * (Alpha - 1)) or 0)
        StareTarget.CFrame = Camera.CFrame

        if Alpha >= 1 then
            FallConn:Disconnect()
            FallConn = nil
        end
    end)

    repeat task.wait() until not FallConn

    AttackVPF.Visible = false

    -- The darkness lifts: the flash fades back out so the environment shows again
    if FlashEffect then
        TweenService:Create(FlashEffect, TweenInfo.new(6, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {Brightness = 0, TintColor = Color3.fromHSV(0.4, 1/2, 1), Saturation = -0.25, Contrast = -0.25}):Play()
    end

    -- The fall in reverse: the player rises from face-down on the floor (as if
    -- flat on their stomach) back up to their head, slow at the ends and
    -- fastest halfway through, like drawing a circle
    local HeadPart = Character:FindFirstChild("Head")
    local RiseStart = CFrame.new(FallEndPos) * CFrame.lookAt(Vector3.zero, FlatLook) * CFrame.Angles(math.rad(-80), 0, 0)
    local RiseEnd = HeadPart and HeadPart.CFrame or FallStart

    local RiseInit = os.clock()
    local RiseConn = nil
    RiseConn = RunService.PreRender:Connect(function()
        local Alpha = math.min((os.clock() - RiseInit) / 6, 1)

        -- Circular InOut easing
        local Ease = Alpha < 0.5 and (1 - math.sqrt(1 - (2 * Alpha) ^ 2)) / 2 or (math.sqrt(1 - (-2 * Alpha + 2) ^ 2) + 1) / 2
        Camera.CFrame = RiseStart:Lerp(RiseEnd, Ease)

        if Alpha >= 1 then
            RiseConn:Disconnect()
            RiseConn = nil
        end
    end)

    for _, image in BloodEffects:GetChildren() do
        TweenService:Create(image, TweenInfo.new(1/2), {ImageTransparency = image.Name ~= "Blood" and 1 or 0.875}):Play()
    end
    TweenService:Create(TheGui._static, TweenInfo.new(6), {ImageTransparency = 3/4}):Play()
    TweenService:Create(Sounds.Ambience, TweenInfo.new(6), {Volume = 1/4}):Play()

    repeat task.wait() until not RiseConn

    task.wait(3)

    -- Beckons player to approach
    for i, msg in PROXY_A_MSGS[1] do
        Sounds.Whispers.Volume = 1
        local UsedMessage = msg:gsub("player_name", Player.Name)
        for j = 1, #UsedMessage do
            ProxyADialog.Text = UsedMessage:sub(1, j)
            Sounds.Whispers.TimePosition = Rand:NextNumber() * Sounds.Whispers.TimeLength
            task.wait(1/30)
        end
        Sounds.Whispers.Volume = 0

        if i == #PROXY_A_MSGS[1] then
            require(script.Parent).SetMovementLocked(false)
        end

        task.wait(3)
    end

    local hasHitTrigger = false
    Platform:WaitForChild("Stage2Trigger").Touched:Connect(function(otherpart)
        if hasHitTrigger then return end
        if otherpart:FindFirstAncestor(Character.Name) then
            hasHitTrigger = true

            -- The Ambience drags to half speed as the second batch unfolds
            Sounds.Ambience.PlaybackSpeed = 1
            TweenService:Create(Sounds.Ambience, TweenInfo.new(BATCH_2_DURATION, Enum.EasingStyle.Linear), {PlaybackSpeed = 1/2}):Play()

            -- The MadnessStatic swells in from silence alongside it
            Sounds.MadnessStatic.Volume = 0
            Sounds.MadnessStatic.PlaybackSpeed = 0
            Sounds.MadnessStatic:Play()
            TweenService:Create(Sounds.MadnessStatic, TweenInfo.new(BATCH_2_DURATION, Enum.EasingStyle.Linear), {Volume = 0.125, PlaybackSpeed = 4/5}):Play()

            for _, msg in PROXY_A_MSGS[2] do
                -- The souls line: summons the apparitions and roots the player in place
                if msg == APPARITION_TRIGGER_MSG then
                    require(script.Parent).SetMovementLocked(true)
                    task.spawn(summonApparitions)
                end

                Sounds.Whispers.Volume = 1
                local UsedMessage = msg:gsub("player_name", Player.Name)
                for i = 1, #UsedMessage do
                    ProxyADialog.Text = UsedMessage:sub(1, i)
                    Sounds.Whispers.TimePosition = Rand:NextNumber() * Sounds.Whispers.TimeLength
                    task.wait(1/30)
                end
                Sounds.Whispers.Volume = 0
                task.wait(3)
            end

            -- The final line settles: the apparitions vanish with the Proxy's exit
            -- sound and the Ambience dies out
            PlaySound(APPARITION_EXIT_SOUND, "End", Character.PrimaryPart, nil, 1, 1)
            despawnApparitions()
            Sounds.Ambience:Stop()

            -- Third part
            for _, msg in PROXY_A_MSGS[3] do
                local UsedMessage = msg:gsub("player_name", Player.Name)
                for i = 1, #UsedMessage do
                    if UsedMessage:sub(i, i) ~= " " then
                        Sounds.Whispers.Volume = 1
                        ProxyADialog.Text = UsedMessage:sub(1, i)
                        Sounds.Whispers.TimePosition = Rand:NextNumber() * Sounds.Whispers.TimeLength
                        task.wait(1/30)
                        Sounds.Whispers.Volume = 0
                        task.wait(1/2)
                    end
                end
            end

            -- Tendrils: regrown to the sizes they had when the Platform was summoned
            for _, tendril in Platform.TendrilHead.Tendrils:GetChildren() do
                tendril.Tendril1.Transparency = 0
                TweenService:Create(tendril.Tendril1, TweenInfo.new(7, Enum.EasingStyle.Exponential), {Size = TendrilSizes[tendril] or tendril.Tendril1.Size}):Play()
            end

            TweenService:Create(Platform.DoorLeft.PrimaryPart, TweenInfo.new(7, Enum.EasingStyle.Exponential), {CFrame = Platform.DoorLeft.PrimaryPart.CFrame * CFrame.Angles(0, -math.rad(math.random(30, 90)), 0)}):Play()
            TweenService:Create(Platform.DoorRight.PrimaryPart, TweenInfo.new(7, Enum.EasingStyle.Exponential), {CFrame = Platform.DoorRight.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(math.random(30, 90)), 0)}):Play()

            -- The camera is dragged toward the TendrilHead with a force that
            -- grows from nothing, like the pull that drew it to the Proxy
            local LookForce = 0
            local LookConn = RunService.PreRender:Connect(function(dt)
                LookForce += dt ^ 1.85
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, Platform.TendrilHead.CFrame.Position), LookForce)
            end)

            -- Each door creaks twice as it swings open; both creaks start together
            -- and layer over each other at random slow speeds
            for _, door in {Platform.DoorLeft, Platform.DoorRight} do
                for _ = 1, 2 do
                    local Creak = Sounds.DoorCreakOpen:Clone()
                    Creak.PlaybackSpeed = Rand:NextNumber(0.125, 0.175)
                    Creak.Parent = door.PrimaryPart
                    Creak:Play()

                    Creak.Ended:Once(function()
                        Creak:Destroy()
                    end)
                end
            end

            TweenService:Create(Sounds.MadnessStatic, TweenInfo.new(7, Enum.EasingStyle.Linear), {Volume = 2/3, PlaybackSpeed = 4/3}):Play()

            -- Two seconds before the doors finish swinging open, the MadnessStatic
            -- peaks and the DeathScream swells from silence
            task.delay(7 - 2, function()
                Sounds.DeathScream.Volume = 0
                Sounds.DeathScream:Play()
                TweenService:Create(FlashEffect, TweenInfo.new(2), {Contrast = 30, Saturation = 30, TintColor = Color3.fromRGB(132, 255, 0)}):Play()
                TweenService:Create(TheGui._static, TweenInfo.new(2), {ImageTransparency = 0.8}):Play()
                TweenService:Create(Sounds.DeathScream, TweenInfo.new(2, Enum.EasingStyle.Linear), {Volume = 2}):Play()

                -- Immediately after, every sound the client can hear ceases:
                -- complete silence (the creaks' crawl outlasts the door swing,
                -- so they are cut here too; stopping them fires their Ended
                -- cleanup)
                task.wait(2)
                for _, root in {PlayerGui, Platform} do
                    for _, desc in root:GetDescendants() do
                        if desc:IsA("Sound") then
                            desc:Stop()
                        end
                    end
                end
            end)

            task.wait(7)

            ProxyADialog.Visible = false
            FinalScene.Visible = true
            LookConn:Disconnect()
            task.wait(5)
            TweenService:Create(FinalScene.TextLabel, TweenInfo.new(2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
            TheGui.BackgroundTransparency = 0
            TweenService:Create(FinalScene, TweenInfo.new(3), {ImageTransparency = 1}):Play()
            TweenService:Create(TheGui._static, TweenInfo.new(2), {ImageTransparency = 1}):Play()
            for _, image in BloodEffects:GetChildren() do
                TweenService:Create(image, TweenInfo.new(1/2), {ImageTransparency = 1}):Play()
            end
            task.wait(3)
            SelfDestruct:Fire("PROXY_4")
        end
    end)
end

return Proxy