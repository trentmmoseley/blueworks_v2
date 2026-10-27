-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local PlayerService   = Knit.CreateService({
    Name = "PlayerService",
    Client = {}
})

local RemFuncs        = RepStorage.RemFuncs

local NameParts       = require(RepStorage.Modules.Util.NameParts)

-- Vars and consts
local NextCheck       = os.clock()

-- [[ funcs ]] --

-- Secure remote function
function PlayerService:RemoteFunction(player : Player, func : string, default : any, dl : number, ...)
    local Deadline = os.clock() + dl
    local Value = RemFuncs:FindFirstChild(func):InvokeClient(player, ...)

    local RunConn = nil
    RunConn = RunService.PreSimulation:Connect(function()
        if os.clock() >= Deadline or Value then
            RunConn:Disconnect()
            RunConn = nil
        end
    end)

    repeat task.wait() until not RunConn
    return (Value and typeof(Value) == typeof(default)) and Value or default
end

-- On knit init
function PlayerService:KnitInit() : ()
    -- Performance eval
    RunService.PreSimulation:Connect(function(dt)
        if os.clock() >= NextCheck then
            NextCheck = os.clock() + 3
            for _, plr in pairs(Players:GetPlayers()) do
                task.spawn(function()
                    -- FPS
                    task.spawn(function()
                        local PlrFPS = self:RemoteFunction(plr, "getLocalVal", 60, 1, "FPS")
                        plr:SetAttribute("FPS", PlrFPS)
                    end)

                    -- Ping
                    local CheckStart = os.clock()

                    local Response = nil
                    local Success, Err = pcall(function()
                        Response = RemFuncs.getPingConfirm:InvokeClient(plr)
                        repeat RunService.PreSimulation:Wait() until Response
                    end)

                    if Success then
                        plr:SetAttribute("Ping", (os.clock() - CheckStart) * 1000)
                    else
                        warn(Err)
                    end
                end)
            end
        end
    end)

    Players.PlayerAdded:Connect(function(player : Player)
        local TheName = NameParts(player)
        print(TheName, "has joined!")
        
        player.CharacterAdded:Connect(function(char : Model)
            print(TheName.."'s character has loaded!")

            local Humanoid : Humanoid = char:FindFirstChildOfClass("Humanoid")
            Humanoid.Died:Connect(function()
                print(TheName, "has died.")
            end)

            warn("below is temporary")
            player:SetAttribute("inGame", true)
        end)
    end)
    
    Players.PlayerRemoving:Connect(function(player : Player)
        local TheName = NameParts(player)
        print(TheName, "has disconnected.")
    end)
end

return PlayerService