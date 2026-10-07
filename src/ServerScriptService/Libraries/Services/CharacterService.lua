-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local S2                = game:GetService("ServerStorage")
local S3                = game:GetService("ServerScriptService")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)
local CharService      = Knit.CreateService({
    Name = "CharService",
    Client = {
        DeviceUpdate  = Knit.CreateSignal(),
    },
    Characters = {},
})

CharService.ClassAdded = _G.Signal.new()

local CharacterClass   = require(S3.Libraries.Classes.CharacterClass)

-- [[ funcs ]] --

-- Gets all registered characters
function CharService:GetAllCharClasses() : {{}}?
    return self.Characters
end

-- Gets char class
function CharService:GetCharacterClass(character : Model) : {}?
    if not character or not character:IsA("Model") then
        warn(`Invalid character: {character}`)
        return
    end

    if not self.Characters[character] then
        local WaitStart = os.clock()
        repeat task.wait() until self.Characters[character] or os.clock() >= WaitStart + 3
    end

    if not self.Characters[character] then
        warn(`Did not find CharacterClass of Entity \"{character.Name}\"`)
    end

    return self.Characters[character]
end

-- Gets character by IDs
function CharService.Client:GetCharacterByID(id : number) : Model?
    for _, char in game.Workspace.Characters:GetChildren() do
        if char:GetAttribute("ID") == id then
            return char
        end
    end
end

-- Manages character
function CharService:ManageCharacter(character : Model) : ()
    -- Stores character class
    if self.Characters[character] then return end

    character.Parent = self.CharacterFolder
    local CharClass = CharacterClass.new(character)
    CharClass:Start()
    self.Characters[character] = CharClass

    character:SetAttribute("ID", math.random(0, 9999999))
    character:SetAttribute("isNPC", CharClass.isNPC)

    -- never break joints on death server-side: the client ragdolls an intact rig
    local Humanoid = character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.BreakJointsOnDeath = false
        Humanoid.RequiresNeck = false
    end

    -- Footstep sounds
	S2.Player.Character.FootstepSounds:Clone().Parent = character.PrimaryPart

    -- On character unload
    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self.Characters[character] = nil
            CharClass:Destroy()
        end
    end)
end

-- Manages player
function CharService:ManagePlayer(plr : Player) : ()
    if plr.Character then
        CharService:ManageCharacter(plr.Character)
    end

    plr.CharacterAdded:Connect(function(char : Model)
        CharService:ManageCharacter(char)
    end)
end

-- On knit init completion
function CharService:KnitInit() : ()
    self.CharacterFolder = game.Workspace:FindFirstChild("Characters")

    if not self.CharacterFolder then
        self.CharacterFolder = Instance.new("Folder")
        self.CharacterFolder.Name = "Characters"
        self.CharacterFolder.Parent = game.Workspace
    end

    -- Tracks all characters
    for _, char in self.CharacterFolder:GetChildren() do
        self:ManageCharacter(char)
    end

    self.CharacterFolder.ChildAdded:Connect(function(char : Model)
        self:ManageCharacter(char)
    end)
    
    for _, plr in Players:GetPlayers() do
        self:ManagePlayer(plr)
    end

    Players.PlayerAdded:Connect(function(plr : Player)
        self:ManagePlayer(plr)
    end)

    -- Device update
    self.Client.DeviceUpdate:Connect(function(plr : Player, device : string)
        plr:SetAttribute("Device", device)
    end)

    -- Arm-look update
    RepStorage.Events.ArmLookUpdate.OnServerEvent:Connect(function(player, offset)
        if player.Team ~= game.Teams.Spectators then
            local Character = player.Character or player.CharacterAdded:Wait()
            Character:SetAttribute("AimOffset", offset)
        end
    end)
end

return CharService