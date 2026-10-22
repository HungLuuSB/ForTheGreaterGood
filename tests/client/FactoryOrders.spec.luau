--!strict
-- Orders for the units a factory builds (C-111, sim S-95): a move then a
-- shift-queued patrol sent to a factory the way the client sends them
-- (Orders.encode) reach each unit it produces, in order.

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

return function(t: any)
	t.test("a factory's move then queued patrol go to the unit it builds, in order", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -80, 0, 0)
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			end
		end
		step(3)
		local function send(intent: any)
			for _, payload in Orders.encode(world, intent, { plant }) do
				assert(Sim.submit(sim, 1, payload))
			end
		end
		send({ cmdType = CT.MOVE, queue = false, x = 120, z = 0 })
		send({ cmdType = CT.PATROL, queue = true, x = 120, z = 100 })
		send({ cmdType = CT.BUILD, queue = true, defIndex = sim.defs.units.ord_lancer.index, x = 0, z = 0, facing = 0 })
		local before = {}
		for _, id in sim.world.ids do
			before[id] = true
		end
		local lancer
		for _ = 1, 15 * 60 do
			step(1)
			for _, id in sim.world.ids do
				if not before[id] and sim.world.defIndex[id] == sim.defs.units.ord_lancer.index and (sim.world.build == nil or (sim.world.build[id] or 1) >= 1) then
					lancer = id
				end
			end
			if lancer then
				break
			end
		end
		t.expect(lancer ~= nil, "the plant built a Lancer")
		step(2)
		local q = sim.orders.queue[lancer :: number] or {}
		local kinds = {}
		for _, o in q do
			table.insert(kinds, o.kind)
		end
		local s = table.concat(kinds, ",")
		t.expect(string.find(s, "move") ~= nil and string.find(s, "patrol") ~= nil, `its orders: {s}`)
		t.expect((string.find(s, "move", 1, true) :: number) < (string.find(s, "patrol", 1, true) :: number), "move first, then patrol")
	end)
end
