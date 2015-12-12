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
	-- TODO: Replace
	local clientid = context.ClientIP() -- Use simply the client IP + Port as the ID.
	event = require("libs.event")

	-- TODO: Actual chan logic.
	local name = query("name") or ("user"..clientid)
	local chan = query("chan") or "lobby"

	-- Fail if username is already existing.
	local started = kvstore.get("started:"..chan)
	if not started then
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
					print("Teardown")
					kvstore.delete("users:"..channel)
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
		content("", 200)
		return
	end

	-- Fire new user event
	kvstore.set("client:"..clientid, ws.con)
	event.fire("chan:"..chan, "join", name, clientid)

	-- Chat loop
	while true do
		local p, msg, err = ws.read()
		if err then
			break
		end
		if msg then
			(msg.." "):gsub("^(.-) (.-)$", function(cmd, args)
				if cmd ~= "join" and cmd ~= "left" then
					event.fire("chan:"..chan, "msg", name, clientid, args)
				else
					ws.send(ws.TextMessage, "error Disallowed command.")
				end
			end)
		end
		os.sleep(0.2)
	end

	-- Finalize
	event.fire("chan:"..chan, "left", chan, clientid)
end))
