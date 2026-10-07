-- Services
local Players            = game:GetService("Players")
local RepStorage         = game:GetService("ReplicatedStorage")
local Rand               = Random.new()
local RunService         = game:GetService("RunService")

local HealthClass        = {}
HealthClass.__index      = HealthClass

-- Modules and objects
local PlaySound          = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local HURT_ANIM          = 114679864298651

-- Constructor
function HealthClass.new(charclass : {}) : {}
    local Self = setmetatable({}, HealthClass)
    Self.CharacterClass = charclass
    Self.Rig = charclass.Character
    Self.Humanoid = Self.Rig.Humanoid

    Self.ClassName = "HealthClass"
    Self.Classes = {}

    Self.canAttack = true
    Self.canBeAttacked = true
    Self.humanoidDiesOnZero = true

    Self.ProxPrompt = Instance.new("ProximityPrompt")
    Self.ProxPrompt.ActionText = "Save"
    Self.ProxPrompt.ObjectText = Self.Rig.Name
    Self.ProxPrompt.HoldDuration = 5
    Self.ProxPrompt.Enabled = false
    Self.ProxPrompt.KeyboardKeyCode = Enum.KeyCode.F
    Self.ProxPrompt.Parent = Self.Rig.PrimaryPart

    local Anim = Instance.new("Animation")
    Anim.AnimationId = "rbxassetid://"..HURT_ANIM
    Self.HurtAnim = Self.Humanoid.Animator:LoadAnimation(Anim)
    Self.HurtAnim.Looped = false

    Self.DownedStep = nil

    return Self
end

-- Sets Health
function HealthClass:Set(number : number) : ()
    self.Rig:SetAttribute("Health", math.clamp(number, 0, self.Rig:GetAttribute("MaxHealth")))
end

-- Increments Health
function HealthClass:Increment(number : number) : ()
    self:Set(self.Rig:GetAttribute("Health") + number)
end

-- Damages player
function HealthClass:Damage(amount  : number, skipanim : boolean?) : ()
    if self.Rig:GetAttribute("isDowned") == false then
        self:Increment(-amount)
    else
        self.Humanoid:TakeDamage(amount)
    end

    if not skipanim then
        -- self.HurtAnim:Play()
    end
end

-- Insta-kills player
function HealthClass:InstaKill() : ()
    self:Set(0)
    self.Humanoid.Health = 0
end

-- Downs player
function HealthClass:DownPlayer()
    self.Rig:SetAttribute("isDowned", true)
    self.ProxPrompt.Enabled = true

    PlaySound(18841759984, "Downed", self.Rig.PrimaryPart, nil, 1, 1)

    self.DownedStep = RunService.PreSimulation:Connect(function(dt)
        if self.Rig and self.Rig.Parent and self.Rig:GetAttribute("isDowned") == true then
            if self.Rig:GetAttribute("beingSaved") ~= true then
                self.Rig.Humanoid.Health -= dt
            end
        else
            self.ProxPrompt.Enabled = false
            self.DownedStep:Disconnect()
            self.DownedStep = nil
        end
    end)
end

-- Starts class
function HealthClass:Start() : ()
    -- Starts all sub-classes
    for _, class in self.Classes do
		task.spawn(function()
			if class.Start then
				class:Start()
			end

			self[class.ClassName] = class
		end)
	end

    -- Sets up character
    self.Rig:SetAttribute("Health", 100)
    self.Rig:SetAttribute("MaxHealth", 100)
    self.Rig:SetAttribute("isDowned", false)
    self.Rig:SetAttribute("beingSaved", false)
    self.Rig:SetAttribute("isRagdolled", false)

    -- Removes Health script
    local HealthScript = self.Rig:FindFirstChild("Health")
    if HealthScript then
       HealthScript:Destroy() 
    end

    -- Save prompt
    local ProxPrompt : ProximityPrompt = self.ProxPrompt
    
    local function isTeammate(plr)
        return _G.Knit.GetService("TeamService"):AreTeammates(plr.Character or plr.CharacterAdded:Wait(), self.Rig)
    end

    ProxPrompt.PromptButtonHoldBegan:Connect(function(plrwhotriggered)
        if isTeammate(plrwhotriggered) then
            self.Rig:SetAttribute("beingSaved", true)
        end
    end)

    ProxPrompt.PromptButtonHoldEnded:Connect(function(plrwhotriggered)
        if isTeammate(plrwhotriggered) then
            self.Rig:SetAttribute("beingSaved", false)
        end
    end)

    ProxPrompt.Triggered:Connect(function(plrwhotriggered)
        if isTeammate(plrwhotriggered) then
            self.Rig:SetAttribute("isDowned", false)
            self.Rig:SetAttribute("beingSaved", false)
            self:Set(self.Rig:GetAttribute("MaxHealth"))

            _G.Knit.GetService("ScoreService"):AwardScore(plrwhotriggered.Character or plrwhotriggered.CharacterAdded:Wait(), 35, "Saved teammate", true)
        end
    end)

    -- On Humanoid death
    self.Humanoid.Died:Connect(function()
        print("i have died")
    end)
end

-- Destructor + stops class
function HealthClass:Destroy() : ()
    -- Unloads sub-classes
    for _, class in self.Classes do
		if class.Destroy then
			class:Destroy()
		end
	end

    self.ProxPrompt:Destroy()
    if self.DownedStep then
        self.DownedStep:Disconnect()
    end

    setmetatable(self, nil)
    table.clear(self)
    table.freeze(self)
end

return HealthClass