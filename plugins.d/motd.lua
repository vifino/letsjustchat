-- Displays MOTD
if settings.motd then
	event.handle("user:join", function(chan, name)
		rpc.call("send", chan, name, "info *motd* "..motd)
	end, {
		motd = settings.motd
	})
	rpc.command("attention:motd", function(chan, name)
		rpc.call("send", chan, name, "info *motd* "..motd)
	end, {
		motd = settings.motd
	})
end
