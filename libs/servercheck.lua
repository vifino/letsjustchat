local function strrandom(length)
	local str = ""
	for i = 1, length do
		str = str..string.char(math.random(32, 126))
	end
	return str
end

return {
	gen_str = strrandom,
	user_valid = function(str)
		-- TODO: Allow some unicode or something.

		-- Check based on pattern.
		local is_invalid = not str:match("^([%w_-]+)$")

		-- Check if it is the restricted *, just in case.
		is_invalid = is_invalid or str == "*"

		return not is_invalid
	end
}
