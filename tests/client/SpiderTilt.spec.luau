--!strict
-- All-terrain spiders (move class SPIDER, batch 2) lie along the drawn
-- ground: nose up a climb, nose down a descent, the downhill side low on a
-- traverse, clamped at Attitude.CLIMB_MAX; they start on the slope the
-- first frame they're drawn; other ground units stay upright.

local Attitude = require("../../src/client/Core/Attitude")

local FRAME = 1 / 60
local spider = { domain = "ground", moveClass = "SPIDER", footprint = 2, movement = { maxSpeed = 10 } }
local bot = { domain = "ground", moveClass = "BOT", footprint = 1, movement = { maxSpeed = 10 } }

-- a ramp rising toward +x at `deg` degrees
local function ramp(deg: number): (number, number) -> number
	local k = math.tan(math.rad(deg))
	return function(x: number, _z: number): number
		return x * k
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < math.rad(0.5)
end

return function(t: any)
	t.test("a spider lies along a slope: pitch up a climb, down a descent, roll on a traverse", function()
		local up = ramp(30)
		-- facing +x (heading π/2): climbing
		local s = Attitude.new()
		local roll, pitch = Attitude.step(s, spider, 0, 0, math.pi / 2, FRAME, up)
		t.expect(near(pitch, math.rad(30)) and near(roll, 0), `climbing: nose up 30° on the first frame ({math.deg(pitch)}°, roll {math.deg(roll)}°)`)
		-- turns to face -x: descending, eased toward it
		for _ = 1, 120 do
			roll, pitch = Attitude.step(s, spider, 0, 0, -math.pi / 2, FRAME, up)
		end
		t.expect(near(pitch, math.rad(-30)), `descending: nose down 30° ({math.deg(pitch)}°)`)
		-- facing +z (heading 0): the slope rises to its left (+x is its left side)
		local side = Attitude.new()
		roll, pitch = Attitude.step(side, spider, 0, 0, 0, FRAME, up)
		t.expect(near(roll, math.rad(-30)) and near(pitch, 0), `traverse, uphill on the left: right side down ({math.deg(roll)}°)`)
	end)

	t.test("a spider on a cliff tilts no further than CLIMB_MAX; other ground units stay upright", function()
		local cliff = ramp(88)
		local s = Attitude.new()
		local _, pitch = Attitude.step(s, spider, 0, 0, math.pi / 2, FRAME, cliff)
		t.expect(math.abs(pitch - Attitude.CLIMB_MAX) < 1e-9, `clamped at {math.deg(Attitude.CLIMB_MAX)}° ({math.deg(pitch)}°)`)
		local b = Attitude.new()
		local roll2, pitch2 = Attitude.step(b, bot, 0, 0, math.pi / 2, FRAME, cliff)
		roll2, pitch2 = Attitude.step(b, bot, 1, 0, math.pi / 2, FRAME, cliff)
		t.expect(roll2 == 0 and pitch2 == 0, "a bot stays upright on the same slope")
		local flat = Attitude.new()
		local roll3, pitch3 = Attitude.step(flat, spider, 0, 0, 1, FRAME, function()
			return 5
		end)
		t.expect(roll3 == 0 and pitch3 == 0, "a spider on flat ground is level")
	end)
end
