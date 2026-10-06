return function(lerp, dt)
	return lerp * (60 / dt ^ -1)
end