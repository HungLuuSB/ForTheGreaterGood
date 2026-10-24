--!strict
-- Order lines last until the order is done (C-193, the user): an assisting
-- builder keeps its line while it stands helping; a build's line stays while
-- its frame goes up and goes when it's finished; units rolled out of a
-- factory take its order list; a turret in the selection takes no move order.
-- Through the real client API and server.

local Api = require("../../src/client/Api")
local BuildTargets = require("../../src/client/Core/BuildTargets")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local CT = Schema.CmdType

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
			sim.eco.accounts[1].supply.stored = 5000
			sim.eco.accounts[1].power.stored = 5000
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			table.clear(world.died)
		end
	end
	return sim, world, api, step
end

local function kinds(api: any, id: number): { number }
	local out = {}
	for _, p in api.waypoints.byUnit[id] or {} do
		table.insert(out, p.kind)
	end
	return out
end

return function(t: any)
	t.test("a build's line stays while its frame goes up, and an assisting builder's while it helps", function()
		local sim, world, api, step = scene()
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0)
		local lead = Spawn.unit(sim, "ord_mason", 1, 0, 0, 0)
		local helper = Spawn.unit(sim, "ord_mason", 1, 20, 0, 0)
		step(3)
		api.actions.select({ lead })
		api.actions.beginPlacement("ord_solar")
		t.expect(api.actions.place(60, 0, false, false))
		api.actions.select({ helper })
		t.expect(api.actions.smartOrder(0, 0, lead, false), "the helper assists the lead")
		-- the frame starts, and both stand working on it for a while
		local building, lines, missed = 0, 0, 0
		local sprayed: { [number]: number } = {}
		local leadKind, helperKind = nil, nil
		for _ = 1, 15 * 30 do
			step(1)
			local going = false
			for _, u in world.units do
				local def = World.def(world, u)
				if def and def.id == "ord_solar" and u.build and u.build < 1 then
					going = true
				end
			end
			if going then
				building += 1
				for _, sp in BuildTargets.list(world, api.waypoints.byUnit, {}) do
					sprayed[sp.builder] = (sprayed[sp.builder] or 0) + 1
				end
				if api.waypoints.byUnit[lead] and api.waypoints.byUnit[helper] then
					lines += 1
					leadKind, helperKind = kinds(api, lead)[1], kinds(api, helper)[1]
				else
					missed += 1
				end
			elseif building > 0 then
				break -- finished
			end
		end
		print(`    the frame went up for {building} frames; both lines drawn for {lines}`)
		t.expect(building > 15 * 2, "the frame took a while")
		t.equal(missed, 0, "both lines stayed the whole time it went up (the old rule dropped them after 2 s still)")
		t.equal(leadKind, CT.BUILD)
		t.equal(helperKind, CT.GUARD, "the assist line")
		print(`    sprays: lead {sprayed[lead] or 0}, helper {sprayed[helper] or 0} of {building} frames`)
		t.expect((sprayed[lead] or 0) > building / 2, "the lead sprays its frame while it builds")
		t.expect((sprayed[helper] or 0) > building / 2, "the helper sprays the lead's frame")
		-- once the solar is finished the lead's line goes; then the server reports it idle
		for _ = 1, 15 * 40 do
			step(1)
			if api.waypoints.byUnit[lead] == nil then
				break
			end
		end
		t.equal(api.waypoints.byUnit[lead], nil, "the build line went once the solar was finished")
	end)

	t.test("units rolled out of a factory take its order list", function()
		local sim, world, api, step = scene()
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		step(3)
		api.actions.select({ plant })
		t.expect(api.actions.smartOrder(200, 120, nil, false), "a rally move for its units")
		t.expect(api.actions.queueBuild("ord_lancer", 1))
		local made = nil
		for _ = 1, 15 * 60 do
			step(1)
			for id, u in world.units do
				local def = World.def(world, u)
				if def and def.id == "ord_lancer" and u.team == 1 then
					made = id
				end
			end
			if made then
				break
			end
		end
		t.expect(made ~= nil, "a Lancer rolled out")
		step(2)
		local list = api.waypoints.byUnit[made :: number]
		t.expect(list ~= nil and list[1].kind == CT.MOVE and math.abs(list[1].x - 200) < 20, "it has the factory's move line")
		t.expect(api.waypoints.byUnit[plant] ~= nil, "the factory keeps its list")
	end)

	t.test("a turret in the selection takes no move order and draws no move line", function()
		local sim, _, api, step = scene()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local turret = Spawn.unit(sim, "ord_bulwark", 1, 40, 0, 0)
		step(3)
		api.actions.select({ lancer, turret })
		t.expect(api.actions.smartOrder(150, 100, nil, false))
		step(1)
		t.expect(api.waypoints.byUnit[lancer] ~= nil, "the tank moves")
		t.equal(api.waypoints.byUnit[turret], nil, "the turret has no move line")
		t.equal(sim.orders.queue[turret], nil, "and the server got no move for it")
	end)

	t.test("another builder's planned build counts as taken (C-193)", function()
		local sim, _, api, step = scene()
		local a = Spawn.unit(sim, "ord_mason", 1, 0, 0, 0)
		local b = Spawn.unit(sim, "ord_mason", 1, -150, 0, 0)
		step(3)
		api.actions.select({ a })
		api.actions.beginPlacement("ord_solar")
		t.expect(api.actions.place(120, 80, false, false), "A plans a solar")
		step(2)
		api.actions.select({ b })
		api.actions.beginPlacement("ord_solar")
		local ok, why = api.actions.updatePlacement(120, 80)
		t.expect(not ok, "B can't place on A's plan")
		t.equal(why, "occupied")
		local ok2 = api.actions.updatePlacement(200, -80)
		t.expect(ok2, "elsewhere is fine")
		api.actions.cancelPlacement()
	end)
end
