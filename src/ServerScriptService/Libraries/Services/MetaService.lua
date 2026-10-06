-- Services
local DSS		      = game:GetService("DataStoreService")
local HTTPService	  = game:GetService("HttpService")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

local GVStore   	  = DSS:GetDataStore("GameVersion")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local MetaService     = Knit.CreateService({
    Name = "MetaService",
    Client = {}
})

local ServerStats     = RepStorage.ServerStats
local Location        = ServerStats.Location
local Version         = ServerStats.Version

-- Vars and consts
local GV_KEY      	  = "GAME_VERSION"
local NextCheck   	  = os.clock()
local NextLocate  	  = os.clock()

local SERVER_START    = os.clock()

-- [[ funcs ]] --

-- Fetches location
local function fetchLocation()
    task.spawn(function()
        local ServerRegion = HTTPService:GetAsync("http://ip-api.com/json/")
        ServerRegion = HTTPService:JSONDecode(ServerRegion)
        Location.Region.Value = ServerRegion["regionName"]
        Location.Country.Value = ServerRegion["countryCode"]
    end)
end

function MetaService.KnitInit() : ()
    -- Fetches game version
    local GV = nil
    local Success, Err = pcall(function()
        GV = GVStore:GetAsync(GV_KEY)
    end)

    if Success then
        if GV then
            Version.LastUpdate.Value = GV[1]
            for i, str in pairs({"Major", "Minor", "Patch"}) do
                Version.Notation[str].Value = string.split(GV[2], ":")[i]
            end
        else
            GV = {os.clock(), "1:0:0"}
            GVStore:SetAsync(GV_KEY, GV)
        end
    else
        warn(Err)
    end

    -- Server region
    local RSuccess, RErr = pcall(function()
        fetchLocation()
    end)

    -- On render step
    RunService.PreSimulation:Connect(function(dt)
        ServerStats.ServerAge.Value = os.clock() - SERVER_START

        -- Server version
        if os.clock() >= NextCheck then
            NextCheck = os.clock() + 60
            local PresentGV = GVStore:GetAsync(GV_KEY)
            Version.upToDate.Value = PresentGV[1] <= Version.LastUpdate.Value
        end

        -- Location if unsuccessful
        if not RSuccess and os.clock() >= NextLocate then
            NextLocate = os.clock() + 5
            RSuccess, RErr = pcall(function()
                fetchLocation()
            end)
        end
    end)
end

return MetaService