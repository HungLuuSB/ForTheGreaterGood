--!strict
-- Unit ID reuse (DECISIONS D109): every remembered unit reference carries
-- the unit's generation, and IDs remembered as ghosts are never reused.
-- Reuse is forced by using up the fresh IDs, so the next spawn takes the
-- oldest freed ID once its delay is over.
local Build = require("../Sim/Build")
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

-- From now on, spawns take freed IDs only.
local function exhaustFresh(w: World.World)
	w.nextFresh = World.MAX_ID + 1
end

-- Kills `id` now and waits out its reuse delay.
local function killAndWait(sim: Sim.Sim, id: number)
	Combat.queueDamage(sim.combat, id, 1e9, 0)
	steps(sim, World.REUSE_DELAY_TICKS + 2)
	assert(sim.world.slot[id] == nil, "killed")
end

return function(t: RunAll.Context)
	t.test("each reuse of an ID is a new generation; pinned IDs wait", function()
		local w = World.new()
		local function spawn(tick: number): number
			return World.spawn(w, tick, { defIndex = 1, team = 1, owner = 1, x = 0, z = 0, health = 1 })
		end
		local a = spawn(0)
		local genA = w.gen[a]
		t.expect(World.isRef(w, a, genA), "a live reference")
		exhaustFresh(w)
		World.despawn(w, 1, a)
		t.expect(not World.isRef(w, a, genA), "gone")
		t.expect(pcall(spawn, 2) == false, "within the reuse delay: no ID")
		local b = spawn(1 + World.REUSE_DELAY_TICKS)
		t.equal(b, a, "the same ID, reused")
		t.equal(w.gen[b], genA + 1, "a new generation")
		t.expect(not World.isRef(w, a, genA), "the old reference doesn't match the new unit")
		-- a pinned ID (remembered as a ghost) is skipped
		World.pin(w, b)
		World.despawn(w, 200, b)
		t.expect(pcall(spawn, 200 + World.REUSE_DELAY_TICKS) == false, "pinned: not reused")
		World.unpin(w, b)
		t.equal(spawn(200 + World.REUSE_DELAY_TICKS), b, "unpinned: reused")
	end)

	-- A Lancer on RETURN_FIRE was shot by a Ravager that then died. Its ID
	-- goes to a new Ravager that never fired: the Lancer must not answer it.
	t.test("RETURN_FIRE never answers a new unit that got its old attacker's ID", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		World.setFireState(w, lancer, World.FireState.HOLD_FIRE)
		World.setHealth(w, lancer, 1e6)
		local raider = Spawn.unit(sim, "chs_ravager", 2, 100, 0, -math.pi / 2)
		for _ = 1, 300 do
			Sim.step(sim)
			if w.lastAttacker[lancer] == raider then
				break
			end
		end
		t.equal(w.lastAttacker[lancer], raider, "the Ravager hit the Lancer")
		exhaustFresh(w)
		killAndWait(sim, raider)
		local newcomer = Spawn.unit(sim, "chs_ravager", 2, 100, 0, -math.pi / 2)
		t.equal(newcomer, raider, "the new Ravager has the old one's ID")
		World.setFireState(w, newcomer, World.FireState.HOLD_FIRE)
		World.setFireState(w, lancer, World.FireState.RETURN_FIRE)
		local shots = 0
		for _ = 1, 60 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and e.unit == lancer then
					shots += 1
				end
			end
		end
		t.equal(shots, 0, "the Lancer holds: the newcomer never attacked it")
	end)

	-- A Chaos generator Order saw once dies unseen: its ID stays pinned while
	-- Order remembers it, and is free again once Order sees the spot.
	t.test("a ghost's ID is not reused while remembered; the ghost keeps the old generation", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = Spawn.unit(sim, "chs_generator", 2, 200, 0)
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 200, 80)
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		steps(sim, 4)
		World.setPosition(w, spotter, -400, 400)
		steps(sim, 4)
		local oldGen = w.gen[gen]
		local filler = Spawn.unit(sim, "chs_ravager", 2, -300, -300) -- its ID will be the free one
		exhaustFresh(w)
		Combat.queueDamage(sim.combat, gen, 1e9, 0) -- the generator's ID is freed first: the oldest in the queue
		steps(sim, 2)
		killAndWait(sim, filler)
		t.equal(Sensors.level(sim, 1, gen), Sensors.Level.GHOST, "remembered")
		t.equal(sim.sensors.ghosts[1][gen].gen, oldGen, "the ghost stores its unit's generation")
		local other = Spawn.unit(sim, "chs_ravager", 2, -300, -300)
		t.equal(other, filler, "the remembered ID is skipped; the filler's is handed out")
		-- seen again: forgotten and unpinned
		World.setPosition(w, spotter, 200, 60)
		steps(sim, 4)
		t.equal(Sensors.level(sim, 1, gen), Sensors.Level.HIDDEN, "forgotten")
		World.setPosition(w, spotter, -400, 400)
		Combat.queueDamage(sim.combat, other, 1e9, 0)
		steps(sim, World.REUSE_DELAY_TICKS + 2)
		local reused = { Spawn.unit(sim, "chs_ravager", 2, 300, 300), Spawn.unit(sim, "chs_ravager", 2, 300, 340) }
		t.expect(table.find(reused, gen) ~= nil, "unpinned: the ID is reused")
		t.expect(w.gen[gen] > oldGen, "with a new generation")
	end)

	-- Stale references set up directly (systems drop them on death, so this
	-- checks the generation guard itself): a builder's target and an
	-- aircraft's pad whose IDs now belong to other units.
	t.test("stale builder targets and rearm pads are recognised after reuse", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local b = sim.build
		local falcon = Spawn.unit(sim, "ord_falcon", 1, -200, -200)
		local pad = Spawn.unit(sim, "ord_airpad", 1, -400, -400)
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, 0)
		local frame = Spawn.unit(sim, "ord_generator", 1, 40, 0)
		World.setBuildProgress(w, frame, 0.2)
		Build.commandAssist(sim, { mason }, frame)
		local frameGen = b.targetGen[mason]
		t.equal(b.target[mason], frame, "assisting the frame")
		-- the frame dies and its ID goes to another Order frame elsewhere
		exhaustFresh(w)
		killAndWait(sim, frame)
		local other = Spawn.unit(sim, "ord_generator", 1, -300, 300)
		World.setBuildProgress(w, other, 0.2)
		t.equal(other, frame, "the ID is reused")
		b.target[mason], b.targetGen[mason] = frame, frameGen -- the stale reference
		steps(sim, 2)
		t.equal(b.target[mason] or 0, 0, "the builder drops the stale target instead of walking to the new frame")
		t.expect(w.buildProgress[other] <= 0.2 + 1e-9, "and doesn't build it")

		-- an aircraft heading to a pad whose ID is now a tank's
		local padGen = w.gen[pad]
		killAndWait(sim, pad)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 300, -300)
		t.equal(tank, pad, "the pad's ID is reused by an enemy tank")
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local a = sim.air
		a.phase[falcon], a.pad[falcon], a.padGen[falcon] = "return", pad, padGen
		steps(sim, 2)
		t.expect(a.pad[falcon] ~= tank or a.padGen[falcon] ~= w.gen[tank], "the stale pad is dropped")
		t.expect(bit32.band(w.state[falcon], World.State.LANDED) == 0, "and the jet never lands on the tank")
	end)
end
