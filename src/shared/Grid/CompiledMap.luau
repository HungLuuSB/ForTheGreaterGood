--!strict
-- Maps built the BAR way (S-196, docs/design/maps.md): a map's layers are
-- painted as images (height, type, metal) with a mapinfo, and
-- `lune run map_compile <name>` writes them into Shared/Grid/Maps/<name> (BAR's
-- compiled .smf, in our form). This turns that module back into Layers.
--
-- A compiled module holds:
--   name, cells            its name and size (cells a side, centred on 0)
--   waterLevel             studs: cells below it are sea
--   wind                   { min, max } fractions of a turbine's best, or nil
--   height                 Base64 of an i16 per cell (Layers' raw steps,
--                          little-endian), rows south to north (cz)
--   terrain                run-length "count:type," of Layers.Terrain per cell
--   deposits               { { cx, cz, value } } (each a 2 × 2 patch's corner
--                          cell once loaded: Layers.expandDeposits)
--   starts                 { { x, z } } start hints, in studs
--   sideSplits             optional, as Layers.sideSplits

local Base64 = require("../Util/Base64")
local Grid = require("./Grid")
local Layers = require("./Layers")

local CompiledMap = {}

export type Compiled = {
	name: string,
	cells: number,
	waterLevel: number,
	wind: { number }?,
	height: string,
	terrain: string,
	deposits: { { number } },
	starts: { { number } },
	sideSplits: { [number]: { { number } } }?,
}

function CompiledMap.build(m: Compiled): Layers.Layers
	local n = m.cells
	local grid = Grid.new(n, n)
	local layers = Layers.new(grid)
	local heights = Base64.decode(m.height)
	assert(buffer.len(heights) == grid.cellCount * 2, `CompiledMap: {m.name}'s height layer is {buffer.len(heights)} bytes, want {grid.cellCount * 2}`)
	buffer.copy(layers.height, 0, heights)
	local wl = m.waterLevel
	for i = 0, grid.cellCount - 1 do
		local h = Layers.getHeight(layers, i)
		if h < wl then
			Layers.setWater(layers, i, wl - h)
		end
	end
	local i = 0
	for count, kind in string.gmatch(m.terrain, "(%d+):(%d+),") do
		local t = tonumber(kind) :: number
		for _ = 1, tonumber(count) :: number do
			Layers.setTerrain(layers, i, t)
			i += 1
		end
	end
	assert(i == grid.cellCount, `CompiledMap: {m.name}'s terrain covers {i} cells, want {grid.cellCount}`)
	for _, d in m.deposits do
		Layers.setSupply(layers, grid:index(d[1], d[2]), d[3])
	end
	local starts = {}
	for _, s in m.starts do
		table.insert(starts, { s[1], s[2] })
	end
	layers.starts = starts
	layers.sideSplits = m.sideSplits
	layers.wind = m.wind
	return layers
end

return CompiledMap
