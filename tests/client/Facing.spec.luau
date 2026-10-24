--!strict
-- Structure facing (C-206): the exit direction the arrow shows is where the
-- server puts the build pad and drives units out (Build.padPosition and
-- produce, heading = facing × 90°), and the names follow the map as the
-- camera shows it (up = -Z = North).

local Facing = require("../../src/client/Core/Facing")
local Build = require("../../src/server/Sim/Build")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

return function(t: any)
	t.test("exit directions and names", function()
		local want = { [0] = { 0, 1, "South" }, [1] = { 1, 0, "East" }, [2] = { 0, -1, "North" }, [3] = { -1, 0, "West" } }
		for f = 0, 3 do
			local x, z = Facing.exit(f)
			t.equal(x, want[f][1], `facing {f} x`)
			t.equal(z, want[f][2], `facing {f} z`)
			t.equal(Facing.name(f), want[f][3])
		end
		t.equal(Facing.message(1), "Buildings set to face East")
		t.equal(Facing.name(5), "East", "wraps")
	end)

	t.test("the arrow's side is the server's build pad side", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		for f = 0, 3 do
			local plant = Spawn.unit(sim, "ord_vehplant", 1, -100 + f * 60, 0, Facing.heading(f))
			local px, pz = Build.padPosition(sim, plant)
			local dx, dz = px - sim.world.posX[plant], pz - sim.world.posZ[plant]
			local ex, ez = Facing.exit(f)
			t.expect(dx * ex + dz * ez > 0, `facing {f}: the pad lies on the exit side ({dx}, {dz})`)
		end
	end)
end
