local PerfStats      = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)

local FPSLabel       = TheGui.Frame.FPS
local PingLabel      = TheGui.Frame.Ping
local Misc           = TheGui.Frame.Misc

local ServerStats    = RepStorage.ServerStats
local ServerVersion  = ServerStats.Version

local Lerp           = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress       = require(RepStorage.Modules.Util.Math.Progress)

-- Vars and consts
local CurrentFPS     = 0
local ClientInit     = os.clock()

local TotalFPS       = 0
local TotalFrames    = 0

local FPSHigh, FPSLow   = 0, 0
local PingHigh, PingLow = 0, math.huge

local CurrentPing    = 0
local TotalPing      = 0
local TotalPingFrames = 0

local MINUTE_LENGTH  = 60
local HOUR_LENGTH    = MINUTE_LENGTH ^ 2
local DAY_LENGTH     = HOUR_LENGTH * 24

local SERVER_AVG_INTERVAL = 5
local ServerAvgFPS   = 0
local ServerAvgPing  = 0
local LastServerAvg  = -SERVER_AVG_INTERVAL -- forces a refresh on first frame

-- [[ funcs ]] --

-- Returns color
local function getColor(prog : number)
    return Color3.fromHSV(prog <= 1 and prog * 0.4 or 1/2, math.clamp(1 - (1 - prog) * (1/3), 0, 1), 1)
end

-- Calculates avg. FPS of server
local function avgFPS()
    local T = 0
    for _, plr in pairs(Players:GetPlayers()) do
        T += plr:GetAttribute("FPS") or 0
    end

    return T / #Players:GetPlayers()
end

-- Calculates avg. ping of server
local function avgServerPing()
    local T = 0
    for _, plr in pairs(Players:GetPlayers()) do
        T += plr:GetAttribute("Ping") or 0
    end

    return T / #Players:GetPlayers()
end

-- Main function
function PerfStats.Function()
    warn("replace toggle with setting")

    RunService.PreRender:Connect(function(dt)
        TheGui.Enabled = true

        local FPS = math.clamp(1 / dt, 0, 1000)
        local QuarterLerp = LerpByFrame(1/4, dt)

        local ProgFPS = FPS / 60
        CurrentFPS = Lerp(CurrentFPS, FPS, QuarterLerp / 2)

        -- Records FPS
        TotalFPS += FPS
        TotalFrames += 1
        local AvgFPS = TotalFPS / TotalFrames

        if os.clock() >= ClientInit + 1 then
            FPSLabel.MoreStats.Visible = true
            FPSHigh = math.max(FPSHigh, CurrentFPS)
            FPSLow = math.min(FPSLow, CurrentFPS)
        end
        
        -- Records Ping
        local AvgPing = 0
        if Player:GetAttribute("Ping") then
            CurrentPing = Lerp(CurrentPing, Player:GetAttribute("Ping") or 0, QuarterLerp / 2)
            TotalPing += CurrentPing
            TotalPingFrames += 1
            AvgPing = TotalPing / TotalPingFrames

            if os.clock() >= ClientInit + 3 then
                PingLabel.MoreStats.Visible = true
                PingHigh = math.max(PingHigh, CurrentPing)
                PingLow = math.min(PingLow, CurrentPing)
            end
        end

        -- The UI
        if TheGui.Enabled then
            -- Refreshes server averages every few seconds
            if os.clock() >= LastServerAvg + SERVER_AVG_INTERVAL then
                ServerAvgFPS = avgFPS()
                ServerAvgPing = avgServerPing()
                LastServerAvg = os.clock()
            end

            -- Writes FPS
            FPSLabel.Text = string.format("<b>%i</b> <font size = '10'>FPS</font>", CurrentFPS)
            FPSLabel.Frame.BackgroundColor3 = FPSLabel.TextColor3
            FPSLabel.TextColor3 = getColor(ProgFPS)

            local FMSOrder = {

                {FPSLabel.MoreStats.High, "<font color = 'rgb(255, 255, 255)'>High:</font> %i", FPSHigh},
                {FPSLabel.MoreStats.Low, "<font color = 'rgb(255, 255, 255)'>Low:</font> %i", FPSLow},
                {FPSLabel.MoreStats.Average, "<font color = 'rgb(255, 255, 255)'>Client Avg.:</font> %i", AvgFPS},
                {FPSLabel.MoreStats.ServerAverage, "<font color = 'rgb(255, 255, 255)'>Server Avg.:</font> %i", ServerAvgFPS},

            }

            for _, info in pairs(FMSOrder) do
                local Label = info[1]
                local Txt = info[2]
                local F = info[3]

                Label.Text = string.format(Txt, F)
                Label.TextColor3 = getColor(math.max(F / 60, 0))
            end

            -- Writes Ping
            PingLabel.Text = string.format("<b>%i</b> <font size = '10'>MS</font>", CurrentPing)
            PingLabel.Frame.BackgroundColor3 = PingLabel.TextColor3
            local PingProgress = 0
            PingProgress = 1 - math.clamp(Progress(CurrentPing, 200, 50), 0, 1)
            PingLabel.TextColor3 = getColor(1 - PingProgress)

            local PMSOrder = {

                {PingLabel.MoreStats.High, "<font color = 'rgb(255, 255, 255)'>High:</font> %i", PingHigh},
                {PingLabel.MoreStats.Low, "<font color = 'rgb(255, 255, 255)'>Low:</font> %i", PingLow},
                {PingLabel.MoreStats.Average, "<font color = 'rgb(255, 255, 255)'>Client Avg.:</font> %i", AvgPing},
                {PingLabel.MoreStats.ServerAverage, "<font color = 'rgb(255, 255, 255)'>Server Avg.:</font> %i", ServerAvgPing},

            }

            for _, info in pairs(PMSOrder) do
                local Label = info[1]
                local Txt = info[2]
                local P = info[3]
                local Prog = Progress(P, 200, 0)

                Label.Text = string.format(Txt, P)
                Label.TextColor3 = getColor(math.clamp(Prog, 0, 1))
            end

            -- More stats
            Misc.Version.Text = string.format("v%i.%i%sa", ServerVersion.Notation.Major.Value, ServerVersion.Notation.Minor.Value, ServerVersion.Notation.Patch.Value > 0 and "."..ServerVersion.Notation.Patch.Value or "")
            Misc.Version.TextLabel.Text = string.format("Server %s", ServerVersion.upToDate.Value and "Version" or "Out of Date")
            Misc.Version.TextLabel.TextColor3 = Color3.fromHSV(1, ServerVersion.upToDate.Value and 0 or 1/2, 1)

            local ServerAge = ServerStats.ServerAge.Value
            Misc.Age.Text = string.format("%s%s%s%s<font size = '10'>.%.2i</font>", ServerAge >= DAY_LENGTH and `{math.floor(ServerAge / DAY_LENGTH)}:` or "", ServerAge >= HOUR_LENGTH and (ServerAge < DAY_LENGTH and `{math.floor(ServerAge / HOUR_LENGTH) % 24}:` or string.format("%.2i:", math.floor(ServerAge / HOUR_LENGTH) % 24)) or "", ServerAge >= MINUTE_LENGTH and (ServerAge < HOUR_LENGTH and `{math.floor(ServerAge / MINUTE_LENGTH) % 60}:` or string.format("%.2i:", math.floor(ServerAge / MINUTE_LENGTH) % 60)) or "", ServerAge < 60 and math.floor(ServerAge) % 60 or string.format("%.2i", math.floor(ServerAge) % 60), (ServerAge % 1) * 100)
    
            Misc.Region.Text = `{ServerStats.Location.Region.Value}, {ServerStats.Location.Country.Value}`
            Misc.PlrCount.Text = string.format("%i<font size = '10'><font color = 'rgb(255, 255, 255)'>/%i</font></font>", #Players:GetPlayers(), 17)
        end
    end)
end

return PerfStats