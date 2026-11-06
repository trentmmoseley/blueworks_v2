-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local CommsService      = Knit.CreateService({
    Name                = "CommsService",
    Client              = {
        SubtitleReceive = Knit.CreateSignal(),
    }
})

-- Vars and consts
local MSG_COLORS        = {
    ["Red"]             = Color3.fromRGB(255, 0, 0),
    ["Green"]           = Color3.fromRGB(0, 255, 0),
    ["Cyan"]            = Color3.fromRGB(0, 255, 255),
    ["Rose"]            = Color3.fromRGB(255, 0, 100),
    ["White"]           = Color3.fromRGB(255, 255, 255),
}

-- [[ funcs ]] --

-- Sends subtitle
function CommsService:SendSubtitle(sender : Player, recipient : Player, message : string, color : Color3 | string)
    self.Client.SubtitleReceive:Fire(recipient, sender, message, MSG_COLORS[color] or color)
end

-- Sends global subtitle
function CommsService:GlobalSubtitle(message : string, color : Color3 | string, onlyplayers : boolean?)
    for _, plr in Players:GetPlayers() do
        if not onlyplayers or self.TeamService:IsInGame(plr) then
            self:SendSubtitle(nil, plr, message, color)
        end
    end
end

-- On knit init completion
function CommsService:KnitInit() : ()
    self.TeamService = Knit.GetService("TeamService")
end

return CommsService
