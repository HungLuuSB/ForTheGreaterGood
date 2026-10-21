--!strict
-- Global sim speed (C-35): with the server ticking `speed` times as fast,
-- the render clock advances at 15 × speed ticks a second without jumps,
-- stays about DELAY_TICKS behind the newest tick, and holds still while
-- paused.

local Interp = require("../../src/client/Core/Interp")

local FRAME = 1 / 60

-- Ticks arrive every 1 / (15 × speed) s; returns the render clock's frame
-- steps (ticks) and how far behind the newest tick it ends.
local function run(speed: number, seconds: number): ({ number }, number)
	local world: any = { latestTick = 0, latestAt = 0 }
	local clock = Interp.newClock()
	local steps = {}
	local nextTick = 0
	local last = nil
	local now = 0
	while now < seconds do
		now += FRAME
		if speed > 0 then
			while now >= nextTick + 1 / (15 * speed) do
				nextTick += 1 / (15 * speed)
				world.latestTick += 1
				world.latestAt = nextTick
			end
		end
		local t = Interp.advance(clock, world, now, FRAME, speed)
		if last then
			table.insert(steps, t - last)
		end
		last = t
	end
	return steps, world.latestTick - (last :: number)
end

return function(t: any)
	for _, speed in { 0.1, 0.25, 0.5, 1, 2 } do
		t.test(`at {speed}x the render clock glides at 15 × {speed} ticks a second`, function()
			local steps, behind = run(speed, 12)
			local want = 15 * speed * FRAME
			local worst = 0
			for i = 120, #steps do -- after the first two seconds of settling
				worst = math.max(worst, math.abs(steps[i] - want) / want)
				t.expect(steps[i] > 0, "never steps back")
			end
			t.expect(worst < 0.25, `each frame within 25 % of the rate (worst {worst})`)
			t.expect(math.abs(behind - Interp.DELAY_TICKS) < 1, `about {Interp.DELAY_TICKS} ticks behind ({behind})`)
		end)
	end

	t.test("paused, the render clock freezes where it is and picks up again", function()
		-- running at 0.25x, then paused mid-way between two ticks
		local world: any = { latestTick = 0, latestAt = 0 }
		local clock = Interp.newClock()
		local now, frozen = 0, 0
		for _ = 1, 600 do
			now += FRAME
			if now >= world.latestAt + 1 / (15 * 0.25) then
				world.latestTick += 1
				world.latestAt = now
			end
			frozen = Interp.advance(clock, world, now, FRAME, 0.25)
		end
		for _ = 1, 300 do
			now += FRAME
			t.equal(Interp.advance(clock, world, now, FRAME, 0), frozen, "not a hair of movement while paused")
		end
		-- resumed at 1x: forward again, without a jump
		local last = frozen
		for _ = 1, 120 do
			now += FRAME
			if now >= world.latestAt + 1 / 15 then
				world.latestTick += 1
				world.latestAt = now
			end
			local tt = Interp.advance(clock, world, now, FRAME, 1)
			t.expect(tt >= last and tt - last < 1, "moves on smoothly")
			last = tt
		end
	end)
end
