--!strict
-- Line of fire (S-32, guide 10.8): direct fire doesn't go through hills.
-- "ridge:64": flat land at height 10, a north–south ridge 20 studs higher
-- at x -8..16, with a gap at z -224..-176.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 3 } }

local function ridge(): Sim.Sim
	return Sim.new({ seed = 3, players = PLAYERS, mapId = "ridge:64" })
end

-- A target that holds fire and can't die.
local function dummy(sim: Sim.Sim, defId: string, x: number, z: number): number
	local id = Spawn.unit(sim, defId, 2, x, z, -math.pi / 2)
	World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
	World.setHealth(sim.world, id, 1e9)
	return id
end

-- Shells and shots fired by `shooter` in `ticks` ticks.
local function shotsBy(sim: Sim.Sim, shooter: number, ticks: number): number
	local n = 0
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and e.unit == shooter then
				n += 1
			end
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("the shot geometry: straight shots and flat shells meet the ridge, an artillery arc clears it", function()
		local sim = ridge()
		local c, defs = sim.combat, sim.defs
		local gun, howitzer, mg = defs.weapons.ord_light_cannon, defs.weapons.ord_howitzer, defs.weapons.chs_mg
		t.expect(not Combat.lineOfFire(c, gun, -80, 14, 60, 90, 13, 60), "a tank shell 170 studs across the ridge hits it")
		t.expect(Combat.lineOfFire(c, gun, -200, 14, 60, -40, 13, 60), "on open ground it doesn't")
		t.expect(not Combat.lineOfFire(c, mg, -80, 14, 60, 90, 13, 60), "nor does a machine gun's straight line")
		t.expect(Combat.lineOfFire(c, howitzer, -230, 14, 60, 190, 13, 60), "a howitzer shell over 420 studs arcs over it")
		t.expect(Combat.lineOfFire(c, gun, -80, 14, -200, 90, 13, -200), "through the gap the tank shell flies")
		t.expect(Combat.lineOfFire(c, defs.weapons.chs_ir_sam, -80, 14, 60, 90, 13, 60), "homing missiles aren't checked")
	end)

	t.test("a tank holding position doesn't fire through the ridge; artillery fires over it", function()
		local sim = ridge()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -80, 60, math.pi / 2)
		World.setMoveState(sim.world, lancer, World.MoveState.HOLD_POSITION) -- on Maneuver it would go round (MoveStates.spec)
		Spawn.unit(sim, "ord_watchtower", 1, -40, 100, 0) -- sight over the ridge
		dummy(sim, "chs_ravager", 90, 60)
		local fired = shotsBy(sim, lancer, 150)
		t.equal(fired, 0, "the Lancer holds fire with the ridge in the way")
		t.equal(sim.world.wBlocked[World.slotKey(lancer, 1)], 1, "its weapon is marked blocked")

		local sim2 = ridge()
		local verdict = Spawn.unit(sim2, "ord_verdict", 1, -230, 60, math.pi / 2)
		Spawn.unit(sim2, "ord_watchtower", 1, -40, 100, 0)
		dummy(sim2, "chs_ravager", 190, 60)
		t.expect(shotsBy(sim2, verdict, 150) >= 2, "the Verdict lobs shells over it")
	end)

	t.test("a direct-fire weapon picks a target it can hit over a nearer one behind the ridge", function()
		local sim = ridge()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -30, -120, math.pi / 2)
		Spawn.unit(sim, "ord_watchtower", 1, -40, -60, 0)
		local behind = dummy(sim, "chs_ravager", 60, -120) -- 90 studs, across the ridge
		local clear = dummy(sim, "chs_ravager", -30, -260) -- 140 studs, same side (open line through the gap's latitude)
		local fired = shotsBy(sim, lancer, 120)
		local target = sim.world.wTarget[World.slotKey(lancer, 1)]
		t.equal(target, clear, `it targets the one it can hit (nearer one behind the ridge: {behind})`)
		t.expect(fired > 0, "and fires")
	end)

	t.test("an attack-move doesn't stop at a target behind the ridge: it goes through the gap and kills it", function()
		local sim = ridge()
		local w = sim.world
		local lancers = {}
		for i = 1, 3 do
			table.insert(lancers, Spawn.unit(sim, "ord_lancer", 1, -80, 40 + i * 12, math.pi / 2))
		end
		Spawn.unit(sim, "ord_watchtower", 1, -40, 100, 0)
		local target = Spawn.unit(sim, "chs_ravager", 2, 90, 60, -math.pi / 2)
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(150, 60)
		local wr = Packer.Writer.new()
		Schema.encodeCommand(wr, { cmdType = Schema.CmdType.FIGHT, flags = 0, unitIds = lancers, cell = cell, offX = ox, offZ = oz })
		assert(Sim.submit(sim, 1, wr:finish()))
		local heldAtRidge = 0
		for _ = 1, 15 * 60 do
			Sim.step(sim)
			if w.slot[target] == nil then
				break
			end
			if sim.orders.hold[lancers[1]] and w.posX[lancers[1]] < -8 then
				heldAtRidge += 1
			end
		end
		t.equal(w.slot[target], nil, "the target died")
		-- it stops while its turret turns to the target and the first shot
		-- finds the ridge in the way, then moves on
		t.expect(heldAtRidge <= 15, `the attack-move held west of the ridge for {heldAtRidge} ticks (at most 1 s)`)
	end)
end
