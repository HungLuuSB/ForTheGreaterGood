--!strict
-- Air transports (S-219, the user): LOAD and UNLOAD, who fits, cargo out of
-- the world while on board, and death on board.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Transport = require("../Sim/Transport")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local NetOut = require("../Sim/NetOut")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function load(sim: Sim.Sim, player: number, ids: { number }, target: number)
	submit(sim, player, { cmdType = CT.LOAD, flags = 0, unitIds = ids, targetId = target })
end

local function unload(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, player, { cmdType = CT.UNLOAD, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

-- Steps until `done()` or `seconds` pass; true if it came.
local function runUntil(sim: Sim.Sim, seconds: number, done: () -> boolean): boolean
	for _ = 1, seconds * 15 do
		Sim.step(sim)
		if done() then
			return true
		end
	end
	return false
end

return function(t: RunAll.T)
	t.test("a transport picks a unit up, carries it out of the world and sets it down at the point (S-219)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 20)
		local hp = w.health[tank] * 0.8
		World.setHealth(w, tank, hp)
		load(sim, 1, { courier }, tank)
		t.expect(runUntil(sim, 20, function()
			return World.isParked(w, tank)
		end), "picked up")
		t.equal(sim.transport.carrier[tank], courier)
		t.expect(table.find(w.ids, tank) == nil, "out of the unit list")
		t.equal(Sensors.level(sim, 2, tank), Sensors.Level.HIDDEN, "nobody else sees it")
		t.expect((sim.transport.slow[courier] or 1) < 1, "a loaded transport is slower")
		Sim.step(sim)
		t.equal(w.posX[tank], w.posX[courier], "it rides along")

		unload(sim, 1, { courier }, 200, -100)
		t.expect(runUntil(sim, 30, function()
			return not World.isParked(w, tank)
		end), "set down")
		t.expect(table.find(w.ids, tank) ~= nil, "back in the world")
		t.expect((w.posX[tank] - 200) ^ 2 + (w.posZ[tank] + 100) ^ 2 < 30 ^ 2, `near the point ({w.posX[tank]}, {w.posZ[tank]})`)
		t.equal(w.health[tank], hp, "with the health it had")
		t.equal(sim.transport.cargo[courier], nil)
		t.equal(sim.transport.slow[courier], nil)
		-- it can move again
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(100, -100)
		submit(sim, 1, { cmdType = CT.MOVE, flags = 0, unitIds = { tank }, cell = cell, offX = ox, offZ = oz })
		local x0 = w.posX[tank]
		for _ = 1, 15 * 3 do
			Sim.step(sim)
		end
		t.expect(w.posX[tank] < x0 - 5, "and it drives off")
	end)

	t.test("who fits: a light transport takes one light unit or a Commander; a heavy one tanks by slots, never T3 (S-219)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
		local ark = Spawn.unit(sim, "ord_ark", 1, 0, 40)
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local com = Spawn.unit(sim, "ord_sovereign", 1, 80, 0)
		local paladin = Spawn.unit(sim, "ord_paladin", 1, 120, 0) -- T2, footprint 2
		local titan = Spawn.unit(sim, "ord_titan", 1, 200, 0) -- T3
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 40, 80)
		local solar = Spawn.unit(sim, "ord_solar", 1, -80, -80)
		t.expect(Transport.canCarry(sim, courier, lancer), "light: a T1 tank")
		t.expect(Transport.canCarry(sim, courier, com), "light: a Commander")
		t.expect(not Transport.canCarry(sim, courier, paladin), "light: not a T2 tank")
		t.expect(Transport.canCarry(sim, ark, paladin), "heavy: a T2 tank")
		t.expect(not Transport.canCarry(sim, ark, titan), "heavy: never T3")
		t.expect(not Transport.canCarry(sim, ark, enemy), "never an enemy")
		t.expect(not Transport.canCarry(sim, ark, solar), "never a structure")
		t.expect(not Transport.canCarry(sim, ark, courier), "never an aircraft")
		Transport.pickUp(sim, courier, lancer)
		t.expect(not Transport.canCarry(sim, courier, com), "the light one is full with one")
		Transport.pickUp(sim, ark, paladin)
		t.expect(not Transport.canCarry(sim, ark, com), "the heavy one is full with one too (S-220)")
	end)

	t.test("units told to LOAD a transport board it, one at a time; a carried unit takes no orders (S-219, S-220)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local ark = Spawn.unit(sim, "ord_ark", 1, 0, 0)
		local a = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local b = Spawn.unit(sim, "ord_lancer", 1, -40, 0)
		load(sim, 1, { a, b }, ark)
		t.expect(runUntil(sim, 30, function()
			return World.isParked(w, a) or World.isParked(w, b)
		end), "one boarded")
		for _ = 1, 15 * 5 do
			Sim.step(sim)
		end
		t.equal(#(sim.transport.cargo[ark] :: { number }), 1, "one unit only (S-220)")
		if not World.isParked(w, a) then
			a, b = b, a
		end
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(200, 200)
		submit(sim, 1, { cmdType = CT.MOVE, flags = 0, unitIds = { a }, cell = cell, offX = ox, offZ = oz })
		Sim.step(sim)
		t.equal(sim.orders.queue[a], nil, "a carried unit takes no orders")
	end)

	t.test("a loaded transport's death kills its cargo, with no wrecks (S-219)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local ark = Spawn.unit(sim, "ord_ark", 1, 0, 0)
		local a = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local b = Spawn.unit(sim, "ord_paladin", 1, -40, 0)
		Transport.pickUp(sim, ark, a)
		Transport.pickUp(sim, ark, b)
		local wrecks = #sim.combat.wreckIds
		Combat.queueDamage(sim.combat, ark, w.health[ark] * 10, 0, 0)
		local deaths: { [number]: boolean } = {}
		for _ = 1, 5 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "DEATH" then
					deaths[e.unit] = true
				end
			end
		end
		t.expect(deaths[ark] and deaths[a] and deaths[b], "all three died")
		t.equal(w.slot[a], nil)
		t.equal(w.slot[b], nil)
		t.expect(#sim.combat.wreckIds <= wrecks + 1, "the cargo leaves no wrecks (the transport may)")
		t.equal(next(sim.transport.carrier), nil, "nothing left on board")
	end)

	t.test("a transport run is deterministic and hashed (S-219)", function()
		local function run(): (number, number)
			local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
			local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
			local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 20)
			load(sim, 1, { courier }, tank)
			for _ = 1, 15 * 6 do
				Sim.step(sim)
			end
			local loaded = Sim.hash(sim)
			unload(sim, 1, { courier }, -150, 100)
			for _ = 1, 15 * 20 do
				Sim.step(sim)
			end
			return loaded, Sim.hash(sim)
		end
		local a1, a2 = run()
		local b1, b2 = run()
		-- (S-219 follow-up, client-B: the hash threw on a load / unload order
		-- under way; every tick of a load and an unload hashes)
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 20)
		load(sim, 1, { courier }, tank)
		for _ = 1, 15 * 6 do
			Sim.step(sim)
			Sim.hash(sim)
		end
		unload(sim, 1, { courier }, -150, 100)
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			Sim.hash(sim)
		end
		t.equal(a1, b1, "same hash while loaded")
		t.equal(a2, b2, "same hash after")
	end)

	t.test("on the wire: the carried unit leaves its owner's view, the transport lists it as cargo, and it enters again on unload (S-219)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local w = sim.world
		NetOut.setCamera(sim, 1, 0, 0, math.min(g.cellsX - 1, 255), math.min(g.cellsZ - 1, 255))
		local view = Client.new(g)
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
			end
		end
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 20)
		step(2)
		t.equal(view.units[tank] and view.units[tank].tier, "tactical", "the tank on camera")
		load(sim, 1, { courier }, tank)
		local loaded = false
		for _ = 1, 15 * 20 do
			step(1)
			if World.isParked(w, tank) then
				loaded = true
				break
			end
		end
		t.expect(loaded, "picked up")
		step(NetOut.SIGHT_EVERY + 2)
		local u = view.units[tank]
		t.expect(u == nil or u.tier ~= "tactical", "the carried tank left the owner's view")
		local cu = view.units[courier] :: any
		t.expect(cu and cu.cargo and cu.cargo[1] == tank, "the transport lists it on board")
		unload(sim, 1, { courier }, -100, -100)
		for _ = 1, 15 * 30 do
			step(1)
			if not World.isParked(w, tank) then
				break
			end
		end
		step(2)
		t.equal(view.units[tank] and view.units[tank].tier, "tactical", "back on unload")
		t.equal(#((view.units[courier] :: any).cargo :: { number }), 0, "nothing on board")
	end)

	t.test("every player who sees the transport hears of the pick-up and set-down as they start, and what it carries (S-220)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local all = { math.min(g.cellsX - 1, 255), math.min(g.cellsZ - 1, 255) }
		NetOut.setCamera(sim, 2, 0, 0, all[1], all[2])
		local enemyView = Client.new(g)
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 20)
		Spawn.unit(sim, "chs_ravager", 2, 30, 30) -- so player 2 sees the transport
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				Client.receive(enemyView, sim.net.players[2].outbox)
			end
		end
		step(2)
		load(sim, 1, { courier }, tank)
		step(15 * 10)
		t.expect(World.isParked(w, tank), "picked up")
		local first = enemyView.transportActions[1]
		t.expect(first ~= nil and first.action == Schema.TransportAction.PICKUP and first.transport == courier and first.unit == tank, "the enemy heard the PICKUP")
		t.equal(first and first.defIndex, sim.defs.units.ord_lancer.index, "with the unit's def")
		local carry = enemyView.carry[courier]
		t.equal(carry and carry.defIndex, sim.defs.units.ord_lancer.index, "and sees what hangs under it")
		unload(sim, 1, { courier }, 120, 60)
		local dropAt = nil
		for _ = 1, 15 * 20 do
			step(1)
			local last = enemyView.transportActions[#enemyView.transportActions]
			if dropAt == nil and last.action == Schema.TransportAction.DROP then
				dropAt = { last.x :: number, last.z :: number }
			end
			if not World.isParked(w, tank) then
				break
			end
		end
		t.expect(dropAt ~= nil, "a DROP before the unit comes down")
		if dropAt then
			t.expect(math.abs(w.posX[tank] - dropAt[1]) < 1 and math.abs(w.posZ[tank] - dropAt[2]) < 1, "set down where the DROP said")
		end
		step(2)
		t.equal(enemyView.carry[courier], nil, "empty again")
	end)

	t.test("both transport tiers carry one unit (S-220, the user)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local ark = Spawn.unit(sim, "ord_ark", 1, 0, 0)
		local a = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local b = Spawn.unit(sim, "ord_lancer", 1, -40, 0)
		Transport.pickUp(sim, ark, a)
		t.expect(not Transport.canCarry(sim, ark, b), "the Ark is full with one")
	end)
end
