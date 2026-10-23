--!strict
-- Map previews (L-5) from the real named maps: size, starts, and the sea,
-- land and deposits each show.

local MapPreview = require("../shared/MapPreview")
local MapRegistry = require("@shared/Grid/MapRegistry")
local RunAll = require("../../server/Tests/RunAll")

local function classes(p: MapPreview.Preview): { [number]: number }
	local count: { [number]: number } = {}
	for i = 0, p.w * p.h - 1 do
		local c = buffer.readu8(p.data, i) // 32
		count[c] = (count[c] or 0) + 1
	end
	return count
end

return function(t: RunAll.Context)
	t.test("Coastline: 96 pixels a side, two starts, sea, land and deposits", function()
		local layers = MapRegistry.load("map:coastline")
		local p = MapPreview.build(layers, 96)
		t.equal(p.w, 96)
		t.equal(p.h, 96)
		t.equal(#p.starts, 2)
		for _, s in p.starts do
			t.expect(s[1] >= 0 and s[1] <= 1 and s[2] >= 0 and s[2] <= 1, "start inside the map")
		end
		local c = classes(p)
		t.expect((c[MapPreview.CLASSES.WATER] or 0) > 500, "a sea")
		t.expect((c[MapPreview.CLASSES.GRASS] or 0) > 500, "land")
		t.expect((c[MapPreview.CLASSES.DEPOSIT] or 0) > 4, "deposits")
	end)

	t.test("The Canyon keeps its 154 x 256 shape", function()
		local p = MapPreview.build(MapRegistry.load("map:canyon"), 96)
		t.equal(p.h, 96)
		t.equal(p.w, 58)
		t.deepEqual(p.cells, { 154, 256 })
	end)

	t.test("colors: deposits are the accent, deep water darker than shallow", function()
		local r, g, b = MapPreview.color(MapPreview.CLASSES.DEPOSIT * 32 + 31)
		t.deepEqual({ r, g, b }, { 238, 186, 92 })
		local _, _, shallow = MapPreview.color(MapPreview.CLASSES.WATER * 32)
		local _, _, deep = MapPreview.color(MapPreview.CLASSES.WATER * 32 + 31)
		t.expect(deep < shallow, "deep water is darker")
	end)
end
