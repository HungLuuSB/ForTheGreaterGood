--!strict
-- Draws a client scene dump (src/client/Debug/SceneDump) as a top-down PNG
-- (C-10): proof of what a Studio playtest client draws when Studio's
-- screenshots can't capture the 3D view. Units are rebuilt from the same
-- blockout data the client builds its models from, placed with the dumped
-- heading and turret yaw. From the project root:
--   lune run render_scene <dump.txt> <out.png> [margin studs]
-- Records: M (map), U (unit), D (disc), L (line), G defId x z facing valid
-- (the build ghost: translucent, over a green / red footprint), and
-- I x z shape size r g b alpha selected (a strategic-zoom icon, in pixels),
-- T x1 z1 x2 z2 width r g b (a shell's trail: fades from x1 to x2, over the units).
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
local overDiscs: { Disc } = {} -- E records: effects drawn over the units
type Icon = { x: number, z: number, shape: string, size: number, r: number, g: number, b: number, alpha: number, selected: boolean }
local icons: { Icon } = {}
local map = { -192, -192, 384, 384 }

-- Roblox rotation about +Y by θ, applied to (x, z)
local function rot(x: number, z: number, t: number): (number, number)
	local c, s = math.cos(t), math.sin(t)
	return x * c + z * s, -x * s + z * c
end

local function addUnit(defId: string, team: { number }, ux: number, uz: number, heading: number, yaw: number, tint: { number }?)
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
		if tint then
			color = { (color[1] + tint[1]) / 2, (color[2] + tint[2]) / 2, (color[3] + tint[3]) / 2 }
		end
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
			alpha = if tint then 0.6 else 1,
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
	elseif w[1] == "G" then
		local def = byId[w[2]]
		local tint = if n(6) == 1 then { 90, 230, 110 } else { 235, 70, 60 }
		if def then
			local half = def.footprint * 4
			table.insert(rects, { cx = n(3), cz = n(4), ax = 1, az = 0, ha = half, bx = 0, bz = 1, hb = half, top = 0.1, r = tint[1], g = tint[2], b = tint[3], alpha = 0.45 })
			addUnit(w[2], { 210, 210, 210 }, n(3), n(4), math.pi - n(5) * math.pi / 2, 0, tint)
		end
	elseif w[1] == "T" then
		-- a trail: segments over the units, fading toward its tail
		local x1, z1, x2, z2, width = n(2), n(3), n(4), n(5), math.max(n(6), 0.5)
		local steps = 6
		for k = 0, steps - 1 do
			local a0, a1 = k / steps, (k + 1) / steps
			local sx, sz = x1 + (x2 - x1) * a0, z1 + (z2 - z1) * a0
			local ex, ez = x1 + (x2 - x1) * a1, z1 + (z2 - z1) * a1
			local dx, dz = ex - sx, ez - sz
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 0.01 then
				table.insert(rects, { cx = (sx + ex) / 2, cz = (sz + ez) / 2, ax = dx / len, az = dz / len, ha = len / 2, bx = -dz / len, bz = dx / len, hb = width * (0.3 + 0.7 * a1) / 2, top = 50, r = n(7), g = n(8), b = n(9), alpha = 0.15 + 0.8 * a1 })
			end
		end
	elseif w[1] == "I" then
		table.insert(icons, { x = n(2), z = n(3), shape = w[4], size = n(5), r = n(6), g = n(7), b = n(8), alpha = n(9), selected = w[10] == "1" })
	elseif w[1] == "D" or w[1] == "E" then
		table.insert(if w[1] == "E" then overDiscs else discs, { x = n(2), z = n(3), radius = n(4) / 2, r = n(5), g = n(6), b = n(7), alpha = n(8) })
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

for _, i in icons do
	table.insert(discs, { x = i.x, z = i.z, radius = 12, r = 0, g = 0, b = 0, alpha = 0 }) -- bounds only
	table.insert(overDiscs, discs[#discs])
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
for _, d in overDiscs do
	table.insert(discs, d) -- for the bounds only; drawn separately below
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

local function drawDisc(d: Disc)
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

-- overlay discs (rings, dots) under the units
for _, d in discs do
	if table.find(overDiscs, d) == nil then
		drawDisc(d)
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

-- effects over the units
for _, d in overDiscs do
	if d.alpha > 0 then
		drawDisc(d)
	end
end

-- strategic-zoom icons, in pixels, centered on the unit
for _, i in icons do
	local cx, cy = (i.x - minX) * scale, (i.z - minZ) * scale
	local half = i.size / 2
	for y = math.floor(cy - half - 2), math.ceil(cy + half + 2) do
		for x = math.floor(cx - half - 2), math.ceil(cx + half + 2) do
			local dx, dy = x + 0.5 - cx, y + 0.5 - cy
			local inside, edge = false, false
			local s = i.shape
			if s == "circle" or s == "blip" then
				local r = if s == "blip" then half * 0.6 else half
				local d = math.sqrt(dx * dx + dy * dy)
				inside, edge = d <= r, d > r - 1.2
			elseif s == "diamond" then
				local d = (math.abs(dx) + math.abs(dy)) / (half * 1.06)
				inside, edge = d <= 1, d > 1 - 1.5 / half
			elseif s == "triangle" then
				local t = (dy + half) / (2 * half) -- 0 at the top, 1 at the bottom
				inside = t >= 0 and t <= 1 and math.abs(dx) <= half * t
				edge = inside and (t > 1 - 1.5 / (2 * half) or math.abs(dx) > half * t - 1.5)
			else -- square, frame, ghost
				inside = math.abs(dx) <= half and math.abs(dy) <= half
				edge = inside and (math.abs(dx) > half - (if s == "square" then 1 else 2) or math.abs(dy) > half - (if s == "square" then 1 else 2))
			end
			if inside then
				local r, g, b = i.r, i.g, i.b
				local a = i.alpha
				if s == "ghost" and not edge then
					a = 0
				elseif s == "frame" and not edge then
					r, g, b = r * 0.55, g * 0.55, b * 0.55
				elseif edge then
					if i.selected then
						r, g, b = 255, 255, 255
					elseif s ~= "frame" and s ~= "ghost" then
						r, g, b = 0, 0, 0
					end
				end
				if a > 0 then
					blend(x, y, r, g, b, a)
				end
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
