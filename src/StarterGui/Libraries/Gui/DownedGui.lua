local DownedGui      = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()
local Humanoid       = Character:FindFirstChildOfClass("Humanoid")
local RootPart       = Character:WaitForChild("HumanoidRootPart")

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)

local LifeBar        = TheGui.Frame.LifeBar
local Bar            = LifeBar.Frame
local Stroke         = LifeBar.UIStroke
local Timer          = LifeBar.Timer

local SAT            = (255 - 100) / 255

local TLTexts        = {
    TextLabel1       = {[false] = "YOU WILL <font color = 'rgb(255, 100, 100)'>DIE</font> IN", [true] = "SOMEONE IS TRYING"},
    TextLabel2       = {[false] = "UNLESS A TEAMMATE SAVES YOU", [true] = "TO SAVE YOU"}
}

-- Cache the text labels once instead of calling GetChildren() every frame
local TextLabels = {}
for _, child in LifeBar.Parent:GetChildren() do
    if child:IsA("TextLabel") then
        table.insert(TextLabels, child)
    end
end

-- Main function
function DownedGui.Function()
    local healthConn, beingSavedConn = nil, nil

    local function updateHealthVisuals()
        local Percentage = math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1)
        local beingSaved = Character:GetAttribute("beingSaved")
        local hue = beingSaved and (1 / 3) or 1

        Bar.Size = UDim2.fromScale(Percentage, 1)
        Timer.Text = string.format("%.2i:%.2i", math.floor(Humanoid.Health), math.floor((Humanoid.Health % 1) * 60))

        local textSat = SAT * (1 - (beingSaved and 0 or Percentage))
        local textColor = Color3.fromHSV(hue, textSat, 1)
        for _, tl in TextLabels do
            tl.TextColor3 = textColor
        end
    end

    local function updateBeingSavedVisuals()
        local beingSaved = Character:GetAttribute("beingSaved")
        local hue = beingSaved and (1 / 3) or 1
        local barColor = Color3.fromHSV(hue, SAT, 1)

        Bar.BackgroundColor3 = barColor
        Stroke.Color = barColor
        Timer.Visible = not beingSaved

        for _, tl in TextLabels do
            tl.Text = TLTexts[tl.Name][beingSaved]
        end

        updateHealthVisuals() -- hue/sat just changed, so refresh the frame-dependent bits too
    end

    Character:GetAttributeChangedSignal("isDowned"):Connect(function()
        local isDowned = Character:GetAttribute("isDowned") == true
        TheGui.Enabled = isDowned

        if healthConn then healthConn:Disconnect(); healthConn = nil end
        if beingSavedConn then beingSavedConn:Disconnect(); beingSavedConn = nil end

        if not isDowned then return end

        beingSavedConn = Character:GetAttributeChangedSignal("beingSaved"):Connect(updateBeingSavedVisuals)
        healthConn = Humanoid.HealthChanged:Connect(updateHealthVisuals)

        updateBeingSavedVisuals() -- initial paint, also calls updateHealthVisuals()
    end)

    local ProxPrompt = RootPart:FindFirstChildOfClass("ProximityPrompt")
    if ProxPrompt then
        ProxPrompt:Destroy()
    end

    RootPart.ChildAdded:Connect(function(prompt)
        if prompt:IsA("ProximityPrompt") then
            prompt:Destroy()
        end
    end)
end

return DownedGui