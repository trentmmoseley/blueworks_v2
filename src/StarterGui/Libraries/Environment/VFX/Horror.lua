-- Services
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local PlayerGui     = Players.LocalPlayer.PlayerGui

local DetectService = _G.Knit.GetService("DetectionService")

-- Player
local Player        = Players.LocalPlayer

-- Modules and objects
local Camera        = game.Workspace.CurrentCamera
local Sounds        = PlayerGui.Sounds.Horror

-- Vars and consts
local SOUND_ORDER   = {"Far", "Medium", "Near"}
local DISTANCES     = {50, 20}

local NextHorror    = 0

local DetectionLevels = {}
local PendingHorrors  = {}
local PendingConnection : RBXScriptConnection? = nil

-- [[ funcs ]] --

local function playHorror(intensity : number) : boolean
    if os.clock() < NextHorror then return false end
    NextHorror = os.clock() + 10

    Camera.FieldOfView += 10 * intensity
    local SoundFolder = Sounds[SOUND_ORDER[intensity]]:GetChildren()
    local ChosenSound = SoundFolder[math.random(1, #SoundFolder)]
    ChosenSound:Play()

    return true
end

local function getIntensity(entity : Model) : number
    local Character = Player.Character
    if not (Character and Character.PrimaryPart and entity.PrimaryPart) then
        return 1
    end

    local Intensity = 1
    local DistanceFromPlayer = (entity.PrimaryPart.Position - Character.PrimaryPart.Position).Magnitude
    for _, distance in DISTANCES do
        if DistanceFromPlayer < distance then
            Intensity += 1
        end
    end

    return Intensity
end

local function isEntityVisible(entity : Model) : boolean
    if not entity.PrimaryPart or entity:GetAttribute("Invisible") == true then
        return false
    end

    local Position = entity.PrimaryPart.Position
    local ViewportPoint, OnScreen = Camera:WorldToViewportPoint(Position)
    if not OnScreen or ViewportPoint.Z <= 0 then
        return false
    end

    local Filter = {Camera}
    local Character = Player.Character
    if Character then
        table.insert(Filter, Character)
    end

    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = Filter

    local Raycast = game.Workspace:Raycast(Camera.CFrame.Position, Position - Camera.CFrame.Position, RayParams)
    return Raycast ~= nil and Raycast.Instance:IsDescendantOf(entity)
end

local function stopPendingCheckIfDone()
    if PendingConnection and next(PendingHorrors) == nil then
        PendingConnection:Disconnect()
        PendingConnection = nil
    end
end

local function updatePendingHorrors()
    for entity in pairs(PendingHorrors) do
        if not entity.Parent or DetectionLevels[entity] ~= 3 then
            PendingHorrors[entity] = nil
            DetectionLevels[entity] = nil
        elseif isEntityVisible(entity) then
            PendingHorrors[entity] = nil
            playHorror(getIntensity(entity))
        end
    end

    stopPendingCheckIfDone()
end

DetectService.DetectionUpdate:Connect(function(_, entity : Model?, level : number?)
    if not entity then return end

    if level and level > 0 then
        DetectionLevels[entity] = level
    else
        DetectionLevels[entity] = nil
        PendingHorrors[entity] = nil
        stopPendingCheckIfDone()
    end
end)

local Horror       = {

    ["Horror"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Entity = args[1]
            local DetectionLevel = args[2]

            if os.clock() < NextHorror or DetectionLevel ~= 3 or typeof(Entity) ~= "Instance" or not Entity:IsA("Model") then return end

            DetectionLevels[Entity] = DetectionLevel
            PendingHorrors[Entity] = true

            if not PendingConnection then
                PendingConnection = RunService.PreRender:Connect(updatePendingHorrors)
            end

            updatePendingHorrors()
        end,

    },

}

return Horror
