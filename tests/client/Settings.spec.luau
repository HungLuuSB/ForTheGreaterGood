--!strict
-- Player settings (C-81): defaults, validation and steps, the graphics
-- presets (High is today's numbers), and the key reference covers the
-- client's bindings.

local Effects = require("../../src/client/Core/Effects")
local PieceAnim = require("../../src/client/Core/PieceAnim")
local Settings = require("../../src/client/Core/Settings")

return function(t: any)
	t.test("defaults, validation, steps", function()
		local s = Settings.new(true)
		t.equal(s.edgeScroll, false, "edge scroll off in Studio")
		t.equal(Settings.new(false).edgeScroll, true, "on in a live game")
		t.equal(s.devMode, true, "developer mode on in Studio (C-124)")
		t.equal(Settings.new(false).devMode, false, "off in a live game")
		t.expect(Settings.set(s, "devMode", false) and s.devMode == false, "and switchable")
		t.equal(s.fog, true, "fog of war shading on (C-100)")
		t.equal(s.quality, "high")
		t.equal(s.atmosphere, "night", "a moonlit night by default (C-101: no sun)")
		t.expect(s.detailedModels and s.glow == "high" and s.headlights, "detailed models, full glow and headlights by default (C-106)")
		t.expect(Settings.set(s, "glow", "low") and s.glow == "low", "a glow level")
		t.expect(not Settings.set(s, "glow", "max"), "an unknown glow level is refused")
		t.expect(Settings.set(s, "detailedModels", false) and not s.detailedModels, "blockouts")
		t.expect(not Settings.set(s, "headlights", "yes"), "headlights take a boolean")
		t.expect(Settings.set(s, "atmosphere", "dusk") and s.atmosphere == "dusk", "a preset")
		t.expect(not Settings.set(s, "atmosphere", "noon"), "an unknown preset is refused")
		t.expect(not Settings.set(s, "panSpeed", "fast"), "a wrong type is refused")
		t.expect(not Settings.set(s, "nope", 1), "an unknown key is refused")
		t.expect(not Settings.set(s, "quality", "ultra"), "an unknown quality is refused")
		Settings.set(s, "panSpeed", 99)
		t.equal(s.panSpeed, Settings.LIMITS.panSpeed[2], "clamped to the maximum")
		Settings.set(s, "uiScale", 1.04)
		t.expect(math.abs(s.uiScale - 1.0) < 1e-9, "rounded to its step")
		Settings.nudge(s, "uiScale", true)
		t.expect(math.abs(s.uiScale - 1.1) < 1e-9, "one step up")
		for _ = 1, 20 do
			Settings.nudge(s, "zoomStep", false)
		end
		t.expect(math.abs(s.zoomStep - Settings.LIMITS.zoomStep[1]) < 1e-9, "stops at the minimum")
	end)

	t.test("presets: High is today's look, lower ones draw less", function()
		local high = Settings.QUALITY.high
		t.equal(high.explosions, Effects.MAX_EXPLOSIONS)
		t.equal(high.tracers, Effects.MAX_TRACERS)
		t.equal(high.projectiles, Effects.MAX_PROJECTILES)
		t.equal(high.detailNear, PieceAnim.NEAR)
		t.equal(high.detailMid, PieceAnim.MID)
		local last: any = nil
		for _, name in Settings.QUALITIES do
			local g = Settings.QUALITY[name]
			if last then
				for k, v in g :: any do
					t.expect(v >= last[k], `{name}.{k} at least the preset below`)
				end
			end
			t.expect(g.detailMid > g.detailNear, `{name}: mid beyond near`)
			last = g
		end
	end)

	t.test("the key reference lists every command key", function()
		local text = {}
		for _, group in Settings.KEYS do
			for _, k in group[2] do
				table.insert(text, k[1])
			end
		end
		local all = table.concat(text, " ")
		for _, key in { "A", "F", "M", "Z", "G", "S", "L", "K", "Y", "U", "X", "B", "R", "T", "V", "N", "J", "O" } do
			t.expect(string.find(all, "%f[%w]" .. key .. "%f[%W]") ~= nil, `{key} is listed`)
		end
	end)
end
