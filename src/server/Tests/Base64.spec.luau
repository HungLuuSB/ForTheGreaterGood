--!strict
-- Shared/Util/Base64 (S-196: compiled maps keep their layers as Base64).
local Base64 = require("@shared/Util/Base64")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	t.test("Base64 round-trips every length and matches RFC 4648", function()
		t.equal(Base64.encode(buffer.fromstring("Man")), "TWFu")
		t.equal(Base64.encode(buffer.fromstring("Ma")), "TWE=")
		t.equal(Base64.encode(buffer.fromstring("M")), "TQ==")
		t.equal(buffer.tostring(Base64.decode("TWFu")), "Man")
		t.equal(buffer.tostring(Base64.decode("TWE=")), "Ma")
		t.equal(buffer.tostring(Base64.decode("TQ==")), "M")
		for len = 0, 40 do
			local b = buffer.create(len)
			for i = 0, len - 1 do
				buffer.writeu8(b, i, (i * 37 + len) % 256)
			end
			t.equal(buffer.tostring(Base64.decode(Base64.encode(b))), buffer.tostring(b), `length {len}`)
		end
	end)
end
