local InventoryGui        = {}

-- Services
local Players        = game:GetService("Players")
local RepStorage     = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")

local DataController = _G.Knit.GetController("DataController")
local InvService     = _G.Knit.GetService("InventoryService")

-- Players
local Player         = Players.LocalPlayer
local PlayerGui      = Player.PlayerGui

local Character      = Player.Character or Player.CharacterAdded:Wait()

-- Modules and objects
local TheGui         = PlayerGui:WaitForChild(script.Name)
local ItemDisplays   = RepStorage:WaitForChild("ItemDisplays")

local Frame          = TheGui:WaitForChild("Frame")
local Counter        = TheGui:WaitForChild("Counter")
local ItemDesc       = TheGui:WaitForChild("ItemDesc")
local ItemName       = TheGui:WaitForChild("ItemName")
local Tier           = TheGui:WaitForChild("Tier")

local TierInfo       = require(RepStorage.Modules.Data.Tiers)

-- Vars and consts
local NUM_KEYS       = {"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero"}
local NextHide       = os.clock()

local DROP_KB        = Enum.KeyCode.X
local FADE_WAIT_TIME = 5
local ROT_SPEED      = 45 -- degrees

_G.ClientInv         = {
    Items = {},
    Equipped = 1,
    MaxSlots = 1
}

local SlotThreads    = {}

-- [[ funcs ]] --

-- Paints slot
local function paintSlot(slot : Frame, item : {}?, selected : boolean) : ()
    if SlotThreads[slot.Name] then
        task.cancel(SlotThreads[slot.Name])
        SlotThreads[slot.Name] = nil
    end

    SlotThreads[slot.Name] = task.spawn(function()
        local TI = TweenInfo.new(1/3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

        TweenService:Create(slot, TI, {Size = UDim2.fromScale(selected and 2 or 0.8, selected and 1 or 0.8), BackgroundTransparency = (selected and item) and 0 or 1}):Play()
        TweenService:Create(slot.UIStroke, TI, {Transparency = 0}):Play()
        TweenService:Create(slot.ViewportFrame, TI, {ImageColor3 = Color3.fromHSV(2/3, 0, selected and 0 or 1), ImageTransparency = 0}):Play()

        task.wait(FADE_WAIT_TIME)

        if os.clock() >= NextHide then
            TweenService:Create(slot, TI, {BackgroundTransparency = 1}):Play()
            TweenService:Create(slot.UIStroke, TI, {Transparency = 1}):Play()
            TweenService:Create(slot.ViewportFrame, TI, {BackgroundTransparency = 1, ImageTransparency = 1}):Play()
        end

        SlotThreads[slot.Name] = nil
    end)
end

-- Paints UI
local function paintUI() : ()
    NextHide = os.clock() + FADE_WAIT_TIME

    -- Paints UI
    ItemName.Text = ""
    ItemDesc.Text = ""
    Tier.Text = ""
    Counter.Text = ""

    for i = 1, _G.ClientInv.MaxSlots do
        local Item = _G.ClientInv.Items[i]
        local isSelected = tonumber(i) == _G.ClientInv.Equipped
        local TierInfo = Item and TierInfo.Tiers[Item.Tier] or {Name = "N/A", Color = Color3.fromRGB(128, 128, 128)}

        local FoundFrame = Frame:FindFirstChild("Slot"..i)
        local Camera = FoundFrame and FoundFrame.ViewportFrame:FindFirstChildOfClass("Camera")

        if not FoundFrame then
            FoundFrame = Frame.UIListLayout.Slot:Clone()
            FoundFrame.Name = "Slot"..i

            Camera = Instance.new("Camera")
            Camera.Parent = FoundFrame.ViewportFrame
            FoundFrame.ViewportFrame.CurrentCamera = Camera

            FoundFrame.Parent = Frame
        end

        FoundFrame.BackgroundColor3 = TierInfo.Color
        FoundFrame.UIStroke.Color = TierInfo.Color
        FoundFrame.ViewportFrame.ImageColor3 = TierInfo.Color
        FoundFrame.ViewportFrame.BackgroundColor3 = TierInfo.Color

        -- Rotating model
        local TheDisplay = FoundFrame.ViewportFrame.WorldModel:FindFirstChildOfClass("Model")
        if TheDisplay then
            TheDisplay:Destroy()
        end

        if Item then
            TheDisplay = ItemDisplays:FindFirstChild(Item.Name):Clone()
            TheDisplay.Parent = FoundFrame.ViewportFrame.WorldModel
            TheDisplay:PivotTo(Camera.CFrame + Camera.CFrame.LookVector * TheDisplay.PrimaryPart.Size.Magnitude)

            -- Repaints display
            for _, part in TheDisplay:GetDescendants() do
                if part:IsA("BasePart") then
                    part.CastShadow = false
                    part.Material = Enum.Material.Neon
                    part.Color = TierInfo.Color
                end
            end            
        end

        -- Writes details
        if isSelected and Item then
            -- Details
            task.spawn(function()
                local ItemDisplay = ItemDisplays:FindFirstChild(Item.Name)
                local ItemInfo = require(ItemDisplay.Configuration.ItemInfo)

                ItemName.Text = ItemInfo.Name
                ItemDesc.Text = ItemInfo.Description

                Tier.Text = string.format("TIER %s", TierInfo.Name)
                Tier.TextColor3 = TierInfo.Color

                ItemName.TextTransparency = 0
                ItemDesc.TextTransparency = 0
                Tier.TextTransparency = 0
                Counter.TextTransparency = 0

                ItemName.TextStrokeTransparency = 0.5
                ItemDesc.TextStrokeTransparency = 0.5
                Tier.TextStrokeTransparency = 0.5
                Counter.TextStrokeTransparency = 0.5

                Counter.Text = Item.Stack > 1 and "x"..Item.Stack or ""

                task.wait(FADE_WAIT_TIME)

                if os.clock() >= NextHide then
                    local TI = TweenInfo.new(1/8)
                    TweenService:Create(TheGui.ItemName, TI, {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
                    TweenService:Create(TheGui.ItemDesc, TI, {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
                    TweenService:Create(TheGui.Tier, TI, {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
                    TweenService:Create(TheGui.Counter, TI, {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
                end
            end)
        end

        paintSlot(FoundFrame, Item, isSelected)
    end

    -- Removes excess frames
    for _, frame in Frame:GetChildren() do
        if frame:IsA("Frame") and tonumber(frame.Name:sub(5)) > _G.ClientInv.MaxSlots then
            frame:Destroy()
        end
    end
end

-- Main function
function InventoryGui.Function()
    if Player.Team == game.Teams.Squadmates then
        InvService.UpdateInventory:Connect(function(items : {}, slot : number, maxslots : number)
            _G.ClientInv = {
                Items = {},
                Equipped = slot,
                MaxSlots = maxslots
            }

            for i, item in pairs(items) do
                _G.ClientInv.Items[tonumber(i)] = item
            end

            paintUI()
        end)

        -- Navigating inventory
        DROP_KB = Enum.KeyCode[DataController:Get("Keybinds.Drop.Keyboard")]

        UIS.InputBegan:Connect(function(input, gpe)
            if not gpe and not Player:GetAttribute("isChatting") then
                if input.KeyCode == DROP_KB then
				    InvService.ActionRequest:Fire("DROP")
                else
                    for i, key in pairs(NUM_KEYS) do
                        if string.find(tostring(input.KeyCode), key) then
                            InvService.ActionRequest:Fire("SWAP", i)
                        end
                    end
                end
            end
        end)

        -- On step
        RunService.PreRender:Connect(function(dt)
            -- Rotates item displays of frames
            for _, frame in Frame:GetChildren() do
                if frame:IsA("Frame") then
                    local Camera = frame.ViewportFrame:FindFirstChildOfClass("Camera")
                    local Display = frame.ViewportFrame.WorldModel:FindFirstChildOfClass("Model")
                    if Display then
                        Display:PivotTo((Camera.CFrame + Camera.CFrame.LookVector * Display.PrimaryPart.Size.Magnitude) * CFrame.Angles(0, math.rad(ROT_SPEED * os.clock() % 360), math.rad(Display:GetAttribute("DisplayTilt"))))
                    end
                end
            end
        end)

        Character:GetAttributeChangedSignal("isDowned"):Connect(function()
            TheGui.Enabled = Character:GetAttribute("isDowned") ~= true
        end)
    end
end

return InventoryGui