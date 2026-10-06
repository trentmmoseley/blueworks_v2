return function(player : Player)
    local DisplayName = player.DisplayName
    local Name = player.Name

    -- Simulate some processing (replace with actual logic if needed)
    return DisplayName, Name ~= DisplayName and Name or nil
end