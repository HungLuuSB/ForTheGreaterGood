--!strict
-- T2 defenses (S-96, client request 43): the beam towers (Radiance,
-- Inferno; BAR's Pulsar) and the flak towers (Lumen, Hailstorm).
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function power(sim: Sim.Sim, team: number, amount: number)
	local acc = sim.eco.accounts[team]
	acc.power.storage = math.max(acc.power.storage, amount)
	acc.power.stored = amount
end

-- Shots `id` fires over `ticks`; `each` runs after every step.
local function shots(sim: Sim.Sim, id: number, ticks: number, each: (() -> ())?): number
	local n = 0
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit == id then
				n += 1
			end
		end
		if each then
			each()
		end
	end
	return n
end

-- A beam tower of player 1 at the origin, a tank of player 2 at `dist`
-- studs, held still and harmless, and (with `spotter`) a scout of player 1
-- beside the tank so the tower's team sees it.
local function range(seed: number, tower: string, dist: number, spotter: boolean): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local w = sim.world
	local t = Spawn.unit(sim, tower, 1, 0, 0)
	local tank = Spawn.unit(sim, "chs_juggernaut", 2, 0, dist, math.pi)
	World.setFireState(w, tank, World.FireState.HOLD_FIRE)
	World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
	World.setHealth(w, tank, 1e6)
	if spotter then
		local scout = Spawn.unit(sim, "ord_herald", 1, 30, dist - 60, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		World.setMoveState(w, scout, World.MoveState.HOLD_POSITION)
	end
	return sim, t, tank
end

return function(t: RunAll.Context)
	t.test("Radiance: one very heavy beam every 9 s at long range, 700 power a shot; none without the power", function()
		local sim, tower, tank = range(1, "ord_radiance", 600, true)
		local w = sim.world
		local acc = sim.eco.accounts[1]
		power(sim, 1, 5000)
		t.expect(bit32.band(w.state[tower], World.State.TOGGLED_ON) ~= 0, "it starts switched on")
		local before = w.health[tank]
		local drawn = acc.power.drawn
		-- (team storage is 1,000 without depots: top it up each tick)
		local n = shots(sim, tower, 15 * 12, function()
			acc.power.stored = acc.power.storage
		end)
		t.equal(n, 2, "two shots in 12 s: the first once aimed, the next 9 s later")
		local hit = before - w.health[tank]
		t.expect(math.abs(hit - 2 * sim.defs.weapons.ord_radiance_beam.damage.ARMORED) < 1, `2 × 2,600 on an armored tank ({hit})`)
		t.expect(math.abs((acc.power.drawn - drawn) - 2 * 700) < 1, `700 power a shot ({acc.power.drawn - drawn})`)
		-- empty stores: no shot
		local held = 0
		held = shots(sim, tower, 15 * 20, function()
			acc.power.stored = 600 -- less than a shot, every tick
		end)
		t.equal(held, 0, "no shot while the stores hold less than 700")
	end)

	t.test("beam towers don't fire at radar-only contacts; seen, they do", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		power(sim, 2, 5000)
		local tower = Spawn.unit(sim, "chs_inferno", 2, 0, 0)
		local tank = Spawn.unit(sim, "ord_paladin", 1, 0, 450, math.pi)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
		World.setHealth(w, tank, 1e6)
		Spawn.unit(sim, "chs_eye", 2, -40, 0) -- radar: the tank is a contact, nothing sees it
		t.equal(shots(sim, tower, 15 * 15), 0, "a radar contact: no shot")
		local scout = Spawn.unit(sim, "chs_jackal", 2, 30, 390, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		World.setMoveState(w, scout, World.MoveState.HOLD_POSITION)
		t.expect(shots(sim, tower, 15 * 15) >= 1, "seen: it fires")
	end)

	t.test("switched off, a beam tower retracts: no fire, a quarter of the damage; on again, it fires", function()
		local sim, tower, tank = range(3, "ord_radiance", 500, true)
		local w = sim.world
		power(sim, 1, 5000)
		submit(sim, 1, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { tower }, value = 0 })
		Sim.step(sim)
		t.equal(bit32.band(w.state[tower], World.State.TOGGLED_ON), 0, "off")
		t.equal(shots(sim, tower, 15 * 12), 0, "no shot while retracted")
		local hp = w.health[tower]
		Combat.queueDamage(sim.combat, tower, 400, tank)
		Sim.step(sim)
		t.expect(math.abs((hp - w.health[tower]) - 100) < 1e-6, `400 damage → 100 retracted ({hp - w.health[tower]})`)
		submit(sim, 1, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { tower }, value = 1 })
		t.expect(shots(sim, tower, 15 * 12) >= 1, "on again: it fires")
		hp = w.health[tower]
		Combat.queueDamage(sim.combat, tower, 400, tank)
		Sim.step(sim)
		t.expect(math.abs((hp - w.health[tower]) - 400) < 1e-6, "full damage when on")
	end)

	t.test("flak towers shoot down aircraft over the base", function()
		for _, pair in { { "ord_lumen", "chs_harpy" }, { "chs_hailstorm", "ord_falcon" } } do
			local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:64" })
			local w = sim.world
			local owner = if string.sub(pair[1], 1, 4) == "ord_" then 1 else 2
			local tower = Spawn.unit(sim, pair[1], owner, 0, 0)
			local plane = Spawn.unit(sim, pair[2], 3 - owner, -150, 0, math.pi / 2)
			World.setFireState(w, plane, World.FireState.HOLD_FIRE)
			local fired = shots(sim, tower, 15 * 20)
			t.expect(fired > 0, `{pair[1]} fired at the {pair[2]} ({fired})`)
			t.expect(not World.isAlive(w, plane) or w.health[plane] < sim.defs.units[pair[2]].health, `{pair[1]}: the {pair[2]} took damage`)
		end
	end)
end
