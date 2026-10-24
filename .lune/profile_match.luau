--!strict
-- Headless copy of client-B's Studio watchdog run (S-164; client request 65):
--   lune run profile_match [minutes] [seed] [mapId] [income]
-- 4 Hard AI FFA on Twin Lakes (default seed 13), `income` (default 100)
-- supply and power a second for every team (the `income all` cheat), one
-- spectator. Per system: ticks over its guide 18.1 budget, the median when
-- over, and the five worst ticks with what happened in them (units, deaths,
-- structure deaths, commands applied; with --parts, Nav work units and
-- the time in a few functions). Lune is not a live
-- server: compare shapes with the Studio run, not milliseconds.

local process = require("@lune/process")

local Lifecycle = require("../src/server/Sim/Lifecycle")
local NetOut = require("../src/server/Sim/NetOut")
local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")

local MINUTES = tonumber(process.args[1]) or 15
local SEED = tonumber(process.args[2]) or 13
local MAP = process.args[3] or "map:twin_lakes"
local INCOME = tonumber(process.args[4]) or 100

local BUDGETS = {
	{ "Sim.Commands", 1 },
	{ "Sim.Economy", 1 },
	{ "Sim.Sensors", 5 },
	{ "Sim.Targeting", 8 },
	{ "Sim.Pathing", 8 },
	{ "Sim.Movement", 10 },
	{ "Sim.Weapons", 5 },
	{ "Sim.Projectiles", 4 },
	{ "Sim.Damage", 2 },
	{ "Sim.Construction", 1.5 },
	{ "Sim.Match", 0.5 },
	{ "Sim.NetOut", 6 },
}

local players, ai = {}, {}
for p = 1, 4 do
	table.insert(players, { id = p, team = p, allyTeam = p })
	ai[p] = "hard"
end
local sim = Sim.new({ seed = SEED, players = players, mapId = MAP, scenario = "standard_start", match = { mode = "FFA", win = "COMMAND_ENDS", ai = ai } })
for p = 1, 4 do
	local acc = sim.eco.accounts[p]
	acc.supply.bonusIncome = INCOME
	acc.power.bonusIncome = INCOME
end
NetOut.addSpectator(sim)
local brains = Skirmish.forMatch(sim)
local timing = Sim.enableTiming(sim)

-- `--parts`: time a few functions inside the systems, per tick (module
-- fields only: calls through a local reference aren't seen)
local PARTS = table.find(process.args, "--parts") ~= nil
local part: { [string]: number } = {}
local partCount: { [string]: number } = {}
local function wrap(mod: any, modName: string, name: string)
	local f = mod[name]
	local key = `{modName}.{name}`
	part[key], partCount[key] = 0, 0
	mod[name] = function(...)
		local t0 = os.clock()
		local a, b, c, d, e, f2, g = f(...)
		part[key] += os.clock() - t0
		partCount[key] += 1
		return a, b, c, d, e, f2, g
	end
end
if PARTS then
	wrap(require("../src/server/Sim/Nav"), "Nav", "issueMove")
	wrap(require("../src/server/Sim/Nav"), "Nav", "terrainChanged")
	wrap(require("../src/server/Sim/Nav"), "Nav", "tree")
	wrap(require("../src/server/Sim/Path/Quadtree"), "Quadtree", "computeComponents")
	wrap(require("../src/server/Sim/Path/Quadtree"), "Quadtree", "update")
	wrap(require("../src/shared/Grid/Passability"), "Passability", "updateRect")
	wrap(require("../src/shared/Grid/Passability"), "Passability", "clearOccupied")
	wrap(require("../src/server/Sim/Orders"), "Orders", "autoStep")
	wrap(require("../src/server/Sim/Orders"), "Orders", "give")
	wrap(require("../src/server/Sim/Lifecycle"), "Lifecycle", "remove")
	wrap(require("../src/server/Sim/Placement"), "Placement", "release")
end

type Row = { tick: number, ms: number, units: number, deaths: number, structures: number, commands: number, parts: string?, work: number }
local worst: { [string]: { Row } } = {}
local over: { [string]: { number } } = {}
for _, b in BUDGETS do
	worst[b[1]] = {}
	over[b[1]] = {}
end
local peakUnits, lastApplied, lastWork = 0, 0, 0
local removedStructures = 0
table.insert(Lifecycle.removalHooks, function(s: any, id: number)
	if s.defs.unitByIndex[s.world.defIndex[id]].domain == "structure" then
		removedStructures += 1
	end
end)
for _ = 1, MINUTES * 900 do
	for _, b in brains do
		Skirmish.tick(b)
	end
	Sim.step(sim)
	local units = #sim.world.ids
	peakUnits = math.max(peakUnits, units)
	local deaths = 0
	for _, e in sim.combat.events do
		if e.kind == "DEATH" then
			deaths += 1
		end
	end
	local structures = removedStructures
	removedStructures = 0
	local partText: string? = nil
	if PARTS then
		local keys = {}
		for k in part do
			table.insert(keys, k)
		end
		table.sort(keys)
		local bits = {}
		for _, k in keys do
			if part[k] > 0.0002 then
				table.insert(bits, string.format("%s %.1fx%d", k, part[k] * 1000, partCount[k]))
			end
			part[k], partCount[k] = 0, 0
		end
		partText = table.concat(bits, ", ")
	end
	local applied = sim.stats.commandsApplied - lastApplied
	lastApplied = sim.stats.commandsApplied
	local work = (sim.nav :: any).stats.workUnits - lastWork
	lastWork = (sim.nav :: any).stats.workUnits
	for _, b in BUDGETS do
		local name, budget = b[1], b[2]
		local ms = (timing.last[name] or 0) * 1000
		if ms > budget then
			table.insert(over[name], ms)
		end
		local list = worst[name]
		if #list < 5 or ms > list[#list].ms then
			table.insert(list, { tick = sim.tick, ms = ms, units = units, deaths = deaths, structures = structures, commands = applied, parts = partText, work = work })
			table.sort(list, function(a, c)
				return a.ms > c.ms
			end)
			if #list > 5 then
				table.remove(list)
			end
		end
	end
	if sim.match.over then
		break
	end
end

print(`{MAP} seed {SEED}, 4 hard AI, +{INCOME} income: {sim.tick} ticks ({math.floor(sim.tick / 90) / 10} min), peak {peakUnits} units`)
print("system            budget  over   median-over  worst ticks (ms @tick: units, deaths, structure deaths, commands)")
for _, b in BUDGETS do
	local name, budget = b[1], b[2]
	local o = over[name]
	table.sort(o)
	local median = if #o > 0 then o[(#o + 1) // 2] else 0
	local parts = {}
	for _, r in worst[name] do
		table.insert(parts, string.format("%.1f@%d: %d, %d, %d, %d", r.ms, r.tick, r.units, r.deaths, r.structures, r.commands))
	end
	print(string.format("%-17s %5.1f  %5d   %6.2f      %s", name, budget, #o, median, table.concat(parts, " | ")))
	if PARTS and (name == "Sim.Commands" or name == "Sim.Damage" or name == "Sim.Pathing" or name == "Sim.Construction") then
		for _, r in worst[name] do
			print(string.format("      %.1f@%d: nav work %d; %s", r.ms, r.tick, r.work, r.parts or ""))
		end
	end
end
