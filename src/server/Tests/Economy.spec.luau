--!strict
local Combat = require("../Sim/Combat/Combat")
local Economy = require("../Sim/Economy")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function near(t: RunAll.Context, a: number, b: number, what: string)
	t.expect(math.abs(a - b) < 1e-9, `{what}: expected {b}, got {a}`)
end

local function resource(stored: number, storage: number, income: number, demand: number, spent: number): Economy.Resource
	return { stored = stored, storage = storage, income = income, demand = demand, ratio = 1, spent = spent, reclaimed = 0, wasted = 0 }
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
end
