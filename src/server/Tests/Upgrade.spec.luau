--!strict
-- In-place upgrades (S-108, the user's request): a T2 extractor is built
-- over its own player's T1 extractor, which works on until the T2 is done.
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Build = require("../Sim/Build")
local Combat = require("../Sim/Combat/Combat")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

-- players 1 and 3 are allies (ally team 1), player 2 the enemy
local PLAYERS = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 }, { id = 3, team = 3, allyTeam = 1 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function build(sim: Sim.Sim, player: number, builder: number, defId: string, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = Schema.CmdType.BUILD, flags = 0, unitIds = { builder }, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
end

local function owned(sim: Sim.Sim, player: number, defId: string): { number }
	local out = {}
	local w = sim.world
	for _, id in w.ids do
		if w.owner[id] == player and w.defIndex[id] == sim.defs.units[defId].index then
			table.insert(out, id)
		end
	end
	return out
end

-- start:64 has deposits; the first one, its T1 extractor for `t1Owner`, and
-- an Architect for player 1 beside it, with full stores.
local function setup(seed: number, t1Owner: number?): (Sim.Sim, number, number, number, number?)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "start:64", cheats = true })
	local layers = (sim.map :: any).layers
	local g = layers.grid
	local dx, dz
	for i = 0, g.cellCount - 1 do
		if buffer.readu8(layers.supply, i) > 0 then
			dx, dz = g:cellCenter(g:coords(i))
			break
		end
	end
	assert(dx and dz, "a deposit")
	local t1 = if t1Owner then Spawn.unit(sim, if t1Owner == 2 then "chs_extractor" else "ord_extractor", t1Owner, dx, dz) else nil
	local arch = Spawn.unit(sim, "ord_architect", 1, dx + 40, dz)
	Spawn.unit(sim, "ord_sovereign", 1, dx + 60, dz + 40)
	return sim, arch, dx, dz, t1
end

local function topUp(sim: Sim.Sim)
	for _, team in sim.eco.teams do
		local acc = sim.eco.accounts[team]
		acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
	end
end

local function step(sim: Sim.Sim, n: number)
	for _ = 1, n do
		topUp(sim)
		Sim.step(sim)
	end
end

local function failed(sim: Sim.Sim, n: number): string?
	local why = nil
	for _ = 1, n do
		topUp(sim)
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "BUILD_FAILED" then
				why = tostring(e.reason)
			end
		end
	end
	return why
end

return function(t: RunAll.Context)
	t.test("over its own T1 extractor: the T1 works on until the T2 is finished, then goes", function()
		local sim, arch, dx, dz, t1 = setup(1, 1)
		local t1Id = t1 :: number
		step(sim, 5)
		local acc = sim.eco.accounts[1]
		local t1Rate = acc.supply.income
		build(sim, 1, arch, "ord_advextractor", dx, dz)
		local frame = nil
		local incomeDuring = math.huge
		for _ = 1, 15 * 120 do
			topUp(sim)
			Sim.step(sim)
			frame = frame or owned(sim, 1, "ord_advextractor")[1]
			if frame and sim.world.buildProgress[frame] < 1 then
				incomeDuring = math.min(incomeDuring, acc.supply.income)
				t.equal(World.isAlive(sim.world, t1Id), true, "the T1 stands while the frame is built")
			end
			if frame and sim.world.buildProgress[frame] >= 1 then
				break
			end
		end
		t.expect(frame ~= nil, "the T2 frame started on the T1")
		t.equal(sim.world.buildProgress[frame :: number], 1, "finished")
		t.expect(incomeDuring >= t1Rate - 1e-6, `the T1's income went on during the build ({incomeDuring} of {t1Rate})`)
		t.equal(World.isAlive(sim.world, t1Id), false, "the T1 went when the T2 was done")
		t.equal(#sim.combat.wreckIds, 0, "no wreck")
		step(sim, 6)
		local base = (sim.defs.units.ord_sovereign.production :: any).supply or 0 -- the Command Vehicle's own
		t.expect(acc.supply.income - base > (t1Rate - base) * 3, `the T2 works the deposit ({acc.supply.income - base} against {t1Rate - base})`)
		local pm = sim.map :: Passability.PassMap
		local gx, gz = pm.grid:cellAt(dx, dz)
		t.equal(Passability.occupant(pm, pm.grid:index(gx, gz)), frame, "the deposit cell is the T2's")
	end)

	t.test("not over an enemy's or an ally's extractor; on an empty deposit as usual", function()
		for _, case in { { 2, "occupied" }, { 3, "occupied" } } do
			local sim, arch, dx, dz = setup(2, case[1])
			build(sim, 1, arch, "ord_advextractor", dx, dz)
			t.equal(failed(sim, 15 * 10), case[2], `player {case[1]}'s extractor blocks it`)
			t.equal(#owned(sim, 1, "ord_advextractor"), 0)
		end
		local sim, arch, dx, dz = setup(3, nil)
		build(sim, 1, arch, "ord_advextractor", dx, dz)
		t.equal(failed(sim, 15 * 10), nil)
		t.equal(#owned(sim, 1, "ord_advextractor"), 1, "an empty deposit takes a T2 directly")
		-- other structures still can't go over an extractor
		local sim2, arch2, dx2, dz2 = setup(4, 1)
		build(sim2, 1, arch2, "ord_generator", dx2, dz2)
		t.equal(failed(sim2, 15 * 10), "occupied", "a generator can't")
	end)

	t.test("cancelled or destroyed, the frame leaves the T1 producing on its cells", function()
		for _, how in { "cancel", "destroy" } do
			local sim, arch, dx, dz, t1 = setup(5, 1)
			local t1Id = t1 :: number
			build(sim, 1, arch, "ord_advextractor", dx, dz)
			local frame = nil
			for _ = 1, 15 * 20 do
				step(sim, 1)
				frame = owned(sim, 1, "ord_advextractor")[1]
				if frame then
					break
				end
			end
			assert(frame, "a frame")
			step(sim, 15)
			local pm = sim.map :: Passability.PassMap
			local gx, gz = pm.grid:cellAt(dx, dz)
			local cell = pm.grid:index(gx, gz)
			t.equal(Passability.occupant(pm, cell), frame, "the frame holds the cells while it is built")
			if how == "cancel" then
				submit(sim, 1, { cmdType = Schema.CmdType.CANCEL, flags = 0, unitIds = { frame }, value = 0 })
			else
				Combat.queueDamage(sim.combat, frame, 1e6, 0)
			end
			step(sim, 6)
			t.equal(World.isAlive(sim.world, frame), false, `{how}: the frame is gone`)
			t.equal(World.isAlive(sim.world, t1Id), true, `{how}: the T1 stands`)
			t.equal(Passability.occupant(pm, cell), t1Id, `{how}: the T1 holds its cells again`)
			t.expect(sim.eco.accounts[1].supply.income > 0, `{how}: and produces`)
		end
	end)

	t.test("the T1 destroyed mid-upgrade: the frame stays and finishes", function()
		local sim, arch, dx, dz, t1 = setup(6, 1)
		build(sim, 1, arch, "ord_advextractor", dx, dz)
		local frame = nil
		for _ = 1, 15 * 20 do
			step(sim, 1)
			frame = owned(sim, 1, "ord_advextractor")[1]
			if frame then
				break
			end
		end
		assert(frame, "a frame")
		Combat.queueDamage(sim.combat, t1 :: number, 1e6, 0)
		step(sim, 2)
		t.equal(World.isAlive(sim.world, t1 :: number), false, "the T1 died")
		t.equal(World.isAlive(sim.world, frame), true, "the frame stays")
		for _ = 1, 15 * 120 do
			step(sim, 1)
			if sim.world.buildProgress[frame] >= 1 then
				break
			end
		end
		t.equal(sim.world.buildProgress[frame], 1, "and is finished")
		t.equal(sim.build.upgrading[frame], nil)
		t.expect(Build.finishUpgrade ~= nil)
	end)

	t.test("replays repeat an upgrade exactly", function()
		-- everything through commands (cheats spawn the units), so the replay has it all
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "start:64", cheats = true })
		local layers = (sim.map :: any).layers
		local g = layers.grid
		local dx, dz
		for i = 0, g.cellCount - 1 do
			if buffer.readu8(layers.supply, i) > 0 then
				dx, dz = g:cellCenter(g:coords(i))
				break
			end
		end
		local function cheat(text: string)
			local CheatText = require("@shared/Net/CheatText")
			submit(sim, 1, assert(CheatText.parse(text, sim.defs)))
		end
		cheat(`give ord_extractor 1 at {math.floor(dx)},{math.floor(dz)}`)
		cheat(`give ord_architect 1 at {math.floor(dx) + 40},{math.floor(dz)}`)
		cheat("res all max")
		cheat("income supply 200")
		cheat("income power 2000")
		Sim.step(sim)
		local arch = owned(sim, 1, "ord_architect")[1]
		build(sim, 1, arch, "ord_advextractor", dx, dz)
		for _ = 1, 15 * 90 do
			Sim.step(sim)
		end
		t.equal(#owned(sim, 1, "ord_advextractor"), 1)
		local replayed, mismatch = Sim.runReplay(Replay.parse(Replay.serialize(sim.replay)), sim.tick)
		t.equal(mismatch, nil)
		t.equal(Sim.hash(replayed), Sim.hash(sim))
	end)
end
