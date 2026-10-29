--!strict
-- A FIRE carries only the shot's end; its start is the shooter as drawn
-- (C-250, H37). A shooter not in the tactical tier or drawn far from its
-- record gives a stale start: no streak, only the hit.

local Effects = require("../../src/client/Core/Effects")

local function unit(tier: string, x: number, z: number, rx: number?, rz: number?): any
	return { id = 1, tier = tier, x = x, z = z, rx = rx, rz = rz }
end

return function(t: any)
	t.test("a stale shooter draws no streak (H37)", function()
		local gun = { range = 100 }
		t.expect(not Effects.staleStart(unit("tactical", 0, 0, 1, 1), gun, 1, 1, 80, 0, false), "drawn where it is: a streak")
		t.expect(not Effects.staleStart(unit("tactical", 0, 0), gun, 0, 0, 80, 0, false), "tactical, not drawn yet: its record is current")
		t.expect(Effects.staleStart(unit("strategic", 0, 0), gun, 0, 0, 80, 0, false), "a strategic record's spot is stale")
		t.expect(Effects.staleStart(nil, gun, 0, 0, 80, 0, false), "no shooter at all")
		t.expect(Effects.staleStart(unit("tactical", 0, 0, 60, 0), gun, 60, 0, 80, 0, false), "drawn 60 studs from its record")
		t.expect(not Effects.staleStart(unit("strategic", 0, 0), gun, 0, 0, 80, 0, true), "a live muzzle is never stale")
		t.expect(Effects.staleStart(unit("tactical", 0, 0, 0, 0), gun, 0, 0, 400, 0, true), "a shot far past its weapon's reach")
		t.expect(not Effects.staleStart(unit("tactical", 0, 0, 0, 0), { range = 100, fullLength = true }, 0, 0, 400, 0, true), "a full-length beam runs on")
	end)
end
