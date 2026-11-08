local InitiationGui  = {}

-- Services
local Lighting       = game:GetService("Lighting")
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local VoteService    = _G.Knit.GetService("VoteService")

-- Players
local Player         = Players.LocalPlayer
local Character      = Player.Character or Player.CharacterAdded:Wait()
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Sounds         = PlayerGui.Sounds
local InitiationSFX  = Sounds.Initiation

local FadeStatic     = TheGui.FadeStatic
local MainFrame      = TheGui.MainFrame
local Stats          = TheGui.Stats

local TeamName       = MainFrame.TeamName
local Timer          = MainFrame.Timer
local VotePrompt     = MainFrame.VotePrompt
local YouAre         = MainFrame.YouAre

local _static        = TheGui._static
local Objective      = TheGui.Objective

local Camera         = game.Workspace.CurrentCamera

local Nodes          = RepStorage.VFX.Initiation

local VoteRequest    = require(RepStorage.Remotes.VoteRequest):Client()
local LerpByFrame    = require(RepStorage.Modules.Util.Math.LerpByFrame)
local MouseTracking  = require(PlayerGui.Libraries.Misc._mousetracking)
local _effects       = require(PlayerGui.Libraries.Gui._EFFECTS)

local ChatSounds     = Sounds:FindFirstChild("Chat")
local ChatInteract   = ChatSounds and ChatSounds:FindFirstChild("ChatInteraction")
local TextScroll     = ChatInteract and ChatInteract:FindFirstChild("TextScroll")

-- Vars and consts
local LTRS_PER_SEC   = 75

local ROLE_COLORS    = {
    Squadmates       = Color3.fromRGB(94, 110, 255),
    Subjects         = Color3.fromRGB(255, 100, 100),
}

local OBJECTIVES     = {
    Squadmates       = "COMMENCE DECONTAMINATION",
    Subjects         = "ELIMINATE ALL SQUADMATES",
}

local Active         = false

-- [[ funcs ]] --

-- Types text out letter by letter
local function typewrite(label : GuiLabel, text : string) : ()
    local TS = nil
    if TextScroll then
        TS = TextScroll:Clone()
        TS.Parent = TextScroll.Parent
        TS.Volume = 1
    end

    if string.find(text, "font") then
        local Redacted = string.sub(text, 1, string.find(text, "</font>") + #"</font>")
        for i = 1, #"[REDACTED]" do
            label.Text = string.format("<font color = 'rgb(255, 100, 100)'><b>%s</b></font>", string.sub("[REDACTED]", 1, i))
            task.wait(1 / LTRS_PER_SEC)
        end

        for i = #Redacted, #text do
            label.Text = label.Text..string.sub(text, i, i)
            task.wait(1 / LTRS_PER_SEC)
        end
    else
        for i = 1, #text do
            label.Text = label.Text..string.sub(text, i, i)
            task.wait(1 / LTRS_PER_SEC)
        end
    end

    if TS then
        TS:Destroy()
    end
end

-- Main voting sequence; runs once per vote
local function runInitiation(voteName : string, voteInfo : {}) : ()
    Active = true
    VoteService:BeginInitiation():catch(warn)

    local PlayerTeamName = Player.Team.Name
    local TeamColor = ROLE_COLORS[PlayerTeamName] or Color3.fromHSV(0, 0, 1)

    if not Player.Character then
        Player.CharacterAdded:Wait()
    end

    local Map = game.Workspace:WaitForChild("Playspace")
    local CharSpawns = Map.Spawns.Characters:FindFirstChild(PlayerTeamName)
    if not CharSpawns then
        warn(`InitiationGui: no spawn folder found for team {PlayerTeamName}`)
    end

    -- Color correction
    local InitiationCC = Lighting:FindFirstChild("InitiationCC")
    if not InitiationCC then
        InitiationCC = Instance.new("ColorCorrectionEffect")
        InitiationCC.Name = "InitiationCC"
        InitiationCC.Parent = Lighting
    end
    InitiationCC.Saturation = 0
    InitiationCC.TintColor = TeamColor:Lerp(Color3.fromHSV(0, 0, 1), 1/2)
    InitiationCC.Brightness = -2
    InitiationCC.Contrast = 1

    -- Team-colored glow
    local InitiationBloom = Lighting:FindFirstChild("InitiationBloom")
    if not InitiationBloom then
        InitiationBloom = Instance.new("BloomEffect")
        InitiationBloom.Name = "InitiationBloom"
        InitiationBloom.Parent = Lighting
    end
    InitiationBloom.Intensity = 0.75
    InitiationBloom.Size = 24
    InitiationBloom.Threshold = 0.95

    -- Resets visuals in case of a re-run
    TheGui.Enabled = true
    MainFrame.Visible = false
    for _, label : GuiObject in {YouAre, TeamName, VotePrompt, Timer} do
        label.Visible = true
    end
    for _, label : GuiObject in Stats:GetChildren() do
        if label:IsA("GuiLabel") then
            label.Text = ""
            label.TextTransparency = 0
            label.TextStrokeTransparency = 1/2
        end
    end

    InitiationSFX.Hiss:Play()

    -- Map camera from the initiation POV, with mouse pan
    local POV = Map:WaitForChild("InitPOV")
    local CF = POV:GetPivot()
    local FOV = POV:GetAttribute("FieldOfView") or 90
    local CFPan = CFrame.Angles(0, 0, 0)

    Camera.CameraType = Enum.CameraType.Scriptable
    local CameraStep = nil
    CameraStep = RunService.RenderStepped:Connect(function(dt)
        local PosX, PosY = MouseTracking.getPositionScale()
        CFPan = CFPan:Lerp(CFrame.Angles(-math.rad(PosY * 5), -math.rad(PosX * 5), 0), LerpByFrame(0.05, dt))
        Camera.CFrame = CF * CFPan
        Camera.FieldOfView = FOV
        _static.ImageColor3 = Color3.fromHSV((Player.Team == game.Teams.Squadmates and 2 or 0) / 3, 2/5, 1)
    end)

    -- Stats
    local MapInfo = require(Map:WaitForChild("MapInfo"))
    local Now = os.date("*t")

    local LastDayDigit = string.sub(tostring(Now.day), -1)
    local DaySuffix = "th"
    if not (Now.day > 3 and Now.day < 21) and LastDayDigit ~= "0" and tonumber(LastDayDigit) <= 3 then
        DaySuffix = ({"st", "nd", "rd"})[tonumber(LastDayDigit)]
    end

    local DateText = string.upper(string.format("%s %i%s, 1999", os.date("%B"), Now.day, DaySuffix))
    local TimeText = string.format("%.2i:%s", MapInfo.Environment.Hour, os.date("%M"))
    local LocationText = string.format("<font color = 'rgb(255, 100, 100)'><b>[REDACTED]</b></font>, %s, U.S.A.", string.upper(MapInfo.Settings.State))

    local StatOrder = {
        {Stats:FindFirstChild("Date"), DateText},
        {Stats:FindFirstChild("Time"), TimeText},
        {Stats:FindFirstChild("Location"), LocationText},
    }

    task.wait(2)

    for _, info in ipairs(StatOrder) do
        if info[1] then
            typewrite(info[1], info[2])
            task.wait(1)
        end
    end

    for _, info in pairs(StatOrder) do
        if info[1] then
            TweenService:Create(info[1], TweenInfo.new(3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
    end

    TweenService:Create(InitiationCC, TweenInfo.new(3), {Brightness = 0.5}):Play()
    task.wait(3)

    -- Nodes
    local NodeFolder = Instance.new("Folder")
    NodeFolder.Name = "Nodes"
    NodeFolder.Parent = PlayerGui

    local VotingNodes = Instance.new("Folder")
    VotingNodes.Name = "VotingNodes"
    VotingNodes.Parent = NodeFolder

    local MapNodes = Instance.new("Folder")
    MapNodes.Name = "MapNodes"
    MapNodes.Parent = NodeFolder

    -- Voting nodes
    local SpawnChoice = nil
    if CharSpawns then
        for _, sp in CharSpawns:GetChildren() do
            local NewNode = Nodes.SpawnNode:Clone()
            NewNode.Parent = VotingNodes
            NewNode.Name = sp.Name
            NewNode.Adornee = sp

            NewNode.LocationName.Text = string.upper(sp.Name)
            _effects:CreateBuffer(NewNode.LocationName, 3)

            NewNode.Button.ImageButton.MouseButton1Click:Connect(function()
                SpawnChoice = NewNode
                InitiationSFX.Vote:Play()
                VoteRequest:Fire(voteName, sp.Name)
            end)
        end
    end

    -- Map node markers: regular nodes in red, checkpoints in blue
    local Interactables = Map:FindFirstChild("Interactables")
    local InteractNodes = Interactables and Interactables:FindFirstChild("Nodes")
    if InteractNodes and Nodes:FindFirstChild("NodeMarker") then
        for _, node in InteractNodes:GetChildren() do
            local Marker = Nodes.NodeMarker:Clone()
            Marker.Parent = MapNodes
            Marker.Name = node.Name
            Marker.Adornee = node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)

            if Marker:FindFirstChild("LocationName") then
                Marker.LocationName.Text = string.upper(node.Name)
                Marker.LocationName.TextColor3 = string.find(node.Name, "Checkpoint") and Color3.fromRGB(94, 110, 255) or Color3.fromRGB(255, 100, 100)
            end
        end
    end

    -- Prompt
    YouAre.Text = "YOU ARE A"
    TeamName.Text = PlayerTeamName == "Squadmates" and "SQUADMATE" or "SUBJECT"
    TeamName.TextColor3 = TeamColor
    VotePrompt.Text = "VOTE FOR A DISPATCH LOCATION"

    MainFrame.Visible = true
    for _, label : GuiObject in {YouAre, TeamName, VotePrompt, Timer} do
        _effects:CreateBuffer(label, 3)
    end

    InitiationSFX.TurnOn:Play()

    -- Vote state
    local LatestInfo = voteInfo
    local WinnerName = nil

    local UpdateConn = VoteService.VoteUpdated:Connect(function(vote : string, info : {})
        if vote ~= voteName then return end
        LatestInfo = info

        Sounds.VoteBeep.PlaybackSpeed = Rand:NextNumber(0.95, 1.05)
        Sounds.VoteBeep:Play()
    end)

    local EndConn = VoteService.VoteEnded:Connect(function(vote : string, winner : any)
        if vote == voteName then
            WinnerName = winner
        end
    end)

    -- Manages voter pips and the timer
    local TimerConn = nil
    TimerConn = RunService.RenderStepped:Connect(function()
        for _, vote in VotingNodes:GetChildren() do
            vote.Button.ImageButton._static.Visible = vote == SpawnChoice

            local Voters = LatestInfo.Choices[vote.Name]
            local VoteCount = Voters and #Voters or 0

            if #vote.Voters:GetChildren() - 1 ~= VoteCount then
                for _, v in vote.Voters:GetChildren() do
                    if v:IsA("Frame") then
                        v:Destroy()
                    end
                end

                for _ = 1, VoteCount do
                    vote.Voters.UIGridLayout.Frame:Clone().Parent = vote.Voters
                end
            end
        end

        -- Timer
        local TimeLeft = math.max((LatestInfo.EndTime or 0) - workspace:GetServerTimeNow(), 0)
        Timer.Text = string.format("%.2i<font size = '10'>.%.2i</font>", math.floor(TimeLeft), math.floor((TimeLeft % 1) * 100))
    end)

    repeat task.wait() until WinnerName

    TimerConn:Disconnect()
    UpdateConn:Disconnect()
    EndConn:Disconnect()

    -- After voting
    for _, label : GuiObject in {YouAre, TeamName, VotePrompt, Timer} do
        label.Visible = false
    end
    MapNodes:Destroy()
    Sounds.GameEvents.GlobalAnn:Play()

    -- Blinks the winning node
    local PostVoteStep = nil
    PostVoteStep = RunService.RenderStepped:Connect(function()
        for _, vote in VotingNodes:GetChildren() do
            vote.Enabled = vote.Name == WinnerName and math.ceil(tick() * 16) % 2 == 0
        end
    end)

    local FadeImg = FadeStatic:FindFirstChild("_static") or FadeStatic
    FadeStatic.Visible = true
    FadeImg.ImageColor3 = TeamColor

    TweenService:Create(Sounds.FadeStatic, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = 3/4}):Play()
    TweenService:Create(FadeImg, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()

    task.wait(5)

    PostVoteStep:Disconnect()
    CameraStep:Disconnect()
    NodeFolder:Destroy()

    InitiationSFX.TurnOn:Play()

    for _, part in TheGui:GetChildren() do
        if part:IsA("GuiObject") then
            part.Visible = part == Objective
        end
    end

    _effects:CreateBuffer(Objective, 3)

    Sounds.FadeStatic:Stop()
    InitiationSFX.Hiss:Stop()
    InitiationSFX.FinalInit.Volume = 0.5
    InitiationSFX.FinalInit:Play()
    Objective.Text = OBJECTIVES[PlayerTeamName] or ""
    Objective.TextTransparency = 0
    Objective.TextStrokeTransparency = 1/2
    InitiationCC:Destroy()
    InitiationBloom:Destroy()

    task.wait(7)

    TweenService:Create(InitiationSFX.FinalInit, TweenInfo.new(7), {Volume = 0}):Play()
    TweenService:Create(Objective, TweenInfo.new(7), {TextTransparency = 1, TextStrokeTransparency = 1, TextColor3 = Color3.fromHSV(2/3, 1, 1)}):Play()

    task.wait(7)

    InitiationSFX.FinalInit:Stop()
    TheGui.Enabled = false
    VoteService:FinishInitiation():catch(warn)
    Active = false
end

-- Main function
function InitiationGui.Function()
    -- Starts the sequence if a vote for our team is currently running
    local function checkForVote() : ()
        if Active or Player.Team == game.Teams.Spectators then return end

        local VoteName = Player.Team.Name.."Spawn"
        VoteService:GetVoteInfo(VoteName):andThen(function(info)
            if info and not Active then
                task.spawn(runInitiation, VoteName, info)
            end
        end):catch(warn)
    end

    -- Vote starts while we are spawned
    VoteService.VoteStarted:Connect(function(voteName : string, info : {})
        if not Active and Player.Team ~= game.Teams.Spectators and voteName == Player.Team.Name.."Spawn" then
            task.spawn(runInitiation, voteName, info)
        end
    end)

    -- Respawning during an active vote
    Player.CharacterAdded:Connect(checkForVote)

    checkForVote()
end

return InitiationGui
