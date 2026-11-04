local ResultsGui     = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

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

local LBTemplate     = LBList.UIGridLayout.Frame

local ResultsScreen  = require(RepStorage.Remotes.ResultsScreen):Client()
local CommsGui       = require(PlayerGui.Libraries.Gui.CommsGui)
local _effects       = require(PlayerGui.Libraries.Gui._EFFECTS)

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
        HowMSG       = "All P.N.D.R. Subjects neutralized",
        Color        = Color3.fromRGB(0, 0, 255),
    },
    Subjects         = {
        WinnerMSG    = "SUBJECTS WIN",
        HowMSG       = "Squadmates wiped out",
        Color        = Color3.fromRGB(255, 0, 0),
    },
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

        ResultsShowing = true
        Player:SetAttribute("ResultsActive", true)
        hideGameplayUIs()
        CommsGui.clearSubtitles()

        Sounds.GameEvents.GlobalAnn:Play()
        TweenService:Create(MissionOver, TweenInfo.new(1), {TextTransparency = 0, TextStrokeTransparency = 1/2}):Play()
        task.wait(1)
        TweenService:Create(MissionOver, TweenInfo.new(1), {Size = UDim2.fromScale(0.345 / 2, 0.062 / 2), Position = UDim2.fromScale(0.5, 0.05)}):Play()
        tweenCameraToPOV()
        task.wait(1)

        for _, part in {Winner, HowTheyWon, MissionOver, Leaderboard} do
            part.Visible = true
            _effects:CreateBuffer(part, 1)
        end
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