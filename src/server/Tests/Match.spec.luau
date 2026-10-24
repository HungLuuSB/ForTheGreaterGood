--!strict
local Combat = require("../Sim/Combat/Combat")
local Match = require("../Sim/Match")
local Packer = require("@shared/Net/Packer")
local Replay = require("../Sim/Replay")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local CORNERS = { { -400, -400 }, { 400, -400 }, { -400, 400 }, { 400, 400 } }

-- FFA: players 1..n, each their own ally team. TEAM: players 1..4 in ally
-- teams {1, 2} and {3, 4}.
local function players(mode: string, n: number): { any }
	local list = {}
	for i = 1, n do
		table.insert(list, { id = i, team = i, allyTeam = if mode == "TEAM" then (if i <= 2 then 1 else 2) else i })
	end
	return list
end

type Setup = { sim: Sim.Sim, commander: { number }, tank: { number } }

-- Each player: a Command Vehicle and a tank in their own corner, holding fire.
local function setup(mode: "FFA" | "TEAM", win: "COMMAND_ENDS" | "ANNIHILATION", n: number, unitCap: number?): Setup
	local sim = Sim.new({ seed = 5, players = players(mode, n), mapId = "flat:128", match = { mode = mode, win = win, unitCap = unitCap } })
	local s: Setup = { sim = sim, commander = {}, tank = {} }
	for pid = 1, n do
		local x, z = CORNERS[pid][1], CORNERS[pid][2]
		s.commander[pid] = Spawn.unit(sim, if pid % 2 == 1 then "ord_sovereign" else "chs_warlord", pid, x, z)
		s.tank[pid] = Spawn.unit(sim, if pid % 2 == 1 then "ord_lancer" else "chs_ravager", pid, x + 30, z)
		for _, id in { s.commander[pid], s.tank[pid] } do
			World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
		end
	end
	return s
end

local function kill(sim: Sim.Sim, ids: { number })
	for _, id in ids do
		if sim.world.slot[id] then
			Combat.queueDamage(sim.combat, id, 1e9, 0)
		end
	end
end

-- Steps `n` ticks; returns the ELIMINATED players and MATCH_END winners seen.
local function step(sim: Sim.Sim, n: number): ({ number }, { number })
	local out, ends = {}, {}
	for _ = 1, n do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "ELIMINATED" then
				table.insert(out, e.other)
			elseif e.kind == "MATCH_END" then
				table.insert(ends, e.other)
			end
		end
	end
	return out, ends
end

local function owned(sim: Sim.Sim, pid: number): number
	local n = 0
	for _, id in sim.world.ids do
		if sim.world.owner[id] == pid then
			n += 1
		end
	end
	return n
end

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

return function(t: RunAll.Context)
	t.test("FFA, Command Ends: losing the Command Vehicle eliminates; the last player standing wins", function()
		local s = setup("FFA", "COMMAND_ENDS", 3)
		local sim = s.sim
		local out, ends = step(sim, 5)
		t.deepEqual(out, {}, "nobody out at the start")
		-- exactly lethal damage: the commander leaves a wreck
		Combat.queueDamage(sim.combat, s.commander[2], sim.world.health[s.commander[2]], 0)
		out, ends = step(sim, 3)
		t.deepEqual(out, { 2 }, "player 2 is out")
		t.equal(owned(sim, 2), 0, "their remaining units self-destructed")
		t.equal(#sim.combat.wreckIds, 1, "self-destruct leaves no wrecks (only the killed commander's)")
		t.expect(not sim.match.over, "two players left")
		kill(sim, { s.commander[3] })
		out, ends = step(sim, 3)
		t.deepEqual(out, { 3 })
		t.deepEqual(ends, { 1 }, "player 1's ally team wins")
		t.expect(sim.match.over and sim.match.winner == 1, "match over")
		t.expect(sim.world.slot[s.tank[1]] ~= nil, "the winner keeps their units")
	end)

	t.test("an eliminated player's units self-destruct a few a tick, not all at once (S-144)", function()
		local s = setup("FFA", "COMMAND_ENDS", 3)
		local sim = s.sim
		for i = 1, 45 do
			Spawn.unit(sim, "chs_ravager", 2, 200 + (i % 9) * 12, -200 + (i // 9) * 12)
		end
		step(sim, 2)
		local before = owned(sim, 2)
		Combat.queueDamage(sim.combat, s.commander[2], sim.world.health[s.commander[2]], 0)
		local counts = {}
		for _ = 1, 6 do
			Sim.step(sim)
			table.insert(counts, owned(sim, 2))
		end
		t.expect(before > 40, `player 2 had an army ({before})`)
		local drops = 0
		for k = 2, #counts do
			local d = counts[k - 1] - counts[k]
			t.expect(d <= Match.SELF_DESTRUCT_PER_TICK, `at most {Match.SELF_DESTRUCT_PER_TICK} a tick ({counts[k - 1]} -> {counts[k]})`)
			if d > 0 then
				drops += 1
			end
		end
		t.expect(drops >= 2, `spread over several ticks ({table.concat(counts, ", ")})`)
		t.equal(counts[#counts], 0, "and all gone within a few ticks")
		t.equal(#sim.match.doomed, 0, "nothing left to do")
	end)

	t.test("an eliminated player's structures self-destruct about two a tick (S-164: B's watchdog saw Damage 96 ms)", function()
		local s = setup("FFA", "COMMAND_ENDS", 3)
		local sim = s.sim
		local gens = {}
		for i = 0, 9 do
			table.insert(gens, Spawn.unit(sim, "chs_generator", 2, 150 + (i % 5) * 24, 150 + (i // 5) * 24))
		end
		step(sim, 2)
		Combat.queueDamage(sim.combat, s.commander[2], sim.world.health[s.commander[2]], 0)
		local function standing(): number
			local n = 0
			for _, id in gens do
				if sim.world.slot[id] then
					n += 1
				end
			end
			return n
		end
		local counts = {}
		for _ = 1, 10 do
			Sim.step(sim)
			table.insert(counts, standing())
		end
		local per = Match.SELF_DESTRUCT_PER_TICK // Match.SELF_DESTRUCT_STRUCTURE
		for k = 2, #counts do
			t.expect(counts[k - 1] - counts[k] <= per, `at most {per} structures a tick ({table.concat(counts, ", ")})`)
		end
		t.equal(counts[#counts], 0, `all gone within 10 ticks ({table.concat(counts, ", ")})`)
	end)

	t.test("FFA, Annihilation: out only when nothing is left", function()
		local s = setup("FFA", "ANNIHILATION", 3)
		local sim = s.sim
		kill(sim, { s.commander[2] })
		local out = step(sim, 3)
		t.deepEqual(out, {}, "a tank is still alive: not out")
		kill(sim, { s.tank[2] })
		out = step(sim, 3)
		t.deepEqual(out, { 2 }, "nothing left: out")
		kill(sim, { s.commander[3], s.tank[3] })
		local out2, ends = step(sim, 3)
		t.deepEqual(out2, { 3 })
		t.deepEqual(ends, { 1 })
		t.equal(sim.match.winner, 1)
	end)

	t.test("Team, Command Ends: an ally team loses when all its Command Vehicles are gone", function()
		local s = setup("TEAM", "COMMAND_ENDS", 4)
		local sim = s.sim
		kill(sim, { s.commander[1] })
		local out, ends = step(sim, 3)
		t.deepEqual(out, { 1 }, "player 1 is out")
		t.deepEqual(ends, {}, "but their ally fights on")
		kill(sim, { s.commander[3] })
		out, ends = step(sim, 3)
		t.deepEqual(out, { 3 })
		t.deepEqual(ends, {})
		kill(sim, { s.commander[4] })
		out, ends = step(sim, 3)
		t.deepEqual(out, { 4 })
		t.deepEqual(ends, { 1 }, "ally team 1 (player 2 still in) wins")
		t.equal(sim.match.eliminated[2], nil, "player 2 was never eliminated")
	end)

	t.test("Team, Annihilation: an ally team loses when its players have nothing left", function()
		local s = setup("TEAM", "ANNIHILATION", 4)
		local sim = s.sim
		kill(sim, { s.commander[3], s.tank[3], s.commander[1] })
		local out, ends = step(sim, 3)
		t.deepEqual(out, { 3 }, "player 3 has nothing left; player 1 still has a tank")
		t.deepEqual(ends, {})
		kill(sim, { s.commander[4], s.tank[4] })
		out, ends = step(sim, 3)
		t.deepEqual(out, { 4 })
		t.deepEqual(ends, { 1 })
	end)

	t.test("mutual destruction is a draw", function()
		local s = setup("FFA", "COMMAND_ENDS", 2)
		kill(s.sim, { s.commander[1], s.commander[2] })
		local out, ends = step(s.sim, 3)
		t.deepEqual(out, { 1, 2 })
		t.deepEqual(ends, { 0 }, "winner 0: nobody left")
	end)

	t.test("allies share sight and never target each other; enemies do", function()
		local function scene(mode: "FFA" | "TEAM"): Sim.Sim
			local sim = Sim.new({ seed = 6, players = players(mode, 4), mapId = "flat:128", match = { mode = mode, win = "ANNIHILATION" } })
			local w = sim.world
			Spawn.unit(sim, "ord_lancer", 1, 0, 0) -- player 1's scout
			Spawn.unit(sim, "chs_ravager", 3, 120, 0) -- an enemy of team 1 in TEAM mode
			local ally = Spawn.unit(sim, "chs_ravager", 2, 60, 0) -- player 2 (player 1's ally in TEAM mode)
			Spawn.unit(sim, "ord_lancer", 4, 400, 400)
			World.setFireState(w, ally, World.FireState.HOLD_FIRE)
			return sim
		end
		local team = scene("TEAM")
		for _ = 1, 4 do
			Sim.step(team)
		end
		local enemy = team.world.ids[2]
		t.equal(Sensors.level(team, team.allyOf[2], enemy), L.VISIBLE, "TEAM: player 2 sees what player 1 sees")
		local damageToAlly, shotsAtEnemy = 0, 0
		local allyUnit = team.world.ids[3]
		local hp = team.world.health[allyUnit]
		for _ = 1, 200 do
			Sim.step(team)
			for _, e in team.combat.events do
				if (e.kind == "SPAWN_PROJ" or e.kind == "FIRE") and e.unit == team.world.ids[1] then
					local tgt = team.world.wTarget[World.slotKey(e.unit, e.slot :: number)]
					t.expect(tgt ~= allyUnit, "never targets an ally")
					shotsAtEnemy += 1
				end
			end
		end
		damageToAlly = hp - (team.world.health[allyUnit] or hp)
		t.expect(shotsAtEnemy > 0, "player 1 engages the enemy")
		t.expect(damageToAlly < hp, "the ally survives the crossfire")

		local ffa = scene("FFA")
		for _ = 1, 4 do
			Sim.step(ffa)
		end
		local ffaEnemy = ffa.world.ids[2]
		local p4 = ffa.world.ids[4]
		t.equal(Sensors.level(ffa, ffa.allyOf[4], ffaEnemy), L.HIDDEN, "FFA: nobody shares sight")
		t.expect(ffa.allyOf[2] ~= ffa.allyOf[1], "FFA: every player is their own ally team")
		local _ = p4
	end)

	t.test("economy overflow goes to allies with room; in FFA it is wasted", function()
		local function run(mode: "FFA" | "TEAM"): (number, number)
			local sim = Sim.new({ seed = 7, players = players(mode, 4), mapId = "flat:128", match = { mode = mode, win = "ANNIHILATION" } })
			for pid = 1, 4 do
				Spawn.unit(sim, "ord_lancer", pid, CORNERS[pid][1], CORNERS[pid][2]) -- keep everyone in
			end
			for i = 1, 3 do
				Spawn.unit(sim, "ord_generator", 1, -300 + i * 30, -300) -- player 1: +60 power/s
			end
			local p1, p2 = sim.eco.accounts[1].power, sim.eco.accounts[2].power
			p1.stored = p1.storage -- full
			p2.stored = 0
			for _ = 1, 300 do -- 20 s
				Sim.step(sim)
			end
			return p2.stored, p1.wasted
		end
		-- 60 power/s for 20 s = 1,200; the generators' own storage (+300)
		-- fills first, so 900 overflows
		local teamP2, teamWasted = run("TEAM")
		local ffaP2, ffaWasted = run("FFA")
		t.expect(math.abs(teamP2 - 900) < 1e-6, `TEAM: the ally received player 1's overflow ({teamP2} power)`)
		t.expect(teamWasted < 1e-6, "TEAM: nothing wasted while the ally has room")
		t.equal(ffaP2, 0, "FFA: no sharing")
		t.expect(math.abs(ffaWasted - 900) < 1e-6, `FFA: overflow wasted ({ffaWasted})`)
	end)

	t.test("unit cap: construction fails and factory output waits at the cap", function()
		local s = setup("FFA", "ANNIHILATION", 2, 4)
		local sim = s.sim
		local w = sim.world
		local generators = {}
		for i = 1, 2 do
			table.insert(generators, Spawn.unit(sim, "ord_generator", 1, -300 + i * 30, -460))
		end
		-- player 1: commander, tank, two generators = 4 = the cap
		t.equal(sim.match.units[1], 4)
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(-300, -300)
		submit(sim, 1, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = { s.commander[1] }, defIndex = sim.defs.units.ord_generator.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
		local failed = nil
		for _ = 1, 600 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "BUILD_FAILED" then
					failed = e.reason
				end
			end
			if failed then
				break
			end
		end
		t.equal(failed, "unit_cap", "construction refused at the cap")

		-- a factory at the cap: the finished tank waits until there is room
		kill(sim, { s.tank[1] })
		Sim.step(sim)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -200, -300, math.pi / 2) -- back to 4
		cell, ox, oz = g:encode(-200, -300)
		submit(sim, 1, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_lancer.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
		local produced = 0
		for _ = 1, 1500 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" then
					produced += 1
				end
			end
		end
		t.equal(produced, 0, "no new unit while at the cap")
		t.expect((sim.build.progress[plant] or 0) >= 1 - 1e-9, "the lancer is finished and waiting")
		t.equal(sim.match.units[1], 4)
		kill(sim, { generators[1] }) -- free one slot
		local rolled = 0
		for _ = 1, 3 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" then
					rolled += 1
				end
			end
		end
		t.equal(rolled, 1, "it rolls out as soon as there is room")
		t.equal(sim.match.units[1], 4)
		local _ = w
	end)

	t.test("match configs are checked", function()
		local function try(mode: any, list: { any }): boolean
			return (pcall(Sim.new, { seed = 1, players = list, mapId = "none", match = { mode = mode, win = "COMMAND_ENDS" } }))
		end
		t.expect(try("FFA", players("FFA", 3)), "FFA of 3 is fine")
		t.expect(try("TEAM", players("TEAM", 4)), "2v2 is fine")
		t.expect(not try("FFA", players("TEAM", 4)), "FFA with shared ally teams is rejected")
		t.expect(not try("TEAM", players("FFA", 1)), "TEAM with one ally team is rejected")
		local five = {}
		for i = 1, 6 do
			table.insert(five, { id = i, team = i, allyTeam = if i <= 5 then 1 else 2 })
		end
		t.expect(try("TEAM", five), "a side of 5 is fine (S-169)")
		local sixteen, seventeen, nine = {}, {}, {}
		for i = 1, 17 do
			table.insert(seventeen, { id = i, team = i, allyTeam = if i <= 8 then 1 else 2 })
			if i <= 16 then
				table.insert(sixteen, { id = i, team = i, allyTeam = if i <= 8 then 1 else 2 })
			end
		end
		for i = 1, 9 do
			table.insert(nine, { id = i, team = i, allyTeam = i })
		end
		t.expect(try("TEAM", sixteen), "8v8 is fine (S-169)")
		t.expect(not try("TEAM", seventeen), "17 players are rejected")
		t.expect(not try("TEAM", nine), "9 sides are rejected")
		t.expect(try("FFA", players("FFA", 16)), "a 16-player FFA is fine")
		t.equal(Sim.new({ seed = 1, players = sixteen, mapId = "none", match = { mode = "TEAM", win = "ANNIHILATION" } }).match.unitCap, 0, "16 players: no cap (S-170)")
		t.expect(not try("CTF", players("FFA", 2)), "unknown modes are rejected")
		local default = Sim.new({ seed = 1, players = players("FFA", 8), mapId = "none", match = { mode = "FFA", win = "ANNIHILATION" } })
		t.equal(default.match.unitCap, 0, "no unit cap by default (S-170, the user)")
		local duel = Sim.new({ seed = 1, players = players("FFA", 2), mapId = "none", match = { mode = "FFA", win = "ANNIHILATION" } })
		t.equal(duel.match.unitCap, 0, "1v1 neither")
		local capped = Sim.new({ seed = 1, players = players("FFA", 2), mapId = "none", match = { mode = "FFA", win = "ANNIHILATION", unitCap = 40 } })
		t.equal(capped.match.unitCap, 40, "a config may still set one")
	end)

	t.test("a fought-out Team match ends and replays exactly", function()
		local sim = Sim.new({
			seed = 8,
			players = players("TEAM", 4),
			mapId = "flat:128",
			scenario = "match_test",
			match = { mode = "TEAM", win = "COMMAND_ENDS" },
		})
		local g = (sim.map :: any).grid
		for pid = 1, 4 do
			local mine = {}
			for _, id in sim.world.ids do
				if sim.world.owner[id] == pid then
					table.insert(mine, id)
				end
			end
			local cell, ox, oz = g:encode(0, 0) -- both sides meet in the middle
			submit(sim, pid, { cmdType = Schema.CmdType.FIGHT, flags = 0, unitIds = mine, cell = cell, offX = ox, offZ = oz })
		end
		local ended = nil
		for _ = 1, 4500 do
			Sim.step(sim)
			if sim.match.over then
				ended = sim.tick
				break
			end
		end
		t.expect(ended ~= nil, "the match ended")
		t.equal(sim.match.winner, 1, "the stronger ally team won")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		local log = Replay.parse(Replay.serialize(sim.replay))
		t.equal((log.header.match :: any).mode, "TEAM")
		local replayed, mismatch = Sim.runReplay(log, sim.tick)
		t.equal(mismatch, nil, "checkpoints match")
		t.equal(Sim.hash(replayed), Sim.hash(sim))
		t.equal(replayed.match.endTick, sim.match.endTick)
		t.equal(replayed.match.winner, sim.match.winner)
		print(`    2v2 Command Ends: ended at {string.format("%.1f", (ended or 0) / 15)} s, ally team {sim.match.winner} won`)
	end)
end
