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

	t.test("a def the sheet has no tile for yet shows its domain's plain frame", function()
		local Icons = require("../../src/client/Core/Icons")
		t.equal(Icons.ofDef({ id = "chs_new_unit", domain = "naval" }, 2, 24).tile, IconAtlas.contacts.ship)
		t.equal(Icons.ofDef({ id = "ord_new_wall", domain = "structure" }, 1).tile, IconAtlas.contacts.struct)
		t.equal(Icons.ofDef({ id = "ord_new_tank" }, 1).tile, IconAtlas.contacts.vehicle)
	end)

	t.test("contacts have a tile per frame", function()
		for f, key in IconAtlas.contacts do
			t.expect(IconAtlas.tiles[key] ~= nil, `no contact tile for {f}`)
		end
	end)

	t.test("tiles fit their sheet and don't overlap; every sheet has its image (C-183)", function()
		local w, h = IconAtlas.TILE_W, IconAtlas.TILE_H
		local seen = {}
		for key, p in IconAtlas.tiles do
			local sheet = p[3]
			t.expect(sheet ~= nil and sheet >= 1 and sheet <= #IconAtlas.images, `{key}: sheet {sheet} of {#IconAtlas.images}`)
			t.expect(p[1] >= 0 and p[2] >= 0 and p[1] + w <= SHEET and p[2] + h <= SHEET, `{key} off the sheet`)
			t.expect(p[1] % w == 0 and p[2] % h == 0, `{key} off the grid`)
			local at = `{sheet},{p[1]},{p[2]}`
			t.expect(seen[at] == nil, `{key} and {seen[at]} share a tile`)
			seen[at] = key
		end
		for i, image in IconAtlas.images do
			t.expect(string.match(image, "^rbxassetid://%d+$") ~= nil, `sheet {i} is uploaded ({image})`)
		end
	end)
end
