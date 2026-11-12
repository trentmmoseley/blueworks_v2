local Proxy        = {}

-- Services
local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")
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
local Camera       = game.Workspace.CurrentCamera

-- Vars and consts
local ATTACK_ANIMS = {97633645023236, 126985686457998, 123162586564812, 94060623091801}

-- Main function
function Proxy.UI()
    local FlashEffect = Lighting:FindFirstChild("OutOfTimeFlash")
    Sounds.Footsteps:Play()
    task.wait(3)

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
        if DotProduct < -0.5 then -- player facing 45 degrees toward Proxy
            LookConn:Disconnect()
            LookConn = nil
        end
    end)

    repeat task.wait() until not LookConn
end

return Proxy