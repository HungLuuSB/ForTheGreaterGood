--!strict
-- Idle builders and factories (C-158 on S-136's IDLE events): through the
-- real server, a Mason with nothing to do and a factory with an empty
-- queue count as idle, on camera or not; an order or a queue makes them
-- busy; the cycle walks the idle builders in order and wraps.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local Idle = require("../../src/client/Core/Idle")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

local function scene()
	local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
	local world = World.new(sim.defs)
	local api = Api.new(world, function(p: buffer)
		assert(Sim.submit(sim, 1, p))
	end)
	NetOut.join(sim, 1)
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
	t.test("idle Masons and an empty factory count; orders and queues make them busy; off camera too", function()
		local sim, world, api, step = scene()
		local g = sim.map.layers.grid
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0)
		local m1 = Spawn.unit(sim, "ord_mason", 1, 0, 60, 0)
		local m2 = Spawn.unit(sim, "ord_mason", 1, 30, 60, 0)
		-- the camera over one corner only: the Masons and the plant are off it
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 3, 3)))
		step(20)
		local st = Idle.new()
		Idle.update(st, world)
		t.equal(table.concat(st.builders, ","), `{m1},{m2}`, "both Masons idle, off camera")
		t.equal(table.concat(st.factories, ","), tostring(plant), "the empty plant")
		-- the camera over them, then orders
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		step(3)
		api.actions.select({ plant })
		t.expect(api.actions.queueBuild("ord_lancer", 2))
		api.actions.select({ m1 })
		t.expect(api.actions.smartOrder(-120, 40, nil, false))
		step(5)
		Idle.update(st, world)
		t.equal(table.concat(st.builders, ","), tostring(m2), "m1 moving: busy")
		t.equal(#st.factories, 0, "the plant producing: busy")
		-- the cycle
		t.equal(Idle.next(st, "builder"), m2)
		t.equal(Idle.next(st, "builder"), m2, "one idle builder: it again")
	end)
end
