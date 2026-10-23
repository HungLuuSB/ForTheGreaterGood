--!strict
-- Each map's own look (C-155): The Canyon in the day, the rest the
-- moonlit night; the setting follows the map by default and offers each
-- look's preset.

local MapLook = require("../../src/client/Core/MapLook")
local Settings = require("../../src/client/Core/Settings")

return function(t: any)
	t.test("The Canyon is a desert day; other maps and no map are the night", function()
		t.equal(MapLook.of("map:canyon").atmosphere, "desert")
		t.equal(MapLook.of("map:normandy").atmosphere, "night")
		t.equal(MapLook.of(nil).atmosphere, "night")
		t.expect(MapLook.of("map:canyon").skirt[1] ~= MapLook.DEFAULT.skirt[1], "its own ground past the edge")
	end)

	t.test("the atmosphere setting follows the map by default and lists every map's preset", function()
		t.equal(Settings.new(false).atmosphere, "map")
		for _, look in MapLook.LOOKS do
			t.expect(table.find(Settings.ATMOSPHERES, look.atmosphere) ~= nil, `{look.atmosphere} can be picked`)
		end
		t.expect(table.find(Settings.ATMOSPHERES, MapLook.DEFAULT.atmosphere) ~= nil)
	end)
end
