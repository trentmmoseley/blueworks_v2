local RiotShield     = {}

-- Services
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local Bar            = TheGui.Bar
local ArmedStatus    = Bar.ArmedStatus

local RS             : Tool? = Character:FindFirstChild("Riot Shield")
local DurabilityConn : RBXScriptConnection = nil

-- [[ funcs ]] --

-- Manages Gui
local function manageGui()
    RS = Character:FindFirstChild("Riot Shield")
    if RS and not DurabilityConn then
        RS:GetAttributeChangedSignal("Durability"):Connect(manageGui)
    else
        if DurabilityConn then
            DurabilityConn:Disconnect()
            DurabilityConn = nil
        end
    end
    
    local usingRiotShield = RS and Character:GetAttribute("useRiotShield") == true
    local TI = TweenInfo.new(1/4)

    TweenService:Create(Bar.Amount, TI, {Transparency = usingRiotShield and 0 or 1}):Play()
    TweenService:Create(ArmedStatus, TI, {TextTransparency = RS and 0 or 1, TextStrokeTransparency = RS and 1/2 or 1, TextColor3 = Color3.fromHSV(1 / (usingRiotShield and 3 or 1), 3/4, 1)}):Play()
    TweenService:Create(Bar.UIStroke, TI, {Transparency = usingRiotShield and 0 or 1}):Play()

    if RS then
        ArmedStatus.Text = string.format("%sARMED", usingRiotShield and "" or "NOT ")
        TweenService:Create(Bar.Amount, TI, {Size = UDim2.fromScale(RS:GetAttribute("Durability") / 100, 1)}):Play()
    end
end

-- Main function
function RiotShield.Function()
    manageGui()
    Character:GetAttributeChangedSignal("useRiotShield"):Connect(manageGui)
    Character.ChildAdded:Connect(manageGui)
    Character.ChildRemoved:Connect(manageGui)
end

return RiotShield