-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)

-- Vars and consts
local TI           = TweenInfo.new(1/4)

-- [[ funcs ]] --

local function calculateTP(strength : number)
    local TP = 0.85

    if strength > 1 then
        for i = 1, strength - 1 do
            strength = Lerp(TP, 1, 2/3)
        end

        return strength
    end

    return TP
end

local Invisibility       = {

    ["Effect"]           = {

        ["RENDER_DISTANCE"] = 2 ^ 10,
        ["Function"]        = function(args)
            local Char = args[1]
            local Length = args[2]
            local Strength = args[3]

            for _, part in pairs(Char:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    local PrevTP = part.Transparency
                    task.spawn(function()
                        TweenService:Create(part, TI, {Transparency = part.Material ~= Enum.Material.Neon and calculateTP(Strength) or 1}):Play()
                        task.wait(Length)
                        TweenService:Create(part, TI, {Transparency = PrevTP}):Play()
                    end)
                end
            end
        end

    },

}

return Invisibility