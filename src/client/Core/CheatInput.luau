--!strict
-- The cheat command line's typing help (C-119), pure: suggestions as the
-- player types (command names, then unit ids or display names after
-- "give"), the cursor position filled in where "at" is left out, and /help.
-- Parsing and the commands themselves are the sim's (Shared/Net/CheatText,
-- net.md 9a): this only shapes the text before it goes there.

local CheatInput = {}

-- Command, usage, example (the sim's CheatText accepts these forms).
CheatInput.COMMANDS = table.freeze({
	{ "give", "give <unit> [count] [team] [at x,z]", "give ord_lancer 5" },
	{ "res", "res supply|power|all <n|max> [team]", "res all max" },
	{ "income", "income supply|power|all <n> [team]", "income power 500" },
	{ "instabuild", "instabuild on|off", "instabuild on" },
	{ "reveal", "reveal on|off [team]", "reveal on" },
	{ "god", "god on|off", "god on" },
	{ "kill", "kill selected | kill <team> | kill at x,z r", "kill selected" },
	{ "speed", "speed 0.25-8", "speed 2" },
	{ "ai", "ai <team> pause|resume", "ai 2 pause" },
	{ "cheat", "cheat on|off (the lobby's Cheats toggle, host only)", "cheat on" },
	{ "help", "help", "help" },
})

export type Suggestion = { text: string, label: string } -- text: the whole line it completes to

local function words(text: string): { string }
	local out = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(out, w)
	end
	return out
end

-- The line without a leading "/" or "/cheat " (CheatText ignores them too).
function CheatInput.strip(text: string): string
	local s = string.gsub(text, "^%s+", "")
	s = string.gsub(s, "^/", "")
	local rest = string.match(s, "^[Cc][Hh][Ee][Aa][Tt]%s+(.+)$")
	if rest and not string.match(string.lower(rest), "^o[nf]") then
		s = rest
	end
	return s
end

-- Up to `max` suggestions for the typed `text`: command names while the
-- first word is typed; after "give", units whose id or name starts with (or
-- contains) what's typed, case-insensitive, id first.
function CheatInput.suggest(text: string, defs: any, max: number?): { Suggestion }
	local limit = max or 8
	local s = CheatInput.strip(text)
	local w = words(s)
	local trailing = string.match(s, "%s$") ~= nil
	local out: { Suggestion } = {}
	if #w == 0 or (#w == 1 and not trailing) then
		local typed = string.lower(w[1] or "")
		for _, c in CheatInput.COMMANDS do
			if string.sub(c[1], 1, #typed) == typed then
				table.insert(out, { text = "/" .. c[1] .. " ", label = c[2] })
			end
		end
	elseif string.lower(w[1]) == "give" and (#w == 1 or (#w == 2 and not trailing)) then
		local typed = string.lower(w[2] or "")
		local starts, contains = {}, {}
		local ids = {}
		for id in defs.units do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local def = defs.units[id]
			local name = string.lower(def.name or id)
			local item = { text = "/give " .. id .. " ", label = `{def.name} ({id})` }
			if typed == "" or string.sub(id, 1, #typed) == typed or string.sub(name, 1, #typed) == typed then
				table.insert(starts, item)
			elseif string.find(id, typed, 1, true) or string.find(name, typed, 1, true) then
				table.insert(contains, item)
			end
		end
		for _, list in { starts, contains } do
			for _, item in list do
				table.insert(out, item)
			end
		end
	end
	while #out > limit do
		table.remove(out)
	end
	return out
end

-- The unit's def id for `word` (an id or a display name, case-insensitive),
-- or nil.
function CheatInput.unitId(word: string, defs: any): string?
	local w = string.lower(word)
	if defs.units[w] then
		return w
	end
	for id, def in defs.units do
		if string.lower(def.name or "") == w then
			return id
		end
	end
	return nil
end

-- The line as it goes to CheatText: the leading slash and "/cheat" kept off,
-- a display name after "give" turned into its id, and " at x,z" added to a
-- give with no "at" (the cursor's ground position, whole studs).
function CheatInput.prepare(text: string, defs: any, cursorX: number?, cursorZ: number?): string
	local s = CheatInput.strip(text)
	local w = words(s)
	if #w >= 2 and string.lower(w[1]) == "give" then
		local id = CheatInput.unitId(w[2], defs)
		if id then
			w[2] = id
		end
		local hasAt = false
		for _, x in w do
			hasAt = hasAt or string.lower(x) == "at"
		end
		if not hasAt and cursorX and cursorZ then
			table.insert(w, "at")
			table.insert(w, `{math.floor(cursorX + 0.5)},{math.floor(cursorZ + 0.5)}`)
		end
		return table.concat(w, " ")
	end
	return s
end

-- Who cheated in a finished match's results (Main.server's: `series` is
-- Stats.series, each player's `stats` Stats.report's): nil when nobody did,
-- else "Name ×n, ..." ("" when only the series' flag says so; C-120).
function CheatInput.cheaters(results: any): string?
	local names = {}
	for _, p in results.players or {} do
		local n = p.stats and p.stats.cheats or 0
		if n > 0 then
			table.insert(names, `{p.name} ×{n}`)
		end
	end
	if #names == 0 and not (results.series and results.series.cheated) then
		return nil
	end
	return table.concat(names, ", ")
end

-- /help's lines.
function CheatInput.help(): { string }
	local out = { "Cheat commands (the match must allow cheats):" }
	for _, c in CheatInput.COMMANDS do
		table.insert(out, `  /{c[2]}    e.g. /{c[3]}`)
	end
	table.insert(out, "  Ctrl+Shift+G repeats the last /give at the cursor.")
	return out
end

return CheatInput
