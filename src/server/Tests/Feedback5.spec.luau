--!strict
-- FTGG-FEEDBACK-5 (the user, S-236): the Overwatch's and the Steadfast's
-- reach back to 10% under what it was, workers guarding a factory help with
-- each unit it makes, unfinished structures leave without a blast, the
-- Juggernaut goes up like a nuke, and the Colossus is a barely mobile
-- turret that takes on a whole army.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Build = require("../Sim/Build")
local Combat = require("../Sim/Combat/Combat")
local Orders = require("../Sim/Orders")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, cmd)
	assert(Sim.submit(sim, player, wr:finish()))
end

local function queueUnit(sim: Sim.Sim, factory: number, defId: string)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(0, 0)
	submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { factory }, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
end

local function fund(sim: Sim.Sim)
	for _, acc in sim.eco.accounts do
		acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
	end
end

local function hold(sim: Sim.Sim, id: number): number
	World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
	World.setMoveState(sim.world, id, World.MoveState.HOLD_POSITION)
	return id
end

local function kill(sim: Sim.Sim, id: number)
	World.setHealth(sim.world, id, 1)
	Combat.queueDamage(sim.combat, id, 10, 0, 2)
end

local function count(sim: Sim.Sim, kind: string, unit: number?): number
	local n = 0
	for _, e in sim.combat.events do
		if e.kind == kind and (unit == nil or e.unit == unit) then
			n += 1
		end
	end
	return n
end

-- A Colossus against `n` of `enemy`, sent at it as an attack-move from 450
-- studs off. Returns whether it won, its health left, and the minutes.
local function colossusAgainst(enemy: string, n: number): (boolean, number, number)
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:160" })
	local w = sim.world
	local colossus = Spawn.unit(sim, "chs_colossus", 2, 0, 0, 0)
	local army = {}
	for i = 1, n do
		local col, row = (i - 1) % 5, (i - 1) // 5
		table.insert(army, Spawn.unit(sim, enemy, 1, (col - 2) * 40, 450 + row * 40, math.pi))
	end
	Orders.give(sim, army, { kind = "fight", x = 0, z = 0 }, false)
	local limit = 15 * 60 * 10
	for tick = 1, limit do
		Sim.step(sim)
		if w.slot[colossus] == nil then
			return false, 0, tick / 900
		end
		local alive = 0
		for _, u in army do
			if w.slot[u] ~= nil then
				alive += 1
			end
		end
		if alive == 0 then
			return true, w.health[colossus], tick / 900
		end
	end
	return false, w.health[colossus], limit / 900
end

return function(t: RunAll.Context)
	t.test("Overwatch and Steadfast: the two 25% cuts reverted, 10% under what they were", function()
		local u = Sim.new({ seed = 1, players = PLAYERS }).defs.units
		t.equal(u.ord_overwatch.sensors.sight, 199, "Overwatch sight: 221 less 10%")
		t.equal(u.ord_overwatch.maxRange, 216, "Overwatch laser: 240 less 10%")
		t.equal(u.ord_warden.sensors.sight, 252, "Steadfast sight: 280 less 10%")
		t.equal(u.ord_warden.maxRange, 252, "Steadfast gun: 280 less 10%")
	end)

	t.test("a worker guarding a factory goes to it, helps build each unit it makes, and waits for the next", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local b = sim.build
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
		local mason = Spawn.unit(sim, "ord_mason", 1, -200, 0)
		submit(sim, 1, { cmdType = CT.GUARD, flags = 0, unitIds = { mason }, targetId = plant })
		local x0 = w.posX[mason]
		for _ = 1, 15 * 4 do
			fund(sim)
			Sim.step(sim)
		end
		t.expect(w.posX[mason] > x0 + 20, "it walks to the factory")
		t.equal(b.target[mason] or 0, 0, "nothing to help with yet")

		local function produce(): (number, boolean)
			queueUnit(sim, plant, "ord_lancer")
			local helped = false
			for tick = 1, 15 * 120 do
				fund(sim)
				Sim.step(sim)
				if b.target[mason] == plant and b.assist[mason] == true and Build.inReach(sim, mason) then
					helped = true
				end
				if count(sim, "PRODUCED") > 0 then
					return tick, helped
				end
			end
			return 0, helped
		end
		local first, helped1 = produce()
		t.expect(first > 0 and helped1, `it helped build the first unit (produced at {first})`)
		for _ = 1, 15 * 5 do
			fund(sim)
			Sim.step(sim)
		end
		t.equal(b.target[mason] or 0, 0, "the queue is empty: it waits")
		local dx, dz = w.posX[mason] - w.posX[plant], w.posZ[mason] - w.posZ[plant]
		t.expect(dx * dx + dz * dz <= Orders.GUARD_RADIUS ^ 2, "beside the factory")
		local second, helped2 = produce()
		t.expect(second > 0 and helped2, "and helps with the next one")
		local q = sim.orders.queue[mason]
		t.equal(q and q[1] and q[1].kind, "guard", "still guarding")
	end)

	t.test("a structure killed while it is being built is just gone: no blast, no wreck", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local frame = Spawn.unit(sim, "ord_fusion", 1, 0, 0)
		w.buildProgress[frame] = 0.6
		local wrecks = #sim.combat.wreckIds
		kill(sim, frame)
		Sim.step(sim)
		t.equal(w.slot[frame], nil, "gone")
		t.equal(count(sim, "BLAST", frame), 0, "no blast")
		t.equal(#sim.combat.wreckIds, wrecks, "no wreck")
	end)

	t.test("the Juggernaut goes up like a nuke, killed or self-destructed", function()
		local nuke = Sim.new({ seed = 1, players = PLAYERS }).defs.weapons.chs_nuke
		for _, selfDestruct in { false, true } do
			local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:96" })
			local w = sim.world
			local d = sim.defs.units.chs_juggernaut
			local blast = if selfDestruct then d.selfDestructBlast else d.deathBlast
			t.equal(blast.aoe, nuke.aoe, "a nuke's radius")
			t.equal(blast.damage, nuke.damage.ARMORED, "a nuke's damage")
			local jug = hold(sim, Spawn.unit(sim, "chs_juggernaut", 2, 0, 0))
			local com = hold(sim, Spawn.unit(sim, "ord_sovereign", 1, 40, 0))
			local far = hold(sim, Spawn.unit(sim, "ord_paladin", 1, 130, 0))
			local out = hold(sim, Spawn.unit(sim, "ord_paladin", 1, 175, 0))
			local farHp, outHp = w.health[far], w.health[out]
			if selfDestruct then
				submit(sim, 2, { cmdType = CT.SELF_DESTRUCT, flags = 0, unitIds = { jug }, value = 1 })
				for _ = 1, 15 * 12 do
					Sim.step(sim)
				end
			else
				kill(sim, jug)
				for _ = 1, 3 do
					Sim.step(sim)
				end
			end
			t.equal(w.slot[jug], nil, "it went up")
			t.equal(w.slot[com], nil, "a Commander 40 studs off dies")
			t.expect(w.slot[far] == nil or w.health[far] < farHp, "a tank 130 studs off is hurt")
			t.equal(w.health[out], outHp, "one past the radius is not")
		end
	end)

	t.test("the Colossus: bigger, 3× the health, half the speed, a D-Gun bolt every 2 s", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		local d = defs.units.chs_colossus
		t.equal(d.health, 240000, "3× 80000")
		t.equal(d.movement.maxSpeed, 1.5, "half of 3")
		t.equal(d.footprint, 5, "bigger (was 4)")
		local gun = defs.weapons.chs_colossus_fire
		t.expect(gun.bolt ~= nil and not gun.manualFire, "a bolt it fires by itself")
		t.equal(gun.reload, 2, "every 2 s")
		t.equal(gun.damage.ARMORED, 9000, "9000 a unit")
	end)

	t.test("the Colossus's bolt deals 9000 to every enemy on its line, and spares its own side", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local colossus = Spawn.unit(sim, "chs_colossus", 2, 0, 0, 0)
		World.setMoveState(w, colossus, World.MoveState.HOLD_POSITION)
		local line = {}
		for i, z in { 120, 170, 220 } do
			local id = hold(sim, Spawn.unit(sim, "ord_titan", 1, 0, z, math.pi))
			World.setHealth(w, id, 1e6)
			line[i] = id
		end
		local friend = hold(sim, Spawn.unit(sim, "chs_goliath", 2, 0, 70, 0))
		World.setHealth(w, friend, 1e6)
		for _ = 1, 15 * 6 do
			Sim.step(sim)
			if w.health[line[3]] < 1e6 then
				break
			end
		end
		for i, id in line do
			t.expect(w.health[id] <= 1e6 - 9000 + 1e-6, `enemy {i} on the line took 9000 ({1e6 - w.health[id]})`)
		end
		t.equal(w.health[friend], 1e6, "the friend in front is spared")
		t.equal(sim.orders.dgunX[colossus], nil, "no D-Gun order needed")
	end)

	t.slow("a Colossus alone beats 15 Titans and 8 Juggernauts (the user)", function()
		for _, case in { { "ord_titan", 15 }, { "chs_juggernaut", 8 } } do
			local won, hp, minutes = colossusAgainst(case[1], case[2])
			print(`  Colossus vs {case[2]} {case[1]}: won {won}, health left {math.floor(hp)}, {string.format("%.1f", minutes)} min`)
			t.expect(won, `it beats {case[2]} {case[1]}`)
		end
	end)
end
