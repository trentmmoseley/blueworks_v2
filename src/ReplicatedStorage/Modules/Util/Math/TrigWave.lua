local Funcs = {
    ["sin"]			= math.sin,
    ["cos"]			= math.cos,
    ["tan"]			= math.tan,
    ["asin"]        = math.asin,
    ["acos"]        = math.acos,
    ["atan"]        = math.atan,
}

return function(func, a, b, x, c, d) -- wave type, amplitude, period, point, x-offset, y-offset
	return a * Funcs[func](((2 * math.pi) / b) * x + c) + d
end