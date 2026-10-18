local ProxyGrabGui   = {}

-- Services
local Players        = game:GetService("Players")
local Rand           = Random.new()
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")

local NPCService     = _G.Knit.GetService("NPCService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)

local Keybind        = TheGui.Keybind
local KeybindRatio   : UIAspectRatioConstraint = Keybind.UIAspectRatioConstraint
local UIStroke       = Keybind.UIStroke
local PressPrompt    : TextLabel = Keybind.PressPrompt
local Key            : TextLabel = Keybind.Key

local ProgressBar    : Frame = TheGui.Progress
local TheBar         : Frame = ProgressBar.Frame
local ProgressStroke : UIStroke = ProgressBar.UIStroke

local GrabbedBlurb   : TextLabel = TheGui.GrabbedBlurb
local Command        : TextLabel = TheGui.TextLabel

local Sounds         = PlayerGui.Sounds.GrabGui

local ProxyGrabSettings = require(RepStorage.Modules.Data.ProxyGrabSettings)

-- Vars and consts
local KEYBINDS       = ProxyGrabSettings.KEYBINDS
local KEYBIND_LOOKUP = {}

for _, Info in KEYBINDS do
    KEYBIND_LOOKUP[Info[1].Name] = Info
end

local WHITE                       = Color3.new(1, 1, 1)
local GOOD_COLOR                  = Color3.fromRGB(0, 255, 0)
local BAD_COLOR                   = Color3.fromRGB(255, 0, 0)
local ORIGINAL_BAR_COLOR          = TheBar.BackgroundColor3
local ORIGINAL_PROGRESS_STROKE_COLOR = ProgressStroke.Color
local ORIGINAL_BLURB_TEXT         = GrabbedBlurb.Text
local ORIGINAL_BLURB_COLOR        = GrabbedBlurb.TextColor3
local ORIGINAL_BLURB_VISIBLE      = GrabbedBlurb.Visible

local FEEDBACK_DURATION      = 1/4
local ESCAPE_FLASHES         = 8
local ESCAPE_FLASH_INTERVAL  = 1/16

local FeedbackGeneration = 0
local GrabGeneration     = 0
local KeyTweens          = {}
local Progress           = ProxyGrabSettings.INITIAL_PROGRESS

local PRESS_PROMPT_TEXT = {
    Good                = {
        "GOOD!",
        "NICE!",
        "GREAT!",
        "OKAY!",
        "COOL!",
        "TOUGH!",
    },
    Bad                = {
        "NOPE!",
        "OOPS!",
        "UH-OH!",
        "NUH-UH!",
        "ACK!",
        "WHOOPS!",
    }
}

-- [[ funcs ]] --

local function stopKeyTweens()
    for _, Tween in KeyTweens do
        Tween:Cancel()
    end

    table.clear(KeyTweens)
end

local function tweenKeybind(Info)
    stopKeyTweens()

    local KeyColor = Info[2]:Lerp(WHITE, 1)
    local TI = TweenInfo.new(FEEDBACK_DURATION)
    table.insert(KeyTweens, TweenService:Create(UIStroke, TI, {Color = KeyColor}))
    table.insert(KeyTweens, TweenService:Create(PressPrompt, TI, {TextColor3 = KeyColor}))
    table.insert(KeyTweens, TweenService:Create(Key, TI, {TextColor3 = KeyColor}))
    table.insert(KeyTweens, TweenService:Create(KeybindRatio, TI, {AspectRatio = Info[3]}))

    for _, Tween in KeyTweens do
        Tween:Play()
    end
end

local function setKeybindColor(KeyColor : Color3)
    stopKeyTweens()
    UIStroke.Color = KeyColor
    PressPrompt.TextColor3 = KeyColor
    Key.TextColor3 = KeyColor
end

local function updateKey()
    if Character:GetAttribute("isGrabbed") ~= true then
        return
    end

    FeedbackGeneration += 1
    local Info = KEYBIND_LOOKUP[Character:GetAttribute("ProxyGrabKey")]
    if not Info then
        return
    end

    Key.Text = string.upper(Info[1].Name)
    tweenKeybind(Info)
end

local function updateProgress()
    Progress = math.clamp(tonumber(Character:GetAttribute("ProxyGrabProgress")) or ProxyGrabSettings.INITIAL_PROGRESS, 0, 100)
    TheBar.Size = UDim2.fromScale(Progress / 100, 1)
end

local function closeGrab()
    GrabGeneration += 1
    FeedbackGeneration += 1
    stopKeyTweens()
    TheGui.Enabled = false
end

local function startGrab()
    GrabGeneration += 1
    FeedbackGeneration += 1
    GrabbedBlurb.Text = ORIGINAL_BLURB_TEXT
    GrabbedBlurb.TextColor3 = ORIGINAL_BLURB_COLOR
    GrabbedBlurb.Visible = ORIGINAL_BLURB_VISIBLE
    PressPrompt.Text = "PRESS"
    TheGui.Enabled = true
    Command.Visible = true
    ProgressBar.Visible = true
    Keybind.Visible = true
    updateProgress()
    updateKey()
end

local function escapeGrab()
    GrabGeneration += 1
    FeedbackGeneration += 1
    local Generation = GrabGeneration

    stopKeyTweens()
    TheGui.Enabled = true
    GrabbedBlurb.Text = "ESCAPED!"
    GrabbedBlurb.TextColor3 = GOOD_COLOR
    GrabbedBlurb.Visible = false

    ProgressBar.Visible = false
    Command.Visible = false
    Keybind.Visible = false

    task.spawn(function()
        for _ = 1, ESCAPE_FLASHES do
            if Generation ~= GrabGeneration then
                return
            end

            GrabbedBlurb.Visible = true
            task.wait(ESCAPE_FLASH_INTERVAL)
            if Generation ~= GrabGeneration then
                return
            end

            GrabbedBlurb.Visible = false
            task.wait(ESCAPE_FLASH_INTERVAL)
        end

        if Generation == GrabGeneration then
            TheGui.Enabled = false
        end
    end)
end

local function handleFeedback()
    if Character:GetAttribute("isGrabbed") ~= true then
        return
    end

    local Feedback = Character:GetAttribute("ProxyGrabFeedback")
    local Blurbs = PRESS_PROMPT_TEXT[Feedback]
    local Info = KEYBIND_LOOKUP[Character:GetAttribute("ProxyGrabKey")]
    if not Blurbs or not Info then
        return
    end

    FeedbackGeneration += 1
    local Generation = FeedbackGeneration
    local CurrentGrab = GrabGeneration
    local Good = Feedback == "Good"

    Key.Text = string.upper(Info[1].Name)
    PressPrompt.Text = Blurbs[Rand:NextInteger(1, #Blurbs)]
    setKeybindColor(Good and GOOD_COLOR or BAD_COLOR)

    Sounds.Good:Stop()
    Sounds.Bad:Stop()
    local FeedbackSound = Good and Sounds.Good or Sounds.Bad
    FeedbackSound:Play()

    if Rand:NextNumber() < 1/2 then
        Sounds.Struggle.PlaybackSpeed = Rand:NextNumber(0.9, 1.1)
        Sounds.Struggle:Stop()
        Sounds.Struggle:Play()
    end

    tweenKeybind(Info)
    task.delay(FEEDBACK_DURATION, function()
        if Generation == FeedbackGeneration and CurrentGrab == GrabGeneration then
            PressPrompt.Text = "PRESS"
        end
    end)
end

-- Main function
function ProxyGrabGui.Function()
    Character:GetAttributeChangedSignal("isGrabbed"):Connect(function()
        if Character:GetAttribute("isGrabbed") == true then
            startGrab()
        elseif Character:GetAttribute("ProxyGrabResult") ~= "ESCAPED" then
            closeGrab()
        end
    end)

    Character:GetAttributeChangedSignal("ProxyGrabKey"):Connect(updateKey)
    Character:GetAttributeChangedSignal("ProxyGrabProgress"):Connect(updateProgress)
    Character:GetAttributeChangedSignal("ProxyGrabInputSerial"):Connect(handleFeedback)
    Character:GetAttributeChangedSignal("ProxyGrabResult"):Connect(function()
        local Result = Character:GetAttribute("ProxyGrabResult")
        if Result == "ESCAPED" then
            escapeGrab()
        elseif Result == "KILLED" then
            closeGrab()
        end
    end)

    UIS.InputBegan:Connect(function(input, gpe)
        if gpe or Character:GetAttribute("isGrabbed") ~= true then
            return
        end

        local KeyName = input.KeyCode.Name
        if KEYBIND_LOOKUP[KeyName] then
            NPCService.ProxyGrabInput:Fire(KeyName)
        end
    end)

    RunService.RenderStepped:Connect(function()
        local IsCritical = Character:GetAttribute("isGrabbed") == true and Progress < 20
        local FlashRed = IsCritical and os.clock() * 6 % 1 >= 0.5
        local BarColor = FlashRed and BAD_COLOR or ORIGINAL_BAR_COLOR
        local StrokeColor = FlashRed and BAD_COLOR or ORIGINAL_PROGRESS_STROKE_COLOR

        if TheBar.BackgroundColor3 ~= BarColor then
            TheBar.BackgroundColor3 = BarColor
        end
        if ProgressStroke.Color ~= StrokeColor then
            ProgressStroke.Color = StrokeColor
        end
    end)

    updateProgress()
    if Character:GetAttribute("isGrabbed") == true then
        startGrab()
    else
        closeGrab()
    end
end

return ProxyGrabGui