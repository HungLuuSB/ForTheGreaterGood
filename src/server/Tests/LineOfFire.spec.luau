--!strict
-- Line of fire (S-32, guide 10.8): direct fire doesn't go through hills.
-- "ridge:64": flat land at height 10, a north–south ridge 20 studs higher
-- at x -8..16, with a gap at z -224..-176.
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
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
		local hd = howitzer.range * 0.9 -- (S-179: range halved, shell slowed so it still arcs)
		t.expect(Combat.lineOfFire(c, howitzer, 4 - hd / 2, 14, 60, 4 + hd / 2, 13, 60), `a howitzer shell over {hd} studs arcs over it`)
		local md = defs.weapons.chs_mortar.range * 0.9
		t.expect(Combat.lineOfFire(c, defs.weapons.chs_mortar, 4 - md / 2, 14, 60, 4 + md / 2, 13, 60), `so does a Hellmouth mortar over {md}`)
		local mortar = defs.weapons.ord_gauntlet_shell
		local d = mortar.range * 0.9
		t.expect(Combat.lineOfFire(c, mortar, 4 - d / 2, 14, 60, 4 + d / 2, 13, 60), "a high-arc Gauntlet shell inside its range clears it")
		t.expect(Combat.lineOfFire(c, gun, -80, 14, -200, 90, 13, -200), "through the gap the tank shell flies")
		-- homing missiles fly about straight (S-182, F29): from the muzzle, or a
		-- vertical launcher's climb
		t.expect(not Combat.lineOfFire(c, defs.weapons.chs_ir_sam, -80, 14, 60, 90, 13, 60), "a SAM across the ridge would hit it")
		t.expect(Combat.lineOfFire(c, defs.weapons.chs_ir_sam, -80, 14, 60, 90, 80, 60), "an aircraft high above it is clear")
		local sanction = defs.weapons.ord_sanction_missile
		t.expect(Combat.lineOfFire(c, sanction, -300, 14, 60, 300, 13, 60), "a Sanction's missile, launched up 60 studs, dives over it from afar")
		t.expect(not Combat.lineOfFire(c, sanction, -300, 14, 60, 30, 11, 60), "but not onto a tank tucked right behind it")
	end)

	t.test("radar needs line of sight: a ridge hides a tank from a radar beside it (S-182, F28)", function()
		local sim = ridge()
		local radar = Spawn.unit(sim, "ord_watchtower", 1, -200, -200)
		local behind = dummy(sim, "chs_ravager", 40, 0) -- across the ridge
		local open = dummy(sim, "chs_ravager", 60, -200) -- straight through the gap
		local sensors = sim.defs.units.ord_watchtower.sensors :: any
		for _, id in { behind, open } do
			local d = math.sqrt((sim.world.posX[id] + 200) ^ 2 + (sim.world.posZ[id] + 200) ^ 2)
			t.expect(d < sensors.radar and d > sensors.sight, `inside radar, outside sight ({d})`)
		end
		for _ = 1, 6 do
			sim.eco.accounts[1].power.stored = 1000
			Sim.step(sim)
		end
		local _ = radar
		t.equal(Sensors.level(sim, 1, behind), Sensors.Level.HIDDEN, "behind the ridge: not on radar")
		t.equal(Sensors.level(sim, 1, open), Sensors.Level.RADAR, "through the gap: a radar contact")
	end)

	t.test("a tank holding position doesn't fire through the ridge; artillery fires over it", function()
		local sim = ridge()
		-- 0.9 × the cannon's range apart, across the ridge (x -8..16)
		local lancerX = -48
		local lancer = Spawn.unit(sim, "ord_lancer", 1, lancerX, 60, math.pi / 2)
		World.setMoveState(sim.world, lancer, World.MoveState.HOLD_POSITION) -- on Maneuver it would go round (MoveStates.spec)
		Spawn.unit(sim, "ord_watchtower", 1, -40, 100, 0) -- sight over the ridge
		dummy(sim, "chs_ravager", lancerX + sim.defs.weapons.ord_lancer_cannon.range * 0.9, 60)
		local fired = shotsBy(sim, lancer, 150)
		t.equal(fired, 0, "the Lancer holds fire with the ridge in the way")
		t.equal(sim.world.wBlocked[World.slotKey(lancer, 1)], 1, "its weapon is marked blocked")

		local sim2 = ridge()
		-- S-179 halved the Verdict's range: within it, its low arc no longer
		-- clears the 20-stud ridge, so the high-arc Gauntlet stands in
		local gunX = -180
		local targetX = gunX + sim2.defs.weapons.ord_gauntlet_shell.range * 0.9 -- across the ridge
		local gauntlet = Spawn.unit(sim2, "ord_gauntlet", 1, gunX, 60, math.pi / 2)
		Spawn.unit(sim2, "ord_watchtower", 1, targetX - 60, 100, 0) -- sight on the target (the Gauntlet can't shell radar contacts)
		dummy(sim2, "chs_ravager", targetX, 60)
		t.expect(shotsBy(sim2, gauntlet, 150) >= 2, "the Gauntlet lobs shells over it")
	end)

	t.test("a direct-fire weapon picks a target it can hit over a nearer one behind the ridge", function()
		local sim = ridge()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -30, -120, math.pi / 2)
		Spawn.unit(sim, "ord_watchtower", 1, -40, -60, 0)
		local range = sim.defs.weapons.ord_lancer_cannon.range
		local behind = dummy(sim, "chs_ravager", -30 + range * 0.6, -120) -- across the ridge
		local clear = dummy(sim, "chs_ravager", -30, -120 - range * 0.85) -- farther but in range, same side (open line through the gap's latitude)
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
