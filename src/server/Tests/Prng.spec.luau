--!strict
local Prng = require("@shared/Util/Prng")
local RunAll = require("./RunAll")

local function take(rng: Prng.Prng, n: number): { number }
	local out = table.create(n)
	for i = 1, n do
		out[i] = rng:nextU32()
	end
	return out
end

return function(t: RunAll.Context)
	t.test("same seed gives the same sequence", function()
		t.deepEqual(take(Prng.new(12345), 1000), take(Prng.new(12345), 1000))
	end)

	t.test("same seed gives the same results across mixed calls", function()
		local function draw(rng: Prng.Prng): { any }
			local out = {}
			for _ = 1, 200 do
				table.insert(out, rng:nextInteger(-50, 50))
				table.insert(out, rng:nextNumber(10, 20))
				table.insert(out, rng:chance(0.3))
			end
			return out
		end
		t.deepEqual(draw(Prng.new(777)), draw(Prng.new(777)))
	end)

	t.test("different seeds give different sequences", function()
		-- Includes adjacent seeds and both ends of the seed range.
		local seeds = { 0, 1, 2, 12345, 12346, 4294967295 }
		for i, seed in seeds do
			local seq = take(Prng.new(seed), 16)
			for j = i + 1, #seeds do
				local other = take(Prng.new(seeds[j]), 16)
				local same = 0
				for k = 1, 16 do
					if seq[k] == other[k] then
						same += 1
					end
				end
				t.equal(same, 0, `seeds {seed} and {seeds[j]} share values`)
			end
		end
	end)

	-- Golden values from an independent exact-integer implementation. If these
	-- change, every recorded replay breaks.
	t.test("matches the xoshiro128** reference vector", function()
		t.deepEqual(take(Prng.fromState(1, 2, 3, 4), 5), { 11520, 0, 5927040, 70819200, 2031721883 })
	end)

	t.test("seeding matches the splitmix32 reference", function()
		t.deepEqual({ Prng.new(12345):getState() }, { 1200724404, 818072533, 996137225, 2397394836 })
		t.deepEqual(take(Prng.new(12345), 5), { 518667457, 440444462, 4232892992, 3757857622, 3939018813 })
		t.deepEqual(take(Prng.new(0), 5), { 3809008728, 1133695204, 53579671, 2891528803, 139681546 })
	end)

	t.test("getState/fromState resumes the sequence", function()
		local a = Prng.new(99)
		take(a, 10)
		local b = Prng.fromState(a:getState())
		t.deepEqual(take(b, 50), take(a, 50))
	end)

	t.test("outputs stay in range", function()
		local rng = Prng.new(4242)
		local sawMin, sawMax = false, false
		for _ = 1, 5000 do
			local u = rng:nextU32()
			t.expect(u >= 0 and u < 2 ^ 32 and u == math.floor(u), `nextU32 out of range: {u}`)
			local i = rng:nextInteger(-3, 3)
			t.expect(i >= -3 and i <= 3 and i == math.floor(i), `nextInteger out of range: {i}`)
			sawMin = sawMin or i == -3
			sawMax = sawMax or i == 3
			local f = rng:nextNumber()
			t.expect(f >= 0 and f < 1, `nextNumber out of range: {f}`)
		end
		t.expect(sawMin and sawMax, "nextInteger never hit its bounds")
	end)

	t.test("rejects invalid seeds", function()
		t.throws(function()
			Prng.new(-1)
		end, "seed must be")
		t.throws(function()
			Prng.new(1.5)
		end, "seed must be")
		t.throws(function()
			Prng.new(2 ^ 32)
		end, "seed must be")
	end)
end
