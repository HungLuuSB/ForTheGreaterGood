--!strict
local Combat = require("../Sim/Combat/Combat")
local Economy = require("../Sim/Economy")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function near(t: RunAll.Context, a: number, b: number, what: string)
	t.expect(math.abs(a - b) < 1e-9, `{what}: expected {b}, got {a}`)
end

local function resource(stored: number, storage: number, income: number, demand: number, spent: number): Economy.Resource
	return { stored = stored, storage = storage, income = income, demand = demand, ratio = 1, spent = spent, reclaimed = 0, wasted = 0, gathered = 0, drawn = 0 }
end

local function step(sim: Sim.Sim, ticks: number)
	for _ = 1, ticks do
		Sim.step(sim)
	end
end

return function(t: RunAll.Context)
	t.test("settle: stored, storage cap, floor and ratio", function()
		local r = resource(100, 1000, 30, 0, 5)
		Economy.settle(r, 1 / 3)
		near(t, r.stored, 105, "stored + income × window − spent")
		t.equal(r.spent, 0, "window spend resets")
		t.equal(r.ratio, 1, "no demand → ratio 1")

		local full = resource(990, 1000, 60, 0, 0)
		Economy.settle(full, 1 / 3)
		t.equal(full.stored, 1000, "capped at storage")
		near(t, full.wasted, 10, "overflow is counted as wasted")

		local short = resource(10, 1000, 30, 120, 0)
		Economy.settle(short, 1 / 3)
		-- settled stored = 10 + 10 = 20; next window offers 20 + 10 = 30 of 40 wanted
		near(t, short.stored, 20, "stored after settling")
		near(t, short.ratio, 0.75, "stall ratio")
		local negative = resource(0, 1000, 0, 0, 3)
		Economy.settle(negative, 1 / 3)
		t.equal(negative.stored, 0, "never below zero")
	end)

	t.test("two-pass effective ratio uses only the resources a consumer needs", function()
		local acc: Economy.Account = { supply = resource(0, 1000, 0, 0, 0), power = resource(0, 1000, 0, 0, 0) }
		acc.supply.ratio = 0.4
		acc.power.ratio = 0.9
		near(t, Economy.effective(acc, 50, 500), 0.4, "both resources: the smaller ratio")
		near(t, Economy.effective(acc, 40, 0), 0.4, "supply only")
		near(t, Economy.effective(acc, 0, 100), 0.9, "power only")
		near(t, Economy.effective(acc, 0, 0), 1, "free")
		local r = resource(100, 1000, 30, 0, 40)
		near(t, Economy.allowance(r), 100 + 10 - 40, "allowance = stored + window income − spent")
	end)

	t.test("teams start with 1,000 / 1,000 and their own accounts", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		t.deepEqual(sim.eco.teams, { 1, 2 })
		for _, team in { 1, 2 } do
			local acc = sim.eco.accounts[team]
			t.equal(acc.supply.stored, 1000)
			t.equal(acc.power.stored, 1000)
			t.equal(acc.supply.storage, 1000)
		end
	end)

	t.test("income from the Command Vehicle, extractors on deposits and generators", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local layers = (sim.map :: any).layers
		local g = layers.grid
		local acc = sim.eco.accounts[1]
		acc.supply.stored, acc.power.stored = 0, 0
		local start = layers.starts[1]
		Spawn.unit(sim, "ord_sovereign", 1, start[1], start[2])
		-- a deposit cell around the west start, and an empty cell
		local sx, sz = g:cellAt(start[1], start[2])
		local dx, dz = g:cellCenter(sx + 4, sz + 4)
		Spawn.unit(sim, "ord_extractor", 1, dx, dz)
		local ex, ez = g:cellCenter(sx + 1, sz + 1)
		Spawn.unit(sim, "ord_extractor", 1, ex, ez) -- no deposit: produces nothing
		Spawn.unit(sim, "ord_generator", 1, start[1], start[2] - 40)
		step(sim, 15) -- three economy steps = 1 second
		near(t, acc.supply.income, 1 + 0.5 * 4, "CV 1 + extractor 0.5 × value 4")
		near(t, acc.power.income, 20 + 20, "CV 20 + generator 20")
		near(t, acc.supply.stored, 3, "1 s of supply income")
		near(t, acc.power.stored, 40, "1 s of power income")
		t.equal(acc.power.storage, 1100, "generator adds 100 power storage")
		t.equal(sim.eco.accounts[2].supply.income, 0, "the other team is untouched")
	end)

	t.test("a destroyed producer stops producing", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local gen = Spawn.unit(sim, "ord_generator", 1, 0, 0)
		step(sim, 5)
		t.equal(sim.eco.accounts[1].power.income, 20)
		Combat.queueDamage(sim.combat, gen, 10000, 0)
		step(sim, 5)
		t.equal(sim.eco.accounts[1].power.income, 0)
		t.equal(#sim.eco.producers, 0)
	end)

	t.test("economy state is part of the sim hash", function()
		local a = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local b = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		t.equal(Sim.hash(a), Sim.hash(b))
		b.eco.accounts[2].power.stored -= 1
		t.notEqual(Sim.hash(a), Sim.hash(b))
	end)

	t.test("wind changes every 30 s, seeded, and drives turbine income", function()
		local values, distinct = {}, 0
		for period = 0, 39 do
			local v = Economy.windAt(7, period * Economy.WIND_PERIOD)
			t.expect(v >= 0 and v <= 1, "wind in 0..1")
			t.equal(Economy.windAt(7, period * Economy.WIND_PERIOD + Economy.WIND_PERIOD - 1), v, "constant within a period")
			if not table.find(values, v) then
				distinct += 1
				table.insert(values, v)
			end
		end
		t.expect(distinct >= 30, `it changes ({distinct} distinct values in 40 periods)`)
		t.expect(Economy.windAt(7, 0) ~= Economy.windAt(8, 0), "another seed, other wind")

		local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:64" })
		Spawn.unit(sim, "ord_windmill", 1, 0, 0)
		Spawn.unit(sim, "ord_windmill", 1, 40, 0)
		local max = sim.defs.units.ord_windmill.wind.max
		for _, at in { 5, Economy.WIND_PERIOD + 5, 3 * Economy.WIND_PERIOD + 5 } do
			step(sim, at - sim.tick)
			near(t, sim.eco.accounts[1].power.income, 2 * max * Economy.windAt(7, sim.tick - (sim.tick % 5)), `turbine income at tick {sim.tick}`)
		end
	end)

	t.test("a converter turns spare power above half storage into supply, until switched off", function()
		local function run(off: boolean): (number, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
			local conv = Spawn.unit(sim, "ord_converter", 1, 0, 0)
			local acc = sim.eco.accounts[1]
			acc.supply.stored = 0 -- room for what is made
			if off then
				local w = Packer.Writer.new()
				Schema.encodeCommand(w, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { conv }, value = 0 })
				assert(Sim.submit(sim, 1, w:finish()))
			end
			step(sim, 300) -- 20 s
			return acc.power.stored, acc.supply.stored
		end
		local power, supply = run(false)
		local rate = 70 -- ord_converter: 70 power → 1 supply
		near(t, power, 500, "power burned down to the reserve (half of 1,000)")
		near(t, supply, 500 / rate, "and turned into supply at 70 : 1")
		local powerOff, supplyOff = run(true)
		near(t, powerOff, 1000, "switched off: no power burned")
		near(t, supplyOff, 0, "and no supply made")
	end)

	t.test("an advanced extractor upgrades your own extractor in place; others' or same-tier ones block", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local layers = (sim.map :: any).layers
		local g = layers.grid
		local w = sim.world
		local start = layers.starts[1]
		local sx, sz = g:cellAt(start[1], start[2])
		local dx, dz = g:cellCenter(sx + 4, sz + 4)
		local t1 = Spawn.unit(sim, "ord_extractor", 1, dx, dz)
		Spawn.unit(sim, "ord_generator", 1, start[1] - 60, start[2]) -- some power
		local builder = Spawn.unit(sim, "ord_architect", 1, dx - 30, dz)
		local Placement = require("../Sim/Placement")
		local ok, why = Placement.check(sim, sim.defs.units.ord_extractor, dx, dz, 1)
		t.expect(not ok and why == "occupied", "a second T1 extractor can't go on it")
		ok, why = Placement.check(sim, sim.defs.units.chs_advextractor, dx, dz, 2)
		t.expect(not ok and why == "occupied", "the other team can't upgrade it")
		local okUp, _, _, _, _, _, replaces = Placement.check(sim, sim.defs.units.ord_advextractor, dx, dz, 1)
		t.expect(okUp and replaces == t1, "its owner can upgrade it")
		local wcmd = Packer.Writer.new()
		local cell, ox, oz = g:encode(dx, dz)
		Schema.encodeCommand(wcmd, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = { builder }, defIndex = sim.defs.units.ord_advextractor.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
		assert(Sim.submit(sim, 1, wcmd:finish()))
		local started, frame = nil, 0
		for _ = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "BUILD_START" then
					started, frame = sim.tick, e.unit
				end
			end
			if started then
				break
			end
		end
		t.expect(started ~= nil, "the upgrade started")
		t.expect(w.slot[t1] ~= nil, "the T1 extractor works on under the frame (S-108)")
		local pm = sim.map :: Passability.PassMap
		local gx, gz = g:cellAt(dx, dz)
		t.equal(Passability.occupant(pm, g:index(gx, gz)), frame, "the frame holds the deposit")
		local done = false
		for _ = 1, 6000 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "BUILD_DONE" and e.unit == frame then
					done = true
				end
			end
			if done then
				break
			end
		end
		t.expect(done, "the advanced extractor finished")
		t.equal(w.slot[t1], nil, "the T1 went when the T2 was finished (S-108)")
		step(sim, 5)
		near(t, sim.eco.accounts[1].supply.income, 1.75 * 4, "advanced rate 1.75 × deposit value 4")
	end)
end
