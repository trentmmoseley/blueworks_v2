return function(t: {}, path: string)
	local parts = string.split(path, ".")
	local current = t

	if #parts > 1 then
		for i = 1, #parts - 1 do
			current = current[parts[i]]

			if not current then
				warn("Invalid path given", path)
				return nil
			end
		end
	end

	return current[parts[#parts]]
end