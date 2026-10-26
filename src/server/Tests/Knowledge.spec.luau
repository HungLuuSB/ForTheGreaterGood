--!strict
-- Decisions follow team knowledge, never server truth (DECISIONS D100,
-- D101, D107): one test per place the audit fixed, and the domain-only rule
-- for untracked radar contacts. Bomber ghost targeting and
-- ATTACK_GROUND are in Air.spec.
local Combat = require("../Sim/Combat/Combat")
local Passability = require("@shared/Grid/Passability")
local Placement = require("../Sim/Placement")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function powered(sim: Sim.Sim)
	for _, team in { 1, 2 } do
		local acc = sim.eco.accounts[team]
		acc.power.stored = acc.power.storage
	end
end

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

-- An AI match start on the skirmish map, without running the AI.
local function aiStart(seed: number): (Sim.Sim, Skirmish.Brain)
	local sim = Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
	return sim, Skirmish.new(sim, 1)
end

return function(t: RunAll.Context)
	-- A Chaos mortar and a Chaos radar; an Order Lancer just
	-- beyond the old candidate radius (range + largest collision radius,
	-- measured on true positions). When the radar blip wobbles into range,
	-- the team believes it is in range, so the mortar fires.
	t.test("targeting judges radar contacts by their believed position, not their true one", function()
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local range = sim.defs.weapons.chs_mortar.range
		local mortar = Spawn.unit(sim, "chs_hellmouth", 2, 200, 0, -math.pi / 2)
		local d = range + sim.combat.maxRadius + 4
		-- the radar halfway out: its radar covers the tank, its sight doesn't
		Spawn.unit(sim, "chs_watcher", 2, 200 - d / 2, 120)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 200 - d, 0)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		local shots, inRangeTicks = 0, 0
		local radius = sim.combat.profiles[w.defIndex[tank]].radius
		for _ = 1, 900 do
			Sim.step(sim)
			if sim.tick < 4 then
				continue -- the first sensor pass
			end
			t.equal(Sensors.level(sim, 2, tank), L.RADAR, "the tank is only a radar contact")
			local kx, kz = Sensors.knownPosition(sim, 2, tank, true)
			if math.sqrt(((kx :: number) - w.posX[mortar]) ^ 2 + ((kz :: number) - w.posZ[mortar]) ^ 2) <= range + radius then
				inRangeTicks += 1
			end
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == mortar then
					shots += 1
				end
			end
		end
		t.expect(inRangeTicks > 0, `the blip wobbled into range ({inRangeTicks} ticks)`)
		t.expect(shots > 0, `the mortar fired at the believed position ({shots} shells)`)
		print(`    blip in range {inRangeTicks} of 900 ticks; {shots} shells`)
	end)

	t.test("planning placement uses team knowledge; the physical check doesn't", function()
		local sim = Sim.new({ seed = 6, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = sim.defs.units.ord_generator
		local enemy = Spawn.unit(sim, "chs_generator", 2, 0, 0)
		steps(sim, 2)
		t.equal(Sensors.level(sim, 1, enemy), L.HIDDEN, "Order doesn't know the Chaos generator")
		t.expect(Placement.check(sim, gen, 0, 0, 1, 1), "the planner thinks the spot is free")
		local ok, why = Placement.check(sim, gen, 0, 0, 1)
		t.expect(not ok and why == "occupied", "the physical check finds it occupied")
		-- seen: now the planner knows
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 0, 60)
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		steps(sim, 4)
		t.expect(not Placement.check(sim, gen, 0, 0, 1, 1), "seen: the planner knows it is occupied")
		-- destroyed unseen: the planner still believes it stands
		World.setPosition(w, spotter, -400, 400)
		steps(sim, 4)
		Combat.queueDamage(sim.combat, enemy, 1e9, 0)
		steps(sim, 2)
		t.expect(w.slot[enemy] == nil, "destroyed")
		t.equal(Sensors.level(sim, 1, enemy), L.GHOST, "remembered")
		t.expect(Placement.check(sim, gen, 0, 0, 1), "physically the spot is free again")
		t.expect(not Placement.check(sim, gen, 0, 0, 1, 1), "the planner still believes it is occupied")
		-- a hidden enemy unit standing there doesn't stop the planner either
		local tank = Spawn.unit(sim, "chs_ravager", 2, 200, 200)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		steps(sim, 2)
		t.expect(Placement.check(sim, gen, 200, 200, 1, 1), "a hidden tank doesn't block the planner")
		t.expect(not Placement.check(sim, gen, 200, 200, 1), "but blocks the frame")
	end)

	t.test("the AI picks deposits by what its team knows", function()
		local sim, brain = aiStart(7)
		local w = sim.world
		local g = (sim.map :: Passability.PassMap).grid
		steps(sim, 2)
		-- the AI's own extractors fill every deposit up to the first one
		-- outside its team's sight, which becomes its next choice
		local cell, x, z = 0, 0, 0
		for _, c in brain.deposits do
			local cx, cz = g:cellCenter(g:coords(c))
			if not Sensors.inSight(sim, brain.ally, cx, cz) then
				cell, x, z = c, cx, cz
				break
			end
			Spawn.unit(sim, "ord_extractor", 1, cx, cz)
		end
		t.expect(cell ~= 0, "a deposit outside the team's sight")
		t.equal(Skirmish.freeDeposit(brain), cell, "the AI's next deposit")
		-- an unseen Chaos extractor takes it
		local ext = Spawn.unit(sim, "chs_extractor", 2, x, z)
		steps(sim, 2)
		t.equal(Sensors.level(sim, brain.ally, ext), L.HIDDEN, "the extractor is unseen")
		t.equal(Skirmish.freeDeposit(brain), cell, "unseen: the AI still thinks the deposit is free")
		-- once seen, the AI looks elsewhere
		local spotter = Spawn.unit(sim, "ord_lancer", 1, x, z + 40)
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		steps(sim, 4)
		t.equal(Sensors.level(sim, brain.ally, ext), L.VISIBLE, "seen")
		t.expect(Skirmish.freeDeposit(brain) ~= cell, "seen: the AI picks another deposit")
	end)

	-- A visible Chaos tank 300 studs from the AI's home and a Chaos
	-- generator 400 studs away that the AI only has on radar. Structures
	-- count four times closer, but a radar blip has no known type.
	t.test("the AI's targets: radar blips have no type, dead ghosts still count", function()
		local sim, brain = aiStart(8)
		local w = sim.world
		local hx, hz, dir = brain.homeX, brain.homeZ, brain.toward
		local tank = Spawn.unit(sim, "chs_ravager", 2, hx + dir * 300, hz)
		local gen = Spawn.unit(sim, "chs_generator", 2, hx, hz + 400)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		local tankSpotter = Spawn.unit(sim, "ord_lancer", 1, hx + dir * 300, hz + 60)
		w.fireState[tankSpotter] = World.FireState.HOLD_FIRE
		Spawn.unit(sim, "ord_watchtower", 1, hx, hz + 150) -- 250 studs from the generator: inside its radar, beyond its sight
		steps(sim, 4)
		t.equal(Sensors.level(sim, 1, tank), L.VISIBLE, "the tank is seen")
		t.equal(Sensors.level(sim, 1, gen), L.RADAR, "the generator is a radar blip")
		local _, _, tx, tz = Skirmish.knownTargets(brain)
		t.expect(tx ~= nil and math.abs((tx :: number) - w.posX[tank]) < 1 and math.abs((tz :: number) - w.posZ[tank]) < 1, "the nearer tank, not the untyped blip")
		-- seen: now it is a structure, the better target
		local genSpotter = Spawn.unit(sim, "ord_lancer", 1, hx, hz + 340)
		w.fireState[genSpotter] = World.FireState.HOLD_FIRE
		steps(sim, 4)
		_, _, tx, tz = Skirmish.knownTargets(brain)
		t.expect(math.abs((tx :: number) - w.posX[gen]) < 1 and math.abs((tz :: number) - w.posZ[gen]) < 1, "seen: the generator")
		-- destroyed unseen: still the target (the AI can't know)
		World.setPosition(w, genSpotter, hx - dir * 200, hz - 200)
		steps(sim, 4)
		local gx, gz = w.posX[gen], w.posZ[gen]
		Combat.queueDamage(sim.combat, gen, 1e9, 0)
		steps(sim, 2)
		t.expect(w.slot[gen] == nil, "destroyed")
		_, _, tx, tz = Skirmish.knownTargets(brain)
		t.expect(math.abs((tx :: number) - gx) < 1 and math.abs((tz :: number) - gz) < 1, "the remembered generator is still the target")
	end)

	-- D107: untracked contacts reveal only their domain.
	t.test("untracked radar contacts reveal only their domain; tracked and visible ones their type", function()
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "sea:128" })
		local w = sim.world
		Spawn.unit(sim, "ord_beacon", 1, -400, 0) -- on the land strip, radar 1100
		local tank = Spawn.unit(sim, "chs_juggernaut", 2, -350, 400) -- on land, far from Order's sight
		local heli = Spawn.unit(sim, "chs_wasp", 2, 200, -300)
		local sub = Spawn.unit(sim, "chs_lamprey", 2, 300, 300)
		Spawn.unit(sim, "ord_crusader", 1, 300, 100) -- sonar 320 reaches the sub
		for _, id in { tank, heli, sub } do
			w.fireState[id] = World.FireState.HOLD_FIRE
		end
		steps(sim, 4)
		local function cats(id: number): number
			local _, _, level, defIndex = Sensors.knownTarget(sim, 1, id)
			return Sensors.knownCategories(sim, 1, id, level, defIndex :: number)
		end
		local D = Sensors.DOMAIN_MASK
		t.equal(Sensors.level(sim, 1, tank), L.RADAR, "the tank is a radar blip")
		t.equal(cats(tank), D.surface, "an untracked surface blip: surface, no ARMORED or COMMANDER")
		t.equal(Sensors.level(sim, 1, heli), L.RADAR, "the helicopter is a radar blip")
		t.equal(cats(heli), D.air, "an untracked air blip: air only")
		t.equal(Sensors.level(sim, 1, sub), L.SONAR, "the submarine is a sonar contact")
		t.equal(cats(sub), D.submerged, "a sonar contact under water: submerged")
		Spawn.unit(sim, "ord_tribunal", 1, -400, 250) -- tracks the tank
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(Sensors.isTracked(sim, 1, tank), "tracked")
		t.equal(cats(tank), sim.defs.units.chs_juggernaut.categoryMask, "tracked: its real categories")
	end)

	-- A Seraph (radar SAM, priority jet > air > helicopter) with a Wasp radar
	-- blip at 400 studs and a Harpy radar blip at 500. Untracked, the nearer
	-- blip wins; tracked, the jet's priority wins.
	local function samChoice(tracking: boolean): (number, number, number)
		local sim = Sim.new({ seed = 10, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local sam = Spawn.unit(sim, "ord_seraph", 1, -300, 0)
		local heli = Spawn.unit(sim, "chs_wasp", 2, 100, 0)
		local jet = Spawn.unit(sim, "chs_harpy", 2, 200, 0, -math.pi / 2)
		w.fireState[heli] = World.FireState.HOLD_FIRE
		w.fireState[jet] = World.FireState.HOLD_FIRE
		if tracking then
			Spawn.unit(sim, "ord_tribunal", 1, -300, 200)
		end
		local first = 0
		for _ = 1, 12 do
			powered(sim)
			Sim.step(sim)
			local cur = w.wTarget[World.slotKey(sam, 1)]
			if first == 0 and cur ~= 0 then
				first = cur
			end
		end
		return first, heli, jet
	end

	t.test("type priorities apply only to tracked or visible targets", function()
		local pick, heli, jet = samChoice(false)
		t.equal(pick, heli, "untracked: the nearer blip (no type priority)")
		pick, heli, jet = samChoice(true)
		t.equal(pick, jet, "tracked: the jet, by priority")
	end)

	t.test("the AI types tracked contacts like seen ones", function()
		local sim, brain = aiStart(11)
		local w = sim.world
		local hx, hz, dir = brain.homeX, brain.homeZ, brain.toward
		local tank = Spawn.unit(sim, "chs_ravager", 2, hx + dir * 300, hz)
		local gen = Spawn.unit(sim, "chs_generator", 2, hx, hz + 400)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		local spotter = Spawn.unit(sim, "ord_lancer", 1, hx + dir * 300, hz + 60)
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		Spawn.unit(sim, "ord_watchtower", 1, hx, hz + 150)
		Spawn.unit(sim, "ord_tribunal", 1, hx - dir * 100, hz + 150)
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, gen), L.RADAR, "the generator is a radar blip")
		t.expect(Sensors.isTracked(sim, 1, gen), "and tracked")
		local _, _, tx, tz = Skirmish.knownTargets(brain)
		t.expect(math.abs((tx :: number) - w.posX[gen]) < 20 and math.abs((tz :: number) - w.posZ[gen]) < 20, "tracked: the AI knows it is a structure and prefers it")
	end)
end
