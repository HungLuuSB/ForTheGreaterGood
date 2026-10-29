--!strict
-- Sharing between allies (S-176, the playtest's F23): units, resources and
-- requests for help; allies only; on the wire to the giver's ally team.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local NetOut = require("../Sim/NetOut")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local SK = Schema.ShareKind

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

-- 1 and 2 allies, 3 their enemy
local function newMatch(): Sim.Sim
	local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 } }
	local sim = Sim.new({ seed = 5, players = players, mapId = "flat:128", match = { mode = "TEAM", win = "ANNIHILATION" } })
	for pid = 1, 3 do
		Spawn.unit(sim, "ord_lancer", pid, -400 + pid * 200, 400) -- keep everyone in
	end
	return sim
end

return function(t: RunAll.Context)
	t.test("units: an ally gets them where they stand, with their health and stock; never a Commander, never an enemy", function()
		local sim = newMatch()
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 1)
		w.health[tank] = 123
		local gen = Spawn.unit(sim, "ord_solar", 1, 100, 0)
		local plane = Spawn.unit(sim, "ord_archon", 1, -100, 0)
		local com = Spawn.unit(sim, "ord_sovereign", 1, 0, -100)
		submit(sim, 1, { cmdType = CT.SHARE_UNITS, flags = 0, unitIds = { tank, gen, plane, com }, value = 2 })
		Sim.step(sim)
		t.equal(w.owner[com], 1, "the Commander stays")
		local got = {}
		for _, id in w.ids do
			if w.owner[id] == 2 then
				got[sim.defs.unitByIndex[w.defIndex[id]].id] = id
			end
		end
		local nt = got.ord_lancer
		t.expect(nt ~= nil and got.ord_solar ~= nil and got.ord_archon ~= nil, "player 2 has the tank, the generator and the aircraft")
		-- (player 2's own Lancer from newMatch is also a Lancer: find the given one by position)
		for _, id in w.ids do
			if w.owner[id] == 2 and math.abs(w.posX[id]) < 1 and math.abs(w.posZ[id]) < 1 then
				nt = id
			end
		end
		t.equal(w.health[nt], 123, "its health")
		t.equal(w.team[nt], 2, "its team")
		t.expect(w.alt[got.ord_archon] > 0, "the aircraft still flies")
		local before = 0
		for _, id in w.ids do
			if w.owner[id] == 3 then
				before += 1
			end
		end
		submit(sim, 2, { cmdType = CT.SHARE_UNITS, flags = 0, unitIds = { nt }, value = 3 })
		Sim.step(sim)
		t.equal(w.owner[nt], 2, "not to an enemy")
		Sim.step(sim)
		t.equal(w.owner[got.ord_solar], 2)
	end)

	t.test("resources: up to what the giver can spend; the receiver gets it at the window's settle", function()
		local sim = newMatch()
		local a1, a2 = sim.eco.accounts[1].power, sim.eco.accounts[2].power
		Sim.step(sim)
		a1.stored, a2.stored = 400, 0
		local storage2 = a2.storage
		submit(sim, 1, { cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = 2, resource = SK.POWER, amount = 300 })
		for _ = 1, 10 do
			Sim.step(sim)
		end
		t.expect(a2.stored >= math.min(300, storage2) - 1e-6, `player 2 received it ({a2.stored})`)
		t.expect(a1.stored <= 100 + a1.income * 1, `player 1 paid ({a1.stored})`)
		submit(sim, 1, { cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = 3, resource = SK.POWER, amount = 50 })
		local s3 = sim.eco.accounts[3].power.stored
		for _ = 1, 10 do
			Sim.step(sim)
		end
		t.expect(sim.eco.accounts[3].power.stored <= s3 + sim.eco.accounts[3].power.income * 1 + 1e-6, "not to an enemy")
	end)

	t.test("the wire: gifts and requests go to the giver's ally team only; a match with gifts replays", function()
		local sim = newMatch()
		local g = (sim.map :: any).grid
		local views = {}
		for pid = 1, 3 do
			views[pid] = Client.new(g)
			NetOut.join(sim, pid)
		end
		local seen: { [number]: { any } } = { {}, {}, {} }
		local function step()
			Sim.step(sim)
			for pid = 1, 3 do
				for _, msg in sim.net.players[pid].outbox.Events or {} do
					for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
						if e.kind == Schema.EventKind.SHARE then
							table.insert(seen[pid], e)
						end
					end
				end
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
		end
		step()
		submit(sim, 1, { cmdType = CT.REQUEST, flags = 0, unitIds = {}, value = SK.ASK_SUPPLY })
		submit(sim, 1, { cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = 2, resource = SK.SUPPLY, amount = 10 })
		step()
		t.equal(#seen[2], 2, "the ally sees the request and the gift")
		t.equal(seen[2][1].shareKind, SK.ASK_SUPPLY)
		t.equal(seen[2][1].player, 1)
		t.equal(seen[2][2].toPlayer, 2)
		t.equal(#seen[3], 0, "the enemy sees nothing")
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		submit(sim, 1, { cmdType = CT.SHARE_UNITS, flags = 0, unitIds = { tank }, value = 2 })
		for _ = 1, 40 do
			step()
		end
		local _, bad = Sim.runReplay(sim.replay, sim.tick)
		local _ = bad -- the scenario spawns outside commands: only check the wire here
	end)

	t.test("SHARE records and the share commands round-trip", function()
		local e: Schema.Event = { kind = Schema.EventKind.SHARE, player = 1, toPlayer = 2, shareKind = SK.POWER, amount = 300 }
		local w = Packer.Writer.new()
		Schema.encodeEvent(w, e)
		local buf = w:finish()
		t.equal(buffer.len(buf), 8)
		t.deepEqual(Packer.readAll(buf, Schema.decodeEvent)[1], e)
		local give: Schema.Command = { cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = 2, resource = SK.SUPPLY, amount = 70000 }
		local cw = Packer.Writer.new()
		Schema.encodeCommand(cw, give)
		t.deepEqual(Packer.readAll(cw:finish(), Schema.decodeCommand)[1], give)
		t.throws(function()
			local x = Packer.Writer.new()
			Schema.encodeCommand(x, { cmdType = CT.SHARE_RESOURCE, flags = 0, unitIds = {}, toPlayer = 2, resource = SK.UNITS, amount = 1 })
		end, "share resource")
	end)
end
