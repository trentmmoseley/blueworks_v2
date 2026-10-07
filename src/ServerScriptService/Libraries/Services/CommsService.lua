-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local TCS               = game:GetService("TextChatService")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local CommsService      = Knit.CreateService({
    Name                = "CommsService",
    Client              = {
        MessageSend     = Knit.CreateSignal(),
        MessageReceive  = Knit.CreateSignal(),
        SubtitleReceive = Knit.CreateSignal(),
        CooldownInit    = Knit.CreateSignal(),
    }
})

local EffectMsgs        = require(RepStorage.Modules.Data.Dialog.EffectMessages)

local GameValues        = RepStorage:WaitForChild("GameValues")

-- Vars and consts
local PlrCooldowns      = {}

local MAX_CHARS         = 135
local MAX_DIST          = 100

local MSGS_PER_SEC      = 6

local MSG_COLORS        = {
    ["Red"]             = Color3.fromRGB(255, 0, 0),
    ["Green"]           = Color3.fromRGB(0, 255, 0),
    ["Cyan"]            = Color3.fromRGB(0, 255, 255),
    ["Rose"]            = Color3.fromRGB(255, 0, 100),
    ["White"]           = Color3.fromRGB(255, 255, 255),
}

local TEAM_COLORS       = {
    Spectators          = Color3.fromRGB(100, 121, 255),
    Squadmates          = Color3.fromRGB(190, 188, 188),
    Subjects            = Color3.fromRGB(121, 71, 178),
}

-- [[ funcs ]] --

-- Checks if a string is all blank
local function checkIfAllSpaces(str)
	return (str == "" or str == " " or #string.gsub(str, " ", "") == 0)
end

-- Removes duplicate spaces
local function removeDupeSpaces(str)
	return string.gsub(str, "%s%s+", " ")
end

-- Determines if players can communicate
function CommsService:playersCanChat(sender : Player, recipient : Player)
    return TCS:CanUsersChatAsync(sender.UserId, recipient.UserId) and (sender.Team == recipient.Team or sender.Team ~= game.Teams.Spectators) and (sender:GetAttribute("inGame") == recipient:GetAttribute("inGame") or recipient.Team == game.Teams.Spectators)
end

-- Sends message
function CommsService:SendMessage(sender : Player, recipient : Player, message : string, color : string, distance : number, radio : boolean)
    self.Client.MessageReceive:Fire(recipient, sender, message, GameValues.Bools.doFriendlyFire.Value and TEAM_COLORS.Spectators or TEAM_COLORS[color], distance, radio)
end

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

-- Filters string
function CommsService:FilterString(str, plr) : string
	local filteredstring
	local success, errormessage = pcall(function()
		filteredstring = game:GetService("TextService"):FilterStringAsync(str, plr.UserId, Enum.TextFilterContext.PublicChat)
		filteredstring = filteredstring:GetNonChatStringForUserAsync(plr.UserId)
	end)

	if not success then
		filteredstring = nil
		warn("Problem filtering message: "..errormessage)
	end

	return filteredstring
end

-- Determines if player on cooldown
function CommsService.Client:IsOnCooldown(plr : Player) : (boolean, number)
    local onCooldown = PlrCooldowns[plr.UserId] and PlrCooldowns[plr.UserId][2]
    local cooldownLength = onCooldown and (PlrCooldowns[plr.UserId] and PlrCooldowns[plr.UserId][1]) or 0

    return onCooldown, cooldownLength
end

-- On knit init completion
function CommsService:KnitInit() : ()
    local CharService = Knit.GetService("CharService")
    local EffectService = Knit.GetService("EffectService")
    self.TeamService = Knit.GetService("TeamService")

    -- Manages cooldowns
    task.spawn(function()
        while true do
            for plr, info in pairs(PlrCooldowns) do
                local Player = Players:GetPlayerByUserId(plr)
                if Player then
                    local Count = info[1]
                    local onCD = info[2]

                    PlrCooldowns[plr][1] = math.max(Count - 1, 0)
                    if PlrCooldowns[plr][1] == 0 then
                        PlrCooldowns[plr][2] = false
                        self.Client.CooldownInit:Fire(Player, false)
                    end
                else
                    PlrCooldowns[plr] = nil
                end
            end
            task.wait(1)
        end
    end)

    self.Client.MessageSend:Connect(function(player : Player, message : string)
        local radioOn = player:GetAttribute("radioOn")
        local inGame = self.TeamService:CharIsLoaded(player)
        local Character = inGame and (player.Character or player.CharacterAdded:Wait()) or nil

        if not checkIfAllSpaces(message) and (not PlrCooldowns[player.UserId] or not PlrCooldowns[player.UserId][2]) then
            -- Manages cooldown
            if not PlrCooldowns[player.UserId] then
                PlrCooldowns[player.UserId] = {0, false}
            end
            PlrCooldowns[player.UserId][1] += 1

            -- Turns on cooldown if message limit is reached
            if PlrCooldowns[player.UserId][1] >= MSGS_PER_SEC then
                PlrCooldowns[player.UserId][2] = true
                self.Client.CooldownInit:Fire(player, true)
            end

            -- Filters message
            local ShortenedMessage = string.sub(message, 1, MAX_CHARS)
            local FilteredMessage = self:FilterString(removeDupeSpaces(ShortenedMessage), player)
            if FilteredMessage then
                -- Broadcasts message
                local HeardPlayers = 0

                -- Distorts message if delirious
                if inGame and EffectService:Check(Character, "Delirium") then
                    FilteredMessage = EffectMsgs.Delirium[math.random(1, #EffectMsgs.Delirium)]
                end

                -- Noise
                local NoiseClass = CharService:GetCharacterClass(Character).NoiseClass
                if NoiseClass then
                    NoiseClass:SetNoise("Chat", #FilteredMessage, true)
                end

                for _, plr in Players:GetPlayers() do
                    local Char = self.TeamService:CharIsLoaded(plr) and (plr.Character or plr.CharacterAdded:Wait()) or nil
                    local rO = plr:GetAttribute("radioOn")

                    if self:playersCanChat(player, plr) then
                        local bothSpectators = plr.Team == game.Teams.Spectators and player.Team == game.Teams.Spectators
                        local Distance = (Char and Character) and (Char.PrimaryPart.Position - Character.PrimaryPart.Position).Magnitude or math.huge
                        if Distance <= MAX_DIST or (radioOn and rO) or bothSpectators or plr == player then
                            if player.Team == game.Teams.Spectators or plr ~= player then
                                HeardPlayers += 1
                            end

                            -- Makes message fully visible
                            if bothSpectators or (rO and radioOn) then
                                Distance = 0
                            end

                            -- Radio
                            local NC = CharService:GetCharacterClass(Char).NoiseClass
                            if NC and rO then
                                NC:SetNoise("Radio", 1, false)
                            end

                            -- Changes message if confused
                            local UsedMessage = FilteredMessage
                            if inGame and EffectService:Check(Char, "Confusion") then
                                UsedMessage = EffectMsgs.Confusion[math.random(1, #EffectMsgs.Confusion)]
                            end

                            -- off it goes
                            self:SendMessage(player, plr, UsedMessage, self.TeamService:GetTeam(player), Distance, radioOn and rO)
                        end
                    end
                end

                if HeardPlayers == 0 then
                    self:SendSubtitle(player, player, "Nobody heard you", "Rose")
                end
            end
        end
    end)
end

return CommsService