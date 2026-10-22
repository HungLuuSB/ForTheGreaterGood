--!strict
-- Cheat commands as chat text (S-102, net.md "Cheat commands"): the client
-- parses what the player typed into a CHEAT command, and turns the server's
-- CHEAT_RESULT answer into a chat line. Shared so the client keeps no copy.
--
--   give <unitId> [count] [team] at <x,z>
--   res <supply|power|all> <amount|max> [team]
--   income <supply|power|all> <amount> [team]      (0 clears)
--   instabuild on|off
--   reveal on|off [team]
--   god on|off
--   kill selected | kill <team> | kill at <x,z> <radius>
--   speed <0.25-8>
--   ai <team> pause|resume
--
-- A leading "/" or "/cheat" is ignored. Team 0 (or none) is the sender's.
-- Positions are world studs.

local Schema = require("./Schema")

local CheatText = {}

local OP = Schema.CheatOp
local R = Schema.CheatResult

local OP_NAMES = { "give", "res", "income", "instabuild", "reveal", "god", "kill", "speed", "ai" }
local RESOURCES = { supply = Schema.CheatResource.SUPPLY, power = Schema.CheatResource.POWER, all = Schema.CheatResource.ALL }
local MESSAGES: { [number]: string } = {
	[R.CHEATS_OFF] = "cheats are off in this match",
	[R.BAD_ARGS] = "bad arguments",
	[R.NO_TEAM] = "no player on that team",
	[R.NO_ROOM] = "no room there",
	[R.NOT_OFFLINE] = "only offline or in Studio",
	[R.NO_AI] = "no AI on that team",
	[R.NO_MAP] = "no map",
}

type Defs = { units: { [string]: { index: number } } }

local function cheat(op: number, fields: { [string]: any }?, unitIds: { number }?): Schema.Command
	local cmd: any = { cmdType = Schema.CmdType.CHEAT, flags = 0, unitIds = unitIds or {}, cheatOp = op, cheatArg = 0, cheatTeam = 0 }
	for k, v in fields or {} do
		cmd[k] = v
	end
	return cmd
end

local function int(s: string?): number?
	local n = tonumber(s)
	if n == nil or n ~= math.floor(n) then
		return nil
	end
	return n
end

local function team(s: string?): (number?, string?)
	if s == nil then
		return 0, nil
	end
	local n = int(s)
	if n == nil or n < 0 or n > Schema.MAX_TEAMS then
		return nil, `team must be 1..{Schema.MAX_TEAMS}`
	end
	return n, nil
end

local function onOff(s: string?): number?
	if s == "on" then
		return 1
	elseif s == "off" then
		return 0
	end
	return nil
end

-- "x,z" at words[i] (or "x," "z" / "x" "," "z" across words): x, z, and the next word's index.
local function point(words: { string }, i: number): (number?, number?, number)
	local rest = table.concat(words, " ", i)
	local x, z, used = string.match(rest, "^(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)()")
	if x == nil then
		return nil, nil, i
	end
	-- count the words the point used
	local consumed = string.sub(rest, 1, (used :: number) - 1)
	local n = 0
	for _ in string.gmatch(consumed, "%S+") do
		n += 1
	end
	local px, pz = math.floor(tonumber(x) :: number + 0.5), math.floor(tonumber(z) :: number + 0.5)
	if px < -32768 or px > 32767 or pz < -32768 or pz > 32767 then
		return nil, nil, i
	end
	return px, pz, i + n
end

-- Parses chat text into a CHEAT command. `selected`: the player's selected
-- unit IDs (for "kill selected"). Returns the command, or nil and why.
function CheatText.parse(text: string, defs: Defs, selected: { number }?): (Schema.Command?, string?)
	local words = {}
	for w in string.gmatch(string.lower(text), "%S+") do
		table.insert(words, w)
	end
	if words[1] == "/cheat" then
		table.remove(words, 1)
	elseif words[1] and string.sub(words[1], 1, 1) == "/" then
		words[1] = string.sub(words[1], 2)
	end
	local verb = words[1]
	if verb == "give" then
		local def = defs.units[words[2] or ""]
		if def == nil then
			return nil, `unknown unit "{words[2] or ""}"`
		end
		local i = 3
		local count, t = 1, 0
		if words[i] ~= "at" then
			count = int(words[i]) or -1
			i += 1
			if words[i] ~= "at" then
				local err
				t, err = team(words[i])
				if t == nil then
					return nil, err
				end
				i += 1
			end
		end
		if count < 1 or count > 100 then
			return nil, "count must be 1..100"
		end
		if words[i] ~= "at" then
			return nil, "usage: give <unit> [count] [team] at <x,z>"
		end
		local x, z = point(words, i + 1)
		if x == nil then
			return nil, "position must be x,z"
		end
		return cheat(OP.GIVE, { defIndex = def.index, amount = count, cheatTeam = t, x = x, z = z })
	elseif verb == "res" or verb == "income" then
		local res = RESOURCES[words[2] or ""]
		if res == nil then
			return nil, `usage: {verb} <supply|power|all> <amount{if verb == "res" then "|max" else ""}> [team]`
		end
		local amount = if verb == "res" and words[3] == "max" then Schema.CHEAT_MAX else int(words[3])
		if amount == nil or amount < 0 or (amount > 10_000_000 and amount ~= Schema.CHEAT_MAX) then
			return nil, "amount must be 0..10000000"
		end
		local t, err = team(words[4])
		if t == nil then
			return nil, err
		end
		return cheat(if verb == "res" then OP.RES else OP.INCOME, { cheatArg = res, amount = amount, cheatTeam = t })
	elseif verb == "instabuild" or verb == "god" or verb == "reveal" then
		local on = onOff(words[2])
		if on == nil then
			return nil, `usage: {verb} on|off`
		end
		local t, err = team(if verb == "reveal" then words[3] else nil)
		if t == nil then
			return nil, err
		end
		local op = if verb == "instabuild" then OP.INSTABUILD elseif verb == "god" then OP.GOD else OP.REVEAL
		return cheat(op, { cheatArg = on, cheatTeam = t })
	elseif verb == "kill" then
		if words[2] == "selected" then
			local ids = table.move(selected or {}, 1, math.min(#(selected or {}), Schema.MAX_UNITS_PER_COMMAND), 1, {})
			if #ids == 0 then
				return nil, "nothing selected"
			end
			return cheat(OP.KILL, { cheatArg = Schema.CheatKill.SELECTED }, ids)
		elseif words[2] == "at" then
			local x, z, i = point(words, 3)
			local r = int(words[i])
			if x == nil or r == nil or r < 1 or r > 65535 then
				return nil, "usage: kill at <x,z> <radius>"
			end
			return cheat(OP.KILL, { cheatArg = Schema.CheatKill.AREA, x = x, z = z, radius = r })
		end
		local t = int(words[2])
		if t == nil or t < 1 or t > Schema.MAX_TEAMS then
			return nil, "usage: kill selected | kill <team> | kill at <x,z> <radius>"
		end
		return cheat(OP.KILL, { cheatArg = Schema.CheatKill.TEAM, cheatTeam = t })
	elseif verb == "speed" then
		local v = tonumber(words[2])
		if v == nil or v < 0.25 or v > 8 then
			return nil, "speed must be 0.25..8"
		end
		return cheat(OP.SPEED, { amount = math.floor(v * 100 + 0.5) })
	elseif verb == "ai" then
		local t = int(words[2])
		local action = words[3]
		if t == nil or t < 1 or t > Schema.MAX_TEAMS or (action ~= "pause" and action ~= "resume") then
			return nil, "usage: ai <team> pause|resume"
		end
		return cheat(OP.AI, { cheatArg = if action == "pause" then 1 else 0, cheatTeam = t })
	end
	return nil, `unknown cheat "{verb or ""}"`
end

-- A chat line for a CHEAT_RESULT event.
function CheatText.describe(e: Schema.Event): string
	local op = e.cheatOp :: number
	local name = OP_NAMES[op] or "cheat"
	local res = e.cheatResult :: number
	if res ~= R.OK then
		if res == R.NO_ROOM then
			return `{name}: no room there (0 of {e.total} placed)`
		end
		return `{name}: {MESSAGES[res] or "failed"}`
	end
	local count = e.count or 0
	if op == OP.GIVE then
		return `give: placed {count} of {e.total}`
	elseif op == OP.KILL then
		return `kill: {count} unit{if count == 1 then "" else "s"}`
	elseif op == OP.SPEED then
		return `speed: {count / 100}x`
	elseif op == OP.AI then
		return `ai: {count} AI player{if count == 1 then "" else "s"}`
	elseif op == OP.RES then
		return `res: set to {count}`
	elseif op == OP.INCOME then
		return if count == 0 then "income: cleared" else `income: +{count}/s`
	end
	return `{name}: ok`
end

return CheatText
