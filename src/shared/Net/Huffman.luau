--!strict
-- Order-0 canonical Huffman coding of bytes in pure Luau (S-77): the
-- entropy stage after Shared/Net/Lz for player replay files (format 2).
-- The input goes in blocks of BLOCK bytes, each with its own code:
--   blockLength varint (0 ends the stream) | 128 bytes: the 256 code
--   lengths as nibbles (0 = absent, 1..15) | the codes, bit-packed LSB
--   first (each code written bit-reversed, so a decoder peeks MAX_BITS
--   bits and looks the symbol up in a table) | padding to a byte
-- Code lengths are limited to MAX_BITS by halving the counts until the
-- tree fits.

local Huffman = {}

local BLOCK = 65536
local MAX_BITS = 15
local readu8, writeu8 = buffer.readu8, buffer.writeu8
local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

-- Code lengths for counts[0..255] (0 for absent symbols).
local function codeLengths(counts: { number }): { number }
	local lengths = table.create(256, 0)
	while true do
		-- nodes: { weight, symbol or -1, left, right }
		local heap: { { any } } = {}
		local function push(node: { any })
			table.insert(heap, node)
			local i = #heap
			while i > 1 do
				local p = i // 2
				local a, b = heap[p], heap[i]
				if a[1] < b[1] or (a[1] == b[1] and a[5] <= b[5]) then
					break
				end
				heap[p], heap[i] = b, a
				i = p
			end
		end
		local function pop(): { any }
			local top = heap[1]
			local last = table.remove(heap) :: { any }
			if #heap > 0 then
				heap[1] = last
				local i = 1
				while true do
					local l, r = i * 2, i * 2 + 1
					local m = i
					local function less(x: { any }, y: { any }): boolean
						return x[1] < y[1] or (x[1] == y[1] and x[5] < y[5])
					end
					if l <= #heap and less(heap[l], heap[m]) then
						m = l
					end
					if r <= #heap and less(heap[r], heap[m]) then
						m = r
					end
					if m == i then
						break
					end
					heap[m], heap[i] = heap[i], heap[m]
					i = m
				end
			end
			return top
		end
		local order = 0
		for s = 0, 255 do
			if counts[s + 1] > 0 then
				order += 1
				push({ counts[s + 1], s, nil, nil, order })
			end
		end
		for s = 0, 255 do
			lengths[s + 1] = 0
		end
		if #heap == 0 then
			return lengths
		elseif #heap == 1 then
			lengths[heap[1][2] + 1] = 1
			return lengths
		end
		while #heap > 1 do
			local a, b = pop(), pop()
			order += 1
			push({ a[1] + b[1], -1, a, b, order })
		end
		local tooLong = false
		local function walk(node: { any }, depth: number)
			if node[2] >= 0 then
				lengths[node[2] + 1] = depth
				if depth > MAX_BITS then
					tooLong = true
				end
			else
				walk(node[3], depth + 1)
				walk(node[4], depth + 1)
			end
		end
		walk(heap[1], 0)
		if not tooLong then
			return lengths
		end
		for s = 1, 256 do
			if counts[s] > 0 then
				counts[s] = math.max(1, counts[s] // 2)
			end
		end
	end
end

-- Canonical codes (bit-reversed for LSB-first packing) from lengths.
local function codes(lengths: { number }): { number }
	local blCount = table.create(MAX_BITS + 1, 0)
	for s = 1, 256 do
		if lengths[s] > 0 then
			blCount[lengths[s] + 1] += 1
		end
	end
	local nextCode = table.create(MAX_BITS + 2, 0)
	local code = 0
	for bits = 1, MAX_BITS do
		code = lshift(code + blCount[bits], 1)
		nextCode[bits + 1] = code
	end
	local out = table.create(256, 0)
	for s = 1, 256 do
		local len = lengths[s]
		if len > 0 then
			local c = nextCode[len + 1]
			nextCode[len + 1] += 1
			-- reverse `len` bits
			local r = 0
			for _ = 1, len do
				r = bor(lshift(r, 1), band(c, 1))
				c = rshift(c, 1)
			end
			out[s] = r
		end
	end
	return out
end

type Out = { buf: buffer, len: number, acc: number, bits: number }
local function ensure(o: Out, extra: number)
	local need = o.len + extra
	local cap = buffer.len(o.buf)
	if need > cap then
		while cap < need do
			cap *= 2
		end
		local nb = buffer.create(cap)
		buffer.copy(nb, 0, o.buf, 0, o.len)
		o.buf = nb
	end
end
local function putByte(o: Out, b: number)
	ensure(o, 1)
	writeu8(o.buf, o.len, b)
	o.len += 1
end
local function putVarint(o: Out, n: number)
	repeat
		local b = n % 128
		n = n // 128
		putByte(o, if n > 0 then b + 128 else b)
	until n == 0
end

function Huffman.encode(src: buffer): buffer
	local n = buffer.len(src)
	local o: Out = { buf = buffer.create(math.max(64, n)), len = 0, acc = 0, bits = 0 }
	local start = 0
	while start < n do
		local len = math.min(BLOCK, n - start)
		local counts = table.create(256, 0)
		for i = start, start + len - 1 do
			local b = readu8(src, i) + 1
			counts[b] += 1
		end
		local lengths = codeLengths(counts)
		local code = codes(lengths)
		putVarint(o, len)
		for s = 1, 256, 2 do
			putByte(o, lengths[s] + lengths[s + 1] * 16)
		end
		ensure(o, len * 2 + 8)
		local buf = o.buf
		local acc, bits, pos = 0, 0, o.len
		for i = start, start + len - 1 do
			local s = readu8(src, i) + 1
			acc = bor(acc, lshift(code[s], bits))
			bits += lengths[s]
			while bits >= 8 do
				writeu8(buf, pos, band(acc, 255))
				pos += 1
				acc = rshift(acc, 8)
				bits -= 8
			end
		end
		if bits > 0 then
			writeu8(buf, pos, band(acc, 255))
			pos += 1
		end
		o.len = pos
		start += len
	end
	putVarint(o, 0)
	local out = buffer.create(o.len)
	buffer.copy(out, 0, o.buf, 0, o.len)
	return out
end

-- Errors "Huffman: truncated or corrupt data" on a cut or damaged stream.
function Huffman.decode(src: buffer): buffer
	local total = buffer.len(src)
	local p = 0
	local function corrupt(): never
		error("Huffman: truncated or corrupt data", 3)
	end
	local function byte(): number
		if p >= total then
			corrupt()
		end
		local b = readu8(src, p)
		p += 1
		return b
	end
	local function varint(): number
		local v, scale = 0, 1
		for _ = 1, 8 do
			local b = byte()
			v += (b % 128) * scale
			if b < 128 then
				return v
			end
			scale *= 128
		end
		return corrupt()
	end
	local parts: { buffer } = {}
	local outLen = 0
	local symOf = table.create(lshift(1, MAX_BITS), 0)
	local lenOf = table.create(lshift(1, MAX_BITS), 0)
	while true do
		local len = varint()
		if len == 0 then
			break
		end
		local lengths = table.create(256, 0)
		for s = 1, 256, 2 do
			local b = byte()
			lengths[s], lengths[s + 1] = b % 16, b // 16
		end
		local code = codes(lengths)
		local size = lshift(1, MAX_BITS)
		for i = 1, size do
			lenOf[i] = 0
		end
		for s = 1, 256 do
			local l = lengths[s]
			if l > 0 then
				local step = lshift(1, l)
				local idx = code[s]
				while idx < size do
					symOf[idx + 1] = s - 1
					lenOf[idx + 1] = l
					idx += step
				end
			end
		end
		local out = buffer.create(len)
		local acc, bits = 0, 0
		local mask = size - 1
		for i = 0, len - 1 do
			while bits < MAX_BITS do
				local b = if p < total then readu8(src, p) else 0
				p += 1
				acc = bor(acc, lshift(b, bits))
				bits += 8
			end
			local k = band(acc, mask) + 1
			local l = lenOf[k]
			if l == 0 then
				corrupt()
			end
			writeu8(out, i, symOf[k])
			acc = rshift(acc, l)
			bits -= l
		end
		-- whole bytes read ahead and not used go back
		p -= bits // 8
		if p > total then
			corrupt()
		end
		table.insert(parts, out)
		outLen += len
	end
	local out = buffer.create(outLen)
	local q = 0
	for _, part in parts do
		buffer.copy(out, q, part, 0, buffer.len(part))
		q += buffer.len(part)
	end
	return out
end

return Huffman
