--!strict
-- SAM readiness under helicopter raids (S-66): lune run sam_raids [minutes] [seeds]
-- A Normal AI (each faction) on skirmish:192 against scripted raids: from
-- minute 4, every minute, N enemy attack helicopters spawn at the far side
-- and attack-move at the AI's home (the enemy player builds nothing). For
-- missile-refill priority off (Economy.REFILL_PRIORITY 0) and on (0.25):
--   empty     share of SAM-ticks with a target in which the SAM had no missile
--   stalled   share of economy steps with the power ratio below 1
--   fired     SAM missiles launched; down: helicopters shot down
--   lived     minutes the AI's Command Vehicle lasted (the limit if it did)
-- Report only.

local process = require("@lune/process")

local Economy = require("../src/server/Sim/Economy")
local Packer = require("../src/shared/Net/Packer")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")
local Spawn = require("../src/server/Sim/Spawn")
local World = require("../src/server/Sim/World")

local MINUTES = tonumber(process.args[1]) or 15
local SEEDS = tonumber(process.args[2]) or 2

local function run(faction: string, helis: number, priority: number, seed: number)
	Economy.REFILL_PRIORITY = priority
	local aiTeam = if faction == "order" then 1 else 2
	local enemyTeam = if faction == "order" then 2 else 1
	local sim = Sim.new({
		seed = seed,
		players = { { id = 1, team = aiTeam }, { id = 2, team = enemyTeam } },
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS", ai = { [1] = "normal" } },
	})
	local brain = Skirmish.new(sim, 1, "normal")
	local w = sim.world
	local heliDef = if enemyTeam == 1 then "ord_guardian" else "chs_wasp"
	local g = (sim.map :: any).grid
	local samTicks, emptyTicks, steps, stalled, fired, down = 0, 0, 0, 0, 0, 0
	local raiders: { [number]: boolean } = {}
	local cvDied: number? = nil
	for tick = 1, MINUTES * 900 do
		Skirmish.tick(brain)
		if tick >= 4 * 900 and tick % 900 == 0 then
			local ids = {}
			for i = 1, helis do
				local x = -brain.homeX * 0.9
				local id = Spawn.unit(sim, heliDef, 2, x, brain.homeZ + (i - (helis + 1) / 2) * 30, 0)
				raiders[id] = true
				table.insert(ids, id)
			end
			local cell, ox, oz = g:encode(brain.homeX, brain.homeZ)
			local wr = Packer.Writer.new()
			Schema.encodeCommand(wr, { cmdType = Schema.CmdType.FIGHT, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
			assert(Sim.submit(sim, 2, wr:finish()))
		end
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and w.owner[e.unit] == 1 and w.wStock[World.slotKey(e.unit, e.slot :: number)] ~= nil then
				fired += 1
			elseif e.kind == "DEATH" and raiders[e.unit] then
				down += 1
				raiders[e.unit] = nil
			end
		end
		for _, id in w.ids do
			if w.owner[id] == 1 then
				for slot = 1, w.weaponCount[id] do
					local key = World.slotKey(id, slot)
					local stock = w.wStock[key]
					if stock ~= nil and w.wTarget[key] ~= 0 then
						samTicks += 1
						if stock == 0 then
							emptyTicks += 1
						end
					end
				end
			end
		end
		if tick % 5 == 0 then
			steps += 1
			if sim.eco.accounts[aiTeam].power.ratio < 1 then
				stalled += 1
			end
		end
		if sim.match.eliminated[1] ~= nil then
			cvDied = tick
			break
		end
	end
	return {
		empty = if samTicks > 0 then emptyTicks / samTicks else 0,
		stalled = stalled / math.max(steps, 1),
		fired = fired,
		down = down,
		lived = (cvDied or MINUTES * 900) / 900,
	}
end

print(string.format("SAM readiness under helicopter raids: Normal AI on skirmish:192, %d min, %d seed(s)", MINUTES, SEEDS))
print("| Faction | Helicopters / min | Priority | Empty with a target | Stalled | Missiles | Shot down | Lived (min) |")
print("|---|---|---|---|---|---|---|---|")
for _, faction in { "order", "chaos" } do
	for _, helis in { 2, 4 } do
		for _, priority in { 0, 0.25 } do
			local e, s, f, d, l = 0, 0, 0, 0, 0
			for seed = 1, SEEDS do
				local r = run(faction, helis, priority, seed)
				e += r.empty
				s += r.stalled
				f += r.fired
				d += r.down
				l += r.lived
			end
			print(string.format("| %s | %d | %s | %.0f%% | %.0f%% | %.0f | %.0f | %.1f |", faction, helis, if priority > 0 then "on (0.25)" else "off", e / SEEDS * 100, s / SEEDS * 100, f / SEEDS, d / SEEDS, l / SEEDS))
		end
	end
end
