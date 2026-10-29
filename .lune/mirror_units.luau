--!strict
-- Mirror AI matches that also count what each AI built (S-216, the user:
-- "show me mirror-match results" once the AI builds playtest 3's units).
--   lune run mirror_units [seeds] [minutes] [maps] [levels]
-- maps: comma-separated map ids (default "map:supreme_strait,map:coastline");
-- levels: comma-separated AI levels (default "normal,hard"). One AI a side,
-- both faction mirrors, seeds 1.. (default 4), up to `minutes` (default 25;
-- then the value lead decides, as in the fairness report). Supreme Strait's
-- sixteen starts: the pre-game's pick, each AI on its side's front spot.
-- Report only (not the balance checkpoint): debug_out/mirror_units.md.
-- `--jobs=N` (default 6): N Lune processes in parallel.

local fs = require("@lune/fs")
local process = require("@lune/process")
local DateTime = require("@lune/datetime")
local Parallel = require("./parallel")

local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")

local ARGS, FLAGS = Parallel.args(process.args)
local SEEDS = tonumber(ARGS[1]) or 4
local MINUTES = tonumber(ARGS[2]) or 25
local MAPS = string.split(ARGS[3] or "map:supreme_strait,map:coastline", ",")
local LEVELS = string.split(ARGS[4] or "normal,hard", ",")

-- what is counted, by the id after the faction prefix; several ids per row
local ROWS: { { string } } = {
	{ "Bot labs", "botlab", "advbotlab" },
	{ "Bots", "glint", "skitter", "mace", "thug", "kestrel", "needle", "lazarus", "graverobber", "fatboy", "centurion" },
	{ "Construction Turrets", "nano" },
	{ "Advanced solar", "advsolar" },
	{ "Fusion", "fusion" },
	{ "Advanced fusion", "advfusion" },
	{ "Advanced converters", "advconverter" },
	{ "Advanced storage", "advdepot", "advcapacitor", "advaccumulator" },
	{ "Offshore extractors", "seaextractor" },
	{ "Experimental Gantry", "gantry" },
	{ "Titan / Juggernaut", "titan", "juggernaut" },
}
local rowOf: { [string]: number } = {}
for r, row in ROWS do
	for k = 2, #row do
		rowOf[row[k]] = r
	end
end

type Item = { mapId: string, level: string, seed: number, mirror: string, teams: { number } }
local items: { Item } = {}
for _, mapId in MAPS do
	for _, level in LEVELS do
		for seed = 1, SEEDS do
			for _, m in { { "order", { 1, 3 } }, { "chaos", { 2, 4 } } } do -- teams: odd = Order, even = Chaos
				table.insert(items, { mapId = mapId, level = level, seed = seed, mirror = m[1] :: string, teams = m[2] :: { number } })
			end
		end
	end
end

-- winner (1, 2 or 0), ticks, and per start the counts of each row ever finished
local function play(item: Item): (number, number, { { number } })
	local match: any = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = item.level, [2] = item.level } }
	if item.mapId == "map:supreme_strait" then
		match.startMode = "choose"
	end
	local sim = Sim.new({
		seed = item.seed,
		players = { { id = 1, team = item.teams[1], allyTeam = 1 }, { id = 2, team = item.teams[2], allyTeam = 2 } },
		mapId = item.mapId,
		scenario = "standard_start",
		match = match,
	})
	local brains = Skirmish.forMatch(sim)
	local w = sim.world
	local seen: { [number]: boolean } = {}
	local counts = { table.create(#ROWS, 0), table.create(#ROWS, 0) }
	local function sample()
		for _, id in w.ids do
			if not seen[id] and w.buildProgress[id] >= 1 then
				local p = w.owner[id]
				if p == 1 or p == 2 then
					local d = sim.defs.unitByIndex[w.defIndex[id]].id
					local r = rowOf[string.sub(d, 5)]
					if r then
						seen[id] = true
						counts[p][r] += 1
					end
				end
			end
		end
	end
	for t = 1, MINUTES * 60 * 15 do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if t % 30 == 0 then
			sample()
		end
		if sim.match.over then
			break
		end
	end
	sample()
	if sim.match.over then
		return sim.match.winner or 0, sim.tick, counts
	end
	local v = { 0, 0 }
	for _, id in w.ids do
		local a = w.ally[id]
		if a == 1 or a == 2 then
			local c = sim.defs.unitByIndex[w.defIndex[id]].cost
			v[a] += (c.supply + c.power / 10) * w.buildProgress[id]
		end
	end
	return if v[1] > v[2] then 1 elseif v[2] > v[1] then 2 else 0, sim.tick, counts
end

local worker, workers = Parallel.worker(FLAGS)
if worker then
	for i, item in items do
		if (i - 1) % workers == worker then
			local winner, tick, counts = play(item)
			print(`RESULT {i} {winner} {tick} {table.concat(counts[1], ",")} {table.concat(counts[2], ",")}`)
		end
	end
	return
end

local t0 = DateTime.now().unixTimestampMillis
type Result = { winner: number, tick: number, counts: { { number } } }
local results: { Result } = {}
local function parse(s: string): { number }
	local out = {}
	for _, v in string.split(s, ",") do
		table.insert(out, tonumber(v) :: number)
	end
	return out
end
local jobs = tonumber(FLAGS.jobs) or 6
if jobs > 1 then
	for i, fields in Parallel.run("mirror_units", process.args, jobs) do
		results[i] = { winner = tonumber(fields[1]) :: number, tick = tonumber(fields[2]) :: number, counts = { parse(fields[3]), parse(fields[4]) } }
	end
else
	for i, item in items do
		local winner, tick, counts = play(item)
		results[i] = { winner = winner, tick = tick, counts = counts }
	end
end

local lines: { string } = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end
out("# Mirror matches: wins and what the AI built")
out("")
out(`\`lune run mirror_units {SEEDS} {MINUTES}\` on {DateTime.now():formatUniversalTime("%Y-%m-%d")} (S-216): one AI a side of the same level and faction, seeds 1..{SEEDS}, both faction mirrors, up to {MINUTES} minutes (then the value lead decides). Report only.`)
for _, mapId in MAPS do
	for _, level in LEVELS do
		local n, s1, s2, draws, ticks = 0, 0, 0, 0, 0
		local by = { order = { 0, 0 }, chaos = { 0, 0 } }
		local sums = { order = table.create(#ROWS, 0), chaos = table.create(#ROWS, 0) }
		local had = { order = table.create(#ROWS, 0), chaos = table.create(#ROWS, 0) }
		local per = { order = 0, chaos = 0 }
		for i, item in items do
			if item.mapId ~= mapId or item.level ~= level then
				continue
			end
			local r = results[i]
			n += 1
			ticks += r.tick
			if r.winner == 1 then
				s1 += 1
				by[item.mirror][1] += 1
			elseif r.winner == 2 then
				s2 += 1
				by[item.mirror][2] += 1
			else
				draws += 1
			end
			for p = 1, 2 do
				per[item.mirror] += 1
				for k = 1, #ROWS do
					sums[item.mirror][k] += r.counts[p][k]
					if r.counts[p][k] > 0 then
						had[item.mirror][k] += 1
					end
				end
			end
		end
		if n == 0 then
			continue
		end
		out("")
		out(`## {mapId}, {level}`)
		out("")
		out(`{n} matches, average length {string.format("%.1f", ticks / n / 900)} min. Start 1 won {s1}, start 2 won {s2}, {draws} draws (Order mirror {by.order[1]} / {by.order[2]}, Chaos mirror {by.chaos[1]} / {by.chaos[2]}).`)
		out("")
		out("| Built (per AI: average; AIs that built any) | Order | Chaos |")
		out("|---|---|---|")
		for k, row in ROWS do
			local function cell(m: string): string
				return `{string.format("%.1f", sums[m][k] / math.max(per[m], 1))} ({had[m][k]} of {per[m]})`
			end
			out(`| {row[1]} | {cell("order")} | {cell("chaos")} |`)
		end
	end
end
out("")
out(`{#items} matches in {math.floor((DateTime.now().unixTimestampMillis - t0) / 1000 + 0.5)} s.`)
fs.writeDir("debug_out")
fs.writeFile("debug_out/mirror_units.md", table.concat(lines, "\n") .. "\n")
print("written to debug_out/mirror_units.md")
