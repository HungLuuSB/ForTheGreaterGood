--!strict
-- Faction-only units, stage 3 (S-75): Locust, Cyclops, Barrier, Citadel.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function shotsBy(sim: Sim.Sim, shooter: number, ticks: number, onImpact: ((number, number, number) -> ())?): number
	local n = 0
	local mine: { [number]: boolean } = {}
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and e.unit == shooter then
				n += 1
				mine[e.other] = true
			elseif e.kind == "IMPACT" and mine[e.other] and onImpact then
				onImpact(e.unit, e.x or 0, e.z or 0)
			end
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("the Locust is the cheapest, fastest tank, with a short gun", function()
		local defs = (Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })).defs
		local l, r = defs.units.chs_locust, defs.units.chs_ravager
		t.expect(l.cost.supply + l.cost.power / 10 < (r.cost.supply + r.cost.power / 10) * 0.6, "well under the Ravager's value")
		t.expect((l.movement :: any).maxSpeed > (r.movement :: any).maxSpeed, "faster")
		t.expect(l.maxRange < r.maxRange, "shorter reach")
	end)

	t.test("the Cyclops shells a structure from beyond its guns, and never fires at units", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local cyclops = Spawn.unit(sim, "chs_cyclops", 2, 300, 0, -math.pi / 2)
		local turret = Spawn.unit(sim, "ord_vehplant", 1, -200, 0) -- 500 studs off
		local spotter = Spawn.unit(sim, "chs_jackal", 2, -40, 0) -- the Cyclops's eyes
		local tank = Spawn.unit(sim, "ord_lancer", 1, 200, 60) -- in its range, a unit
		for _, id in { spotter, tank } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setHealth(w, id, 1e6)
		end
		local full = w.health[turret]
		local onTank = 0
		local fired = shotsBy(sim, cyclops, 600, function(unit)
			if unit == tank then
				onTank += 1
			end
		end)
		t.expect(fired >= 3, `it fired ({fired} shells in 40 s)`)
		t.expect(not World.isAlive(w, turret) or w.health[turret] <= full - 1200, `the plant took its 1,200-damage shells ({full - (w.health[turret] or 0)})`)
		t.equal(w.wTarget[World.slotKey(cyclops, 1)] == tank, false, "it never took the tank as a target")
		t.equal(onTank, 0, "no shell landed on the tank")
	end)

	t.test("a Barrier wall blocks movement and catches shells fired through it", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local walls = {}
		for i = -6, 6 do
			table.insert(walls, Spawn.unit(sim, "ord_barrier", 1, 0, i * 8))
		end
		local tank = Spawn.unit(sim, "chs_ravager", 2, 60, 0, -math.pi / 2)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		moveTo(sim, 2, { tank }, -60, 0)
		local crossedThrough = false
		for _ = 1, 600 do
			Sim.step(sim)
			if math.abs(w.posX[tank]) < 4 and math.abs(w.posZ[tank]) < 48 then
				crossedThrough = true
			end
		end
		t.expect(not crossedThrough, "the tank never drove through the wall")
		t.expect(w.posX[tank] < -20, `it went round it to the far side (x {w.posX[tank]})`)

		-- a gun firing at a target hidden behind the wall hits the wall
		local sim2 = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:128" })
		local w2 = sim2.world
		local wall = Spawn.unit(sim2, "ord_barrier", 1, 0, 0)
		local wallL = Spawn.unit(sim2, "ord_barrier", 1, 0, -8)
		local wallR = Spawn.unit(sim2, "ord_barrier", 1, 0, 8)
		local behind = Spawn.unit(sim2, "ord_lancer", 1, -20, 0)
		World.setFireState(w2, behind, World.FireState.HOLD_FIRE)
		-- the Lancer in the Ravager's range (78 since S-179) from the start, and
		-- the Ravager holds its spot: a Maneuver approach would pick a wall
		-- segment as its target first and keep it
		local gunX = sim2.defs.weapons[sim2.defs.units.chs_ravager.weapons[1].def].range - 25
		local gun = Spawn.unit(sim2, "chs_ravager", 2, gunX, 0, -math.pi / 2)
		World.setMoveState(w2, gun, World.MoveState.HOLD_POSITION)
		local onWall, onTank = 0, 0
		local fired = shotsBy(sim2, gun, 300, function(unit)
			if unit == wall or unit == wallL or unit == wallR then
				onWall += 1
			elseif unit == behind then
				onTank += 1
			end
		end)
		t.expect(fired >= 3, `the Ravager fired ({fired})`)
		t.expect(onTank <= fired / 6, `{onTank} of {fired} shells cleared the wall (as tall as the tank) and hit it`)
		t.expect(onWall >= fired * 0.75, `{onWall} of {fired} shells hit the wall (the rest landed short or long)`)
		t.expect(w2.health[wall] < sim2.defs.units.ord_barrier.health, "the wall soaked them")
	end)

	t.test("the Citadel guns down tanks at 270 studs and fires its SAMs at aircraft", function()
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local citadel = Spawn.unit(sim, "ord_citadel", 1, -150, 0)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 120, 0) -- 270 studs: in sight and range
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local heli = Spawn.unit(sim, "chs_wasp", 2, -150, 150)
		World.setFireState(w, heli, World.FireState.HOLD_FIRE)
		World.setHealth(w, heli, 1e6)
		local gunShots, samShots = 0, 0
		for _ = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == citadel then
					if e.slot == 1 then
						gunShots += 1
					else
						samShots += 1
					end
				end
			end
		end
		t.expect(not World.isAlive(w, tank), `the Ravager 270 studs off is gone ({gunShots} shells)`)
		t.expect(samShots >= 2, `its IR SAM fired at the helicopter ({samShots})`)
	end)
end
