--!strict
-- Each map's own look (C-155): The Canyon in the day, the rest the
-- moonlit night; the setting follows the map by default and offers each
-- look's preset.

local MapLook = require("../../src/client/Core/MapLook")

return function(t: any)
	t.test("The Canyon is a desert day, Supreme Strait a clear day; other maps and no map are the night", function()
		t.equal(MapLook.of("map:canyon").atmosphere, "desert")
		t.equal(MapLook.of("map:supreme_strait").atmosphere, "clear", "the user: Supreme Strait is day")
		t.equal(MapLook.of("map:normandy").atmosphere, "night")
		t.equal(MapLook.of(nil).atmosphere, "night")
		t.expect(MapLook.of("map:canyon").skirt[1] ~= MapLook.DEFAULT.skirt[1], "its own ground past the edge")
	end)

	t.test("every map's look names a lighting preset Render/Atmosphere has", function()
		local presets = { "night", "clear", "haze", "dusk", "desert" } -- (Render/Atmosphere.PRESETS, Roblox-only)
		for id, look in MapLook.LOOKS do
			t.expect(table.find(presets, look.atmosphere) ~= nil, `{id}: {look.atmosphere}`)
		end
		t.expect(table.find(presets, MapLook.DEFAULT.atmosphere) ~= nil)
	end)
end
