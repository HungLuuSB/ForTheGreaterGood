--!strict
-- lune run map_compile <name>
--
-- Step 2 of the map pipeline (S-196, after BAR's: docs/design/maps.md). It
-- reads assets/maps/<name>/source/ (mapinfo.luau, height.png, type.png,
-- metal.png), builds the map at mapinfo.cells cells a side, checks it like
-- BAR's map checklist, and writes src/shared/Grid/Maps/<name>.luau (BAR's
-- compiled .smf, in our form; Shared/Grid/CompiledMap loads it).
--
--   height  box-averaged over each cell; black = height.min, white =
--           height.max studs; cells below waterLevel are sea
--   type    each cell's nearest pixel; its grey's nearest mapinfo.types entry
--   metal   every red pixel is a deposit (full red = metalValue), at its cell;
--           spots closer than 3 cells merge
--   point symmetry (mapinfo.symmetry = "point"): every cell matches its twin
--           (heights averaged, the rest from the south-west twin), deposits
--           come from the south-west half and are mirrored
--
-- The checks (it exits 1 if one fails): every start on dry, open, passable
-- ground; every start and deposit reachable from start 1 by every land move
-- class; the map's twin cells match.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Base64 = require("@shared/Util/Base64")
local CompiledMap = require("@shared/Grid/CompiledMap")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local Png = require("./lib/Png")

local name = process.args[1]
if name == nil then
	print("usage: lune run map_compile <name>")
	process.exit(1)
end
local dir = `assets/maps/{name}/source/`
local info = (require)(`../{dir}mapinfo`) :: any
local n = info.cells :: number
local CELL = Grid.CELL_SIZE
local half = n * CELL / 2
local point = info.symmetry == "point"

local heightImg = Png.decode(fs.readFile(dir .. "height.png"))
local typeImg = Png.decode(fs.readFile(dir .. "type.png"))
local metalImg = Png.decode(fs.readFile(dir .. "metal.png"))

-- cell (cx, cz) ↔ image fractions: u from the west edge, v from the north
-- edge (north = +z, so v runs against cz)
local function cellBox(cx: number, cz: number): (number, number, number, number)
	return cx / n, 1 - (cz + 1) / n, (cx + 1) / n, 1 - cz / n
end

-- the height map averaged over cell (cx, cz), in studs
local hmin, hmax = info.height.min :: number, info.height.max :: number
local function cellHeight(cx: number, cz: number): number
	local u0, v0, u1, v1 = cellBox(cx, cz)
	local w, h = heightImg.width - 1, heightImg.height - 1
	local x0, y0 = math.floor(u0 * w + 0.5), math.floor(v0 * h + 0.5)
	local x1, y1 = math.max(x0, math.floor(u1 * w + 0.5) - 1), math.max(y0, math.floor(v1 * h + 0.5) - 1)
	local sum, count = 0, 0
	for y = y0, y1 do
		for x = x0, x1 do
			sum += Png.sample(heightImg, x, y, 1)
			count += 1
		end
	end
	return hmin + (hmax - hmin) * sum / count
end

-- the ground type at cell (cx, cz)
local TYPE_ORDER = { "GRASS", "ROCK", "SAND", "ROAD" }
local function cellType(cx: number, cz: number): number
	local u0, v0, u1, v1 = cellBox(cx, cz)
	local x = math.clamp(math.floor((u0 + u1) / 2 * typeImg.width), 0, typeImg.width - 1)
	local y = math.clamp(math.floor((v0 + v1) / 2 * typeImg.height), 0, typeImg.height - 1)
	local grey = math.floor(Png.sample(typeImg, x, y, 1) * 255 + 0.5)
	local best, bestD = "GRASS", math.huge
	for _, t in TYPE_ORDER do
		local g = info.types[t]
		if g and math.abs(g - grey) < bestD then
			best, bestD = t, math.abs(g - grey)
		end
	end
	return Layers.Terrain[best]
end

local function twin(cx: number, cz: number): (number, number)
	return n - 1 - cx, n - 1 - cz
end
-- the south-west twin of a pair (its cells come first in row order from the south)
local function canonical(cx: number, cz: number): boolean
	local tx, tz = twin(cx, cz)
	return cz < tz or (cz == tz and cx <= tx)
end

-- heights and types
local grid = Grid.new(n, n)
local heights = buffer.create(grid.cellCount * 2)
local terrain = buffer.create(grid.cellCount)
local raw: { number } = table.create(grid.cellCount)
for cz = 0, n - 1 do
	for cx = 0, n - 1 do
		raw[grid:index(cx, cz) + 1] = cellHeight(cx, cz)
	end
end
for cz = 0, n - 1 do
	for cx = 0, n - 1 do
		local i = grid:index(cx, cz)
		local h = raw[i + 1]
		local sx, sz = cx, cz
		if point then
			local tx, tz = twin(cx, cz)
			h = (h + raw[grid:index(tx, tz) + 1]) / 2
			if not canonical(cx, cz) then
				sx, sz = tx, tz
			end
		end
		buffer.writei16(heights, i * 2, math.clamp(math.floor(h / Layers.HEIGHT_STEP + 0.5), -32768, 32767))
		buffer.writeu8(terrain, i, cellType(sx, sz))
	end
end

-- deposits: red pixels → cells, south-west half mirrored when point-symmetric
local spots: { { number } } = {}
for y = 0, metalImg.height - 1 do
	for x = 0, metalImg.width - 1 do
		local r = Png.sample(metalImg, x, y, 1)
		if r > 0.2 then
			local cx = math.clamp(math.floor((x + 0.5) / metalImg.width * n), 0, n - 1)
			local cz = math.clamp(n - 1 - math.floor((y + 0.5) / metalImg.height * n), 0, n - 1)
			if point and not canonical(cx, cz) then
				cx, cz = twin(cx, cz)
			end
			local value = math.max(1, math.floor(info.metalValue * r + 0.5))
			local near = false
			for _, s in spots do
				if math.max(math.abs(s[1] - cx), math.abs(s[2] - cz)) < 3 then
					near = true
				end
			end
			if not near then
				table.insert(spots, { cx, cz, value })
			end
		end
	end
end
table.sort(spots, function(a, b)
	return if a[2] ~= b[2] then a[2] < b[2] else a[1] < b[1]
end)
local deposits = {}
for _, s in spots do
	table.insert(deposits, { s[1], s[2], s[3] })
	if point then
		local tx, tz = twin(s[1], s[2])
		if tx ~= s[1] or tz ~= s[2] then
			table.insert(deposits, { tx, tz, s[3] })
		end
	end
end

-- starts: hints as fractions, each snapped to the nearest open spot (dry,
-- not rock, wheeled units can stand there, a 5 × 5 clearing round it) on cell
-- centres; their twins after them
local probe = CompiledMap.build({ name = info.name, cells = n, waterLevel = info.waterLevel, height = Base64.encode(heights), terrain = (function()
	local r = {}
	for c = 0, grid.cellCount - 1 do
		table.insert(r, `1:{buffer.readu8(terrain, c)},`)
	end
	return table.concat(r)
end)(), deposits = {}, starts = {} })
local probePm = Passability.build(probe)
local function open(cx: number, cz: number): boolean
	for dz = -2, 2 do
		for dx = -2, 2 do
			local ax, az = cx + dx, cz + dz
			if ax < 0 or az < 0 or ax >= n or az >= n then
				return false
			end
			local idx = grid:index(ax, az)
			if Layers.getWater(probe, idx) > 0 or Layers.getTerrain(probe, idx) == Layers.Terrain.ROCK or not Passability.canEnter(probePm, "WHEELED", idx) then
				return false
			end
		end
	end
	return true
end
local starts = {}
for k, s in info.starts do
	local cx0 = math.clamp(math.floor(s[1] * n), 0, n - 1)
	local cz0 = math.clamp(n - 1 - math.floor(s[2] * n), 0, n - 1)
	local found = nil
	for r = 0, 24 do
		for dz = -r, r do
			for dx = -r, r do
				if found == nil and math.max(math.abs(dx), math.abs(dz)) == r and open(cx0 + dx, cz0 + dz) then
					found = { cx0 + dx, cz0 + dz, r }
				end
			end
		end
		if found then
			break
		end
	end
	if found == nil then
		error(`map_compile: start hint {k} has no open ground within 24 cells`)
	end
	if found[3] > 0 then
		print(`  start {k}: moved {found[3]} cells to open ground`)
	end
	table.insert(starts, { grid:cellCenter(found[1], found[2]) })
end
if point then
	for i = 1, #info.starts do
		table.insert(starts, { -starts[i][1], -starts[i][2] })
	end
end

-- the terrain as runs
local runs = {}
local i = 0
while i < grid.cellCount do
	local t = buffer.readu8(terrain, i)
	local j = i
	while j < grid.cellCount and buffer.readu8(terrain, j) == t do
		j += 1
	end
	table.insert(runs, `{j - i}:{t},`)
	i = j
end

local compiled: CompiledMap.Compiled = {
	name = info.name,
	cells = n,
	waterLevel = info.waterLevel,
	wind = info.wind,
	height = Base64.encode(heights),
	terrain = table.concat(runs),
	deposits = deposits,
	starts = starts,
	sideSplits = info.sideSplits,
}

-- the checks
local layers = CompiledMap.build(compiled)
Layers.expandDeposits(layers)
local pm = Passability.build(layers)
local failures = 0
local function fail(msg: string)
	failures += 1
	print(`  FAIL {msg}`)
end
for k, s in starts do
	local idx = grid:index(grid:cellAt(s[1], s[2]))
	if Layers.getWater(layers, idx) > 0 or Layers.getTerrain(layers, idx) == Layers.Terrain.ROCK then
		fail(`start {k} at ({s[1]}, {s[2]}) is in water or on rock`)
	end
end
for _, mc in { "WHEELED", "TRACKED", "WALKER" } do
	local from = grid:index(grid:cellAt(starts[1][1], starts[1][2]))
	local seen = { [from] = true }
	local queue, head = { from }, 1
	while head <= #queue do
		local c = queue[head]
		head += 1
		local cx, cz = c % n, c // n
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ax, az = cx + d[1], cz + d[2]
			if ax >= 0 and ax < n and az >= 0 and az < n then
				local j = grid:index(ax, az)
				if not seen[j] and Passability.canEnter(pm, mc, j) then
					seen[j] = true
					table.insert(queue, j)
				end
			end
		end
	end
	for k, s in starts do
		if not seen[grid:index(grid:cellAt(s[1], s[2]))] then
			fail(`{mc} can't reach start {k} from start 1`)
		end
	end
	local landless = 0
	for _, d in deposits do
		local idx = grid:index(d[1], d[2])
		if Layers.getWater(layers, idx) <= 0 and not seen[idx] then
			landless += 1
		end
	end
	if landless > 0 then
		print(`  note: {landless} dry deposits {mc} can't reach (on mesas or cut off)`)
	end
end
local water, rock = 0, 0
for c = 0, grid.cellCount - 1 do
	water += if Layers.getWater(layers, c) > 0 then 1 else 0
	rock += if Layers.getTerrain(layers, c) == Layers.Terrain.ROCK then 1 else 0
end
local wet = 0
for _, d in deposits do
	wet += if Layers.getWater(layers, grid:index(d[1], d[2])) > 0 then 1 else 0
end
print(`{info.name}: {n} × {n} cells, {#starts} starts, {#deposits} deposits ({wet} under water), {math.floor(water / grid.cellCount * 100 + 0.5)}% sea, {math.floor(rock / grid.cellCount * 100 + 0.5)}% rock`)

-- the module
local lines = {
	"--!strict",
	`-- GENERATED by \`lune run map_compile {name}\` from assets/maps/{name}/source/`,
	"-- (S-196, docs/design/maps.md); don't edit: change the images or mapinfo and",
	"-- compile again. Shared/Grid/CompiledMap loads it.",
	"return {",
	`\tname = {string.format("%q", compiled.name)},`,
	`\tcells = {n},`,
	`\twaterLevel = {compiled.waterLevel},`,
}
if compiled.wind then
	table.insert(lines, `\twind = \{ {compiled.wind[1]}, {compiled.wind[2]} \},`)
end
local function list(rows: { { number } }): string
	local parts = {}
	for _, r in rows do
		local nums = {}
		for _, v in r do
			table.insert(nums, tostring(v))
		end
		table.insert(parts, "{ " .. table.concat(nums, ", ") .. " }")
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end
table.insert(lines, `\tstarts = {list(starts)},`)
table.insert(lines, `\tdeposits = {list(deposits)},`)
table.insert(lines, `\tterrain = "{compiled.terrain}",`)
table.insert(lines, `\theight = "{compiled.height}",`)
table.insert(lines, "}")
fs.writeFile(`src/shared/Grid/Maps/{name}.luau`, table.concat(lines, "\n") .. "\n")
print(`wrote src/shared/Grid/Maps/{name}.luau`)
if failures > 0 then
	print(`{failures} check(s) failed`)
	process.exit(1)
end
