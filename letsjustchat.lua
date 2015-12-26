#!/usr/bin/env carbon

-- Lets just chat!
event = require("libs.event")
logger = require("libs.logger")
loader = require("libs.loader")

-- Settings
settings = require("settings")

logger.log("Main", logger.normal, "Loading Init files...")
local loaded, loadtime = loader.load("init.d/*")
logger.log("Main", logger.normal, "Loaded "..tostring(loaded).." Init Files. Took "..tostring(loadtime).."s.")

-- Chat interface
local f = io.open("client/index.html")
local web_interface = f:read("*a")
f:close()
srv.GET("/", mw.echo(web_interface))

-- Chat logic
srv.GET("/ws", mw.ws(function()
	-- Small variables we use later.
	local deflen = 10
	local minlen = 1
	local maxlen = 30

	local maxmsglen = 1024

	local disallowed = {
		["join"] = true,
		["left"] = true,
		["info"] = true,
		["warn"] = true,
		["error"] = true,
	}

	local clientid = context.ClientIP() -- Use simply the client IP + Port as the ID.
	local ip = clientid:gsub(":(%d+)$", "")

	local connected_from_ip = tonumber(kvstore.get("concount:"..ip))
	if not connected_from_ip then
		kvstore.set("concount:"..ip, 1)
	elseif connected_from_ip == max_cons -1 then
		ws.send(ws.TextMessage, "warn * Connection limit reached. Any further connections will be disconnected. (Max Connections: "..tostring(max_cons)..")")
		kvstore.inc("concount:"..ip, 1)
	elseif connected_from_ip == max_cons then
		ws.send(ws.TextMessage, "error * Too many active connections. (Max Connection count exceeded: "..tostring(max_cons)..")")
		return
	else
		kvstore.inc("concount:"..ip, 1)
	end

	-- Require libraries we use.
	event = require("libs.event")
	rpc = require("libs.multirpc")
	server = server or require("libs.servercheck")

	-- TODO: Actual chan logic.
	local name = query("name")

	if name == nil or name == "" then
		ws.send(ws.TextMessage, "error * Please choose a name by connecting to the WebSocket with the query argument name set to your preferred name.")
		kvstore.dec("concount:"..ip, 1)
		return
	elseif #name > maxlen then -- Exceeds maximum name length
		ws.send(ws.TextMessage, "error * Name exceeds max length. ("..tostring(maxlen)..")")
		kvstore.dec("concount:"..ip, 1)
		return
	end

	if not server.user_valid(name) then
		ws.send(ws.TextMessage, "error * Name contains invalid characters and/or is restricted.")
		kvstore.dec("concount:"..ip, 1)
		return
	end

	local chan = query("chan") or "lobby"

	-- Fail if username is already existing.
	local started = kvstore.get("started:"..chan)
	if not started then
		rpc.call("log.normal", "Chat", "Looks like "..chan.." is getting some activity!")
		event.handle("chan:"..chan, function(callee, action, name, clientid, msg)
			usercount = usercount or 0

			-- DB Structure:
			-- name - clientid
			db = db or {}

			action = action:lower()

			local function pub(a, nme, m)
				for user, userid in pairs(db) do
					if user ~= nme:lower() then
						local wsok = kvstore.get("client:"..userid)
						if wsok then
							wsok.WriteMessage(1, convert.stringtocharslice(a..(nme and (" " .. nme) or "")..(m and (" " .. m) or ""))) -- Dark magic
						else
							event.fire("client:"..channel, "client", "left", name, clientid)
						end
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
						if wsok then
							wsok.WriteMessage(1, convert.stringtocharslice(name..(clientid and (" " .. clientid) or "")..(msg and (" " .. msg) or ""))) -- Dark magic
						else
							event.fire("client:"..channel, "client", "left", name, clientid)
						end
					end
				end
			else
				if action == "join" then
					db[name:lower()] = clientid
					usercount = usercount + 1
					kvstore.set("users:"..channel, db)
					pub("join", name)
					event.fire("user:join", channel, name, db)
				elseif action == "left" then
					db[name:lower()] = nil
					usercount = usercount - 1
					kvstore.set("users:"..channel, db)
					event.fire("user:left", channel, name, db)
					pub("left", name)
					if usercount == 0 then -- Teardown
						kvstore.del("users:"..channel)
						kvstore.del("started:"..channel)
						rpc.call("log.normal", "Chat", "Channel "..channel.." seems to have lost it's userbase... :(")
						return false
					end
				elseif action == "!" then -- ! = ATTENTION!
					(msg.." "):gsub("^(%w+) (.*)", function(rpc_cmd, arguments)
						rpc.call("attention:"..rpc_cmd:lower(), channel, name, arguments, db)
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

	local other_user_alias = kvstore.get("alias:"..name:lower())
	if other_user_alias then
		local other_user = (kvstore.get("users:"..chan) or {})[name:lower()]
		if other_user:gsub(":(%d+)$", "") == ip then
			-- Ghosting other user.
			local wsok = kvstore.get("client:"..other_user)
			wsok.WriteMessage(1, convert.stringtocharslice("error * You got ghosted!"))
			wsok.Close()
			kvstore.del("client:"..other_user)
			ws.send(ws.TextMessage, "info * Ghosted connection with same name as current one.")
			os.sleep(1) -- To further limit spam and stuff.
		else
			ws.send(ws.TextMessage, "error * User already existing.")
			kvstore.dec("concount:"..ip, 1)
			return
		end
	end

	-- Fire new user event
	kvstore.set("client:"..clientid, ws.con)
	kvstore.set("alias:"..name:lower(), name)
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
		os.sleep(1)
	end

	-- Finalize
	kvstore.del("client:"..clientid)
	kvstore.del("alias:"..name:lower())
	kvstore.dec("concount:"..clientid:gsub(":(%d+)$", ""), 1)
	event.fire("chan:"..chan, "client", "left", name, clientid)
end, {
	max_cons = settings.max_connections or 5,
}))
