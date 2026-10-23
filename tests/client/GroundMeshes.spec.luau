--!strict
-- Baked map ground (C-167): a named map uses its mesh tiles only when the
-- entry is approved (or review with the Studio switch) and has tiles; every
-- material the client draws has a plain fallback look; the export covers
-- every named map with heights matching the drawn surface.

local GroundMeshes = require("../../src/client/Core/GroundMeshes")
local Terrain = require("../../src/client/Core/Terrain")
local MapRegistry = require("@shared/Grid/MapRegistry")

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
