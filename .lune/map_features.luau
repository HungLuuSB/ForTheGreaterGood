--!strict
-- lune run map_features <name> [seed]
--
-- Writes a first feature list for a compiled map (S-197, docs/design/maps.md):
-- assets/maps/<name>/source/features.luau, one side's trees and rocks (the
-- compiler adds the twins). Edit it by hand afterwards, then run
-- `lune run map_compile <name>`.
--
--   trees  copses on grass near its edges (beaches, cliffs, lakes), 4-9
--          trees each, plus a few lone trees
--   rocks  on the sea's islets and at the feet of cliffs, one a cell
--
-- Nothing goes within START_CLEAR studs of a start or DEPOSIT_CLEAR of a metal
-- spot, and the side is the south-west half (x + z < 0), so its twins fill
-- the other.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Layers = require("@shared/Grid/Layers")
local Prng = require("@shared/Util/Prng")
local CompiledMap = require("@shared/Grid/CompiledMap")

local name = process.args[1]
if name == nil then
	print("usage: lune run map_features <name> [seed]")
	process.exit(1)
end
local seed = tonumber(process.args[2]) or 197
local compiled = (require)(`../src/shared/Grid/Maps/{name}`) :: any
local plain = table.clone(compiled)
plain.features = nil
local layers = CompiledMap.build(plain)
Layers.expandDeposits(layers)
local g = layers.grid
local n = g.cellsX
local size = g.sizeX
local rng = Prng.new(seed)

local START_CLEAR = 70
local DEPOSIT_CLEAR = 14
local COPSES = 34 -- on one side
local LONE = 24
local T = Layers.Terrain

local function terrainAt(cx: number, cz: number): number?
	if cx < 0 or cz < 0 or cx >= n or cz >= n then
		return nil
	end
	return Layers.getTerrain(layers, g:index(cx, cz))
end
local function wet(cx: number, cz: number): boolean
	return cx >= 0 and cz >= 0 and cx < n and cz < n and Layers.getWater(layers, g:index(cx, cz)) > 0
end
local function clear(x: number, z: number): boolean
	if x + z >= -8 then
		return false -- the other side (the twins cover it)
	end
	for _, s in layers.starts do
		if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < START_CLEAR ^ 2 then
			return false
		end
	end
	for _, d in layers.deposits :: { { number } } do
		if (d[1] - x) ^ 2 + (d[2] - z) ^ 2 < DEPOSIT_CLEAR ^ 2 then
			return false
		end
	end
	return true
end
-- grass with something else (beach, rock, water) within `r` cells
local function edgeGrass(cx: number, cz: number, r: number): boolean
	if terrainAt(cx, cz) ~= T.GRASS or wet(cx, cz) then
		return false
	end
	for dz = -r, r do
		for dx = -r, r do
			local t = terrainAt(cx + dx, cz + dz)
			if t ~= nil and (t ~= T.GRASS or wet(cx + dx, cz + dz)) then
				return true
			end
		end
	end
	return false
end

local out: { { any } } = {}
local function add(kind: string, x: number, z: number)
	table.insert(out, { kind, 0.5 + x / size, 0.5 + z / size }) -- (v from the image's top, -z: map_compile)
end

-- trees: copses on grass near its edges, then a few lone ones
local copses, tries = 0, 0
while copses < COPSES and tries < 20000 do
	tries += 1
	local cx, cz = rng:nextInteger(0, n - 1), rng:nextInteger(0, n - 1)
	if edgeGrass(cx, cz, 4) then
		local x0, z0 = g:cellCenter(cx, cz)
		if clear(x0, z0) then
			copses += 1
			for _ = 1, rng:nextInteger(4, 9) do
				local x, z = x0 + rng:nextNumber(-22, 22), z0 + rng:nextNumber(-22, 22)
				local tx, tz = g:cellAt(x, z)
				if terrainAt(tx, tz) == T.GRASS and not wet(tx, tz) and clear(x, z) then
					add("tree", x, z)
				end
			end
		end
	end
end
local lone = 0
tries = 0
while lone < LONE and tries < 20000 do
	tries += 1
	local cx, cz = rng:nextInteger(0, n - 1), rng:nextInteger(0, n - 1)
	if terrainAt(cx, cz) == T.GRASS and not wet(cx, cz) then
		local x, z = g:cellCenter(cx, cz)
		x, z = x + rng:nextNumber(-3, 3), z + rng:nextNumber(-3, 3)
		if clear(x, z) then
			lone += 1
			add("tree", x, z)
		end
	end
end

-- rocks: dry cells on islets (water all round within 3 cells) and cliff feet
local rocks = 0
for cz = 0, n - 1 do
	for cx = 0, n - 1 do
		local x, z = g:cellCenter(cx, cz)
		if not wet(cx, cz) and clear(x, z) then
			local islet = true
			for dz = -3, 3 do
				for dx = -3, 3 do
					if math.max(math.abs(dx), math.abs(dz)) == 3 and not wet(cx + dx, cz + dz) then
						islet = false
					end
				end
			end
			local foot = terrainAt(cx, cz) ~= T.ROCK and (terrainAt(cx + 1, cz) == T.ROCK or terrainAt(cx - 1, cz) == T.ROCK or terrainAt(cx, cz + 1) == T.ROCK or terrainAt(cx, cz - 1) == T.ROCK)
			if (islet and rng:chance(0.6)) or (foot and rng:chance(0.035)) then
				rocks += 1
				add("rock", x, z)
			end
		end
	end
end

local lines = {
	"--!strict",
	`-- {compiled.name}'s map features (S-197): one side's trees and rocks as map`,
	"-- fractions { kind, u (from the image's left), v (from its top, -z), value? };",
	"-- `lune run map_compile` adds the twins. First written by",
	`-- \`lune run map_features {name} {seed}\`; edit freely.`,
	"return {",
}
for _, f in out do
	table.insert(lines, string.format('\t{ "%s", %.4f, %.4f },', f[1], f[2], f[3]))
end
table.insert(lines, "}")
fs.writeFile(`assets/maps/{name}/source/features.luau`, table.concat(lines, "\n") .. "\n")
print(`{#out - rocks} trees, {rocks} rocks on one side → assets/maps/{name}/source/features.luau`)
