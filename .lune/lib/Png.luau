--!strict
-- A small PNG reader and writer for the map tools (S-196: maps are made the
-- BAR way, from image layers). Reads non-interlaced 8- or 16-bit grey,
-- grey + alpha, RGB and RGBA; writes 8-bit grey, 8-bit RGB and 16-bit grey.
-- Lune-only (it inflates with @lune/serde's zlib).

local serde = require("@lune/serde")

local Png = {}

export type Image = {
	width: number,
	height: number,
	channels: number, -- 1 grey, 2 grey + alpha, 3 RGB, 4 RGBA
	depth: number, -- bits per sample: 8 or 16
	data: buffer, -- rows top to bottom, samples big-endian for 16-bit
}

local SIGNATURE = "\137PNG\r\n\26\n"
local CHANNELS = { [0] = 1, [2] = 3, [4] = 2, [6] = 4 }

local function paeth(a: number, b: number, c: number): number
	local p = a + b - c
	local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
	if pa <= pb and pa <= pc then
		return a
	elseif pb <= pc then
		return b
	end
	return c
end

function Png.decode(bytes: string): Image
	assert(string.sub(bytes, 1, 8) == SIGNATURE, "Png.decode: not a PNG")
	local pos = 9
	local width, height, depth, colorType = 0, 0, 0, 0
	local idat = {}
	while pos <= #bytes do
		local len = string.unpack(">I4", bytes, pos)
		local kind = string.sub(bytes, pos + 4, pos + 7)
		local body = string.sub(bytes, pos + 8, pos + 7 + len)
		pos += 12 + len
		if kind == "IHDR" then
			local interlace
			width, height, depth, colorType = string.unpack(">I4I4BB", body)
			interlace = string.byte(body, 13)
			assert(interlace == 0, "Png.decode: interlaced PNGs aren't supported")
			assert(depth == 8 or depth == 16, `Png.decode: bit depth {depth} isn't supported`)
			assert(CHANNELS[colorType], `Png.decode: colour type {colorType} isn't supported (no palettes)`)
		elseif kind == "IDAT" then
			table.insert(idat, body)
		elseif kind == "IEND" then
			break
		end
	end
	local channels = CHANNELS[colorType]
	local bpp = channels * depth // 8 -- bytes per pixel
	local stride = width * bpp
	local raw = buffer.fromstring(serde.decompress("zlib", table.concat(idat)))
	local out = buffer.create(stride * height)
	local readu8, writeu8 = buffer.readu8, buffer.writeu8
	for y = 0, height - 1 do
		local src = y * (stride + 1)
		local filter = readu8(raw, src)
		src += 1
		local dst = y * stride
		local up = dst - stride
		for x = 0, stride - 1 do
			local v = readu8(raw, src + x)
			local a = if x >= bpp then readu8(out, dst + x - bpp) else 0
			local b = if y > 0 then readu8(out, up + x) else 0
			if filter == 1 then
				v += a
			elseif filter == 2 then
				v += b
			elseif filter == 3 then
				v += (a + b) // 2
			elseif filter == 4 then
				local c = if x >= bpp and y > 0 then readu8(out, up + x - bpp) else 0
				v += paeth(a, b, c)
			end
			writeu8(out, dst + x, v % 256)
		end
	end
	return { width = width, height = height, channels = channels, depth = depth, data = out }
end

-- Sample `channel` (1-based) of pixel (x, y), as 0..1 (16-bit samples are
-- big-endian).
function Png.sample(img: Image, x: number, y: number, channel: number?): number
	local ch = (channel or 1) - 1
	local i = (y * img.width + x) * img.channels + ch
	if img.depth == 16 then
		return (buffer.readu8(img.data, i * 2) * 256 + buffer.readu8(img.data, i * 2 + 1)) / 65535
	end
	return buffer.readu8(img.data, i) / 255
end

-- RGB of pixel (x, y), 0..255 each (grey images give the grey three times).
function Png.rgb(img: Image, x: number, y: number): (number, number, number)
	if img.channels <= 2 then
		local v = math.floor(Png.sample(img, x, y, 1) * 255 + 0.5)
		return v, v, v
	end
	return math.floor(Png.sample(img, x, y, 1) * 255 + 0.5), math.floor(Png.sample(img, x, y, 2) * 255 + 0.5), math.floor(Png.sample(img, x, y, 3) * 255 + 0.5)
end

local crcTable: { number }? = nil
local function crc32(s: string): number
	local t = crcTable
	if t == nil then
		t = {}
		for n = 0, 255 do
			local c = n
			for _ = 1, 8 do
				c = if bit32.band(c, 1) ~= 0 then bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else bit32.rshift(c, 1)
			end
			t[n] = c
		end
		crcTable = t
	end
	local tt = t :: { number }
	local c = 0xFFFFFFFF
	for i = 1, #s do
		c = bit32.bxor(tt[bit32.band(bit32.bxor(c, string.byte(s, i)), 0xFF)], bit32.rshift(c, 8))
	end
	return bit32.bxor(c, 0xFFFFFFFF)
end

local function chunk(kind: string, body: string): string
	return string.pack(">I4", #body) .. kind .. body .. string.pack(">I4", crc32(kind .. body))
end

-- Encodes `img` (1 or 3 channels, 8-bit; or 1 channel, 16-bit) as a PNG.
function Png.encode(img: Image): string
	local colorType = if img.channels == 1 then 0 elseif img.channels == 3 then 2 else error("Png.encode: 1 or 3 channels")
	assert(img.depth == 8 or (img.depth == 16 and img.channels == 1), "Png.encode: 8-bit, or 16-bit grey")
	local stride = img.width * img.channels * img.depth // 8
	local rows = table.create(img.height)
	for y = 0, img.height - 1 do
		rows[y + 1] = "\0" .. buffer.readstring(img.data, y * stride, stride) -- filter 0
	end
	local ihdr = string.pack(">I4I4BBBBB", img.width, img.height, img.depth, colorType, 0, 0, 0)
	return SIGNATURE .. chunk("IHDR", ihdr) .. chunk("IDAT", serde.compress("zlib", table.concat(rows))) .. chunk("IEND", "")
end

-- A new blank image.
function Png.new(width: number, height: number, channels: number, depth: number?): Image
	local d = depth or 8
	return { width = width, height = height, channels = channels, depth = d, data = buffer.create(width * height * channels * d // 8) }
end

return Png
