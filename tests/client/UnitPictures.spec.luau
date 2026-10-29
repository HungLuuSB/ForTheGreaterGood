--!strict
-- Unit pictures (C-262, 2D-E's E-11): every picture names a real def and a
-- sheet, sits on the 128-px grid, and a def without an uploaded picture
-- keeps its live portrait (`of` returns nil).

local UnitPictures = require("../../src/client/UI/UnitPictures")
local Defs = require("@shared/Defs/Defs")

return function(t: any)
	t.test("pictures name real defs and sheets, on the grid", function()
		local units = Defs.load().units
		local tile = UnitPictures.TILE
		for id, u in UnitPictures.units do
			t.expect(units[id] ~= nil, `{id} is no unit def`)
			t.expect(u[1] >= 1 and u[1] <= #UnitPictures.sheets, `{id}: sheet {u[1]}`)
			t.expect(u[2] % tile == 0 and u[3] % tile == 0 and u[2] + tile <= 1024, `{id}: off the grid`)
		end
		for i, image in UnitPictures.sheets do
			t.expect(image == "" or string.match(image, "^rbxassetid://%d+$") ~= nil, `sheet {i}: {image}`)
		end
	end)

	t.test("a def without an uploaded picture keeps its live portrait", function()
		t.equal((UnitPictures.of("ord_not_a_unit")), nil)
		for id, u in UnitPictures.units do
			local image = UnitPictures.of(id)
			t.equal(image ~= nil, UnitPictures.sheets[u[1]] ~= "", id)
		end
	end)
end
