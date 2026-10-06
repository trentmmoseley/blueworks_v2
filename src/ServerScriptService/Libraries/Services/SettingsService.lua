-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)
local SetsService      =  Knit.CreateService({
    Name               = "SettingsService",
    Client             = {
        UpdateSetting  = Knit.CreateSignal()
    }
})

-- Vars and consts
local SETTINGS         = {
    inGame             = {false, false}, -- default value, is changeable
    isChatting         = {false, true},
    onChatCD           = {false, true},
    radioOn            = {false, true}
}

-- [[ funcs ]] --

-- On knit init completion
function SetsService:KnitInit() : ()
    -- Sets default values for players
    Players.PlayerAdded:Connect(function(player : Player)
        for setname, setinfo in SETTINGS do
            player:SetAttribute(setname, setinfo[1])
        end
    end)

    -- Update setting
    self.Client.UpdateSetting:Connect(function(player : Player, setname : string, newval : any)
        if SETTINGS[setname] ~= nil and typeof(newval) == typeof(SETTINGS[setname][1]) then
            player:SetAttribute(setname, newval)
        else
            warn(`Illegal value change attempt of "{setname}" made by @{player.Name}`)
        end
    end)
end

return SetsService