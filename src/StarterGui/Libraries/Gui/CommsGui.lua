local CommsGui       = {}

-- Services
local Debris         = game:GetService("Debris")
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")

local CommsService   = _G.Knit.GetService("CommsService")
local DataController = _G.Knit.GetController("DataController")
local SetsService    = _G.Knit.GetService("SettingsService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local ChatSounds     = PlayerGui.Sounds.Chat

local Feed           = TheGui:WaitForChild("Feed")
local Subtitles      = TheGui:WaitForChild("Subtitles")

local Output         = Feed:WaitForChild("Output")
local ChatInput      = Feed:WaitForChild("Input")
local ChatButton     = Feed:WaitForChild("TextButton")

local RadioToggle    = Feed.RadioToggle
local RadioObj       = RadioToggle.ViewportFrame.WorldModel.Radio

local NameParts      = require(RepStorage.Modules.Util.NameParts)

-- Vars and consts
local PHT_PLATFORM   = {["Desktop"] = "\"/\"", ["Mobile"] = "here", ["Console"] = "Button North"}
local PLR_PLATFORM   = Player:GetAttribute("Device")

local MsgCounter     = 0
local MAX_MSGS       = 8
local MSG_LIFETIME   = 10

local SubCounter     = 0
local MAX_SUBS       = 6
local SUB_LIFETIME   = 7

local LTRS_PER_SEC   = 75

local WritingMsgs    = {}

local RADIO_DEF_CF   = RadioObj.PrimaryPart.CFrame

local RADIO_OFF      = Color3.fromRGB(100, 0, 0)
local RADIO_ON       = Color3.fromRGB(0, 255, 75)

local onChatCD       = false

-- [[ funcs ]] --

-- Writes placeholder text
local function writePrompt()
    ChatInput.PlaceholderText = string.format("Press %s to chat", PHT_PLATFORM[PLR_PLATFORM])
end

-- Captures chat input focus
local function captureFocus()
    if not Player:GetAttribute("isChatting") and not onChatCD and TheGui.Enabled then
        SetsService.UpdateSetting:Fire("isChatting", true)
    end
end

-- Writes message
function CommsGui.newMessage(sender, text, color, tp, radio)
    task.spawn(function()
        local NewMessage : TextLabel = Output.UIListLayout.Message:Clone()
        NewMessage.Text = ""
        NewMessage.TextColor3 = sender == Player and Color3.fromHSV(1, 0, 1) or color
        NewMessage.TextTransparency = tp
        NewMessage.Parent = Output

        MsgCounter += 1

        local MsgInit = os.clock()
        local MsgNumber = MsgCounter
        local isTyping = true

        if radio then
            NewMessage._static.ImageTransparency = 0
		    NewMessage.TextColor3 = Color3.fromRGB(0, 255, 150)
            TweenService:Create(NewMessage._static, TweenInfo.new(1/2), {ImageTransparency = 2/3}):Play()
        end
        
        if sender and sender:IsA("Player") then
            -- Sound for own message
            if sender.Name == Player.Name then
                task.spawn(function()
                    table.insert(WritingMsgs, NewMessage)
                    repeat task.wait() until not isTyping
                    table.remove(WritingMsgs, table.find(WritingMsgs, NewMessage))
                end)
            end

            local Displayname, Realname = NameParts(sender)
            for i = 1, #Displayname do
                NewMessage.Text = string.sub(Displayname, 1, i)
                task.wait(1 / LTRS_PER_SEC)
            end
        
            local SavedString = NewMessage.Text
            if Realname then
            for i = 1, #Realname do
                    NewMessage.Text = string.format(SavedString.."%s", string.format(" <font size = '10'>(@%s)</font>", string.sub(Realname, 1, i)))
                    task.wait(1 / LTRS_PER_SEC)
                end 
            end

            NewMessage.Text = NewMessage.Text..": "
            task.wait(1 / LTRS_PER_SEC)

            SavedString = NewMessage.Text
            for i = 1, #text do
                NewMessage.Text = SavedString..string.format("<b><font color = 'rgb(255, 255, 255)'>%s</font></b>", string.sub(text, 1, i))
                task.wait(1 / LTRS_PER_SEC)
            end
        else
            for i = 1, #text do
                NewMessage.Text = string.sub(text, 1, i)
                task.wait(1 / LTRS_PER_SEC)
            end
        end

        isTyping = false
        repeat task.wait() until os.clock() >= MsgInit + MSG_LIFETIME or MsgCounter >= MsgNumber + MAX_MSGS

        local VanishTime = MsgCounter >= MsgNumber + MAX_MSGS and 0.5 or 2
        TweenService:Create(NewMessage, TweenInfo.new(VanishTime), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        TweenService:Create(NewMessage._static, TweenInfo.new(VanishTime), {ImageTransparency = 1}):Play()
        Debris:AddItem(NewMessage, VanishTime)
    end)
end

-- New subsitle
function CommsGui.newSubtitle(text, color)
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

-- Updates radio
local function updateRadio()
    if not RadioToggle.Visible then return end
    local radioOn = Player:GetAttribute("radioOn")

    -- Button
    local TI = TweenInfo.new(1/4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local TheColor = radioOn and RADIO_ON or RADIO_OFF

    TweenService:Create(RadioToggle, TI, {BackgroundColor3 = TheColor}):Play()
    for _, part : UIStroke | ViewportFrame | ImageLabel in RadioToggle:GetChildren() do
        if part:IsA("UIStroke") then
           TweenService:Create(part, TI, {Color = TheColor}):Play()
           part.Transparency = 0
           if radioOn then
              task.spawn(function()
                  task.wait(1/4)
                  TweenService:Create(part, TI, {Transparency = (radioOn and 1/2 or 3/4)}):Play()
              end)
           end
        elseif part:IsA("ViewportFrame") or part:IsA("ImageLabel") then
            TweenService:Create(part, TI, {ImageColor3 = TheColor}):Play()
            if part:IsA("ViewportFrame") then
                TweenService:Create(part, TI, {Ambient = TheColor, LightColor = TheColor}):Play()
            end

            part.ImageTransparency = 0
            if radioOn then
                task.spawn(function()
                    TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = part:IsA("ImageLabel") and 1 or (radioOn and 1/2 or 3/4)}):Play()
                end)
            else
                if part:IsA("ImageLabel") then
                    part.ImageTransparency = 1
                end
            end
        end
    end

    -- Sounds
    ChatSounds.RadioToggle.Click.PlaybackSpeed = radioOn and 1 or 0.9
    ChatSounds.RadioToggle.Click:Play()
    
    if radioOn then
        ChatSounds.RadioStatic.Volume = 0.25
    end
end

-- Main function
function CommsGui.Function()
    DataController:AwaitLoaded()
    writePrompt()

    -- Capturing input
    UIS.InputBegan:Connect(function(input, gpe)
        if not gpe then
            if Enum.KeyCode[DataController:Get("Keybinds.ChatToggle.Keyboard")] == input.KeyCode then
                captureFocus()
            else
                if Enum.KeyCode[DataController:Get("Keybinds.ToggleRadio.Keyboard")] == input.KeyCode and RadioToggle.Visible then
                    SetsService.UpdateSetting:Fire("radioOn", not Player:GetAttribute("radioOn"))
                end
            end
        end
    end)
    
    Player:GetAttributeChangedSignal("isChatting"):Connect(function()
        if Player:GetAttribute("isChatting") then
            ChatInput:CaptureFocus()
        end
    end)

    ChatButton.MouseButton1Click:Connect(captureFocus)

    ChatInput.Focused:Connect(function()
        ChatInput.PlaceholderText = ""
        ChatInput.Text = ""
        TweenService:Create(ChatInput.Frame, TweenInfo.new(1/8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 0.1)}):Play()
        
        if Player:GetAttribute("radioOn") then
            ChatSounds.ChatToggle:Play()
        end
    end)

    -- Sending message
    ChatInput.FocusLost:Connect(function(enterpressed)
        if enterpressed then
            CommsService.MessageSend:Fire(ChatInput.Text)
        end

        ChatInput.Text = ""
        writePrompt()
        SetsService.UpdateSetting:Fire("isChatting", false)
        TweenService:Create(ChatInput.Frame, TweenInfo.new(1/8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0.1)}):Play()
    end)

    -----------------------------------------------

    -- Receiving messages
    CommsService.MessageReceive:Connect(function(sender : Player?, message : string, color : Color3, tp : number, radio : boolean)
        if sender and sender ~= Player and sender.Team == game.Teams.Squadmates then
            game:GetService("Chat"):Chat(sender.Character or sender.CharacterAdded:Wait(), message)
        end

        if radio then
			ChatSounds.TextReceive:Play()
            ChatSounds.RadioToggle.Beep:Play()
			ChatSounds.RadioToggle.Static.Volume = 1
		end

        CommsGui.newMessage(sender, message, color, tp, radio)
    end)

    -- Receiving subtitles
    CommsService.SubtitleReceive:Connect(function(sender : Player?, message : string, color : Color3)
        CommsGui.newSubtitle(message, color)
    end)

    -- Run service
    RunService.PreRender:Connect(function(dt)
        if not TheGui.Enabled then return end

        ChatSounds.TextScroll.Volume = math.min(#WritingMsgs / 8, 1/8)
        ChatSounds.RadioStatic.Volume *= 0.95
        ChatSounds.RadioToggle.Static.Volume *= 0.99

        CommsService:IsOnCooldown(Player):andThen(function(oncd, length)
            onChatCD = oncd
            if oncd then
                ChatInput.PlaceholderText = string.format("Cooldown (%i)", length)
            else
                if not string.find(ChatInput.PlaceholderText, "Press") and not Player:GetAttribute("isChatting") then
                    writePrompt()
                end
            end
        end)

        -- Radio button
        RadioToggle.Visible = Player.Team == game.Teams.Squadmates
        RadioObj:PivotTo(RADIO_DEF_CF * CFrame.Angles(math.rad(22.5), math.rad(os.clock() * 22.5) % (2 * math.pi), math.rad(22.5)))
    end)

    -- Cooldown init
    CommsService.CooldownInit:Connect(function(new : boolean)
        if new then
            ChatSounds.Cooldown:Play()
        end
        
        TweenService:Create(ChatInput, TweenInfo.new(1/4), {PlaceholderColor3 = Color3.fromHSV(1, new and 1/2 or 0, new and 1 or 0.7)}):Play()
    end)

    updateRadio()
    Player:GetAttributeChangedSignal("radioOn"):Connect(function()
        updateRadio()
    end)

    RadioToggle.TextButton.MouseButton1Click:Connect(function()
        updateRadio()
    end)
end

return CommsGui