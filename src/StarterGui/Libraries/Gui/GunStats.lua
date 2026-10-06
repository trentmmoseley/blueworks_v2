local GunStats        = {}

-- Services
local Players         = game:GetService("Players")
local RepStorage      = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

-- Players
local Player          = Players.LocalPlayer
local PlayerGui       = Player.PlayerGui

local Character       = Player.Character or Player.CharacterAdded:Wait()
local Humanoid        = Character:WaitForChild("Humanoid")

-- Modules and objects
local TheGui          = PlayerGui:WaitForChild(script.Name)
local Camera		  = game.Workspace.CurrentCamera

local AmmoTracker 	  = TheGui.Ammo
local AmmoType 		  = TheGui.AmmoType
local ReloadPrompt 	  = TheGui.ReloadPrompt

local Crosshair		  = TheGui.Crosshair

local BulletSpread    = require(RepStorage.Modules.Util.BulletSpread)
local Lerp            = require(RepStorage.Modules.Util.Math.Lerp)
local LerpByFrame     = require(RepStorage.Modules.Util.Math.LerpByFrame)
local Progress        = require(RepStorage.Modules.Util.Math.Progress)

local DamageCrosshair = require(RepStorage.Remotes.DamageCrosshair):Client()

-- Vars and consts
local DEFAULT_WIDTH	  = 0.164
local DEFAULT_HEIGHT  = 0.328

local CurrentTVal	  = 1
local CurrentGun	  = nil

-- Cached ammo state, kept up to date by attribute-change events instead of being
-- recomputed every frame
local CurrentAmmo, DesiredAmmo = nil, nil

-- [[ event-driven helpers ]] --

-- Pushes the current ammo numbers into the UI. Only called when something
-- ammo-related actually changes, not once per frame.
local function RefreshAmmoUI()
    if CurrentGun and _G.CurrentI2 then
        CurrentAmmo = CurrentGun:GetAttribute("Ammo")
        DesiredAmmo = Character:GetAttribute(string.format("Ammo_%s", _G.CurrentI2.AmmoType))

        AmmoTracker.Text = string.format("%i<font size = '10'><font color = 'rgb(200, 200, 200)'>/%i</font></font>", CurrentAmmo, DesiredAmmo)
        AmmoType.Text = string.upper(_G.CurrentI2.AmmoType)

        ReloadPrompt.Text = DesiredAmmo > 0 and "<b>[R]</b> RELOAD" or "NO AMMO"
        ReloadPrompt.TextColor3 = Color3.fromRGB(255, DesiredAmmo > 0 and 175 or 0, 0)
    else
        CurrentAmmo, DesiredAmmo = nil, nil
    end
end

-- Connections that need to be torn down / rebuilt whenever the equipped tool changes
local AmmoAttrConn, CharAmmoAttrConn = nil, nil

local function OnToolEquipped(tool)
    if not (tool and tool:IsA("Tool")) then
        return
    end

    -- Wait until _G.CurrentI2 describes THIS tool. It is set asynchronously by
    -- the Viewmodel's ToolAdded handler, so it may still be nil (just unequipped)
    -- or hold the previous item's info (mid-swap); a plain non-nil check would
    -- pass on that stale value and bail on the Class check below. Also bail if
    -- the tool was removed while waiting.
    repeat
        task.wait()
    until tool.Parent ~= Character or (_G.CurrentI2 and _G.CurrentI2.Name == tool.Name)

    if tool.Parent ~= Character then return end
    if not (_G.CurrentI2 and _G.CurrentI2.Class == "Ranged") then return end

    CurrentGun = tool

    if AmmoAttrConn then AmmoAttrConn:Disconnect() end
    if CharAmmoAttrConn then CharAmmoAttrConn:Disconnect() end

    AmmoAttrConn = tool:GetAttributeChangedSignal("Ammo"):Connect(RefreshAmmoUI)
    CharAmmoAttrConn = Character:GetAttributeChangedSignal(string.format("Ammo_%s", _G.CurrentI2.AmmoType)):Connect(RefreshAmmoUI)

    RefreshAmmoUI()
end

local function OnToolUnequipped(tool)
    if not (tool and tool:IsA("Tool")) then return end

    CurrentGun = nil
    CurrentAmmo, DesiredAmmo = nil, nil

    if AmmoAttrConn then AmmoAttrConn:Disconnect(); AmmoAttrConn = nil end
    if CharAmmoAttrConn then CharAmmoAttrConn:Disconnect(); CharAmmoAttrConn = nil end
end

local function UpdateGuiEnabled()
    TheGui.Enabled = Player.Team == game.Teams.Squadmates
end

-- [[ funcs ]] --

-- Main function
function GunStats.Function()
    UpdateGuiEnabled()
    Player:GetPropertyChangedSignal("Team"):Connect(UpdateGuiEnabled)

    Character.ChildAdded:Connect(OnToolEquipped)
    Character.ChildRemoved:Connect(OnToolUnequipped)

    -- Catch the case where a tool is already equipped when this script starts
    OnToolUnequipped()
    local startingTool = Character:FindFirstChildOfClass("Tool")
    if startingTool then
        OnToolEquipped(startingTool)
    end

    if TheGui.Enabled then
        RunService.PreRender:Connect(function(dt)
            local QuarterLerp = LerpByFrame(1/4, dt)
            local VPSize = Camera.ViewportSize
		    local VisLerp = 1

            local Angle = 0
            if Character and _G.CurrentI2 and _G.CurrentI2.Class == "Ranged" then
                Angle = BulletSpread(_G.CurrentI2, Character:GetAttribute("MovementType"), Character:GetAttribute("isAiming"), Character:GetAttribute("isLeaning"))
                VisLerp = math.clamp(Angle / Camera.FieldOfView, 0, 1)
            end

            if CurrentGun and _G.CurrentI2 and _G.CurrentI2.Class == "Ranged" then
                VisLerp = math.clamp(Angle / Camera.FieldOfView, 0, 1)
            else
                VisLerp = 1
            end

            -- Reload prompt visibility still needs a per-frame timer since it blinks based on os.clock()
            ReloadPrompt.Visible = (CurrentGun and CurrentAmmo == 0 and not Character:GetAttribute("isReloading") and os.clock() * 8 % 1 > 1/2)

            for _, tl : TextLabel in {AmmoTracker, AmmoType, ReloadPrompt} do
                tl.TextTransparency = Lerp(tl.TextTransparency, CurrentGun and 0 or 1, QuarterLerp)
                tl.TextStrokeTransparency = Lerp(tl.TextTransparency, 1, 1/2)
            end

            -- Crosshair
            Crosshair.Size = Crosshair.Size:Lerp(UDim2.fromScale(
                
                VisLerp,
                VisLerp * (VPSize.X / VPSize.Y)
                
            ), QuarterLerp)
            
            Crosshair.Position = UDim2.fromScale(
                
                .5 - Crosshair.Size.X.Scale * .5,
                .5 - Crosshair.Size.Y.Scale * .5
                
            ) + UDim2.fromOffset(1, 0)

            local WidthModifier = 0.004 * (Crosshair.Size.X.Scale / DEFAULT_WIDTH) ^ -1
            local HeightModifier = 0.125 * (Crosshair.Size.X.Scale / DEFAULT_HEIGHT) ^ -1
            local LengthModifier = Lerp(0.05, 1, LerpByFrame(VisLerp, dt))
            local CHColor = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(255, 0, 0), Progress(CurrentTVal, 1, 7))
            
            for _, hair in pairs(Crosshair:GetChildren()) do
                if hair:IsA("Frame") then
                    hair.Transparency = Lerp(hair.Transparency, ((_G.CurrentI2 and _G.CurrentI2.Class == "Ranged") and VisLerp or 1), QuarterLerp / 2)

                    if string.find(hair.Name, "Vertical") then
                        local isTop = string.find(hair.Name, "Top")
                        hair.Size = UDim2.fromScale(WidthModifier, HeightModifier * LengthModifier * CurrentTVal)
                        hair.Position = UDim2.fromScale(0.5 - hair.Size.X.Scale, isTop and 0 or 1 - hair.Size.Y.Scale)
                    else
                        local isLeft = string.find(hair.Name, "Left")
                        hair.Size = UDim2.fromScale(HeightModifier * LengthModifier * CurrentTVal, WidthModifier)
                        hair.Position = UDim2.fromScale(isLeft and 0 or 1 - hair.Size.X.Scale, 0.5 - hair.Size.Y.Scale) - UDim2.fromOffset(1.25, -1)
                    end
                    hair.BackgroundColor3 = CHColor
                end
            end

            CurrentTVal = Lerp(CurrentTVal, 1, QuarterLerp / 2)
        end)

        -- Damage crosshairs
        DamageCrosshair:On(function()
            CurrentTVal = 7
		    PlayerGui.Sounds.Guns.DamageMarker:Play()
        end)
    end
end

return GunStats