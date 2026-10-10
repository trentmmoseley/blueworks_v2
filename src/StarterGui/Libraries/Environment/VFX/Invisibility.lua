-- Services
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules and objects
local Lerp         = require(RepStorage.Modules.Util.Math.Lerp)

-- Vars and consts
local TI           = TweenInfo.new(1/4)

-- Characters with an active invisibility effect, so it can be ended early from anywhere
local Active       = {}

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

-- Tweens a character back to its pre-invisibility appearance and forgets the effect
local function wearOff(char : Model)
    local Record = Active[char]
    if not Record then
        return
    end

    Active[char] = nil

    if Record.RevertThread then
        task.cancel(Record.RevertThread)
    end

    if Record.AddedConn then
        Record.AddedConn:Disconnect()
    end

    -- Transparency fades back in; anything that was disabled re-enables once the fade ends
    local Disabled = {}
    for _, restore in Record.Restores do
        local inst, prop, prev = restore[1], restore[2], restore[3]

        if inst.Parent then
            if prop == "Transparency" then
                TweenService:Create(inst, TI, {Transparency = prev}):Play()
            else
                table.insert(Disabled, restore)
            end
        end
    end

    if #Disabled > 0 then
        task.delay(TI.Time, function()
            for _, restore in Disabled do
                local inst, prop, prev = restore[1], restore[2], restore[3]

                if inst.Parent then
                    inst[prop] = prev
                end
            end
        end)
    end
end

-- Hides one visual instance and records how to restore it. Complete invisibility
-- also covers decals, beams, trails, particles, lights and on-character GUIs
local function hideInstance(inst : Instance, Record, full : boolean, strength : number)
    if Record.Hidden[inst] then
        return
    end

    if inst:IsA("BasePart") then
        local Target = full and 1 or (inst.Material ~= Enum.Material.Neon and calculateTP(strength) or 1)

        if inst.Transparency < Target then
            Record.Hidden[inst] = true
            table.insert(Record.Restores, {inst, "Transparency", inst.Transparency})
            TweenService:Create(inst, TI, {Transparency = Target}):Play()
        end
    elseif full then
        if inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("ParticleEmitter")
            or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles")
            or inst:IsA("Light") or inst:IsA("LayerCollector") then
            Record.Hidden[inst] = true
            table.insert(Record.Restores, {inst, "Enabled", inst.Enabled})
            inst.Enabled = false
        elseif inst:IsA("Decal") then
            Record.Hidden[inst] = true
            table.insert(Record.Restores, {inst, "Transparency", inst.Transparency})
            TweenService:Create(inst, TI, {Transparency = 1}):Play()
        end
    end
end

local Invisibility       = {

    -- Length <= 0 lasts until "End" is invoked for the same character.
    -- A Strength of math.huge renders the character completely invisible
    ["Effect"]           = {

        ["RENDER_DISTANCE"] = 2 ^ 10,
        ["Function"]        = function(args)
            local Char     = args[1]
            local Length   = args[2]
            local Strength = args[3]

            local Full = Strength == math.huge

            -- Re-applying while invisible refreshes the effect instead of stacking restores
            local Record = Active[Char]
            if Record then
                if Record.RevertThread then
                    task.cancel(Record.RevertThread)
                    Record.RevertThread = nil
                end

                if Record.AddedConn then
                    Record.AddedConn:Disconnect()
                    Record.AddedConn = nil
                end
            else
                Record = {Restores = {}, Hidden = {}, RevertThread = nil, AddedConn = nil}
                Active[Char] = Record

                Char.Destroying:Connect(function()
                    Active[Char] = nil
                end)
            end

            for _, inst in Char:GetDescendants() do
                hideInstance(inst, Record, Full, Strength)
            end

            -- Anything parented to the character while invisible gets hidden too
            Record.AddedConn = Char.DescendantAdded:Connect(function(inst)
                hideInstance(inst, Record, Full, Strength)
            end)

            if typeof(Length) == "number" and Length > 0 then
                Record.RevertThread = task.delay(Length, wearOff, Char)
            end
        end

    },

    -- Forces any active invisibility on the character to wear off; reaches every
    -- client so nobody keeps an outdated invisible copy of the character
    ["End"]              = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            wearOff(args[1])
        end

    },

}

return Invisibility
