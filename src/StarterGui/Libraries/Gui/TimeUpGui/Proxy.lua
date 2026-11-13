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
local Camera       = game.Workspace.CurrentCamera

local VFX          = RepStorage.VFX.TimeUp.Proxy

local PlaySound    = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local ATTACK_ANIMS = {97633645023236, 126985686457998, 123162586564812, 94060623091801}

-- Same swing/stab sound pools as the Proxy NPC
local SWING_SOUNDS = {7801336419, 7801329626}
local STAB_SOUNDS  = {18512265986, 18512270266}

-- Main function
function Proxy.UI()
    -- Summons the Platform and places the player upon its Spawnpoint
    local Platform = VFX.Platform:Clone()
    Platform.Parent = game.Workspace
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
        TweenService:Create(FlashEffect, TweenInfo.new(6, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), {Brightness = 0, TintColor = Color3.fromHSV(2/3, 1/2, 1), Saturation = -0.5, Contrast = 0.125}):Play()
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

    require(script.Parent).SetMovementLocked(false)
end

return Proxy