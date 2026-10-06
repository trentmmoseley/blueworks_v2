-- Services
local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local S3               = game:GetService("ServerScriptService")

-- Modules and objects
local Knit             = require(RepStorage.Packages.Knit)
local DataService      = Knit.CreateService({
    Name               = "DataService",
    Client             = {},
    Profiles           = {}
})

local DataTemplate     = require(RepStorage.Modules.Data.DataTemplate)
local ProfileStore     = require(S3.Libraries.ProfileStore.ProfileStore)

local NameParts        = require(RepStorage.Modules.Util.NameParts)

local GetData          = require(RepStorage.Remotes.GetData)
local GetPath          = require(RepStorage.Modules.Util.GetPath)
local SetPath          = require(RepStorage.Modules.Util.SetPath)
local UpdateData       = require(RepStorage.Remotes.UpdateData)

-- Vars and consts
local StoreKey         = "PlayerData"..(RunService:IsStudio() and "_Dev" or "")

-- [[ funcs ]] --

-- Manages player
function DataService:ManagePlayer(player : Player)
    -- Initialize profile session for player
    local Profile = self.PlayerStore:StartSessionAsync(`{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end
    })

    -- Handling profile session
    if Profile ~= nil then -- success
        Profile:AddUserId(player.UserId)
        Profile:Reconcile()

        Profile.OnSessionEnd:Connect(function()
            self.Profiles[player.UserId] = nil
            player:Kick("Profile session ended. Please rejoin.")
        end)

        if player.Parent == Players then
            self.Profiles[player.UserId] = Profile
            print(`Profile initialized for {NameParts(player)}!`)
        else -- player left before session started
            Profile:EndSession()
        end
    else -- failure; should only happen if server shuts down
        player:Kick("Profile load failed. Please rejoin.")
    end
end

-- On knit init completion
function DataService:KnitInit() : ()
    self.PlayerStore = ProfileStore.New(StoreKey, DataTemplate)

    -- Manages players
    for _, player in Players:GetPlayers() do
        self:ManagePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player : Player)
        self:ManagePlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player : Player)
        local Profile = self.Profiles[player.UserId]
        if Profile then
            Profile:EndSession()
        end
    end)

    -- Remote data request
    GetData:SetCallback(function(player)
        if not self.Profiles[player.UserId] then
			repeat
				task.wait()
			until self.Profiles[player.UserId] or (not player or player.Parent ~= Players)
		end

		return self:GetData()
    end)
end

function DataService:GetProfile(player: Player)
	local profile = self.Profiles[player.UserId]

	while not profile and player and player.Parent == Players do
		profile = self.Profiles[player.UserId]
		task.wait()
	end

	return profile
end

function DataService:GetData()
	local Data = {}

	for id, profile in self.Profiles do
		local player = Players:GetPlayerByUserId(id)

		if player and player.Parent == Players then
			Data[tostring(id)] = profile.Data
		end
	end

	return Data
end

function DataService:Get(player: Player, path: string)
	local profile = self:GetProfile(player)

	if not profile then
		warn("Could not get profile for player", player)
		return
	end

	if path == "" then
		return profile.Data
	end

	local data = GetPath(profile.Data, path)

	if data == nil then
		warn("Could not find data for", player, "at path", path)
		return
	end

	return data
end

function DataService:Set(player: Player, path: string, value: any)
	local profile = self:GetProfile(player)

	if not profile then
		warn("Could not get profile for player", player)
		return
	end

	local success = SetPath(profile.Data, path, value, function(currentValue)
		if typeof(currentValue) ~= typeof(value) then
			warn(
				"Given incorrect value type ("
					.. typeof(value)
					.. ") for value ("
					.. typeof(currentValue)
					.. ") at "
					.. path
			)
			return false
		else
			return true
		end
	end)

	if not success then
		return
	end

	UpdateData:FireAll(player, path, value)

	local signal = self:GetDataChangedSignal(player, path, true)

	if signal then
		signal:Fire(value)
	end
end

function DataService:Increment(player: Player, path: string, amount: number)
	if not amount then
		amount = 1
	end

	local current = self:Get(player, path)

	if not current or typeof(current) ~= "number" then
		warn("Path:", path, "has value type", typeof(current), ", it must be a number to increment.")
		return
	end

	self:Set(player, path, current + amount)
end

function DataService:GetDataChangedSignal(player: Player, path: string, dontCreate: boolean)
	local profile = self:GetProfile(player)

	if not profile then
		return
	end

	if not self.DataChangedSignals[player] then
		self.DataChangedSignals[player] = {}
	end

	local signal = self.DataChangedSignals[player][path]

	if not signal and not dontCreate then
		signal = _G.Signal.new()
		self.DataChangedSignals[player][path] = signal
	end

	return signal
end

return DataService