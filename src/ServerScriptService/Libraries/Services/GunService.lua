-- Services
local Debris          = game:GetService("Debris")
local Rand            = Random.new()
local RepStorage      = game:GetService("ReplicatedStorage")
local S2              = game:GetService("ServerStorage")

-- Modules and objects
local Knit            = require(RepStorage.Packages.Knit)
local GunService      = Knit.CreateService({
    Name              = "GunService",
    Client            = {
        AimToggle     = Knit.CreateSignal(),
        BulletShot    = Knit.CreateSignal(),
        PlayGunAnim   = Knit.CreateSignal(),
    },
    Bullets           = {},

    CharService       = nil,
    CAS               = nil,

    GunAnim           = _G.Signal.new()
})

local GunRequest      = require(RepStorage.Remotes.GunRequest):Server()
local HitDetection    = require(RepStorage.Remotes.HitDetection):Server()

-- [[ funcs ]] --

-- Increments ammo
local function incrementAmmo(gun : Tool, amount : number?) : ()
    gun:SetAttribute("Ammo", gun:GetAttribute("Ammo") + (amount or -1))
end

-- On knit init completion
function GunService:KnitInit() : ()
    self.CAS = _G.Knit.GetService("ChargedActionService")
    self.CharService = _G.Knit.GetService("CharService")
    self.CombatService = _G.Knit.GetService("CombatService")
    self.CommsService = _G.Knit.GetService("CommsService")
    self.TeamService = _G.Knit.GetService("TeamService")

    -- Aiming
    self.Client.AimToggle:Connect(function(plr : Player, toggle : boolean)
        -- Only allow aiming while a ranged tool is equipped
        local Gun = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
        if toggle and (not Gun or Gun:GetAttribute("Class") ~= "Ranged") then return end

        -- Gets character class + gun class then toggles aiming
        local CharClass = _G.Knit.GetService("CharService"):GetCharacterClass(plr.Character)
        if not CharClass then return end
        local GunClass = CharClass.GunClass
        if not GunClass then return end
        GunClass:ToggleAiming(toggle)
    end)

    -- Firing and whatnot
    GunRequest:On(function(player : Player, action : string, ...)
        if player.Team ~= game.Teams.Squadmates then return end
        local Character = player.Character or player.CharacterAdded:Wait()
        if not Character then return end
        local Gun = Character:FindFirstChildOfClass("Tool")
        if not Gun or Gun:GetAttribute("Class") ~= "Ranged" then return end

        local CharClass = self.CharService:GetCharacterClass(Character)
        local GunClass = CharClass.GunClass

        local ItemInfo = require(S2:FindFirstChild(Gun.Name, true).Configuration.ItemInfo)
        local isSuppressed = Gun:FindFirstChild("_suppressor") ~= nil

        local Attributes = {...}

        if action == "FIRE" and (not Character:GetAttribute("isReloading") or ItemInfo.repeatReloadTillFull == true) then
            -- Firing during a shell-by-shell reload interrupts it
            if Character:GetAttribute("isReloading") then
                Character:SetAttribute("isReloading", false)
            end

            -- Verifies that player is close enough to origin
            local DistanceFromOrigin = (Character.Head.CFrame.Position - Attributes[1]).Magnitude
            if DistanceFromOrigin < 6 then
                -- Registers one bullet per ShotsPerFire (defaults to 1); each gets
                -- its own name and spread angle so pellets fly in their own directions
                local ID = Character:GetAttribute("ID")
                local ShotsPerFire = ItemInfo.ShotsPerFire or 1

                for i = 1, ShotsPerFire do
                    local BN = `{ID}_{Attributes[4]}_{i}`
                    local ShotAngle = ShotsPerFire > 1 and Rand:NextNumber(-math.abs(Attributes[3]), math.abs(Attributes[3])) or Attributes[3]
                    self.Bullets[BN] = {Shooter = Character, Origin = Attributes[1], Direction = Attributes[2], AmmoType = ItemInfo.AmmoType, Gun = ItemInfo.Name, Tier = ItemInfo.Tier, Damage = ItemInfo.Damage, Angle = ShotAngle, BulletName = BN, ShotCount = `{Attributes[4]}_{i}`, Tool = Gun, SkipEffects = i > 1}

                    self.Client.BulletShot:FireAll(self.Bullets[BN])
                end

                if Gun:GetAttribute("Ammo") > 0 then
                    incrementAmmo(Gun)
                end

                self.GunAnim:Fire(Character, "Fire")

                -- Noise
                CharClass.NoiseClass:SetNoise("Gun", ItemInfo.Noise * (isSuppressed and 1 - isSuppressed:GetAttribute("NoiseReduction") or 1), true)

                -- Guns with playEquipAfterFire replay their equip animation a third-second after firing
                if ItemInfo.playEquipAfterFire == true then
                    task.delay(1/3, function()
                        self.GunAnim:Fire(Character, "GunEquip")
                        self.Client.PlayGunAnim:Fire(player, "GunEquip")
                    end)
                end
            end
        elseif action == "RELOAD" then
            -- Ignores reload requests while one is already running; concurrent
            -- reloads race the shared reserve count and can drive it negative
            if Character:GetAttribute("isReloading") then return end

            local DesiredAmmo = Character:GetAttribute("Ammo_"..ItemInfo.AmmoType)
            if DesiredAmmo > 0 and Gun:GetAttribute("Ammo") < ItemInfo.Mag then
                Character:SetAttribute("isReloading", true)

                -- Plays the reload sound server-side so every other client hears it
                -- positionally; the shooter's own client strips the tool's children
                -- (see Viewmodel) and plays the sound on the viewmodel instead
                local Handle = Gun:FindFirstChild("Handle")
                local ReloadSound = Handle and Handle:FindFirstChild("Reload")
                if ReloadSound and ReloadSound:IsA("Sound") then
                    ReloadSound:Stop()
                    ReloadSound:Play()
                end

                if ItemInfo.repeatReloadTillFull == true then
                    -- Loads one round per ReloadLength until the mag is full or ammo runs out
                    local Completed = true
                    local Rounds = 0

                    while Gun:GetAttribute("Ammo") < ItemInfo.Mag and Character:GetAttribute("Ammo_"..ItemInfo.AmmoType) > 0 do
                        Rounds += 1
                        self.GunAnim:Fire(Character, "Reload")

                        -- The first round's reload anim/sound is driven by the isReloading
                        -- attribute change; later rounds replay them through PlayGunAnim
                        if Rounds > 1 then
                            self.Client.PlayGunAnim:Fire(player, "Reload")

                            if ReloadSound and ReloadSound:IsA("Sound") then
                                ReloadSound:Stop()
                                ReloadSound:Play()
                            end
                        end

                        -- Failing the sanity check (e.g. the player fired to interrupt
                        -- the reload, clearing isReloading) cancels the round load
                        local reloadSuccess = self.CAS:ChargedAction(Character, "Reload", ItemInfo.ReloadLength, function()
                            return Character:GetAttribute("isReloading") == true
                        end)

                        if reloadSuccess == true then
                            Character:SetAttribute("Ammo_"..ItemInfo.AmmoType, Character:GetAttribute("Ammo_"..ItemInfo.AmmoType) - 1)
                            incrementAmmo(Gun, 1)
                        else
                            self.GunAnim:Fire(Character, "Reload", true)
                            Completed = false
                            break
                        end
                    end

                    Character:SetAttribute("isReloading", false)

                    -- Mirrors the shooter stopping the sound on their viewmodel
                    if ReloadSound and ReloadSound:IsA("Sound") then
                        ReloadSound:Stop()
                    end

                    if Completed then
                        self.GunAnim:Fire(Character, "GunEquip")
                        self.Client.PlayGunAnim:Fire(player, "GunEquip")
                    end
                else
                    self.GunAnim:Fire(Character, "Reload")

                    local reloadSuccess = self.CAS:ChargedAction(Character, "Reload", ItemInfo.ReloadLength, function()
                        return true
                    end)

                    Character:SetAttribute("isReloading", false)

                    -- Mirrors the shooter stopping the sound on their viewmodel
                    if ReloadSound and ReloadSound:IsA("Sound") then
                        ReloadSound:Stop()
                    end

                    if reloadSuccess == true then
                        local IdealAmmo = ItemInfo.Mag - Gun:GetAttribute("Ammo")
                        local GivenAmmo = math.min(Character:GetAttribute("Ammo_"..ItemInfo.AmmoType), IdealAmmo)

                        Character:SetAttribute("Ammo_"..ItemInfo.AmmoType, Character:GetAttribute("Ammo_"..ItemInfo.AmmoType) - GivenAmmo)
                        incrementAmmo(Gun, GivenAmmo)
                    else
                        self.GunAnim:Fire(Character, "Reload", true)
                    end
                end
            end
        end
    end)

    -- Hit detection
    HitDetection:On(function(player : Player, info : {})
        if player.Team == game.Teams.Spectators then return end -- player must be in-game
        local Character = player.Character or player.CharacterAdded:Wait()
        if not self.Bullets[info.BulletID] then return end -- bullet must be registered
        local Info = self.Bullets[info.BulletID]
        if Info.Shooter ~= Character then return end -- only perform hit detection on own bullets

        -- Checks if possible to reach point via shot
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = {game.Workspace:WaitForChild("Characters")}

        local DistanceFromHit = (info.Position - Info.Origin).Magnitude
        local Raycast = game.Workspace:Raycast(Info.Origin, (info.Position - Info.Origin).Unit * DistanceFromHit, RayParams)
        if Raycast and Raycast.Instance and Raycast.Instance ~= info.HitInstance then return end

        -- Target exists and is valid, detect if on same team
        if info.HitCharacter and info.HitCharacter.Parent == game.Workspace.Characters then
            if not self.TeamService:AreTeammates(Character, info.HitCharacter) then
                self.CombatService:Damage(Character, info.HitCharacter, Info.Damage, string.upper(Info.Gun), "DEFAULT", true, info.HitInstance)
            end
        else
            if not info.HitInstance:FindFirstAncestor("Glass") then
                if info.HitInstance.Transparency < 1 then
                    _G.Knit.GetService("VFXService"):GlobalVFX("BulletHole", "BulletHole", info.Position, info.Position, info.Normal, info.HitInstance)
                end
            end
        end

        self.Bullets[info.BulletID] = nil
    end)

    -- Gets live gun's attachments
    function GunService:GetAttachments(gun : Tool)
        assert(gun:IsA("Tool"), "Gun reference must be a Tool")
        local Attachments = {}

        for _, folder in RepStorage.PlayerRep.Attachments:GetChildren() do
            local Att = gun:GetAttribute(folder.Name)
            if Att then
                Attachments[folder.Name] = Att
            end
        end

        return Attachments
    end
end

return GunService