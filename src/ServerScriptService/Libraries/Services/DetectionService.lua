-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local DetectionService  = Knit.CreateService({
    Name                = "DetectionService",
    Client              = {
        DetectionUpdate = Knit.CreateSignal()
    },
    DetectedPlayers     = {}
})

-- [[ funcs ]] --

-- Updates player detection status
function DetectionService:DetectPlayer(entity : Model, target : Model, level : number?, subtract : boolean?)
    local PlayerInfo = self.DetectedPlayers[target:GetAttribute("ID")]
    if subtract ~= true and level > 0 then -- initiate detection status
        if not PlayerInfo then
            self.DetectedPlayers[target:GetAttribute("ID")] = {}
            PlayerInfo = self.DetectedPlayers[target:GetAttribute("ID")]
        end
        
        local FoundInfo = nil
        for _, info in pairs(PlayerInfo) do
            if info[1] == entity then
                FoundInfo = info
                info[2] = level
                break
            end
        end

        if not FoundInfo then
            table.insert(self.DetectedPlayers[target:GetAttribute("ID")], {entity, level})
        end
    else
        if PlayerInfo then
            for i, v in pairs(PlayerInfo) do
                if v[1] == entity then
                    table.remove(PlayerInfo, i)
                end
            end

            if #PlayerInfo == 0 then
                self.DetectedPlayers[target:GetAttribute("ID")] = nil
            else
                self.DetectedPlayers[target:GetAttribute("ID")] = PlayerInfo
            end
        end
    end

    -- Sends update to player
    local Player = Players:GetPlayerFromCharacter(target)
    if Player then
        local HighestLevel = 0
        PlayerInfo = self.DetectedPlayers[target:GetAttribute("ID")]

        if PlayerInfo then
            for i, info in pairs(PlayerInfo) do
                if info[2] > HighestLevel then
                    HighestLevel = info[2]
                    if HighestLevel == 3 then
                        break
                    end
                end
            end
        end

        self.Client.DetectionUpdate:Fire(Player, HighestLevel)
    end
end

-- Clears detection table
function DetectionService:ClearDetection(entity : Model)
    self.DetectedPlayers[entity:GetAttribute("ID")] = nil

    local Player = Players:GetPlayerFromCharacter(entity)
    if Player then
        self.Client.DetectionUpdate:Fire(Player, 0)
    end
end

return DetectionService