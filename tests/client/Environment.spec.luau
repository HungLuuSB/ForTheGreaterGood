--!strict
-- The ground skirt round the map and the colour grade (C-102): tiles cover
-- the ring exactly within Roblox's part size, the skirt sits under every
-- edge, the grade eases off with zoom, blasts flash and fade, the vignette
-- is clear in the middle.

local Environment = require("../../src/client/Core/Environment")
local Grade = require("../../src/client/Core/Grade")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")

return function(t: any)
	t.test("the skirt's tiles cover the ring round the map exactly, none over the map, none too big", function()
		local tiles = Environment.skirt(-512, -512, 512, 512, 6000, 2048)
		local area = 0
		for _, r in tiles do
			local w, d = r.x1 - r.x0, r.z1 - r.z0
			t.expect(w <= 2048 + 1e-6 and d <= 2048 + 1e-6, `tile within a part's size ({w} × {d})`)
			area += w * d
			local overlapsMap = r.x0 < 512 and r.x1 > -512 and r.z0 < 512 and r.z1 > -512
			t.expect(not overlapsMap, "no tile over the map")
		end
		local outer = (1024 + 12000) ^ 2
		t.expect(math.abs(area - (outer - 1024 * 1024)) < 1, `the ring's area exactly ({area})`)
		t.expect(#tiles <= 60, `a few dozen parts ({#tiles})`)
	end)

	t.test("the skirt's top sits under the lowest edge surface, water included", function()
		local g = Grid.new(8, 8)
		local layers = Layers.new(g)
		for i = 0, g.cellCount - 1 do
			Layers.setHeight(layers, i, 20)
		end
		Layers.setHeight(layers, 3 * 8 + 3, 2) -- a pit inside: ignored
		Layers.setHeight(layers, 7 * 8 + 5, 12) -- the south edge dips
		t.equal(Environment.edgeY(layers), 12 - Environment.BELOW)
		Layers.setHeight(layers, 0, 4)
		Layers.setWater(layers, 0, 6) -- a sea corner: its surface counts
		t.equal(Environment.edgeY(layers), 10 - Environment.BELOW)
	end)

	t.test("the grade is full up close and eases off at strategic zoom", function()
		local c = { brightness = 0.05, contrast = 0.3, saturation = -0.1, tint = { 196, 218, 255 } }
		t.equal(Grade.zoom(100), 0)
		t.equal(Grade.zoom(2000), 1)
		local _, k0, _, r0 = Grade.mix(c, Grade.zoom(100))
		t.equal(k0, 0.3)
		t.equal(r0, 196)
		local _, k1, s1, r1, _, b1 = Grade.mix(c, 1)
		t.expect(math.abs(k1 - 0.3 * Grade.FAR_CONTRAST) < 1e-9, "less contrast far out")
		t.expect(math.abs(s1 - -0.1 * Grade.FAR_CONTRAST) < 1e-9, "and less desaturation")
		t.expect(r1 > 196 and r1 < 255 and b1 == 255, "the tint goes part way back to white")
	end)

	t.test("big blasts near the focus flash, small ones and far ones don't, and it fades", function()
		local f = Grade.newFlash()
		Grade.burst(f, "impact", 6, 0, 300)
		Grade.burst(f, "death", 1, 0, 300)
		t.equal(f.level, 0, "impacts and small deaths never flash")
		Grade.burst(f, "death", 3, 400, 300)
		t.equal(f.level, 0, "out of view: nothing")
		Grade.burst(f, "death", 3, 0, 300)
		t.expect(math.abs(f.level - Grade.FLASH.death) < 1e-9, "a big death at the focus")
		Grade.burst(f, "nuke", 1, 0, 300)
		t.equal(f.level, 1, "capped at 1")
		local b, _, _, r, g, bl = Grade.flash(f)
		t.expect(b > 0 and r == 255 and g < 255 and bl < g, "warm and brighter")
		Grade.step(f, Grade.DECAY)
		t.expect(math.abs(f.level - math.exp(-1)) < 1e-6, "1/e after DECAY")
		for _ = 1, 100 do
			Grade.step(f, 0.1)
		end
		t.equal(f.level, 0)
		local b0, k0, s0, r0, g0, bb0 = Grade.flash(f)
		t.expect(b0 == 0 and k0 == 0 and s0 == 0 and r0 == 255 and g0 == 255 and bb0 == 255, "no flash: no change")
	end)

	t.test("the vignette is clear in the middle and dark in the corners", function()
		local n = 64
		local img = Grade.vignette(n, 4, 6, 12)
		local function alpha(x: number, y: number): number
			return buffer.readu8(img, (y * n + x) * 4 + 3)
		end
		t.equal(alpha(32, 32), 0)
		t.expect(alpha(0, 0) > 200, `corners dark ({alpha(0, 0)})`)
		t.expect(alpha(0, 32) > 0 and alpha(0, 32) < alpha(0, 0), "the sides between")
		t.equal(buffer.readu8(img, 2), 12, "its colour")
	end)
end
