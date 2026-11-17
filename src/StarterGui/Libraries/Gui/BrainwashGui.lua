local BrainwashGui   = {}

-- Services
local Debris         = game:GetService("Debris")
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Sounds         = PlayerGui.Sounds.Brainwashed

local BWSequence     = require(RepStorage.Remotes.BrainwashSequence):Client()
local BWVFX          = RepStorage.VFX.TetheredBrainwash

local BlueScreen     = TheGui.BlueScreen
local InitFrame      = TheGui.InitFrame
local RebootScreen   = TheGui.RebootScreen
local TetheredImg    = TheGui.TetheredImage
local I2             = TheGui.IllegalInstruction

local TetheredInit   = InitFrame.ViewportFrame.WorldModel.Tethered

local Camera         = game.Workspace.CurrentCamera

local Progress       = require(RepStorage.Modules.Util.Math.Progress)
local TrigWave       = require(RepStorage.Modules.Util.Math.TrigWave)

local BWPaths        = game.Workspace:WaitForChild("Cutscenes"):WaitForChild("BWPaths")
local BWDeath        = game.Workspace:WaitForChild("Cutscenes"):WaitForChild("BWDeath")
local BWRig          = BWDeath:WaitForChild("Rigs"):FindFirstChild("Brainwashed") or BWDeath.Rigs:FindFirstChild("_bw")

local BWCC           : ColorCorrectionEffect = nil

-- Vars and consts
local Offset         = Vector3.zero

local BALL_TEXTURES  = {
	
	16397680553,
	15485895248,
	12827396698,
	
}

local REBOOT_MSGS    = {
    "FATAL ERROR DETECTED",
    "ANALYZING ERROR CODE",
    "\"PNDR_TETHERED_INFILTRATION\"",
    "ILLEGAL INSTRUCTION",
    "ATTEMPTING HARD REBOOT OF BLUEWORKS PER ROBLOX CLIENT PROTOCOL",
    "BUILD FAILURE",
    "ATTEMPT 2",
    "BUILD FAILURE",
    "ATTEMPT 3",
    "BUILD FAILURE",
    "ATTEMPT 4",
    "BUILD FAILURE",
    "LOAD CONTENTS OF CURRENT CLIENT? (Y/N) (\"N\" RECOMMENDED)",
    "(Y) SELECTED PER ADIMINSTRATIVE FORCE",
    "POSITIVE TO RELOAD? MAY CONTAIN CORRUPTED DATA (Y/N) (\"N\" RECOMMENDED)",
    "(Y) SELECTED PER ADIMINSTRATIVE FORCE",
    "PERMISSION GRANTED TO REBOOT",
    "REBOOTING...",
    "...",
    "...",
    "...",
    "REBOOT COMPLETE. STARTING BLUEWORKS (DATA MAY HAVE BEEN LOST)...",
    "HAHAHAHAHAHAHAHAHAHAHA",
}

-- Main function
function BrainwashGui.Function()
    -- Clears old parts
    for _, part in BWVFX:GetChildren() do
        local FoundItem = game.Workspace:FindFirstChild(part.Name)
        if FoundItem then
            FoundItem:Destroy()
        end
    end

    -- Tethered anim
    local NewAnim = Instance.new("Animation")
    NewAnim.AnimationId = "rbxassetid://112532176303591"
    local LoadedAnim = TetheredInit.Humanoid.Animator:LoadAnimation(NewAnim)
    LoadedAnim.Looped = true
    LoadedAnim:Play()
    NewAnim:Destroy()

    local Cam = Instance.new("Camera")
    Cam.Parent = InitFrame.ViewportFrame
    Cam.FieldOfView = 30
    InitFrame.ViewportFrame.CurrentCamera = Cam
    task.delay(1, function()
        Cam.CFrame = CFrame.lookAt(InitFrame.ViewportFrame.WorldModel.CamPOV.CFrame.Position, TetheredInit.Head.Position)
    end)

    -- TheCam does not reliably persist on load; rebuild it from scratch
    for _, OldCam in TheGui.ViewportFrame:GetChildren() do
        if OldCam:IsA("Camera") then
            OldCam:Destroy()
        end
    end

    local TheCam                       = Instance.new("Camera")
    TheCam.Name                        = "TheCam"
    TheCam.CFrame                      = CFrame.new(122.864, 6.519, 3.797) * CFrame.fromOrientation(math.rad(-3.147), math.rad(149.159), 0)
    TheCam.Parent                      = TheGui.ViewportFrame
    TheGui.ViewportFrame.CurrentCamera = TheCam

    -- BW Death sequence anim
    if BWRig.Name ~= "_bw" then
        local NewAnim = Instance.new("Animation")
        NewAnim.AnimationId = "rbxassetid://114801650547496"
        local LoadedAnim = BWRig.Humanoid.Animator:LoadAnimation(NewAnim)
        LoadedAnim.Looped = true
        LoadedAnim:Play()
        NewAnim:Destroy()
        BWRig.Name = "_bw"
    end

    BWSequence:On(function(origcamcf : CFrameValue)
        TheGui.Enabled = true
        Sounds.Static.Volume = 0

        -- Stage 1
        BWCC = Instance.new("ColorCorrectionEffect")
        BWCC.Contrast = -2
        BWCC.TintColor = Color3.fromHSV(2/3, 1, 1)
        BWCC.Parent = Lighting

        local StutterConn = RunService.PreRender:Connect(function(dt)
            Camera.CFrame = CFrame.new(origcamcf.Position + Offset)
        end)

        Sounds.DeathScream:Play()
        task.wait(2/3 * (1 / 5))

        local SavedPosition = Sounds.DeathScream.TimePosition
        I2.Visible = true

        for i = 1, 45 do
            Sounds.DeathScream.TimePosition = SavedPosition
            BWCC.Contrast *= -1
            task.wait(1/60)
        end

        Sounds.DeathScream:Stop()
        Offset += Vector3.new(0, 2048, 0)

        -- Stage 2
        BlueScreen.Visible = true
        I2.Visible = false

        task.wait(1/4)

        for _, part in BlueScreen:GetChildren() do
            part.Visible = true
            task.wait(1/8)
        end
        TetheredImg.Visible = true

        task.wait(4)

        for _, part in BlueScreen:GetChildren() do
            part.Visible = false
            task.wait(1/40)
        end
        TetheredImg.Visible = false

        task.wait(3/2)
        BlueScreen.Visible = false

        -- Stage 3
        RebootScreen.Visible = true
        for i, blurb in REBOOT_MSGS do
           local NewBlurb = RebootScreen.UIListLayout.TextLabel:Clone()
           NewBlurb.Text = string.format("C:/USERS/KEA2012/BLUEWORKS> %s (%s)", blurb, os.date("%m/%d/████ %X", os.time()))
           NewBlurb.Parent = RebootScreen
           Sounds.Beep:Play()
           task.wait(Rand:NextNumber(0, 1) / 3)
        end

        for _, blurb in RebootScreen:GetChildren() do
            if blurb:IsA("TextLabel") then
                blurb:Destroy()
            end
        end

        -- Stage 4
        TheGui._static.ImageTransparency = 1
        InitFrame.Visible = true
        RebootScreen.Visible = false

        Sounds.Whirr:Play()

        local Cutscene1 = BWVFX.Cutscene1:Clone()
        Cutscene1.Parent = game.Workspace

        local POVs = Cutscene1.POVs:GetChildren()
        local ChosenPOV = POVs[math.random(1, #POVs)]
        Cutscene1.PrimaryPart = ChosenPOV

        local CutsceneConn = nil
        CutsceneConn = RunService.PreRender:Connect(function(dt)
            Cutscene1:PivotTo(origcamcf + Offset)
        end)

        local PulldownConn = nil
        local PulldownStart = os.clock()
        local PulldownEnd = os.clock() + Sounds.Whirr.TimeLength
        local NextUpdate = os.clock()

        PulldownConn = RunService.PreRender:Connect(function(dt)
            if os.clock() >= NextUpdate then
                NextUpdate = os.clock() + Rand:NextNumber(0, 1) / 8
                InitFrame.PulldownFrame.Size = UDim2.fromScale(1, 1 - Progress(os.clock(), PulldownStart, PulldownEnd))
            end

            if os.clock() >= PulldownEnd then
                PulldownConn:Disconnect()
                PulldownConn = nil
            end
        end)

        repeat task.wait() until not PulldownConn

        Sounds.Music:Play()

        InitFrame.PulldownFrame.Size = UDim2.fromScale(1, 0)
        InitFrame.ViewportFrame.Visible = true
        InitFrame.TetheredNote.Visible = true

        task.wait(3)

        InitFrame.ViewportFrame.Visible = false
        InitFrame.TetheredNote.Visible = false

        InitFrame.Visible = false
        TheGui.ViewportFrame.Visible = true

        -- Effects
        local BWSky = BWVFX.BWSky:Clone()
        BWSky.Parent = game.Workspace

        local BGGrid         : Texture = BWSky:FindFirstChild("BGGrid", true):FindFirstChild("Texture")
        local LogoGrid       : Texture = BWSky:FindFirstChild("LogoGrid", true):FindFirstChild("Texture")

        for _, part : BasePart in Cutscene1:GetDescendants() do
            if not part:IsA("BasePart") then continue end
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.AudioCanCollide = false
        end

        local Connection = nil
        local CurrentTexture = 1
        local NextBallUpdate = os.clock()

        CutsceneConn:Disconnect()
        StutterConn:Disconnect()
        Cutscene1:Destroy()

        Connection = RunService.PreRender:Connect(function(dt)
            -- Cutscene1:PivotTo(Camera.CFrame)
            BWSky:PivotTo(Camera.CFrame + Camera.CFrame.LookVector * 2000)

            BGGrid.OffsetStudsU += dt * 400
		    BGGrid.OffsetStudsV += (dt * 400 / 3)

            LogoGrid.OffsetStudsU += dt * 400
		    LogoGrid.OffsetStudsV = TrigWave("sin", 400, 10, tick(), 0, 0)

            -- Ball texture
            if os.clock() >= NextBallUpdate then
                NextBallUpdate = os.clock() + 1/30
                CurrentTexture = CurrentTexture == #BALL_TEXTURES and 1 or CurrentTexture + 1

                for _, txt in pairs(TheGui.ViewportFrame.WorldModel.Logo:GetChildren()) do
                    if txt:IsA("Texture") then
                        txt.Texture = string.format("rbxassetid://%i", BALL_TEXTURES[CurrentTexture])
                    end
                end
            end

            -- Noise effect
            local DistFromStart = (BWPaths.Spawnpoint.CFrame.Position - Camera.CFrame.Position).Magnitude
            local StaticStrength = math.clamp(DistFromStart / 150, 0, 1) ^ 4
            TheGui._static.ImageTransparency = 1 - StaticStrength
            Sounds.Static.Volume = StaticStrength

            if not TheGui.Enabled then
                BWCC:Destroy()
                BWSky:Destroy()
                Connection:Disconnect()
                Connection = nil
                Sounds.Static.Volume = 0
            end
        end)
    end)

    -- escape brainwashing
    Character:GetAttributeChangedSignal("beingBrainwashed"):Connect(function()
        local beingBrainwashed = Character:GetAttribute("beingBrainwashed")
        TheGui.Enabled = beingBrainwashed

        if not beingBrainwashed then
            Sounds.Music:Stop()

            -- The recovery presentation is only for survivors: dying to the
            -- Tethered runs the BRAINWASHED death sequence instead, with no
            -- fade from black, no blur, and no ears ringing
            if (Character:GetAttribute("Health") or 0) <= 0 then
                return
            end

            local RecoverCC = Instance.new("ColorCorrectionEffect")
            RecoverCC.Brightness = -1
            RecoverCC.TintColor = Color3.fromHSV(2/3, 1, 0)
            RecoverCC.Parent = Lighting

            local Blur = Instance.new("BlurEffect")
            Blur.Size = 56
            Blur.Parent = Lighting

            TweenService:Create(RecoverCC, TweenInfo.new(5), {Brightness = 0, TintColor = Color3.fromHSV(1, 0, 1)}):Play()
            TweenService:Create(Blur, TweenInfo.new(10), {Size = 0}):Play()

            Debris:AddItem(RecoverCC, 5)
            Debris:AddItem(Blur, 10)

            Sounds.EarsRinging.Volume = 1/4
            Sounds.EarsRinging:Play()
            TweenService:Create(Sounds.EarsRinging, TweenInfo.new(8), {Volume = 0}):Play()

            Sounds.Tada.Volume = 1
            Sounds.Tada.PitchMod.Octave = 5/4
            Sounds.Tada:Play()
            TweenService:Create(Sounds.Tada.PitchMod, TweenInfo.new(2/3), {Octave = 5/4 * 3/4}):Play()
			TweenService:Create(Sounds.Tada, TweenInfo.new(2/3), {Volume = 0}):Play()
        end
    end)
end

return BrainwashGui