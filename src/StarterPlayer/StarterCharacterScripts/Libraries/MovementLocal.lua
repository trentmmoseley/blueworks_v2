local MovementLocal   = {}

-- Services
local CAS             = game:GetService("ContextActionService")
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")

local DataController  = _G.Knit.GetController("DataController")

-- Player
local Player          = Players.LocalPlayer
local PlayerGui       = Player.PlayerGui
local Character       = Player.Character or Player.CharacterAdded:Wait()
local Humanoid        : Humanoid
local HRP             : Part

local WindSound		  = Player.PlayerGui.Sounds.Environment.FallingWind

-- Modules and objects
local Camera          = game.Workspace.CurrentCamera
local MovementRequest = require(RepStorage.Remotes.MovementRequest):Client()

local MMT_SETTINGS    = require(RepStorage.Modules.Data.MovementSettings)
local MobileButtons   = PlayerGui:WaitForChild("MobileButtons")

local PlaySound       = require(RepStorage.Modules.Util.PlaySound)
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)
local Progress        = require(RepStorage.Modules.Util.Math.Progress)

-- Vars and consts
local CONFIG          = {
    TEMP_SPEED        = 16,
    ACCELERATION      = 10, -- studs per second^2
    DECELERATION      = 14,
    MOBILE_DEAD_ZONE  = 0.1,
}

local SlidingInfo     = nil

local CurrentVelocity = Vector3.zero
local MobileInput     = Vector2.zero

local RUN_KB          = Enum.KeyCode.LeftShift
local CROUCH_KB       = Enum.KeyCode.C
local CRAWL_KB        = Enum.KeyCode.LeftControl

local RUN_KB_GP, CROUCH_KB_GP, CRAWL_KB_GP

-- [[ funcs ]] --

-- Mobile thumbstick
local function onThumbstick(_, inputstate, inputobj)
    if inputstate == Enum.UserInputState.Change or inputstate == Enum.UserInputState.Begin then
        MobileInput = inputobj.Position
    else
        MobileInput = Vector2.zero
    end
end

CAS:BindAction("MobileThumbstick", onThumbstick, false, Enum.KeyCode.Thumbstick1)

-- Main function
function MovementLocal.Function()
    Character:SetAttribute("inAir", false)

    -- Sets up keybinds
    RUN_KB = DataController:Get("Keybinds.Run.Keyboard")
    CROUCH_KB = DataController:Get("Keybinds.Crouch.Keyboard")
    CRAWL_KB = DataController:Get("Keybinds.Crawl.Keyboard")

    RUN_KB_GP = DataController:Get("Keybinds.Run.Gamepad")
    CROUCH_KB_GP = DataController:Get("Keybinds.Crouch.Gamepad")
    CRAWL_KB_GP = DataController:Get("Keybinds.Crawl.Gamepad")

    -- On movement changes
    Character:GetAttributeChangedSignal("MovementType"):Connect(function()
        local Mmt = Character:GetAttribute("MovementType")
        if Mmt == "SLIDE" and not SlidingInfo then
            local Sound = PlaySound(9118657617, "Slide", Character:FindFirstChild("Torso"), nil, 1/4, 1)
            SlidingInfo = {
                ["LastYPos"] = Character.PrimaryPart.CFrame.Position.Y,
                ["Speed"]    = 9/8,
                ["TimePos"]  = 0, -- for audio
                ["Sound"]	 = Sound
            }
        else
            if Mmt ~= "SLIDE" then
                SlidingInfo = nil
            end
        end
    end)

    -- On render
    RunService.RenderStepped:Connect(function(dt)
        local Character = Player.Character
        if Player.Team ~= game.Teams.Spectators and Character and Character.Parent then
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
            local MovementType = Character:GetAttribute("MovementType")

            HRP = Character.PrimaryPart
            if not Humanoid or not HRP or Humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

            Character:SetAttribute("inAir", Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall)

            -- Records input
            local RawInput = Vector2.zero
            if UIS.KeyboardEnabled then
                if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then
                    RawInput += Vector2.new(0, 1)
                end
                if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then
                    RawInput += Vector2.new(0, -1)
                end
                if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then
                    RawInput += Vector2.new(-1, 0)
                end
                if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then
                    RawInput += Vector2.new(1, 0)
                end
            end

            -- Mobile: thumbstick (apply deadzone)
            if MobileInput.Magnitude > CONFIG.MOBILE_DEAD_ZONE then
                RawInput += MobileInput
            end

            -- Clamp to unit length so diagonals aren't faster
            Character:SetAttribute("rawInputDetected", RawInput.Magnitude > 0)
            if RawInput.Magnitude > 1 then
                RawInput = RawInput.Unit
            end

            -- Converts input to world-space direction, determines target velocity
            local CamCF = Camera.CFrame
            local Forward = Vector3.new(CamCF.LookVector.X, 0, CamCF.LookVector.Z).Unit
            local Right = Vector3.new(CamCF.RightVector.X, 0, CamCF.RightVector.Z).Unit
            local WishDir = (Forward * RawInput.Y + Right * RawInput.X)

            -- Sliding
            local isSliding = SlidingInfo ~= nil
            if isSliding then
                -- Adjusts speed
                local YVel = (Character.PrimaryPart.CFrame.Position.Y - SlidingInfo["LastYPos"]) * (1 / dt)
                    
                SlidingInfo["LastYPos"] = Character.PrimaryPart.CFrame.Position.Y
                if YVel >= -0.25 and not Character:GetAttribute("inAir") then
                    SlidingInfo["Speed"] = math.max(SlidingInfo["Speed"] - math.max(math.abs(YVel / 10), 2) * dt, 1/4)
                else
                    SlidingInfo["Speed"] = math.min(SlidingInfo["Speed"] + (math.abs(YVel) / 30) * dt, 2)
                end

                if SlidingInfo["Speed"] <= 1/4 or MovementType ~= "SLIDE" then
                    SlidingInfo["Sound"]:Destroy()
                    SlidingInfo = nil
                else
                    if SlidingInfo["Sound"].TimePosition >= 3/4 then
                        SlidingInfo["Sound"].TimePosition = 5/8
                    end
                end

                -- Resets movement if no longer sliding
                if not SlidingInfo then
                    MovementRequest:Fire("WALK")
                else
                    -- Stops sliding if no input
                    if RawInput.Magnitude == 0 then
                        SlidingInfo = nil
                    end
                end
            end
            local UsedSpeed = MMT_SETTINGS[Character:GetAttribute("MovementType")].Speed * (SlidingInfo and SlidingInfo.Speed or 1)
            local TargetVelocity = WishDir * UsedSpeed

            -- Accelerate towards target velocity
            local LerpFactor
            if RawInput.Magnitude > 0 then
                LerpFactor = math.min(1, CONFIG.ACCELERATION * dt)
            else
                LerpFactor = math.min(1, CONFIG.DECELERATION * dt)
            end

            CurrentVelocity = CurrentVelocity:Lerp(TargetVelocity, LerpFactor)

            if Humanoid.JumpHeight >= 1 then
                local Params = RaycastParams.new()
                Params.FilterType = Enum.RaycastFilterType.Exclude
                Params.FilterDescendantsInstances = {Character, game.Workspace:FindFirstChild("Characters"), game.Workspace:FindFirstChild("Corpses"), Camera}

                local Direction = CurrentVelocity.Unit
                local Distance = CurrentVelocity.Magnitude * dt + 2

                local Hit = workspace:Raycast(
                    HRP.Position,
                    Direction * Distance,
                    Params
                )

                if Hit and Hit.Instance and Hit.Instance.Name ~= "_stair" and Hit.Instance.CanCollide == true then
                    CurrentVelocity = Vector3.zero
                end
            end
            
            -- Apply to Humanoid
            local Speed = CurrentVelocity.Magnitude * (SlidingInfo and SlidingInfo.Speed or 1) * (Humanoid.FloorMaterial == Enum.Material.Air and 1.25 or 1)
            Character:SetAttribute("MoveDirection", Vector3.new(RawInput.X, 0, RawInput.Y))
            Humanoid.WalkSpeed = Speed

            if Speed > 0.1 then
                Humanoid:Move(CurrentVelocity.Unit, false)
            else
                Humanoid:Move(Vector3.zero, false)
            end

            Humanoid.JumpHeight = Character:GetAttribute("Stamina") >= 20 and 3 or 0

            WindSound.Volume = math.abs(Character.PrimaryPart.AssemblyLinearVelocity.Y / 100) ^ 3
			WindSound.PlaybackSpeed = Lerp(0.75, 1.5, Progress(WindSound.Volume, 0, 1))
        end
    end)

    -- Keybinds
    UIS.InputBegan:Connect(function(input, gpe)
        if not gpe and not Player:GetAttribute("isChatting") then
            if input.KeyCode == Enum.KeyCode[RUN_KB] or input.KeyCode == Enum.KeyCode[RUN_KB_GP] then
                MovementRequest:Fire("RUN")
            elseif input.KeyCode == Enum.KeyCode[CROUCH_KB] or input.KeyCode == Enum.KeyCode[CROUCH_KB_GP] then
                if Character:GetAttribute("MovementType") ~= "RUN" then
                    MovementRequest:Fire(Character:GetAttribute("MovementType") ~= "CROUCH" and "CROUCH" or "WALK")
                else
                    MovementRequest:Fire("SLIDE") -- character slides when running + c
                end
            elseif input.KeyCode == Enum.KeyCode[CRAWL_KB] or input.KeyCode == Enum.KeyCode[CRAWL_KB_GP] then
                MovementRequest:Fire(Character:GetAttribute("MovementType") ~= "CRAWL" and "CRAWL" or "WALK")
            elseif input.KeyCode == Enum.KeyCode.Space then
                MovementRequest:Fire("JUMP")
            end
        end
    end)

    UIS.InputEnded:Connect(function(input, gpe)
        if not gpe and not Player:GetAttribute("isChatting") then
            if input.KeyCode == Enum.KeyCode[RUN_KB] or input.KeyCode == Enum.KeyCode[RUN_KB_GP] then
                MovementRequest:Fire("WALK")
            end
        end
    end)

    -- Mobile buttons
    MobileButtons.ButtonsHolder.Sprint.TextButton.MouseButton1Click:Connect(function()
        MovementRequest:Fire(Character:GetAttribute("MovementType") ~= "RUN" and "RUN" or "WALK")
    end)

    MobileButtons.ButtonsHolder.Crouch.TextButton.MouseButton1Click:Connect(function()
        if Character:GetAttribute("MovementType") ~= "RUN" and Character.Humanoid.WalkSpeed > 4 then
            MovementRequest:Fire(Character:GetAttribute("MovementType") ~= "CROUCH" and "CROUCH" or "WALK")
        else
            MovementRequest:Fire("SLIDE") -- character slides when running + c
        end
    end)

    MobileButtons.ButtonsHolder.Crawl.TextButton.MouseButton1Click:Connect(function()
        MovementRequest:Fire(Character:GetAttribute("MovementType") ~= "CRAWL" and "CRAWL" or "WALK")
    end)

    Character:GetAttributeChangedSignal("MovementType"):Connect(function()
        local Mmt = Character:GetAttribute("MovementType")

        -- Sprint button
        if Mmt == "RUN" then
            MobileButtons.ButtonsHolder.Sprint.TextLabel.Text = "WALK"
            MobileButtons.ButtonsHolder.Crouch.TextLabel.Text = "SLIDE"
        else
            MobileButtons.ButtonsHolder.Sprint.TextLabel.Text = "RUN"
            MobileButtons.ButtonsHolder.Crouch.TextLabel.Text = "CROUCH"
        end
    end)
end

return MovementLocal