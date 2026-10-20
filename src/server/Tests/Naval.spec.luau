--!strict
local Combat = require("../Sim/Combat/Combat")
local Layers = require("@shared/Grid/Layers")
local MoveClasses = require("@shared/Defs/MoveClasses")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
-- "sea:128": 1024 studs across, centered on 0; land where x < -256, deep water (20) elsewhere
local MAP = "sea:128"
local SHORE_X = -256

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function depthUnder(sim: Sim.Sim, id: number): number
	local map = sim.map :: any
	local g = map.grid
	local cx, cz = g:cellAt(sim.world.posX[id], sim.world.posZ[id])
	assert(g:inBounds(cx, cz), "unit left the map")
	return Layers.getWater(map.layers, g:index(cx, cz))
end

-- A destroyer at (0, 0) and an enemy submarine 200 studs east.
local function duel(seed: number): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = MAP })
	local destroyer = Spawn.unit(sim, "ord_crusader", 1, 0, 0, math.pi / 2)
	local sub = Spawn.unit(sim, "chs_lamprey", 2, 200, 0, -math.pi / 2)
	return sim, destroyer, sub
end

-- Weapon def id and target of a shot event (FIRE for hitscan, SPAWN_PROJ
-- for projectiles; the projectile's target is the slot's current target).
local function shot(sim: Sim.Sim, e: any): (string?, number)
	local w = sim.world
	if e.kind ~= "FIRE" and e.kind ~= "SPAWN_PROJ" then
		return nil, 0
	end
	local slot = e.slot :: number
	local target = if e.kind == "FIRE" then e.other else w.wTarget[World.slotKey(e.unit, slot)]
	return sim.defs.unitByIndex[w.defIndex[e.unit]].weapons[slot].def, target
end

local function runDuel(sim: Sim.Sim, destroyer: number, sub: number, maxTicks: number): (number?, { [string]: number })
	local w = sim.world
	local shotsBy: { [string]: number } = {} -- weapon id -> shots at the sub
	for _ = 1, maxTicks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			local wd, target = shot(sim, e)
			if wd and e.unit == destroyer and target == sub then
				shotsBy[wd] = (shotsBy[wd] or 0) + 1
			end
		end
		if w.slot[sub] == nil then
			return sim.tick, shotsBy
		end
	end
	return nil, shotsBy
end

return function(t: RunAll.Context)
	t.test("ships and submarines never leave the water, even when ordered inland", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = MAP })
		local w = sim.world
		local ship = Spawn.unit(sim, "ord_sentry", 1, 0, 0)
		local destroyer = Spawn.unit(sim, "ord_crusader", 1, 0, 120)
		local sub = Spawn.unit(sim, "ord_silence", 1, 0, -120)
		moveTo(sim, 1, { ship, destroyer, sub }, -450, 0) -- deep inland
		local minShip, minSub, westmost = math.huge, math.huge, math.huge
		for _ = 1, 600 do
			Sim.step(sim)
			minShip = math.min(minShip, depthUnder(sim, ship), depthUnder(sim, destroyer))
			minSub = math.min(minSub, depthUnder(sim, sub))
			westmost = math.min(westmost, w.posX[ship], w.posX[destroyer], w.posX[sub])
		end
		t.expect(minShip >= MoveClasses.SHIP.minDepth :: number, `ships stayed in water (shallowest {minShip})`)
		t.expect(minSub >= MoveClasses.SUB.minDepth :: number, `the submarine stayed in deep water (shallowest {minSub})`)
		t.expect(westmost < SHORE_X + 80, `they did head for the order and reached the shore (westmost x {westmost})`)
		t.expect(bit32.band(w.state[sub], World.State.SUBMERGED) ~= 0, "submarines are always submerged")
	end)

	t.test("a submarine is invisible without sonar and only ever a sonar contact with it", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = MAP })
		local corvette = Spawn.unit(sim, "ord_sentry", 1, 0, 0) -- sight 220, no sonar
		local sub = Spawn.unit(sim, "chs_lamprey", 2, 100, 0) -- well within sight
		for _ = 1, 40 do
			Sim.step(sim)
			t.equal(Sensors.level(sim, 1, sub), L.HIDDEN, "no sonar: the submarine stays hidden")
			t.expect(Sensors.knownPosition(sim, 1, sub) == nil, "and its position is unknown")
		end
		-- the corvette sees the surface around it, so a ship there would be visible
		local ship = Spawn.unit(sim, "chs_barracuda", 2, 100, 60)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, ship), L.VISIBLE, "a surface ship at the same range is visible")
		t.expect(sim.world.slot[corvette] ~= nil, "corvette alive")

		-- a destroyer's sonar reveals it, but never better than SONAR
		Spawn.unit(sim, "ord_crusader", 1, -60, 0)
		local sonarTicks = 0
		for _ = 1, 30 do
			Sim.step(sim)
			if sim.world.slot[sub] == nil then
				break
			end
			local level = Sensors.level(sim, 1, sub)
			t.expect(level ~= L.VISIBLE, "a submerged submarine is never VISIBLE")
			if level == L.SONAR then
				sonarTicks += 1
			end
		end
		t.expect(sonarTicks > 0, "the destroyer's sonar picks the submarine up")
	end)

	t.test("only torpedoes target submarines: guns and land units ignore a known sub", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = MAP })
		local w = sim.world
		local lancer = Spawn.unit(sim, "ord_lancer", 1, SHORE_X - 30, 0) -- on the beach
		local corvette = Spawn.unit(sim, "ord_sentry", 1, SHORE_X + 60, 80)
		Spawn.unit(sim, "ord_crusader", 1, SHORE_X + 60, -80) -- sonar: team 1 knows the sub
		local sub = Spawn.unit(sim, "chs_lamprey", 2, SHORE_X + 80, 0)
		local known, shotsAtSub = 0, 0
		for _ = 1, 60 do
			Sim.step(sim)
			if w.slot[sub] == nil then
				break
			end
			if Sensors.level(sim, 1, sub) == L.SONAR then
				known += 1
			end
			t.equal(w.wTarget[World.slotKey(lancer, 1)], 0, "the tank never targets the submarine")
			t.equal(w.wTarget[World.slotKey(corvette, 1)], 0, "the corvette's gun never targets the submarine")
			for _, e in sim.combat.events do
				local wd, target = shot(sim, e)
				if wd and target == sub then
					shotsAtSub += 1
					t.equal(sim.defs.weapons[wd].type, "TORPEDO", `only torpedoes fire at the submarine ({wd})`)
				end
			end
		end
		t.expect(known > 0, "the submarine was a known sonar contact")
		t.expect(shotsAtSub > 0, "the destroyer's torpedoes did engage it")
	end)

	t.test("torpedoes stay in the water and die at the shore", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = MAP })
		local c = sim.combat
		local lancer = Spawn.unit(sim, "chs_ravager", 2, SHORE_X - 20, 0) -- on land, just past the shore
		local hp = sim.world.health[lancer]
		local weapon = sim.defs.weapons.ord_torpedo
		local x0 = SHORE_X + 100
		local y0 = Combat.surfaceHeight(c, x0, 0) - Combat.TORPEDO_DEPTH
		-- fired straight at the tank, homing on it, angled up out of the water
		local p = Combat.spawnProjectile(c, x0, y0, 0, -90, 20, 0, weapon.index, 0, 1, 10, lancer) :: number
		local maxY, removedAt = -math.huge, nil
		for _ = 1, 60 do
			Sim.step(sim)
			if c.projSlot[p] == nil then
				removedAt = c.px[p] or SHORE_X
				break
			end
			maxY = math.max(maxY, c.py[p])
			t.expect(Combat.waterDepth(c, c.px[p], c.pz[p]) > 0, "a live torpedo is always over water")
		end
		t.expect(c.projSlot[p] == nil, "the torpedo was removed")
		t.expect(maxY < Combat.surfaceHeight(c, x0, 0), `it stayed under the surface (max y {maxY})`)
		t.equal(sim.world.health[lancer], hp, "the land unit took no damage")
		t.expect(removedAt ~= nil, "removed within 4 s")
	end)

	t.test("a destroyer with sonar beats a submarine it detects", function()
		local sim, destroyer, sub = duel(7)
		local w = sim.world
		local killedAt, shotsBy = runDuel(sim, destroyer, sub, 900)
		t.expect(killedAt ~= nil, "the submarine was sunk")
		t.expect(w.slot[destroyer] ~= nil, "the destroyer survived")
		t.expect((shotsBy.ord_asw_torpedo or 0) > 0, "with its anti-submarine torpedoes")
		t.equal(shotsBy.ord_naval_gun, nil, "its gun never fired at the submarine")
		local maxHp = sim.defs.units.ord_crusader.health
		print(
			`    sub sunk at {string.format("%.1f", (killedAt or 0) / 15)} s; destroyer at {math.floor(w.health[destroyer])}/{maxHp} HP`
		)
	end)

	t.test("naval combat is deterministic", function()
		local a, ad, as = duel(11)
		local b, bd, bs = duel(11)
		for i = 1, 300 do
			Sim.step(a)
			Sim.step(b)
			if i % 50 == 0 then
				t.equal(Sim.hash(a), Sim.hash(b), `hash at tick {i}`)
			end
		end
		t.equal(a.world.health[ad], b.world.health[bd], "destroyer health")
		t.equal(a.world.slot[as] ~= nil, b.world.slot[bs] ~= nil, "sub alive")
	end)
end
