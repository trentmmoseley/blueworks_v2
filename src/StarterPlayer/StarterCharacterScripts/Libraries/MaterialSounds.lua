local MaterialSounds  = {}

-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Player
local Player          = Players.LocalPlayer

-- Modules and objects
local Characters      = game.Workspace:WaitForChild("Characters")
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)

-- Vars and consts
local REPLICATE_WAIT  = 10 -- max seconds to wait for a rig's parts to replicate in

-- playback speed is fit linearly through the two anchors the footstep sounds were
-- mixed at (WALK speed 10 -> 1.25, RUN speed 24 -> 2), so any WalkSpeed sounds as
-- fast as it moves, for players and NPCs alike
local SPEED_A, SPEED_B = 10, 24
local RATE_A, RATE_B   = 1.25, 2
local RATE_SLOPE       = (RATE_B - RATE_A) / (SPEED_B - SPEED_A)
local RATE_BASE        = RATE_A - RATE_SLOPE * SPEED_A

-- Changes sound ID
local function changeSoundID(sound, humanoid)
    local Character = humanoid.Parent

    -- rig destroyed or unloaded (e.g. fell out of the world): bail out instead of yielding
    if not (Character and Character.Parent) then
        return
    end

    local ThisPlayer = Players:GetPlayerFromCharacter(Character)
    local RootPart = Character:FindFirstChild("HumanoidRootPart")
    local FootstepSounds = RootPart and RootPart:FindFirstChild("FootstepSounds")

    if not FootstepSounds then
        return
    end

    local Material = humanoid.FloorMaterial
    if Material ~= nil then
        Material = string.split(tostring(Material), "Enum.Material.")[2]
    else
        Material = "Air"
    end

    local FabricSpeed = Material == "Fabric" and 1 or 1 / 1.45
    if ThisPlayer ~= Player then
        FabricSpeed = Material ~= "Fabric" and 1 or 1.45
    end

    -- Sound volume + playback speed
    local Sound = FootstepSounds:FindFirstChild(Material)
    if Sound then
        sound.SoundId = Sound.SoundId
    end
    sound.Volume = (Sound and Character:GetAttribute("isMoving") and humanoid.WalkSpeed > 1 and Material ~= "Air" and Character:FindFirstAncestor("Characters")) and 1 or 0

    -- playback speed tracks the rig's actual WalkSpeed, so running sounds faster,
    -- walking sounds slower, and NPCs (which never set a MovementType) match too
    local LerpVal = (RATE_BASE + RATE_SLOPE * humanoid.WalkSpeed) * FabricSpeed
    sound.PlaybackSpeed = Lerp(sound.PlaybackSpeed, LerpVal, 1/4)
end

-- Manages character
local function manageCharacter(char : Model)
    -- rig parts replicate in after the model itself; wait with a timeout so an
    -- unloaded or destroyed rig can never yield this thread forever
    local RootPart = char:WaitForChild("HumanoidRootPart", REPLICATE_WAIT)
    local Humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", REPLICATE_WAIT)

    if not (RootPart and Humanoid and char.Parent) then
        return
    end

    local SoundParent = char.PrimaryPart or RootPart

    local RunSound = SoundParent:FindFirstChild("_run")
    if not RunSound then
        RunSound = Instance.new("Sound")
        RunSound.Name = "_run"
        RunSound.Parent = SoundParent
        RunSound.Looped = true
    end

    local OldRun = RootPart:FindFirstChild("Running")
    if OldRun then
        OldRun.Volume = 0
    end

    -- Changes footstep sound
    changeSoundID(RunSound, Humanoid)
    local ChangedConn = Humanoid.Changed:Connect(function()
        changeSoundID(RunSound, Humanoid)
    end)

    -- walking sounds must never outlive the character
    local DiedConn = Humanoid.Died:Connect(function()
        RunSound:Stop()
        RunSound.Volume = 0
    end)

    local AncestryConn
    AncestryConn = char.AncestryChanged:Connect(function(_, parent)
        if parent then
            changeSoundID(RunSound, Humanoid)
            return
        end

        -- rig left the game: drop every connection and the looping sound so nothing
        -- keeps firing (and potentially yielding) against a destroyed rig
        ChangedConn:Disconnect()
        DiedConn:Disconnect()
        AncestryConn:Disconnect()
        RunSound:Destroy()
    end)

    RunSound:Play()

    -- Jump sound
    local JumpingSound = RootPart:FindFirstChild("Jumping")
    if JumpingSound then
        JumpingSound.SoundId = "rbxassetid://9120728815"
    end
end

-- Main function
function MaterialSounds.Function()
    -- Manages characters
    for _, char in Characters:GetChildren() do
        task.spawn(manageCharacter, char)
    end

    Characters.ChildAdded:Connect(manageCharacter)
end

return MaterialSounds
