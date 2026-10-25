--!strict
-- Overkill-aware targeting (S-29, guide 10.2): a weapon doesn't fire at a
-- visible target that damage already on its way will kill, so a group's
-- fire spreads over several targets.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 3 } }

type Run = {
	firstVolley: number, -- distinct targets among the first `#guns` shots
	shots: number, -- shells fired until every target died
	ticks: number, -- until every target died (or the limit)
	alive: number, -- targets left at the end
	shotAt: { [number]: number }, -- target → shells fired at it
}

-- `guns` Verdicts (precise artillery) against `n` Ravagers that hold fire,
-- each with `shells` × a howitzer shell's armour damage in health, seen by a
-- Lancer that holds fire too. The column ends just inside the gun's range
-- (where it ended before S-179 halved it), its Ravagers far enough apart that
-- a death blast doesn't reach the next one.
local function barrage(guns: number, n: number, shells: number, avoid: boolean, attackOrder: boolean?): Run
	Combat.AVOID_OVERKILL = avoid
	local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:96" })
	local w, c = sim.world, sim.combat
	local weapon = sim.defs.weapons.ord_howitzer
	local health = shells * weapon.damage.ARMORED
	local gap = math.max(20, sim.defs.units.chs_ravager.deathBlast.aoe)
	local near = -170 + weapon.range * 0.92 - (n - 1) * gap
	local gunIds, targets = {}, {}
	for i = 1, guns do
		table.insert(gunIds, Spawn.unit(sim, "ord_verdict", 1, -170, (i - (guns + 1) / 2) * 24, math.pi / 2))
	end
	local spotter = Spawn.unit(sim, "ord_lancer", 1, near + 2 * gap, 80, math.pi / 2) -- artillery needs eyes
	World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
	for i = 1, n do
		local t = Spawn.unit(sim, "chs_ravager", 2, near + (i - 1) * gap, 0, -math.pi / 2) -- a column: the nearest is the same for every gun
		World.setFireState(w, t, World.FireState.HOLD_FIRE)
		World.setHealth(w, t, health)
		table.insert(targets, t)
	end
	if attackOrder then
		-- an ATTACK needs a target the team knows: wait for the spotter's
		-- first look (an order at tick 0 is dropped)
		while Sensors.knownTarget(sim, w.ally[gunIds[1]], targets[1]) == nil do
			Sim.step(sim)
		end
		local wr = Packer.Writer.new()
		Schema.encodeCommand(wr, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = gunIds, targetId = targets[1] })
		assert(Sim.submit(sim, 1, wr:finish()))
	end
	local r: Run = { firstVolley = 0, shots = 0, ticks = 0, alive = n, shotAt = {} }
	local first: { [number]: boolean } = {}
	local firstCount = 0
	for _ = 1, 900 do
		Sim.step(sim)
		for _, e in c.events do
			if e.kind == "SPAWN_PROJ" then
				r.shots += 1
				local t = c.pAim[e.other] or 0
				r.shotAt[t] = (r.shotAt[t] or 0) + 1
				if firstCount < guns then
					firstCount += 1
					if not first[t] then
						first[t] = true
						r.firstVolley += 1
					end
				end
			end
		end
		r.alive = 0
		for _, t in targets do
			if w.slot[t] ~= nil then
				r.alive += 1
			end
		end
		r.ticks = sim.tick
		if r.alive == 0 and #c.proj == 0 then
			break
		end
	end
	Combat.AVOID_OVERKILL = true
	return r
end

return function(t: RunAll.Context)
	t.test("the hit-chance estimate matches the damage fired shells really deal", function()
		-- a gun firing at a stationary Ravager that can't die, seen by a tower
		local sim0 = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:32" })
		local function measured(gun: string, weapon: string, dist: number): (number, number)
			local sim = Sim.new({ seed = 7, players = PLAYERS, mapId = "flat:128" })
			local w, c = sim.world, sim.combat
			local shooter = Spawn.unit(sim, gun, 1, -dist / 2, 0, math.pi / 2)
			Spawn.unit(sim, "ord_watchtower", 1, dist / 2 - 40, 60, 0)
			local t = Spawn.unit(sim, "chs_ravager", 2, dist / 2, 0, -math.pi / 2)
			World.setFireState(w, t, World.FireState.HOLD_FIRE)
			World.setHealth(w, t, 1e9)
			local fired = 0
			for _ = 1, 15 * 120 do
				Sim.step(sim)
				for _, e in c.events do
					if e.kind == "SPAWN_PROJ" then
						fired += 1
					end
				end
				if fired >= 30 then
					break
				end
			end
			World.setFireState(w, shooter, World.FireState.HOLD_FIRE) -- no more shells than counted
			for _ = 1, 60 do
				Sim.step(sim) -- the last shells land
			end
			local wd = sim.defs.weapons[weapon]
			return (1e9 - w.health[t]) / fired / wd.damage.ARMORED, Combat.hitChance(wd, c.profiles[sim.defs.units.chs_ravager.index], dist)
		end
		-- distances as shares of each weapon's range, so they stay inside it
		-- through balance passes (S-179 halved T1 ranges)
		for _, case in { { "ord_verdict", "ord_howitzer", 0.73 }, { "chs_hellmouth", "chs_mortar", 0.53 }, { "chs_hellmouth", "chs_mortar", 0.92 }, { "ord_lancer", "ord_lancer_cannon", 0.95 } } do
			local weapon = case[2] :: string
			local dist = math.floor(sim0.defs.weapons[weapon].range * (case[3] :: number))
			local real, model = measured(case[1] :: string, weapon, dist)
			print(string.format("    %s at %d: damage per shell %.2f of full, estimate %.2f", weapon, dist, real, model))
			t.expect(math.abs(real - model) < 0.15, `{weapon} at {dist}: estimate {model} against {real} measured`)
		end
		t.equal(Combat.hitChance(sim0.defs.weapons.chs_ir_sam, sim0.combat.profiles[sim0.defs.units.ord_falcon.index], 250), 1, "guided weapons: sure")
	end)

	t.test("an artillery group spreads its volley instead of overkilling one target", function()
		-- six one-shot targets (5/6 of a shell's damage in health) in a column,
		-- so every gun's nearest target is the same one
		local on = barrage(6, 6, 5 / 6, true)
		local off = barrage(6, 6, 5 / 6, false)
		print(string.format("    6 Verdicts vs 6 one-shot Ravagers: first volley on %d targets (%d without), %d shells and %.1f s to kill all (%d shells, %.1f s without)",
			on.firstVolley, off.firstVolley, on.shots, on.ticks / 15, off.shots, off.ticks / 15))
		t.equal(on.alive, 0, "all six die")
		t.expect(on.firstVolley >= 5, `the first six shells go to at least five targets ({on.firstVolley}; {off.firstVolley} without avoidance)`)
		t.expect(off.firstVolley < on.firstVolley, "more than without avoidance, where every gun picks the nearest")
		t.expect(on.shots < off.shots, `fewer shells wasted ({on.shots} against {off.shots})`)
		t.expect(on.ticks < off.ticks, `the group dies sooner ({on.ticks} against {off.ticks} ticks)`)
	end)

	t.test("with nothing else in reach a doomed target is still shot, and a miss gets followed up", function()
		local r = barrage(6, 1, 10 / 3, true) -- four hits needed
		t.equal(r.alive, 0, "the lone target dies")
		t.expect(r.shots >= 4, `it took the shells it needed ({r.shots})`)
		t.expect(r.ticks < 15 * 20, `without stalling ({r.ticks / 15} s)`)
	end)

	t.test("an attack order is obeyed even when the target is already doomed", function()
		local r = barrage(4, 3, 5 / 6, true, true)
		t.expect(((r.shotAt[0] or 0) + r.shots) > 0, "shells were fired")
		-- the ordered target gets every gun's first shell, though one would do
		local firstTarget = 0
		for target, n in r.shotAt do
			if n >= 4 then
				firstTarget = target
			end
		end
		t.expect(firstTarget ~= 0, "all four guns fired at the ordered target")
	end)
end
