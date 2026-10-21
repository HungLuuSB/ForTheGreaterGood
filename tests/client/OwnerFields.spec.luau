--!strict
-- Request 36 (S-61, protocol 20, C-75): the client's view of its own units'
-- factory queues, fire / move states and ammo matches the server's on every
-- tick, through the real NetOut → NetIn path and the client API.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Stockpile = require("../../src/server/Sim/Stockpile")

local DT = 1 / 15

local function scene()
	local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
	local world = World.new(sim.defs)
	local api = Api.new(world, function(p: buffer)
		assert(Sim.submit(sim, 1, p))
	end)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local tick = 0
	local function step(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			table.clear(world.died)
		end
	end
	return sim, world, api, step
end

local function same(a: { number }?, b: { number }?): boolean
	if a == nil or b == nil then
		return a == b
	end
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

return function(t: any)
	t.test("factory queue: the client's equals the server's every tick, through production and CANCEL", function()
		local sim, world, api, step = scene()
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0) -- power for production
		step(3)
		api.actions.select({ plant })
		t.expect(api.actions.queueBuild("ord_lancer", 2))
		t.expect(api.actions.queueBuild("ord_herald", 1))
		t.equal(api.state.factoryQueues[plant], nil, "nothing guessed before the server says")
		local ticks, mismatches, worstProgress, produced = 0, 0, 0, 0
		local lastLen = 3
		for _ = 1, 15 * 150 do
			step(1)
			ticks += 1
			local server = sim.build.queue[plant]
			local client = api.state.factoryQueues[plant]
			if not same(client, server) then
				mismatches += 1
			end
			local u = world.units[plant]
			if server and #server > 0 and u and u.queueProgress then
				worstProgress = math.max(worstProgress, math.abs(u.queueProgress - (sim.build.progress[plant] or 0)))
			end
			if server and #server < lastLen then
				produced += lastLen - #server
				lastLen = #server
			end
			if produced >= 2 then
				break
			end
		end
		t.equal(mismatches, 0, `queue differed on {mismatches} of {ticks} ticks`)
		t.expect(produced >= 2, `two items produced ({produced})`)
		-- progress goes out by sixteenths (Stockpile.WIRE_STEPS), to a 255th
		t.expect(worstProgress <= 1 / Stockpile.WIRE_STEPS + 1 / 255, `head progress off by {worstProgress}`)
		api.actions.cancel(0)
		step(2)
		t.expect(same(api.state.factoryQueues[plant], sim.build.queue[plant]), "after CANCEL")
		t.equal(#api.state.factoryQueues[plant], 0, "emptied")
		print(string.format("    %d ticks, queue identical on all; head progress within %.3f", ticks, worstProgress))
	end)

	t.test("fire and move states: the server's, after each command, for the selection", function()
		local sim, world, api, step = scene()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		step(3)
		local u = assert(world.units[lancer])
		t.equal(u.fireState, sim.world.fireState[lancer], "fire state with the ENTER")
		t.equal(u.moveState, sim.world.moveState[lancer], "move state with the ENTER")
		api.actions.select({ lancer })
		step(1)
		t.equal(api.state.fireState, sim.world.fireState[lancer])
		for _, fs in { 0, 1, 2, 0 } do
			api.actions.setFireState(fs)
			api.actions.setMoveState(2 - fs)
			step(2)
			t.equal(sim.world.fireState[lancer], fs, "the server took it")
			t.equal(u.fireState, sim.world.fireState[lancer], `fire state {fs}`)
			t.equal(u.moveState, sim.world.moveState[lancer], `move state {2 - fs}`)
			t.equal(api.state.fireState, fs, "the command card reads the server's")
			t.equal(api.state.moveState, 2 - fs)
		end
		api.actions.select({})
		step(1)
		t.equal(api.state.fireState, nil, "nothing selected: no state")
	end)

	t.test("ammo: an aircraft's rounds follow the server's", function()
		local sim, world, _api, step = scene()
		local bomber = Spawn.unit(sim, "ord_absolution", 1, 0, 0, 0)
		step(3)
		local u = assert(world.units[bomber])
		local max = sim.defs.units.ord_absolution.ammo
		t.equal(u.ammo, sim.air.ammo[bomber], "full with the ENTER")
		t.equal(u.maxAmmo, max)
		for _, rounds in { max - 1, 1, 0, max } do
			sim.air.ammo[bomber] = rounds
			step(1)
			t.equal(u.ammo, sim.air.ammo[bomber], `{rounds} rounds`)
		end
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 40, 0, 0)
		step(2)
		t.equal((world.units[lancer] :: any).ammo, nil, "no ammo for units without an ammo count")
	end)

	t.test("countermeasure charges (protocol 21): flares and chaff left follow the server's", function()
		local sim, world, _api, step = scene()
		local harpy = Spawn.unit(sim, "chs_harpy", 1, 0, 0, 0) -- flares and chaff
		step(3)
		local u = assert(world.units[harpy])
		local cm = sim.defs.units.chs_harpy.countermeasures
		t.equal(u.flares, cm.flares.charges, "full flares with the ENTER")
		t.equal(u.chaff, cm.chaff.charges, "full chaff")
		for _, left in { 3, 0, 1 } do
			sim.ew.flares[harpy], sim.ew.chaff[harpy] = left, 2
			step(1)
			t.equal(u.flares, sim.ew.flares[harpy], `{left} flares`)
			t.equal(u.chaff, sim.ew.chaff[harpy])
		end
	end)
end
