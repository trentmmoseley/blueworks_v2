-- Services
local Debris       = game:GetService("Debris")
local Rand         = Random.new()
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Vars and consts
local DmgInd       = {

    ["Indicator"]     = {

        ["RENDER_DISTANCE"] = math.huge,
        ["Function"]        = function(args)
            local CF = args[2]
            local Dmg = args[1]

            local DamageInd = RepStorage.VFX.Misc.DmgIndicator:Clone()
            DamageInd.Parent = game.Workspace
            DamageInd.CFrame = CF + Vector3.new(Rand:NextNumber(-1, 1) * 2, 0, Rand:NextNumber(-1, 1) * 2)
            DamageInd.BillboardGui.TextLabel.Text = math.floor(Dmg)
            DamageInd.BillboardGui.TextLabel.TextColor3 = Dmg < 0 and Color3.fromHSV(1, math.abs(Dmg) / 100, 1) or Color3.fromRGB(0, 255, 100)

            local TI = TweenInfo.new(1/2)
            TweenService:Create(DamageInd.BillboardGui.TextLabel, TI, {Size = UDim2.fromScale(2/3, 2/3), Position = UDim2.fromScale(1/6, 1/6)}):Play()
            TweenService:Create(DamageInd, TweenInfo.new(5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {CFrame = DamageInd.CFrame + Vector3.new(0, 5, 0)}):Play()

            task.wait(1)
            TweenService:Create(DamageInd.BillboardGui.TextLabel, TI, {Size = UDim2.fromScale(0, 0), Position = UDim2.fromScale(0.5, 0.5)}):Play()
            Debris:AddItem(DamageInd, 1/2)
        end

    },

}

return DmgInd