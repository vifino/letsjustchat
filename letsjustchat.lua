#!/usr/bin/env carbon

-- Lets just chat!
event = require("libs.event")
logger = require("libs.logger")
loader = require("libs.loader")

logger.log("Main", logger.normal, "Loading Init files...")
local loaded, loadtime = loader.load("init.d/*")
logger.log("Main", logger.normal, "Loaded "..tostring(loaded).." Init Files. Took "..tostring(loadtime).."s.")

-- Chat interface
srv.GET("/", mw.new(function()
	-- TODO: Replace stub
	content("Go away. (For now.)")
end))

-- Chat logic
srv.GET("/ws", mw.ws(function()
	-- Small variables we use later.
	local deflen = 10
	local maxlen = 30

	local maxmsglen = 1024

	local disallowed = {
		["join"] = true,
		["left"] = true,
		["error"] = true,
		["info"] = true,
	}
	-- Require libraries we use.
	event = require("libs.event")
	rpc = require("libs.multirpc")
	server = server or require("libs.servercheck")

	local clientid = context.ClientIP() -- Use simply the client IP + Port as the ID.

	-- TODO: Actual chan logic.
	local name = query("name") or server.gen_str(deflen)

	if #name > maxlen then -- Exceeds maximum name length
		ws.send(ws.TextMessage, "error * Name exceeds max length.")
		return
	end

	if not server.user_valid(name) then
		ws.send(ws.TextMessage, "error * Name contains invalid characters and/or is restricted.")
		return
	end

	local chan = query("chan") or "lobby"

	-- Fail if username is already existing.
	local started = kvstore.get("started:"..chan)
	if not started then
		rpc.call("log.normal", "Chat", "Looks like "..chan.." is getting some activity!")
		event.handle("chan:"..chan, function(callee, action, name, clientid, msg)
			usercount = usercount or 0
			db = db or {}

			action = action:lower()

			local function pub(a, nme, m)
				for user, userid in pairs(db) do
					if user ~= name then
						local wsok = kvstore.get("client:"..userid)
						wsok.WriteMessage(1, convert.stringtocharslice(a..(nme and (" " .. nme) or "")..(m and (" " .. m) or ""))) -- Dark magic
					end
				end
			end

			if callee == "server" then
				-- Reassigned:
				--   action = selector/name
				--   name, clientid, msg = args
				if action == "*" then -- Broadcast.
					pub(name, clientid, msg) -- These are actually different things then..
				else -- Target name
					local cid = db[action]
					if cid then
						local wsok = kvstore.get("client:"..cid)
						wsok.WriteMessage(1, convert.stringtocharslice(name..(clientid and (" " .. clientid) or "")..(msg and (" " .. msg) or ""))) -- Dark magic
					end
				end
			else
				if action == "join" then
					db[name] = clientid
					usercount = usercount + 1
					kvstore.set("users:"..channel, db)
					pub("join", name)
					event.fire("user:join", channel, name, db)
				elseif action == "left" then
					db[name] = nil
					usercount = usercount - 1
					kvstore.set("users:"..channel, db)
					event.fire("user:left", channel, name, db)
					pub("left", name)
					if usercount == 0 then -- Teardown
						kvstore.del("users:"..channel)
						rpc.call("log.normal", "Chat", "Channel "..channel.." seems to have lost it's userbase... :(")
						return false
					end
				elseif action == "!" then -- ! = ATTENTION!
					msg:gsub("^(%w+) (.*)", function(rpc_cmd, arguments)
						rpc.call("attention:"..rpc_cmd, channel, name, arguments)
					end)
				else
					pub(action, name, msg)
				end
			end
		end, {
			["channel"] = chan
		})
		kvstore.set("started:"..chan, true)
	end

	if (kvstore.get("users:"..chan) or {})[name] then
		ws.send(ws.TextMessage, "User already existing.")
		return
	end

	-- Fire new user event
	kvstore.set("client:"..clientid, ws.con)
	event.fire("chan:"..chan, "client", "join", name, clientid)

	local matchfunc = function(cmd, args)
		if cmd and cmd ~= "" then
			if disallowed[cmd] then
				ws.send(ws.TextMessage, "error * Disallowed command.")
			else
				event.fire("chan:"..chan, "client", cmd, name, clientid, args)
			end
		end
	end

	-- Chat loop
	while true do
		local p, msg, err = ws.read()
		if err then
			break
		end

		if msg then
			if #msg < maxmsglen then
				local matched = false
				msg:gsub("^([%w!_-]-) (.-)$", function(cmd, args)
					matched = true
					matchfunc(cmd, args)
				end)
				if not matched then
					msg:gsub("^([%w!_-]-)$", function(cmd)
						matchfunc(cmd)
					end)
				end
			else
				ws.send(ws.TextMessage, "error * Command exceeded maximum length of "..tostring(maxmsglen)..".")
			end
		end
		os.sleep(0.2)
	end

	-- Finalize
	event.fire("chan:"..chan, "client", "left", chan, clientid)
end))
