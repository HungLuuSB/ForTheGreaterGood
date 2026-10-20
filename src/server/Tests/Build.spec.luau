--!strict
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function build(sim: Sim.Sim, ids: { number }, defId: string, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = ids, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
end

-- Steps until `pred` holds (returns the tick) or `limit` ticks pass (nil).
-- `onTick` sees each tick's events.
local function runUntil(sim: Sim.Sim, limit: number, pred: () -> boolean, onTick: ((Sim.Sim) -> ())?): number?
	for _ = 1, limit do
		Sim.step(sim)
		if onTick then
			onTick(sim)
		end
		if pred() then
			return sim.tick
		end
	end
	return nil
end

local function events(sim: Sim.Sim, kind: string): { Combat.Event }
	local out = {}
	for _, e in sim.combat.events do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- Enough income that factory tests measure production, not a power stall:
-- a Command Vehicle and two generators parked in a corner (+60 power/s).
local function fund(sim: Sim.Sim)
	Spawn.unit(sim, "ord_sovereign", 1, -200, -200)
	Spawn.unit(sim, "ord_generator", 1, -230, -230)
	Spawn.unit(sim, "ord_generator", 1, -230, -200)
end

local function newStart(): (Sim.Sim, number, number, number)
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
	local start = (sim.map :: any).layers.starts[1]
	local cv = Spawn.unit(sim, "ord_sovereign", 1, start[1], start[2], math.pi / 2)
	return sim, cv, start[1], start[2]
end

-- Time for `ids` to build a generator 60 studs east of the start.
local function generatorTime(withMason: boolean): number
	local sim, cv, sx, sz = newStart()
	local ids = { cv }
	if withMason then
		table.insert(ids, Spawn.unit(sim, "ord_mason", 1, sx, sz + 20, math.pi / 2))
	end
	build(sim, ids, "ord_generator", sx + 60, sz)
	local frame = 0
	local done = runUntil(sim, 2000, function()
		return frame ~= 0 and sim.world.buildProgress[frame] == 1
	end, function(s)
		for _, e in events(s, "BUILD_START") do
			frame = e.unit
		end
	end)
	return done :: number
end

return function(t: RunAll.Context)
	t.test("the Command Vehicle drives over and builds a generator that then produces", function()
		local sim, cv, sx, sz = newStart()
		local acc = sim.eco.accounts[1]
		build(sim, { cv }, "ord_generator", sx + 60, sz)
		local frame, started, maxDist = 0, 0, 0
		local w = sim.world
		local done = runUntil(sim, 2000, function()
			return frame ~= 0 and w.buildProgress[frame] == 1
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame, started = e.unit, s.tick
			end
			if frame ~= 0 then
				maxDist = math.max(maxDist, math.abs(w.posX[cv] - w.posX[frame]))
			end
			t.expect(acc.supply.stored >= 0 and acc.power.stored >= 0, "stored never negative")
		end)
		t.expect(done ~= nil, "the generator was finished")
		local d = sim.defs.units.ord_generator
		-- 1,200 work units at BP 300 = 4 s = 60 ticks of building (no stall at 1,000 supply)
		t.expect(math.abs((done :: number) - started - 60) <= 2, `build took {(done :: number) - started} ticks`)
		t.equal(w.health[frame], d.health, "health grows to full with progress")
		t.expect(maxDist <= 80 + 4 + 1, "the CV stayed within build range")
		Sim.step(sim) -- (economy step comes at the next multiple of 5)
		for _ = 1, 5 do
			Sim.step(sim)
		end
		t.equal(acc.power.income, 20 + 20, "CV + new generator")
	end)

	t.test("assisting builders add their build power", function()
		local alone = generatorTime(false)
		local helped = generatorTime(true)
		t.expect(helped < alone, `with a Mason {helped} ticks vs alone {alone}`)
	end)

	t.test("a stalled team builds slower and never overspends", function()
		local function vehplantTicks(startSupply: number): (number?, boolean)
			local sim, cv, sx, sz = newStart()
			local acc = sim.eco.accounts[1]
			acc.supply.stored = startSupply
			build(sim, { cv }, "ord_vehplant", sx + 70, sz)
			local frame = 0
			local neverNegative = true
			local done = runUntil(sim, 9000, function()
				return frame ~= 0 and sim.world.buildProgress[frame] == 1
			end, function(s)
				for _, e in events(s, "BUILD_START") do
					frame = e.unit
				end
				neverNegative = neverNegative and acc.supply.stored >= 0 and acc.power.stored >= 0
			end)
			return done, neverNegative
		end
		local fullTicks, ok1 = vehplantTicks(1000)
		local starvedTicks, ok2 = vehplantTicks(50)
		t.expect(fullTicks ~= nil and starvedTicks ~= nil, "both plants were finished")
		t.expect(ok1 and ok2, "stored never went negative")
		t.expect((starvedTicks :: number) > (fullTicks :: number) * 2, `starved {starvedTicks} vs full {fullTicks}`)
		-- 600 supply at 1 supply/s income (+50 start) can't finish before ~550 s
		t.expect((starvedTicks :: number) > 15 * 500, "progress was limited by income")
	end)

	t.test("invalid sites fail with a reason", function()
		local sim, cv, sx, sz = newStart()
		build(sim, { cv }, "ord_extractor", sx + 30, sz) -- no deposit there
		local reason = nil
		runUntil(sim, 600, function()
			return reason ~= nil
		end, function(s)
			for _, e in events(s, "BUILD_FAILED") do
				reason = e.reason
			end
		end)
		t.equal(reason, "no deposit")
	end)

	t.test("factories produce their queue in order and units roll out", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2) -- exit faces +X
		build(sim, { plant }, "ord_lancer", 0, 0)
		build(sim, { plant }, "ord_mason", 0, 0)
		local produced = {}
		runUntil(sim, 3000, function()
			return #produced == 2
		end, function(s)
			for _, e in events(s, "PRODUCED") do
				table.insert(produced, { tick = s.tick, unit = e.unit })
			end
		end)
		t.equal(#produced, 2)
		local w = sim.world
		t.equal(w.defIndex[produced[1].unit], sim.defs.units.ord_lancer.index, "first in queue first out")
		t.equal(w.defIndex[produced[2].unit], sim.defs.units.ord_mason.index)
		-- 4,500 work units at BP 100 = 45 s = 675 ticks
		t.expect(math.abs(produced[1].tick - 675) <= 3, `lancer finished at tick {produced[1].tick}`)
		for _ = 1, 60 do
			Sim.step(sim)
		end
		t.expect(w.posX[produced[1].unit] > 12 + 8, "the new tank drove out of the plant")
		t.expect(not Passability.canEnter(sim.map :: any, "TRACKED", (sim.map :: any).grid:index(32, 32)), "the plant blocks its cells")
	end)

	t.test("a builder assisting a factory speeds up production", function()
		local function firstLancer(assist: boolean): number
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			fund(sim)
			local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
			if assist then
				local cv = Spawn.unit(sim, "ord_sovereign", 1, -40, 0)
				submit(sim, 1, { cmdType = CT.REPAIR, flags = 0, unitIds = { cv }, targetId = plant })
			end
			build(sim, { plant }, "ord_lancer", 0, 0)
			local tick = 0
			runUntil(sim, 3000, function()
				return tick ~= 0
			end, function(s)
				for _ in events(s, "PRODUCED") do
					tick = s.tick
				end
			end)
			return tick
		end
		local alone, helped = firstLancer(false), firstLancer(true)
		t.expect(alone > 0 and helped > 0, "both produced")
		t.expect(helped < alone / 2, `assisted {helped} vs alone {alone} ticks (BP 100 + 300)`)
	end)

	t.test("reclaiming a wreck returns its supply", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local victim = Spawn.unit(sim, "chs_ravager", 2, 40, 0)
		sim.world.health[victim] = 1
		Combat.queueDamage(sim.combat, victim, 100, 0) -- low overkill: leaves a wreck
		Sim.step(sim)
		local wreck = sim.combat.wreckIds[1]
		t.expect(wreck ~= nil, "a wreck")
		local value = sim.combat.wreckSupply[wreck]
		t.equal(value, 130 * 0.5)
		local mason = Spawn.unit(sim, "ord_mason", 1, -20, 0)
		local acc = sim.eco.accounts[1]
		acc.supply.stored = 0
		submit(sim, 1, { cmdType = CT.RECLAIM, flags = 0, unitIds = { mason }, targetId = wreck })
		local done = runUntil(sim, 600, function()
			return sim.combat.wreckX[wreck] == nil
		end)
		t.expect(done ~= nil, "the wreck was reclaimed")
		for _ = 1, 5 do
			Sim.step(sim) -- settle the window
		end
		t.expect(math.abs(acc.supply.stored - value) < 1e-6, `stored {acc.supply.stored}, expected {value}`)
		t.equal(#sim.combat.wreckIds, 0)
	end)

	t.test("a frame destroyed mid-build frees its footprint and its builders", function()
		local sim, cv, sx, sz = newStart()
		build(sim, { cv }, "ord_vehplant", sx + 70, sz)
		local frame = 0
		runUntil(sim, 600, function()
			return frame ~= 0 and sim.world.buildProgress[frame] > 0.1
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame = e.unit
			end
		end)
		local pm = sim.map :: any
		local cell = pm.grid:index(pm.grid:cellAt(sim.world.posX[frame], sim.world.posZ[frame]))
		t.equal(Passability.occupant(pm, cell), frame)
		Combat.queueDamage(sim.combat, frame, 1e6, 0)
		Sim.step(sim)
		Sim.step(sim)
		t.equal(Passability.occupant(pm, cell), 0, "footprint released")
		t.equal(sim.build.target[cv], 0, "the CV stopped building")
	end)

	t.test("construction is deterministic", function()
		local function run(): number
			local sim, cv, sx, sz = newStart()
			build(sim, { cv }, "ord_generator", sx + 60, sz)
			for _ = 1, 400 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)
end
