--!strict
-- Units take radar blips (S-202, the user): every weapon fires at radar
-- contacts it can reach, and a structure seen once (a ghost) that the
-- team's radar covers now is a blip too. A ghost out of radar is still shot
-- only on an attack order (S-127).
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- shots `id` fires over `ticks` (power kept full for the radar's upkeep)
local function shots(sim: Sim.Sim, id: number, ticks: number): number
	local n = 0
	for _ = 1, ticks do
		local acc = sim.eco.accounts[2]
		acc.power.stored = acc.power.storage
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit == id then
				n += 1
			end
		end
	end
	return n
end

-- A Talos (range 360, sight 220) of player 2 at the origin; `radar`: a Chaos
-- Eye 200 studs off the target point, out of sight of it (160) but its radar
-- (280) covers it.
local function setup(seed: number, radar: boolean): (Sim.Sim, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local talos = Spawn.unit(sim, "chs_talos", 2, 0, 0)
	if radar then
		Spawn.unit(sim, "chs_eye", 2, 200, 300)
	end
	return sim, talos
end

return function(t: RunAll.Context)
	t.test("a weapon without canTargetRadar in its def fires at a radar blip beyond its sight (S-202)", function()
		t.expect(require("@shared/Defs/Registry").weapons.chs_talos_shell.canTargetRadar == nil, "(the def doesn't ask for it)")
		local sim, talos = setup(1, true)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 300, math.pi)
		World.setFireState(sim.world, tank, World.FireState.HOLD_FIRE)
		World.setMoveState(sim.world, tank, World.MoveState.HOLD_POSITION)
		World.setHealth(sim.world, tank, 1e6)
		local n = shots(sim, talos, 15 * 20)
		t.expect(n >= 3, `it shells the blip ({n} shots in 20 s)`)
		-- no radar: nothing to shoot at
		local sim2, talos2 = setup(1, false)
		local tank2 = Spawn.unit(sim2, "ord_lancer", 1, 0, 300, math.pi)
		World.setFireState(sim2.world, tank2, World.FireState.HOLD_FIRE)
		World.setMoveState(sim2.world, tank2, World.MoveState.HOLD_POSITION)
		t.equal(shots(sim2, talos2, 15 * 10), 0, "unseen and off radar: no shot")
	end)

	t.test("a structure seen once is shot while radar covers it, not when only remembered (S-202, S-127)", function()
		local function run(radar: boolean): number
			local sim, talos = setup(2, radar)
			local w = sim.world
			local gen = Spawn.unit(sim, "ord_generator", 1, 0, 300)
			World.setHealth(w, gen, 1e6)
			-- a scout sees it for a moment, then dies: the team remembers a ghost
			local scout = Spawn.unit(sim, "chs_scrapper", 2, 30, 300)
			World.setFireState(w, scout, World.FireState.HOLD_FIRE)
			shots(sim, talos, 6)
			Combat.queueDamage(sim.combat, scout, w.health[scout] + 1, 0)
			shots(sim, talos, 6)
			return shots(sim, talos, 15 * 20)
		end
		local covered = run(true)
		local remembered = run(false)
		t.expect(covered >= 3, `on radar: shelled ({covered} shots)`)
		t.equal(remembered, 0, "only remembered: left alone without an attack order")
	end)
end
