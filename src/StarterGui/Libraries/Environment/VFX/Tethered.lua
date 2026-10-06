-- Services
local Debris          = game:GetService("Debris")
local Players         = game:GetService("Players")
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")

-- Player
local Player          = Players.LocalPlayer
local PlayerGui       = Player.PlayerGui
local Sounds          = PlayerGui:WaitForChild("Sounds")

local TetheredFlashes = PlayerGui:WaitForChild("TetheredFlashes")
local TetheredSounds  = Sounds.Characters.Tethered

-- Modules and objects
local Camera          = game.Workspace.CurrentCamera

local Objects         = RepStorage.VFX.Tethered
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame     = require(RepStorage.Modules.Util.Math.LerpByFrame)
local PlaySound       = require(RepStorage.Modules.Util.PlaySound)

-- Vars and consts
local COLORS          = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(0, 255, 255), Color3.fromRGB(100, 0, 255), Color3.fromRGB(255, 0, 255)}
local discreteRunning = false

-- [[ funcs ]] --

-- Laugh sound
local function laughSound(pos : Vector3)
    task.spawn(function()
        local Folder = TetheredSounds.Laugh:GetChildren()
        local ChosenSound = Folder[math.random(1, #Folder)]

        local NewPart = Instance.new("Part")
        NewPart.Size = Vector3.one
        NewPart.Transparency = 1
        NewPart.Anchored = true
        NewPart.CanCollide = false
        NewPart.CanQuery = false
        NewPart.CanTouch = false
        NewPart.AudioCanCollide = false
        NewPart.Parent = game.Workspace
        NewPart.Position = pos
        
        local NewSound = ChosenSound:Clone()
        NewSound.Parent = NewPart
        NewSound.PlaybackSpeed *= Rand:NextNumber(0.95, 1.05)
        NewSound:Play()

        if NewSound:GetAttribute("_starttime") then
            NewSound.TimePosition = NewSound:GetAttribute("_starttime")
        end

        NewSound.Ended:Connect(function()
            NewPart:Destroy()
        end)
    end)
end

-- Tone sound
local function toneSound()
    local Folder = TetheredSounds.Tones:GetChildren()
    local ChosenSound = Folder[math.random(1, #Folder)]
    ChosenSound.PlaybackSpeed = Rand:NextNumber(0.95, 1.05)
    ChosenSound:Play()
end

local Tethered       = {

    ["Flash1"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local Message = args[1]
            local Position = args[2]

            -- UI
            task.spawn(function()
                local ChosenBG = COLORS[math.random(1, #COLORS)]
                local H, S, V = ChosenBG:ToHSV()
                TetheredFlashes.Flash1.BackgroundColor3 = ChosenBG
                TetheredFlashes.Flash1.TextLabel.TextColor3 = Color3.fromHSV(1, 0, 1 - V)
                TetheredFlashes.Flash1.TextLabel.Text = string.upper(Message)
                TetheredFlashes.Flash1.TextLabel.TextSize = Rand:NextNumber(10, 100)
                TetheredFlashes.Flash1.Visible = true
                task.wait(Rand:NextNumber(1/20, 1/8))
                game.Workspace.CurrentCamera.FieldOfView += Rand:NextNumber(-50, 50)
                TetheredFlashes.Flash1.Visible = false

                local CC = Instance.new("ColorCorrectionEffect")
                CC.Saturation = -2
                CC.Parent = game.Lighting
                game:GetService("Debris"):AddItem(CC, 1/15)
            end)

            -- Sounds
            local doLaugh = math.random(0, 1) == 1
            local doTone = math.random(0, 1) == 1

            if doLaugh then
                laughSound(Position)
            end

            if doTone then
                toneSound()
            end
        end,

    },

    ["Discrete"]        = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            if not discreteRunning then
                discreteRunning = true

                local Message = args[1]
                local Position = args[2]

                -- Sounds
                local doLaugh = math.random(0, 5) == 0
                local doTone = math.random(0, 5) == 0

                if doLaugh then
                    laughSound(Position)
                end

                if doTone then
                    toneSound()
                end

                TetheredFlashes.Discrete.Text = Message
                TetheredFlashes.Discrete.Position = UDim2.fromScale(Rand:NextNumber(0, 1 - TetheredFlashes.Discrete.Size.X.Scale), Rand:NextNumber(0, 1 - TetheredFlashes.Discrete.Size.Y.Scale))
                TetheredFlashes.Discrete.Visible = true
                task.wait(2)
                TetheredFlashes.Discrete.Visible = false

                discreteRunning = false
            end
        end,

    },

    ["Phase"]     = {

        ["RENDER_DISTANCE"] = 1000,
        ["Function"]        = function(args)
            local Char = args[1]
            local CF = args[2]

            local PsyRig = Objects.PsyRig
            PsyRig = PsyRig:Clone()
            PsyRig.Parent = game.Workspace

            -- Glitch
            local Glitch = Objects._psychophase
			Glitch = Glitch:Clone()
			Glitch.Parent = Char.PrimaryPart
            Glitch:Emit()
            Debris:AddItem(Glitch, 2)

            -- Positions parts
            for _, part in pairs(PsyRig:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CFrame = Char[part.Name].CFrame
                end
            end

            for _, par in pairs({PsyRig, Char}) do
                task.spawn(function()
                    PlaySound(250945230, "Psychophase1", par.Torso, nil, 1, Rand:NextNumber(0.9, 1.1))
                    PlaySound(9810776841, "Psychophase2", par.Torso, nil, 1, Rand:NextNumber(0.9, 1.1))
                    task.wait(Rand:NextNumber(0.25, 0.375))
                    par.Torso:WaitForChild("Psychophase1"):Stop()
                    TweenService:Create(par.Torso.Psychophase2, TweenInfo.new(1), {Volume = 0}):Play()
                end)
			end

            PsyRig:PivotTo(CF)

            task.wait(20)

            for _, part in pairs(PsyRig:GetDescendants()) do
                if part:IsA("BasePart") then
                    TweenService:Create(part, TweenInfo.new(20), {Transparency = 1, Color = Color3.fromHSV(2/3, 1, 1)}):Play()
                end
            end
            
            Debris:AddItem(PsyRig, 20)
        end

    },

    ["Surprise"]            = {

        ["RENDER_DISTANCE"]        = 1000,
        ["Function"]        = function(args)
            local Char = args[1]
            local Message = args[2]

            local CC = Objects.Surprise:Clone()
            CC.Parent = game.Lighting
            CC.Enabled = true

            local MessageParts = string.split(Message, " ")
            local StartPosition = UDim2.fromScale(Rand:NextNumber(0, 1) / 4, Rand:NextNumber(0, 1) / 2)

            local Letters : {TextLabel} = {}

            for i, word in MessageParts do
                for j = 1, #word do
                    local Letter = TetheredFlashes.SurpriseLetter:Clone()
                    Letter.Text = string.sub(word, j, j)
                    Letter.Position = StartPosition + UDim2.fromScale(j * Letter.Size.X.Scale * 1.05 + (i - 1) * 0.1, i * Letter.Size.Y.Scale)
                    Letter.Size += UDim2.fromScale(Rand:NextNumber(-1, 1) / 100, Rand:NextNumber(-1, 1) / 100)
                    Letter.Parent = TetheredFlashes
                    Letter.Visible = true

                    table.insert(Letters, Letter)
                end
            end

            local RunConn : RBXScriptSignal = nil
            RunConn = RunService.PreRender:Connect(function(dt)
                local QuarterLerp = LerpByFrame(1/4, dt)
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, Char.Head.CFrame.Position), QuarterLerp / 1.5)
                Camera.FieldOfView = Lerp(Camera.FieldOfView, 1, QuarterLerp / 2)
                Camera.CFrame *= CFrame.Angles(math.rad(Rand:NextNumber(-1, 1)), math.rad(Rand:NextNumber(-1, 1)), math.rad(Rand:NextNumber(-1, 1)))

                for _, letter in Letters do
                    letter.Rotation += Rand:NextNumber(-1, 1)
                    letter.Position += UDim2.fromScale(Rand:NextNumber(-0.5, 1) / 500, Rand:NextNumber(-0.5, 1) / 500)
                    letter.Size += UDim2.fromScale(Rand:NextNumber(-1, 1) / 250, Rand:NextNumber(-1, 1) / 250)
                end
            end)

            task.wait(1/2)

            RunConn:Disconnect()
            CC:Destroy()
            for _, letter in Letters do
                task.spawn(function()
                    TweenService:Create(letter, TweenInfo.new(1), {TextTransparency = 1, TextColor3 = Color3.fromHSV(2/3, 1, 1)}):Play()
                    TweenService:Create(letter.UIStroke, TweenInfo.new(1), {Transparency = 1}):Play()
                    Debris:AddItem(letter, 1)
                end)
            end
        end,

    }

}

return Tethered