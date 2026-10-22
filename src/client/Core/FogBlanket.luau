--!strict
-- Fog of war as one image per map (C-100, BAR style; replaces the C-32
-- point-light fog): normal daylight everywhere, and what the team can't see
-- darkened. One pixel per grid cell, each in one of three states from the
-- server's ally-team sight (Core/Vision):
--   visible  - clear;
--   explored - seen before, not now: desaturated grey, about 40% darker;
--   never    - never seen: about 70% darker.
-- A pixel's look is its four nearest sensor cells' looks blended by
-- distance (Roblox samples this texture without smoothing, so the soft edge
-- is made here, about a sensor cell wide), and it fades there over FADE
-- seconds. Pixels hold a grey level and an alpha; `rgba` is the image's bytes (written by
-- Render/FogBlanket) and `step` reports the rectangle of pixels it changed,
-- so only those are uploaded. Pure Luau (C-7).

local Vision = require("./Vision")

local FogBlanket = {}

FogBlanket.FADE = 0.3 -- seconds from one state to another
-- per state: grey level (0..255) and alpha (0..1); blended over the scene,
-- a grey layer both darkens and desaturates
FogBlanket.LOOK = table.freeze({
	visible = table.freeze({ grey = 30, alpha = 0 }),
	explored = table.freeze({ grey = 30, alpha = 0.52 }),
	never = table.freeze({ grey = 8, alpha = 0.74 }),
})
FogBlanket.TINT = table.freeze({ 1, 1.04, 1.18 }) -- r, g, b multipliers on the grey (a cool shadow)
FogBlanket.BUDGET = 3000 -- pixels faded per step at most: a huge change spreads over a few steps

local STATES = { FogBlanket.LOOK.visible, FogBlanket.LOOK.explored, FogBlanket.LOOK.never }
local GREY = { STATES[1].grey, STATES[2].grey, STATES[3].grey }
local ALPHA = { STATES[1].alpha, STATES[2].alpha, STATES[3].alpha }
local VISIBLE, EXPLORED, NEVER = 1, 2, 3

export type Rect = { x: number, y: number, w: number, h: number }

export type Blanket = {
	width: number, -- pixels = grid cells
	depth: number,
	k: number, -- grid cells per sensor cell side
	explored: buffer, -- u8 per sensor cell: seen at least once
	target: buffer, -- u8 per pixel: the state of the sensor cell it lies in (VISIBLE, EXPLORED or NEVER)
	state: buffer, -- u8 per sensor cell: its state
	cur: buffer, -- f32 × 2 per pixel: grey level, alpha
	goal: buffer, -- f32 × 2 per pixel: where it is fading to
	rgba: buffer, -- the image, 4 bytes per pixel
	queued: buffer, -- u8 per pixel: 1 while in `fading` (2, 3 during an apply)
	fading: { number }, -- pixels still moving (a queue)
	reblend: { number }, -- pixels whose goal must be worked out again (this apply)
	dirty: Rect?, -- changed since the last take
	visionVersion: number,
	stats: { fading: number, written: number },
}

local function writePixel(b: Blanket, i: number, grey: number, alpha: number)
	local t = FogBlanket.TINT
	local o = i * 4
	buffer.writeu8(b.rgba, o, math.clamp(math.floor(grey * t[1] + 0.5), 0, 255))
	buffer.writeu8(b.rgba, o + 1, math.clamp(math.floor(grey * t[2] + 0.5), 0, 255))
	buffer.writeu8(b.rgba, o + 2, math.clamp(math.floor(grey * t[3] + 0.5), 0, 255))
	buffer.writeu8(b.rgba, o + 3, math.clamp(math.floor(alpha * 255 + 0.5), 0, 255))
end

local function touch(b: Blanket, px: number, py: number)
	local r = b.dirty
	if r == nil then
		b.dirty = { x = px, y = py, w = 1, h = 1 }
		return
	end
	local x0, y0 = math.min(r.x, px), math.min(r.y, py)
	local x1, y1 = math.max(r.x + r.w, px + 1), math.max(r.y + r.h, py + 1)
	r.x, r.y, r.w, r.h = x0, y0, x1 - x0, y1 - y0
end

-- A blanket for a map of `cellsX` × `cellsZ` grid cells, `k` grid cells per
-- sensor cell: all never seen.
function FogBlanket.new(cellsX: number, cellsZ: number, k: number): Blanket
	local n = cellsX * cellsZ
	local b: Blanket = {
		width = cellsX,
		depth = cellsZ,
		k = k,
		explored = buffer.create(math.ceil(cellsX / k) * math.ceil(cellsZ / k)),
		target = buffer.create(n),
		state = buffer.create(math.ceil(cellsX / k) * math.ceil(cellsZ / k)),
		cur = buffer.create(n * 8),
		goal = buffer.create(n * 8),
		rgba = buffer.create(n * 4),
		queued = buffer.create(n),
		fading = {},
		reblend = {},
		dirty = { x = 0, y = 0, w = cellsX, h = cellsZ },
		visionVersion = -1,
		stats = { fading = 0, written = 0 },
	}
	local never = FogBlanket.LOOK.never
	buffer.fill(b.state, 0, NEVER)
	for i = 0, n - 1 do
		buffer.writeu8(b.target, i, NEVER)
		buffer.writef32(b.cur, i * 8, never.grey)
		buffer.writef32(b.cur, i * 8 + 4, never.alpha)
		buffer.writef32(b.goal, i * 8, never.grey)
		buffer.writef32(b.goal, i * 8 + 4, never.alpha)
		writePixel(b, i, never.grey, never.alpha)
	end
	return b
end

-- The state of sensor cell s.
local function stateOf(b: Blanket, v: Vision.Vision, s: number): number
	if buffer.readu16(v.seen, s * 2) > 0 then
		return VISIBLE
	end
	return if buffer.readu8(b.explored, s) > 0 then EXPLORED else NEVER
end

-- Sets the pixels of sensor cell s to their new state (fading there).
local function setCell(b: Blanket, v: Vision.Vision, s: number)
	if buffer.readu16(v.seen, s * 2) > 0 then
		buffer.writeu8(b.explored, s, 1)
	end
	local state = stateOf(b, v, s)
	if buffer.readu8(b.state, s) == state then
		return
	end
	buffer.writeu8(b.state, s, state)
	local sx, sz = s % v.width, s // v.width
	local k = b.k
	for py = sz * k, math.min(sz * k + k, b.depth) - 1 do
		for px = sx * k, math.min(sx * k + k, b.width) - 1 do
			buffer.writeu8(b.target, py * b.width + px, state)
		end
	end
	-- every pixel whose blend reaches this cell: centres within a cell of its
	-- centre, k / 2 + k + k / 2 pixels a side
	local queued, reblend = b.queued, b.reblend
	local h = k // 2
	for py = math.max(0, sz * k - h), math.min(sz * k + k + h, b.depth) - 1 do
		for px = math.max(0, sx * k - h), math.min(sx * k + k + h, b.width) - 1 do
			local i = py * b.width + px
			local q = buffer.readu8(queued, i)
			if q < 2 then
				-- 2: to reblend and join the queue; 3: to reblend, already queued
				buffer.writeu8(queued, i, if q == 0 then 2 else 3)
				reblend[#reblend + 1] = i
			end
		end
	end
end

-- Takes in Vision's changes since its last update (`v.changed`); the first
-- call (or a new vision map) reads every cell.
function FogBlanket.apply(b: Blanket, v: Vision.Vision)
	if b.visionVersion < 0 then
		for s = 0, v.width * v.depth - 1 do
			setCell(b, v, s)
		end
	else
		for _, s in v.changed do
			setCell(b, v, s)
		end
	end
	b.visionVersion = v.version
	-- new goals, once per pixel; pixels not already fading join the queue
	local fading, queued = b.fading, b.queued
	for _, i in b.reblend do
		local grey, alpha = FogBlanket.blend(b, i % b.width, i // b.width)
		buffer.writef32(b.goal, i * 8, grey)
		buffer.writef32(b.goal, i * 8 + 4, alpha)
		if buffer.readu8(queued, i) == 2 then
			fading[#fading + 1] = i
		end
		buffer.writeu8(queued, i, 1)
	end
	table.clear(b.reblend)
end

-- A pixel's look: its four nearest sensor cells' looks, weighted by
-- distance from the pixel's centre to theirs (bilinear).
function FogBlanket.blend(b: Blanket, px: number, py: number): (number, number)
	local k = b.k
	local sw, sd = math.ceil(b.width / k), math.ceil(b.depth / k)
	local fx, fz = (px + 0.5) / k - 0.5, (py + 0.5) / k - 0.5
	local x0, z0 = math.floor(fx), math.floor(fz)
	local tx, tz = fx - x0, fz - z0
	local x1, z1 = x0 + 1, z0 + 1
	if x0 < 0 then
		x0 = 0
	end
	if z0 < 0 then
		z0 = 0
	end
	if x1 >= sw then
		x1 = sw - 1
	end
	if z1 >= sd then
		z1 = sd - 1
	end
	local state = b.state
	local s00, s10 = buffer.readu8(state, z0 * sw + x0), buffer.readu8(state, z0 * sw + x1)
	local s01, s11 = buffer.readu8(state, z1 * sw + x0), buffer.readu8(state, z1 * sw + x1)
	if s00 == s10 and s00 == s01 and s00 == s11 then
		return GREY[s00], ALPHA[s00] -- the usual case: all four alike
	end
	local w00, w10, w01, w11 = (1 - tx) * (1 - tz), tx * (1 - tz), (1 - tx) * tz, tx * tz
	return GREY[s00] * w00 + GREY[s10] * w10 + GREY[s01] * w01 + GREY[s11] * w11, ALPHA[s00] * w00 + ALPHA[s10] * w10 + ALPHA[s01] * w01 + ALPHA[s11] * w11
end

-- Fades the moving pixels by `dt` seconds. Returns the rectangle of pixels
-- changed since the last call (nil if none) and clears it.
function FogBlanket.step(b: Blanket, dt: number): Rect?
	local greyStep = 255 / FogBlanket.FADE * dt
	local alphaStep = 1 / FogBlanket.FADE * dt
	local cur, goal, queued, width = b.cur, b.goal, b.queued, b.width
	local list = b.fading
	local keep: { number } = {}
	local count = math.min(#list, FogBlanket.BUDGET)
	for j = 1, count do
		local i = list[j]
		local o = i * 8
		local goalGrey, goalAlpha = buffer.readf32(goal, o), buffer.readf32(goal, o + 4)
		local g, a = buffer.readf32(cur, o), buffer.readf32(cur, o + 4)
		local dg, da = goalGrey - g, goalAlpha - a
		if math.abs(dg) < 1e-3 and math.abs(da) < 1e-5 then
			buffer.writeu8(queued, i, 0) -- its blend didn't change
			continue
		end
		g = if math.abs(dg) <= greyStep then goalGrey elseif dg > 0 then g + greyStep else g - greyStep
		a = if math.abs(da) <= alphaStep then goalAlpha elseif da > 0 then a + alphaStep else a - alphaStep
		buffer.writef32(cur, o, g)
		buffer.writef32(cur, o + 4, a)
		writePixel(b, i, g, a)
		touch(b, i % width, i // width)
		if g == goalGrey and a == goalAlpha then
			buffer.writeu8(queued, i, 0)
		else
			keep[#keep + 1] = i
		end
	end
	-- over budget: the rest wait their turn, ahead of those still fading
	local rest = table.move(list, count + 1, #list, 1, {})
	table.move(keep, 1, #keep, #rest + 1, rest)
	b.fading = rest
	b.stats.fading = #rest
	local r = b.dirty
	b.dirty = nil
	if r then
		b.stats.written += r.w * r.h
	end
	return r
end

-- The bytes of rectangle `r` of the image, rows packed (for a partial upload).
function FogBlanket.region(b: Blanket, r: Rect): buffer
	if r.x == 0 and r.w == b.width then
		local out = buffer.create(r.w * r.h * 4)
		buffer.copy(out, 0, b.rgba, r.y * b.width * 4, r.w * r.h * 4)
		return out
	end
	local out = buffer.create(r.w * r.h * 4)
	for row = 0, r.h - 1 do
		buffer.copy(out, row * r.w * 4, b.rgba, ((r.y + row) * b.width + r.x) * 4, r.w * 4)
	end
	return out
end

-- A pixel's state name and alpha (tests, debug).
function FogBlanket.pixel(b: Blanket, px: number, py: number): (string, number)
	local i = py * b.width + px
	local names = { "visible", "explored", "never" }
	return names[buffer.readu8(b.target, i)], buffer.readu8(b.rgba, i * 4 + 3) / 255
end

return FogBlanket
