-- Announce users on connect.

-- List user names.
event.handle("user:join", function(chan, name, db)
	local userstr = ""
	for user, cid in pairs(db) do
		userstr = userstr..kvstore.get("alias:"..user).." "
	end

	rpc.call("send", chan, name, "info *list* Currently connected users: "..userstr)
end)
rpc.command("attention:list", function(chan, name, args, db)
	local userstr = ""
	for user, cid in pairs(db) do
		userstr = userstr..kvstore.get("alias:"..user).." "
	end

	rpc.call("send", chan, name, "info *list* Currently connected users: "..userstr)
end)
