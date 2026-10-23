--!strict
-- Builders assist (C-163, BAR's assist): right-clicking an own factory with
-- builders selected makes them help its production (REPAIR), while other
-- selected units guard it; right-clicking an own builder makes builders
-- follow its lead and help whatever it builds (GUARD, S-128). Through the
-- real client API and server.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Orders = require("../../src/client/Core/Orders")
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
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			table.clear(world.died)
		end
	end
	return sim, world, api, step
end

return function(t: any)
	t.test("right-click an own factory: builders assist its production, tanks guard it", function()
		local sim, world, api, step = scene()
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0)
		local mason = Spawn.unit(sim, "ord_mason", 1, 60, 60, 0)
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 40, 60, 0)
		step(3)
		api.actions.select({ plant })
		t.expect(api.actions.queueBuild("ord_lancer", 3))
		step(2)
		local parts = Orders.smartFor(world, 100, 0, plant, false, { mason, lancer })
		t.equal(#parts, 2)
		t.equal(parts[1].intent.cmdType, CT.REPAIR)
		t.equal(parts[1].ids[1], mason)
		t.equal(parts[2].intent.cmdType, CT.GUARD)
		t.equal(parts[2].ids[1], lancer)
		api.actions.select({ mason, lancer })
		t.expect(api.actions.smartOrder(100, 0, plant, false))
		step(3)
		t.equal(sim.build.target[mason], plant, "the Mason works on the factory")
		t.equal(sim.build.assist[mason], true, "assisting its production")
	end)

	t.test("right-click an own builder: builders follow its lead", function()
		local _sim, world, _api, _step = scene()
		local leader, helper = 1001, 1002
		local def = world.defs.units.ord_mason
		for _, id in { leader, helper } do
			world.units[id] = { id = id, tier = "tactical", team = world.me.team, defIndex = def.index, x = id, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {}, build = 1, health = 1 } :: any
		end
		local parts = Orders.smartFor(world, 0, 0, leader, false, { helper })
		t.equal(#parts, 1)
		t.equal(parts[1].intent.cmdType, CT.GUARD, "guard = assist for builders (S-128)")
	end)
end
