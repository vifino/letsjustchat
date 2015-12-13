-- Helpers, mainly for plugins.

rpc.command("broadcast", function(chan, msg) -- Just basic broadcast.
	event.fire("chan:"..chan, "server", "*", msg)
end)

rpc.command("send", function(chan, name, msg) -- Similar to broadcast, except targeting a user.
	event.fire("chan:"..chan, "server", name, msg)
end)
