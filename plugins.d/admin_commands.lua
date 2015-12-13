-- Admin commands, like bcast and stuff.

-- Basically just msg, but with variable chan.
rpc.command("attention:bcast", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	-- TODO: Add whitelist settings thing.
	if clientid:gsub(":(%d+)", "") == "127.0.0.1" then
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
		logger.log("bcast", logger.important, "Unauthenticated user tried to use bcast!")
		rpc.call("send", chan, name, "error * You are not authorized to use the local broadcast command.")
	end
end)

-- Pretty much bcast with just one person receiving it.
rpc.command("attention:send", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	-- TODO: Add whitelist settings thing.
	if clientid:gsub(":(%d+)", "") == "127.0.0.1" then
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
		logger.log("bcast", logger.important, "Unauthenticated user tried to use send!")
		rpc.call("send", chan, name, "error * You are not authorized to use the send command.")
	end
end)

-- Lua eval.
rpc.command("attention:lua", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	if clientid:gsub(":(%d+)", "") == "127.0.0.1" then
		function print(...)
			for k, v in pairs({...}) do
				rpc.call("send", chan, name, "msg *lua* "..tostring(v))
			end
		end
		local f, err = loadstring("return "..arg)
		if err then
			f, err = loadstring(arg)
			if err then
				rpc.call("send", chan, name, "msg *lua* Error: "..err)
				return
			end
		end
		local suc, res = pcall(f)
		if suc then
			rpc.call("send", chan, name, "msg *lua* -> "..tostring(res))
		else
			rpc.call("send", chan, name, "msg *lua* Error: "..res)
		end
	else
		logger.log("bcast", logger.important, "Unauthenticated user tried to use lua!")
		rpc.call("send", chan, name, "error * You are not authorized to use the lua command.")
	end
end)

-- Same as above, but print() and return outputs to the channel instead.
rpc.command("attention:glua", function(chan, name, arg)
	local clientid = (kvstore.get("users:"..chan) or {})[name]
	if clientid:gsub(":(%d+)", "") == "127.0.0.1" then
		function print(...)
			for k, v in pairs({...}) do
				rpc.call("broadcast", chan, "msg *lua* "..tostring(v))
			end
		end
		local f, err = loadstring("return "..arg)
		if err then
			f, err = loadstring(arg)
			if err then
				rpc.call("broadcast", chan, name, "msg *lua* Error: "..err)
				return
			end
		end
		local suc, res = pcall(f)
		if suc then
			rpc.call("broadcast", chan, "msg *lua* -> "..tostring(res))
		else
			rpc.call("broadcast", chan, "msg *lua* Error: "..res)
		end
	else
		logger.log("bcast", logger.important, "Unauthenticated user tried to use glua!")
		rpc.call("send", chan, name, "error * You are not authorized to use the glua command.")
	end
end)
