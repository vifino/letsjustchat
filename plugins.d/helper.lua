-- Small helper/aliases.

rpc.command("attention:me", function(chan, name, arg)
	rpc.call("send", chan, name, "action " .. name .. " " .. arg)
end)
