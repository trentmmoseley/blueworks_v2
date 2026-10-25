local Switch = {}

-- Generates random boolean
local function randomBool(rand : Random) : boolean
    return rand:NextInteger(0, 1) == 1
end

-- Generates current input for solution
function Switch.GenerateInput(node : Model, rand : Random) : {boolean}
    local Input = {}
    local ButtonCount = #node:WaitForChild("_puzzle").Buttons:GetChildren()

    for i = 1, ButtonCount do
        local RandomBool = randomBool(rand)
        if i == ButtonCount and not table.find(Input, true) then
            RandomBool = true
        end
        table.insert(Input, RandomBool)
    end

    return Input
end

-- Gets row and column of index
local function getRowColumn(index : number) : (number, number)
    local Row = math.floor((index - 1) / 3) + 1
    local Column = (index - 1) % 3 + 1
    return Row, Column
end

-- Handles a button press: toggles the button and its orthogonal neighbors
function Switch.HandleInput(data : {Input : {boolean}}, index : number, render : (index : number) -> ()) : ()
    local Row, Column = getRowColumn(index)

    for x = -1, 1 do
        for y = -1, 1 do
            local i = index + x + (y * 3)
            local NewRow, NewColumn = getRowColumn(i)
            if (x ~= 0 and y ~= 0) or math.abs(NewRow - Row) > 1 or math.abs(NewColumn - Column) > 1 then continue end

            if data.Input[i] ~= nil then
                data.Input[i] = not data.Input[i]
                render(i)
            end
        end
    end
end

-- Generate solution for Node: every button green
function Switch.GenerateSolution(node : Model) : {boolean}
    local Solution = {}
    local ButtonCount = #node:WaitForChild("_puzzle").Buttons:GetChildren()

    for i = 1, ButtonCount do
        Solution[i] = true
    end

    return Solution
end

return Switch
