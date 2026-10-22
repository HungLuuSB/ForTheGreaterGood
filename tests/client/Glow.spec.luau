--!strict
-- Unit glow states (C-103, docs/contracts/fx.md "Unit glow"): dark while
-- built, power dims on a stall with a floor, factories pulse while
-- producing, weapons flash on a shot and settle, running and head stay on.

local Glow = require("../../src/client/Core/Glow")

local function ctx(over: { [string]: any }?): Glow.Context
	local c: any = { built = true, ratio = 1, producing = false, sinceShot = math.huge, now = 0, phase = 0 }
	for k, v in over or {} do
		c[k] = v
	end
	return c
end

return function(t: any)
	t.test("running and head stay at rest; everything is dark while being built", function()
		t.equal(Glow.strength("running", 2, ctx()), 2)
		t.equal(Glow.strength("head", 2.5, ctx({ ratio = 0.1 })), 2.5, "headlights don't dim on a stall")
		for _, ch in { "running", "head", "power", "weapon" } do
			t.equal(Glow.strength(ch, 2, ctx({ built = false, sinceShot = 0 })), 0, `{ch} dark while built`)
		end
	end)

	t.test("power dims with the stall ratio, not below the floor", function()
		t.equal(Glow.strength("power", 2.5, ctx()), 2.5)
		t.expect(math.abs(Glow.strength("power", 2.5, ctx({ ratio = 0.5 })) - 1.25) < 1e-9, "half power, half glow")
		t.equal(Glow.strength("power", 2.5, ctx({ ratio = 0 })), Glow.POWER_FLOOR)
	end)

	t.test("factories pulse 1.5..4 at 1 Hz while producing, out of step by phase", function()
		local lo, hi = math.huge, -math.huge
		for i = 0, 99 do
			local s = Glow.strength("power", 2.5, ctx({ producing = true, now = i / 100 }))
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
		t.expect(math.abs(lo - Glow.PULSE_LOW) < 0.01 and math.abs(hi - Glow.PULSE_HIGH) < 0.01, `range {lo}..{hi}`)
		t.expect(math.abs(Glow.strength("power", 2.5, ctx({ producing = true, now = 0.3 })) - Glow.strength("power", 2.5, ctx({ producing = true, now = 1.3 }))) < 1e-9, "one second a cycle")
		t.expect(Glow.strength("power", 2.5, ctx({ producing = true, now = 0, phase = 0.5 })) > 3.9, "phase shifts it")
		local stalled = Glow.strength("power", 2.5, ctx({ producing = true, now = 0.5, ratio = 0.5 }))
		t.expect(math.abs(stalled - 2) < 1e-9, "a stall dims the pulse too")
	end)

	t.test("weapons flash on a shot and settle back over FLASH_SECONDS", function()
		t.equal(Glow.strength("weapon", 1.5, ctx({ sinceShot = 0 })), Glow.FLASH)
		local mid = Glow.strength("weapon", 1.5, ctx({ sinceShot = Glow.FLASH_SECONDS / 2 }))
		t.expect(mid > 1.5 and mid < Glow.FLASH, `between ({mid})`)
		t.equal(Glow.strength("weapon", 1.5, ctx({ sinceShot = Glow.FLASH_SECONDS })), 1.5)
		t.equal(Glow.strength("weapon", 1.5, ctx()), 1.5)
	end)

	t.test("only real changes are written", function()
		t.expect(not Glow.changed(2, 2.01), "a hundredth is skipped")
		t.expect(Glow.changed(2, 2.5), "a real change")
		t.expect(Glow.changed(0.01, 0), "going dark is always written")
	end)
end
