local Weather      = {}

-- Services
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")

-- Modules and objects
local GameStats    = RepStorage.GameValues
local ServerStats  = RepStorage.ServerStats
local WeightSystem = require(RepStorage.Modules.Util.Math.WeightSystem)

-- [[ funcs ]] --

-- Main function
function Weather.Init(map)
    local MapInfo = require(map.MapInfo)
	local MapEnv = MapInfo.Environment

    local Temps = MapEnv.Temperatures
	local WeatherChances = MapEnv.Weather

    -- Temperature + time of day
    repeat task.wait() until ServerStats.Date.Season.Value > 0
    GameStats.Numbers.Temperature.Value = Temps[ServerStats.Date.Season.Value] + Rand:NextNumber(-1, 1) / 10
	GameStats.Strings.TimeOfDay.Value = MapEnv.TimeOfDay

    -- Weather
    local W = {}
    local FinalWeather = {}

    for weather, chance in WeatherChances do
        table.insert(W, {weather, chance})
    end

    table.sort(W, function(a, b)
        return a[2] < b[2]
    end)

    for _, info in ipairs(W) do
        FinalWeather[info[1]] = info[2]
    end

    local ChosenWeather = WeightSystem(FinalWeather)
    GameStats.Strings.Weather.Value = ChosenWeather

    -- Determines if it snows
	local SnowChance = 1 - (GameStats.Numbers.Temperature.Value + 0.68) ^ 10
	GameStats.Bools.doSnow.Value = Rand:NextNumber() <= SnowChance
end

return Weather