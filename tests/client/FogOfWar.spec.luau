--!strict
-- Fog of war in 3D (C-32): overlay plates cover exactly the unseen sensor
-- cells and never dip under the drawn ground; light cells are lit by the
-- share of their cells in sight; ghosts come back with the def and spot
-- the client saw; radar contacts are listed for the world.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local Fog = require("../../src/client/Core/Fog")
local Ghosts = require("../../src/client/Core/Ghosts")
local NetIn = require("../../src/client/Core/NetIn")
local Terrain = require("../../src/client/Core/Terrain")
local Vision = require("../../src/client/Core/Vision")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local MapRegistry = require("@shared/Grid/MapRegistry")

local DT = 1 / 15

return function(t: any)
	t.test("plates cover exactly the unseen cells, over the terrain, merged where flat", function()
		local layers = assert(MapRegistry.load("map:coastline"))
		local v = Vision.new(layers.grid)
		-- a fake sight map: a disc of seen cells
		local seenCells = 0
		for cz = 0, v.depth - 1 do
			for cx = 0, v.width - 1 do
				if (cx - 20) ^ 2 + (cz - 30) ^ 2 <= 100 then
					buffer.writeu16(v.seen, (cz * v.width + cx) * 2, 1)
					seenCells += 1
				end
			end
		end
		local bw, bd = Fog.blocks(v)
		local area, plates, under = 0, 0, 0
		for bz = 0, bd - 1 do
			for bx = 0, bw - 1 do
				for _, p in Fog.blockPlates(v, layers, bx, bz) do
					plates += 1
					area += p.sx * p.sz
					-- the drawn ground stays under the plate across it
					for _, f in { { -0.5, -0.5 }, { 0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, 0.5 }, { 0, 0 } } do
						local x, z = p.x + f[1] * (p.sx - 0.01), p.z + f[2] * (p.sz - 0.01)
						local planeY = p.y + (x - p.x) * p.slopeX + (z - p.z) * p.slopeZ
						if Terrain.surfaceY(layers, x, z) > planeY + 1e-6 then
							under += 1
						end
					end
				end
			end
		end
		local unseen = v.width * v.depth - seenCells
		t.equal(area, unseen * 16 * 16, "the plates' area is exactly the unseen cells'")
		t.equal(under, 0, "no ground pokes through a plate")
		print(string.format("    coastline: %d unseen cells in %d plates", unseen, plates))
		t.expect(plates < unseen / 2, "flat runs merge")
		-- light levels: full inside the disc, none far away, partial on its edge
		t.equal(Fog.lightLevel(v, 10, 15), 1)
		t.equal(Fog.lightLevel(v, 0, 0), 0)
		local partial = false
		local lw, ld = Fog.lightSize(v)
		for lz = 0, ld - 1 do
			for lx = 0, lw - 1 do
				local l = Fog.lightLevel(v, lx, lz)
				if l > 0 and l < 1 then
					partial = true
				end
			end
		end
		t.expect(partial, "edge light cells are partly lit")
	end)

	t.test("a structure seen and then left behind comes back as a ghost where it stood", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		api.send(Commands.camera(0, 0, 63, 63))
		local scout = Spawn.unit(sim, "ord_lancer", 1, 60, 0, math.pi / 2)
		local enemy = Spawn.unit(sim, "chs_generator", 2, 140, 20, 0)
		local g = Ghosts.new()
		local tick = 0
		local function run(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				Ghosts.remember(g, world)
				table.clear(world.died)
				Api.frame(api, tick * DT)
			end
		end
		run(2)
		api.actions.select({ scout })
		api.actions.setFireState(0) -- hold fire: look, don't shoot
		run(8)
		t.expect(world.units[enemy] and world.units[enemy].tier == "tactical", "the generator is in sight")
		api.actions.order("move", { x = -200, z = 0 }, false)
		run(15 * 12)
		local u = world.units[enemy]
		t.expect(u and u.tier == "strategic" and bit32.band(u.flags or 0, 8) ~= 0, "now a ghost record")
		local ghosts = Ghosts.list(g, world)
		t.equal(#ghosts, 1)
		local gh = ghosts[1]
		t.expect(gh.exact and gh.def.id == "chs_generator", "drawn as the generator it was")
		t.expect(math.abs(gh.x - sim.world.posX[enemy]) < 0.1 and math.abs(gh.z - sim.world.posZ[enemy]) < 0.1, "where it stands")
	end)

	t.test("radar contacts are listed for the world", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		-- a watchtower (sight 160, radar 650) and an enemy tank 350 studs out: on radar, out of sight
		Spawn.unit(sim, "ord_watchtower", 1, 0, 0, 0)
		Spawn.unit(sim, "chs_ravager", 2, 350, 0, 0)
		local g = Ghosts.new()
		local most = 0
		for tick = 1, 60 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.died)
			local _, contacts = Ghosts.list(g, world)
			most = math.max(most, #contacts)
			for _, c in contacts do
				t.expect(world.units[c.id].tier ~= "tactical", "contacts are never drawn units")
			end
		end
		t.expect(most > 0, `the radar finds contacts ({most})`)
	end)
end
