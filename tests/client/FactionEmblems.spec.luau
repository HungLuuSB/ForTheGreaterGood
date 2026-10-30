--!strict
-- 2D-E's faction emblems (C-265): one per faction, every drawn size's rect
-- inside the atlas, and the size picked for a label is the smallest drawn one
-- that covers it.

local FactionEmblems = require("../../src/client/UI/FactionEmblems")

return function(t: any)
	t.test("each faction has its emblem, every rect on the atlas", function()
		local w, h = FactionEmblems.atlasSize[1], FactionEmblems.atlasSize[2]
		for _, faction in { "order", "chaos" } do
			local key = FactionEmblems.keyOf(faction)
			t.expect(key ~= nil, `{faction} has an emblem`)
			local e = FactionEmblems.emblems[key :: string]
			for _, s in FactionEmblems.sizes do
				local r = e.rect[s]
				t.expect(r ~= nil and r[3] == s and r[4] == s, `{key} drawn at {s}`)
				t.expect(r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= w and r[2] + r[4] <= h, `{key} {s}: on the atlas`)
			end
		end
		t.equal(FactionEmblems.keyOf("neutral"), nil)
	end)

	t.test("a label takes the smallest drawn size that covers it", function()
		t.equal(FactionEmblems.pick(10), 16)
		t.equal(FactionEmblems.pick(30), 32)
		t.equal(FactionEmblems.pick(100), 128)
		t.equal(FactionEmblems.pick(400), 256)
		local image, rect, tint = FactionEmblems.of("chaos", 40)
		if FactionEmblems.image ~= "" then
			t.equal(image, FactionEmblems.image)
			t.equal((rect :: { number })[3], 64)
			t.expect(tint ~= nil, "with its tint")
		else
			t.equal(image, nil, "nothing before the upload")
		end
	end)
end
