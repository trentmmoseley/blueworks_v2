-- Services
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local TCS               = game:GetService("TextChatService")

-- Modules and objects
local Knit              = require(RepStorage.Packages.Knit)
local CommsService      = Knit.CreateService({
    Name                = "CommsService",
    Client              = {
        SubtitleReceive = Knit.CreateSignal(),
        CooldownInit    = Knit.CreateSignal(),
    }
})

local GenChannel        = TCS:WaitForChild("General")

-- Vars and consts
local PlrCooldowns      = {}

local MAX_DIST          = 100

local MSGS_PER_SEC      = 6

-- Message text is not readable by game code under PlatformIntegratedChat, so noise uses a fixed length
local NOMINAL_MSG_LEN   = 20

local MSG_COLORS        = {
    ["Red"]             = Color3.fromRGB(255, 0, 0),
    ["Green"]           = Color3.fromRGB(0, 255, 0),
    ["Cyan"]            = Color3.fromRGB(0, 255, 255),
    ["Rose"]            = Color3.fromRGB(255, 0, 100),
    ["White"]           = Color3.fromRGB(255, 255, 255),
}

-- MessageStates[message] = whether the message was sent while on cooldown (blocked from delivery)
local MessageStates     = {}

-- ChatPairs[senderId][recipientId] = whether the sender is permitted to chat with the recipient
local ChatPairs         = {}

-- [[ funcs ]] --

-- Determines if players can communicate
function CommsService:playersCanChat(sender : Player, recipient : Player)
    local PairCache = ChatPairs[sender.UserId]
    local CanChat = if PairCache and PairCache[recipient.UserId] ~= nil then PairCache[recipient.UserId] else true

    return CanChat and (sender.Team == recipient.Team or sender.Team ~= game.Teams.Spectators) and (sender:GetAttribute("inGame") == recipient:GetAttribute("inGame") or recipient.Team == game.Teams.Spectators)
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

-- Determines if player on cooldown
function CommsService.Client:IsOnCooldown(plr : Player) : (boolean, number)
    local onCooldown = PlrCooldowns[plr.UserId] and PlrCooldowns[plr.UserId][2]
    local cooldownLength = onCooldown and (PlrCooldowns[plr.UserId] and PlrCooldowns[plr.UserId][1]) or 0

    return onCooldown, cooldownLength
end

-- On knit init completion
function CommsService:KnitInit() : ()
    local CharService = Knit.GetService("CharService")
    self.TeamService = Knit.GetService("TeamService")

    -- Returns the player's character if it's loaded into a playable team
    local function getLoadedChar(plr : Player) : Model?
        local Character = plr.Character
        return (Character and Character:GetAttribute("Team") ~= "Spectators") and Character or nil
    end

    -- Determines if a recipient can hear a sender's message
    local function canHear(sender : Player, recipient : Player) : boolean
        if not self:playersCanChat(sender, recipient) then
            return false
        end

        local bothSpectators = recipient.Team == game.Teams.Spectators and sender.Team == game.Teams.Spectators
        local SenderChar     = getLoadedChar(sender)
        local RecipChar      = getLoadedChar(recipient)
        local Distance       = (SenderChar and RecipChar and SenderChar.PrimaryPart and RecipChar.PrimaryPart)
            and (RecipChar.PrimaryPart.Position - SenderChar.PrimaryPart.Position).Magnitude or math.huge

        return Distance <= MAX_DIST or bothSpectators or recipient == sender
    end

    -- Returns a character's noise class without yielding
    local function getNoiseClass(Character : Model?)
        if Character and CharService.Characters[Character] then
            return CharService:GetCharacterClass(Character).NoiseClass
        end
    end

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

    -- Gates delivery of every chat message; runs once per recipient on the server
    GenChannel.ShouldDeliverCallback = function(textChatMessage : TextChatMessage, textSource : TextSource) : boolean
        local sender = textChatMessage.TextSource and Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
        local recipient = Players:GetPlayerByUserId(textSource.UserId)
        if not sender or not recipient then
            return true
        end

        -- Once-per-message bookkeeping
        if MessageStates[textChatMessage] == nil then
            local onCooldown = PlrCooldowns[sender.UserId] ~= nil and PlrCooldowns[sender.UserId][2]
            MessageStates[textChatMessage] = onCooldown
            task.delay(30, function()
                MessageStates[textChatMessage] = nil
            end)

            if not onCooldown then
                -- Manages cooldown
                if not PlrCooldowns[sender.UserId] then
                    PlrCooldowns[sender.UserId] = {0, false}
                end
                PlrCooldowns[sender.UserId][1] += 1

                -- Turns on cooldown if message limit is reached
                if PlrCooldowns[sender.UserId][1] >= MSGS_PER_SEC then
                    PlrCooldowns[sender.UserId][2] = true
                    self.Client.CooldownInit:Fire(sender, true)
                    self:SendSubtitle(sender, sender, "Chat cooldown", "Rose")
                end

                -- Noise
                local NoiseClass = getNoiseClass(getLoadedChar(sender))
                if NoiseClass then
                    NoiseClass:SetNoise("Chat", NOMINAL_MSG_LEN, true)
                end

                -- Lets the sender know if their message reached nobody
                local HeardPlayers = 0
                for _, plr in Players:GetPlayers() do
                    if canHear(sender, plr) and (sender.Team == game.Teams.Spectators or plr ~= sender) then
                        HeardPlayers += 1
                    end
                end

                if HeardPlayers == 0 then
                    self:SendSubtitle(sender, sender, "Nobody heard you", "Rose")
                end
            end
        end

        if MessageStates[textChatMessage] then
            return false
        end

        return canHear(sender, recipient)
    end
end

-- On knit start completion
function CommsService:KnitStart() : ()
    -- Adds a player to the chat channel and warms their chat permission cache
    local function initPlayer(plr : Player)
        task.spawn(function()
            pcall(function()
                GenChannel:AddUserAsync(plr.UserId)
            end)

            ChatPairs[plr.UserId] = ChatPairs[plr.UserId] or {}
            for _, other in Players:GetPlayers() do
                for _, pair in {{plr, other}, {other, plr}} do
                    local pairSender, pairRecipient = pair[1], pair[2]

                    ChatPairs[pairSender.UserId] = ChatPairs[pairSender.UserId] or {}
                    if ChatPairs[pairSender.UserId][pairRecipient.UserId] == nil then
                        task.spawn(function()
                            local success, result = pcall(TCS.CanUsersChatAsync, TCS, pairSender.UserId, pairRecipient.UserId)
                            ChatPairs[pairSender.UserId][pairRecipient.UserId] = success and result or true
                        end)
                    end
                end
            end
        end)
    end

    for _, plr in Players:GetPlayers() do
        initPlayer(plr)
    end
    Players.PlayerAdded:Connect(initPlayer)

    Players.PlayerRemoving:Connect(function(plr : Player)
        ChatPairs[plr.UserId] = nil
        for _, cache in pairs(ChatPairs) do
            cache[plr.UserId] = nil
        end
    end)
end

return CommsService
