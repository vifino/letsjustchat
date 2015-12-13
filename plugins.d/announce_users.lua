-- Announce users on connect.

-- List user names.
event.handle("user:join", function(chan, name, db)
	local userstr = ""
	for user, cid in pairs(db) do
		userstr = userstr..user.." "
	end
	
	rpc.call("send", chan, name, "msg * Currently connected users: "..userstr)
end)
