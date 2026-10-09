local LeaningAndFootsteps = {}

-- Services
local Players             = game:GetService("Players")
local RepStorage          = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")

-- Player
local Player              = Players.LocalPlayer
local MyChar              = Player.Character or Player.CharacterAdded:Wait()
local Mouse			      = Player:GetMouse()

-- Modules and objects
local Camera			  = game.Workspace.CurrentCamera
local ALUEvent            = RepStorage.Events.ArmLookUpdate

local LerpByFrame         = require(RepStorage.Modules.Util.Math.LerpByFrame)

-- Vars and consts
local MAX_DISTANCE_LN	  = 70

local NextDistCheck       = os.clock()
local OriginalM6DC0		  = {}

local NextAimOffsetCheck  = os.clock()
local MyAimOffset         = 0

local MOMENTUM_FACTOR  	  = 0.008
local MIN_MOMENTUM		  = 0
local MAX_MOMENTUM		  = math.huge
local SPEED 			  = 15

local PrevPositions       = {}

-- [[ funcs ]] --

-- Gets character by ID
local function getCharacterByID(id : number) : Model?
    for _, char in game.Workspace.Characters:GetChildren() do
        if char:GetAttribute("ID") == id then
            return char
        end
    end
end

-- Main function
function LeaningAndFootsteps.Function()
	-- Most stuff
	RunService.PreRender:Connect(function(dt)
        local QuarterLerp = LerpByFrame(1/4, dt)

        local checkBotVel = os.clock() >= NextDistCheck
        local LastCheck = NextDistCheck
        if checkBotVel then
            NextDistCheck = os.clock() + 1/4
        end

        -- Manages characters
		for _, Character in pairs(game.Workspace:WaitForChild("Characters"):GetChildren()) do
            if (Character == Players.LocalPlayer.Character and Player.CameraMode == Enum.CameraMode.LockFirstPerson) or Character:GetAttribute("isNPC") == true then continue end

            local Humanoid  = Character:WaitForChild("Humanoid")
            if Humanoid.Health <= 0 then continue end
            local HRP = Character.PrimaryPart
            
            local MovementType = Character:GetAttribute("MovementType")

            -- Died sound
            local Died = HRP:FindFirstChild("Died")
            if Died then
                Died.Volume = 0
            end

            local Distance = (HRP.Position - Camera.CFrame.Position).Magnitude

            -- borrowed from an open-source project by @SwenzjeGames_Dev (lead dev of Combat Warriors)
            if Distance <= MAX_DISTANCE_LN then
                -- Manages char. leaning
                local M6D = HRP["RootJoint"]
                local ID = Character:GetAttribute("ID")
                local isBot = not Players:GetPlayerFromCharacter(Character)

                if not OriginalM6DC0[ID] then
                    OriginalM6DC0[ID] = M6D.C0
                end

                local direction = HRP.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
                if isBot and checkBotVel then
                    if not PrevPositions[ID] then
                        PrevPositions[ID] = Character.PrimaryPart.CFrame.Position
                    end

                    direction = HRP.CFrame:VectorToObjectSpace(Character.PrimaryPart.CFrame.Position - PrevPositions[ID])
                end

                local momentum
                if MovementType ~= "SLIDE" and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                    momentum = HRP.CFrame:VectorToObjectSpace(HRP[isBot and "Velocity" or "AssemblyLinearVelocity"]) * MOMENTUM_FACTOR
                else
                    momentum = HRP.CFrame:VectorToObjectSpace(HRP[isBot and "Velocity" or "AssemblyLinearVelocity"]) * (MOMENTUM_FACTOR * .2)
                end

                momentum = Vector3.new(
                    math.clamp(math.abs(momentum.X), MIN_MOMENTUM, MAX_MOMENTUM),
                    0,
                    math.clamp(math.abs(momentum.Z), MIN_MOMENTUM, MAX_MOMENTUM)
                ) * (isBot and 6 or 1)
                
                local x = direction.X * momentum.X * (isBot and 6 or 1)
                local z = direction.Z * momentum.Z * (isBot and 6 or 1)

                local angles = nil
                if Humanoid.RigType == Enum.HumanoidRigType.R15 then
                    angles = {z, 0, -x}
                else
                    angles = {-z, -x, 0}
                end

                M6D.C0 = M6D.C0:Lerp(OriginalM6DC0[ID] * CFrame.Angles(unpack(angles)), dt * SPEED)

                -- Arm-look
                local UsedOffset = (Character == MyChar) and MyAimOffset or (Character:GetAttribute("AimOffset") or 0)
                local RightShoulder = Character.Torso["Right Shoulder"]
                local LeftShoulder = Character.Torso["Left Shoulder"]
                local Neck = Character.Torso["Neck"]

                local RightShoulderBase = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)
                local LeftShoulderBase = CFrame.new(-1, 0.5, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)

                if Character:FindFirstChildOfClass("Tool") and MovementType == "CRAWL" then
                    -- Arms extend forward toward the player's perspective while crawling with a tool
                    RightShoulder.C0 = RightShoulder.C0:Lerp(RightShoulderBase * CFrame.Angles(0, 0, math.pi / 2 - UsedOffset), QuarterLerp * 0.4)
                    LeftShoulder.C0 = LeftShoulder.C0:Lerp(LeftShoulderBase * CFrame.Angles(0, 0, UsedOffset - math.pi / 2), QuarterLerp * 0.4)
                else
                    RightShoulder.C0 = RightShoulder.C0:Lerp(RightShoulderBase * CFrame.fromEulerAnglesXYZ(0, 0, -UsedOffset), QuarterLerp * 0.4)
                    LeftShoulder.C0 = LeftShoulder.C0:Lerp(LeftShoulderBase * CFrame.fromEulerAnglesXYZ(0, 0, UsedOffset), QuarterLerp * 0.4)
                end

                Neck.C0 = Neck.C0:Lerp(CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0) * CFrame.fromEulerAnglesXYZ(UsedOffset, (Character:GetAttribute("isAiming") == true and math.pi / -6 or 0), 0), QuarterLerp / 5)
            end
		end

        -- Removes old IDs
        for id, _ in OriginalM6DC0 do
            if not getCharacterByID(id) then
                OriginalM6DC0[id] = nil
            end
        end

        -- Aim offset check (straight up ripped this code from the devforum LOL (by @vendinY))
        local Hit = (MyChar.Torso.Position.Y - Mouse.Hit.Position.Y) / 100
        local Magnitude = (MyChar.Torso.Position - Mouse.Hit.Position).Magnitude / 100
        local Offset = Hit / Magnitude

        MyAimOffset = Offset

        if os.clock() >= NextAimOffsetCheck then
            NextAimOffsetCheck = os.clock() + 1/2
            ALUEvent:FireServer(MyAimOffset)
        end
	end)
end

return LeaningAndFootsteps