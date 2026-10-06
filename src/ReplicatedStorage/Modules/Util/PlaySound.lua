local Debris = game:GetService("Debris")
return function(soundid : number | string, soundname : string, parent : Instance?, location : Vector3?, volume : number, speed : number) : Sound?
    local NewSound = Instance.new("Sound")
	NewSound.SoundId = typeof(soundid) == "string" and soundid or "rbxassetid://"..tostring(soundid)
	NewSound.Volume = volume
	NewSound.PlaybackSpeed = speed

	if soundname ~= nil then
		NewSound.Name = soundname
	end
	
	task.spawn(function()
		-- Sees if the parent is defined, and sets the sound's parent to a new and random part if it isn't
		local Temp = nil
		if parent then
			NewSound.Parent = parent
		else
			Temp = Instance.new("Part")
            Temp.Parent = game.Workspace
			Temp.Name = "Temp"
			Temp.Anchored = true
			Temp.CanCollide = false
			Temp.CanQuery = false
			Temp.Transparency = 1
			Temp.Position = location
			NewSound.Parent = Temp
		end
		
		NewSound:Play()
	end)
	
	NewSound.Ended:Connect(function()
		if NewSound.Parent.Name == "Temp" then
			NewSound.Parent:Destroy()
		else
			NewSound:Destroy()
		end
	end)
	
	return NewSound
end