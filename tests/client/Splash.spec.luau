--!strict
-- Water splashes (C-82): shells that end at the water surface make splash
-- bursts (the renderer draws a column, spray and foam instead of fire and
-- dust); impacts on land don't.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

local function fight(mapId: string, a: string, b: string, gap: number): (number, number)
	local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = mapId, scenario = "empty" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	for i = 0, 2 do
		Spawn.unit(sim, a, 1, -gap / 2, -30 + i * 30, math.pi / 2)
		Spawn.unit(sim, b, 2, gap / 2, -30 + i * 30, -math.pi / 2)
	end
	local fx = Effects.new()
	local splashes, impacts = 0, 0
	local seen: { [any]: boolean } = {}
	for tick = 1, 15 * 25 do
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		Effects.update(fx, world, tick, tick * DT, 0, 0)
		for _, burst in fx.bursts do
			if burst.kind == "impact" and not seen[burst] then
				seen[burst] = true
				impacts += 1
				if burst.water then
					splashes += 1
					assert(math.abs(burst.water - burst.y) <= Effects.SPLASH_ABOVE + 1, "the splash sits on the surface")
				end
			end
		end
		table.clear(world.died)
	end
	return splashes, impacts
end

return function(t: any)
	t.test("shells landing in the sea splash; on land they don't", function()
		local seaSplash, seaImpacts = fight("sea:64", "ord_sentry", "chs_barracuda", 160)
		t.expect(seaImpacts > 0, "the corvettes fought")
		t.expect(seaSplash > 0, `misses splash ({seaSplash} of {seaImpacts} impacts)`)
		t.expect(seaSplash < seaImpacts, "hits on the ships explode")
		local landSplash, landImpacts = fight("flat:64", "ord_lancer", "chs_ravager", 140)
		t.expect(landImpacts > 0, "the tanks fought")
		t.equal(landSplash, 0, "no splashes on land")
		print(string.format("    sea: %d of %d impacts splash; land: %d of %d", seaSplash, seaImpacts, landSplash, landImpacts))
	end)

	t.test("a Fusion Reactor's death blast (S-70) draws a big explosion as wide as its damage (F15)", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local id = Spawn.unit(sim, "chs_fusion", 1, 0, 0, 0)
		local blast = sim.defs.units.chs_fusion.deathBlast
		local fx = Effects.new()
		local Combat = require("../../src/server/Sim/Combat/Combat")
		local found = false
		for tick = 1, 60 do
			if tick == 5 then
				Combat.queueDamage(sim.combat, id, 1e7, 0)
			end
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				-- a huge blast (F15): the nuke's look at its radius, no crater
				if b.kind == "nuke" and b.radius == blast.aoe and b.noCrater then
					found = true
				end
			end
			table.clear(world.died)
		end
		t.expect(blast.aoe >= Effects.HUGE_BLAST, "the fusion reactor's blast is a huge one")
		t.expect(found, "a blast of the def's aoe, the nuke's look without its crater")
	end)

	t.test("a T3 walker's death blast (S-217) plays the heavier StructureDeath, not the nuke's look (C-270)", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local id = Spawn.unit(sim, "ord_titan", 1, 0, 0, 0)
		local blast = sim.defs.units.ord_titan.deathBlast
		local fx = Effects.new()
		local Combat = require("../../src/server/Sim/Combat/Combat")
		local heavy, nuke = false, false
		for tick = 1, 60 do
			if tick == 5 then
				Combat.queueDamage(sim.combat, id, 1e7, 0)
			end
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				if b.kind == "structureDeath" and b.radius == blast.aoe * Effects.BLAST_SHOWN then
					heavy = true
				elseif b.kind == "nuke" then
					nuke = true
				end
			end
			table.clear(world.died)
		end
		t.expect(blast.aoe >= Effects.HEAVY_BLAST and blast.aoe < Effects.HUGE_BLAST, "the Titan's blast is a heavy one")
		t.expect(heavy, "a StructureDeath as wide as its shown blast")
		t.expect(not nuke, "not the nuke's look")
	end)

	local function dieAndWatch(defId: string, progress: number?): ({ Effects.Burst }, World.Death?)
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local id = Spawn.unit(sim, defId, 1, 0, 0, 0)
		if progress then
			sim.world.buildProgress[id] = progress
		end
		local fx = Effects.new()
		local Combat = require("../../src/server/Sim/Combat/Combat")
		local seen: { Effects.Burst } = {}
		local death: World.Death? = nil
		for tick = 1, 60 do
			if tick == 5 then
				Combat.queueDamage(sim.combat, id, 1e7, 0)
			end
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			death = death or world.died[1]
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				if not table.find(seen, b) then
					table.insert(seen, b)
				end
			end
			table.clear(world.died)
		end
		return seen, death
	end

	t.test("the Juggernaut goes up as a nuke: a nuke missile's detonation, crater and all (S-236, C-292)", function()
		local blast = Sim.new({ seed = 4, players = { { id = 1, team = 1 } }, mapId = "flat:16", scenario = "empty" }).defs.units.chs_juggernaut.deathBlast
		t.expect(blast.aoe >= Effects.NUKE_BLAST, `its blast is a nuke's ({blast.aoe})`)
		local nuke: Effects.Burst? = nil
		for _, b in (dieAndWatch("chs_juggernaut")) do
			if b.kind == "nuke" then
				nuke = b
			end
		end
		t.expect(nuke ~= nil, "a nuke burst")
		local b = nuke :: Effects.Burst
		t.equal(b.radius, blast.aoe)
		t.equal(b.life, Effects.NUKE_SECONDS)
		t.expect(not b.noCrater, "with the nuke's crater")
	end)

	t.test("a structure killed while it is being built is just gone: no explosion, no debris (S-236, C-292)", function()
		local bursts, death = dieAndWatch("ord_fusion", 0.6)
		t.expect(death ~= nil and death.unfinished == true, "its DEATH says it was a frame")
		t.equal(#bursts, 0, "nothing goes off")
		local finished, done = dieAndWatch("ord_fusion")
		t.expect(done ~= nil and not done.unfinished, "a finished one is no frame")
		t.expect(#finished > 0, "and it explodes as ever")
	end)
end
