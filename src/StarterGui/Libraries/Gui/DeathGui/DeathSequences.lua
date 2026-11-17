-- Services
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Parent.Name)
local Camera         = game.Workspace.CurrentCamera

local Sounds         = PlayerGui.Sounds.Death

local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local MouseTracking  = require(PlayerGui.Libraries.Misc._mousetracking)

-- Vars and consts
local CFPan          = CFrame.Angles(0, 0, 0)

-- [[ funcs ]] --

local DeathSequences = {
    BRAINWASHED      = function(...)
        local Cutscene = game.Workspace:WaitForChild("Cutscenes"):WaitForChild("BWDeath")
        local BWRig = Cutscene.Rigs:FindFirstChild("Brainwashed") or Cutscene.Rigs:FindFirstChild("_bw")

        -- No blur during this sequence: destroy any existing Blur and any
        -- created while it runs (e.g. the unbrainwash recovery blur)
        for _, effect in Lighting:GetChildren() do
            if effect:IsA("BlurEffect") then
                effect:Destroy()
            end
        end

        local BlurConn = Lighting.ChildAdded:Connect(function(effect)
            if effect:IsA("BlurEffect") then
                effect:Destroy()
            end
        end)

        -- Stops all sounds
        for _, sound in PlayerGui:GetDescendants() do
            if sound:IsA("Sound") then
                sound:Stop()
            end
        end

        -- IK control
        local IKControl = BWRig.Head:WaitForChild("IKControl")
        IKControl.Weight = 0

        task.delay(2, function()
            TweenService:Create(IKControl, TweenInfo.new(1/2), {Weight = 1}):Play()
        end)

        -- Connection
        local Connection = nil
        local ConnInit = os.clock()

        -- Creepy but fully visible lighting, applied immediately: the scene
        -- never fades from black (regular ambient returns once the player is
        -- no longer brainwashed, so the sequence owns the lighting here)
        local DeathAmbient = Color3.fromHSV(2/3, 1/4, 3/5)
        Lighting.Ambient = DeathAmbient
        Lighting.OutdoorAmbient = DeathAmbient
        Lighting.Brightness = 1/2

        Connection = RunService.PreRender:Connect(function(dt)
            game.Lighting:FindFirstChildOfClass("DepthOfFieldEffect").Enabled = false
            Lighting.Ambient = DeathAmbient
            Lighting.OutdoorAmbient = DeathAmbient
            Lighting.Brightness = 1/2

            Camera.CFrame = CFrame.lookAt(Cutscene.POV.CFrame.Position, BWRig.Head.CFrame.Position)
            Camera.FieldOfView = os.clock() <= ConnInit + 1.5 and 60 or 4

            if os.clock() >= ConnInit + 3 then
                Connection:Disconnect()
                Connection = nil
            end
        end)

        repeat task.wait() until not Connection

        local DeathCC = Instance.new("ColorCorrectionEffect")
        DeathCC.Name = "DeathCC"
        DeathCC.Parent = Lighting

        DeathCC.TintColor = Color3.fromHSV(1, 0, 1)
        DeathCC.Brightness = 1000
        DeathCC.Contrast = 0
        DeathCC.Saturation = 0
        task.wait(1/20)
        DeathCC.Brightness = -1

        BlurConn:Disconnect()
        task.wait(2)
    end,

    PROXY_3          = function(...)
        local DeathCC = Instance.new("ColorCorrectionEffect")
        DeathCC.Name = "DeathCC"
        DeathCC.TintColor = Color3.fromHSV(1, 1, 1)
        DeathCC.Contrast = 11/8
        DeathCC.Brightness = 0.65
        DeathCC.Saturation = -0.9
        DeathCC.Parent = Lighting

        local CamStep = nil
        local TimeInit = os.clock()

        Lighting.ClockTime = 16
        Sounds.PROXY_3.Buzzing:Play()

        CamStep = RunService.PreRender:Connect(function(dt)
            Camera.CFrame = game.Workspace.ChargeJS.CamPart.CFrame
            if os.clock() >= TimeInit + 2/3 then
                CamStep:Disconnect()
                CamStep = nil
            end
        end)

        repeat task.wait() until not CamStep

        DeathCC.TintColor = Color3.fromHSV(1, 0, 1)
        DeathCC.Brightness = 1000
        DeathCC.Contrast = 0
        DeathCC.Saturation = 0

        Sounds.PROXY_3.Buzzing:Stop()
        task.wait(1/20)
        DeathCC.Brightness = -1

        task.wait(2)
    end,

    PROXY_4 = function(...)

    end,

    DEFAULT          = function(...)
        Sounds.Death:Play()
        Sounds.Sting:Play()

        local Connection = nil
        local EndCam = Camera.CFrame - Vector3.new(0, 1, 0)

        local DeathCC = Instance.new("ColorCorrectionEffect")
        DeathCC.Name = "DeathCC"
        DeathCC.Parent = Lighting

        local Blur = Instance.new("BlurEffect")
        Blur.Name = "DeathBlur"
        Blur.Size = 0
        Blur.Parent = Lighting

        local Corpse = game.Workspace:WaitForChild("Corpses"):WaitForChild(Player.Name, 3)
        if Corpse then
            Corpse = Corpse:FindFirstChild("Head") and Corpse or nil 
        end

        -- position if the corpse can't be located
        Connection = RunService.PreRender:Connect(function(dt)
            local QuarterLerp = LerpByFrame(1/4, dt)

            if Corpse then
                Camera.CFrame = Corpse.Head.CFrame
            else
                Camera.CFrame = EndCam
            end

            local PosX, PosY = MouseTracking.getPositionScale()
            local QuarterLerp = LerpByFrame(1/4, dt)
            CFPan = CFPan:Lerp(CFrame.Angles(-math.rad(PosY * 5), -math.rad(PosX * 5), 0), QuarterLerp)
            Camera.CFrame *= CFPan
        end)

        TweenService:Create(Blur, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = 56}):Play()
        TweenService:Create(DeathCC, TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Brightness = -1}):Play()

        task.wait(5)
        Connection:Disconnect()
        Connection = nil
    end
}

return DeathSequences