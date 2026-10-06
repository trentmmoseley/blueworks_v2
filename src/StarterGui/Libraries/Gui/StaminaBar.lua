local StaminaBar     = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Bar            = TheGui.Bar

local MMT_SETTINGS   = require(RepStorage.Modules.Data.MovementSettings)

-- Vars and consts
local isCrit         = false

-- [[ funcs ]] --

-- Gets stamina
local function getStamina() : number
    return Character:GetAttribute("Stamina")
end

-- Manages UI
local function manageUI()
    local STAMINA = getStamina()

    -- Amount
    TweenService:Create(Bar.Amount, TweenInfo.new(1/4), {Size = UDim2.fromScale(STAMINA / Character:GetAttribute("MaxStamina"), 1), Position = UDim2.fromScale(1 - (STAMINA / Character:GetAttribute("MaxStamina")), 0)}):Play()

    -- Visibility
    local TI = TweenInfo.new(1/2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local doVis = STAMINA < Character:GetAttribute("MaxStamina")
    isCrit = STAMINA < MMT_SETTINGS.RUN.MinStamina

    for _, part : UIStroke | Frame in Bar:GetChildren() do
        if part:IsA("UIStroke") then
            TweenService:Create(part, TI, {Transparency = doVis and 0 or 1, Color = Color3.fromHSV(1, isCrit and 1 or 0, 1)}):Play()
        elseif part:IsA("Frame") then
            TweenService:Create(part, TI, {BackgroundTransparency = doVis and 0 or 1, BackgroundColor3 = Color3.fromHSV(1, isCrit and 1 or 0, 1)}):Play()
        end
    end
end

-- Main function
function StaminaBar.Function()
    manageUI()
    Character:GetAttributeChangedSignal("Stamina"):Connect(function()
        manageUI()
    end)

    -- On death
    Player.Changed:Connect(function()
        if Player.Team == game.Teams.Spectators then
            TheGui.Enabled = false
        end
    end)

    task.defer(function()
        while true do
            TheGui.Enabled = (os.clock() * 6 % 1 >= 0.5) or not isCrit
            task.wait()
        end
    end)
end

return StaminaBar