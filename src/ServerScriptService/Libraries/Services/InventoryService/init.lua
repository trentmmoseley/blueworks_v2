-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local S2                = game:GetService("ServerStorage")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local InvService        = Knit.CreateService({
    Name = "InventoryService",
    Client = {
        ActionRequest   = Knit.CreateSignal(),
        ToolAdded       = Knit.CreateSignal(),
        ToolRemoved     = Knit.CreateSignal(),
        UpdateInventory = Knit.CreateSignal()
    }
})

local Tools             = S2.Tools
InvService.ItemAdded    = _G.Signal.new()

local GunAttach         = require(RepStorage.Modules.Util.GunAttach)

-- Vars and consts
local COMPILE_VALS      = {"Stack", "Ammo", "Class"} -- values that carry with a specific item 
local SKIP_VALS         = {"Name", "Tier", "MAX_STACK"}

-- [[ funcs ]] --

-- Compiles tool
function InvService:CompileTool(tool: Tool) : {}
    local Compiled = {}
    local ItemInfo = require(tool.Configuration.ItemInfo)

    Compiled["Name"] = tool.Name
    Compiled["Tier"] = ItemInfo.Tier
    Compiled["MAX_STACK"] = ItemInfo.Stack

    for _, val in pairs(COMPILE_VALS) do
        if val == "Ammo" and ItemInfo.Class ~= "Ranged" then continue end
        local Default = val == "Ammo" and ItemInfo.Mag or val == "Class" and ItemInfo.Class or 1
        Compiled[val] = tool:GetAttribute(val) or Default
    end

    for tag, val in tool:GetAttributes() do
        Compiled[tag] = val
    end

    return Compiled
end

-- Assigns tool values
function InvService:AssignValues(tool : Tool, compiled : {}) : ()
    for tag, val in compiled do
        if table.find(SKIP_VALS, tag) then continue end
        tool:SetAttribute(tag, val)
    end
end

-- Compiles loot
function InvService:CompileLoot(loot : Vector3Value) : {}
    local Compiled = {}

    for attr, val in loot:GetAttributes() do
        Compiled[attr] = val
    end

    return Compiled
end

-- Serializes the slot-indexed Items table into a string-keyed dictionary for
-- transport. Sparse numeric arrays lose every entry past the first nil hole
-- when fired through a remote, which made items in later slots vanish from
-- the client GUI while remaining equipped server-side. The client converts
-- the keys back with tonumber().
function InvService:SerializeItems(items : {}) : {}
    local Serialized = {}

    for slot, item in items do
        Serialized[tostring(slot)] = item
    end

    return Serialized
end

-- Adds item to inventory
function InvService:AddItem(char : Model, tool : Tool | {}) : ()
    local CharClass = self.CharService:GetCharacterClass(char)
    if not CharClass then return end
    local InvClass = CharClass.InventoryClass
    if not InvClass then return end

    local FoundIndex = InvClass:GetItemIndexOfName(tool.Name)
    local NextAvailableSlot = InvClass:GetNextAvailableSlot()
    local updateSlot = false
    local UsedSlot = 0

    if FoundIndex or NextAvailableSlot then
        if FoundIndex then -- tool of same name exists
            local FoundItem = InvClass.Items[FoundIndex]
            if FoundItem.Stack < FoundItem.MAX_STACK then
                FoundItem.Stack = math.max(math.min(FoundItem.Stack + 1, FoundItem.MAX_STACK), 1)
                -- Keep the equipped Tool's Stack attribute in sync with the table
                local EquippedTool = char:FindFirstChild(FoundItem.Name)
                if EquippedTool and EquippedTool:IsA("Tool") then
                    EquippedTool:SetAttribute("Stack", FoundItem.Stack)
                end
            end
        else -- new tool
            local Compiled = typeof(tool) == "table" and tool or self:CompileTool(tool)
            Compiled.Stack = math.max(Compiled.Stack or 1, 1) -- Stacks must never go below 1
            updateSlot = true
            UsedSlot = (InvClass.CurrentSlot > 0 and not InvClass.Items[InvClass.CurrentSlot]) and InvClass.CurrentSlot or NextAvailableSlot
            -- Items is slot-indexed (holes from dropped items are valid), so assign the
            -- slot directly. table.insert would shift all later items up one slot and
            -- could push the last one past MaxSlots, making it vanish from the UI.
            InvClass.Items[UsedSlot] = Compiled
        end

        if CharClass.Player then
            self.Client.UpdateInventory:Fire(CharClass.Player, self:SerializeItems(InvClass.Items), InvClass.CurrentSlot, InvClass.MaxSlots)
            if updateSlot then
                self.ItemAdded:Fire(CharClass.Player, UsedSlot)
            end
        end
    end
end

-- On knit init completion
function InvService:KnitInit() : ()
    self.CharService = Knit.GetService("CharService")
    self.StrayLootService = Knit.GetService("StrayLootService")
    self.CollisionService = Knit.GetService("CollisionService")

    -- Compiles displays for all items
    local DisplayFolder = Instance.new("Folder")
    DisplayFolder.Name = "ItemDisplays"
    DisplayFolder.Parent = RepStorage

    for _, folder in S2.Tools:GetChildren() do
        for _, tool in folder:GetChildren() do
            local Model = Instance.new("Model")
            local ItemInfo = require(tool.Configuration.ItemInfo)
            Model.Name = tool.Name
            Model:SetAttribute("DisplayTilt", ItemInfo.DisplayTilt or 0)

            for _, part in tool:GetChildren() do
                part:Clone().Parent = Model
            end

            Model.PrimaryPart = Model.Handle.Parts.DisplayPart
            Model.Parent = DisplayFolder
        end
    end

    local CharFolder = game.Workspace:WaitForChild("Characters")
    CharFolder.ChildAdded:Connect(function(char)
        local Class = self.CharService:GetCharacterClass(char)

        local InvClass = Class.InventoryClass

        if not InvClass then return end
        
        local Player = Class.Player
        local Character = Class.Character
        local Humanoid : Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local CurrentItem : Tool? = nil
        local CurrentItemInfo = nil
        local Compiled = nil
        local CurrentModule = nil
        local ItemConnection : RBXScriptConnection? = nil
        local UnequipConnection : RBXScriptConnection? = nil
        local StackConnection : RBXScriptConnection? = nil

        local function updateInv()
            if not Player then return end
            self.Client.UpdateInventory:Fire(Player, self:SerializeItems(InvClass.Items), InvClass.CurrentSlot, InvClass.MaxSlots)
        end

        -- Completely unloads the equipped item: clears its inventory slot,
        -- destroys the tool, and disconnects its listeners
        local function unloadItem()
            if not CurrentItem then return end

            if CurrentModule and CurrentModule.onUnequip then
                CurrentModule.onUnequip()
            end
            self.Client.ToolRemoved:Fire(Player, CurrentItemInfo)

            -- Disconnect listeners BEFORE destroying so they cannot double-fire
            if UnequipConnection then
                UnequipConnection:Disconnect()
                UnequipConnection = nil
            end
            if ItemConnection then
                ItemConnection:Disconnect()
                ItemConnection = nil
            end
            if StackConnection then
                StackConnection:Disconnect()
                StackConnection = nil
            end

            InvClass.Items[InvClass.CurrentSlot] = nil
            InvClass.CurrentSlot = 0
            Humanoid:UnequipTools()
            CurrentItem:Destroy()
            CurrentItem = nil
            CurrentItemInfo = nil
            Compiled = nil
            CurrentModule = nil

            updateInv()
        end

        local function swapItem(slot : number, override : boolean?)
            -- Removes old item
            if CurrentItem then
                -- Explicitly notify client of removal BEFORE destroying the tool.
                -- Relying on Unequipped is unreliable because Destroy() may suppress it.
                if CurrentModule and CurrentModule.onUnequip then
                    CurrentModule.onUnequip()
                end
                self.Client.ToolRemoved:Fire(Player, CurrentItemInfo)

                -- Disconnect the old listener so it cannot double-fire later
                if UnequipConnection then
                    UnequipConnection:Disconnect()
                    UnequipConnection = nil
                end
                if StackConnection then
                    StackConnection:Disconnect()
                    StackConnection = nil
                end

                InvClass.Items[InvClass.CurrentSlot] = self:CompileTool(CurrentItem)
                Humanoid:UnequipTools()
                CurrentItem:Destroy()
                CurrentItem = nil
                Compiled = nil
            end

            -- Moves to new slot (forced to 0 while downed or in a checkpoint)
            local NewSlot = not char:GetAttribute("isDowned") and slot or 0
            InvClass.CurrentSlot = math.clamp((NewSlot ~= InvClass.CurrentSlot or override == true) and NewSlot or 0, 0, InvClass.MaxSlots)
            updateInv()

            -- Disconnects old connections
            if ItemConnection then
                ItemConnection:Disconnect()
                ItemConnection = nil
            end

            -- Equips new item
            local Item = InvClass.Items[InvClass.CurrentSlot]
            if Item then
                CurrentItem = Tools:FindFirstChild(Item.Name, true):Clone()
                -- Strip physics from the tool's parts before they enter the
                -- world, so no physics step sees them colliding or massive
                self.CollisionService:PrepareTool(CurrentItem)
                CurrentItem.Parent = Character
                CurrentItemInfo = require(CurrentItem.Configuration.ItemInfo)
                Compiled = Item
                self:AssignValues(CurrentItem, Compiled)
                Humanoid:EquipTool(CurrentItem)

                local Attachments = CurrentItemInfo.Class == "Ranged" and {} or nil

                if CurrentItemInfo.Class == "Ranged" then
                    GunAttach(CurrentItem, Attachments)
                end

                -- Equip
                CurrentModule = require(script[CurrentItemInfo.Class]).initItem(CurrentItem, Character)
                CurrentModule.onEquip()
                self.Client.ToolAdded:Fire(Player, CurrentItemInfo, Attachments)

                -- Unequip (capture by value so future swaps don't corrupt this closure)
                local CapturedItemInfo = CurrentItemInfo
                local CapturedModule = CurrentModule
                UnequipConnection = CurrentItem.Unequipped:Connect(function()
                    if CapturedModule and CapturedModule.onUnequip then
                        CapturedModule.onUnequip()
                    end
                    self.Client.ToolRemoved:Fire(Player, CapturedItemInfo)
                end)

                -- Completely unload the item if its Stack ever drops below 1
                -- (e.g. a Healer consuming its last use); otherwise keep the
                -- inventory table (and the client GUI) in sync with the tool,
                -- since Healer uses only decrement the tool attribute
                local CapturedItem = CurrentItem
                StackConnection = CapturedItem:GetAttributeChangedSignal("Stack"):Connect(function()
                    local NewStack = CapturedItem:GetAttribute("Stack") or 0

                    if NewStack < 1 then
                        unloadItem()
                    else
                        local Item = InvClass.Items[InvClass.CurrentSlot]
                        if Item and Item.Name == CapturedItem.Name then
                            Item.Stack = NewStack
                            updateInv()
                        end
                    end
                end)

                -- Use
                if CurrentItemInfo.Class ~= "Ranged" then
                    ItemConnection = CurrentItem.Activated:Connect(function()
                        CurrentModule.onActivate()
                    end)
                else
                    ItemConnection = Character:GetAttributeChangedSignal("isFiring"):Connect(function()
                        if Character:GetAttribute("isFiring") == true then
                            CurrentModule.onActivate()
                        else
                            CurrentModule.onDeactivate()
                        end
                    end)
                end

                -- Deactivate
                CurrentItem.Deactivated:Connect(CurrentModule.onDeactivate)
            end
        end

        updateInv()

        self:AddItem(Character, S2.Tools.Ranged["Sniper Rifle"])
        self:AddItem(Character, S2.Tools.Ranged["Desert Eagle"])

        -- Action request
        local ActionRequest = nil
        ActionRequest = self.Client.ActionRequest:Connect(function(player, action, ...)
            if player ~= Player or player.Team ~= game.Teams.Squadmates then return end

            local Info = {...}

            if not (Class and Class.GunClass) then ActionRequest:Disconnect() return end

            Class.GunClass:ToggleAiming(false)

            if action == "SWAP" then
                swapItem(Info[1])
            elseif action == "DROP" and CurrentItem then
                -- Firing/reloading only mutates the equipped tool's attributes;
                -- the cached inventory table is stale (it is normally re-synced
                -- on swap), so recompile from the live tool before cloning.
                -- Otherwise the dropped loot carries the equip-time Ammo value
                -- and recollecting the gun replenishes its loaded ammo.
                Compiled = self:CompileTool(CurrentItem)
                Compiled.Stack -= 1

                -- The dropped loot is a single item: give it its own table with Stack 1
                -- instead of the inventory's table, whose Stack was just decremented.
                local DroppedItem = table.clone(Compiled)
                DroppedItem.Stack = 1

                local GunAttachments : {}?
                if CurrentItemInfo.Class == "Ranged" then
                    GunAttachments = _G.Knit.GetService("GunService"):GetAttachments(CurrentItem)
                end

                if Compiled.Stack > 0 then
                    InvClass.Items[InvClass.CurrentSlot] = Compiled
                end

                -- Keep the equipped Tool's Stack attribute in sync with the table.
                -- If this takes Stack below 1, the Stack watcher completely unloads
                -- the item (clears its slot, destroys the tool) for us.
                CurrentItem:SetAttribute("Stack", Compiled.Stack)

                updateInv()

                -- Char drops loot not any further than three studs away
                local RaycastParams = RaycastParams.new()
                RaycastParams.FilterDescendantsInstances = {Character}
                RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

                local LookVector = Character.PrimaryPart.CFrame.LookVector
                local Origin = Character.PrimaryPart.Position
                local Direction = LookVector * 3

                local RaycastResult = game.Workspace:Raycast(Origin, Direction, RaycastParams)
                local Position = RaycastResult and RaycastResult.Position or Origin + Direction

                self.StrayLootService:AddLoot(DroppedItem, Position, GunAttachments)
            elseif action == "USE" and CurrentItem then
                CurrentModule.onActivate()
            end
        end)

        -- Collecting item
        self.ItemAdded:Connect(function(p : Player, index : number)
            if Player and p == Player and (InvClass.CurrentSlot or InvClass.CurrentSlot == index) then
                swapItem(index, true)
            end
        end)

        -- Downed
        char:GetAttributeChangedSignal("isDowned"):Connect(function()
            if char:GetAttribute("isDowned") == true then
                swapItem(0, true)
            end
        end)

        -- Brainwashed
        char:GetAttributeChangedSignal("beingBrainwashed"):Connect(function()
            if char:GetAttribute("beingBrainwashed") == true then
                swapItem(0, true)
            end
        end)
    end)
end

return InvService