--!strict
-- The extractor hint on a free deposit (C-244, the user's QoL): hovering
-- one with builders selected names the extractor they'd put there (T1 for a
-- Commander or T1 builder, T2 for a T2 builder) and its spot; a right-click
-- orders it, as the server takes it.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("a free deposit under the mouse: the selected builders' extractor, ordered with a right-click (C-244)", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "map:ridgeline", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local d = sim.map.layers.deposits[1]
		local cmd = Spawn.unit(sim, "ord_sovereign", 1, d[1] + 40, d[2], 0)
		local architect = Spawn.unit(sim, "ord_architect", 1, d[1] - 40, d[2], 0)
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
		-- nothing selected: no hint
		t.equal(api.actions.depositHintAt(d[1], d[2]), nil, "no builder selected")
		-- the Commander: a T1 extractor on the deposit
		api.actions.select({ cmd })
		local h = api.actions.depositHintAt(d[1] + 3, d[2] - 2)
		t.expect(h ~= nil and h.defId == "ord_extractor", `the Commander's T1 extractor ({h and h.defId})`)
		t.expect(h ~= nil and math.abs(h.x - d[1]) <= 8 and math.abs(h.z - d[2]) <= 8, "on the deposit")
		-- a T2 builder: the advanced one
		api.actions.select({ architect })
		local h2 = api.actions.depositHintAt(d[1], d[2])
		t.expect(h2 ~= nil and h2.defId == "ord_advextractor", `the T2 builder's T2 extractor ({h2 and h2.defId})`)
		-- away from any deposit: none
		t.equal(api.actions.depositHintAt(d[1] + 200, d[2] + 200), nil, "no deposit there")
		-- the right-click: the Commander builds it
		api.actions.select({ cmd })
		api.state.depositHint = api.actions.depositHintAt(d[1], d[2])
		t.expect(api.actions.buildHint(false), "ordered")
		local built = nil
		for _ = 1, 15 * 20 do
			step(1)
			for id, u in world.units do
				local def = World.def(world, u)
				if def and def.id == "ord_extractor" and u.team == 1 then
					built = id
				end
			end
			if built then
				break
			end
		end
		t.expect(built ~= nil, "the extractor's frame stands on the deposit")
		-- taken: no hint on it any more
		t.equal(api.actions.depositHintAt(d[1], d[2]), nil, "an own extractor there: no hint")
	end)
end
