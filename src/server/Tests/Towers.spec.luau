--!strict
-- T1 laser towers, the Beamer, the lobbing guns and Chaos's Bulwark (S-157,
-- the user), and the tier rebalance they came with. Since the playtest's
-- balance notes (S-179) a T1 tower holds against scouts and a pair of T1
-- tanks and takes three or four; a T2 tank still beats one comfortably.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Combat = require("../Sim/Combat/Combat")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

export type Fight = { towerDead: boolean, alive: number, health: number, seconds: number }

-- `count` units of `attacker` (player 1) 260 studs south of a lone `tower`
-- (player 2), attack-moving onto it; up to 90 s. `health`: the attackers'
-- health left, as a share of their full health.
local function fight(seed: number, tower: string, attacker: string, count: number): Fight
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local w = sim.world
	local t = Spawn.unit(sim, tower, 2, 0, 0)
	local ids = {}
	for i = 1, count do
		table.insert(ids, Spawn.unit(sim, attacker, 1, (i - (count + 1) / 2) * 14, -260, 0))
	end
	-- an attack-move to 40 studs short of the tower (an ATTACK needs it seen
	-- first, and an attack-move onto it drives into it)
	local cell, ox, oz = (sim.map :: any).grid:encode(0, -40)
	submit(sim, 1, { cmdType = CT.FIGHT, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	local full = sim.defs.units[attacker].health * count
	local ticks = 0
	for _ = 1, 15 * 90 do
		Sim.step(sim)
		ticks += 1
		if w.slot[t] == nil then
			break
		end
		local any = false
		for _, id in ids do
			any = any or w.slot[id] ~= nil
		end
		if not any then
			break
		end
	end
	local alive, health = 0, 0
	for _, id in ids do
		if w.slot[id] ~= nil then
			alive += 1
			health += w.health[id]
		end
	end
	return { towerDead = w.slot[t] == nil, alive = alive, health = health / full, seconds = ticks / 15 }
end

local function describe(f: Fight): string
	return `tower {if f.towerDead then "down" else "standing"}, {f.alive} left at {math.floor(f.health * 100 + 0.5)}% health, {f.seconds} s`
end

return function(t: RunAll.Context)
	t.test("a lone T1 laser tower holds against six scouts and two T1 tanks; four tanks take it (S-179, the playtest)", function()
		for _, tower in { "ord_sentry_tower", "chs_guard" } do
			for _, scout in { "chs_jackal", "ord_herald" } do
				local f = fight(1, tower, scout, 6)
				t.expect(not f.towerDead, `6 {scout} don't take a {tower}: {describe(f)}`)
			end
			for _, tank in { "ord_lancer", "chs_ravager" } do
				local two = fight(1, tower, tank, 2)
				local four = fight(1, tower, tank, 4)
				print(`    {tower} vs {tank}: 2: {describe(two)}; 4: {describe(four)}`)
				t.expect(not two.towerDead, `2 {tank} don't take a {tower}: {describe(two)}`)
				t.expect(four.towerDead, `4 {tank} do: {describe(four)}`)
			end
		end
	end)

	t.test("a T2 tank beats a lone T1 tower (S-157, the user: a Spike took half a Juggernaut; S-179)", function()
		for _, case in { { "chs_guard", "ord_paladin" }, { "ord_sentry_tower", "chs_goliath" }, { "chs_guard", "chs_goliath" }, { "chs_spike", "chs_goliath" } } do
			local f = fight(1, case[1], case[2], 1)
			print(`    {case[2]} vs {case[1]}: {describe(f)}`)
			-- (S-179: T1 towers doubled; a T2 tank still wins, with less to spare)
			t.expect(f.towerDead and f.health >= 0.25, `{case[2]} beats a {case[1]} with a quarter of its health left: {describe(f)}`)
		end
	end)

	t.test("the Beamer ramps up a hit over 4 s on one target (1/5 to full), and pauses when it switches", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local beamer = Spawn.unit(sim, "ord_beamer", 1, 0, 0)
		local tanks = {}
		for i, x in { -40, 40 } do
			local tank = Spawn.unit(sim, "chs_goliath", 2, x, 150, math.pi)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
			World.setHealth(w, tank, 1e6)
			tanks[i] = tank
		end
		local hits: { { tick: number, target: number, damage: number } } = {}
		local lastHealth: { [number]: number } = {}
		for _, tank in tanks do
			lastHealth[tank] = w.health[tank]
		end
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				for _, tank in tanks do
					local h = w.health[tank]
					if h == nil then
						continue -- dead
					end
					if h < lastHealth[tank] - 1e-6 then
						table.insert(hits, { tick = sim.tick, target = tank, damage = lastHealth[tank] - h })
					end
					lastHealth[tank] = h
				end
			end
		end
		step(15 * 7)
		t.expect(#hits >= 25, `it fires about five times a second ({#hits} hits in 7 s)`)
		local first, target = hits[1], hits[1].target
		-- ARMORED: ramp.from .. the full damage, a laser's at this distance (S-178)
		local beam = sim.defs.weapons.ord_beamer_beam
		local ramp = beam.ramp :: any
		local full = beam.damage.ARMORED * Combat.nearFactor(beam, math.sqrt(40 * 40 + 150 * 150))
		local low = full * ramp.from / ramp.to
		t.expect(first.damage < low * 1.4, `the first hit is weak: {first.damage} (ramp start {low})`)
		local last = hits[#hits]
		t.equal(last.target, target, "it stays on one target")
		t.expect(math.abs(last.damage - full) < 1e-3, `after 4 s every hit deals {full}: {last.damage}`)
		local mid = 0
		for _, h in hits do
			if h.tick - first.tick >= 30 and h.tick - first.tick < 33 then
				mid = h.damage
			end
		end
		t.expect(mid > 0.5 * full and mid < 0.7 * full, `halfway up the ramp after 2 s: {mid}`)

		-- the target dies: it switches, after a pause from full intensity
		World.setHealth(w, target, 1)
		lastHealth[target] = 1
		local before = #hits
		local deadAt = 0
		local other = if target == tanks[1] then tanks[2] else tanks[1]
		for _ = 1, 30 do
			step(1)
			if deadAt == 0 and w.slot[target] == nil then
				deadAt = sim.tick
			end
		end
		local nextHit = nil
		for i = before + 1, #hits do
			if hits[i].target == other then
				nextHit = hits[i]
				break
			end
		end
		t.expect(deadAt > 0 and nextHit ~= nil, "it switched to the other tank")
		local gap = ((nextHit :: any).tick - deadAt) / 15
		t.expect(gap >= 0.45, `a pause of about 0.5 s from full intensity: {gap} s`)
		t.expect((nextHit :: any).damage < low * 1.4, `and it starts low again: {(nextHit :: any).damage}`)
	end)

	t.test("laser shots cost power: a Sentry fires while the team has it, and holds when it's gone (S-187, the user)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tower = Spawn.unit(sim, "ord_sentry_tower", 1, 0, 0)
		local tank = Spawn.unit(sim, "chs_goliath", 2, 0, 120, math.pi)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
		World.setHealth(w, tank, 1e6)
		local acc = sim.eco.accounts[1].power
		local cost = (sim.defs.weapons.ord_sentry_laser.shotCost :: any).power
		local function shots(ticks: number, refill: number?): number
			local n = 0
			for _ = 1, ticks do
				if refill then
					acc.stored = refill
				end
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "FIRE" and e.unit == tower then
						n += 1
					end
				end
			end
			return n
		end
		t.expect(shots(15 * 5, 1000) >= 4, "with power it fires")
		local drawn = acc.drawn
		shots(15 * 2, 1000)
		t.expect(acc.drawn - drawn >= cost, `each shot draws {cost} power`)
		t.equal(shots(15 * 5, 0), 0, "with none it holds")
	end)

	t.test("the lobbing guns fire on the high arc and hit a still target at medium range", function()
		for _, id in { "ord_gauntlet", "chs_talos" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local gun = Spawn.unit(sim, id, 1, 0, 0)
			local range = sim.defs.weapons[sim.defs.units[id].weapons[1].def].range
			local tank = Spawn.unit(sim, "chs_goliath", 2, 0, range - 40, math.pi)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
			World.setHealth(w, tank, 1e6)
			local spotter = Spawn.unit(sim, "ord_herald", 1, 30, range - 100, 0)
			World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
			World.setMoveState(w, spotter, World.MoveState.HOLD_POSITION)
			local hurt = false
			for _ = 1, 15 * 20 do
				Sim.step(sim)
				hurt = hurt or w.health[tank] < 1e6
			end
			t.expect(hurt, `{id} hits a tank {range - 40} studs off`)
			t.expect(w.wPitch[World.slotKey(gun, 1)] > math.rad(45), `{id} aims above 45°: {math.deg(w.wPitch[World.slotKey(gun, 1)])}°`)
		end
	end)

	t.test("Chaos's Bulwark fires its beam and its laser, and starts switched on (S-157)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local acc = sim.eco.accounts[1]
		acc.power.storage, acc.power.stored = 100000, 100000
		local tower = Spawn.unit(sim, "chs_bulwark", 1, 0, 0)
		local tank = Spawn.unit(sim, "ord_paladin", 2, 0, 150, math.pi)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
		World.setHealth(w, tank, 1e6)
		local fired = { false, false }
		for _ = 1, 15 * 10 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower then
					fired[e.slot :: number] = true
				end
			end
		end
		t.expect(fired[1] and fired[2], `both weapons fire (beam {fired[1]}, laser {fired[2]})`)
		t.expect(bit32.band(w.state[tower], World.State.TOGGLED_ON) ~= 0, "it starts switched on")
	end)
end
