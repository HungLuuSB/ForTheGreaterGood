--!strict
-- Unit order queues and behaviors (S-4): shift-queue, FIGHT, PATROL, GUARD,
-- ATTACK, REPAIR, RECLAIM, queued BUILD, factory rally and repeat.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local QUEUE = Schema.CmdFlag.QUEUE
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function at(sim: Sim.Sim, cmdType: number, player: number, ids: { number }, x: number, z: number, queued: boolean?)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = cmdType, flags = if queued then QUEUE else 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

local function on(sim: Sim.Sim, cmdType: number, player: number, ids: { number }, target: number, queued: boolean?)
	submit(sim, player, { cmdType = cmdType, flags = if queued then QUEUE else 0, unitIds = ids, targetId = target })
end

local function steps(sim: Sim.Sim, n: number, each: ((number) -> boolean?)?)
	for i = 1, n do
		Sim.step(sim)
		if each and each(i) then
			return
		end
	end
end

local function dist(w: World.World, id: number, x: number, z: number): number
	return math.sqrt((w.posX[id] - x) ^ 2 + (w.posZ[id] - z) ^ 2)
end

local function powered(sim: Sim.Sim)
	for _, team in { 1, 2 } do
		local acc = sim.eco.accounts[team]
		acc.supply.stored = acc.supply.storage
		acc.power.stored = acc.power.storage
	end
end

return function(t: RunAll.Context)
	t.test("shift queues moves in order; a plain command replaces the queue", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -150, -150)
		at(sim, CT.MOVE, 1, { tank }, 100, -150)
		at(sim, CT.MOVE, 1, { tank }, 100, 100, true)
		local reachedA, reachedBAfterA = false, false
		steps(sim, 900, function()
			reachedA = reachedA or dist(w, tank, 100, -150) < 10
			reachedBAfterA = reachedA and dist(w, tank, 100, 100) < 10
			return reachedBAfterA
		end)
		t.expect(reachedA and reachedBAfterA, "went to A, then B")
		steps(sim, 120, function()
			return sim.orders.queue[tank] == nil
		end)
		t.equal(sim.orders.queue[tank], nil, "queue empty once it arrives")
		-- replace: a queued pair, then a plain move cancels both
		at(sim, CT.MOVE, 1, { tank }, -150, 100)
		at(sim, CT.MOVE, 1, { tank }, -150, -150, true)
		steps(sim, 2)
		at(sim, CT.MOVE, 1, { tank }, 0, 0)
		steps(sim, 2)
		t.equal(#(sim.orders.queue[tank] :: any), 1, "replaced: only the new move")
		steps(sim, 600, function()
			return sim.orders.queue[tank] == nil
		end)
		t.expect(dist(w, tank, 0, 0) < 10, "it went to the new point")
	end)

	-- A Lancer crosses a parked enemy's range: on FIGHT it stops to engage;
	-- on MOVE it drives through.
	local function crossing(kind: number): (number, number)
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 0, 120)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		World.setHealth(w, enemy, 1e6)
		at(sim, kind, 1, { tank }, 200, 0)
		local held, shots = 0, 0
		steps(sim, 300, function()
			if sim.orders.hold[tank] and w.speed[tank] < 1 then
				held += 1
			end
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == tank then
					shots += 1
				end
			end
			return nil
		end)
		return held, shots
	end

	t.test("FIGHT holds to engage what it meets; MOVE drives on", function()
		local heldFight, shotsFight = crossing(CT.FIGHT)
		local heldMove = crossing(CT.MOVE)
		t.expect(heldFight > 30 and shotsFight > 0, `attack-move stopped and fired ({heldFight} ticks held, {shotsFight} shots)`)
		t.equal(heldMove, 0, "a plain move never holds")
	end)

	-- S-14 (BAR attack-move): advance while no enemy is within weapon range,
	-- stop and fire when one is, go on when none are left. Seeing an enemy
	-- isn't a reason to stop, and neither is a target Targeting still keeps
	-- just beyond range (its 10% hysteresis).
	t.test("attack-move holds only while an enemy is within firing range", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -220, 0, math.pi / 2)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 0, 110)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		World.setHealth(w, enemy, 1e6)
		local spotter = Spawn.unit(sim, "ord_herald", 1, 0, 70) -- the team sees the enemy from the start
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		World.setHealth(w, spotter, 1e6)
		local range = sim.combat.profiles[w.defIndex[tank]].weapons[1].range + sim.combat.profiles[w.defIndex[enemy]].radius
		at(sim, CT.FIGHT, 1, { tank }, 220, 0)
		local heldOut, heldIn, seenOut, retreated = 0, 0, 0, false
		-- the hold is decided at the start of a tick (Commands), from the
		-- positions the previous tick ended with
		local d = dist(w, tank, w.posX[enemy], w.posZ[enemy])
		steps(sim, 1500, function(i)
			local before = d
			d = dist(w, tank, w.posX[enemy], w.posZ[enemy])
			if before > range + 0.5 then
				seenOut += 1
				if sim.orders.hold[tank] then
					heldOut += 1
				end
			elseif sim.orders.hold[tank] then
				heldIn += 1
			end
			if heldIn >= 45 and not retreated then
				retreated = true
				at(sim, CT.MOVE, 2, { enemy }, 40, 240) -- backs off out of range
			end
			return retreated and dist(w, tank, 220, 0) < 30
		end)
		t.expect(seenOut > 30, `the enemy was seen out of range for a while ({seenOut} ticks)`)
		t.equal(heldOut, 0, "never held with the enemy beyond firing range")
		t.expect(heldIn >= 45, `held to fire once in range ({heldIn} ticks)`)
		t.expect(dist(w, tank, 220, 0) < 30, `went on to the goal once nothing was in range ({dist(w, tank, 220, 0)} studs left)`)
	end)

	t.test("PATROL goes back and forth between the start and the point", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -150, 0)
		at(sim, CT.PATROL, 1, { tank }, 150, 0)
		local ends, last = 0, ""
		steps(sim, 2400, function()
			local here = if dist(w, tank, 150, 0) < 12 then "far" elseif dist(w, tank, -150, 0) < 12 then "start" else ""
			if here ~= "" and here ~= last then
				ends += 1
				last = here
			end
			return nil
		end)
		t.expect(ends >= 4, `visited the two ends in turn ({ends} times)`)
		t.expect(sim.orders.queue[tank] ~= nil, "a patrol never ends by itself")
	end)

	t.test("GUARD follows an ally and ends when it is gone", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local guard = Spawn.unit(sim, "ord_lancer", 1, -200, -200)
		local vip = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		on(sim, CT.GUARD, 1, { guard }, vip)
		at(sim, CT.MOVE, 1, { vip }, 200, 200)
		local worst = 0
		steps(sim, 900, function(i)
			if i > 300 then
				worst = math.max(worst, dist(w, guard, w.posX[vip], w.posZ[vip]))
			end
			return nil
		end)
		t.expect(worst < 80 + 40, `stayed near the guarded unit ({worst} studs at worst)`)
		Combat.queueDamage(sim.combat, vip, 1e9, 0)
		steps(sim, 3)
		t.equal(sim.orders.queue[guard], nil, "the guarded unit died: order done")
	end)

	t.test("ATTACK: forced fire on a known target, even on hold fire; hidden targets are refused", function()
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local near = Spawn.unit(sim, "chs_ravager", 2, -60, 40) -- closer, not ordered
		local target = Spawn.unit(sim, "chs_ravager", 2, 120, -40)
		local spotter = Spawn.unit(sim, "ord_lancer", 1, 100, -120)
		for _, id in { near, target, spotter } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		World.setHealth(w, near, 1e6)
		World.setHealth(w, target, 1e6)
		steps(sim, 4)
		on(sim, CT.ATTACK, 1, { tank }, target)
		local atTarget, atNear = 0, 0
		steps(sim, 600, function()
			local key = World.slotKey(tank, 1)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == tank then
					if w.wTarget[key] == target then
						atTarget += 1
					elseif w.wTarget[key] == near then
						atNear += 1
					end
				end
			end
			return nil
		end)
		t.expect(atTarget >= 3, `fired at the ordered target ({atTarget} shots)`)
		t.equal(atNear, 0, "never at the nearer one")
		-- a hidden unit: the order is refused (no info leak, no cheating)
		local hidden = Spawn.unit(sim, "chs_ravager", 2, 250, 250)
		World.setFireState(w, hidden, World.FireState.HOLD_FIRE)
		steps(sim, 2)
		on(sim, CT.ATTACK, 1, { spotter }, hidden)
		steps(sim, 2)
		t.equal(sim.orders.queue[spotter], nil, "ATTACK on a unit the team doesn't know is ignored")
	end)

	t.test("REPAIR heals a damaged unit for free; RECLAIM and BUILD queue up", function()
		local sim = Sim.new({ seed = 6, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		World.setHealth(w, tank, 500)
		local supplyBefore = sim.eco.accounts[1].supply.stored
		on(sim, CT.REPAIR, 1, { mason }, tank)
		local full = sim.defs.units.ord_lancer.health
		steps(sim, 600, function()
			return w.health[tank] >= full
		end)
		t.equal(w.health[tank], full, "repaired to full")
		steps(sim, 2)
		t.expect(sim.eco.accounts[1].supply.stored >= supplyBefore - 1e-6, "for free")
		t.equal(sim.orders.queue[mason], nil, "then idle")

		-- two wrecks reclaimed in queue order
		local c = sim.combat
		local function wreck(x: number): number
			local id = Spawn.unit(sim, "chs_ravager", 2, x, 120)
			Combat.queueDamage(c, id, w.health[id], 0) -- exact kill: leaves a wreck
			steps(sim, 2)
			return c.wreckIds[#c.wreckIds]
		end
		local a, b = wreck(-60), wreck(60)
		on(sim, CT.RECLAIM, 1, { mason }, a)
		on(sim, CT.RECLAIM, 1, { mason }, b, true)
		local goneA, goneB = 0, 0
		steps(sim, 1500, function(i)
			if goneA == 0 and c.wreckX[a] == nil then
				goneA = i
			end
			if goneB == 0 and c.wreckX[b] == nil then
				goneB = i
			end
			return goneA > 0 and goneB > 0
		end)
		t.expect(goneA > 0 and goneB > goneA, `reclaimed A (tick {goneA}) then B (tick {goneB})`)

		-- two generators built one after the other
		local gen = sim.defs.units.ord_generator.index
		local g = (sim.map :: any).grid
		local function build(x: number, z: number, queued: boolean)
			local cell, ox, oz = g:encode(x, z)
			submit(sim, 1, { cmdType = CT.BUILD, flags = if queued then QUEUE else 0, unitIds = { mason }, defIndex = gen, cell = cell, offX = ox, offZ = oz, facing = 0 })
		end
		build(-100, -100, false)
		build(100, -100, true)
		local done = 0
		steps(sim, 3000, function()
			powered(sim)
			for _, e in sim.combat.events do
				if e.kind == "BUILD_DONE" then
					done += 1
				end
			end
			return done >= 2
		end)
		t.equal(done, 2, "both queued structures were built")
	end)

	t.test("factory rally point and repeat", function()
		local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150)
		at(sim, CT.MOVE, 1, { plant }, 150, 150) -- rally point
		submit(sim, 1, { cmdType = CT.REPEAT, flags = 0, unitIds = { plant }, value = 1 })
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_herald.index, cell = 0, offX = 0, offZ = 0, facing = 0 })
		local produced = {}
		steps(sim, 6000, function()
			powered(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" and e.other == plant then
					table.insert(produced, e.unit)
				end
			end
			return #produced >= 2
		end)
		t.expect(#produced >= 2, `repeat kept producing ({#produced} from one queued item)`)
		steps(sim, 900)
		t.expect(dist(w, produced[1], 150, 150) < 40, "the first one went to the rally point")
		t.equal(#(sim.build.queue[plant] :: any), 1, "the queue still holds the repeated item")
	end)

	t.test("a factory's order list: each new unit takes a copy, in order; a plain order replaces it, STOP clears it (S-95)", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local o = sim.orders
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 100, -100)
		at(sim, CT.MOVE, 1, { plant }, 0, 0) -- pre-move
		on(sim, CT.GUARD, 1, { plant }, tank, true) -- then guard the tank
		steps(sim, 1)
		t.equal(#o.rally[plant], 2, "two orders kept")
		t.equal(o.rally[plant][1].kind, "move")
		t.equal(o.rally[plant][2].kind, "guard")
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_herald.index, cell = 0, offX = 0, offZ = 0, facing = 0 })
		local made = 0
		steps(sim, 3000, function()
			powered(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" and e.other == plant then
					made = e.unit
				end
			end
			return made ~= 0
		end)
		t.expect(made ~= 0, "a unit was produced")
		local q = o.queue[made] :: any
		t.expect(q ~= nil and #q == 3, "out of the exit, then the two orders")
		t.equal(q[2].kind, "move")
		t.equal(q[3].kind, "guard")
		t.equal(q[3].target, tank, "guarding the tank")
		steps(sim, 900)
		t.expect(dist(w, made, w.posX[tank], w.posZ[tank]) < 120, "it went to the spot, then to the tank")
		-- a plain order replaces the list; STOP clears it
		at(sim, CT.FIGHT, 1, { plant }, 50, 50)
		steps(sim, 1)
		t.equal(#o.rally[plant], 1, "a plain order replaces")
		t.equal(o.rally[plant][1].kind, "fight")
		submit(sim, 1, { cmdType = CT.STOP, flags = 0, unitIds = { plant } })
		steps(sim, 1)
		t.equal(o.rally[plant], nil, "STOP clears it")
	end)

	t.test("a factory's guard order for a unit that died since is dropped, not crashed on (S-95)", function()
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "flat:64" })
		local o = sim.orders
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 100, -100)
		on(sim, CT.GUARD, 1, { plant }, tank)
		steps(sim, 1)
		Combat.queueDamage(sim.combat, tank, 1e6, 0) -- the guarded tank dies
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_herald.index, cell = 0, offX = 0, offZ = 0, facing = 0 })
		local made = 0
		steps(sim, 3000, function()
			powered(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" and e.other == plant then
					made = e.unit
				end
			end
			return made ~= 0
		end)
		t.expect(made ~= 0, "a unit was produced")
		steps(sim, 300)
		t.equal(o.queue[made], nil, "it rolled out, then dropped the guard order on a gone unit")
	end)

	t.test("REPEAT sets a factory's repeat (and its state bit); TOGGLE only switches on / off", function()
		local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150)
		local radar = Spawn.unit(sim, "ord_herald", 1, 0, 0)
		local REPEAT, ON = World.State.REPEAT, World.State.TOGGLED_ON
		submit(sim, 1, { cmdType = CT.TOGGLE, flags = 0, unitIds = { plant }, value = 1 })
		steps(sim, 1)
		t.expect(not sim.orders.repeatOn[plant], "TOGGLE no longer means repeat")
		t.equal(bit32.band(w.state[plant], REPEAT), 0)
		submit(sim, 1, { cmdType = CT.REPEAT, flags = 0, unitIds = { plant, radar }, value = 1 })
		steps(sim, 1)
		t.expect(sim.orders.repeatOn[plant], "REPEAT turns repeat on")
		t.equal(bit32.band(w.state[plant], REPEAT), REPEAT, "and the client sees it")
		t.expect(not sim.orders.repeatOn[radar], "non-factories ignore REPEAT")
		t.equal(bit32.band(w.state[radar], REPEAT), 0)
		submit(sim, 1, { cmdType = CT.TOGGLE, flags = 0, unitIds = { radar }, value = 0 })
		steps(sim, 1)
		t.equal(bit32.band(w.state[radar], ON), 0, "TOGGLE switches a unit off")
		submit(sim, 1, { cmdType = CT.REPEAT, flags = 0, unitIds = { plant }, value = 0 })
		steps(sim, 1)
		t.expect(not sim.orders.repeatOn[plant], "REPEAT 0 turns it off")
		t.equal(bit32.band(w.state[plant], REPEAT), 0)
	end)

	t.test("orders are deterministic", function()
		local function run(): number
			local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:64" })
			local a = Spawn.unit(sim, "ord_lancer", 1, -150, 0)
			local b = Spawn.unit(sim, "ord_lancer", 1, -150, 30)
			Spawn.unit(sim, "chs_ravager", 2, 100, 0)
			at(sim, CT.PATROL, 1, { a }, 150, 0)
			at(sim, CT.FIGHT, 1, { b }, 150, 50)
			at(sim, CT.MOVE, 1, { b }, -100, -100, true)
			steps(sim, 600)
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)

	t.test("an attack order's target stays the unit's pick whenever in range, through later orders, until STOP (S-115)", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local manual = Spawn.unit(sim, "chs_ravager", 2, 0, 160, math.pi)
		local other = Spawn.unit(sim, "chs_ravager", 2, 0, -160, 0)
		for _, id in { manual, other } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e6)
		end
		local key = World.slotKey(tank, 1)
		steps(sim, 4) -- sensors first: an attack order needs a target the team knows
		on(sim, CT.ATTACK, 1, { tank }, manual)
		steps(sim, 20)
		t.equal(w.wTarget[key], manual, "the attack order's target")
		-- a plain move south: the attack order ends, the manual target stays
		at(sim, CT.MOVE, 1, { tank }, 0, -120)
		steps(sim, 15 * 12)
		t.equal(sim.orders.manual[tank], manual, "kept after the order ended")
		t.equal(w.wTarget[key], other, "out of range: it picks its own target")
		-- back north: both in range, the manual target wins
		at(sim, CT.MOVE, 1, { tank }, 0, 0)
		steps(sim, 15 * 12)
		t.equal(w.wTarget[key], manual, "back in range: the manual target again")
		submit(sim, 1, { cmdType = CT.STOP, flags = 0, unitIds = { tank } })
		steps(sim, 15)
		t.equal(sim.orders.manual[tank], nil, "STOP drops it")
	end)
end
