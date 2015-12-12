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
end))

-- Chat logic
srv.GET("/ws", mw.ws(function()
	-- Small variables we use later.
	local deflen = 10
	local maxlen = 30
	-- Require libraries we use.
	event = require("libs.event")
	rpc = require("libs.multirpc")
	user = user or require("libs.usercheck")

	local clientid = context.ClientIP() -- Use simply the client IP + Port as the ID.

	-- TODO: Actual chan logic.
	local name = query("name") or user.gen(deflen)

	if #name > maxlen then -- Exceeds maximum name length
		ws.send(ws.TextMessage, "Name exceeds max length.")
		return
	end

	if not user.valid(name) then
		ws.send(ws.TextMessage, "Name contains invalid characters.")
		return
	end

	local chan = query("chan") or "lobby"

	-- Fail if username is already existing.
	local started = kvstore.get("started:"..chan)
	if not started then
		rpc.call("log.normal", "Chat", "Looks like "..chan.." is getting some activity!")
		event.handle("chan:"..chan, function(action, name, clientid, msg)
			usercount = usercount or 0
			db = db or {}

			local function pub(a, nme, m)
				for user, userid in pairs(db) do
					if user ~= name then
						local wsok = kvstore.get("client:"..userid)
						wsok.WriteMessage(1, convert.stringtocharslice(a..(nme and (" " .. nme) or "")..(m and (" " .. m) or ""))) -- Dark magic
					end
				end
			end

			if action == "join" then
				db[name] = clientid
				usercount = usercount + 1
				kvstore.set("users:"..channel, db)
				pub("join", name)
			elseif action == "left" then
				db[name] = nil
				usercount = usercount - 1
				kvstore.set("users:"..channel, db)
				pub("left", name)
				if usercount == 0 then -- Teardown
					kvstore.del("users:"..channel)
					rpc.call("log.normal", "Chat", "Channel "..channel.." seems to have lost it's userbase... :(")
					return false
				end
			else
				pub(action, name, msg)
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
	event.fire("chan:"..chan, "join", name, clientid)

	local matchfunc = function(cmd, args)
		if cmd == "join" or cmd == "left" then
			ws.send(ws.TextMessage, "error Disallowed command.")
		else
			event.fire("chan:"..chan, cmd, name, clientid, args)
		end
	end

	-- Chat loop
	while true do
		local p, msg, err = ws.read()
		if err then
			break
		end

		if msg then
			local matched = false
			msg:gsub("^(%w-) (.-)$", function(cmd, args)
				matched = true
				matchfunc(cmd, args)
			end)
			if not matched then
				msg:gsub("^(%w-)$", function(cmd)
					matchfunc(cmd)
				end)
			end
		end
		os.sleep(0.2)
	end

	-- Finalize
	event.fire("chan:"..chan, "left", chan, clientid)
end))
