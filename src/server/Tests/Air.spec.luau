--!strict
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Air = require("../Sim/Air")
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local TAU = 2 * math.pi

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function attackGround(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.ATTACK_GROUND, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function wrap(a: number): number
	a = a % TAU
	return if a > math.pi then a - TAU else a
end

local function dist(w: World.World, id: number, x: number, z: number): number
	return math.sqrt((w.posX[id] - x) ^ 2 + (w.posZ[id] - z) ^ 2)
end

-- A Falcon circling (-200, 0) and a Wasp flying in from the east.
local function intercept(seed: number): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local falcon = Spawn.unit(sim, "ord_falcon", 1, -200, 0, math.pi / 2)
	local wasp = Spawn.unit(sim, "chs_wasp", 2, 380, 30, -math.pi / 2)
	moveTo(sim, 1, { falcon }, -200, 0)
	moveTo(sim, 2, { wasp }, -450, 30)
	-- no flares: this spec is about flight, ammo and rearming; countermeasures
	-- are EW.spec's subject (with flares the 4 missiles may all be decoyed)
	sim.ew.flares[wasp] = 0
	return sim, falcon, wasp
end

return function(t: RunAll.Context)
	t.test("a fighter intercepts, kills, then circles its point; never below minimum speed", function()
		local sim, falcon, wasp = intercept(3)
		local w = sim.world
		local minSpeed = sim.defs.units.ord_falcon.movement.minSpeed :: number
		local killedAt, closest = nil, math.huge
		for _ = 1, 1500 do
			Sim.step(sim)
			t.expect(w.speed[falcon] >= minSpeed - 1e-9, `fighter slowed to {w.speed[falcon]}`)
			if w.slot[wasp] then
				closest = math.min(closest, dist(w, falcon, w.posX[wasp], w.posZ[wasp]))
			elseif killedAt == nil then
				killedAt = sim.tick
				break
			end
		end
		t.expect(killedAt ~= nil, "the helicopter was shot down")
		t.expect(closest < 320, `the fighter closed to missile range (closest {closest})`)
		-- afterwards: back to circling (-200, 0)
		for _ = 1, 300 do
			Sim.step(sim)
		end
		local turned, prev = 0, w.heading[falcon]
		for _ = 1, 450 do
			Sim.step(sim)
			t.expect(w.speed[falcon] >= minSpeed - 1e-9, "minimum speed while circling")
			local d = dist(w, falcon, -200, 0)
			t.expect(d > 80 and d < 420, `circling at {d} studs from its point`)
			turned += math.abs(wrap(w.heading[falcon] - prev))
			prev = w.heading[falcon]
		end
		t.expect(turned > TAU, `heading turned {turned} rad in 30 s: it circles`)
		t.equal(w.alt[falcon], Air.ALTITUDE.JET, "cruise altitude")
	end)

	t.test("an empty fighter flies to a pad, lands, rearms and goes back out", function()
		local sim, falcon = intercept(5)
		local w = sim.world
		local pad = Spawn.unit(sim, "ord_airpad", 1, -420, 200)
		sim.air.ammo[falcon] = 1 -- one shot left
		local phases = { "fly" }
		local landedAt = nil
		for _ = 1, 3000 do
			Sim.step(sim)
			local phase = sim.air.phase[falcon]
			if phases[#phases] ~= phase then
				table.insert(phases, phase)
				if phase == "rearm" then
					landedAt = { w.posX[falcon], w.posZ[falcon] }
					t.expect(bit32.band(w.state[falcon], World.State.LANDED) ~= 0, "LANDED while rearming")
				end
			end
			if #phases == 4 then
				break
			end
		end
		t.deepEqual(phases, { "fly", "return", "rearm", "fly" })
		t.expect(landedAt ~= nil and landedAt[1] == w.posX[pad] and landedAt[2] == w.posZ[pad], "landed on the pad")
		t.equal(sim.air.ammo[falcon], sim.defs.units.ord_falcon.ammo, "full ammo again")
		t.equal(bit32.band(w.state[falcon], World.State.LANDED), 0, "took off")
		for _ = 1, 600 do
			Sim.step(sim)
		end
		t.expect(dist(w, falcon, w.posX[pad], w.posZ[pad]) > 150, "went back out")
		t.expect(dist(w, falcon, -200, 0) < 420, "back near its patrol point")
	end)

	t.test("rearming slows down when the team stalls", function()
		local function rearmTicks(stall: boolean): number
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local pad = Spawn.unit(sim, "ord_airpad", 1, 0, 0)
			if stall then
				Spawn.unit(sim, "ord_generator", 1, 200, 200) -- 20 power/s, nothing stored
				sim.eco.accounts[1].power.stored = 0
			end
			local falcon = Spawn.unit(sim, "ord_falcon", 1, 40, 0)
			sim.air.ammo[falcon] = 0
			Air.onEmpty(sim, falcon)
			local landed, done = nil, nil
			for _ = 1, 3000 do
				Sim.step(sim)
				local phase = sim.air.phase[falcon]
				if phase == "rearm" and landed == nil then
					landed = sim.tick
				elseif phase == "fly" and landed ~= nil then
					done = sim.tick
					break
				end
			end
			t.expect(landed ~= nil and done ~= nil, "landed and finished rearming")
			local _ = pad
			return (done :: number) - (landed :: number)
		end
		local full, stalled = rearmTicks(false), rearmTicks(true)
		-- 4 rounds × 2 s = 8 s = 120 ticks at full economy
		t.expect(math.abs(full - 120) <= 3, `full-economy rearm took {full} ticks`)
		-- 4 × 150 power at 20 power/s ≈ 30 s
		t.expect(stalled > 3 * full, `stalled rearm took {stalled} ticks vs {full}`)
	end)

	t.test("helicopters hover at their band", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local heli = Spawn.unit(sim, "ord_guardian", 1, -100, 0)
		moveTo(sim, 1, { heli }, 100, 50)
		for _ = 1, 600 do
			Sim.step(sim)
		end
		t.expect(dist(w, heli, 100, 50) < 4, "arrived")
		t.equal(w.speed[heli], 0, "hovering")
		t.equal(w.alt[heli], Air.ALTITUDE.HELI)
	end)

	t.test("air combat is deterministic", function()
		local function run(): number
			local sim = intercept(9)
			for _ = 1, 600 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)

	-- An Absolution bomber 600 studs west of three parked Ravagers, with an
	-- Order spotter keeping them VISIBLE; the bomber is told to fight there.
	local function bombRange(seed: number, moving: boolean): (Sim.Sim, number, { number })
		local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -450, 0, math.pi / 2)
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 150, 0) -- 100 studs from the targets: in sight
		local targets = {}
		for i = 1, 3 do
			local id = Spawn.unit(sim, "chs_ravager", 2, 150 + (i - 2) * 20, -100, 0)
			table.insert(targets, id)
			w.fireState[id] = World.FireState.HOLD_FIRE
			World.setHealth(w, id, 1e6) -- survive, so every bomb can be judged
		end
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		moveTo(sim, 1, { bomber }, 150, -100)
		if moving then
			moveTo(sim, 2, targets, 150, 250) -- driving north under the bombs
		end
		return sim, bomber, targets
	end

	-- Steps `ticks`; returns bombs released and how many landed within the
	-- blast radius of a target unit (judged at impact).
	local function judge(sim: Sim.Sim, bomber: number, targets: { number }, ticks: number): (number, number, { number })
		local w = sim.world
		local released, near = 0, 0
		local releaseTicks = {}
		local aoe = sim.defs.weapons.ord_bomb.aoe :: number
		for _ = 1, ticks do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					released += 1
					table.insert(releaseTicks, sim.tick)
				elseif e.kind == "IMPACT" and e.x then
					local best = math.huge
					for _, t in targets do
						if w.slot[t] then
							best = math.min(best, math.sqrt((w.posX[t] - (e.x :: number)) ^ 2 + (w.posZ[t] - (e.z :: number)) ^ 2))
						end
					end
					if best <= aoe then
						near += 1
					end
				end
			end
		end
		return released, near, releaseTicks
	end

	t.test("bombers make runs and release at the lead point: bombs land on parked targets", function()
		local sim, bomber, targets = bombRange(21, false)
		t.equal(sim.world.alt[bomber], Air.ALTITUDE.BOMBER, "bombers fly in their own band")
		local released, near = judge(sim, bomber, targets, 1800)
		local ammo = sim.defs.units.ord_absolution.ammo :: number
		t.equal(released, ammo, `all {ammo} bombs dropped`)
		t.expect(near >= ammo - 1, `{near} of {released} bombs landed within the blast radius`)
		print(`    parked targets: {near} of {released} bombs within the blast radius`)
	end)

	t.test("the lead point accounts for a moving target", function()
		local sim, bomber, targets = bombRange(22, true)
		local released, near = judge(sim, bomber, targets, 1800)
		t.expect(released >= 2, `bombs dropped on the moving column ({released})`)
		t.expect(near >= released - 1, `{near} of {released} bombs landed within the blast radius of a moving target`)
		print(`    moving column: {near} of {released} bombs within the blast radius`)
	end)

	t.test("after a release the bomber egresses straight, then comes round for the next run", function()
		local sim, bomber, targets = bombRange(23, false)
		local w = sim.world
		local headingAt: { number } = {}
		local releaseTick: number? = nil
		for _ = 1, 1800 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber and releaseTick == nil then
					releaseTick = sim.tick
				end
			end
			if releaseTick and sim.tick - releaseTick <= Air.EGRESS_TICKS then
				table.insert(headingAt, w.heading[bomber])
			end
			if releaseTick and sim.tick - releaseTick > Air.EGRESS_TICKS + 5 then
				break
			end
		end
		t.expect(releaseTick ~= nil, "released")
		for i = 2, #headingAt do
			t.expect(math.abs(headingAt[i] - headingAt[1]) < 1e-9, "heading held during egress")
		end
		local _ = targets
	end)

	t.test("an empty bomber flies home, rearms, and resumes its runs", function()
		local sim, bomber, targets = bombRange(24, false)
		Spawn.unit(sim, "ord_airpad", 1, -450, -300)
		local phases = { "fly" }
		local drops = 0
		for _ = 1, 6000 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					drops += 1
				end
			end
			local phase = sim.air.phase[bomber]
			if phases[#phases] ~= phase then
				table.insert(phases, phase)
			end
			if #phases >= 4 and drops > (sim.defs.units.ord_absolution.ammo :: number) then
				break
			end
		end
		t.deepEqual({ phases[1], phases[2], phases[3], phases[4] }, { "fly", "return", "rearm", "fly" })
		t.expect(drops > (sim.defs.units.ord_absolution.ammo :: number), `bombed again after rearming ({drops} drops)`)
		local _ = targets
	end)

	t.test("bomb runs are deterministic", function()
		local function run(): number
			local sim, bomber, targets = bombRange(25, true)
			judge(sim, bomber, targets, 900)
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)

	-- Team knowledge, not server truth (D100): a Chaos plant that Order saw
	-- once is destroyed while nobody watches. Order still remembers it, so a
	-- bomber sent later bombs the empty spot, until a spotter sees it again.
	t.test("bombers bomb a ghost whose structure died unseen, until the spot is seen again", function()
		local sim = Sim.new({ seed = 34, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local plant = Spawn.unit(sim, "chs_vehplant", 2, 150, -100)
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 150, 0)
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		for _ = 1, 4 do
			Sim.step(sim)
		end
		World.setPosition(w, spotter, -450, 450) -- leaves: the plant is a ghost
		for _ = 1, 4 do
			Sim.step(sim)
		end
		Combat.queueDamage(sim.combat, plant, 1e9, 0) -- destroyed unseen
		Sim.step(sim)
		t.expect(w.slot[plant] == nil, "the plant is gone")
		t.equal(Sensors.level(sim, 1, plant), Sensors.Level.GHOST, "Order still remembers it")
		-- a bomber arrives from beyond its acquisition range
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -450, -400, math.pi / 2)
		moveTo(sim, 1, { bomber }, 150, -100)
		local drops, onGround = 0, 0
		for _ = 1, 900 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					drops += 1
				elseif e.kind == "IMPACT" and e.unit == 0 and e.x and math.sqrt((e.x - 150) ^ 2 + ((e.z :: number) + 100) ^ 2) < 40 then
					onGround += 1
				end
			end
		end
		t.expect(drops >= 1, `the bomber bombed the remembered plant ({drops} bombs)`)
		t.expect(onGround >= 1, `the bombs hit empty ground where it stood ({onGround})`)
		-- a spotter sees the spot again: the ghost is forgotten, the bombing stops
		World.setPosition(w, spotter, 150, -40)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, plant), Sensors.Level.HIDDEN, "seen again: the ghost is gone")
		local later = 0
		for _ = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					later += 1
				end
			end
		end
		t.equal(later, 0, "no bombs once the spot is seen empty")
		print(`    dead ghost: {drops} bombs on the remembered plant, {onGround} landed on its empty spot`)
	end)

	t.test("ATTACK_GROUND: a bomber bombs an empty spot until another order", function()
		local sim = Sim.new({ seed = 35, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -450, 0, math.pi / 2)
		local tank = Spawn.unit(sim, "ord_lancer", 1, -400, 200)
		attackGround(sim, 1, { bomber, tank }, 100, 50)
		local near, drops = 0, 0
		for _ = 1, 900 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					drops += 1
				elseif e.kind == "IMPACT" and e.x and math.sqrt((e.x - 100) ^ 2 + ((e.z :: number) - 50) ^ 2) <= 10 then
					near += 1
				end
			end
		end
		t.expect(drops >= 2, `bombs dropped on the spot ({drops})`)
		t.expect(near >= drops - 1, `{near} of {drops} landed within 10 studs of it`)
		t.equal(sim.air.groundX[tank], nil, "only bombers take the order")
		moveTo(sim, 1, { bomber }, -300, 0)
		Sim.step(sim)
		t.equal(sim.air.groundX[bomber], nil, "a move order cancels it")
		local later = 0
		for _ = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					later += 1
				end
			end
		end
		t.equal(later, 0, "no more bombs after the move")
		print(`    attack-ground: {near} of {drops} bombs within 10 studs`)
		local _ = w
	end)

	-- Missile guidance (D97): a Seraph radar SAM against a Harpy circling
	-- 100 studs away. Pure pursuit with contact fuses never hit a circling
	-- jet; lead pursuit and the proximity fuse bring it down.
	t.test("a SAM shoots down a circling jet (lead pursuit, proximity fuse)", function()
		local sim = Sim.new({ seed = 33, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local sam = Spawn.unit(sim, "ord_seraph", 1, 0, 0)
		local jet = Spawn.unit(sim, "chs_harpy", 2, 300, 0, -math.pi / 2)
		w.fireState[jet] = World.FireState.HOLD_FIRE
		moveTo(sim, 2, { jet }, 100, 0)
		local launched, bursts = 0, 0
		local down: number? = nil
		for _ = 1, 1200 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == sam then
					launched += 1
				elseif e.kind == "IMPACT" and e.unit == jet then
					bursts += 1
				end
			end
			if w.slot[jet] == nil then
				down = sim.tick
				break
			end
		end
		t.expect(down ~= nil, `the Harpy is shot down ({launched} missiles, {bursts} on target)`)
		t.expect(bursts >= 1 and launched <= 12, `within a dozen missiles ({bursts} of {launched} on target)`)
		print(`    Seraph vs circling Harpy: down at tick {down}, {bursts} of {launched} missiles on target`)
	end)

	-- Unseen targets (D96). Steps `ticks` and returns, per bomb that landed:
	-- the sensor level of the bomber's target at release, the impact's
	-- distance to the believed and to the true position of the target at
	-- release, and whether it damaged the target.
	type Drop = { level: number, toBelieved: number, toTrue: number, hit: boolean }
	local function unseenDrops(sim: Sim.Sim, bomber: number, ticks: number): { Drop }
		local w = sim.world
		local pending: { [number]: { level: number, target: number, bx: number, bz: number, tx: number, tz: number, hp: number } } = {}
		local drops: { Drop } = {}
		for _ = 1, ticks do
			for _, r in pending do
				r.hp = w.health[r.target]
			end
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					local target = w.wTarget[World.slotKey(bomber, 1)]
					local bx, bz, level = Sensors.knownPosition(sim, w.ally[bomber], target)
					pending[e.other] = { level = level, target = target, bx = bx :: number, bz = bz :: number, tx = w.posX[target], tz = w.posZ[target], hp = w.health[target] }
				elseif e.kind == "IMPACT" and pending[e.other] and e.x then
					local r = pending[e.other]
					pending[e.other] = nil
					local ix, iz = e.x :: number, e.z :: number
					table.insert(drops, {
						level = r.level,
						toBelieved = math.sqrt((ix - r.bx) ^ 2 + (iz - r.bz) ^ 2),
						toTrue = math.sqrt((ix - r.tx) ^ 2 + (iz - r.tz) ^ 2),
						hit = w.health[r.target] < r.hp, -- damaged by this bomb
					})
				end
			end
		end
		return drops
	end

	-- A Plague 600 studs east of a parked Lancer that only Chaos radar sees
	-- (an Eye tower: radar error 45 studs, so the blip is well off the tank).
	t.test("bombs target radar contacts and land on the wobbled position", function()
		local sim = Sim.new({ seed = 31, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "chs_plague", 2, 450, 0, -math.pi / 2)
		Spawn.unit(sim, "chs_eye", 2, 200, 250) -- radar 600 reaches the target; sight 160 doesn't
		local target = Spawn.unit(sim, "ord_lancer", 1, -150, -100, 0)
		w.fireState[target] = World.FireState.HOLD_FIRE
		World.setHealth(w, target, 1e6)
		moveTo(sim, 2, { bomber }, -150, -100)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 2, target), Sensors.Level.RADAR, "the target is a radar contact only")
		local drops = unseenDrops(sim, bomber, 1800)
		local onRadar, believed, actual = 0, 0, 0
		for _, d in drops do
			if d.level == Sensors.Level.RADAR then
				onRadar += 1
				believed += d.toBelieved
				actual += d.toTrue
			end
		end
		t.expect(onRadar >= 3, `bombs released on the radar contact ({onRadar} of {#drops})`)
		believed /= math.max(onRadar, 1)
		actual /= math.max(onRadar, 1)
		-- a release is allowed within aoe / 2 + radius across the track (Air.bombRelease)
		local weapon = sim.defs.weapons.chs_bomb
		local tolerance = (weapon.aoe :: number) / 2 + sim.combat.profiles[w.defIndex[target]].radius + weapon.accuracy
		t.expect(believed <= tolerance, `bombs land on the believed (wobbled) position: {believed} studs on average (release tolerance {tolerance})`)
		t.expect(actual > believed + 10, `and miss the true position by about the radar error: {actual} studs on average`)
		print(`    radar contact: {onRadar} drops, {string.format("%.1f", believed)} studs from the blip, {string.format("%.1f", actual)} from the tank`)
	end)

	t.test("bombs target ghost structures at their last known position", function()
		local sim = Sim.new({ seed = 32, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -450, 0, math.pi / 2)
		local plant = Spawn.unit(sim, "chs_vehplant", 2, 150, -100)
		World.setHealth(w, plant, 1e6)
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 150, 0)
		w.fireState[spotter] = World.FireState.HOLD_FIRE
		for _ = 1, 4 do
			Sim.step(sim)
		end
		World.setPosition(w, spotter, -450, 450) -- the spotter leaves; nobody sees the plant now
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, plant), Sensors.Level.GHOST, "the plant is a ghost")
		moveTo(sim, 1, { bomber }, 150, -100)
		local drops = unseenDrops(sim, bomber, 1800)
		local onGhost, hits = 0, 0
		for _, d in drops do
			if d.level == Sensors.Level.GHOST then
				onGhost += 1
				hits += if d.hit then 1 else 0
			end
		end
		t.expect(onGhost >= 2, `bombs released on the ghost ({onGhost} of {#drops})`)
		t.equal(hits, onGhost, "every bomb released on the ghost damaged the plant")
		print(`    ghost structure: {onGhost} of {#drops} drops released on the ghost, {hits} damaged it`)
	end)
end
