--!strict
-- lune run map_derive <name> <texture.png> [height.png]
--
-- Step 1 of the map pipeline (S-196, after BAR's: docs/design/maps.md), for
-- a map whose layers come from a painted texture (BAR's "diffuse") rather
-- than being painted by hand. From the full-resolution texture (and a height
-- map, if given) it writes into assets/maps/<name>/source/:
--
--   height.png   the height map as 8-bit grey (BAR's is 16-bit, 64 × size + 1)
--   type.png     16 × size: the ground type per pixel, the greys mapinfo.types
--                names (green → grass, dark stone → rock, the rest → sand)
--   metal.png    16 × size: a red dot at every metal spot the texture marks
--                (BAR's metal map; full red = the richest)
--   minimap.png  1024 × 1024: the texture, scaled
--
-- These are then the map's sources: edit them like BAR's (a paint program),
-- and `lune run map_compile <name>` builds the map from them. The texture
-- itself isn't kept (too big for the repository); keep it with the map's
-- source files elsewhere.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Png = require("./lib/Png")

local name = process.args[1]
local texturePath = process.args[2]
local heightPath = process.args[3]
if name == nil or texturePath == nil then
	print("usage: lune run map_derive <name> <texture.png> [height.png]")
	process.exit(1)
end
local dir = `assets/maps/{name}/source/`
local info = (require)(`../{dir}mapinfo`) :: any
local size = info.size :: number -- BAR map units (512 elmos each)

local tex = Png.decode(fs.readFile(texturePath))
print(`texture {tex.width} × {tex.height}`)
-- the height map: rock is steep or high ground, not just grey paint
local hmap = Png.decode(fs.readFile(heightPath or (dir .. "height.png")))
local function heightAt(u: number, v: number): number
	local x = math.clamp(math.floor(u * (hmap.width - 1) + 0.5), 0, hmap.width - 1)
	local y = math.clamp(math.floor(v * (hmap.height - 1) + 0.5), 0, hmap.height - 1)
	return Png.sample(hmap, x, y, 1)
end
-- the steepest height change (0..1 of the map's range) per BAR pixel round (u, v)
local function steepness(u: number, v: number): number
	local d = 1 / (hmap.width - 1)
	local h = heightAt(u, v)
	return math.max(math.abs(heightAt(u + d, v) - h), math.abs(heightAt(u - d, v) - h), math.abs(heightAt(u, v + d) - h), math.abs(heightAt(u, v - d) - h))
end

-- the average colour of the texture over a box (u0, v0)-(u1, v1), fractions
local function boxRgb(u0: number, v0: number, u1: number, v1: number): (number, number, number)
	local x0, y0 = math.floor(u0 * tex.width), math.floor(v0 * tex.height)
	local x1, y1 = math.max(x0 + 1, math.floor(u1 * tex.width)), math.max(y0 + 1, math.floor(v1 * tex.height))
	local r, g, b, n = 0, 0, 0, 0
	for y = y0, math.min(y1, tex.height) - 1 do
		for x = x0, math.min(x1, tex.width) - 1 do
			local pr, pg, pb = Png.rgb(tex, x, y)
			r, g, b, n = r + pr, g + pg, b + pb, n + 1
		end
	end
	return r / n, g / n, b / n
end

-- the ground type at (u, v): its paint, and the height map's slope
local types = info.types :: { [string]: number }
local range = info.height.max - info.height.min
local waterH = (info.waterLevel - info.height.min) / range -- the sea's surface, 0..1
local function typeOf(r: number, g: number, b: number, u: number, v: number): number
	local lum = (r + g + b) / 3
	local h, steep = heightAt(u, v), steepness(u, v)
	-- cliffs: over 1 stud of rise per BAR pixel (8 elmos), ~ 45° at our scale
	if steep * range > 1.6 and h > waterH then
		return types.ROCK
	end
	if g > r + 6 and g > b + 12 then
		return types.GRASS -- green
	elseif r > 150 and g > 110 and b < 90 then
		return types.GRASS -- the mesas' yellow tops (flat, walkable)
	elseif lum < 95 and h > waterH + 0.25 then
		return types.ROCK -- dark stone on high ground: the mountains
	end
	return types.SAND -- grey: beaches, paths, the sea floor
end

-- type.png and the minimap
local px = 16 * size
local typeImg = Png.new(px, px, 1)
for y = 0, px - 1 do
	for x = 0, px - 1 do
		local r, g, b = boxRgb(x / px, y / px, (x + 1) / px, (y + 1) / px)
		buffer.writeu8(typeImg.data, y * px + x, typeOf(r, g, b, (x + 0.5) / px, (y + 0.5) / px))
	end
end
fs.writeFile(dir .. "type.png", Png.encode(typeImg))
local mini = Png.new(1024, 1024, 3)
for y = 0, 1023 do
	for x = 0, 1023 do
		local r, g, b = boxRgb(x / 1024, y / 1024, (x + 1) / 1024, (y + 1) / 1024)
		local o = (y * 1024 + x) * 3
		buffer.writeu8(mini.data, o, math.floor(r + 0.5))
		buffer.writeu8(mini.data, o + 1, math.floor(g + 0.5))
		buffer.writeu8(mini.data, o + 2, math.floor(b + 0.5))
	end
end
fs.writeFile(dir .. "minimap.png", Png.encode(mini))

-- metal: the texture's cyan crystals, clustered on a 1024 grid
local G = 1024
local cyan: { [number]: boolean } = {}
for y = 0, tex.height - 1 do
	for x = 0, tex.width - 1 do
		local r, g, b = Png.rgb(tex, x, y)
		if b > 130 and g > 120 and r < 130 and b - r > 50 and g - r > 35 then
			cyan[(y * G // tex.height) * G + (x * G // tex.width)] = true
		end
	end
end
local seen, spots = {}, {}
for cell in cyan do
	if not seen[cell] then
		local stack, sx, sy, n = { cell }, 0, 0, 0
		seen[cell] = true
		while #stack > 0 do
			local c = table.remove(stack) :: number
			local cx, cy = c % G, c // G
			sx, sy, n = sx + cx, sy + cy, n + 1
			for dy = -2, 2 do
				for dx = -2, 2 do
					local o = (cy + dy) * G + cx + dx
					if cyan[o] and not seen[o] then
						seen[o] = true
						table.insert(stack, o)
					end
				end
			end
		end
		table.insert(spots, { (sx / n + 0.5) / G, (sy / n + 0.5) / G })
	end
end
table.sort(spots, function(a, b)
	return if a[2] ~= b[2] then a[2] < b[2] else a[1] < b[1]
end)
local metal = Png.new(px, px, 3)
for _, s in spots do
	local x, y = math.floor(s[1] * px), math.floor(s[2] * px)
	buffer.writeu8(metal.data, (y * px + x) * 3, 255) -- one full-red pixel per spot
end
fs.writeFile(dir .. "metal.png", Png.encode(metal))
print(`metal spots: {#spots}`)

if heightPath then
	local h = Png.decode(fs.readFile(heightPath))
	local grey = Png.new(h.width, h.height, 1)
	for y = 0, h.height - 1 do
		for x = 0, h.width - 1 do
			buffer.writeu8(grey.data, y * h.width + x, math.floor(Png.sample(h, x, y, 1) * 255 + 0.5))
		end
	end
	fs.writeFile(dir .. "height.png", Png.encode(grey))
	print(`height {h.width} × {h.height}`)
end
print(`wrote {dir}type.png, metal.png, minimap.png`)
