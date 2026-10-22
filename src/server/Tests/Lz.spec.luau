--!strict
-- Shared/Net/Lz and Shared/Net/Huffman (S-77): the replay compressors
-- round-trip anything, and refuse a cut stream.
local Huffman = require("@shared/Net/Huffman")
local Lz = require("@shared/Net/Lz")
local Prng = require("@shared/Util/Prng")
local RunAll = require("./RunAll")

local function roundTrip(t: RunAll.Context, s: string, what: string): number
	local c = Lz.compress(buffer.fromstring(s))
	t.equal(buffer.tostring(Lz.decompress(c)), s, what)
	return buffer.len(c)
end

return function(t: RunAll.Context)
	t.test("round trips: empty, tiny, random, runs, repeats across the window", function()
		roundTrip(t, "", "empty")
		roundTrip(t, "abc", "shorter than a match")
		local rng = Prng.new(5)
		local parts = {}
		for _ = 1, 20000 do
			table.insert(parts, string.char(rng:nextInteger(0, 255)))
		end
		local random = table.concat(parts)
		local n = roundTrip(t, random, "random bytes")
		t.expect(n <= #random + #random // 200 + 16, `random data barely grows ({n} for {#random})`)
		local runs = string.rep("a", 5000) .. string.rep("ab", 3000) .. string.rep("\0", 70000)
		local m = roundTrip(t, runs, "runs, overlapping copies, long lengths")
		t.expect(m < #runs // 50, `runs shrink ({m} for {#runs})`)
		-- a block repeated after 60 KB (inside the window) and after 70 KB (outside)
		local block = string.sub(random, 1, 4000)
		roundTrip(t, block .. string.rep("x", 60000) .. block .. string.rep("y", 70000) .. block, "repeats near and past the window")
	end)

	t.test("a cut stream is refused with a clear error", function()
		-- (damage inside a stream isn't always detectable here: PlayerReplay
		-- checks a hash of what it decompresses)
		local c = buffer.tostring(Lz.compress(buffer.fromstring(string.rep("hello world ", 500))))
		t.throws(function()
			Lz.decompress(buffer.fromstring(string.sub(c, 1, #c - 3)))
		end, "truncated or corrupt")
	end)

	t.test("Huffman round-trips skewed and tiny inputs across blocks", function()
		local rng = Prng.new(9)
		local skewed = {}
		for _ = 1, 150000 do
			-- mostly small values: a long-tailed distribution, so some codes get long
			local v = math.min(255, math.floor(-math.log(1 - rng:nextNumber(0, 0.999999)) * 3))
			table.insert(skewed, string.char(v))
		end
		local s = table.concat(skewed)
		local h = Huffman.encode(buffer.fromstring(s))
		t.equal(buffer.tostring(Huffman.decode(h)), s, "skewed, three blocks")
		t.expect(buffer.len(h) < #s * 0.6, `skewed data shrinks ({buffer.len(h)} for {#s})`)
		for _, x in { "", "a", "aaaa", "ab" } do
			t.equal(buffer.tostring(Huffman.decode(Huffman.encode(buffer.fromstring(x)))), x, `tiny input "{x}"`)
		end
		t.throws(function()
			Huffman.decode(buffer.fromstring(string.sub(buffer.tostring(h), 1, 200)))
		end, "truncated or corrupt")
	end)
end
