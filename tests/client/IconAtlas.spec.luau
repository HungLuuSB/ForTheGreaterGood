--!strict
-- The icon sprite sheet (C-74): every unit def has an icon on it, every
-- tile it names exists and fits the sheet, and no two tiles overlap. Fails
-- when a def is added without rerunning tools/icons/render.mjs.

local IconAtlas = require("../../src/client/UI/IconAtlas")
local Defs = require("@shared/Defs/Defs")

local SHEET = 1024

return function(t: any)
	t.test("every unit def has a tile", function()
		for _, def in Defs.load().unitByIndex do
			local e = IconAtlas.byDef[def.id]
			t.expect(e ~= nil, `{def.id} has no icon: rerun node tools/icons/render.mjs`)
			if e then
				t.expect(IconAtlas.tiles[e.tile] ~= nil, `{def.id}: no tile {e.tile}`)
				t.expect(e.scale >= 1 and e.scale <= 1.35, `{def.id}: scale {e.scale}`)
				t.expect(IconAtlas.contacts[e.frame] ~= nil, `{def.id}: no contact tile for its frame {e.frame}`)
			end
		end
	end)

	t.test("contacts have a tile per frame", function()
		for f, key in IconAtlas.contacts do
			t.expect(IconAtlas.tiles[key] ~= nil, `no contact tile for {f}`)
		end
	end)

	t.test("tiles fit the sheet and don't overlap", function()
		local w, h = IconAtlas.TILE_W, IconAtlas.TILE_H
		local seen = {}
		for key, p in IconAtlas.tiles do
			t.expect(p[1] >= 0 and p[2] >= 0 and p[1] + w <= SHEET and p[2] + h <= SHEET, `{key} off the sheet`)
			t.expect(p[1] % w == 0 and p[2] % h == 0, `{key} off the grid`)
			local at = `{p[1]},{p[2]}`
			t.expect(seen[at] == nil, `{key} and {seen[at]} share a tile`)
			seen[at] = key
		end
	end)
end
