return function(t: {}, path: string, value: any, condition: ({}) -> ()?)
	local parts = string.split(path, ".")
	local current = t

	if #parts > 1 then
		for i = 1, #parts - 1 do
			current = current[parts[i]]

			if not current then
				warn("Invalid path received", path)
				return false
			end
		end
	end

	if condition and not condition(current[parts[#parts]]) then
		return false
	end

	current[parts[#parts]] = value
	return true
end
