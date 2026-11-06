local CommsGui       = {}

-- Services
local Debris         = game:GetService("Debris")
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local CommsService   = _G.Knit.GetService("CommsService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local ChatSounds     = PlayerGui.Sounds.Chat

local Feed           = TheGui:WaitForChild("Feed")
local Subtitles      = TheGui:WaitForChild("Subtitles")

-- Vars and consts
local SubCounter     = 0
local MAX_SUBS       = 6
local SUB_LIFETIME   = 7

local LTRS_PER_SEC   = 75

local WritingMsgs    = {}

-- [[ funcs ]] --

-- New subsitle
function CommsGui.newSubtitle(text, color)
    if Player:GetAttribute("ResultsActive") then return end -- don't show subtitles during results
    task.spawn(function()
        local NewSubtitle : TextLabel = Subtitles.UIListLayout.Subtitle:Clone()
        NewSubtitle.Text = ""
        NewSubtitle.TextColor3 = color
        NewSubtitle.Parent = Subtitles

        SubCounter += 1

        local SubInit = os.clock()
        local SubNumber = SubCounter

        table.insert(WritingMsgs, NewSubtitle)

        for i = 1, #text do
            NewSubtitle.Text = string.upper(string.sub(text, 1, i))
            task.wait(1 / LTRS_PER_SEC)
        end

        table.remove(WritingMsgs, table.find(WritingMsgs, NewSubtitle))

        repeat task.wait() until os.clock() >= SubInit + SUB_LIFETIME or SubCounter >= SubNumber + MAX_SUBS

        local VanishTime = SubCounter >= SubNumber + MAX_SUBS and 0.25 or 1
        TweenService:Create(NewSubtitle, TweenInfo.new(VanishTime), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        Debris:AddItem(NewSubtitle, VanishTime)
    end)
end

-- Clears the subtitles queue
function CommsGui.clearSubtitles()
    SubCounter += MAX_SUBS -- forces queued subtitles to vanish

    for _, sub : TextLabel in Subtitles:GetChildren() do
        if sub:IsA("TextLabel") then
            sub:Destroy()
        end
    end
end

-- Main function
function CommsGui.Function()
    -- Retires the legacy custom chat GUI; the default TextChatService window handles chat now
    Feed.Input.Visible = false
    Feed.Input.Frame.Visible = false
    Feed.TextButton.Visible = false
    Feed.RadioToggle.Visible = false

    -- Receiving subtitles
    CommsService.SubtitleReceive:Connect(function(sender : Player?, message : string, color : Color3)
        CommsGui.newSubtitle(message, color)
    end)

    -- Run service
    RunService.PreRender:Connect(function(dt)
        if not TheGui.Enabled then return end

        ChatSounds.TextScroll.Volume = math.min(#WritingMsgs / 8, 1/8)
    end)
end

return CommsGui
