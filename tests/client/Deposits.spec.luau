--!strict
-- Supply deposits as the client shows them (C-123): the list, who holds
-- each (an extractor over it, an enemy's structure, nobody), the look
-- picked from the cell, and the overlay's yield text.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local Deposits = require("../../src/client/Core/Deposits")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Lifecycle = require("../../src/server/Sim/Lifecycle")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("holders: own extractor, an enemy's, free; a removed extractor frees it", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:48", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local api = Api.new(world, function(payload: buffer)
			assert(Sim.submit(sim, 1, payload))
		end)
		local grid = (sim.map :: any).grid
		api.send(Commands.camera(0, 0, grid.cellsX - 1, grid.cellsZ - 1))
		local tick = 0
		local function run(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				table.clear(world.entered)
				table.clear(world.left)
				table.clear(world.died)
				Api.frame(api, tick * DT)
			end
		end
		run(2)
		local list = Deposits.list(world.layers :: any)
		t.expect(#list >= 8, `the start map's deposits ({#list})`)
		for _, d in list do
			t.expect(d.supply > 0, "each has a value")
		end
		local mine = Spawn.unit(sim, "ord_extractor", 1, list[1].x, list[1].z)
		-- an enemy structure the player sees, next to its own (sight)
		Spawn.unit(sim, "ord_mason", 1, list[2].x + 10, list[2].z)
		Spawn.unit(sim, "chs_extractor", 2, list[2].x, list[2].z)
		run(3)
		local holders = Deposits.holders(world, list)
		t.expect(holders[1] and holders[1].team == world.me.team and not holders[1].ghost, "the own extractor holds the first")
		t.expect(holders[2] and holders[2].team ~= world.me.team, "the enemy's holds the second")
		local free = 0
		for k = 3, #list do
			if holders[k] == nil then
				free += 1
			end
		end
		t.equal(free, #list - 2, "the rest are free")
		Lifecycle.remove(sim, mine)
		run(15) -- its strategic record goes at the next strategic refresh
		t.equal(Deposits.holders(world, list)[1], nil, "free again once the extractor is gone")
	end)

	t.test("the look comes from the cell; the yield text from the extractor in hand", function()
		local d = { cell = 0, cx = 12, cz = 30, x = 0, z = 0, supply = 4 }
		local v1, r1 = Deposits.look(d, 3)
		local v2, r2 = Deposits.look(d, 3)
		t.expect(v1 == v2 and r1 == r2, "the same every time")
		t.expect(v1 >= 1 and v1 <= 3 and r1 >= 0 and r1 < 360, "a variant and a yaw")
		local seen = {}
		for cx = 0, 40 do
			seen[(Deposits.look({ cell = 0, cx = cx, cz = 7, x = 0, z = 0, supply = 1 }, 3))] = true
		end
		t.expect(seen[1] and seen[2] and seen[3], "every variant gets used")
		t.equal(Deposits.yieldText(d, 0.5), "+2.0", "a T1 extractor's take")
		t.equal(Deposits.yieldText(d, nil), "4", "the value without one")
	end)
end
