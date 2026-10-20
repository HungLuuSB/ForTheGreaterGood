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
		steps(sim, 600, function()
			return w.health[tank] >= 1100
		end)
		t.equal(w.health[tank], 1100, "repaired to full")
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
		submit(sim, 1, { cmdType = CT.TOGGLE, flags = 0, unitIds = { plant }, value = 1 }) -- repeat
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
end
