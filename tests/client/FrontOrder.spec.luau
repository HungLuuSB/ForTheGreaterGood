--!strict
-- Space held (FRONT, protocol 40, S-199, the user's QoL): an order goes to
-- the head of the queue and the one under way resumes after it, on the
-- server and in the client's drawn order line.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("Space: the new order first, the one under way after it (S-199)", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local sent: { buffer } = {}
		local api = Api.new(world, function(p: buffer)
			table.insert(sent, p)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local tank = Spawn.unit(sim, "ord_lancer", 1, -200, 0, math.pi / 2)
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				Api.frame(api, tick * DT)
			end
		end
		step(3)
		api.actions.select({ tank })
		t.expect(api.actions.smartOrder(200, 0, nil, false, false), "a long move east")
		step(15)
		-- Space held: a detour north first
		api.state.front = true
		t.expect(api.actions.smartOrder(-150, 150, nil, false, false), "a FRONT move")
		api.state.front = false
		local last = sent[#sent]
		local cmd = Schema.decodeCommand(require("@shared/Net/Packer").Reader.new(last))
		t.expect(bit32.band(cmd.flags, Schema.CmdFlag.FRONT) ~= 0, "sent with FRONT")
		local line = api.waypoints.byUnit[tank]
		t.expect(line ~= nil and #line == 2, `the drawn line: the detour, then the move under way ({line and #line})`)
		t.expect(line ~= nil and line[1].x == -150 and line[2].x == 200, "in that order")
		-- the server: north first, then on east
		local reachedNorth, thenEast = false, false
		for _ = 1, 15 * 60 do
			step(1)
			local x, z = sim.world.posX[tank], sim.world.posZ[tank]
			if not reachedNorth and math.abs(x + 150) < 12 and math.abs(z - 150) < 12 then
				reachedNorth = true
			end
			if reachedNorth and x > 150 then
				thenEast = true
				break
			end
		end
		t.expect(reachedNorth, "it went to the detour first")
		t.expect(thenEast, "then resumed the move east")
	end)
end
