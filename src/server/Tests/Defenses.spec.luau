--!strict
-- T2 defenses (S-96, client request 43): the beam towers (Radiance,
-- Inferno; BAR's Pulsar) and the flak towers (Lumen, Hailstorm).
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function power(sim: Sim.Sim, team: number, amount: number)
	local acc = sim.eco.accounts[team]
	acc.power.storage = math.max(acc.power.storage, amount)
	acc.power.stored = amount
end

-- Shots `id` fires over `ticks`; `each` runs after every step.
local function shots(sim: Sim.Sim, id: number, ticks: number, each: (() -> ())?): number
	local n = 0
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit == id then
				n += 1
			end
		end
		if each then
			each()
		end
	end
	return n
end

-- A beam tower of player 1 at the origin, a tank of player 2 at `dist`
-- studs, held still and harmless, and (with `spotter`) a scout of player 1
-- beside the tank so the tower's team sees it.
local function range(seed: number, tower: string, dist: number, spotter: boolean): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local w = sim.world
	local t = Spawn.unit(sim, tower, 1, 0, 0)
	local tank = Spawn.unit(sim, "chs_juggernaut", 2, 0, dist, math.pi)
	World.setFireState(w, tank, World.FireState.HOLD_FIRE)
	World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
	World.setHealth(w, tank, 1e6)
	if spotter then
		local scout = Spawn.unit(sim, "ord_herald", 1, 30, dist - 60, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		World.setMoveState(w, scout, World.MoveState.HOLD_POSITION)
	end
	return sim, t, tank
end

return function(t: RunAll.Context)
	t.test("Radiance: one very heavy lingering beam every 9 s at long range, 700 power a shot; none without the power", function()
		local sim, tower, tank = range(1, "ord_radiance", 600, true)
		local w = sim.world
		local acc = sim.eco.accounts[1]
		power(sim, 1, 5000)
		t.expect(bit32.band(w.state[tower], World.State.TOGGLED_ON) ~= 0, "it starts switched on")
		local before = w.health[tank]
		local drawn = acc.power.drawn
		-- (team storage is 1,000 without depots: top it up each tick)
		-- the first beam: its damage arrives over beamDuration (S-113), not at once
		local firstAt = nil
		local afterFirstTick = nil
		local n = shots(sim, tower, 15 * 14, function()
			acc.power.stored = acc.power.storage
			if firstAt == nil and w.health[tank] < before then
				firstAt = sim.tick
				afterFirstTick = before - w.health[tank]
			end
		end)
		t.equal(n, 2, "two shots in 14 s: the first once aimed, the next 9 s later")
		local full = sim.defs.weapons.ord_radiance_beam.damage.ARMORED
		t.expect(afterFirstTick ~= nil and afterFirstTick < full / 10, `a lingering beam: one tick's share first ({afterFirstTick})`)
		local hit = before - w.health[tank]
		t.expect(math.abs(hit - 2 * full) < 1, `2 × {full} on an armored tank, each over 2.5 s ({hit})`)
		t.expect(math.abs((acc.power.drawn - drawn) - 2 * 700) < 1, `700 power a shot ({acc.power.drawn - drawn})`)
		-- empty stores: no shot
		local held = 0
		held = shots(sim, tower, 15 * 20, function()
			acc.power.stored = 600 -- less than a shot, every tick
		end)
		t.equal(held, 0, "no shot while the stores hold less than 700")
	end)

	t.test("Radiance fires at radar blips and misses wobbling ones without Pinpointers (S-113)", function()
		local function run(pinpointers: number): (number, number)
			local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
			Spawn.unit(sim, "ord_watchtower", 1, -40, -300) -- radar only: the tank is a blip
			for i = 1, pinpointers do
				Spawn.unit(sim, "ord_witness", 1, -200 + i * 30, -460)
			end
			local tank = Spawn.unit(sim, "chs_juggernaut", 2, 0, 300, math.pi)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
			World.setHealth(w, tank, 1e6)
			local fired, missed = 0, 0
			for _ = 1, 15 * 60 do
				power(sim, 1, 5000)
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "FIRE" and e.unit == tower then
						fired += 1
						if not e.hit then
							missed += 1
						end
					end
				end
			end
			return fired, missed
		end
		local fired, missed = run(0)
		local firedP, missedP = run(6)
		print(`    Radiance at a blip: {missed} of {fired} missed without Pinpointers, {missedP} of {firedP} with six`)
		t.expect(fired >= 5, "it fires at the radar blip")
		t.expect(missed > 0, "and misses some without Pinpointers")
		t.expect(missedP < missed, "fewer with them")
	end)

	t.test("Radiance's beam is a hit-ray: enemies on its line are hurt, allies aren't (S-115)", function()
		local sim = Sim.new({ seed = 6, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		-- the tower picks the Juggernaut (armored first); a worker stands on
		-- the line just in front of it, an Order tank further back
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local far = Spawn.unit(sim, "chs_juggernaut", 2, 0, 300, math.pi)
		local near = Spawn.unit(sim, "chs_scrapper", 2, 0, 240, math.pi)
		local ally = Spawn.unit(sim, "ord_lancer", 1, 0, 100, 0)
		local scout = Spawn.unit(sim, "ord_herald", 1, 40, 250, 0)
		for _, id in { far, near, ally, scout } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e6)
		end
		local fired = shots(sim, tower, 15 * 6, function()
			power(sim, 1, 5000)
		end)
		t.expect(fired >= 1, "it fired at the far tank")
		t.expect(w.health[far] < 1e6, "the target took damage")
		t.expect(w.health[near] < 1e6, "so did the enemy worker on the line")
		t.equal(w.health[ally], 1e6, "the ally on the line took nothing")
	end)

	t.test("beam towers fire at an attack-ground point; the ray hurts what stands on its line (S-119, client request 53)", function()
		local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local crossing = Spawn.unit(sim, "chs_ravager", 2, 0, 0, math.pi) -- on the line, not visible to Order
		World.setFireState(w, crossing, World.FireState.HOLD_FIRE)
		World.setMoveState(w, crossing, World.MoveState.HOLD_POSITION)
		World.setHealth(w, crossing, 1e6)
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(0, 300)
		submit(sim, 1, { cmdType = Schema.CmdType.ATTACK_GROUND, flags = 0, unitIds = { tower }, cell = cell, offX = ox, offZ = oz })
		local ends = nil
		local fired = shots(sim, tower, 15 * 6, function()
			power(sim, 1, 5000)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower and ends == nil then
					ends = { e.x, e.z }
				end
			end
		end)
		t.expect(fired >= 1, "it fired at the ordered point")
		t.expect(ends ~= nil and math.abs(ends[2] - 300) < 20, `the beam ends at the point ({ends and ends[2]})`)
		t.expect(w.health[crossing] < 1e6, "the Ravager on the line took the ray")
		-- the Inferno: a single-target beam; nothing on the line is a miss on the ground
		local sim2 = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:128" })
		local w2 = sim2.world
		local inferno = Spawn.unit(sim2, "chs_inferno", 2, 0, 300)
		local nobody = Spawn.unit(sim2, "ord_lancer", 1, 200, -200, 0) -- off the line
		World.setFireState(w2, nobody, World.FireState.HOLD_FIRE)
		local c2, o2x, o2z = (sim2.map :: any).grid:encode(0, -100)
		local wr = Packer.Writer.new()
		Schema.encodeCommand(wr, { cmdType = Schema.CmdType.ATTACK_GROUND, flags = 0, unitIds = { inferno }, cell = c2, offX = o2x, offZ = o2z })
		assert(Sim.submit(sim2, 2, wr:finish()))
		local missed = 0
		shots(sim2, inferno, 15 * 6, function()
			power(sim2, 2, 5000)
			for _, e in sim2.combat.events do
				if e.kind == "FIRE" and e.unit == inferno and not e.hit then
					missed += 1
				end
			end
		end)
		t.expect(missed >= 1, "the Inferno fired at the empty ground")
		t.equal(w2.health[nobody], sim2.defs.units.ord_lancer.health, "and hurt nobody off its line")
	end)

	t.test("a burning beam holds the barrel on its line until it ends (S-119, client request 53)", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local runner = Spawn.unit(sim, "chs_ravager", 2, -200, 200, math.pi / 2)
		Spawn.unit(sim, "ord_herald", 1, 0, 120, 0) -- sees it
		World.setFireState(w, runner, World.FireState.HOLD_FIRE)
		World.setHealth(w, runner, 1e6)
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(300, 200)
		submit(sim, 2, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { runner }, cell = cell, offX = ox, offZ = oz })
		local key = World.slotKey(tower, 1)
		local firedAt, yawAtFire = nil, 0
		local moved = false
		for _ = 1, 15 * 10 do
			power(sim, 1, 5000)
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower and firedAt == nil then
					firedAt, yawAtFire = sim.tick, w.wYaw[key]
				end
			end
			if firedAt and sim.tick > firedAt and sim.tick < firedAt + 15 * 3 then
				if w.wYaw[key] ~= yawAtFire then
					moved = true
				end
			end
		end
		t.expect(firedAt ~= nil, "it fired at the moving Ravager")
		t.equal(moved, false, "the barrel stayed on the beam's line while it burned")
		t.expect(w.wYaw[key] ~= yawAtFire, "and tracked again after")
	end)

	t.test("a manual target stays while it lives, unseen too; when it dies the tower picks its own at once (S-125, client request 57)", function()
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local tank = Spawn.unit(sim, "chs_juggernaut", 2, 0, 250, math.pi)
		local other = Spawn.unit(sim, "chs_ravager", 2, 300, -100, math.pi) -- visible, nearer: the tower's own pick
		local spotter = Spawn.unit(sim, "ord_herald", 1, 40, 150, 0)
		Spawn.unit(sim, "ord_herald", 1, 300, -200, 0) -- sees the Ravager
		for _, id in { tank, other } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e6)
		end
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		submit(sim, 1, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { tower }, targetId = tank })
		local key = World.slotKey(tower, 1)
		shots(sim, tower, 15 * 2, function()
			power(sim, 1, 5000)
		end)
		t.equal(w.wTarget[key], tank, "on the ordered tank")
		-- the spotter goes: the tank lives, unseen
		Combat.queueDamage(sim.combat, spotter, 1e6, 0)
		local fired = shots(sim, tower, 15 * 12, function()
			power(sim, 1, 5000)
			t.expect(w.wTarget[key] ~= other, "never switches to the Ravager")
		end)
		t.equal(sim.orders.manualBlind[tower], true, "fires blind at the tank's last known position")
		t.expect(fired >= 1, `and keeps firing there ({fired})`)
		-- the tank dies: the tower takes the Ravager at once
		Combat.queueDamage(sim.combat, tank, 1e9, 0)
		Sim.step(sim) -- (Damage removes it)
		power(sim, 1, 5000)
		Sim.step(sim)
		t.equal(sim.orders.manual[tower], nil, "the manual target is gone")
		t.equal(w.wTarget[key], other, "and the tower picked its own target on the next tick")
	end)

	t.test("a beam at a destroyed structure's ghost misses at the spot instead of crashing the tick (S-126); ghosts only on orders (S-127)", function()
		local sim = Sim.new({ seed = 10, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local gen = Spawn.unit(sim, "chs_generator", 2, 0, 200)
		local scout = Spawn.unit(sim, "ord_herald", 1, 40, 100, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		for _ = 1, 6 do
			Sim.step(sim)
		end
		-- the team remembers the generator; the scout and then the generator go
		Combat.queueDamage(sim.combat, scout, 1e6, 0)
		Sim.step(sim)
		Combat.queueDamage(sim.combat, gen, 1e6, 0)
		local misses = 0
		local ok, err = pcall(function()
			for _ = 1, 15 * 20 do
				power(sim, 1, 5000)
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "FIRE" and e.unit == tower and not e.hit then
						misses += 1
					end
				end
			end
		end)
		t.expect(ok, `no crash ({err})`)
		t.equal(w.slot[gen], nil, "the generator is gone")
		-- (S-127: ghosts are for manual orders only, so on its own the tower
		-- doesn't fire at it; ordered, it does, and those shots miss)
		t.equal(misses, 0, "no shot at the ghost on its own")
		submit(sim, 1, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { tower }, targetId = gen })
		local ordered = 0
		for _ = 1, 15 * 12 do
			power(sim, 1, 5000)
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower then
					ordered += 1
					t.equal(e.hit, false, "a shot at a ghost is a miss")
				end
			end
		end
		t.expect(ordered >= 1, `ordered onto the ghost, it fires ({ordered})`)
	end)

	t.test("units don't pick a structure ghost on their own (S-127, the user)", function()
		local sim = Sim.new({ seed = 11, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local gen = Spawn.unit(sim, "chs_generator", 2, 0, 200)
		World.setHealth(w, gen, 1e6) -- (it may take a beam while still seen)
		local scout = Spawn.unit(sim, "ord_herald", 1, 40, 100, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		for _ = 1, 6 do
			Sim.step(sim)
		end
		Combat.queueDamage(sim.combat, scout, 1e6, 0) -- the generator becomes a ghost, alive
		local key = World.slotKey(tower, 1)
		local onGhost = 0
		for i = 1, 15 * 10 do
			power(sim, 1, 5000)
			Sim.step(sim)
			if i > 4 and w.wTarget[key] == gen then -- (sensors update every 2 ticks)
				onGhost += 1
			end
		end
		t.equal(onGhost, 0, "the tower never keeps or picks the ghost")
		t.expect(w.slot[gen] ~= nil, "the generator lives")
	end)

	t.test("the Inferno doesn't fire at radar-only contacts; seen, it does", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		power(sim, 2, 5000)
		local tower = Spawn.unit(sim, "chs_inferno", 2, 0, 0)
		local tank = Spawn.unit(sim, "ord_paladin", 1, 0, 450, math.pi)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
		World.setHealth(w, tank, 1e6)
		Spawn.unit(sim, "chs_eye", 2, -40, 0) -- radar: the tank is a contact, nothing sees it
		t.equal(shots(sim, tower, 15 * 15), 0, "a radar contact: no shot")
		local scout = Spawn.unit(sim, "chs_jackal", 2, 30, 390, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		World.setMoveState(w, scout, World.MoveState.HOLD_POSITION)
		t.expect(shots(sim, tower, 15 * 15) >= 1, "seen: it fires")
	end)

	t.test("switched off, a beam tower retracts: no fire, a quarter of the damage; on again, it fires", function()
		local sim, tower, tank = range(3, "ord_radiance", 500, true)
		local w = sim.world
		power(sim, 1, 5000)
		submit(sim, 1, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { tower }, value = 0 })
		Sim.step(sim)
		t.equal(bit32.band(w.state[tower], World.State.TOGGLED_ON), 0, "off")
		t.equal(shots(sim, tower, 15 * 12), 0, "no shot while retracted")
		local hp = w.health[tower]
		Combat.queueDamage(sim.combat, tower, 400, tank)
		Sim.step(sim)
		t.expect(math.abs((hp - w.health[tower]) - 100) < 1e-6, `400 damage → 100 retracted ({hp - w.health[tower]})`)
		submit(sim, 1, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { tower }, value = 1 })
		t.expect(shots(sim, tower, 15 * 12) >= 1, "on again: it fires")
		hp = w.health[tower]
		Combat.queueDamage(sim.combat, tower, 400, tank)
		Sim.step(sim)
		t.expect(math.abs((hp - w.health[tower]) - 400) < 1e-6, "full damage when on")
	end)

	t.test("flak towers shoot down aircraft over the base", function()
		for _, pair in { { "ord_lumen", "chs_harpy" }, { "chs_hailstorm", "ord_falcon" } } do
			local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:64" })
			local w = sim.world
			local owner = if string.sub(pair[1], 1, 4) == "ord_" then 1 else 2
			local tower = Spawn.unit(sim, pair[1], owner, 0, 0)
			local plane = Spawn.unit(sim, pair[2], 3 - owner, -150, 0, math.pi / 2)
			World.setFireState(w, plane, World.FireState.HOLD_FIRE)
			local fired = shots(sim, tower, 15 * 20)
			t.expect(fired > 0, `{pair[1]} fired at the {pair[2]} ({fired})`)
			t.expect(not World.isAlive(w, plane) or w.health[plane] < sim.defs.units[pair[2]].health, `{pair[1]}: the {pair[2]} took damage`)
		end
	end)

	-- S-106: missile batteries (Sanction, Scourge) answer artillery from
	-- beyond its range: a radar tower and a fire-control radar track an
	-- enemy artillery piece and a tank (tracking identifies them, D107); the
	-- battery picks the artillery, though the tank is nearer.
	t.test("missile batteries pick artillery over a nearer tank and outrange it", function()
		for _, set in { { "ord_sanction", "ord_watchtower", "chs_hellmouth", "chs_ravager", "ord_tribunal" }, { "chs_scourge", "chs_eye", "ord_verdict", "ord_lancer", "chs_seekerspire" } } do
			local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local owner = if string.sub(set[1], 1, 4) == "ord_" then 1 else 2
			local battery = Spawn.unit(sim, set[1], owner, 0, -400) -- (flat:128 spans ±512)
			Spawn.unit(sim, set[2], owner, -40, -200) -- radar over both targets
			Spawn.unit(sim, set[5], owner, 40, -200) -- and tracking
			local d = sim.defs.units[set[1]].maxRange - 40
			local arty = Spawn.unit(sim, set[3], 3 - owner, 0, d - 400, math.pi)
			local tank = Spawn.unit(sim, set[4], 3 - owner, 120, d - 480, math.pi)
			for _, id in { arty, tank } do
				World.setFireState(w, id, World.FireState.HOLD_FIRE)
				World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			end
			t.expect(sim.defs.units[set[3]].maxRange < d, `{set[3]} can't reach the battery`)
			local first = nil
			for _ = 1, 15 * 30 do
				power(sim, owner, 1000) -- the fire-control radar's drain
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "SPAWN_PROJ" and e.unit == battery and first == nil then
						first = sim.combat.pTarget and sim.combat.pTarget[e.other] or w.wTarget[World.slotKey(battery, 1)]
					end
				end
				if not World.isAlive(w, arty) then
					break
				end
			end
			t.equal(first, arty, `{set[1]} aimed its first salvo at the artillery`)
			t.expect(not World.isAlive(w, arty), `{set[1]} destroyed the {set[3]} within 30 s (health left {w.health[arty]})`)
		end
	end)
end
