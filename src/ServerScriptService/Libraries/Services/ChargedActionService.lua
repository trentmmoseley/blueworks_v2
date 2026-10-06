-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local CAS             = Knit.CreateService({
    Name              = "ChargedActionService",
    Client            = {
        ChargeBegin   = Knit.CreateSignal(),
        ChargeEnd     = Knit.CreateSignal()
    },

    ChargedActions    = {},
    CharService       = nil
})

-- [[ funcs ]] --

-- Initiates charged action
function CAS:ChargedAction(char : Model, name : string, length : number, sanitycheck : () -> (), allowinvslot : boolean?) : boolean
    -- Removes old attempt from table
    if self.ChargedActions[char][name] then
        self.ChargedActions[char][name] = nil
    end

    -- Inits charge
    local TimeInit = os.clock()
    local TimeEnd  = TimeInit + length

    self.ChargedActions[char][name] = {
        ChargeInit = TimeInit,
        ChargeEnd = TimeEnd
    }

    local Connection = nil
    local chargeSuccess = false

    local CharClass = self.CharService:GetCharacterClass(char)
    local PrevSlot = CharClass.InventoryClass.CurrentSlot

    Connection = RunService.PreSimulation:Connect(function(dt)
        if not (char and char:FindFirstAncestor("Workspace")) or os.clock() >= TimeEnd or (allowinvslot ~= true and CharClass.InventoryClass.CurrentSlot ~= PrevSlot) or sanitycheck() ~= true then
            chargeSuccess = os.clock() >= TimeEnd
            Connection:Disconnect()
            Connection = nil
        end
    end)

    repeat task.wait() until not Connection

    return chargeSuccess
end

-- Creates profile
function CAS:CreateProfile(char : Model)
    self.ChargedActions[char] = {}
    char.AncestryChanged:Connect(function()
        if not char:FindFirstAncestor("Workspace") then
            self.ChargedActions[char] = nil
        end
    end)

    print(self.ChargedActions[char])
end

function CAS:ManagePlayer(player : Player)
    player.CharacterAdded:Connect(function(char)
        self:CreateProfile(char)
    end)
end

-- On knit init completion
function CAS:KnitInit() : ()
    self.CharService = _G.Knit.GetService("CharService")

    for _, plr in Players:GetPlayers() do
        self:ManagePlayer(plr)
    end

    Players.PlayerAdded:Connect(function(plr)
        self:ManagePlayer(plr)
    end)
end

return CAS