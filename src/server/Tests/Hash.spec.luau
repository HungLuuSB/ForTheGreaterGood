--!strict
local Hash = require("@shared/Util/Hash")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	-- Published FNV-1a 32-bit test vectors.
	t.test("fnv1a matches the reference vectors", function()
		t.equal(Hash.fnv1a(""), 0x811C9DC5)
		t.equal(Hash.fnv1a("a"), 0xE40C292C)
		t.equal(Hash.fnv1a("foobar"), 0xBF9CF968)
	end)

	t.test("u32 hashes the same bytes as the little-endian string", function()
		local n = 0x89ABCDEF
		t.equal(Hash.u32(Hash.OFFSET_BASIS, n), Hash.fnv1a(string.pack("<I4", n)))
		t.equal(Hash.u32(Hash.OFFSET_BASIS, 0), Hash.fnv1a(string.pack("<I4", 0)))
	end)

	t.test("value is independent of table construction order", function()
		local a = { x = 1, y = { 2, 3 }, z = "s" }
		local b = {}
		b.z = "s"
		b.y = { 2, 3 }
		b.x = 1
		t.equal(Hash.value(a), Hash.value(b))
	end)

	t.test("value tells apart types and nesting", function()
		local hashes = {
			Hash.value(1),
			Hash.value("1"),
			Hash.value(true),
			Hash.value({ 1 }),
			Hash.value({ { 1 } }),
			Hash.value({ ["1"] = 1 }),
			Hash.value({ a = "bc" }),
			Hash.value({ ab = "c" }),
			Hash.value(0.1),
			Hash.value(0.1 + 1e-17 * 2),
		}
		for i = 1, #hashes do
			for j = i + 1, #hashes do
				t.notEqual(hashes[i], hashes[j], `values {i} and {j} collide`)
			end
		end
	end)

	t.test("value rejects functions", function()
		t.throws(function()
			Hash.value({ f = function() end })
		end, "unsupported type function")
	end)
end
