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