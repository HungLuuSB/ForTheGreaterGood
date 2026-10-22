--!strict
-- The ground beyond the map's edge (C-102), pure: Render/Environment lays
-- dark slabs round the map so the battlefield ends on dim land fading into
-- the haze, not on the sky's colour (the void showed bright blue at 55°,
-- 80° and strategic zoom). Roblox parts are at most 2048 studs a side, so
-- the ring is cut into tiles.

local Layers = require("@shared/Grid/Layers")

local Environment = {}

Environment.REACH = 6000 -- studs of skirt beyond each edge (the haze has swallowed it by then)
Environment.MAX_PART = 2048 -- Roblox's largest part side
Environment.BELOW = 0.5 -- the skirt's top sits this far under the lowest edge surface

export type Rect = { x0: number, z0: number, x1: number, z1: number }

-- `x0..x1` × `z0..z1` cut into equal tiles no wider than `max`.
local function tile(out: { Rect }, x0: number, z0: number, x1: number, z1: number, max: number)
	local nx, nz = math.ceil((x1 - x0) / max), math.ceil((z1 - z0) / max)
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			table.insert(out, { x0 = x0 + i * sx, z0 = z0 + k * sz, x1 = x0 + (i + 1) * sx, z1 = z0 + (k + 1) * sz })
		end
	end
end

-- Tiles covering the ring `reach` studs wide round the map rectangle
-- (`x0..x1` × `z0..z1`): a band north and south the full width, and the
-- sides between them. None overlaps the map or another.
function Environment.skirt(x0: number, z0: number, x1: number, z1: number, reach: number?, max: number?): { Rect }
	local r, m = reach or Environment.REACH, max or Environment.MAX_PART
	local out = {}
	tile(out, x0 - r, z0 - r, x1 + r, z0, m)
	tile(out, x0 - r, z1, x1 + r, z1 + r, m)
	tile(out, x0 - r, z0, x0, z1, m)
	tile(out, x1, z0, x1 + r, z1, m)
	return out
end

-- The skirt's top: just under the lowest surface (ground, or water where
-- there is some) along the map's border cells, so no edge floats over it.
function Environment.edgeY(layers: Layers.Layers): number
	local g = layers.grid
	local lo = math.huge
	local function at(cx: number, cz: number)
		local i = cz * g.cellsX + cx
		lo = math.min(lo, Layers.getHeight(layers, i) + Layers.getWater(layers, i))
	end
	for cx = 0, g.cellsX - 1 do
		at(cx, 0)
		at(cx, g.cellsZ - 1)
	end
	for cz = 1, g.cellsZ - 2 do
		at(0, cz)
		at(g.cellsX - 1, cz)
	end
	return lo - Environment.BELOW
end

return Environment
