--!strict
-- Minimal image writer for Lune debug output: binary PPM (P6) and PNG.
-- Lune-only. PNG is what Windows can open; PPM is the simplest format to read.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Ppm = {}

export type Image = { width: number, height: number, pixels: buffer }

function Ppm.new(width: number, height: number): Image
	return { width = width, height = height, pixels = buffer.create(width * height * 3) }
end

-- Colors are 0..255 per channel; out-of-range values are clamped.
function Ppm.set(img: Image, x: number, y: number, r: number, g: number, b: number)
	if x < 0 or y < 0 or x >= img.width or y >= img.height then
		return
	end
	local o = (y * img.width + x) * 3
	buffer.writeu8(img.pixels, o, math.clamp(math.floor(r), 0, 255))
	buffer.writeu8(img.pixels, o + 1, math.clamp(math.floor(g), 0, 255))
	buffer.writeu8(img.pixels, o + 2, math.clamp(math.floor(b), 0, 255))
end

local function ensureDir(path: string)
	local dir = string.match(path, "^(.*)/[^/]+$")
	if dir and not fs.isDir(dir) then
		fs.writeDir(dir)
	end
end

-- Nearest-neighbor upscale by an integer factor.
function Ppm.scale(img: Image, factor: number): Image
	local out = Ppm.new(img.width * factor, img.height * factor)
	for y = 0, out.height - 1 do
		for x = 0, out.width - 1 do
			buffer.copy(out.pixels, (y * out.width + x) * 3, img.pixels, ((y // factor) * img.width + x // factor) * 3, 3)
		end
	end
	return out
end

function Ppm.write(img: Image, path: string)
	ensureDir(path)
	fs.writeFile(path, `P6\n{img.width} {img.height}\n255\n` .. buffer.tostring(img.pixels))
end

local crcTable: { number } = {}
for n = 0, 255 do
	local c = n
	for _ = 1, 8 do
		c = if bit32.band(c, 1) ~= 0 then bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else bit32.rshift(c, 1)
	end
	crcTable[n + 1] = c
end

local function crc32(s: string): number
	local c = 0xFFFFFFFF
	for i = 1, #s do
		c = bit32.bxor(crcTable[bit32.band(bit32.bxor(c, string.byte(s, i)), 0xFF) + 1], bit32.rshift(c, 8))
	end
	return bit32.bxor(c, 0xFFFFFFFF)
end

local function chunk(tag: string, body: string): string
	return string.pack(">I4", #body) .. tag .. body .. string.pack(">I4", crc32(tag .. body))
end

function Ppm.writePng(img: Image, path: string)
	ensureDir(path)
	local rowBytes = img.width * 3
	local rows = table.create(img.height)
	for y = 0, img.height - 1 do
		rows[y + 1] = "\0" .. buffer.readstring(img.pixels, y * rowBytes, rowBytes)
	end
	local header = string.pack(">I4I4BBBBB", img.width, img.height, 8, 2, 0, 0, 0)
	local png = "\137PNG\r\n\26\n"
		.. chunk("IHDR", header)
		.. chunk("IDAT", serde.compress("zlib", table.concat(rows)))
		.. chunk("IEND", "")
	fs.writeFile(path, png)
end

return Ppm
