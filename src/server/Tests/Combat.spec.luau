--!strict
local Defs = require("@shared/Defs/Defs")
local Registry = require("@shared/Defs/Registry")
local Ballistics = require("../Sim/Combat/Ballistics")
local Combat = require("../Sim/Combat/Combat")
local ContactGrid = require("../Sim/Combat/ContactGrid")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- Registered defs plus test-only weapons/units (neutral prefix).
-- `weapon(id, overrides)` derives from ord_light_cannon; units derive from
-- ord_lancer with that weapon in slot 1.
local function testDefs(extra: { [string]: { [string]: any } }): Defs.DefSet
	local raw = deepCopy(Registry)
	for name, overrides in extra do
		local weaponId = `neu_{name}_gun`
		local w = Defs.extend(raw.weapons.ord_light_cannon, overrides)
		w.id = weaponId
		raw.weapons[weaponId] = w
		local unitId = `neu_{name}`
		local u = Defs.extend(raw.units.ord_lancer, { weapons = { { def = weaponId, turretPiece = "turret" } } })
		u.id = unitId
		u.faction = "neutral"
		u.model = unitId
		raw.units[unitId] = u
	end
	return Defs.build(raw)
end

local function newSim(defs: Defs.DefSet?, seed: number?): Sim.Sim
	return Sim.new({ seed = seed or 1, players = PLAYERS, mapId = "flat:64", scenario = "empty", defs = defs })
end

local function step(sim: Sim.Sim, ticks: number, onEvent: ((Combat.Event) -> ())?)
	for _ = 1, ticks do
		Sim.step(sim)
		if onEvent then
			for _, e in sim.combat.events do
				onEvent(e)
			end
		end
	end
end

local function teamCount(w: World.World, team: number): number
	local n = 0
	for _, id in w.ids do
		if w.team[id] == team then
			n += 1
		end
	end
	return n
end

local function duel(seed: number, maxTicks: number): (Sim.Sim, number?)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:64", scenario = "duel_test" })
	for _ = 1, maxTicks do
		Sim.step(sim)
		if teamCount(sim.world, 1) == 0 or teamCount(sim.world, 2) == 0 then
			return sim, sim.tick
		end
	end
	return sim, nil
end

return function(t: RunAll.Context)
	t.test("10 Lancers vs 10 Ravagers fight until one side is gone", function()
		local sim, endTick = duel(42, 3000)
		t.expect(endTick ~= nil, "the fight never ended")
		local order, chaos = teamCount(sim.world, 1), teamCount(sim.world, 2)
		t.expect((order == 0) ~= (chaos == 0), "exactly one side is wiped out")
		t.expect(sim.combat.stats.kills >= 10, "at least ten kills")
		t.expect(sim.combat.stats.shots > sim.combat.stats.kills, "more shots than kills")
		local wrecks = #sim.combat.wreckIds
		t.expect(wrecks > 0 and wrecks <= sim.combat.stats.kills, `wrecks {wrecks}`)
	end)

	t.test("the duel is deterministic across runs and replays", function()
		local a, endA = duel(42, 3000)
		local b, endB = duel(42, 3000)
		t.equal(endA, endB)
		t.equal(Sim.hash(a), Sim.hash(b))
		t.deepEqual(a.world.ids, b.world.ids)
		for _, id in a.world.ids do
			t.equal(a.world.health[id], b.world.health[id])
		end
		local replayed, mismatch = Sim.runReplay(Replay.parse(Replay.serialize(a.replay)), a.tick)
		t.equal(mismatch, nil)
		t.equal(Sim.hash(replayed), Sim.hash(a))
		local other = duel(43, 3000)
		t.notEqual(Sim.hash(other), Sim.hash(a), "a different seed changes the spread rolls and the outcome")
	end)

	t.test("a slow turret fires later than a fast one", function()
		local defs = testDefs({
			slow = { turret = { yawRate = 30 } },
			fast = { turret = { yawRate = 180 } },
		})
		local sim = newSim(defs)
		-- Both shooters face away (-X) from their own target 100 studs to +X.
		local slow = Spawn.unit(sim, "neu_slow", 1, -100, -80, -math.pi / 2)
		local fast = Spawn.unit(sim, "neu_fast", 1, -100, 80, -math.pi / 2)
		for _, z in { -80, 80 } do
			local dummy = Spawn.unit(sim, "ord_lancer", 2, 0, z, 0)
			World.setFireState(sim.world, dummy, World.FireState.HOLD_FIRE)
		end
		local first: { [number]: number } = {}
		step(sim, 200, function(e)
			if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and first[e.unit] == nil then
				first[e.unit] = e.tick
			end
		end)
		t.expect(first[fast] ~= nil and first[slow] ~= nil, "both fired")
		-- 180° at 180°/s ≈ 15 ticks; at 30°/s ≈ 90 ticks (plus up to 6 ticks of targeting stagger).
		t.expect(first[fast] <= 25, `fast turret first fired at tick {first[fast]}`)
		t.expect(first[slow] >= 85, `slow turret first fired at tick {first[slow]}`)
		t.expect(first[slow] - first[fast] >= 60, "slow fires much later")
	end)

	t.test("AoE damage falls off with distance, exactly", function()
		local sim = newSim()
		local w = sim.world
		local c = sim.combat
		local p = c.profiles[sim.defs.units.ord_lancer.index]
		-- Victims at center distances D from the blast point (0, mid-height, 0).
		local ids = {}
		local centers = { 0, 8, 14, 20, 30 }
		for i, d in centers do
			ids[i] = Spawn.unit(sim, "ord_lancer", 2, d, -40 + i * 16, 0) -- separate rows so they don't overlap
		end
		-- Re-place them on the x axis at their distances, spread around the blast.
		for i, d in centers do
			local angle = i * 1.1
			World.setPosition(w, ids[i], math.sin(angle) * d, math.cos(angle) * d)
		end
		ContactGrid.rebuild(c.contacts, w)
		local weapon = deepCopy(sim.defs.weapons.ord_light_cannon)
		weapon.aoe = 20
		weapon.edgeEffectiveness = 0.25
		weapon.damage.ARMORED = 100
		local y = Combat.groundHeight(c, 0, 0) + p.height / 2
		Combat.explode(c, w, 0, y, 0, weapon, 0, 1, 0)
		local got: { [number]: number } = {}
		for i = 1, c.dmgCount do
			got[c.dmgTarget[i]] = c.dmgAmount[i]
		end
		for i, d in centers do
			local surface = math.max(0, d - p.radius)
			local expected = if surface < 20 then 100 * (1 - (surface / 20) * 0.75) else nil
			if expected then
				t.expect(got[ids[i]] ~= nil and math.abs(got[ids[i]] - expected) < 1e-9, `unit at {d} studs: expected {expected}, got {got[ids[i]]}`)
			else
				t.equal(got[ids[i]], nil, `unit at {d} studs is outside the blast`)
			end
		end
		-- friendly fire off: same-team units are spared
		c.dmgCount = 0
		c.friendlyFire = false
		Combat.explode(c, w, 0, y, 0, weapon, 0, 2, 0)
		t.equal(c.dmgCount, 0, "no damage to allies without friendly fire")
	end)

	t.test("a shell's blast hits several units with falloff", function()
		local defs = testDefs({ mortar = { aoe = 16, edgeEffectiveness = 0.2, accuracy = 0, damage = { ARMORED = 200 } } })
		local sim = newSim(defs)
		local w = sim.world
		local shooter = Spawn.unit(sim, "neu_mortar", 1, -120, 0, math.pi / 2)
		local victims = {
			Spawn.unit(sim, "ord_lancer", 2, 0, 0, 0),
			Spawn.unit(sim, "ord_lancer", 2, 0, 9, 0),
			Spawn.unit(sim, "ord_lancer", 2, 0, -12, 0),
		}
		for _, v in victims do
			World.setFireState(w, v, World.FireState.HOLD_FIRE)
		end
		local impact: Combat.Event? = nil
		local before = {}
		for _, v in victims do
			before[v] = w.health[v]
		end
		for _ = 1, 120 do
			-- remember health right before the first impact's damage lands
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and impact == nil then
					impact = e
				end
			end
			if impact then
				break
			end
		end
		assert(impact, "no impact")
		t.equal(impact.unit, victims[1], "the shell struck the middle tank")
		local p = sim.combat.profiles[w.defIndex[victims[1]]]
		local damaged = 0
		for _, v in victims do
			local base = Combat.unitBase(sim.combat, w, v)
			local d = Ballistics.distanceToCylinder(impact.x :: number, impact.y :: number, impact.z :: number, w.posX[v], w.posZ[v], p.radius, base, base + p.height)
			local expected = if v == impact.unit then 200 else 200 * Ballistics.falloff(d, 16, 0.2)
			local lost = before[v] - w.health[v]
			t.expect(math.abs(lost - expected) < 1e-6, `unit {v}: lost {lost}, expected {expected}`)
			if lost > 0 then
				damaged += 1
			end
		end
		t.expect(damaged >= 2, `blast damaged {damaged} units`)
		local _ = shooter
	end)

	t.test("hitscan damage lands the same tick", function()
		local defs = testDefs({ laser = { type = "HITSCAN", accuracy = 0, aoe = 0 } })
		local sim = newSim(defs)
		local w = sim.world
		local shooter = Spawn.unit(sim, "neu_laser", 1, -60, 0, math.pi / 2)
		local target = Spawn.unit(sim, "ord_lancer", 2, 0, 0, 0)
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		local fired = false
		for _ = 1, 30 do
			local before = w.health[target]
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == shooter then
					fired = true
					t.expect(e.hit == true, "accuracy 0 always hits")
					t.equal(before - w.health[target], sim.defs.weapons.neu_laser_gun.damage.ARMORED, "full ARMORED damage, same tick")
				end
			end
			if fired then
				break
			end
		end
		t.expect(fired, "the laser fired")
	end)

	t.test("fast rounds don't tunnel; allies are never hit directly", function()
		local defs = testDefs({ rail = { projectileSpeed = 3000, gravity = 0, accuracy = 0, aoe = 0 } })
		local sim = newSim(defs)
		local w = sim.world
		local shooter = Spawn.unit(sim, "neu_rail", 1, -90, 0, math.pi / 2)
		local ally = Spawn.unit(sim, "ord_lancer", 1, -45, 0, 0) -- right in the line of fire
		local enemy = Spawn.unit(sim, "ord_lancer", 2, 0, 0, 0)
		World.setFireState(w, ally, World.FireState.HOLD_FIRE)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		local impacts = {}
		step(sim, 60, function(e)
			if e.kind == "IMPACT" then
				table.insert(impacts, e.unit)
			end
		end)
		t.expect(#impacts > 0, "the rail fired")
		for _, u in impacts do
			t.equal(u, enemy, "every round hit the enemy (200 studs per tick, 7-stud target)")
		end
		t.equal(w.health[ally], sim.defs.units.ord_lancer.health, "the ally in the way is untouched")
		local _ = shooter
	end)

	t.test("deaths leave wrecks unless overkill is high; damage uses armor class", function()
		local sim = newSim()
		local w = sim.world
		local c = sim.combat
		local light = Spawn.unit(sim, "ord_lancer", 2, 0, 0, 0)
		local heavy = Spawn.unit(sim, "ord_lancer", 2, 40, 0, 0)
		World.setHealth(w, light, 10)
		Combat.queueDamage(c, light, 100, 0) -- overkill 90 / 1100: wreck
		Combat.queueDamage(c, heavy, 5000, 0) -- overkill 3900 / 1100: obliterated
		local deaths = {}
		step(sim, 1, function(e)
			if e.kind == "DEATH" then
				deaths[e.unit] = e
			end
		end)
		t.expect(not World.isAlive(w, light) and not World.isAlive(w, heavy), "both died")
		t.expect(deaths[light] ~= nil and deaths[light].other ~= 0, "low overkill leaves a wreck")
		t.equal(deaths[heavy].other, 0, "high overkill leaves none")
		t.equal(deaths[heavy].severity, 255)
		t.equal(c.wreckSupply[deaths[light].other], sim.defs.units.ord_lancer.cost.supply * 0.5, "wreck worth half the supply cost")

		-- armor classes: the cannon does 165 to LIGHT, 141 to ARMORED (S-62)
		local cannon = sim.defs.weapons.ord_light_cannon
		t.equal(cannon.damage.LIGHT, 165)
		t.equal(cannon.damage.ARMORED, 141)
	end)

	t.test("fire states: hold fire never shoots, return fire only shoots back", function()
		local sim = newSim()
		local w = sim.world
		local holder = Spawn.unit(sim, "ord_lancer", 1, -60, -40, math.pi / 2)
		local returner = Spawn.unit(sim, "ord_lancer", 1, -60, 40, math.pi / 2)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 60, 40, -math.pi / 2)
		World.setFireState(w, holder, World.FireState.HOLD_FIRE)
		World.setFireState(w, returner, World.FireState.RETURN_FIRE)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		local shots: { [number]: number } = {}
		local function count(e: Combat.Event)
			if e.kind == "FIRE" or e.kind == "SPAWN_PROJ" then
				shots[e.unit] = (shots[e.unit] or 0) + 1
			end
		end
		step(sim, 90, count)
		t.equal(shots[holder], nil, "hold fire")
		t.equal(shots[returner], nil, "return fire waits to be attacked")
		-- the enemy opens fire on the returner
		World.setFireState(w, enemy, World.FireState.FIRE_AT_WILL)
		step(sim, 150, count)
		t.expect((shots[enemy] or 0) > 0, "enemy fired")
		-- The returner is the enemy's nearest target (120 vs 144 studs).
		t.equal(w.lastAttacker[returner], enemy, "the enemy attacked the returner")
		t.expect((shots[returner] or 0) > 0, "return fire shoots back")
		t.equal(shots[holder], nil, "hold fire still silent")
	end)
end
