--!strict
-- Cheat / test commands (S-102): rejected unless the match allows them,
-- recorded and replayed like any command, and each does what it says.
local Defs = require("@shared/Defs/Defs")
local CheatText = require("@shared/Net/CheatText")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Skirmish = require("../Sim/AI/Skirmish")
local Combat = require("../Sim/Combat/Combat")
local Replay = require("../Sim/Replay")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Stats = require("../Sim/Stats")
local RunAll = require("./RunAll")

local R = Schema.CheatResult
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local defs = Defs.load()

local function newSim(cheats: boolean?, extra: { [string]: any }?): Sim.Sim
	local config: any = { seed = 7, players = PLAYERS, mapId = "flat:128", cheats = cheats }
	for k, v in extra or {} do
		config[k] = v
	end
	return Sim.new(config)
end

-- Submits chat text from `player` (selection for "kill selected").
local function say(sim: Sim.Sim, player: number, text: string, selected: { number }?)
	local cmd, err = CheatText.parse(text, defs, selected)
	assert(cmd, err)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, why = Sim.submit(sim, player, w:finish())
	assert(ok, why)
end

-- Steps once and returns the player's answers, as NetOut sent them.
local function answers(sim: Sim.Sim, player: number): { Schema.Event }
	Sim.step(sim)
	local out = {}
	for _, msg in sim.net.players[player].outbox.Events do
		for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
			if e.kind == Schema.EventKind.CHEAT_RESULT then
				table.insert(out, e)
			end
		end
	end
	return out
end

local function owned(sim: Sim.Sim, player: number, defId: string?): { number }
	local out = {}
	local w = sim.world
	for _, id in w.ids do
		if w.owner[id] == player and (defId == nil or w.defIndex[id] == sim.defs.units[defId].index) then
			table.insert(out, id)
		end
	end
	return out
end

return function(t: RunAll.Context)
	t.test("off by default: every cheat is answered CHEATS_OFF and changes nothing", function()
		local sim = newSim(nil)
		local before = Sim.hash(newSim(nil))
		say(sim, 1, "give ord_lancer 5 at 0,0")
		say(sim, 1, "res supply 9000")
		say(sim, 1, "god on")
		local a = answers(sim, 1)
		t.equal(#a, 3)
		for _, e in a do
			t.equal(e.cheatResult, R.CHEATS_OFF)
		end
		t.equal(#owned(sim, 1), 0, "nothing given")
		t.equal(sim.cheats.used, false)
		t.equal(sim.replay.header.cheated, nil)
		local plain = newSim(nil)
		Sim.step(plain)
		t.equal(Sim.hash(sim), Sim.hash(plain), "same state as a match with no commands")
		t.notEqual(before, 0)
		-- a match option too
		local m = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128", match = { mode = "FFA", win = "ANNIHILATION", cheats = true } })
		t.equal(m.cheats.enabled, true, "match option cheats")
	end)

	t.test("give: a formation of finished units; structures snap and skip bad cells", function()
		local sim = newSim(true)
		say(sim, 1, "give ord_lancer 9 at 100,-40")
		local a = answers(sim, 1)
		t.equal(a[1].cheatResult, R.OK)
		t.equal(a[1].count, 9)
		t.equal(a[1].total, 9)
		local lancers = owned(sim, 1, "ord_lancer")
		t.equal(#lancers, 9)
		t.equal(sim.world.buildProgress[lancers[1]], 1, "finished")
		-- another team's, and structures at the map's edge (flat:128: ±512)
		say(sim, 1, "give chs_ravager 2 2 at -100,0")
		say(sim, 1, "give ord_solar 9 at 500,500")
		a = answers(sim, 1)
		t.equal(#owned(sim, 2, "chs_ravager"), 2, "team 2's player owns them")
		t.equal(a[2].cheatResult, R.OK)
		t.expect(a[2].count >= 1 and a[2].count < 9, `some generators off the map skipped ({a[2].count} of 9)`)
		t.equal(#owned(sim, 1, "ord_solar"), a[2].count)
		-- nowhere valid
		say(sim, 1, "give ord_solar 1 at 2000,2000")
		t.equal(answers(sim, 1)[1].cheatResult, R.NO_ROOM)
		t.equal(sim.cheats.used, true)
		t.equal(sim.replay.header.cheated, true)
		t.equal(Stats.report(sim)[1].cheats, 3, "the three that applied")
		t.equal(Stats.series(sim).cheated, true)
	end)

	t.test("res and income: stores set, storage raised, a flat bonus per second", function()
		local sim = newSim(true)
		say(sim, 1, "res supply 5000")
		say(sim, 2, "res power max")
		local a = answers(sim, 1)
		t.equal(a[1].count, 5000)
		local acc = sim.eco.accounts[1]
		t.equal(acc.supply.stored, 5000)
		t.expect(acc.supply.storage >= 5000, "storage raised")
		for _ = 1, 10 do
			Sim.step(sim)
		end
		t.expect(acc.supply.storage >= 5000 and acc.supply.stored >= 4999, "raise lasts")
		t.equal(sim.eco.accounts[2].power.stored, sim.eco.accounts[2].power.storage, "max fills")
		say(sim, 1, "res supply 100")
		say(sim, 1, "income supply 90")
		Sim.step(sim)
		local p0 = acc.supply.stored
		for _ = 1, 15 do
			Sim.step(sim)
		end
		t.equal(acc.supply.income, 90)
		t.expect(acc.supply.stored - p0 > 80, `about 90 more in a second ({acc.supply.stored - p0})`)
		say(sim, 1, "income supply 0")
		answers(sim, 1)
		for _ = 1, 5 do
			Sim.step(sim)
		end
		t.equal(acc.supply.income, 0, "cleared")
	end)

	t.test("instabuild: factory items and frames finish on their next build step, free", function()
		local sim = newSim(true)
		say(sim, 1, "give ord_vehplant 1 at 0,0")
		say(sim, 1, "give ord_mason 1 at 100,100")
		say(sim, 1, "instabuild on")
		answers(sim, 1)
		local plant = owned(sim, 1, "ord_vehplant")[1]
		local mason = owned(sim, 1, "ord_mason")[1]
		local supply = sim.eco.accounts[1].supply.stored
		local g = (sim.map :: any).grid
		local function cmd(ids: { number }, defId: string, x: number, z: number)
			local cell, ox, oz = g:encode(x, z)
			local w = Packer.Writer.new()
			Schema.encodeCommand(w, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = ids, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
			assert(Sim.submit(sim, 1, w:finish()))
		end
		cmd({ plant }, "ord_lancer", 0, 0)
		cmd({ mason }, "ord_solar", 120, 100)
		for _ = 1, 3 do
			Sim.step(sim)
		end
		t.equal(#owned(sim, 1, "ord_lancer"), 1, "the Lancer rolled out")
		local gens = owned(sim, 1, "ord_solar")
		t.equal(#gens, 1)
		t.equal(sim.world.buildProgress[gens[1]], 1, "the generator is finished")
		t.expect(sim.eco.accounts[1].supply.stored >= supply, "nothing spent")
	end)

	t.test("reveal: the team sees every enemy; off again", function()
		local sim = newSim(true)
		say(sim, 2, "give chs_ravager 1 at 400,400")
		say(sim, 1, "give ord_lancer 1 at -400,-400")
		answers(sim, 1)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		local enemy = owned(sim, 2)[1]
		t.equal(Sensors.level(sim, 1, enemy), Sensors.Level.HIDDEN, "too far to see")
		say(sim, 1, "reveal on")
		answers(sim, 1)
		for _ = 1, 2 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, enemy), Sensors.Level.VISIBLE, "revealed")
		t.equal(Sensors.inSight(sim, 1, 0, 300), true, "sight everywhere")
		t.equal(Sensors.level(sim, 2, owned(sim, 1)[1]), Sensors.Level.HIDDEN, "only for team 1")
		say(sim, 1, "reveal off")
		answers(sim, 1)
		for _ = 1, 2 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, enemy), Sensors.Level.HIDDEN, "hidden again")
	end)

	t.test("god: the sender's units take no damage; kill still works", function()
		local sim = newSim(true)
		say(sim, 1, "give ord_lancer 2 at 0,0")
		say(sim, 2, "give chs_ravager 1 at 200,0")
		say(sim, 1, "god on")
		answers(sim, 1)
		local mine = owned(sim, 1)
		local theirs = owned(sim, 2)[1]
		local h = sim.world.health[mine[1]]
		Combat.queueDamage(sim.combat, mine[1], 50, theirs, 2)
		Combat.queueDamage(sim.combat, theirs, 50, mine[1], 1)
		Sim.step(sim)
		t.equal(sim.world.health[mine[1]], h, "no damage")
		t.expect(sim.world.health[theirs] < sim.defs.units.chs_ravager.health, "the enemy's isn't god")
		say(sim, 1, "kill selected", { mine[1] })
		local a = answers(sim, 1)
		t.equal(a[1].count, 1)
		t.equal(sim.world.slot[mine[1]], nil, "killed through god mode")
		t.equal(sim.world.slot[mine[2]] ~= nil, true)
	end)

	t.test("kill a team, kill an area", function()
		local sim = newSim(true)
		say(sim, 1, "give ord_lancer 4 at 0,0")
		say(sim, 1, "give ord_lancer 3 at 300,300")
		say(sim, 1, "give chs_ravager 3 2 at -300,0")
		answers(sim, 1)
		say(sim, 1, "kill at 300,300 60")
		t.equal(answers(sim, 1)[1].count, 3)
		t.equal(#owned(sim, 1), 4)
		say(sim, 1, "kill 2")
		t.equal(answers(sim, 1)[1].count, 3)
		t.equal(#owned(sim, 2), 0)
		t.equal(#sim.combat.wreckIds, 0, "no wrecks")
	end)

	t.test("speed only offline; ai pause / resume", function()
		local sim = newSim(true)
		say(sim, 1, "speed 4")
		t.equal(answers(sim, 1)[1].cheatResult, R.NOT_OFFLINE)
		t.equal(sim.cheats.speed, 1)
		local off = newSim(true, { offline = true })
		say(off, 1, "speed 4")
		t.equal(answers(off, 1)[1].count, 400)
		t.equal(off.cheats.speed, 4)

		local ai = Sim.new({ seed = 3, players = PLAYERS, mapId = "start:64", scenario = "empty", match = { mode = "FFA", win = "ANNIHILATION", ai = { [2] = "normal" }, cheats = true } })
		Spawn.unit(ai, "chs_warlord", 2, 0, 0)
		Spawn.unit(ai, "ord_sovereign", 1, -100, 0)
		local brain = Skirmish.new(ai, 2)
		say(ai, 1, "ai 1 pause")
		t.equal(answers(ai, 1)[1].cheatResult, R.NO_AI, "team 1 has no AI")
		say(ai, 1, "ai 2 pause")
		answers(ai, 1)
		for _ = 1, 60 do
			Skirmish.tick(brain)
			Sim.step(ai)
		end
		t.equal(#ai.queue, 0, "a paused AI sends nothing")
		local applied = ai.stats.commandsApplied
		say(ai, 1, "ai 2 resume")
		answers(ai, 1)
		for _ = 1, 60 do
			Skirmish.tick(brain)
			Sim.step(ai)
		end
		t.expect(ai.stats.commandsApplied > applied + 1, "resumed: the AI gives orders again")
	end)

	t.test("replays repeat cheats exactly; the header keeps the flags", function()
		local sim = newSim(true)
		say(sim, 1, "give ord_lancer 6 at 0,0")
		say(sim, 2, "give chs_ravager 6 at 150,0")
		say(sim, 1, "god on")
		say(sim, 1, "income supply 50")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		say(sim, 1, "kill at 150,0 40")
		say(sim, 2, "reveal on")
		say(sim, 1, "instabuild on")
		for _ = 1, 300 do
			Sim.step(sim)
		end
		local log = Replay.parse(Replay.serialize(sim.replay))
		t.equal(log.header.cheats, true)
		t.equal(log.header.cheated, true)
		local replayed, mismatch = Sim.runReplay(log, sim.tick)
		t.equal(mismatch, nil, "every checkpoint matches")
		t.equal(Sim.hash(replayed), Sim.hash(sim), "same final state")
		t.equal(#replayed.world.ids, #sim.world.ids)
	end)

	t.test("wire: the CHEAT command and CHEAT_RESULT round-trip; chat text", function()
		local cmd = assert(CheatText.parse("/cheat give ord_lancer 3 2 at -120.4, 33", defs))
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, cmd)
		local back = Schema.decodeCommand(Packer.Reader.new(w:finish()))
		t.equal(back.cheatOp, Schema.CheatOp.GIVE)
		t.equal(back.defIndex, defs.units.ord_lancer.index)
		t.equal(back.amount, 3)
		t.equal(back.cheatTeam, 2)
		t.equal(back.x, -120)
		t.equal(back.z, 33)
		local e = { kind = Schema.EventKind.CHEAT_RESULT, cheatOp = Schema.CheatOp.GIVE, cheatResult = R.OK, count = 2, total = 3 }
		local ew = Packer.Writer.new()
		Schema.encodeEvent(ew, e)
		t.equal(buffer.len(ew:finish()), Schema.EVENT_BYTES[Schema.EventKind.CHEAT_RESULT])
		t.equal(CheatText.describe(e), "give: placed 2 of 3")
		t.equal(CheatText.describe({ kind = 22, cheatOp = Schema.CheatOp.GOD, cheatResult = R.CHEATS_OFF }), "god: cheats are off in this match")
		for _, bad in { "give nothing at 0,0", "res gold 5", "speed 9", "kill", "ai 1 sleep", "fly" } do
			local c, why = CheatText.parse(bad, defs)
			t.equal(c, nil, bad)
			t.expect(why ~= nil, bad)
		end
		t.equal((assert(CheatText.parse("res all max", defs))).amount, Schema.CHEAT_MAX)
		t.equal((assert(CheatText.parse("speed 0.25", defs))).amount, 25)
	end)
end
