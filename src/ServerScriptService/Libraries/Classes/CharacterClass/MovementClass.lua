-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local Rand            = Random.new()

local MovementClass   = {}
MovementClass.__index = MovementClass

-- Modules and objects
-- local FallDamage 	  = require(RepStorage.Remotes.FallDamage):Server()
local MMT_SETTINGS    = require(RepStorage.Modules.Data.MovementSettings)
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local DEFAULT_JUMP      = 2
local FLAG_THRESHOLD    = 30
local FDV_THRESHOLD     = 35 -- fall at 30+ studs per second to sustain fall damage
local POS_INTERVAL      = 1/8 -- seconds between position checks for players
local NPC_POS_INTERVAL  = 1/4 -- seconds between position checks for NPCs

local FD_SOUNDS       = {121870043011805}

-- Calculates fall damage
local function calcFallDamage(vel)
	return (1.75 * (vel - FDV_THRESHOLD)) ^ 1.1
end

-- Constructor
function MovementClass.new(charclass : {}) : {}
    local Self = setmetatable({}, MovementClass)
    Self.CharacterClass = charclass
    Self.Character = charclass.Character
    Self.Humanoid = Self.Character:FindFirstChildOfClass("Humanoid")

    Self.ClassName = "MovementClass"
    Self.Classes = {}

    Self.MmtChangedConn = nil
    Self.StateChangedConn = nil
    Self.Rig = charclass.Character
    Self.NoiseClass = charclass.NoiseClass
    Self.Player = Players:GetPlayerFromCharacter(charclass.Character)

    -- Movement monitoring
    Self.FlagLevel = 0 -- if it reaches FLAG_THRESHOLD, flag user for cheating
    Self.Flagged = false
    Self.Velocity = Vector3.zero
    Self.PrevPos = Vector3.zero
    Self.NextPosCheck = 0

    return Self
end

-- Determines if character is moving
function MovementClass:IsMoving() : boolean
    return self.Velocity.Magnitude >= 1
end

-- Starts class
function MovementClass:Start()
    if self.CharacterClass.Player and self.CharacterClass.Player.Team == game.Teams.Spectators then return end

    -- Sets up character
    self.Character:SetAttribute("MovementType", "WALK")
    self.Character:SetAttribute("Speed", MMT_SETTINGS.WALK.Speed)
    self.Hitbox = self.Character:WaitForChild("Hitbox")

    self.NextPosCheck = os.clock()
    self.PrevPos = self.Character.PrimaryPart.CFrame.Position
    local SlidingInfo = nil

    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- On movement changes
    self.MmtChangedConn = self.Character:GetAttributeChangedSignal("MovementType"):Connect(function()
        local Mmt = self.Character:GetAttribute("MovementType")
        if Mmt == "SLIDE" and not SlidingInfo then
            self.CharacterClass.StaminaClass:SetStamina(-MMT_SETTINGS[Mmt].MinStamina, true)
        end
    end)

    -- Landing + fall damage
    self.StateChangedConn = self.Humanoid.StateChanged:Connect(function(old, new)
        if old == Enum.HumanoidStateType.Freefall and new == Enum.HumanoidStateType.Landed then
            local YVel = -self.Character.PrimaryPart.AssemblyLinearVelocity.Y
            if YVel > FDV_THRESHOLD then
                local FD = math.clamp(calcFallDamage(YVel), 0, math.huge)
                _G.Knit.GetService("CombatService"):Damage(nil, self.Character, FD, "FALL_DAMAGE", "DEFAULT", true, nil, {"Leg"})
                PlaySound(FD_SOUNDS[math.random(1, #FD_SOUNDS)], "FD", self.Character.Torso, nil, 1, Rand:NextNumber(0.95, 1.05))

                if self.Player then
                    -- FallDamage:Fire(self.Player, math.abs(YVel))
                    warn("register fall damage")
                end

                if YVel >= 60 then
                    _G.Knit.GetService("EffectService"):Add(self.Character, "Bleeding", YVel * 0.75)

                    if YVel >= 80 then
                        _G.Knit.GetService("EffectService"):Add(self.Character, "Arterial Bleeding", 99999)
                    end
                end
            end
        end
    end)
end

-- Per-step movement monitor (called from CharClass)
function MovementClass:Step(dt)
    self.FlagLevel = math.max(self.FlagLevel - dt, 0)
    if self.FlagLevel == 0 then
        self.Flagged = false
    end

    local isMoving = self.Velocity.Magnitude >= 0.01
    if isMoving ~= self._lastIsMoving then
        self._lastIsMoving = isMoving
        self.Character:SetAttribute("isMoving", isMoving)
    end

    local MovementType = self.Character:GetAttribute("MovementType")

    -- Downed
    if self.Character:GetAttribute("isDowned") then
        if MovementType ~= "DOWNED" then
            MovementType = "DOWNED"
            self.Character:SetAttribute("MovementType", MovementType)
        end
    elseif MovementType == "DOWNED" then
        MovementType = "WALK"
        self.Character:SetAttribute("MovementType", MovementType)
    end

    local MmtInfo = MMT_SETTINGS[MovementType]

    if os.clock() >= self.NextPosCheck then
        self.NextPosCheck = os.clock() + (self.Player and POS_INTERVAL or NPC_POS_INTERVAL)

        -- Anti-cheat below only runs if char. class contains player
        local CurrentPos = self.Character.PrimaryPart.CFrame.Position
        local Displacement = (CurrentPos - self.PrevPos)

        if self.Player and self.Humanoid.Health > 0 then
            local Threshold = MmtInfo.Speed * 9/8 * 1/4 * (MovementType == "SLIDE" and 2 or 1)

            if Displacement.Magnitude > Threshold then
                self.FlagLevel = math.min(self.FlagLevel + 1, FLAG_THRESHOLD)

                if self.FlagLevel >= FLAG_THRESHOLD and not self.Flagged then
                    self.Flagged = true
                    warn("FLAGGED FOR CHEATING")
                end
            end
        end

        self.PrevPos = CurrentPos
        self.Velocity = Displacement
    end

    local JumpHeight = DEFAULT_JUMP * (MmtInfo.canJump and 1 or 0)
    if JumpHeight ~= self._lastJumpHeight then
        self._lastJumpHeight = JumpHeight
        self.Humanoid.JumpHeight = JumpHeight
    end
end

-- Destructor + stops class
function MovementClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    if self.MmtChangedConn then
        self.MmtChangedConn:Disconnect()
        self.MmtChangedConn = nil
    end

    if self.StateChangedConn then
        self.StateChangedConn:Disconnect()
        self.StateChangedConn = nil
    end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return MovementClass
