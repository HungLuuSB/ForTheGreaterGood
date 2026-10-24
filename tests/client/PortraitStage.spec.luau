--!strict
-- What portraits stand a unit on (C-192): ground, water, a shore or ground
-- far below, from the def's domain, move class and placement.

local PortraitStage = require("../../src/client/Core/PortraitStage")
local World = require("../../src/client/Core/World")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

return function(t: any)
	t.test("tanks and structures on ground, ships and water structures on water, amphibious on a shore, aircraft above", function()
		local u = defs.units
		t.equal(PortraitStage.kind(u.ord_lancer), "ground")
		t.equal(PortraitStage.kind(u.ord_vehplant), "ground")
		t.equal(PortraitStage.kind(u.ord_falcon), "air")
		t.equal(PortraitStage.kind(u.ord_tideguard), "shore", "amphibious")
		t.equal(PortraitStage.kind(u.chs_mire), "shore")
		t.equal(PortraitStage.kind(u.chs_tidal), "water", "a water structure")
		local ship, sub
		for _, d in u do
			if d.moveClass == "SHIP" then
				ship = d
			elseif d.moveClass == "SUB" then
				sub = d
			end
		end
		t.equal(PortraitStage.kind(ship), "water")
		t.equal(PortraitStage.kind(sub), "water")
		-- every def gets one
		for id, d in u do
			local k = PortraitStage.kind(d)
			t.expect(k == "ground" or k == "water" or k == "shore" or k == "air", id)
		end
	end)

	t.test("in the world, ships, water structures and amphibious units ride the water surface; tanks and aircraft don't", function()
		local u = defs.units
		t.expect(World.floats(u.chs_tidal), "a water structure")
		t.expect(World.floats(u.ord_tideguard), "amphibious")
		t.expect(not World.floats(u.ord_lancer), "a tank drives on the bed (it can't go deep)")
		t.expect(not World.floats(u.ord_falcon), "aircraft fly above the ground")
		t.expect(not World.floats(u.ord_vehplant))
	end)
end
