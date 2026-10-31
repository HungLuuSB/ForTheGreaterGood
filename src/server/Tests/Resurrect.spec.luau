--!strict
-- Resurrect and reclaim (S-168, the user): T1 workers bring a wreck's unit
-- back for power; a partly reclaimed wreck is first refilled with supply.
-- The wire carries each wreck's supply and resurrect progress.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local NetOut = require("../Sim/NetOut")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function fund(sim: Sim.Sim, team: number, supply: number, power: number)
	local acc = sim.eco.accounts[team]
	-- as the RES cheat does: storage the economy step keeps (S-102)
	for _, pair in { { acc.supply, supply }, { acc.power, power } } do
		local r, amount = pair[1] :: any, pair[2]
		if amount > r.storage then
			r.bonusStorage = (r.bonusStorage or 0) + amount - r.storage
			r.storage = amount
		end
		r.stored = amount
	end
end

-- A wreck of `defId` (team 2's unit, killed cleanly) at (x, z).
local function wreckOf(sim: Sim.Sim, defId: string, x: number, z: number): number
	local id = Spawn.unit(sim, defId, 2, x, z, math.pi)
	Combat.queueDamage(sim.combat, id, sim.world.health[id], 0)
	Sim.step(sim)
	for _, e in sim.combat.events do
		if e.kind == "DEATH" and e.unit == id then
			assert(e.other ~= 0, "a wreck was left")
			return e.other :: number
		end
	end
	error("no death")
end

local function resurrect(sim: Sim.Sim, player: number, ids: { number }, wreck: number)
	submit(sim, player, { cmdType = CT.RESURRECT, flags = 0, unitIds = ids, targetId = wreck })
end

-- Steps until the wreck is resurrected; returns the new unit (0 if not within `limit`).
local function runUntilRisen(sim: Sim.Sim, limit: number, each: (() -> ())?): number
	for _ = 1, limit do
		if each then
			each()
		end
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "RESURRECTED" then
				return e.unit
			end
		end
	end
	return 0
end

return function(t: RunAll.Context)
	t.test("a Mason resurrects an untouched wreck for power only; the unit is its owner's, at full health", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local c = sim.combat
		local wreck = wreckOf(sim, "chs_ravager", 0, 0)
		local d = sim.defs.units.chs_ravager
		t.equal(c.wreckSupply[wreck], Combat.fullWreckSupply(d), "a full wreck")
		local mason = Spawn.unit(sim, "ord_mason", 1, 60, 0)
		fund(sim, 1, 1000, 5000)
		local supplyBefore = sim.eco.accounts[1].supply.stored
		resurrect(sim, 1, { mason }, wreck)
		local unit = runUntilRisen(sim, 15 * 60)
		t.expect(unit ~= 0, "resurrected")
		t.equal(c.wreckX[wreck], nil, "the wreck is gone")
		t.equal(sim.defs.unitByIndex[w.defIndex[unit]].id, "chs_ravager", "the wreck's unit")
		t.equal(w.owner[unit], 1, "now the worker's owner's (an enemy wreck)")
		t.equal(w.health[unit], d.health, "full health")
		for _ = 1, 10 do
			Sim.step(sim) -- an economy step settles the spending
		end
		local acc = sim.eco.accounts[1]
		t.expect(math.abs(acc.supply.stored - supplyBefore) < 1e-6, `no supply spent ({supplyBefore} → {acc.supply.stored})`)
		t.expect(acc.power.stored < 5000 - d.cost.power * 0.95, `about its power cost spent ({5000 - acc.power.stored} of {d.cost.power})`)
		-- the build time at the Mason's build power: 3700 / 110 ≈ 34 s
		local bp = sim.defs.units.ord_mason.buildPower :: number
		t.expect(sim.tick > d.cost.buildTime / bp * 15 * 0.9, `took about its build time ({sim.tick / 15} s)`)
	end)

	t.test("a partly reclaimed wreck is refilled with supply first, then resurrected", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local c = sim.combat
		local wreck = wreckOf(sim, "chs_ravager", 0, 0)
		local full = c.wreckSupply[wreck]
		c.wreckSupply[wreck] = full * 0.5 -- half reclaimed (below 40% it would be a heap, S-227)
		local mason = Spawn.unit(sim, "ord_mason", 1, 40, 0)
		fund(sim, 1, 1000, 5000)
		resurrect(sim, 1, { mason }, wreck)
		local refilledAt, rezStarted = nil, nil
		local unit = runUntilRisen(sim, 15 * 90, function()
			fund(sim, 1, 1000, 5000)
			if refilledAt == nil and c.wreckSupply[wreck] and c.wreckSupply[wreck] >= full - 1e-6 then
				refilledAt = sim.tick
			end
			if rezStarted == nil and (c.wreckRez[wreck] or 0) > 0 then
				rezStarted = sim.tick
				t.expect(refilledAt ~= nil, "resurrecting starts only once the wreck is full again")
			end
		end)
		t.expect(unit ~= 0, "resurrected")
		t.expect(refilledAt ~= nil and rezStarted ~= nil and rezStarted >= refilledAt, `refilled at {refilledAt}, then resurrect from {rezStarted}`)
		-- the refill runs at the reclaim rate: 0.5 × 65 supply at 11 supply/s ≈ 3 s
		local rate = (sim.defs.units.ord_mason.buildPower :: number) * 0.1
		t.expect(math.abs((refilledAt :: number) - 2 - full * 0.5 / rate * 15) <= 3, `refill took {(refilledAt :: number) - 2} ticks`)
	end)

	t.test("reclaiming a wreck being resurrected sets it back: it must be refilled again", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local c = sim.combat
		local wreck = wreckOf(sim, "chs_ravager", 0, 0)
		local full = c.wreckSupply[wreck]
		local mason = Spawn.unit(sim, "ord_mason", 1, 40, 0)
		local reclaimer = Spawn.unit(sim, "chs_scrapper", 2, -40, 0)
		fund(sim, 1, 1000, 5000)
		resurrect(sim, 1, { mason }, wreck)
		for _ = 1, 15 * 10 do
			fund(sim, 1, 1000, 5000)
			Sim.step(sim)
		end
		local progress = c.wreckRez[wreck] or 0
		t.expect(progress > 0, `resurrecting ({progress})`)
		submit(sim, 2, { cmdType = CT.RECLAIM, flags = 0, unitIds = { reclaimer }, targetId = wreck })
		for _ = 1, 15 * 2 do
			fund(sim, 1, 1000, 5000)
			Sim.step(sim)
		end
		t.expect(c.wreckSupply[wreck] < full, "the enemy reclaimed some of it")
		t.expect((c.wreckRez[wreck] or 0) >= progress - 1e-9, "the resurrect progress stays")
	end)

	t.test("only T1 workers resurrect, and never a Commander's wreck", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local c = sim.combat
		t.expect(sim.defs.units.ord_mason.canResurrect == true and sim.defs.units.chs_scrapper.canResurrect == true, "the T1 workers can")
		t.expect(not sim.defs.units.ord_sovereign.canResurrect, "a Commander can't")
		local wreck = wreckOf(sim, "chs_ravager", 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local cv = Spawn.unit(sim, "ord_sovereign", 1, 60, 30)
		fund(sim, 1, 1000, 5000)
		resurrect(sim, 1, { tank, cv }, wreck)
		local unit = runUntilRisen(sim, 15 * 40)
		t.equal(unit, 0, "a tank and a Commander don't resurrect")
		t.equal(c.wreckRez[wreck], nil, "no progress")
		-- a Commander's wreck
		local warlord = Spawn.unit(sim, "chs_warlord", 2, -200, -200)
		Combat.queueDamage(c, warlord, sim.world.health[warlord], 0)
		Sim.step(sim)
		local cw = 0
		for _, e in sim.combat.events do
			if e.kind == "DEATH" and e.unit == warlord then
				cw = e.other :: number
			end
		end
		t.expect(cw ~= 0, "the Commander left a wreck")
		local mason = Spawn.unit(sim, "ord_mason", 1, -160, -200)
		resurrect(sim, 1, { mason }, cw)
		for _ = 1, 15 * 20 do
			fund(sim, 1, 1000, 5000)
			Sim.step(sim)
		end
		t.equal(c.wreckRez[cw], nil, "a Commander's wreck can't be resurrected")
		t.equal(sim.build.resurrect[mason] or 0, 0, "the order was refused")
	end)

	t.test("a structure's wreck comes back as the structure on its footprint", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local wreck = wreckOf(sim, "chs_solar", 0, 0)
		local mason = Spawn.unit(sim, "ord_mason", 1, 50, 0)
		fund(sim, 1, 1000, 5000)
		resurrect(sim, 1, { mason }, wreck)
		local unit = runUntilRisen(sim, 15 * 120, function()
			fund(sim, 1, 1000, 5000)
		end)
		t.expect(unit ~= 0, "resurrected")
		t.equal(sim.defs.unitByIndex[w.defIndex[unit]].id, "chs_solar")
		t.equal(w.buildProgress[unit], 1, "finished, not a frame")
		local g = (sim.map :: any).grid
		local cx, cz = g:cellAt(w.posX[unit], w.posZ[unit])
		t.equal(require("@shared/Grid/Passability").occupant(sim.map :: any, g:index(cx, cz)), unit, "it occupies its footprint")
	end)

	t.test("the wire: WRECK carries its supply; WRECK_STATE its supply and resurrect progress, in sight only (protocol 35)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local c = sim.combat
		local mason = Spawn.unit(sim, "ord_mason", 1, 40, 0)
		local wreck = wreckOf(sim, "chs_ravager", 0, 0)
		local view = Client.new(g)
		local enemy = Client.new(g)
		NetOut.join(sim, 1) -- (they connect now: the whole picture comes again)
		NetOut.join(sim, 2)
		local function step(n: number)
			for _ = 1, n do
				fund(sim, 1, 1000, 5000)
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
				Client.receive(enemy, sim.net.players[2].outbox)
			end
		end
		step(4)
		local known = view.wrecks[wreck]
		t.expect(known ~= nil, "the team sees the wreck")
		local full = math.floor(Combat.fullWreckSupply(sim.defs.units.chs_ravager) + 0.5)
		t.equal(known.fullSupply, full, "its full supply")
		t.equal(known.supply, full, "untouched")
		resurrect(sim, 1, { mason }, wreck)
		step(15 * 6)
		t.expect(view.wrecks[wreck].rez > 0, `resurrect progress arrives ({view.wrecks[wreck].rez})`)
		t.expect(math.abs(view.wrecks[wreck].rez - math.floor(c.wreckRez[wreck] * 255)) <= 3, "close to the server's")
		-- out of the enemy's sight: its client keeps what it knew
		local enemyRez = if enemy.wrecks[wreck] then enemy.wrecks[wreck].rez else nil
		t.expect(enemyRez == nil or enemyRez == 0, "the enemy, who can't see the spot, hears nothing of it")
		-- a reclaimer drains it: the supply goes down on the client too
		submit(sim, 1, { cmdType = CT.RECLAIM, flags = 0, unitIds = { mason }, targetId = wreck })
		step(15 * 2)
		t.expect(view.wrecks[wreck].supply < full, `the supply left arrives ({view.wrecks[wreck].supply} of {full})`)
		t.expect(math.abs(view.wrecks[wreck].supply - c.wreckSupply[wreck]) <= 2, `as the server has it (sent on sensor ticks: {view.wrecks[wreck].supply} / {c.wreckSupply[wreck]})`)
		local _ = World
	end)
end
