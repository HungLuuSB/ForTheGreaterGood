--!strict
-- Faction balance in AI matches (S-65; docs/design/factions.md section 6):
--   lune run faction_ai [minutes] [seeds] [mapFilter] [mirroredOnly]
-- Order AI against Chaos AI under Command Ends, up to `minutes` of game time
-- (default 40), seeds 7.. (default 3), both starts:
--   1v1 on map:ridgeline, map:coastline, skirmish:256, map:normandy: every
--   level pair (Order's level × Chaos's level, 9 pairs);
--   2v2 on map:twin_lakes: two Order players against two Chaos players,
--   every level pair (both players of a side at that side's level);
--   4-player FFA on map:crossroads: two of each faction, alternating
--   starts, all at one level (easy, normal, hard).
-- Targets (mirrored levels: both sides at the same level): each faction
-- wins 40–60% overall and 35–65% on every map; at most 10% of matches
-- undecided at the limit (still running: they count for nobody).
-- Writes docs/FACTION_AI.md (report only) when run without a map filter.
-- `mirroredOnly` = "mirrored": only the same-level pairs (a quicker check).
-- `--jobs=N` (default 6; S-99, next.md item 9): N Lune processes play the
-- matches in parallel (each every N-th one, `--worker=k/N`), and this one
-- gathers their results in match order: the report is the same as one
-- process would write, only sooner.

local fs = require("@lune/fs")
local process = require("@lune/process")
local DateTime = require("@lune/datetime")
local Parallel = require("./parallel")

local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")

local ARGS, FLAGS = Parallel.args(process.args)
local MINUTES = tonumber(ARGS[1]) or 40
local SEEDS = tonumber(ARGS[2]) or 3
local FILTER = if ARGS[3] == nil or ARGS[3] == "all" then nil else ARGS[3]
local MIRRORED_ONLY = ARGS[4] == "mirrored"
local TICKS = MINUTES * 60 * 15
local LEVELS = { "easy", "normal", "hard" }

-- a player: { faction, level }; teams: odd = Order, even = Chaos
-- (Scenarios.standard_start); starts follow player order
type Slot = { faction: string, level: string }
type Match = { mapId: string, slots: { Slot }, mode: string, label: string }

local matches: { Match } = {}
for _, mapId in { "map:ridgeline", "map:coastline", "skirmish:256", "map:normandy" } do
	for _, lo in LEVELS do
		for _, lc in LEVELS do
			if MIRRORED_ONLY and lo ~= lc then
				continue
			end
			local o, c = { faction = "order", level = lo }, { faction = "chaos", level = lc }
			table.insert(matches, { mapId = mapId, slots = { o, c }, mode = "FFA", label = `Order {lo} (west) vs Chaos {lc}` })
			table.insert(matches, { mapId = mapId, slots = { c, o }, mode = "FFA", label = `Chaos {lc} (west) vs Order {lo}` })
		end
	end
end
for _, lo in LEVELS do
	for _, lc in LEVELS do
		if MIRRORED_ONLY and lo ~= lc then
			continue
		end
		local o, c = { faction = "order", level = lo }, { faction = "chaos", level = lc }
		table.insert(matches, { mapId = "map:twin_lakes", slots = { o, o, c, c }, mode = "TEAM", label = `Order {lo} ×2 (west) vs Chaos {lc} ×2` })
		table.insert(matches, { mapId = "map:twin_lakes", slots = { c, c, o, o }, mode = "TEAM", label = `Chaos {lc} ×2 (west) vs Order {lo} ×2` })
	end
end
for _, l in LEVELS do
	local o, c = { faction = "order", level = l }, { faction = "chaos", level = l }
	table.insert(matches, { mapId = "map:crossroads", slots = { o, c, o, c }, mode = "FFA", label = `FFA {l}: Order, Chaos, Order, Chaos` })
	table.insert(matches, { mapId = "map:crossroads", slots = { c, o, c, o }, mode = "FFA", label = `FFA {l}: Chaos, Order, Chaos, Order` })
end

-- Every (match, seed) to play, in report order.
type Item = { m: Match, seed: number }
local items: { Item } = {}
for _, m in matches do
	if FILTER and not string.find(m.mapId, FILTER, 1, true) then
		continue
	end
	for seed = 7, 6 + SEEDS do
		table.insert(items, { m = m, seed = seed })
	end
end

-- Plays one item: the winning faction ("order", "chaos" or "" undecided)
-- and the last tick.
local function play(item: Item): (string, number)
	local m, seed = item.m, item.seed
	local players, ai = {}, {}
	local nextTeam = { order = 1, chaos = 2 }
	for i, s in m.slots do
		local team = nextTeam[s.faction]
		nextTeam[s.faction] += 2
		local ally = if m.mode == "TEAM" then (if s.faction == m.slots[1].faction then 1 else 2) else i
		table.insert(players, { id = i, team = team, allyTeam = ally })
		ai[i] = s.level
	end
	local sim = Sim.new({
		seed = seed,
		players = players,
		mapId = m.mapId,
		scenario = "standard_start",
		match = { mode = m.mode, win = "COMMAND_ENDS", ai = ai },
	})
	local brains = Skirmish.forMatch(sim)
	for _ = 1, TICKS do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if sim.match.over then
			break
		end
	end
	if sim.match.over and sim.match.winner ~= 0 then
		for i, s in m.slots do
			if sim.players[i].allyTeam == sim.match.winner then
				return s.faction, sim.tick
			end
		end
	end
	return "", sim.tick
end

-- A worker plays its share and prints one result line per item.
local worker, workers = Parallel.worker(FLAGS)
if worker then
	for i, item in items do
		if (i - 1) % workers == worker then
			local winner, tick = play(item)
			print(`RESULT {i} {if winner == "" then "-" else winner} {tick}`)
		end
	end
	return
end

-- Results by item: in parallel by workers, else here.
local t0 = DateTime.now().unixTimestampMillis
local results: { { winner: string, tick: number } } = {}
local jobs = tonumber(FLAGS.jobs) or 6
if jobs > 1 then
	for i, fields in Parallel.run("faction_ai", process.args, jobs) do
		results[i] = { winner = if fields[1] == "-" then "" else fields[1], tick = tonumber(fields[2]) :: number }
	end
else
	for i, item in items do
		local winner, tick = play(item)
		results[i] = { winner = winner, tick = tick }
	end
end

local lines: { string } = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

out("# Faction balance in AI matches")
out("")
out(`Generated by \`lune run faction_ai {MINUTES} {SEEDS}\` (S-65): Order AI against Chaos AI under Command Ends, up to {MINUTES} minutes of game time, seeds 7..{6 + SEEDS}, both starts. Report only. Targets for the same-level matches: each faction wins 40–60% overall and 35–65% per map; at most 10% undecided at the limit (those count for nobody).`)
out("")
out("| Map | Players (in start order) | Seed | Winner | Length |")
out("|---|---|---|---|---|")

type Tally = { order: number, chaos: number, undecided: number }
local function newTally(): Tally
	return { order = 0, chaos = 0, undecided = 0 }
end
local mirroredByMap: { [string]: Tally } = {}
local mirroredAll = newTally()
local byLevels: { [string]: Tally } = {} -- "orderLevel/chaosLevel" (1v1 and 2v2)
local lengths: { [string]: { number } } = {}

for index, item in items do
	local m, seed = item.m, item.seed
	do
		local r = results[index]
		assert(r, `no result for match {index}`)
		local winnerFaction: string? = if r.winner == "" then nil else r.winner
		local lastTick = r.tick
		local mirrored = true
		for _, s in m.slots do
			mirrored = mirrored and s.level == m.slots[1].level
		end
		local function add(t: Tally)
			if winnerFaction == "order" then
				t.order += 1
			elseif winnerFaction == "chaos" then
				t.chaos += 1
			else
				t.undecided += 1
			end
		end
		if mirrored then
			mirroredByMap[m.mapId] = mirroredByMap[m.mapId] or newTally()
			add(mirroredByMap[m.mapId])
			add(mirroredAll)
		end
		if #m.slots == 2 or m.mode == "TEAM" then
			local lo, lc = "", ""
			for _, s in m.slots do
				if s.faction == "order" then
					lo = s.level
				else
					lc = s.level
				end
			end
			local key = `{lo}/{lc}`
			byLevels[key] = byLevels[key] or newTally()
			add(byLevels[key])
		end
		out(string.format("| %s | %s | %d | %s | %.1f min |", m.mapId, m.label, seed, if winnerFaction then (if winnerFaction == "order" then "Order" else "Chaos") else "undecided", lastTick / 900))
		lengths[m.mapId] = lengths[m.mapId] or {}
		table.insert(lengths[m.mapId], lastTick / 900)
	end
end

local function pct(a: number, total: number): string
	return if total > 0 then string.format("%.0f%%", a / total * 100) else "—"
end
local function verdict(t: Tally, lo: number, hi: number): string
	local decided = t.order + t.chaos
	local total = decided + t.undecided
	if total == 0 then
		return "—"
	end
	local share = if decided > 0 then t.order / decided else 0.5
	local ok = share >= lo and share <= hi and t.undecided <= 0.1 * total
	return if ok then "yes" else "**no**"
end

out("")
out("**Same-level matches** (both sides at one level; share of the decided matches):")
out("")
out("| Map | Order wins | Chaos wins | Undecided | Order share | In target |")
out("|---|---|---|---|---|---|")
for _, mapId in { "map:ridgeline", "map:coastline", "skirmish:256", "map:normandy", "map:twin_lakes", "map:crossroads" } do
	local t = mirroredByMap[mapId]
	if t then
		out(string.format("| %s | %d | %d | %d | %s | %s |", mapId, t.order, t.chaos, t.undecided, pct(t.order, t.order + t.chaos), verdict(t, 0.35, 0.65)))
	end
end
local a = mirroredAll
out(string.format("| **all** | %d | %d | %d (%s) | %s | %s |", a.order, a.chaos, a.undecided, pct(a.undecided, a.order + a.chaos + a.undecided), pct(a.order, a.order + a.chaos), verdict(a, 0.4, 0.6)))
out("")
out("**Every level pair** (1v1 and 2v2; Order's level in the row, Chaos's in the column; Order wins – Chaos wins (undecided)):")
out("")
out("| Order \\ Chaos | easy | normal | hard |")
out("|---|---|---|---|")
for _, lo in LEVELS do
	local row = {}
	for _, lc in LEVELS do
		local t = byLevels[`{lo}/{lc}`]
		table.insert(row, if t then `{t.order}–{t.chaos} ({t.undecided})` else "—")
	end
	out(`| {lo} | {table.concat(row, " | ")} |`)
end
out("")
out("**Match lengths** (minutes; matches stopped at the limit count as the limit):")
out("")
out("| Map | Matches | Shortest | Median | Longest | At the limit |")
out("|---|---|---|---|---|---|")
for _, mapId in { "map:ridgeline", "map:coastline", "skirmish:256", "map:normandy", "map:twin_lakes", "map:crossroads" } do
	local l = lengths[mapId]
	if l then
		table.sort(l)
		local atLimit = 0
		for _, v in l do
			if v >= MINUTES then
				atLimit += 1
			end
		end
		out(string.format("| %s | %d | %.1f | %.1f | %.1f | %d |", mapId, #l, l[1], l[(#l + 1) // 2], l[#l], atLimit))
	end
end
out("")
out(string.format("Run time %.0f s on the dev PC (%d job(s)).", (DateTime.now().unixTimestampMillis - t0) / 1000, jobs))
if FILTER == nil then
	fs.writeFile("docs/FACTION_AI.md", table.concat(lines, "\n") .. "\n")
	print("wrote docs/FACTION_AI.md")
end
