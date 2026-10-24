--!strict
-- The cheat command line's typing help (C-119), pure: suggestions as the
-- player types (command names; after "give" units by id, display name or
-- alias; each command's choices after it: on / off, supply / power / all,
-- selected / a team, pause / resume, speeds; C-194), the cursor position
-- filled in where "at" is left out, and /help. A unit's aliases are its
-- icon-sheet type with the faction's prefix, in full and short (the user:
-- "give ord_shield -> Phalanx, give ord_ir-sam"): ord_shield-generator,
-- ord_shield; chs_ir-sam-site, chs_ir-sam; and the type alone for both.
-- Parsing and the commands themselves are the sim's (Shared/Net/CheatText,
-- net.md 9a): this only shapes the text before it goes there.

local IconAtlas = require("../UI/IconAtlas")

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

-- Each command's choices, word by word after the command (C-194; `team`
-- stands for the team numbers 1-4).
local CHOICES: { [string]: { { string } } } = {
	res = { { "supply", "power", "all" }, { "max", "1000", "10000" } },
	income = { { "supply", "power", "all" }, { "100", "500", "1000", "0" } },
	instabuild = { { "on", "off" } },
	reveal = { { "on", "off" } },
	god = { { "on", "off" } },
	kill = { { "selected", "1", "2", "3", "4", "at" } },
	speed = { { "0.25", "0.5", "1", "2", "4", "8" } },
	ai = { { "1", "2", "3", "4" }, { "pause", "resume" } },
	cheat = { { "on", "off" } },
	give = { {}, { "1", "5", "10" } },
}
CheatInput.CHOICES = CHOICES

-- Trailing type words a short alias drops ("IR SAM Site" -> "ir-sam").
local GENERIC = { site = true, generator = true, tower = true, station = true, plant = true, launcher = true, emplacement = true }

local function slug(text: string): string
	local s = string.gsub(string.lower(text), "[^%w]+", "-")
	s = string.gsub(s, "^%-+", "")
	return (string.gsub(s, "%-+$", ""))
end

local aliasCache: { [any]: { [string]: { string } } } = setmetatable({}, { __mode = "k" }) :: any

-- alias -> the unit ids it names (sorted), for every unit in `defs`.
function CheatInput.aliases(defs: any): { [string]: { string } }
	local cached = aliasCache[defs]
	if cached then
		return cached
	end
	local map: { [string]: { string } } = {}
	local function add(alias: string, id: string)
		if alias == "" then
			return
		end
		local list = map[alias]
		if list == nil then
			list = {}
			map[alias] = list
		end
		if not table.find(list, id) then
			table.insert(list, id)
		end
	end
	for id, def in defs.units do
		local prefix = string.match(id, "^(%a+_)") or ""
		local entry = (IconAtlas.byDef :: any)[id]
		if entry then
			local full = slug(entry.name)
			local words = string.split(full, "-")
			while #words > 1 and GENERIC[words[#words]] do
				table.remove(words)
			end
			local short = table.concat(words, "-")
			for _, a in { full, short } do
				add(prefix .. a, id)
				add(a, id)
			end
		end
	end
	for _, list in map do
		table.sort(list)
	end
	aliasCache[defs] = map
	return map
end

-- The unit ids `word` names: an id, a display name (any case) or an alias.
function CheatInput.resolve(word: string, defs: any): { string }
	local w = string.lower(word)
	if defs.units[w] then
		return { w }
	end
	local out = {}
	for id, def in defs.units do
		if string.lower(def.name or "") == w then
			table.insert(out, id)
		end
	end
	if #out > 0 then
		table.sort(out)
		return out
	end
	return CheatInput.aliases(defs)[w] or {}
end

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
		-- the aliases each unit answers to (C-194)
		local byUnit: { [string]: { string } } = {}
		for alias, list in CheatInput.aliases(defs) do
			for _, id in list do
				byUnit[id] = byUnit[id] or {}
				table.insert(byUnit[id], alias)
			end
		end
		for _, id in ids do
			local def = defs.units[id]
			local name = string.lower(def.name or id)
			local entry = (IconAtlas.byDef :: any)[id]
			local item = { text = "/give " .. id .. " ", label = if entry then `{def.name} ({id}) - {entry.name}` else `{def.name} ({id})` }
			local aliasStarts, aliasContains = false, false
			for _, a in byUnit[id] or {} do
				aliasStarts = aliasStarts or string.sub(a, 1, #typed) == typed
				aliasContains = aliasContains or string.find(a, typed, 1, true) ~= nil
			end
			if typed == "" or string.sub(id, 1, #typed) == typed or string.sub(name, 1, #typed) == typed or aliasStarts then
				table.insert(starts, item)
			elseif string.find(id, typed, 1, true) or string.find(name, typed, 1, true) or aliasContains then
				table.insert(contains, item)
			end
		end
		for _, list in { starts, contains } do
			for _, item in list do
				table.insert(out, item)
			end
		end
	elseif #w >= 1 then
		-- a command's choices for the word being typed (C-194)
		local cmd = string.lower(w[1])
		local index = if trailing then #w else #w - 1 -- which word after the command
		local spec = CHOICES[cmd] and CHOICES[cmd][index]
		if spec and #spec > 0 then
			local typed = if trailing then "" else string.lower(w[#w])
			local head = {}
			for i = 1, index do
				table.insert(head, w[i])
			end
			local prefix = "/" .. table.concat(head, " ") .. " "
			for _, choice in spec do
				if string.sub(choice, 1, #typed) == typed then
					table.insert(out, { text = prefix .. choice .. " ", label = choice })
				end
			end
		end
	end
	while #out > limit do
		table.remove(out)
	end
	return out
end

-- The unit's def id for `word` (an id, a display name or an alias, any
-- case), or nil when it names none or several (Tab cycles those).
function CheatInput.unitId(word: string, defs: any): string?
	local ids = CheatInput.resolve(word, defs)
	return if #ids == 1 then ids[1] else nil
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
	table.insert(out, "  Units by id, name or type: /give ord_shield, /give chs_ir-sam, /give phalanx.")
	table.insert(out, "  Tab completes; Tab again cycles the choices.")
	table.insert(out, "  Ctrl+Shift+G repeats the last /give at the cursor.")
	return out
end

return CheatInput
