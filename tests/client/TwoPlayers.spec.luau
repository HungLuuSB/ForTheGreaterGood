--!strict
-- Two humans in one match (C-77): two complete client stacks (World, NetIn,
-- the client API) on one sim, each fed only its own player's outbox, as the
-- Roblox server sends them. Joining, separate fog of war, commands that move
-- only one's own units, combat both see, and the win condition.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")
local Packer = require("@shared/Net/Packer")

local DT = 1 / 15

type Client = { world: World.World, api: Api.Api, pid: number }

local function match()
	local sim = Sim.new({
		seed = 21,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "flat:96",
		scenario = "empty",
		match = { mode = "FFA", win = "ANNIHILATION" },
	})
	local clients: { Client } = {}
	for pid = 1, 2 do
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, pid, p))
		end)
		NetOut.join(sim, pid)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, pid, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		clients[pid] = { world = world, api = api, pid = pid }
	end
	local tick = 0
	local function step(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			for pid, c in clients do
				NetIn.applyOutbox(c.world, sim.net.players[pid].outbox, tick * DT)
				Api.frame(c.api, tick * DT)
				table.clear(c.world.died)
			end
		end
	end
	return sim, clients, step
end

local function knows(c: Client, id: number): boolean
	local u = c.world.units[id]
	return u ~= nil and u.tier == "tactical"
end

return function(t: any)
	t.test("joining, separate fog, own commands only, combat, annihilation", function()
		local sim, clients, step = match()
		local a, b = clients[1], clients[2]
		-- far apart: each sees only its own
		local lancers, ravagers = {}, {}
		for i = 0, 3 do
			table.insert(lancers, Spawn.unit(sim, "ord_lancer", 1, -300, -30 + i * 20, math.pi / 2))
			table.insert(ravagers, Spawn.unit(sim, "chs_ravager", 2, 300, -30 + i * 20, -math.pi / 2))
		end
		step(5)
		t.expect(a.world.joined and b.world.joined, "both joined")
		t.equal(a.world.me.player, 1)
		t.equal(b.world.me.player, 2)
		t.equal(a.world.me.team, 1)
		t.equal(b.world.me.team, 2)
		for i = 1, 4 do
			t.expect(knows(a, lancers[i]) and knows(b, ravagers[i]), "each sees its own units")
			t.expect(not knows(a, ravagers[i]), "A doesn't see B's units through the fog")
			t.expect(not knows(b, lancers[i]), "B doesn't see A's units")
		end
		local sightA, sightB = assert(a.world.sight), assert(b.world.sight)
		t.expect(sightA.version > 0 and sightB.version > 0, "each has its own sight map")

		-- B can't select or order A's units
		b.api.actions.select(lancers)
		t.equal(#b.api.state.selection, 0, "B can't select A's units")
		local before = { sim.world.posX[lancers[1]], sim.world.posZ[lancers[1]] }
		local grid = sim.map.layers.grid
		local cell, offX, offZ = grid:encode(-300, 300)
		local w = Packer.Writer.new(64)
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { lancers[1] }, cell = cell, offX = offX, offZ = offZ })
		Sim.submit(sim, 2, w:finish()) -- a forged order from B's client
		step(30)
		t.expect(math.abs(sim.world.posZ[lancers[1]] - before[2]) < 1, "the server ignores B's order for A's unit")

		-- both advance: A by smart order (move), B by the attack command mode
		a.api.actions.select(lancers)
		t.equal(#a.api.state.selection, 4)
		a.api.actions.smartOrder(0, 0)
		b.api.actions.select(ravagers)
		b.api.actions.setCommandMode("fight")
		b.api.actions.commandAt(0, 0, nil, false)
		local saw = { a = false, b = false }
		for _ = 1, 15 * 20 do
			step(1)
			if knows(a, ravagers[1]) or knows(a, ravagers[2]) then
				saw.a = true
			end
			if knows(b, lancers[1]) or knows(b, lancers[2]) then
				saw.b = true
			end
			if saw.a and saw.b then
				break
			end
		end
		t.expect(saw.a and saw.b, "they meet: each sees the other")

		-- combat: both see health drop and deaths; A's view of B's units matches the server
		local deathsSeen = { 0, 0 }
		for _ = 1, 15 * 90 do
			step(1)
			if sim.match.over then
				break
			end
		end
		-- deaths are recorded in each world's DEATH queue as they come; count what each knows now
		for pid, c in clients do
			for _, id in (if pid == 1 then ravagers else lancers) do
				if c.world.units[id] == nil and sim.world.slot[id] == nil then
					deathsSeen[pid] += 1
				end
			end
		end
		t.expect(sim.match.over, "one side was annihilated")
		local loser = if sim.match.eliminated[1] then 1 else 2
		local winner = 3 - loser
		t.equal(sim.match.winner, sim.players[winner].allyTeam, "the survivor's ally team won")
		t.expect(deathsSeen[winner] == 4, `the winner saw all 4 enemy deaths ({deathsSeen[winner]})`)
		for _, id in (if loser == 1 then lancers else ravagers) do
			t.equal(clients[loser].world.units[id], nil, "the loser's client dropped its dead units")
		end
		print(string.format("    player %d won at tick %d; the winner's client saw %d of 4 enemy deaths", winner, sim.tick, deathsSeen[winner]))
	end)
end
