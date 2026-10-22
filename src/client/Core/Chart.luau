--!strict
-- Line charts for the statistics panel (C-105), pure: downsampling, axis
-- numbers and a rasterizer that draws anti-aliased polylines into an RGBA
-- buffer (UI/Kit shows it in one EditableImage per chart; measured cheaper
-- than a Frame per segment, see C-105).

local Chart = {}

Chart.MAX_POINTS = 120 -- per line, after downsampling
Chart.WIDTH = 1.6 -- line width (pixels)

-- Largest-Triangle-Three-Buckets: at most `max` points keeping the line's
-- shape (first and last kept).
function Chart.downsample(xs: { number }, ys: { number }, max: number?): ({ number }, { number })
	local m = max or Chart.MAX_POINTS
	local n = #xs
	if n <= m or m < 3 then
		return table.clone(xs), table.clone(ys)
	end
	local ox, oy = { xs[1] }, { ys[1] }
	local every = (n - 2) / (m - 2)
	local a = 1
	for i = 0, m - 3 do
		-- the next bucket's average point
		local s, e = math.floor((i + 1) * every) + 2, math.min(math.floor((i + 2) * every) + 2, n + 1) - 1
		if i == m - 3 then
			s, e = n, n
		end
		local avx, avy, cnt = 0, 0, 0
		for j = s, e do
			avx += xs[j]
			avy += ys[j]
			cnt += 1
		end
		avx, avy = avx / math.max(cnt, 1), avy / math.max(cnt, 1)
		-- in this bucket, the point making the largest triangle with a and the average
		local bs, be = math.floor(i * every) + 2, math.floor((i + 1) * every) + 1
		local best, pick = -1, bs
		for j = bs, be do
			local area = math.abs((xs[a] - avx) * (ys[j] - ys[a]) - (xs[a] - xs[j]) * (avy - ys[a]))
			if area > best then
				best, pick = area, j
			end
		end
		table.insert(ox, xs[pick])
		table.insert(oy, ys[pick])
		a = pick
	end
	table.insert(ox, xs[n])
	table.insert(oy, ys[n])
	return ox, oy
end

-- The axis top: the next 1, 2 or 5 × 10^n at or above `v` (1 for 0).
function Chart.niceMax(v: number): number
	if v <= 0 then
		return 1
	end
	local p = 10 ^ math.floor(math.log10(v))
	for _, k in { 1, 2, 5, 10 } do
		if k * p >= v - 1e-9 then
			return k * p
		end
	end
	return 10 * p
end

-- 950, 1.5k, 20k, 3M.
function Chart.format(v: number): string
	local a = math.abs(v)
	local function short(x: number, unit: string): string
		local s = if x < 10 and x ~= math.floor(x) then string.format("%.1f", x) else tostring(math.floor(x + 0.5))
		return s .. unit
	end
	if a >= 1e6 then
		return short(v / 1e6, "M")
	elseif a >= 1e3 then
		return short(v / 1e3, "k")
	end
	return tostring(math.floor(v + 0.5))
end

function Chart.clock(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds) % 60)
end

export type Line = { xs: { number }, ys: { number }, r: number, g: number, b: number }

-- Draws `lines` into `buf` (w × h RGBA, transparent where nothing is),
-- x in 0..xMax left to right, y in 0..yMax bottom to top, one pixel inset.
-- Each line's coverage is the max over its segments (no dark joints), then
-- it is laid over what is there.
function Chart.raster(buf: buffer, w: number, h: number, lines: { Line }, xMax: number, yMax: number)
	buffer.fill(buf, 0, 0, w * h * 4)
	local cover = buffer.create(w * h)
	local half = Chart.WIDTH / 2
	local sx, sy = (w - 2) / math.max(xMax, 1e-9), (h - 2) / math.max(yMax, 1e-9)
	for _, line in lines do
		buffer.fill(cover, 0, 0, w * h)
		local xs, ys = line.xs, line.ys
		for i = 1, #xs - 1 do
			local x0, y0 = 1 + xs[i] * sx, h - 1 - ys[i] * sy
			local x1, y1 = 1 + xs[i + 1] * sx, h - 1 - ys[i + 1] * sy
			local dx, dy = x1 - x0, y1 - y0
			local len2 = dx * dx + dy * dy
			local minX = math.max(0, math.floor(math.min(x0, x1) - half - 1))
			local maxX = math.min(w - 1, math.ceil(math.max(x0, x1) + half + 1))
			local minY = math.max(0, math.floor(math.min(y0, y1) - half - 1))
			local maxY = math.min(h - 1, math.ceil(math.max(y0, y1) + half + 1))
			for py = minY, maxY do
				for px = minX, maxX do
					local cx, cy = px + 0.5, py + 0.5
					local t = if len2 > 0 then math.clamp(((cx - x0) * dx + (cy - y0) * dy) / len2, 0, 1) else 0
					local ex, ey = cx - (x0 + t * dx), cy - (y0 + t * dy)
					local d = math.sqrt(ex * ex + ey * ey)
					local c = math.clamp(half + 0.5 - d, 0, 1)
					if c > 0 then
						local o = py * w + px
						local v = math.floor(c * 255 + 0.5)
						if v > buffer.readu8(cover, o) then
							buffer.writeu8(cover, o, v)
						end
					end
				end
			end
		end
		-- lay it over
		for o = 0, w * h - 1 do
			local a = buffer.readu8(cover, o)
			if a > 0 then
				local p = o * 4
				local fa = a / 255
				local da = buffer.readu8(buf, p + 3) / 255
				local oa = fa + da * (1 - fa)
				local function mix(src: number, k: number): number
					return math.floor((src * fa + buffer.readu8(buf, p + k) * da * (1 - fa)) / oa + 0.5)
				end
				buffer.writeu8(buf, p, mix(line.r, 0))
				buffer.writeu8(buf, p + 1, mix(line.g, 1))
				buffer.writeu8(buf, p + 2, mix(line.b, 2))
				buffer.writeu8(buf, p + 3, math.floor(oa * 255 + 0.5))
			end
		end
	end
end

return Chart
