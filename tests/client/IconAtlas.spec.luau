--!strict
-- The icon sprite sheet (C-74): every unit def has an icon on it, every
-- tile it names exists and fits the sheet, and no two tiles overlap. A def
-- the sheet doesn't list yet draws its type's placeholder (C-258).

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
				t.expect(e.scale >= 1 and e.scale <= 1.4, `{def.id}: scale {e.scale}`) -- 1.4: the experimental mechs (draft 7)
				t.expect(IconAtlas.contacts[e.frame] ~= nil, `{def.id}: no contact tile for its frame {e.frame}`)
			end
		end
	end)

	t.test("a def the sheet has no tile for yet draws its type's placeholder (the sheet's rule, C-258)", function()
		local Icons = require("../../src/client/Core/Icons")
		local ph = IconAtlas.placeholders
		for f, key in ph do
			t.expect(IconAtlas.tiles[key] ~= nil, `no tile for {f}'s placeholder {key}`)
		end
		t.equal(Icons.ofDef({ id = "chs_new_ship", domain = "naval", moveClass = "SHIP" }, 2, 24).tile, ph.ship)
		t.equal(Icons.ofDef({ id = "chs_new_sub", domain = "naval", moveClass = "SUB" }, 2).tile, ph.sub)
		t.equal(Icons.ofDef({ id = "ord_new_wall", domain = "structure" }, 1).tile, ph.struct)
		t.equal(Icons.ofDef({ id = "ord_new_tower", domain = "structure", weapons = { {} } }, 1).tile, ph.defense)
		t.equal(Icons.ofDef({ id = "ord_new_heli", domain = "air", moveClass = "HELI" }, 1).tile, ph.vtol)
		t.equal(Icons.ofDef({ id = "ord_new_jet", domain = "air", moveClass = "JET" }, 1).tile, ph.air)
		t.equal(Icons.ofDef({ id = "ord_new_bot", domain = "ground", moveClass = "WALKER" }, 1).tile, ph.walker)
		t.equal(Icons.ofDef({ id = "ord_new_mech", domain = "ground", moveClass = "AMPHIB_WALKER" }, 1).tile, ph.walker)
		t.equal(Icons.ofDef({ id = "ord_new_amphib", domain = "ground", moveClass = "AMPHIB" }, 1).tile, ph.amphib)
		t.equal(Icons.ofDef({ id = "ord_new_hover", domain = "ground", moveClass = "HOVER" }, 1).tile, ph.hover)
		t.equal(Icons.ofDef({ id = "ord_new_tank", domain = "ground", moveClass = "TRACKED" }, 1).tile, ph.vehicle)
		t.equal(Icons.entry({ id = "ord_new_bot", domain = "ground", moveClass = "WALKER" }).frame, "walker", "its radar contact is its type's frame")
	end)

	t.test("the Commanders draw their heads but keep the walker frame, so radar shows a plain walker (2D-E)", function()
		for _, id in { "ord_sovereign", "chs_warlord" } do
			local e = IconAtlas.byDef[id]
			t.expect(e ~= nil and e.frame == "walker", `{id}: frame {e and e.frame}`)
		end
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
