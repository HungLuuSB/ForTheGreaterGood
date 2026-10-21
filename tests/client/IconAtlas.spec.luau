--!strict
-- The icon sprite sheets (C-74): every unit def has an icon on them, every
-- tile it names exists and fits the sheet, and no two tiles overlap. Fails
-- when a def is added without rerunning tools/icons/render.mjs.

local IconAtlas = require("../../src/client/UI/IconAtlas")
local Defs = require("@shared/Defs/Defs")

local SHEET = 1024

return function(t: any)
	t.test("every unit def has a unit and a ghost tile", function()
		for _, def in Defs.load().unitByIndex do
			local e = IconAtlas.byDef[def.id]
			t.expect(e ~= nil, `{def.id} has no icon: rerun node tools/icons/render.mjs`)
			if e then
				t.expect(IconAtlas.tiles[e.unit] ~= nil, `{def.id}: no tile {e.unit}`)
				t.expect(IconAtlas.tiles[e.ghost] ~= nil, `{def.id}: no tile {e.ghost}`)
				t.expect(e.scale >= 1 and e.scale <= 1.35, `{def.id}: scale {e.scale}`)
			end
		end
	end)

	t.test("contacts have a tile per frame", function()
		for _, f in { "ground", "air", "naval", "sub", "struct" } do
			t.expect(IconAtlas.tiles[IconAtlas.blips[f]] ~= nil, `no contact tile for {f}`)
		end
	end)

	t.test("tiles fit the sheet and don't overlap", function()
		local seen = {}
		for key, p in IconAtlas.tiles do
			t.expect(p[1] >= 0 and p[2] >= 0 and p[1] + IconAtlas.TILE <= SHEET and p[2] + IconAtlas.TILE <= SHEET, `{key} off the sheet`)
			t.expect(p[1] % IconAtlas.TILE == 0 and p[2] % IconAtlas.TILE == 0, `{key} off the grid`)
			local at = `{p[1]},{p[2]}`
			t.expect(seen[at] == nil, `{key} and {seen[at]} share a tile`)
			seen[at] = key
		end
	end)
end
