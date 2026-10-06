-- Services
local RepStorage      = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local SLService       = Knit.CreateService({
    Name = "StrayLootService",
    Client = {
        CollectLoot   = Knit:CreateSignal()
    }
})

local GunAttach       = require(RepStorage.Modules.Util.GunAttach)

-- [[ funcs ]] --

function SLService:AddLoot(tool : {}, position : Vector3, gunatts : {}?) : ()
    local NewLoot = Instance.new("Vector3Value")
    NewLoot.Name = string.format("Display%i", math.random(1, 9999999))
    NewLoot.Value = position
    NewLoot.Parent = self.Folder

    if gunatts then
        for att, val in gunatts do
            NewLoot:SetAttribute(att, val)
        end
    end

    for tag, val in tool do
        NewLoot:SetAttribute(tag, val)
    end

    local Raycast = game.Workspace:Raycast(position, Vector3.new(0, -99999, 0), RaycastParams.new())
    NewLoot:SetAttribute("GroundPosition", Raycast and Raycast.Position or position)
end

-- On knit init completion
function SLService:KnitInit() : ()
    self.CharacterService = Knit.GetService("CharService")
    self.CommsService = Knit.GetService("CommsService")
    self.InventoryService = Knit.GetService("InventoryService")

    self.Folder = Instance.new("Folder")
    self.Folder.Name = "StrayLoot"
    self.Folder.Parent = RepStorage

    self.Client.CollectLoot:Connect(function(player : Player, loot : Vector3Value)
        if loot and loot:IsDescendantOf(self.Folder) then
            local CharClass = self.CharacterService:GetCharacterClass(player.Character)
            local CompiledLoot = self.InventoryService:CompileLoot(loot)
            if CharClass and CharClass.InventoryClass and CharClass.InventoryClass:CanPickUp(loot:GetAttribute("Name")) == true then
                self.InventoryService:AddItem(player.Character, CompiledLoot)
                self.CommsService:SendSubtitle(nil, player, loot:GetAttribute("Name").." added to inventory", "White")
                loot:Destroy()
            end
        end
    end)
end

return SLService