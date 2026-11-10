local ResultsGui     = {}

-- Services
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local ScoreService   = _G.Knit.GetService("ScoreService")

-- Players
local Player         = Players.LocalPlayer
local Character      = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Sounds         = PlayerGui.Sounds
local Camera         = game.Workspace.CurrentCamera

local MissionOver    = TheGui.MissionOver
local Winner         = TheGui.Winner
local HowTheyWon     = TheGui.HowTheyWon

local Leaderboard    = TheGui.Leaderboard
local LBList         = Leaderboard.Leaderboard
local Stats          = Leaderboard.Stats 

local ResultsScreen  = require(RepStorage.Remotes.ResultsScreen):Client()
local CommsGui       = require(PlayerGui.Libraries.Gui.CommsGui)
local _effects       = require(PlayerGui.Libraries.Gui._EFFECTS)

local GameValues     = RepStorage.GameValues

-- Vars and consts
local GAMEPLAY_GUIS  = {
    "InventoryGui",
    "StaminaBar",
    "HealthEffects",
    "EffectGui",
    "GunStats",
    "DetectionGui",
    "NVGui",
    "RiotShieldStats",
    "ProxPromptGui",
    "NodeAnnouncement",
    "GrainEffect",
    "DownedGui",
    "ProxyGrabGui",
    "MobileButtons",
}

local ResultsShowing = false
local PrevEnabled    = {}
local GuiConns       = {}

local WINNER_INFO    = {
    Squadmates       = {
        WinnerMSG    = "SQUADMATES WIN",
        HowMSG       = "All threats eliminated",
        Color        = Color3.fromRGB(0, 0, 255),
    },
    Subjects         = {
        WinnerMSG    = "SUBJECTS WIN",
        HowMSG       = "Squadmates wiped out",
        Color        = Color3.fromRGB(255, 0, 0),
    },
}

local PLACE_COLORS   = {
    Color3.fromRGB(255, 215, 0), -- 1st
    Color3.fromRGB(192, 192, 192), -- 2nd
    Color3.fromRGB(205, 127, 50), -- 3rd
}

local ENTITY_NAME_MAP = {
    Proxy = "PNDR-4075",
    Tethered = "PNDR-0770",
}

-- [[ funcs ]] --

-- Hides all gameplay UIs and keeps them hidden while results are showing
local function hideGameplayUIs()
    for _, name in GAMEPLAY_GUIS do
        local Gui = PlayerGui:FindFirstChild(name)
        if Gui and Gui:IsA("ScreenGui") then
            PrevEnabled[Gui] = Gui.Enabled
            Gui.Enabled = false

            table.insert(GuiConns, Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if ResultsShowing and Gui.Enabled then
                    Gui.Enabled = false
                end
            end))
        end
    end
end

-- Restores gameplay UIs once the character is reloaded
local function restoreGameplayUIs()
    for _, conn : RBXScriptConnection in GuiConns do
        conn:Disconnect()
    end
    table.clear(GuiConns)

    for Gui : ScreenGui, wasEnabled : boolean in PrevEnabled do
        -- NVGui stays off: night vision is force-disabled for results
        Gui.Enabled = wasEnabled and Gui.Name ~= "NVGui"
    end
    table.clear(PrevEnabled)
end

-- Tweens the camera over to the results POV
local function tweenCameraToPOV()
    local Playspace = game.Workspace:FindFirstChild("Playspace")
    local POV = Playspace and Playspace:FindFirstChild("ResultsPOV")
    if not POV then
        warn("ResultsGui: Workspace.Playspace.ResultsPOV not found")
        return
    end

    Camera.CameraType = Enum.CameraType.Scriptable
    TweenService:Create(Camera, TweenInfo.new(1), {CFrame = POV:GetPivot(), FieldOfView = POV:GetAttribute("FieldOfView") or 70}):Play()
end

-- Main function
function ResultsGui.Function()
    ResultsScreen:On(function(winner : string, how : string)
        if Player.Team == game.Teams.Spectators then return end
        local WinnerInfo = WINNER_INFO[winner]
        Sounds.GameEvents.LastNode:Stop()

        ResultsShowing = true
        Player:SetAttribute("ResultsActive", true)
        hideGameplayUIs()
        CommsGui.clearSubtitles()

        Sounds.GameEvents.GlobalAnn:Play()
        TweenService:Create(MissionOver, TweenInfo.new(1), {TextTransparency = 0, TextStrokeTransparency = 1/2}):Play()
        task.wait(1)

        local ResultsCC = Instance.new("ColorCorrectionEffect")
        ResultsCC.Name = "ResultsCC"
        ResultsCC.Parent = Lighting

        TweenService:Create(MissionOver, TweenInfo.new(1), {Size = UDim2.fromScale(0.345 / 2, 0.062 / 2), Position = UDim2.fromScale(0.5, 0.05)}):Play()
        TweenService:Create(ResultsCC, TweenInfo.new(1), {Brightness = -0.7, Contrast = -2, TintColor = WinnerInfo.Color}):Play()

        tweenCameraToPOV()
        task.wait(1)

        Winner.Text = WinnerInfo.WinnerMSG or winner
        HowTheyWon.Text = WinnerInfo.HowMSG or how

        local TimeElapsed = GameValues.Numbers.TimeLeft:GetAttribute("TimeElapsed")

        Stats.TimeElapsed.Value.Text = string.format("%2i:%2i<font size = '10'>.%2i</font>", math.floor(TimeElapsed / 60), TimeElapsed % 60, (TimeElapsed * 100) % 100)
        Stats.NodesCompleted.Value.Text = string.format("%i<font size = '10'>/%i</font>", GameValues.Numbers.NodesLeft:GetAttribute("Init") - GameValues.Numbers.NodesLeft.Value, GameValues.Numbers.NodesLeft:GetAttribute("Init"))

        for _, part in {Winner, HowTheyWon, MissionOver, Leaderboard} do
            part.Visible = true
            _effects:CreateBuffer(part, 1)
        end

        Sounds.Results[winner]:Play()
        Sounds.Death.TurnOn:Play()

        -- Leaderboard
        ScoreService:CompileLeaderboard():andThen(function(data)
            for i, profile in ipairs(data) do
                print(profile)

                local Template = LBList.UIListLayout.Template:Clone()
                Template:WaitForChild("Place").Text = string.format("#%i", i)
                Template.Place.TextColor3 = PLACE_COLORS[i] or Color3.fromRGB(67, 81, 147)
                Template.UIStroke.Color = Template.Place.TextColor3

                Template.PlayerName.Text = ENTITY_NAME_MAP[profile.Username] or profile.Username
                Template.PlayerName.TextColor3 = WINNER_INFO[profile.Team].Color:Lerp(Color3.fromHSV(1, 0, 1), 1/2)

                if profile.Status == "DEAD" then
                    Template.PlayerName.TextColor3 = Template.PlayerName.TextColor3:Lerp(Color3.fromRGB(61, 46, 46), 1/2)
                    Template.Place.TextColor3 = Template.PlayerName.TextColor3
                    Template.Score.TextColor3 = Template.PlayerName.TextColor3
                    Template.PlayerName.Text = Template.PlayerName.Text..string.format(" <font color = 'rgb(255, 255, 255)'><font size = '8'>%s</font></font>", profile.Team == "Squadmates" and "DEAD" or "NEUTRALIZED")
                    Template.UIStroke.Transparency = 1
                end

                Template.Score.Text = not ENTITY_NAME_MAP[profile.Username] and tostring(profile.Score).." pts." or ""
                Template.Parent = LBList
            end
        end):catch(warn)

        task.wait(10)

        for _, part in {Winner, HowTheyWon, MissionOver, Leaderboard} do
            task.spawn(function()
                _effects:CreateBuffer(part, 1)
                task.wait(1/4.5)
                part.Visible = false
            end)
        end

        task.wait(2)
        TweenService:Create(ResultsCC, TweenInfo.new(5), {Brightness = -1}):Play()
        task.wait(5)
    end)

    -- Restores movement, UIs and the camera once the character is reloaded
    Player.CharacterAdded:Connect(function(char : Model)
        if not ResultsShowing then return end
        ResultsShowing = false
        Player:SetAttribute("ResultsActive", false)
        restoreGameplayUIs()

        Camera.CameraType = Enum.CameraType.Custom
        local Humanoid = char:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Camera.CameraSubject = Humanoid
        end
    end)
end

return ResultsGui