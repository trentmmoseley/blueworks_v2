-- Services
local Players             = game:GetService("Players")
local RepStorage          = game:GetService("ReplicatedStorage")

-- Modules and objects
local DataController      = _G.Knit.CreateController({
    Name = "DataController",
    Data = {},
	DataChangedSignals = {},

	HasLoaded = false,
	Loaded = _G.Signal.new(),
})

local GetPath             = require(RepStorage.Modules.Util.GetPath)
local SetPath             = require(RepStorage.Modules.Util.SetPath)
local GetData             = require(RepStorage.Remotes.GetData)
local UpdateData          = require(RepStorage.Remotes.UpdateData):Client()

-- On knit init
function DataController:KnitInit()
    UpdateData:On(function(player, path, value)
        if not player or player.Parent ~= Players then
			return
		end

		local id = tostring(player.UserId)

		if not self.Data[id] and path == "" then
			self.Data[id] = value
			return
		end

		if not self.Data[id] then
			local elapsed = 0

			repeat
				task.wait(0)
			until self.Data[id] or elapsed > 5
		end

		if not self.Data[id] then
			return
		end

		local success = SetPath(self.Data[id], path, value)

		if not success then
			warn("Error occured when trying to update data")
			return
		end

		local signal = self:GetDataChangedSignal(path, player, true)

		if signal then
			signal:Fire(value)
		end
    end)

    local success, data = GetData:Call():Await()

	if success then
		self.Data = data
		task.wait()
	else
		warn("No success getting data")
	end

	self:Load()

	if not success then
		warn("Error occured when getting data")
		return
	end
end

function DataController:AwaitLoaded()
	if not self.HasLoaded or not self.Data[tostring(Players.LocalPlayer.UserId)] then
		self.Loaded:Wait()
	end
end

function DataController:Load()
	self.HasLoaded = true
	self.Loaded:Fire()
end

local function ValidatePlayer(player: Player?): Player?
	if not player then
		player = Players.LocalPlayer
	end

	if not player or player.Parent ~= Players then
		warn("Invalid player given", player)
		return nil
	end

	return player
end

function DataController:GetDataChangedSignal(path: string, player: Player?, dontCreate)
	player = ValidatePlayer(player)

	if not player then
		return
	end

	local id = tostring(player.UserId)

	if not self.DataChangedSignals[id] then
		self.DataChangedSignals[id] = {}
	end

	local signal = self.DataChangedSignals[id][path]

	if not signal and not dontCreate then
		signal = _G.Signal.new()
		self.DataChangedSignals[id][path] = signal
	end

	return signal
end

function DataController:Get(path: string, player: Player?)
	player = ValidatePlayer(player)

	if not player then
		return
	end

	local id = tostring(player.UserId)
	local dataTable = self.Data[id]

	if dataTable == nil then
		warn("Could not find data for player", player)
		return
	end

	local data = GetPath(dataTable, path)

	if data == nil then
		warn("Could not get data at path", path, "in table", dataTable)
		return
	end

	return data
end

return DataController