--!strict
local Prng = require("@shared/Util/Prng")
local Tick = require("@shared/Net/Tick")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	t.test("toWire wraps at 2^16", function()
		t.equal(Tick.toWire(0), 0)
		t.equal(Tick.toWire(65535), 65535)
		t.equal(Tick.toWire(65536), 0)
		t.equal(Tick.toWire(70000), 70000 - 65536)
		t.throws(function()
			Tick.toWire(-1)
		end, "integer >= 0")
	end)

	t.test("diff and isNewer across the wrap", function()
		t.equal(Tick.diff(5, 3), 2)
		t.equal(Tick.diff(3, 5), -2)
		t.equal(Tick.diff(0, 65535), 1, "0 comes right after 65535")
		t.equal(Tick.diff(65535, 0), -1)
		t.equal(Tick.diff(2, 65530), 8)
		t.equal(Tick.diff(100, 100), 0)
		t.equal(Tick.diff(32767, 0), 32767, "largest forward distance")
		t.equal(Tick.diff(0, 32768), -32768, "exactly half a wrap counts as older")
		t.equal(Tick.diff(32768, 0), -32768)

		t.expect(Tick.isNewer(0, 65535), "0 is newer than 65535")
		t.expect(not Tick.isNewer(65535, 0), "65535 is older than 0")
		t.expect(not Tick.isNewer(7, 7), "a tick is not newer than itself")
		t.expect(Tick.isNewer(10, 65000), "10 is newer than 65000 after a wrap")
	end)

	t.test("unwrap recovers the full sim tick near a reference", function()
		t.equal(Tick.unwrap(Tick.toWire(65540), 65530), 65540, "just after the wrap")
		t.equal(Tick.unwrap(Tick.toWire(65530), 65540), 65530, "late packet from before the wrap")
		t.equal(Tick.unwrap(Tick.toWire(1000000), 1000000), 1000000)
		t.equal(Tick.unwrap(Tick.toWire(10), 20), 10)
	end)

	t.test("randomized: diff matches the true distance within half a wrap", function()
		local rng = Prng.new(1515)
		for _ = 1, 1000 do
			local a = rng:nextInteger(0, 10000000)
			local delta = rng:nextInteger(-32767, 32767)
			local b = a + delta
			if b >= 0 then
				local wa, wb = Tick.toWire(a), Tick.toWire(b)
				t.equal(Tick.diff(wb, wa), delta, `diff({b}, {a})`)
				t.equal(Tick.isNewer(wb, wa), delta > 0)
				t.equal(Tick.unwrap(wb, a), b, `unwrap({b}) near {a}`)
			end
		end
	end)
end
