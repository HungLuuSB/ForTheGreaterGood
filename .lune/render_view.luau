--!strict
-- Draws a client view dump (src/client/Debug/ViewDump) as a top-down PNG
-- (C-10): proof of what the playtest client draws when Studio's screenshots
-- can't capture the 3D view. From the project root:
--   lune run render_view <dump.txt> <out.png> [studs per pixel crop margin]
-- The image is cropped to the drawn parts plus a margin, on a 64-stud
-- checkerboard (one tile = 8 × 8 cells), north (-Z) up.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Ppm = require("./lib/Ppm")

local input, output = process.args[1], process.args[2]
if input == nil or output == nil then
	print("usage: lune run render_view <dump.txt> <out.png> [margin studs]")
	process.exit(1)
end
local margin = tonumber(process.args[3]) or 24

type P = { cx: number, cz: number, top: number, ax: number, az: number, ha: number, bx: number, bz: number, hb: number, r: number, g: number, b: number }

local parts: { P } = {}
local map = { 0, 0, 0, 0 }
for line in string.gmatch(fs.readFile(input), "[^\r\n]+") do
	local nums = {}
	for n in string.gmatch(line, "%S+") do
		table.insert(nums, tonumber(n) or 0)
	end
	local kind = string.sub(line, 1, 1)
	if kind == "M" then
		map = { nums[2], nums[3], nums[4], nums[5] }
	elseif kind == "P" then
		table.insert(parts, {
			cx = nums[2], cz = nums[3], top = nums[4],
			ax = nums[5], az = nums[6], ha = nums[7],
			bx = nums[8], bz = nums[9], hb = nums[10],
			r = nums[11], g = nums[12], b = nums[13],
		})
	end
end
if #parts == 0 then
	print("no parts in the dump")
	process.exit(1)
end

local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
for _, p in parts do
	local ex = math.abs(p.ax) * p.ha + math.abs(p.bx) * p.hb
	local ez = math.abs(p.az) * p.ha + math.abs(p.bz) * p.hb
	minX, maxX = math.min(minX, p.cx - ex), math.max(maxX, p.cx + ex)
	minZ, maxZ = math.min(minZ, p.cz - ez), math.max(maxZ, p.cz + ez)
end
minX, minZ, maxX, maxZ = minX - margin, minZ - margin, maxX + margin, maxZ + margin
local scale = math.min(1400 / (maxX - minX), 900 / (maxZ - minZ), 10) -- pixels per stud
local w, h = math.ceil((maxX - minX) * scale), math.ceil((maxZ - minZ) * scale)
local img = Ppm.new(w, h)

-- ground: 64-stud checkerboard aligned to the map origin; off-map is dark
for py = 0, h - 1 do
	local z = minZ + (py + 0.5) / scale
	for px = 0, w - 1 do
		local x = minX + (px + 0.5) / scale
		local on = x >= map[1] and x <= map[1] + map[3] and z >= map[2] and z <= map[2] + map[4]
		if on then
			local checker = (math.floor((x - map[1]) / 64) + math.floor((z - map[2]) / 64)) % 2 == 1
			local s = if checker then 0.92 else 1
			Ppm.set(img, px, py, 104 * s, 130 * s, 80 * s)
		else
			Ppm.set(img, px, py, 30, 32, 36)
		end
	end
end

-- parts, lowest top first, with simple top shading by height
table.sort(parts, function(a, b)
	return a.top < b.top
end)
for _, p in parts do
	local ex = math.abs(p.ax) * p.ha + math.abs(p.bx) * p.hb
	local ez = math.abs(p.az) * p.ha + math.abs(p.bz) * p.hb
	local x0, x1 = math.floor((p.cx - ex - minX) * scale), math.ceil((p.cx + ex - minX) * scale)
	local y0, y1 = math.floor((p.cz - ez - minZ) * scale), math.ceil((p.cz + ez - minZ) * scale)
	local shade = math.clamp(0.75 + p.top / 40, 0.75, 1.15)
	for py = math.max(y0, 0), math.min(y1, h - 1) do
		local z = minZ + (py + 0.5) / scale - p.cz
		for px = math.max(x0, 0), math.min(x1, w - 1) do
			local x = minX + (px + 0.5) / scale - p.cx
			local u = x * p.ax + z * p.az
			local v = x * p.bx + z * p.bz
			if math.abs(u) <= p.ha and math.abs(v) <= p.hb then
				-- darker rim so neighbouring parts read apart
				local edge = math.abs(u) > p.ha - 0.25 or math.abs(v) > p.hb - 0.25
				local k = if edge then shade * 0.7 else shade
				Ppm.set(img, px, py, p.r * k, p.g * k, p.b * k)
			end
		end
	end
end

Ppm.writePng(img, output)
print(`{output}: {w} x {h}, {#parts} parts, {string.format("%.1f", scale)} px per stud`)
