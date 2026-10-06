-- Welds a piece of clothing to a player
return function(part0, part1, m6d : boolean?)
	local NewWeld = Instance.new(not m6d and "Weld" or "Motor6D") -- no parent yet
    NewWeld.Part0 = part0
    NewWeld.Part1 = part1
    NewWeld.C0 = NewWeld.Part0.CFrame:ToObjectSpace(NewWeld.Part1.CFrame)
    NewWeld.Parent = part1 -- parent set last

    return NewWeld
end