--!strict
-- Why does the skirmish AI give up build sites (next.md item 3, S-161)?
--   lune run debug_giveups [minutes] [seeds] [mapFilter]
-- Plays mirror AI matches (normal and hard, both factions) and prints each
-- give-up (Skirmish.giveUpHook: 20 s without getting closer to a site) with
-- what stood around it: the builder's speed and move order, whether a flow
-- field from the builder reaches the site's range, what is on the site,
-- and the units nearest the builder.

local process = require("@lune/process")

local Passability = require("../src/shared/Grid/Passability")
local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")
local Placement = require("../src/server/Sim/Placement")

local MINUTES = tonumber(process.args[1]) or 12
local SEEDS = tonumber(process.args[2]) or 2
local FILTER = process.args[3]

local total, matches = 0, 0
local causes: { [string]: number } = {}

local function describe(sim: Sim.Sim, id: number): string
	local w = sim.world
	return `{sim.defs.unitByIndex[w.defIndex[id]].id}#{id}`
end

Skirmish.giveUpHook = function(brain: any, id: number, o: any, d: number, best: number)
	local sim: Sim.Sim = brain.sim
	local w = sim.world
	local g = (sim.map :: Passability.PassMap).grid
	local bd = sim.defs.unitByIndex[w.defIndex[id]]
	local sd = sim.defs.unitByIndex[o.defIndex]
	local ok, why = Placement.check(sim, sd, o.x, o.z, w.owner[id])
	-- what stands within 3 cells of the builder: structures and units
	local near: { string } = {}
	local blockers = 0
	for _, other in w.ids do
		if other ~= id then
			local dx, dz = w.posX[other] - w.posX[id], w.posZ[other] - w.posZ[id]
			if dx * dx + dz * dz < 24 * 24 then
				blockers += 1
				if #near < 5 then
					table.insert(near, `{describe(sim, other)}@{math.floor(math.sqrt(dx * dx + dz * dz))}`)
				end
			end
		end
	end
	local moving = w.orderId[id] ~= 0
	local cause = if not ok then `site invalid ({why})`
		elseif not moving then "builder not moving"
		elseif (w.speed[id] or 0) < 1 then "builder stuck (moving order, no speed)"
		else "builder moving but no closer"
	causes[cause] = (causes[cause] or 0) + 1
	total += 1
	local cx, cz = g:cellAt(w.posX[id], w.posZ[id])
	print(string.format("  t=%5.1f min p%d %s -> %s at (%.0f, %.0f): %.0f studs away (best %.0f, range %s), speed %.1f, order %d, cell (%d, %d) clearance %d; %s; near: %s",
		sim.tick / 900, w.owner[id], describe(sim, id), sd.id, o.x, o.z, d, best, tostring(bd.buildRange), w.speed[id] or 0, w.orderId[id],
		cx, cz, Passability.clearance(sim.map :: any, bd.moveClass, g:index(cx, cz)), cause, table.concat(near, ", ")))
end

for _, mapId in { "map:ridgeline", "map:coastline", "map:twin_lakes", "map:canyon" } do
	if FILTER and not string.find(mapId, FILTER, 1, true) then
		continue
	end
	for seed = 1, SEEDS do
		for _, level in { "normal", "hard" } do
			local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 } }
			local ai = { [1] = level, [2] = level }
			if mapId == "map:twin_lakes" then
				players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 }, { id = 4, team = 4, allyTeam = 2 } }
				ai = { [1] = level, [2] = level, [3] = level, [4] = level }
			end
			local sim = Sim.new({ seed = seed, players = players, mapId = mapId, scenario = "standard_start", match = { mode = if #players == 4 then "TEAM" else "FFA", win = "COMMAND_ENDS", ai = ai } })
			local brains = Skirmish.forMatch(sim)
			print(`{mapId} seed {seed} {level}:`)
			for _ = 1, MINUTES * 900 do
				for _, b in brains do
					Skirmish.tick(b)
				end
				Sim.step(sim)
				if sim.match.over then
					break
				end
			end
			matches += 1
		end
	end
end

print(`\n{total} give-ups in {matches} matches of up to {MINUTES} min:`)
for cause, n in causes do
	print(`  {n}  {cause}`)
end
