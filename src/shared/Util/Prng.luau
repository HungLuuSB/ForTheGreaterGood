--!strict
-- Seeded, deterministic PRNG: xoshiro128** seeded through splitmix32.
-- Pure Luau on doubles + bit32, so Roblox and Lune produce bit-identical
-- sequences for the same seed. The sim's only source of randomness: never use
-- math.random or Random.new in gameplay logic.
--
-- Every intermediate value stays below 2^53, so double arithmetic is exact.

local band = bit32.band
local bxor = bit32.bxor
local lshift = bit32.lshift
local rshift = bit32.rshift
local lrotate = bit32.lrotate

local TWO_32 = 4294967296

-- (a * b) mod 2^32 for u32 a, b. A plain a * b can reach 2^64 and lose bits.
local function mul32(a: number, b: number): number
	local hi = rshift(b, 16)
	local lo = band(b, 0xFFFF)
	return (((a * hi) % 0x10000) * 0x10000 + a * lo) % TWO_32
end

local Prng = {}
Prng.__index = Prng

type PrngData = { _s0: number, _s1: number, _s2: number, _s3: number }
export type Prng = typeof(setmetatable({} :: PrngData, Prng))

-- seed: integer in [0, 2^32). Store it in the replay header to reproduce a match.
function Prng.new(seed: number): Prng
	assert(
		type(seed) == "number" and seed == math.floor(seed) and seed >= 0 and seed < TWO_32,
		"Prng.new: seed must be an integer in [0, 2^32)"
	)
	-- splitmix32 (golden-ratio step + murmur3 fmix32) spreads one seed over
	-- four state words. The four inputs are distinct and fmix32 is a bijection,
	-- so the words are distinct too and the state can never be all zero.
	local x = seed
	local s = table.create(4, 0)
	for i = 1, 4 do
		x = (x + 0x9E3779B9) % TWO_32
		local z = x
		z = mul32(bxor(z, rshift(z, 16)), 0x85EBCA6B)
		z = mul32(bxor(z, rshift(z, 13)), 0xC2B2AE35)
		s[i] = bxor(z, rshift(z, 16))
	end
	return setmetatable({ _s0 = s[1], _s1 = s[2], _s2 = s[3], _s3 = s[4] }, Prng)
end

-- Restores a generator from getState() output (snapshots, reference vectors).
function Prng.fromState(s0: number, s1: number, s2: number, s3: number): Prng
	assert(s0 ~= 0 or s1 ~= 0 or s2 ~= 0 or s3 ~= 0, "Prng.fromState: state must not be all zero")
	return setmetatable({ _s0 = band(s0), _s1 = band(s1), _s2 = band(s2), _s3 = band(s3) }, Prng)
end

function Prng.getState(self: Prng): (number, number, number, number)
	return self._s0, self._s1, self._s2, self._s3
end

-- Integer in [0, 2^32).
function Prng.nextU32(self: Prng): number
	local s0, s1, s2, s3 = self._s0, self._s1, self._s2, self._s3
	local result = (lrotate((s1 * 5) % TWO_32, 7) * 9) % TWO_32
	local t = lshift(s1, 9)
	s2 = bxor(s2, s0)
	s3 = bxor(s3, s1)
	s1 = bxor(s1, s2)
	s0 = bxor(s0, s3)
	s2 = bxor(s2, t)
	s3 = lrotate(s3, 11)
	self._s0, self._s1, self._s2, self._s3 = s0, s1, s2, s3
	return result
end

-- Integer in [min, max], both inclusive, without modulo bias.
function Prng.nextInteger(self: Prng, min: number, max: number): number
	local range = max - min + 1
	assert(
		min == math.floor(min) and max == math.floor(max) and range >= 1 and range <= TWO_32,
		"Prng.nextInteger: need integers with 1 <= max - min + 1 <= 2^32"
	)
	-- Reject the top partial bucket so every value is equally likely.
	local limit = TWO_32 - (TWO_32 % range)
	local r = self:nextU32()
	while r >= limit do
		r = self:nextU32()
	end
	return min + r % range
end

-- Number in [min, max); defaults to [0, 1). 32 bits of resolution.
function Prng.nextNumber(self: Prng, min: number?, max: number?): number
	local lo = min or 0
	local hi = max or 1
	return lo + (hi - lo) * (self:nextU32() / TWO_32)
end

-- true with probability p (countermeasure rolls, accuracy spread...).
function Prng.chance(self: Prng, p: number): boolean
	return self:nextU32() / TWO_32 < p
end

return Prng
