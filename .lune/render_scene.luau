--!strict
-- Draws a client scene dump (src/client/Debug/SceneDump) as a top-down PNG
-- (C-10): proof of what a Studio playtest client draws when Studio's
-- screenshots can't capture the 3D view. Units are rebuilt from the same
-- blockout data the client builds its models from, placed with the dumped
-- heading and turret yaw. From the project root:
--   lune run render_scene <dump.txt> <out.png> [margin studs]
-- North (-Z) is up; the ground is a 64-stud checkerboard (8 × 8 cells).

local fs = require("@lune/fs")
local process = require("@lune/process")
local Blockout = require("@shared/Defs/Blockouts/Blockout")
local Defs = require("@shared/Defs/Defs")
local Ppm = require("./lib/Ppm")

local input, output = process.args[1], process.args[2]
if input == nil or output == nil then
	print("usage: lune run render_scene <dump.txt> <out.png> [margin studs]")
	process.exit(1)
end
local margin = tonumber(process.args[3]) or 20

local defs = Defs.load()
local byId: { [string]: any } = {}
for _, def in defs.unitByIndex do
	byId[def.id] = def
end

-- An oriented rectangle in world X/Z: center, unit axes a and b, half sizes.
type Rect = { cx: number, cz: number, ax: number, az: number, ha: number, bx: number, bz: number, hb: number, top: number, r: number, g: number, b: number, alpha: number }
type Disc = { x: number, z: number, radius: number, r: number, g: number, b: number, alpha: number }

local rects: { Rect } = {}
local discs: { Disc } = {}
local map = { -192, -192, 384, 384 }

-- Roblox rotation about +Y by θ, applied to (x, z)
local function rot(x: number, z: number, t: number): (number, number)
	local c, s = math.cos(t), math.sin(t)
	return x * c + z * s, -x * s + z * c
end

local function addUnit(defId: string, team: { number }, ux: number, uz: number, heading: number, yaw: number)
	local def = byId[defId]
	if def == nil then
		print(`unknown def {defId}, skipped`)
		return
	end
	local bp = Blockout.forDef(def)
	local palette = Blockout.PALETTES[def.faction] or Blockout.PALETTES.neutral
	local slot = def.weapons[1]
	local yawPiece = if slot and slot.turretPiece then slot.turretPiece else "turret"
	local partByName: { [string]: Blockout.Part } = {}
	for _, p in bp.parts do
		partByName[p.name] = p
	end
	local isPiece: { [string]: boolean } = {}
	for _, piece in def.pieces do
		isPiece[piece] = true
	end
	for _, p in bp.parts do
		local cx, cz = p.at[1], p.at[3]
		local ax, az, bx, bz = 1, 0, 0, 1
		if p.rot then
			local t = math.rad(p.rot[2])
			ax, az = rot(1, 0, t)
			bx, bz = rot(0, 1, t)
		end
		-- the joints up the chain: the yaw piece turns about its pivot
		local name: string? = if isPiece[p.name] then p.name else p.parent
		while name do
			local piece = partByName[name]
			if name == yawPiece then
				local pv = piece.pivot or piece.at
				local dx, dz = rot(cx - pv[1], cz - pv[3], yaw)
				cx, cz = pv[1] + dx, pv[3] + dz
				ax, az = rot(ax, az, yaw)
				bx, bz = rot(bx, bz, yaw)
			end
			name = piece.parent
		end
		-- the unit: rotated by heading + π, then moved
		local t = heading + math.pi
		cx, cz = rot(cx, cz, t)
		ax, az = rot(ax, az, t)
		bx, bz = rot(bx, bz, t)
		local color = if p.color == "team" then team else palette[p.color]
		table.insert(rects, {
			cx = ux + cx,
			cz = uz + cz,
			ax = ax,
			az = az,
			ha = p.size[1] / 2,
			bx = bx,
			bz = bz,
			hb = p.size[3] / 2,
			top = p.at[2] + p.size[2] / 2,
			r = color[1],
			g = color[2],
			b = color[3],
			alpha = 1,
		})
	end
end

for line in string.gmatch(fs.readFile(input), "[^\r\n]+") do
	local w = {}
	for token in string.gmatch(line, "%S+") do
		table.insert(w, token)
	end
	local n = function(i: number): number
		return tonumber(w[i]) or 0
	end
	if w[1] == "M" then
		map = { n(2), n(3), n(4), n(5) }
	elseif w[1] == "U" then
		local team = {}
		for c in string.gmatch(w[3], "[^,]+") do
			table.insert(team, tonumber(c) or 0)
		end
		addUnit(w[2], team, n(4), n(5), n(6), n(7))
	elseif w[1] == "D" then
		table.insert(discs, { x = n(2), z = n(3), radius = n(4) / 2, r = n(5), g = n(6), b = n(7), alpha = n(8) })
	elseif w[1] == "L" then
		local x1, z1, x2, z2, width = n(2), n(3), n(4), n(5), n(6)
		local dx, dz = x2 - x1, z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0.01 then
			table.insert(rects, {
				cx = (x1 + x2) / 2,
				cz = (z1 + z2) / 2,
				ax = dx / len,
				az = dz / len,
				ha = len / 2,
				bx = -dz / len,
				bz = dx / len,
				hb = math.max(width, 0.5) / 2,
				top = 0.2, -- under the units
				r = n(7),
				g = n(8),
				b = n(9),
				alpha = 0.9,
			})
		end
	end
end

if #rects == 0 and #discs == 0 then
	print("nothing to draw")
	process.exit(1)
end

local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
for _, r in rects do
	local ex = math.abs(r.ax) * r.ha + math.abs(r.bx) * r.hb
	local ez = math.abs(r.az) * r.ha + math.abs(r.bz) * r.hb
	minX, maxX = math.min(minX, r.cx - ex), math.max(maxX, r.cx + ex)
	minZ, maxZ = math.min(minZ, r.cz - ez), math.max(maxZ, r.cz + ez)
end
for _, d in discs do
	minX, maxX = math.min(minX, d.x - d.radius), math.max(maxX, d.x + d.radius)
	minZ, maxZ = math.min(minZ, d.z - d.radius), math.max(maxZ, d.z + d.radius)
end
minX, minZ, maxX, maxZ = minX - margin, minZ - margin, maxX + margin, maxZ + margin
local scale = math.min(1400 / (maxX - minX), 900 / (maxZ - minZ), 10)
local w, h = math.ceil((maxX - minX) * scale), math.ceil((maxZ - minZ) * scale)
local img = Ppm.new(w, h)
local px = buffer.create(w * h * 3) -- working copy as floats would be nicer; u8 blending is enough

local function blend(x: number, y: number, r: number, g: number, b: number, a: number)
	if x < 0 or y < 0 or x >= w or y >= h then
		return
	end
	local o = (y * w + x) * 3
	local function mix(i: number, v: number)
		local old = buffer.readu8(px, o + i)
		buffer.writeu8(px, o + i, math.clamp(math.floor(old + (v - old) * a + 0.5), 0, 255))
	end
	mix(0, r)
	mix(1, g)
	mix(2, b)
end

-- ground
for y = 0, h - 1 do
	local z = minZ + (y + 0.5) / scale
	for x = 0, w - 1 do
		local wx = minX + (x + 0.5) / scale
		local on = wx >= map[1] and wx <= map[1] + map[3] and z >= map[2] and z <= map[2] + map[4]
		if on then
			local checker = (math.floor((wx - map[1]) / 64) + math.floor((z - map[2]) / 64)) % 2 == 1
			local s = if checker then 0.92 else 1
			blend(x, y, 104 * s, 130 * s, 80 * s, 1)
		else
			blend(x, y, 30, 32, 36, 1)
		end
	end
end

-- overlay discs (rings, dots, flashes) under the units
for _, d in discs do
	local x0, x1 = math.floor((d.x - d.radius - minX) * scale), math.ceil((d.x + d.radius - minX) * scale)
	local y0, y1 = math.floor((d.z - d.radius - minZ) * scale), math.ceil((d.z + d.radius - minZ) * scale)
	for y = math.max(y0, 0), math.min(y1, h - 1) do
		for x = math.max(x0, 0), math.min(x1, w - 1) do
			local dx = minX + (x + 0.5) / scale - d.x
			local dz = minZ + (y + 0.5) / scale - d.z
			if dx * dx + dz * dz <= d.radius * d.radius then
				blend(x, y, d.r, d.g, d.b, d.alpha)
			end
		end
	end
end

table.sort(rects, function(a, b)
	return a.top < b.top
end)
for _, r in rects do
	local ex = math.abs(r.ax) * r.ha + math.abs(r.bx) * r.hb
	local ez = math.abs(r.az) * r.ha + math.abs(r.bz) * r.hb
	local x0, x1 = math.floor((r.cx - ex - minX) * scale), math.ceil((r.cx + ex - minX) * scale)
	local y0, y1 = math.floor((r.cz - ez - minZ) * scale), math.ceil((r.cz + ez - minZ) * scale)
	local shade = math.clamp(0.8 + r.top / 25, 0.8, 1.15)
	for y = math.max(y0, 0), math.min(y1, h - 1) do
		local dz = minZ + (y + 0.5) / scale - r.cz
		for x = math.max(x0, 0), math.min(x1, w - 1) do
			local dx = minX + (x + 0.5) / scale - r.cx
			local u = dx * r.ax + dz * r.az
			local v = dx * r.bx + dz * r.bz
			if math.abs(u) <= r.ha and math.abs(v) <= r.hb then
				local edge = r.alpha >= 1 and (math.abs(u) > r.ha - 0.2 or math.abs(v) > r.hb - 0.2)
				local k = if edge then shade * 0.7 else shade
				blend(x, y, r.r * k, r.g * k, r.b * k, r.alpha)
			end
		end
	end
end

for y = 0, h - 1 do
	for x = 0, w - 1 do
		local o = (y * w + x) * 3
		Ppm.set(img, x, y, buffer.readu8(px, o), buffer.readu8(px, o + 1), buffer.readu8(px, o + 2))
	end
end
Ppm.writePng(img, output)
print(`{output}: {w} x {h}, {#rects} shapes, {#discs} discs, {string.format("%.1f", scale)} px per stud`)
