-- Gets information about the client

rpc.command("attention:ip", function(chan, name, arg, db)
	rpc.call("send", chan, name, "info *ip* Your IP is " .. db[name]:gsub(":(%d+)$", ""))
end)
