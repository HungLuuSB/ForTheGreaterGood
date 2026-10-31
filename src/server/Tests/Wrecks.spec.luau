--!strict
-- Wrecks wear down to scrap heaps (S-227): health 0.54 × the unit's, what a
-- wreck holds follows its health, blasts damage it, a heap below 40% can
-- only be reclaimed, and at 0 it's gone.
local Build = require("../Sim/Build")
local Combat = require("../Sim/Combat/Combat")
local Orders = require("../Sim/Orders")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local function start(): Sim.Sim
	return Sim.new({
		seed = 9,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

-- A blast weapon for the tests: `damage` against structures (what wrecks
-- take), nothing against units.
local function blast(damage: number, aoe: number, edge: number?): any
	return {
		aoe = aoe,
		edgeEffectiveness = edge or 1,
		damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = damage, SHIP = 0, AIR = 0, SUB = 0 },
	}
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: RunAll.Context)
	t.test("a wreck's health is 0.54 × its unit's, and what it holds follows a blast's damage", function()
		local sim = start()
		local c = sim.combat
		local d = sim.defs.units.ord_paladin
		local wid = Combat.addWreck(c, 800, 800, d, 0)
		Sim.step(sim) -- (a wreck is safe from the blasts of the tick it was made in)
		local full = Combat.fullWreckSupply(d)
		local hp = d.health * Combat.WRECK_HEALTH
		t.expect(near(Combat.wreckHealth(c, wid), hp))
		t.equal(c.wreckSupply[wid], full)
		Combat.explode(c, sim.world, 800, 0, 800, blast(hp * 0.25, 30), 0, 0, 0)
		t.expect(near(Combat.wreckHealth(c, wid), hp * 0.75), "a quarter of its health")
		t.expect(near(c.wreckSupply[wid], full * 0.75), "and a quarter of its supply")
		t.equal(Combat.isHeap(c, wid), false)
		local hit = false
		for _, e in c.events do
			hit = hit or (e.kind == "WRECK_HIT" and e.other == wid)
		end
		t.expect(hit, "a WRECK_HIT event for the client's sparks")
	end)

	t.test("splash falls off to the wreck's edge; a shell with no splash hits only the wreck it lands on", function()
		local sim = start()
		local c = sim.combat
		local d = sim.defs.units.ord_paladin
		local wid = Combat.addWreck(c, 800, 800, d, 0)
		Sim.step(sim)
		local full = c.wreckSupply[wid]
		local r = c.wreckRadius[wid]
		Combat.explode(c, sim.world, 800 + r + 40, 0, 800, blast(1000, 20), 0, 0, 0)
		t.equal(c.wreckSupply[wid], full, "a blast that doesn't reach it")
		Combat.explode(c, sim.world, 800 + r + 1, 0, 800, blast(1000, 0), 0, 0, 0)
		t.equal(c.wreckSupply[wid], full, "a point hit beside it")
		Combat.explode(c, sim.world, 800 + r * 0.5, 0, 800, blast(100, 0), 0, 0, 0)
		t.expect(c.wreckSupply[wid] < full, "a point hit on it")
		local before = c.wreckSupply[wid]
		Combat.explode(c, sim.world, 800 + r + 10, 0, 800, blast(100, 20, 0), 0, 0, 0)
		local half = before - c.wreckSupply[wid]
		t.expect(half > 0, "splash reaching its edge")
		local full100 = 100 / c.wreckMaxHp[wid] * c.wreckFull[wid]
		t.expect(near(half, full100 * 0.5), "halfway out of a 20-stud blast with no edge damage: half")
	end)

	t.test("below 40% it's a scrap heap: resurrect refused, reclaim only; at 0 it's gone", function()
		local sim = start()
		local c = sim.combat
		local d = sim.defs.units.ord_paladin
		local wid = Combat.addWreck(c, 800, 800, d, 0)
		local hp = c.wreckMaxHp[wid]
		Combat.damageWreck(c, wid, hp * 0.59)
		t.equal(Combat.isHeap(c, wid), false, "41% left: still a wreck")
		local mason = Spawn.unit(sim, "ord_mason", 1, 780, 800, 0)
		Build.commandResurrect(sim, { mason }, wid)
		t.equal(sim.build.resurrect[mason], wid, "a wreck can be resurrected")
		Combat.damageWreck(c, wid, hp * 0.02)
		t.equal(Combat.isHeap(c, wid), true, "39% left: a heap")
		Sim.step(sim)
		t.equal(sim.build.resurrect[mason], 0, "the resurrect under way stops")
		Build.commandResurrect(sim, { mason }, wid)
		t.expect((sim.build.resurrect[mason] or 0) == 0, "and a new one is refused")
		t.equal(Orders.areaTarget(sim, mason, Schema.AreaOp.RESURRECT, 800, 800, 50), nil, "area resurrect skips it")
		Combat.damageWreck(c, wid, hp)
		t.equal(c.wreckX[wid], nil, "at 0 it's gone")
		local gone = false
		for _, e in c.events do
			gone = gone or (e.kind == "RECLAIMED" and e.other == wid and e.unit == 0)
		end
		t.expect(gone, "as if reclaimed, so every team's map forgets it")
	end)

	t.test("reclaim wears the same bar; Smart Reclaim takes a heap first", function()
		local sim = start()
		local c = sim.combat
		local d = sim.defs.units.ord_paladin
		local wreck = Combat.addWreck(c, 825, 800, d, 0)
		local heap = Combat.addWreck(c, 845, 800, d, 0)
		Combat.damageWreck(c, heap, c.wreckMaxHp[heap] * 0.7)
		local mason = Spawn.unit(sim, "ord_mason", 1, 800, 800, 0)
		t.equal(Orders.areaTarget(sim, mason, Schema.AreaOp.RECLAIM, 830, 800, 60), heap, "the heap, though the wreck is nearer")
		Build.commandReclaim(sim, { mason }, wreck)
		for _ = 1, 60 do
			Sim.step(sim)
		end
		t.expect(c.wreckSupply[wreck] < Combat.fullWreckSupply(d), "reclaimed some")
		t.expect(near(Combat.wreckHealth(c, wreck) / c.wreckMaxHp[wreck], c.wreckSupply[wreck] / c.wreckFull[wreck]), "health follows supply")
	end)

	t.test("a wreck is safe from the blasts of the tick it was made in (its own death blast)", function()
		local sim = start()
		local c = sim.combat
		local wid = Combat.addWreck(c, 800, 800, sim.defs.units.ord_paladin, 0)
		local full = c.wreckSupply[wid]
		Combat.explode(c, sim.world, 800, 0, 800, blast(100000, 30), 0, 0, 0)
		t.equal(c.wreckSupply[wid], full)
		Sim.step(sim)
		Combat.explode(c, sim.world, 800, 0, 800, blast(100, 30), 0, 0, 0)
		t.expect(c.wreckSupply[wid] < full, "the next tick's do")
	end)

	t.test("map trees and rocks don't take damage", function()
		local sim = start()
		local c = sim.combat
		local tree = Combat.addFeature(c, 900, 900, 1, 50, 0)
		Sim.step(sim)
		Combat.explode(c, sim.world, 900, 0, 900, blast(100000, 40), 0, 0, 0)
		t.equal(c.wreckSupply[tree], 50)
		t.equal(Combat.isHeap(c, tree), false)
	end)
end
