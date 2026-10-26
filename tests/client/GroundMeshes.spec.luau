--!strict
-- Baked map ground (C-167): a named map uses its mesh tiles only when the
-- entry is approved (or review with the Studio switch) and has tiles; every
-- material the client draws has a plain fallback look; the export covers
-- every named map with heights matching the drawn surface; on a coarser
-- bake (the Lakelands, 8 studs) what stands on the ground follows the mesh.

local GroundMeshes = require("../../src/client/Core/GroundMeshes")
local Terrain = require("../../src/client/Core/Terrain")
local MapRegistry = require("@shared/Grid/MapRegistry")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TILE = { mesh = "rbxassetid://1", center = { 0, 10, 0 }, size = { 64, 4, 64 }, material = "desert" }

return function(t: any)
	t.test("an entry is used when approved with tiles; review only with the switch", function()
		local manifest: any = {
			canyon = { status = "approved", tiles = { TILE } },
			normandy = { status = "review", tiles = { TILE } },
			ridgeline = { status = "approved", tiles = {} },
		}
		t.expect(GroundMeshes.entryFor("map:canyon", manifest) ~= nil, "approved")
		t.equal(GroundMeshes.entryFor("map:normandy", manifest), nil, "review: not by default")
		t.equal(GroundMeshes.entryFor("map:ridgeline", manifest), nil, "no tiles: the terrain")
		t.equal(GroundMeshes.entryFor("map:coastline", manifest), nil, "no entry")
		t.equal(GroundMeshes.entryFor("start:48", manifest), nil, "not a named map")
		GroundMeshes.ANYWAY = true
		t.expect(GroundMeshes.entryFor("map:normandy", manifest) ~= nil, "review with the switch")
		GroundMeshes.ANYWAY = false
	end)

	t.test("a coarser bake: units stand on the mesh, not on the cell centres it skips (C-235)", function()
		local manifest: any = {
			lakelands = { status = "approved", tiles = { TILE }, step = 8 },
			canyon = { status = "approved", tiles = { TILE } },
			plains = { status = "approved", tiles = { TILE } },
		}
		t.equal(GroundMeshes.drawnStep("map:lakelands", manifest), 8, "the Lakelands' bake samples every 8 studs")
		t.equal(GroundMeshes.drawnStep("map:lakelands"), 8, "and the manifest says so (models-C writes `step` for a coarser bake)")
		t.equal(GroundMeshes.drawnStep("map:plains", manifest), nil, "an entry without a step: a 4-stud bake")
		t.equal(GroundMeshes.drawnStep("map:canyon", manifest), nil, "a 4-stud bake: the smooth ground as it is")
		t.equal(GroundMeshes.drawnStep("map:ridgeline", manifest), nil, "no mesh ground")
		-- the bake itself: its 8-stud samples, each square two triangles split
		-- along the flatter diagonal (assets/maps/tools/ground.py)
		local g = serde.decode("json", fs.readFile("assets/maps/lakelands/ground.json"))
		local layers = assert(MapRegistry.load("map:lakelands"))
		local nx = g.vertices[1]
		local function sample(i: number, j: number): number -- 8-stud sample (i, j)
			return g.heights[(2 * j) * nx + 2 * i + 1]
		end
		local function mesh(x: number, z: number): number
			local fx, fz = (x - g.origin[1]) / 8, (z - g.origin[2]) / 8
			local i, j = math.floor(fx), math.floor(fz)
			local tx, tz = fx - i, fz - j
			local h00, h10, h01, h11 = sample(i, j), sample(i + 1, j), sample(i, j + 1), sample(i + 1, j + 1)
			-- the triangle's plane through its three corners
			local a, b, c
			if math.abs(h00 - h11) <= math.abs(h10 - h01) then
				if tx >= tz then
					a, b, c = { 0, 0, h00 }, { 1, 1, h11 }, { 1, 0, h10 }
				else
					a, b, c = { 0, 0, h00 }, { 0, 1, h01 }, { 1, 1, h11 }
				end
			elseif tx + tz <= 1 then
				a, b, c = { 0, 0, h00 }, { 0, 1, h01 }, { 1, 0, h10 }
			else
				a, b, c = { 1, 0, h10 }, { 0, 1, h01 }, { 1, 1, h11 }
			end
			local ux, uz, uh = b[1] - a[1], b[2] - a[2], b[3] - a[3]
			local vx, vz, vh = c[1] - a[1], c[2] - a[2], c[3] - a[3]
			local nX, nZ, nH = uz * vh - uh * vz, uh * vx - ux * vh, ux * vz - uz * vx -- the normal, (x, z, height)
			return a[3] - (nX * (tx - a[1]) + nZ * (tz - a[2])) / nH
		end
		local worst, smoothWorst, n = 0, 0, 0
		local rng = 12345
		local function rand(): number
			rng = (rng * 1103515245 + 12345) % 2147483648
			return rng / 2147483648
		end
		local spots = { { -964, -1580 }, { 1012, -1580 }, { -572, -324 } } -- grass at a ridge's foot (the smooth ground 2 studs off the mesh)
		for _ = 1, 4000 do
			table.insert(spots, { -2040 + rand() * 4080, -2040 + rand() * 4080 })
		end
		for _, p in spots do
			local m = mesh(p[1], p[2])
			local dd = math.abs(Terrain.drawnY(layers, p[1], p[2], 8) - m)
			worst = math.max(worst, dd)
			smoothWorst = math.max(smoothWorst, math.abs(Terrain.groundY(layers, p[1], p[2]) - m))
			n += 1
		end
		print(string.format("    %d spots: drawnY off the bake by at most %.4f studs (the cell-centre surface by %.2f)", n, worst, smoothWorst))
		-- (a few hundredths where a square's two diagonals are nearly as flat:
		-- the export's rounded heights may tip the bake's split the other way)
		t.expect(worst < 0.1, `units on the mesh ({worst})`)
		t.expect(smoothWorst > 1, "the cell-centre surface is visibly off there (why this exists)")
	end)

	t.test("every ground type the client draws has a fallback look", function()
		local seen = {}
		for _, name in { "map:canyon", "map:normandy", "map:coastline", "map:ridgeline" } do
			local layers = assert(MapRegistry.load(name))
			local g = layers.grid
			local feature = if name == "map:canyon" then require("@shared/Grid/Canyon").feature elseif name == "map:normandy" then require("@shared/Grid/Normandy").feature else nil
			for cz = 0, g.cellsZ - 1, 3 do
				for cx = 0, g.cellsX - 1, 3 do
					local x, z = g:cellCenter(cx, cz)
					seen[Terrain.material(layers, x, z, feature)] = true
				end
			end
		end
		for key in seen do
			t.expect(GroundMeshes.FALLBACK[key] ~= nil, `{key} has a fallback`)
		end
	end)
end
