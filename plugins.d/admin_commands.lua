-- Admin commands, like bcast and stuff.

-- Basically just msg, but with variable chan.
rpc.command("attention:bcast", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	-- TODO: Add whitelist settings thing.
	local ip = clientid:gsub(":(%d+)$", "")
	if admins[ip] then
		arg:gsub("^(.-) (.+)$", function(target_chan, bcast_args)
			local target_chan = target_chan
			if target_chan == "-" then
				target_chan = chan
			end
			print("Broadcast to "..target_chan..": "..bcast_args)
			rpc.call("broadcast", target_chan, bcast_args)
		end)
		--rpc.call("broadcast", chan, "msg "..msg_arg)
	else
		logger.log("Chat", logger.important, "Unauthenticated user "..name.." tried to use bcast!")
		rpc.call("send", chan, name, "error * You are not authorized to use the local broadcast command.")
	end
end, {
	admins = settings.admins,
})

-- Pretty much bcast with just one person receiving it.
rpc.command("attention:send", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	-- TODO: Add whitelist settings thing.
	local ip = clientid:gsub(":(%d+)$", "")
	if admins[ip] then
		arg:gsub("^(.-) (.-) (.+)$", function(target_chan, user, send_args)
			local target_chan = target_chan
			if target_chan == "-" then
				target_chan = chan
			end
			print("Sending to "..user.." of "..target_chan..": "..send_args)
			rpc.call("send", target_chan, user, send_args)
		end)
		--rpc.call("broadcast", chan, "msg "..msg_arg)
	else
		logger.log("Chat", logger.important, "Unauthenticated user "..name.." tried to use send!")
		rpc.call("send", chan, name, "error * You are not authorized to use the send command.")
	end
end, {
	admins = settings.admins,
})

-- Lua eval.
rpc.command("attention:lua", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	local ip = clientid:gsub(":(%d+)$", "")
	if admins[ip] then
		function print(...)
			for k, v in pairs({...}) do
				rpc.call("send", chan, name, "msg *lua* "..tostring(v))
			end
		end
		local f, err = loadstring("return "..arg)
		if err then
			f, err = loadstring(arg)
			if err then
				rpc.call("send", chan, name, "error *lua* Error: "..err)
				return
			end
		end
		local suc, res = pcall(f)
		if suc then
			rpc.call("send", chan, name, "msg *lua* -> "..tostring(res))
		else
			rpc.call("send", chan, name, "error *lua* Error: "..res)
		end
	else
		logger.log("Chat", logger.important, "Unauthenticated user "..name.." tried to use lua!")
		rpc.call("send", chan, name, "error * You are not authorized to use the lua command.")
	end
end, {
	admins = settings.admins,
})

-- Same as above, but print() and return outputs to the channel instead.
rpc.command("attention:glua", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	local ip = clientid:gsub(":(%d+)$", "")
	if admins[ip] then
		function print(...)
			for k, v in pairs({...}) do
				rpc.call("broadcast", chan, "msg *lua* "..tostring(v))
			end
		end
		local f, err = loadstring("return "..arg)
		if err then
			f, err = loadstring(arg)
			if err then
				rpc.call("broadcast", chan, name, "error *lua* Error: "..err)
				return
			end
		end
		local suc, res = pcall(f)
		if suc then
			if res then
				rpc.call("broadcast", chan, "msg *lua* -> "..tostring(res))
			end
		else
			rpc.call("broadcast", chan, "error *lua* Error: "..res)
		end
	else
		logger.log("Chat", logger.important, "Unauthenticated user "..name.." tried to use glua!")
		rpc.call("send", chan, name, "error * You are not authorized to use the glua command.")
	end
end, {
	admins = settings.admins,
})
