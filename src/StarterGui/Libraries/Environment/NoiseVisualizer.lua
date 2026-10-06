local NOISEVis       = {}

-- Services
local Debris 		 = game:GetService("Debris")
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local DataController = _G.Knit.GetController("DataController")

-- Player stuff
local Player 		 = Players.LocalPlayer
local Character 	 = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local NOISEInds		 = RepStorage.PlayerRep.NoiseVisualizers

local ThisGround	 = nil
local SGUI           : SurfaceGui = nil

-- Vars and consts
local InitInds		 = {}
local NextNOISEInd	 = os.clock()

local doNoiseVis     = false

-- Main function
function NOISEVis.Function()
    DataController:AwaitLoaded()
    doNoiseVis = DataController:Get("Client.doNoiseVal")

    if Player.Team == game.Teams.Squadmates then
        ThisGround = game.Workspace:FindFirstChild(NOISEInds.IndGround.Name)

        if ThisGround then
            ThisGround:Destroy()
        end

        ThisGround = NOISEInds.IndGround:Clone()
        ThisGround.Parent = game.Workspace
        SGUI = ThisGround.SurfaceGui

        table.insert(InitInds, ThisGround)

        -- Manages indicators
        local Event = RunService.PreRender:Connect(function(dt)
            local NOISE = Character:GetAttribute("Noise")
            if not NOISE or not doNoiseVis then return end

            local CurrentChar = Character
            if not (ThisGround and Character and Character.Parent) then return end
            
            ThisGround.Position = CurrentChar.PrimaryPart.Position + Vector3.new(0, -3.45, 0)

            -- NOISE indicator
            if os.clock() >= NextNOISEInd and NOISE > 3 then
                NextNOISEInd = os.clock() + 1/8

                local NewVis = SGUI.Frame.VisTemp:Clone()
                NewVis.Parent = SGUI.Frame
                NewVis.Position = UDim2.fromScale(1/2, 1/2)
                NewVis.Size = UDim2.fromScale(0, 0)
                NewVis.UIStroke.Transparency = 0

                local SizeProg = NOISE / ThisGround.Size.X

                TweenService:Create(NewVis, TweenInfo.new(1/2), {Size = UDim2.fromScale(SizeProg, SizeProg), Position = UDim2.fromScale(1/2, 1/2):Lerp(UDim2.fromScale(0, 0), SizeProg)}):Play()
                TweenService:Create(NewVis.UIStroke, TweenInfo.new(1/2), {Transparency = 1}):Play()
                Debris:AddItem(NewVis, 1/2)
            end
        end)

        -- Stops event
        Player.Changed:Connect(function()
            if Player.Team ~= game.Teams.Squadmates then
                Event:Disconnect()
            end
        end)
    end
end

return NOISEVis