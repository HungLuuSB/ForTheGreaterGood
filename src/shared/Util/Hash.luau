--!strict
-- FNV-1a (32-bit) hashing for determinism checks: the defs hash (guide 4.5)
-- and world-state hashes (guide 17.1). Not cryptographic.
--
-- Pure Luau on doubles + bit32, so every runtime produces the same value.
-- Numbers are hashed by their exact IEEE-754 bits (string.pack), never by a
-- formatted string, so platform printf differences can't leak in.

local band = bit32.band
local bxor = bit32.bxor
local rshift = bit32.rshift
local byte = string.byte
local pack = string.pack

local TWO_32 = 4294967296
local OFFSET_BASIS = 0x811C9DC5
local PRIME = 0x01000193

local Hash = {}

Hash.OFFSET_BASIS = OFFSET_BASIS

-- (a * b) mod 2^32 for u32 a, b, exact in doubles.
local function mul32(a: number, b: number): number
	local hi = rshift(b, 16)
	local lo = band(b, 0xFFFF)
	return (((a * hi) % 0x10000) * 0x10000 + a * lo) % TWO_32
end
Hash.mul32 = mul32

-- Continues hash state h over the bytes of s.
function Hash.string(h: number, s: string): number
	for i = 1, #s do
		h = mul32(bxor(h, byte(s, i)), PRIME)
	end
	return h
end

-- Continues hash state h over one number (its 8 IEEE-754 bytes).
function Hash.number(h: number, n: number): number
	return Hash.string(h, pack("<d", n))
end

-- Continues hash state h over a u32 (4 bytes, little-endian). Faster than
-- Hash.number for integer state such as IDs and counters.
function Hash.u32(h: number, n: number): number
	for _ = 1, 4 do
		h = mul32(bxor(h, n % 256), PRIME)
		n = n // 256
	end
	return h
end

-- FNV-1a of a whole string, from the standard offset basis.
function Hash.fnv1a(s: string): number
	return Hash.string(OFFSET_BASIS, s)
end

-- Canonical hash of a plain data value (nil, boolean, number, string, table).
-- Table keys are visited in sorted order, so the result never depends on
-- pairs() order. Functions and other types are rejected.
local function keyLess(a: any, b: any): boolean
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return ta < tb -- "number" < "string"
	end
	return a < b
end

local function value(h: number, v: any): number
	local t = type(v)
	if t == "nil" then
		return Hash.string(h, "n")
	elseif t == "boolean" then
		return Hash.string(h, if v then "T" else "F")
	elseif t == "number" then
		return Hash.number(Hash.string(h, "#"), v)
	elseif t == "string" then
		return Hash.string(Hash.u32(Hash.string(h, "s"), #v), v)
	elseif t == "table" then
		local keys = {}
		for k in v do
			local kt = type(k)
			if kt ~= "string" and kt ~= "number" then
				error(`Hash.value: unsupported table key type {kt}`, 0)
			end
			table.insert(keys, k)
		end
		table.sort(keys, keyLess)
		h = Hash.u32(Hash.string(h, "{"), #keys)
		for _, k in keys do
			h = value(h, k)
			h = value(h, v[k])
		end
		return Hash.string(h, "}")
	end
	error(`Hash.value: unsupported type {t}`, 0)
end

function Hash.value(v: any, h: number?): number
	return value(h or OFFSET_BASIS, v)
end

return table.freeze(Hash)
