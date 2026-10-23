--!strict
-- A factory still being built takes a queue (S-138, client request 63):
-- through the real client API and server, the build menu's queue on a
-- frame reaches the server and comes back as the frame's queue. And Ctrl
-- moves carry the GROUP flag (S-137, C-169) on moves, fights and patrols
-- only.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Orders = require("../../src/client/Core/Orders")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local CT = Schema.CmdType

return function(t: any)
	t.test("queueing in a factory frame: the server takes it and the frame shows it", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 } }, mapId = "start:48", scenario = "standard_start" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		api.send(Commands.camera(0, 0, 47, 47))
		local tick = 0
		local function run(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				table.clear(world.died)
				Api.frame(api, tick * DT)
			end
		end
		run(3)
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		t.expect(api.actions.beginPlacement("ord_vehplant"))
		local u = world.units[cv]
		t.expect(api.actions.place(u.x + 70, u.z, false, false))
		local frame
		for _ = 1, 15 * 30 do
			run(1)
			for id, w in world.units do
				local d = World.def(world, w)
				if d and d.id == "ord_vehplant" and w.build and w.build < 1 then
					frame = id
				end
			end
			if frame then
				break
			end
		end
		t.expect(frame ~= nil, "a plant frame is going up")
		api.actions.select({ frame })
		t.expect(api.actions.queueBuild("ord_lancer", 2))
		run(3)
		t.equal(#(sim.build.queue[frame] or {}), 2, "the server took the queue on the frame")
		t.equal(#(world.units[frame].queue or {}), 2, "and the client shows it")
		t.expect((world.units[frame].build or 1) < 1, "still a frame")
	end)

	t.test("Ctrl moves carry GROUP; other commands don't", function()
		local world = World.new(require("@shared/Defs/Defs").load())
		local function flags(intent: any): number
			local buf = Orders.encode(world, intent, { 1 })[1]
			return Schema.decodeCommand(Packer.Reader.new(buf)).flags
		end
		local G = Schema.CmdFlag.GROUP
		t.expect(bit32.band(flags({ cmdType = CT.MOVE, queue = false, x = 10, z = 10, group = true }), G) ~= 0, "move")
		t.expect(bit32.band(flags({ cmdType = CT.FIGHT, queue = true, x = 10, z = 10, group = true }), G) ~= 0, "fight, queued")
		t.expect(bit32.band(flags({ cmdType = CT.PATROL, queue = false, x = 10, z = 10, group = true }), G) ~= 0, "patrol")
		t.equal(bit32.band(flags({ cmdType = CT.MOVE, queue = false, x = 10, z = 10 }), G), 0, "no Ctrl")
		t.equal(bit32.band(flags({ cmdType = CT.ATTACK, queue = false, targetId = 2, group = true }), G), 0, "attack ignores it")
	end)
end
