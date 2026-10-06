local InvRep = {}

-- Gets item in inventory
function InvRep:GetItemOfName(items : {}, name : string) : {}?
    for _, item in items do
        if item.Name == name then
            return item
        end
    end
end

-- Gets index of item in inventory
function InvRep:GetItemIndexOfName(items : {}, name : string) : number?
    for index, item in items do
        if item.Name == name then
            return index
        end
    end
end

-- Gets next available slot of inventory
function InvRep:GetNextAvailableSlot(items : {}, maxslots : number) : number?
    for i = 1, maxslots do
        if not items[i] then
            return i
        end
    end
end

-- Determines if player can pick up item
function InvRep:CanPickUp(name : string, items : {}, maxslots : number) : boolean | string
    local FoundItem = InvRep:GetItemOfName(items, name)

    -- inventory is full (Items is slot-indexed and may contain holes from
    -- dropped items, so #items is unreliable; scan for a free slot instead)
    if not FoundItem and not InvRep:GetNextAvailableSlot(items, maxslots) then
        return "Inventory full"
    end

    if FoundItem then
        if FoundItem.Stack >= FoundItem.MAX_STACK then -- item cannot be stacked further
            return "Stack full"
        end
    end

    return true
end

return InvRep