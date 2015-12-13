local function strrandom(length)
	local str = ""
	for i = 1, length do
		str = str..string.char(math.random(32, 126))
	end
	return str
end

return {
	gen_str = function(len)
		-- TODO: Make better generator.
		return strrandom(length)
	end,
	user_valid = function(str)
		-- TODO: Allow some unicode or something.

		-- Check based on pattern.
		local is_invalid = str:match("%W")

		-- Check if it is the restricted *, just in case.
		is_invalid = is_invalid or str == "*"

		return not is_invalid
	end
}
