--!strict
-- Own units out of the camera area (C-161): when the camera moves away,
-- the strategic record keeps the unit's type (so it stays drawn, its build
-- menu and command card stay), its exact spot while it stays in its cell,
-- and its heading and health; radar contacts stay typeless. Through the
-- real NetOut → NetIn path.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("an own Mason off camera keeps its type, spot, heading and health", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		local mason = Spawn.unit(sim, "ord_mason", 1, -150, -150, 1.2)
		local mx, mz = sim.world.posX[mason], sim.world.posZ[mason]
		local cx, cz = g:cellAt(mx, mz)
		-- the camera over the Mason
		assert(Sim.submit(sim, 1, Commands.camera(cx - 3, cz - 3, cx + 3, cz + 3)))
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				table.clear(world.died)
				table.clear(world.entered)
				table.clear(world.left)
			end
		end
		step(10)
		local u = assert(world.units[mason])
		t.equal(u.tier, "tactical")
		local heading, health = u.heading, u.health
		-- the camera far away
		assert(Sim.submit(sim, 1, Commands.camera(g.cellsX - 6, g.cellsZ - 6, g.cellsX - 1, g.cellsZ - 1)))
		step(15)
		u = assert(world.units[mason])
		t.equal(u.tier, "strategic", "left the tactical tier")
		t.expect(World.def(world, u) ~= nil and World.def(world, u).id == "ord_mason", "still known as a Mason")
		t.equal(u.x, mx, "its exact spot, not the cell's centre")
		t.equal(u.z, mz)
		t.equal(u.heading, heading, "its heading")
		t.equal(u.health, health, "its last health")
		-- back: tactical again, the same unit
		assert(Sim.submit(sim, 1, Commands.camera(cx - 3, cz - 3, cx + 3, cz + 3)))
		step(10)
		t.equal(world.units[mason].tier, "tactical")
	end)
end
