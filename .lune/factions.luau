--!strict
-- Faction pass trade check (S-62; docs/design/factions.md section 6).
-- Report only; it never changes stats.
--   lune run factions [seeds] [filter]   (filter: only roles whose name contains it)
--
-- Every shared role's two versions (Order, Chaos) at equal value
-- (Scenes.trial, value = supply + power / 10):
--   * Roles that fight each other (tanks, artillery, fighters, scouts):
--     close (120 studs, both attack-move), long (600 studs, both
--     attack-move), defend (Order holds a prepared position, Chaos
--     attacks it from 600 studs) and flank (Chaos in two halves, 300
--     studs north and south of Order: its numbers come from two sides).
--     Trade = Chaos value destroyed / Order value lost, all seeds summed:
--     above 1 favours Order.
--       overall    geometric mean of close and long: target 0.8–1.25
--       Order's    long or defend at least 1.25 (it wins at range or
--       condition  behind defenses)
--       Chaos's    close or flank at most 0.8 (it wins up close or in
--       condition  numbers)
--   * Roles that don't fight each other (SAMs, artillery emplacements):
--     each version holds against the same equal-value raid; the score is
--     Order's trade / Chaos's trade (target 0.8–1.25). SAMs face two
--     raids: `heavy` (bombers: few, expensive targets, Order's condition)
--     and `swarm` (gunship helicopters: many, Chaos's condition).
-- Workers and radars have no fight to measure (their numbers follow the
-- proposal's directions).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Defs = require("../src/shared/Defs/Defs")
local Sim = require("../src/server/Sim/Sim")
local Scenes = require("../src/server/Tests/Support/Scenes")

local SEEDS = tonumber(process.args[1]) or 3
local FILTER = process.args[2]
local defs = Defs.load()

local function value(d: Defs.UnitDef): number
	return d.cost.supply + d.cost.power / 10
end

-- Plays one scene; returns the value each side lost.
local function play(scene: Scenes.Scene): (number, number)
	local sim = scene.sim
	local w = sim.world
	local sides = scene.sides :: { { number } }
	local defOf: { [number]: Defs.UnitDef } = {}
	for s = 1, 2 do
		for _, id in sides[s] do
			defOf[id] = defs.unitByIndex[w.defIndex[id]]
		end
	end
	local function note()
		for s = 1, 2 do
			for _, id in sides[s] do
				if defOf[id] == nil and w.slot[id] then
					defOf[id] = defs.unitByIndex[w.defIndex[id]]
				end
			end
		end
	end
	while sim.tick < scene.maxTicks and not scene.done(sim) do
		scene.drive(sim)
		note() -- units that joined (waves)
		Sim.step(sim)
	end
	local function lost(ids: { number }): number
		local v = 0
		for _, id in ids do
			local d = defOf[id]
			local hp = if w.slot[id] then w.health[id] else 0
			v += value(d) * (1 - math.clamp(hp / d.health, 0, 1))
		end
		return v
	end
	return lost(sides[1]), lost(sides[2])
end

-- Side a's trade (b's value destroyed / a's value lost) over every seed.
local function trade(a: { string }, b: { string }, kind: string): number
	local lostA, lostB = 0, 0
	for seed = 1, SEEDS do
		local la, lb = play(Scenes.trial(a, b, kind, seed))
		lostA += la
		lostB += lb
	end
	if lostA == 0 then
		return if lostB > 0 then math.huge else 1
	end
	return lostB / lostA
end

local function fmt(x: number): string
	if x == math.huge then
		return "∞"
	end
	return string.format("%.2f", x)
end

local lines: { string } = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

local function wanted(role: string): boolean
	return FILTER == nil or string.find(string.lower(role), string.lower(FILTER), 1, true) ~= nil
end

local DUELS = {
	{ "T1 tank", "ord_lancer", "chs_ravager" },
	{ "T2 tank", "ord_paladin", "chs_juggernaut" },
	{ "T1 artillery", "ord_verdict", "chs_hellmouth" },
	{ "T2 MLRS", "ord_judgement", "chs_hydra" },
	{ "T1 fighter", "ord_falcon", "chs_harpy" },
	{ "T2 fighter", "ord_archon", "chs_manticore" },
	{ "Scout", "ord_herald", "chs_jackal" },
}

local inBand, total = 0, 0
local failures: { string } = {}

out(string.format("### Shared roles that fight each other (%d seed(s); trade > 1 favours Order)", SEEDS))
out("")
out("| Role | Order / Chaos | close | long | defend | flank | overall | in band | Order wins its condition | Chaos wins its condition |")
out("|---|---|---|---|---|---|---|---|---|---|")
for _, r in DUELS do
	local role, o, c = r[1], r[2], r[3]
	if not wanted(role) then
		continue
	end
	local close = trade({ o }, { c }, "close")
	local long = trade({ o }, { c }, "long")
	local defend = trade({ o }, { c }, "defend")
	local flank = trade({ o }, { c }, "flank")
	local overall = math.sqrt(math.min(close, 1e6) * math.min(long, 1e6))
	local band = overall >= 0.8 and overall <= 1.25
	local oWins = long >= 1.25 or defend >= 1.25
	local cWins = close <= 0.8 or flank <= 0.8
	total += 1
	if band then
		inBand += 1
	else
		table.insert(failures, `{role}: overall {fmt(overall)}`)
	end
	if not oWins then
		table.insert(failures, `{role}: Order doesn't win its condition (long {fmt(long)}, defend {fmt(defend)})`)
	end
	if not cWins then
		table.insert(failures, `{role}: Chaos wins neither close ({fmt(close)}) nor on the flank ({fmt(flank)})`)
	end
	out(string.format("| %s | %s / %s | %s | %s | %s | %s | **%s** | %s | %s | %s |", role, defs.units[o].name, defs.units[c].name, fmt(close), fmt(long), fmt(defend), fmt(flank), fmt(overall), if band then "yes" else "**no**", if oWins then "yes" else "**no**", if cWins then "yes" else "**no**"))
end

local HOLDERS = {
	{ "Mobile IR SAM", "ord_halo", "chs_hornet" },
	{ "IR SAM site", "ord_vigil", "chs_thorn" },
	{ "Mobile radar SAM", "ord_seraph", "chs_gorgon" },
	{ "Radar SAM site", "ord_aegis", "chs_wyvern" },
}
local RAIDS = {
	heavy = { "ord_absolution", "chs_plague" },
	swarm = { "ord_guardian", "chs_wasp" },
}

out("")
out("### SAMs: each version against the same raid (defend; the raid's value destroyed / own value lost)")
out("")
out("| Role | Order / Chaos | heavy: Order | heavy: Chaos | swarm: Order | swarm: Chaos | Order / Chaos overall | in band | Order better vs heavy | Chaos better vs swarm |")
out("|---|---|---|---|---|---|---|---|---|---|")
for _, r in HOLDERS do
	local role, o, c = r[1], r[2], r[3]
	if not wanted(role) then
		continue
	end
	local ho, hc = trade({ o }, RAIDS.heavy, "defend"), trade({ c }, RAIDS.heavy, "defend")
	local so, sc = trade({ o }, RAIDS.swarm, "defend"), trade({ c }, RAIDS.swarm, "defend")
	local function ratio(x: number, y: number): number
		return math.min(x, 1e3) / math.max(math.min(y, 1e3), 1e-3)
	end
	local overall = math.sqrt(ratio(ho, hc) * ratio(so, sc))
	local band = overall >= 0.8 and overall <= 1.25
	local oWins = ratio(ho, hc) >= ratio(so, sc)
	local cWins = ratio(so, sc) <= 1
	total += 1
	if band then
		inBand += 1
	else
		table.insert(failures, `{role}: Order / Chaos {fmt(overall)}`)
	end
	out(string.format("| %s | %s / %s | %s | %s | %s | %s | **%s** | %s | %s | %s |", role, defs.units[o].name, defs.units[c].name, fmt(ho), fmt(hc), fmt(so), fmt(sc), fmt(overall), if band then "yes" else "**no**", if oWins then "yes" else "no", if cWins then "yes" else "no"))
end

local EMPLACEMENTS = { { "Artillery emplacement", "ord_edict", "chs_cataclysm" } }
local ASSAULT = { "ord_lancer", "chs_ravager", "ord_paladin", "chs_juggernaut" }
out("")
out("### Artillery emplacements: each version against the same tank assault (defend)")
out("")
out("| Role | Order / Chaos | Order | Chaos | Order / Chaos | in band |")
out("|---|---|---|---|---|---|")
for _, r in EMPLACEMENTS do
	local role, o, c = r[1], r[2], r[3]
	if not wanted(role) then
		continue
	end
	local to, tc = trade({ o }, ASSAULT, "defend"), trade({ c }, ASSAULT, "defend")
	local ratio = math.min(to, 1e3) / math.max(math.min(tc, 1e3), 1e-3)
	local band = ratio >= 0.8 and ratio <= 1.25
	total += 1
	if band then
		inBand += 1
	else
		table.insert(failures, `{role}: Order / Chaos {fmt(ratio)}`)
	end
	out(string.format("| %s | %s / %s | %s | %s | **%s** | %s |", role, defs.units[o].name, defs.units[c].name, fmt(to), fmt(tc), fmt(ratio), if band then "yes" else "**no**"))
end

-- Faction-only units (S-64, S-75): report only, no band. Each line: the
-- Order side's trade (Chaos value destroyed / Order value lost).
local SPECIALS = {
	{ "Locust swarm against Lancers", { "ord_lancer" }, { "chs_locust" }, { "close", "long", "flank" } },
	{ "Warden holding against Ravagers", { "ord_warden" }, { "chs_ravager" }, { "defend" } },
	{ "Citadel holding against a tank assault", { "ord_citadel" }, { "chs_ravager", "chs_juggernaut" }, { "defend" } },
	{ "Citadel holding against Cyclops siege mortars with a Watcher radar", { "ord_citadel" }, { "chs_cyclops", "chs_watcher" }, { "defend" } },
	{ "Citadel holding against Minotaurs", { "ord_citadel" }, { "chs_minotaur" }, { "defend" } },
}
out("")
out("### Faction-only units (report only; the Order side's trade)")
out("")
out("| Matchup | Starts | Trade |")
out("|---|---|---|")
for _, sp in SPECIALS do
	if not wanted(sp[1]) then
		continue
	end
	local parts = {}
	for _, kind in sp[4] do
		table.insert(parts, `{kind} {fmt(trade(sp[2], sp[3], kind))}`)
	end
	out(string.format("| %s | %s | %s |", sp[1], table.concat(sp[4], ", "), table.concat(parts, "; ")))
end

-- The match-shaped trial (S-91; next.md item 1a): waves against a rallied
-- defender with a turret, both directions. Report only.
out("")
out("### Match-shaped: waves against a rallied defender with a turret (report only; the Order side's trade)")
out("")
out("| Attacker | 1 wave | 4 waves | 8 waves | base fell (1 / 4 / 8) |")
out("|---|---|---|---|---|")
if wanted("match") or FILTER == nil then
	for _, attacker in { "order", "chaos" } do
		local parts, fell = {}, {}
		for _, waves in { 1, 4, 8 } do
			local lostO, lostC, falls = 0, 0, 0
			for seed = 1, SEEDS do
				local scene = Scenes.waves(attacker, waves, seed)
				local lo, lc = play(scene)
				lostO += lo
				lostC += lc
				local base = scene.base :: { number }
				local standing = 0
				for _, id in base do
					if scene.sim.world.slot[id] then
						standing += 1
					end
				end
				if standing == 0 then
					falls += 1
				end
			end
			table.insert(parts, fmt(if lostO > 0 then lostC / lostO else math.huge))
			table.insert(fell, `{falls}/{SEEDS}`)
		end
		out(string.format("| %s | %s | %s |", if attacker == "order" then "Order attacks" else "Chaos attacks", table.concat(parts, " | "), table.concat(fell, " / ")))
	end
end

out("")
out(string.format("**%d of %d roles in band.**", inBand, total))
for _, f in failures do
	out("- " .. f)
end

fs.writeFile("debug_out/factions.md", table.concat(lines, "\n") .. "\n")
