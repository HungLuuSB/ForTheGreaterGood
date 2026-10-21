--!strict
-- Client robustness (C-78): a client that joins late, one that drops and
-- rejoins with a fresh client (Roblox can't reconnect a client, a new one
-- joins: S-2's reconnect), and a match restart (a new sim, the same
-- client), each checked against the server's own view: the units it shows
-- in detail, their health, the sight map, and nothing left from before.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")

local DT = 1 / 15

local function newSim(seed: number, mapId: string): any
	return Sim.new({
		seed = seed,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = mapId,
		scenario = "standard_start",
		match = { mode = "FFA", win = "ANNIHILATION", ai = { [2] = "normal" } },
	})
end

type Client = { world: World.World, api: Api.Api }

local function connect(sim: any, pid: number): Client
	local world = World.new(sim.defs)
	local api = Api.new(world, function(p: buffer)
		Sim.submit(sim, pid, p)
	end)
	NetOut.join(sim, pid)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, pid, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	return { world = world, api = api }
end

local function feed(c: Client, sim: any, pid: number, now: number)
	NetIn.applyOutbox(c.world, sim.net.players[pid].outbox, now)
	Api.frame(c.api, now)
	table.clear(c.world.died)
end

-- How far a client's view is from the server's: units the server shows the
-- player in detail that the client lacks or has extra, and the worst
-- health difference.
local function diff(c: Client, sim: any, pid: number): (number, number, number)
	local pn = sim.net.players[pid]
	local want: { [number]: boolean } = {}
	for _, id in pn.tacticalList do
		want[id] = true
	end
	local missing, extra, worstHealth = 0, 0, 0
	for id in want do
		local u = c.world.units[id]
		if u == nil or u.tier ~= "tactical" then
			missing += 1
		elseif u.health then
			local d = sim.defs.unitByIndex[sim.world.defIndex[id]]
			worstHealth = math.max(worstHealth, math.abs(u.health - sim.world.health[id] / d.health))
		end
	end
	for id, u in c.world.units do
		if u.tier == "tactical" and not want[id] then
			extra += 1
		end
	end
	return missing, extra, worstHealth
end

return function(t: any)
	t.test("a client joining a running match matches the server's view", function()
		local sim = newSim(4, "map:crossroads")
		local brains = Skirmish.forMatch(sim)
		local a = connect(sim, 1)
		local tick = 0
		local function step(clients: { [number]: Client })
			tick += 1
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			for pid, c in clients do
				feed(c, sim, pid, tick * DT)
			end
		end
		for _ = 1, 15 * 30 do
			step({ [1] = a })
		end
		-- player 2's seat is the AI's here; a late human client for it
		-- watches its units like a rejoin would
		local late = connect(sim, 2)
		for _ = 1, 5 do
			step({ [1] = a, [2] = late })
		end
		t.expect(late.world.joined, "joined")
		t.equal(late.world.me.player, 2)
		local missing, extra, worst = diff(late, sim, 2)
		t.equal(missing, 0, "every unit the server shows")
		t.equal(extra, 0, "nothing else")
		t.expect(worst <= 1 / 255 + 1e-9, `health within the wire's step ({worst})`)
		t.expect(late.world.sight ~= nil and (late.world.sight :: any).version > 0, "the sight map arrived whole")
		local m1, e1 = diff(a, sim, 1)
		t.expect(m1 == 0 and e1 == 0, "the first client is unaffected")
	end)

	t.test("a dropped client rejoins with a fresh client: the same view as the server, the camera kept", function()
		local sim = newSim(8, "map:crossroads")
		local brains = Skirmish.forMatch(sim)
		local a = connect(sim, 1)
		local tick = 0
		local function step(c: Client?)
			tick += 1
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			if c then
				feed(c, sim, 1, tick * DT)
			end
		end
		for _ = 1, 15 * 20 do
			step(a)
		end
		local mine = #a.world.units
		local _ = mine
		-- the connection drops: the server runs on and the outbox goes nowhere
		for _ = 1, 15 * 15 do
			step(nil)
		end
		-- a new client process joins as the same player: HELLO → NetOut.join (a reconnect keeps the camera)
		local back = World.new(sim.defs)
		local api = Api.new(back, function(p: buffer)
			Sim.submit(sim, 1, p)
		end)
		NetOut.join(sim, 1)
		local again: Client = { world = back, api = api }
		for _ = 1, 4 do
			step(again)
		end
		t.expect(back.joined, "rejoined")
		local missing, extra, worst = diff(again, sim, 1)
		t.equal(missing, 0, "every unit the server shows, with no CAMERA sent again")
		t.equal(extra, 0)
		t.expect(worst <= 1 / 255 + 1e-9, `health within the wire's step ({worst})`)
		t.expect(back.economy ~= nil, "the economy arrived")
		-- and it plays on: an order works
		local own = World.ownIds(back)
		t.expect(#own >= 1, "own units")
		api.actions.select(own)
		t.expect(api.actions.smartOrder(0, 0), "an order goes out")
	end)

	t.test("a match restart on a new sim and map: nothing left from the old match", function()
		local sim1 = newSim(2, "map:crossroads")
		local c = connect(sim1, 1)
		for tick = 1, 15 * 10 do
			Sim.step(sim1)
			feed(c, sim1, 1, tick * DT)
		end
		local old = {}
		for id in c.world.units do
			table.insert(old, id)
		end
		t.expect(#old >= 1, "the first match's units")
		c.api.actions.select(World.ownIds(c.world))
		t.expect(#c.api.state.selection >= 1, "something selected")
		local oldTick = c.world.latestTick
		-- the server starts a new match (Main.startMatch): a new sim, a fresh view for every joined player
		local sim2 = Sim.new({ seed = 3, players = { { id = 1, team = 2 }, { id = 2, team = 1 } }, mapId = "map:ridgeline", scenario = "standard_start" })
		NetOut.join(sim2, 1, true)
		local g = sim2.map.layers.grid
		Sim.submit(sim2, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1))
		for tick = 1, 10 do
			Sim.step(sim2)
			feed(c, sim2, 1, (15 * 10 + tick) * DT)
		end
		t.equal(c.world.mapId, "map:ridgeline", "the new map")
		t.equal(c.world.me.team, 2, "the new team")
		t.expect(c.world.latestTick < oldTick, "ticks restart with the new sim")
		local missing, extra = diff(c, sim2, 1)
		t.equal(missing, 0, "the new match's units")
		t.equal(extra, 0, "none of the old")
		t.equal(#c.api.state.selection, 0, "the old selection is gone")
	end)
end
