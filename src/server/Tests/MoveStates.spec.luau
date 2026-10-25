--!strict
-- Move states (guide 10.1, S-34): what idle units do on their own.
local Defs = require("@shared/Defs/Defs")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 3 } }
local MS = World.MoveState

-- A Lancer at (-200, 0), a Ravager that holds fire `gap` studs
-- east of it, and a scout of the Lancer's side next to the Ravager (so the
-- team sees it: Maneuver chases only what the team sees), on `mapId`.
local function scene(mapId: string, state: number, gap: number, ravagerHealth: number?): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = mapId })
	local w = sim.world
	local lancer = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
	World.setMoveState(w, lancer, state)
	local scout = Spawn.unit(sim, "ord_herald", 1, -200 + gap - 60, 90, 0)
	World.setFireState(w, scout, World.FireState.HOLD_FIRE)
	World.setMoveState(w, scout, MS.HOLD_POSITION)
	local enemy = Spawn.unit(sim, "chs_ravager", 2, -200 + gap, 0, -math.pi / 2)
	World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
	World.setMoveState(w, enemy, MS.HOLD_POSITION)
	if ravagerHealth then
		World.setHealth(w, enemy, ravagerHealth)
	end
	return sim, lancer, enemy
end

-- The Lancer's weapon range (S-179 halved it): "just out of range" is
-- range + 110, inside the Maneuver leash (Orders.MANEUVER_LEASH = 150).
local function lancerRange(): number
	local d = Defs.load()
	return d.weapons[d.units.ord_lancer.weapons[1].def].range
end
local NEAR_GAP = lancerRange() + 110

local function run(sim: Sim.Sim, ticks: number, each: (() -> boolean)?)
	for _ = 1, ticks do
		Sim.step(sim)
		if each and each() then
			return
		end
	end
end

return function(t: RunAll.Context)
	t.test("Hold Position never moves on its own", function()
		local sim, lancer = scene("flat:96", MS.HOLD_POSITION, 300)
		run(sim, 300)
		local w = sim.world
		t.expect(math.abs(w.posX[lancer] + 200) < 1 and math.abs(w.posZ[lancer]) < 1, "it stayed on its spot")
	end)

	t.test("Maneuver closes in on an enemy just out of range, fights, and walks back", function()
		local sim, lancer, enemy = scene("flat:96", MS.MANEUVER, NEAR_GAP, 1600) -- as many shots as before S-179 (damage × 0.8)
		local w = sim.world
		local farthest = 0
		run(sim, 15 * 40, function()
			farthest = math.max(farthest, w.posX[lancer] + 200)
			return w.slot[enemy] == nil and w.orderId[lancer] == 0 and math.abs(w.posX[lancer] + 200) < 30
		end)
		t.expect(farthest > 80 and farthest <= 150 + 24, `it went {farthest} studs toward the enemy (leash 150)`)
		t.equal(w.slot[enemy], nil, "and killed it")
		t.expect(math.abs(w.posX[lancer] + 200) < 30, `then walked back to its spot ({w.posX[lancer] + 200} studs off)`)
	end)

	t.test("Maneuver doesn't chase beyond its leash; Roam does, and stays", function()
		-- 520 > range + leash (150), and < range + Orders.ROAM_CHASE (500)
		t.expect(520 > lancerRange() + 150 and 520 < lancerRange() + 500, "the gap is past the leash, within Roam's chase")
		local sim, lancer = scene("flat:128", MS.MANEUVER, 520)
		run(sim, 300)
		t.expect(math.abs(sim.world.posX[lancer] + 200) < 1, "Maneuver: too far, stays")

		local sim2, roamer, enemy = scene("flat:128", MS.ROAM, 520, 2000)
		local w = sim2.world
		run(sim2, 15 * 60, function()
			return w.slot[enemy] == nil
		end)
		t.equal(w.slot[enemy], nil, "Roam chased and killed it")
		run(sim2, 300)
		t.expect(w.posX[roamer] + 200 > 250, `and stayed out there ({w.posX[roamer] + 200} studs from its start)`)
	end)

	t.test("Maneuver repositions to get a shot past a ridge (line of fire)", function()
		-- "ridge:64": a 20-stud ridge at x -8..16 with a gap at z -224..-176
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "ridge:64" })
		local w = sim.world
		-- just south of the gap: a short move north opens the line
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -70, -130, math.pi / 2)
		local scout = Spawn.unit(sim, "ord_herald", 1, 50, -100, 0) -- east of the ridge
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		World.setMoveState(w, scout, MS.HOLD_POSITION)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 80, -150, -math.pi / 2)
		World.setFireState(w, enemy, World.FireState.HOLD_FIRE)
		World.setMoveState(w, enemy, MS.HOLD_POSITION)
		World.setHealth(w, enemy, 600)
		local fired = 0
		run(sim, 15 * 60, function()
			for _, e in sim.combat.events do
				if e.unit == lancer and (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") then
					fired += 1
				end
			end
			return w.slot[enemy] == nil
		end)
		t.expect(fired > 0, "it found a firing position")
		t.equal(w.slot[enemy], nil, "and killed the enemy behind the ridge")
	end)

	t.test("a command replaces the automatic chase and re-anchors the unit", function()
		local sim, lancer = scene("flat:96", MS.MANEUVER, NEAR_GAP, 1e9)
		local w = sim.world
		run(sim, 60)
		t.expect(w.posX[lancer] + 200 > 10, "it set off on its own")
		local Orders = require("../Sim/Orders")
		Orders.give(sim, { lancer }, { kind = "move", x = -300, z = 100 }, false)
		run(sim, 15 * 20)
		t.expect(math.abs(w.posX[lancer] + 300) < 20 and math.abs(w.posZ[lancer] - 100) < 20, "it went where it was told")
		run(sim, 15 * 10)
		t.expect(math.abs(w.posX[lancer] + 300) < 30, "and stays there: its new anchor, the enemy beyond its leash")
	end)
end
