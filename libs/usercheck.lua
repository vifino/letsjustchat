local function strrandom(length)
	local str = ""
	for i = 1, length do
		str = str..string.char(math.random(32, 126))
	end
	return str
end

return {
	gen = function(len)
		-- TODO: Make better generator.
		return strrandom(length)
	end,
	valid = function(str)
		-- TODO: Allow some unicode or something.
		return not str:match("%W")
	end
}
