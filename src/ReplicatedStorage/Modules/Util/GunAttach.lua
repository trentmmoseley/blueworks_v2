-- Services
local RepStorage = game:GetService("ReplicatedStorage")

-- Modules and objects
local Atts       = RepStorage.PlayerRep.Attachments
local WeldPiece  = require(RepStorage.Modules.Util.WeldPiece)

-- [[ funcs ]] --

local function IsModBlacklisted(ModBlacklist : {[any] : any}?, att : string) : boolean
    if not ModBlacklist then return false end
    return ModBlacklist[att] == true or table.find(ModBlacklist, att) ~= nil
end

-- Attachments
return function(gun : Tool | Model, attachments : {[string] : string}?)
    local UsedAttachments = attachments or {}
    local ModBlacklist = require(gun.Configuration.ItemInfo).ModBlacklist

    local AttsFolder = Instance.new("Folder")
    AttsFolder.Name = "Attachments"
    AttsFolder.Parent = gun

    -- removes pre-existing attachments
    local PreExistingAtts = gun:FindFirstChild("Attachments", true)
    if PreExistingAtts then
        PreExistingAtts:ClearAllChildren()
    end

    -- reassigns pre-existing attachments
    for _, att in gun.Handle._attachments:GetChildren() do
        if IsModBlacklisted(ModBlacklist, att.Name) then continue end
        if not UsedAttachments[att.Name] then
            UsedAttachments[att.Name] = gun:GetAttribute(att.Name)
        end
    end

    -- attaches attachments
    for att, val in UsedAttachments do
        if IsModBlacklisted(ModBlacklist, att) then continue end
        if not val then continue end
        local NewAtt = Atts[att]:FindFirstChild(val, true):Clone()
        NewAtt.Parent = AttsFolder
        local ItemInfo = require(NewAtt.Configuration.ItemInfo)

        for _, part in pairs(NewAtt:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = false
            end
        end

        local FoundWeld = gun.Handle._attachments:FindFirstChild(att)
        if FoundWeld then 
            NewAtt:PivotTo(FoundWeld.CFrame)
            WeldPiece(NewAtt.PrimaryPart, FoundWeld)

            if ItemInfo.Class == "Suppressor" then
                NewAtt.Name = "_suppressor"
            end

            gun:SetAttribute(att, val)
        end
    end
end