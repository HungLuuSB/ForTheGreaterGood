--!strict
-- Base64 (RFC 4648, with "=" padding) into a buffer. Pure Luau, the same in
-- both runtimes (CLAUDE.md): compiled maps keep their layers as Base64 text
-- (S-196).

local Base64 = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE: { [number]: number } = {}
for i = 1, 64 do
	VALUE[string.byte(ALPHABET, i)] = i - 1
end

function Base64.decode(text: string): buffer
	local n = #text
	local pad = 0
	if n > 0 and string.byte(text, n) == 61 then
		pad += 1
		if string.byte(text, n - 1) == 61 then
			pad += 1
		end
	end
	local out = buffer.create(n // 4 * 3 - pad)
	local len = buffer.len(out)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local v = bit32.lshift(VALUE[a], 18) + bit32.lshift(VALUE[b], 12) + bit32.lshift(VALUE[c] or 0, 6) + (VALUE[d] or 0)
		buffer.writeu8(out, o, bit32.rshift(v, 16))
		if o + 1 < len then
			buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 0xFF))
		end
		if o + 2 < len then
			buffer.writeu8(out, o + 2, bit32.band(v, 0xFF))
		end
		o += 3
	end
	return out
end

function Base64.encode(data: buffer): string
	local parts = {}
	local len = buffer.len(data)
	for i = 0, len - 1, 3 do
		local a = buffer.readu8(data, i)
		local b = if i + 1 < len then buffer.readu8(data, i + 1) else 0
		local c = if i + 2 < len then buffer.readu8(data, i + 2) else 0
		local v = a * 65536 + b * 256 + c
		local c1 = bit32.rshift(v, 18) + 1
		local c2 = bit32.band(bit32.rshift(v, 12), 63) + 1
		local c3 = bit32.band(bit32.rshift(v, 6), 63) + 1
		local c4 = bit32.band(v, 63) + 1
		table.insert(parts, string.sub(ALPHABET, c1, c1) .. string.sub(ALPHABET, c2, c2) .. (if i + 1 < len then string.sub(ALPHABET, c3, c3) else "=") .. (if i + 2 < len then string.sub(ALPHABET, c4, c4) else "="))
	end
	return table.concat(parts)
end

return Base64
