--!strict
local Packer = require("@shared/Net/Packer")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function step(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

-- Recounts every map from scratch: each complete unit's circles at the cell
-- it was stamped at (Sensors run before Movement in a tick, so after a step
-- the stamp may trail the position by up to one tick of movement; that is
-- checked separately). Returns the first mismatch, or nil.
local function bruteMismatch(sim: Sim.Sim): string?
	local s = sim.sensors
	local w = sim.world
	local expected: { [number]: { [string]: { [number]: number } } } = {}
	for _, team in s.teams do
		expected[team] = {}
		for _, kind in Sensors.KINDS do
			expected[team][kind] = {}
		end
	end
	for _, id in w.ids do
		if w.buildProgress[id] < 1 then
			continue
		end
		local sensors = sim.defs.unitByIndex[w.defIndex[id]].sensors
		local radii = { sensors.sight, sensors.airSight or sensors.sight * 1.5, sensors.radar, sensors.sonar, sensors.jam or 0 }
		local stamped = s.stampCell[id]
		if stamped == nil then
			return `unit {id} is complete but not stamped`
		end
		local cx, cz = stamped % s.width, stamped // s.width
		local px, pz = Sensors.cellOf(s, w.posX[id], w.posZ[id])
		if math.abs(px - cx) > 1 or math.abs(pz - cz) > 1 then
			return `unit {id} stamped at ({cx}, {cz}) but stands in ({px}, {pz})`
		end
		for k, kind in Sensors.KINDS do
			if radii[k] > 0 then
				local c = Sensors.circle(radii[k])
				for i = 1, #c, 2 do
					local x, z = cx + c[i], cz + c[i + 1]
					if x >= 0 and z >= 0 and x < s.width and z < s.depth then
						local cell = z * s.width + x
						local m = expected[w.team[id]][kind]
						m[cell] = (m[cell] or 0) + 1
					end
				end
			end
		end
	end
	for _, team in s.teams do
		for _, kind in Sensors.KINDS do
			for cell = 0, s.width * s.depth - 1 do
				local want = expected[team][kind][cell] or 0
				local got = Sensors.count(s, team, kind, cell)
				if got ~= want then
					return `team {team} {kind} cell {cell}: {got} vs {want}`
				end
			end
		end
	end
	return nil
end

return function(t: RunAll.Context)
	t.test("stamping matches a full recount while units move and die, and returns to zero", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local rng = Prng.new(77)
		local defs = { "ord_lancer", "chs_ravager", "ord_oracle", "chs_watcher" }
		local ids = {}
		for i = 1, 30 do
			local owner = if i % 2 == 0 then 1 else 2
			local id = Spawn.unit(sim, defs[rng:nextInteger(1, #defs)], owner, rng:nextNumber(-240, 240), rng:nextNumber(-240, 240))
			World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
			table.insert(ids, id)
		end
		for round = 1, 6 do
			for _, id in ids do
				if sim.world.slot[id] and rng:chance(0.5) then
					moveTo(sim, sim.world.owner[id], { id }, rng:nextNumber(-240, 240), rng:nextNumber(-240, 240))
				end
			end
			step(sim, 40)
			local mismatch = bruteMismatch(sim)
			t.equal(mismatch, nil, `round {round}`)
			if round == 3 then
				for i = 1, 10 do
					Combat.queueDamage(sim.combat, ids[i], 1e6, 0)
				end
			end
		end
		for _, id in sim.world.ids do
			Combat.queueDamage(sim.combat, id, 1e6, 0)
		end
		step(sim, 2)
		t.equal(#sim.world.ids, 0)
		local s = sim.sensors
		for _, team in s.teams do
			for _, kind in Sensors.KINDS do
				for cell = 0, s.width * s.depth - 1 do
					if Sensors.count(s, team, kind, cell) ~= 0 then
						t.expect(false, `team {team} {kind} not zero at cell {cell}`)
						return
					end
				end
			end
		end
	end)

	t.test("a unit walking past changes HIDDEN → VISIBLE → HIDDEN exactly at the sight circle", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local observer = Spawn.unit(sim, "ord_lancer", 1, -100, 0)
		local walker = Spawn.unit(sim, "chs_ravager", 2, 300, 40, -math.pi / 2)
		for _, id in { observer, walker } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		moveTo(sim, 2, { walker }, -340, 40)
		local s = sim.sensors
		local ocx, ocz = Sensors.cellOf(s, w.posX[observer], w.posZ[observer])
		local circle = Sensors.circle(110)
		local function inCircle(x: number, z: number): boolean
			local cx, cz = Sensors.cellOf(s, x, z)
			for i = 1, #circle, 2 do
				if ocx + circle[i] == cx and ocz + circle[i + 1] == cz then
					return true
				end
			end
			return false
		end
		local sequence = {}
		for _ = 1, 900 do
			Sim.step(sim)
			if sim.tick % 2 == 0 then -- sensors run on even ticks
				local level = Sensors.level(sim, 1, walker)
				local want = if inCircle(w.posX[walker], w.posZ[walker]) then L.VISIBLE else L.HIDDEN
				t.equal(level, want, `tick {sim.tick} at x = {w.posX[walker]}`)
				if sequence[#sequence] ~= level then
					table.insert(sequence, level)
				end
			end
		end
		t.deepEqual(sequence, { L.HIDDEN, L.VISIBLE, L.HIDDEN })
		t.equal(Sensors.level(sim, 2, walker), L.VISIBLE, "own units are always visible")
	end)

	t.test("structure ghosts persist out of sight and after death, until the spot is seen", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local scout = Spawn.unit(sim, "ord_lancer", 1, -60, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		local gen = Spawn.unit(sim, "chs_generator", 2, 0, 0)
		step(sim, 2)
		t.equal(Sensors.level(sim, 1, gen), L.VISIBLE)
		moveTo(sim, 1, { scout }, -330, 0)
		step(sim, 300)
		t.equal(Sensors.level(sim, 1, gen), L.GHOST, "out of sight: a ghost, not hidden")
		local ghost = sim.sensors.ghosts[1][gen]
		t.expect(ghost ~= nil and ghost.defIndex == sim.defs.units.chs_generator.index, "ghost keeps the type")
		Combat.queueDamage(sim.combat, gen, 1e6, 0)
		step(sim, 2)
		t.equal(Sensors.level(sim, 1, gen), L.GHOST, "destroyed unseen: the ghost stays")
		moveTo(sim, 1, { scout }, -40, 0)
		step(sim, 300)
		t.equal(Sensors.level(sim, 1, gen), L.HIDDEN, "seen empty: the ghost is gone")
		t.equal(sim.sensors.ghosts[1][gen], nil)
	end)

	t.test("radar reveals units beyond sight; unfinished frames emit nothing", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local radar = Spawn.unit(sim, "ord_oracle", 1, -400, 0)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 200, 0)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		step(sim, 2)
		t.equal(Sensors.level(sim, 1, enemy), L.RADAR, "600 studs away: radar contact")
		Combat.queueDamage(sim.combat, radar, 1e6, 0)
		step(sim, 2)
		t.equal(Sensors.level(sim, 1, enemy), L.HIDDEN, "radar gone")

		local s = sim.sensors
		local frame = World.spawn(w, sim.tick, { defIndex = sim.defs.units.ord_oracle.index, team = 1, owner = 1, x = 0, z = 300, health = 10, buildProgress = 0.5 })
		step(sim, 2)
		t.equal(s.stampCell[frame], nil, "an unfinished unit doesn't emit")
	end)
end
