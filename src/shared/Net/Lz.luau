--!strict
-- A small LZ77 compressor in pure Luau (S-77): the LZ4 block layout, for
-- player replay files (PlayerReplay format 2). Greedy matching through a
-- hash of the next 4 bytes; a 64 KB window. No entropy coding: it relies on
-- PlayerReplay's delta transforms to make repeats out of slowly changing
-- records.
--
-- Stream: originalLength varint, then sequences of
--   token u8 (literal count in the high nibble, match length - 4 in the
--   low; 15 = more bytes follow, each 255 adding, the last one < 255) |
--   [literal count extension] | literals | offset u16 (1..65535) |
--   [match length extension]
-- The last sequence has literals only.

local Lz = {}

local MIN_MATCH = 4
local HASH_BITS = 16
local HASH_SIZE = 2 ^ HASH_BITS
local WINDOW = 65535
local band, bxor, rshift, lshift = bit32.band, bit32.bxor, bit32.rshift, bit32.lshift
local readu8, readu32, writeu8 = buffer.readu8, buffer.readu32, buffer.writeu8

local function hash(v: number): number
	-- Knuth's multiplicative hash of the 4 bytes, top HASH_BITS bits
	return rshift(band(v * 2654435761, 0xFFFFFFFF), 32 - HASH_BITS)
end

-- Growable output buffer.
type Out = { buf: buffer, len: number }
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
local function put(o: Out, b: number)
	ensure(o, 1)
	writeu8(o.buf, o.len, b)
	o.len += 1
end
local function putLength(o: Out, n: number)
	while n >= 255 do
		put(o, 255)
		n -= 255
	end
	put(o, n)
end

function Lz.compress(src: buffer): buffer
	local n = buffer.len(src)
	local o: Out = { buf = buffer.create(math.max(64, n // 2)), len = 0 }
	local v = n
	repeat
		local b = v % 128
		v = v // 128
		put(o, if v > 0 then b + 128 else b)
	until v == 0
	local table_: { number } = table.create(HASH_SIZE, -1)
	local anchor = 0 -- first literal not yet written
	local i = 0
	local limit = n - MIN_MATCH -- last position a match may start at
	local function emit(litStart: number, litLen: number, offset: number, matchLen: number)
		local ml = matchLen - MIN_MATCH
		local token = lshift(math.min(litLen, 15), 4) + (if offset > 0 then math.min(ml, 15) else 0)
		put(o, token)
		if litLen >= 15 then
			putLength(o, litLen - 15)
		end
		ensure(o, litLen)
		buffer.copy(o.buf, o.len, src, litStart, litLen)
		o.len += litLen
		if offset > 0 then
			put(o, offset % 256)
			put(o, offset // 256)
			if ml >= 15 then
				putLength(o, ml - 15)
			end
		end
	end
	while i <= limit do
		local word = readu32(src, i)
		local h = hash(word) + 1
		local cand = table_[h]
		table_[h] = i
		if cand >= 0 and i - cand <= WINDOW and readu32(src, cand) == word then
			-- extend the match
			local len = MIN_MATCH
			while i + len < n and readu8(src, cand + len) == readu8(src, i + len) do
				len += 1
			end
			emit(anchor, i - anchor, i - cand, len)
			-- index a few positions inside the match so later repeats find it
			local stop = math.min(i + len, limit + 1)
			local j = i + 1
			while j < stop do
				table_[hash(readu32(src, j)) + 1] = j
				j += if len > 32 then 4 else 1
			end
			i += len
			anchor = i
		else
			i += 1
		end
	end
	emit(anchor, n - anchor, 0, 0)
	local out = buffer.create(o.len)
	buffer.copy(out, 0, o.buf, 0, o.len)
	return out
end

-- Errors "Lz: truncated or corrupt data" on a cut or damaged stream.
function Lz.decompress(src: buffer): buffer
	local total = buffer.len(src)
	local function corrupt(): never
		error("Lz: truncated or corrupt data", 3)
	end
	local p = 0
	local function byte(): number
		if p >= total then
			corrupt()
		end
		local b = readu8(src, p)
		p += 1
		return b
	end
	local n, scale = 0, 1
	for _ = 1, 8 do
		local b = byte()
		n += (b % 128) * scale
		if b < 128 then
			break
		end
		scale *= 128
	end
	local out = buffer.create(n)
	local q = 0
	while p < total do
		local token = byte()
		local lit = rshift(token, 4)
		if lit == 15 then
			repeat
				local b = byte()
				lit += b
			until b ~= 255
		end
		if lit > 0 then
			if p + lit > total or q + lit > n then
				corrupt()
			end
			buffer.copy(out, q, src, p, lit)
			p += lit
			q += lit
		end
		if p >= total then
			break -- the last sequence: literals only
		end
		local offset = byte() + byte() * 256
		local ml = band(token, 15)
		if ml == 15 then
			repeat
				local b = byte()
				ml += b
			until b ~= 255
		end
		ml += MIN_MATCH
		local from = q - offset
		if offset == 0 or from < 0 or q + ml > n then
			corrupt()
		end
		if offset >= ml then
			buffer.copy(out, q, out, from, ml)
		else
			for k = 0, ml - 1 do -- overlapping copy: a run
				writeu8(out, q + k, readu8(out, from + k))
			end
		end
		q += ml
	end
	if q ~= n then
		corrupt()
	end
	return out
end

local _ = bxor
return Lz
