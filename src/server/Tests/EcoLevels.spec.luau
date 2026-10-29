--!strict
-- The economy balance of S-198 (the user): extractors cost power to run;
-- the resource bar's sliders: share levels (stored above them goes to the
-- allies, fairly) and the converters' level (each converter needs its whole
-- 70 spare above it).
local Packer = require("@shared/Net/Packer")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local Economy = require("../Sim/Economy")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function step(sim: Sim.Sim, ticks: number)
	for _ = 1, ticks do
		Sim.step(sim)
	end
end

return function(t: RunAll.Context)
	t.test("extractors cost power to run: with none, they extract nothing; with it, full rate for their upkeep", function()
		local function run(power: number): (number, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			local layers = (sim.map :: any).layers
			local g = layers.grid
			local start = layers.starts[1]
			local sx, sz = g:cellAt(start[1], start[2])
			local dx, dz = g:cellCenter(sx + 4, sz + 4)
			local px, pz = PlacementRules.depositNear(layers, dx, dz, 16)
			Spawn.unit(sim, "ord_extractor", 1, px :: number, pz :: number)
			local acc = sim.eco.accounts[1]
			acc.supply.stored, acc.power.stored = 0, power
			step(sim, 15)
			return acc.supply.income, acc.power.stored
		end
		local starved = run(0)
		t.equal(starved, 0, "no power: no supply")
		local income, left = run(500)
		t.expect(math.abs(income - 0.5 * 4) < 1e-9, `with power: 0.5 × value 4 ({income})`)
		t.expect(math.abs(left - (500 - 3)) < 1e-6, `and 3 power a second paid ({left})`)
	end)

	t.test("the converter level: 80 power spare runs one of two converters, not both", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		Spawn.unit(sim, "ord_converter", 1, -20, 0)
		Spawn.unit(sim, "ord_converter", 1, 20, 0)
		submit(sim, 1, { cmdType = CT.ECO_LEVEL, flags = 0, unitIds = {}, ecoLevel = Schema.EcoLevel.CONVERT, value = 50 })
		step(sim, 1)
		local acc = sim.eco.accounts[1]
		t.equal(acc.convertAt, 0.5)
		acc.supply.stored, acc.power.stored = 0, 580 -- 80 above half of 1,000
		step(sim, Economy.STEP_TICKS) -- one economy window
		local burned = 580 - acc.power.stored
		t.expect(math.abs(burned - 70 * Economy.WINDOW) < 1e-6, `one converter's window: {burned} power`)
	end)

	t.test("the bar's power demand counts extractor upkeep and converters' burn (S-215, client-B: it showed -0 with extractors running)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local layers = (sim.map :: any).layers
		local g = layers.grid
		local start = layers.starts[1]
		local sx, sz = g:cellAt(start[1], start[2])
		local dx, dz = g:cellCenter(sx + 4, sz + 4)
		local px, pz = PlacementRules.depositNear(layers, dx, dz, 16)
		Spawn.unit(sim, "ord_extractor", 1, px :: number, pz :: number)
		local acc = sim.eco.accounts[1]
		acc.power.stored = 500
		step(sim, Economy.STEP_TICKS)
		t.expect(math.abs((acc.power.fixedRate or 0) - 3) < 1e-9, `the extractor's 3 power a second ({acc.power.fixedRate})`)
		t.equal(acc.power.demand, 0, "(construction demands nothing)")
		Spawn.unit(sim, "ord_converter", 1, start[1] - 40, start[2] - 40)
		acc.power.stored = 900
		step(sim, Economy.STEP_TICKS)
		t.expect(math.abs((acc.power.fixedRate or 0) - (3 + 70)) < 1e-9, `and a burning converter's 70 ({acc.power.fixedRate})`)
	end)

	t.test("share levels: what is stored above them goes to the allies, fairly, up to their own levels", function()
		local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 1 }, { id = 4, team = 4, allyTeam = 2 } }
		local sim = Sim.new({ seed = 1, players = players, mapId = "flat:64" })
		submit(sim, 1, { cmdType = CT.ECO_LEVEL, flags = 0, unitIds = {}, ecoLevel = Schema.EcoLevel.POWER_SHARE, value = 40 })
		submit(sim, 1, { cmdType = CT.ECO_LEVEL, flags = 0, unitIds = {}, ecoLevel = Schema.EcoLevel.SUPPLY_SHARE, value = 100 })
		step(sim, 1)
		local a = sim.eco.accounts
		a[1].power.stored, a[2].power.stored, a[3].power.stored, a[4].power.stored = 1000, 0, 100, 0
		step(sim, Economy.STEP_TICKS)
		t.expect(math.abs(a[1].power.stored - 400) < 1e-6, `player 1 keeps its 40% ({a[1].power.stored})`)
		t.expect(math.abs(a[2].power.stored - 300) < 1e-6 and math.abs(a[3].power.stored - 400) < 1e-6, `600 split fairly: {a[2].power.stored}, {a[3].power.stored}`)
		t.equal(a[4].power.stored, 0, "the enemy gets nothing")
		-- an ally at its own lower level takes only up to it
		submit(sim, 2, { cmdType = CT.ECO_LEVEL, flags = 0, unitIds = {}, ecoLevel = Schema.EcoLevel.POWER_SHARE, value = 30 })
		step(sim, 1)
		a[1].power.stored, a[2].power.stored, a[3].power.stored = 1000, 0, 0
		step(sim, Economy.STEP_TICKS)
		t.expect(a[2].power.stored <= 300 + 1e-6, `player 2 takes up to its 30% ({a[2].power.stored})`)
	end)

	t.test("the converter costs 1 supply and 1,200 power; both factions convert 70 : 1", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		for _, id in { "ord_converter", "chs_converter" } do
			local d = defs.units[id]
			t.equal(d.cost.supply, 1, id)
			t.equal(d.cost.power, 1200, id)
			t.equal((d.converter :: any).power, 70, id)
		end
	end)
end
