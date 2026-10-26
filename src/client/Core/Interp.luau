--!strict
-- Client interpolation (guide 7.4): draw units DELAY_TICKS behind the newest
-- server tick, between the two surrounding snapshots. Past the newest
-- snapshot a MOVING unit extrapolates up to one tick, then holds; a unit that
-- stopped just holds (no overshoot). Pure Luau (C-7).

local World = require("./World")

local Interp = {}

Interp.TICK_RATE = 15
Interp.DELAY_TICKS = 2
Interp.MAX_EXTRAPOLATE = 1 -- ticks
Interp.SNAP_ERROR = 3 -- ticks: a render clock further off than this jumps

export type Clock = { tick: number, started: boolean }

function Interp.newClock(): Clock
	return { tick = 0, started = false }
end

-- Advances the render clock by `dt` seconds and returns the render tick
-- (fractional sim tick), or -1 before any packet. It runs at the tick rate
-- times the sim speed (C-35: 0.25 = slow motion, 0 = paused) and is pulled
-- gently toward (newest tick + time since it arrived − delay), so packet
-- jitter doesn't make units stutter.
function Interp.advance(clock: Clock, world: World.World, now: number, dt: number, speed: number?): number
	if world.latestTick < 0 then
		return -1
	end
	local rate = Interp.TICK_RATE * (speed or 1)
	local target = world.latestTick + (now - world.latestAt) * rate - Interp.DELAY_TICKS
	if not clock.started then
		clock.tick, clock.started = target, true
		return target
	end
	if rate <= 0 then
		return clock.tick -- paused: the picture freezes where it is (no pull back toward the target)
	end
	clock.tick += dt * rate
	local err = target - clock.tick
	if math.abs(err) > Interp.SNAP_ERROR then
		clock.tick = target
	else
		clock.tick += err * math.min(1, dt * 2)
	end
	return clock.tick
end

local function lerpAngle(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

-- Position (x, z), altitude and heading of `unit` at render tick `t`.
function Interp.sample(unit: World.Unit, t: number): (number, number, number, number)
	local snaps = unit.snaps
	local n = #snaps
	if n == 0 then
		return unit.x, unit.z, unit.alt, unit.heading
	end
	local first = snaps[1]
	if t <= first.tick then
		return first.x, first.z, first.alt, first.heading
	end
	local last = snaps[n]
	if t < last.tick then
		for i = n - 1, 1, -1 do
			local a = snaps[i]
			if a.tick <= t then
				local b = snaps[i + 1]
				local k = (t - a.tick) / (b.tick - a.tick)
				return a.x + (b.x - a.x) * k, a.z + (b.z - a.z) * k, a.alt + (b.alt - a.alt) * k, lerpAngle(a.heading, b.heading, k)
			end
		end
	end
	local over = t - last.tick
	if n >= 2 and over > 0 and bit32.band(unit.state, World.State.MOVING) ~= 0 then
		local prev = snaps[n - 1]
		local span = last.tick - prev.tick
		local k = math.min(over, Interp.MAX_EXTRAPOLATE) / span
		return last.x + (last.x - prev.x) * k, last.z + (last.z - prev.z) * k, last.alt + (last.alt - prev.alt) * k, lerpAngle(last.heading, last.heading + ((last.heading - prev.heading + math.pi) % (2 * math.pi) - math.pi), k) -- the turn's short way (C-107)
	end
	return last.x, last.z, last.alt, last.heading
end

-- Absolute height of an aircraft at render tick `t` (G16, the user's
-- playtest: planes snapped crossing a mountain). The wire's `alt` is above
-- the ground under the aircraft, so ground(x(t)) + alt(t) jumps where a
-- cliff passes under it between two snapshots: the ground term steps at a
-- point in space, the altitude the other way at a snapshot tick. Each
-- snapshot's own height, ground(snapshot) + alt with the sim's ground
-- (`ground`, World.simGroundY), is what the sim flew; interpolating those
-- is smooth (the sim climbs at most 2.67 studs a tick).
-- A wire position is within 1/8 stud of the sim's (quarter studs): near a
-- cell's edge the sim's ground may be the next cell's. Of the grounds that
-- close, the one that keeps the height nearest the previous snapshot's is
-- the sim's (it climbs at most 2.67 studs a tick; cells step much more).
local NEAR = { { 0, 0 }, { 0.125, 0.125 }, { -0.125, 0.125 }, { 0.125, -0.125 }, { -0.125, -0.125 } }
local function heightOf(s: World.Snap, ground: (number, number) -> number, prev: World.Snap?): number
	local y = s.y
	if y == nil then
		local best = ground(s.x, s.z) + s.alt
		local py = if prev then prev.y else nil
		if py then
			for i = 2, #NEAR do
				local c = ground(s.x + NEAR[i][1], s.z + NEAR[i][2]) + s.alt
				if math.abs(c - py) < math.abs(best - py) then
					best = c
				end
			end
		end
		y = best
		s.y = y
	end
	return y :: number
end
function Interp.height(unit: World.Unit, t: number, ground: (number, number) -> number): number
	local snaps = unit.snaps
	local n = #snaps
	if n == 0 then
		return ground(unit.x, unit.z) + unit.alt
	end
	-- heights in snapshot order, each from the one before (see heightOf)
	for i = 1, n do
		if snaps[i].y == nil then
			heightOf(snaps[i], ground, snaps[i - 1])
		end
	end
	local first = snaps[1]
	if t <= first.tick then
		return first.y :: number
	end
	local last = snaps[n]
	if t < last.tick then
		for i = n - 1, 1, -1 do
			local a = snaps[i]
			if a.tick <= t then
				local b = snaps[i + 1]
				local k = (t - a.tick) / (b.tick - a.tick)
				local ya = a.y :: number
				return ya + ((b.y :: number) - ya) * k
			end
		end
	end
	local over = t - last.tick
	local yl = last.y :: number
	if n >= 2 and over > 0 and bit32.band(unit.state, World.State.MOVING) ~= 0 then
		local prev = snaps[n - 1]
		local k = math.min(over, Interp.MAX_EXTRAPOLATE) / (last.tick - prev.tick)
		return yl + (yl - (prev.y :: number)) * k
	end
	return yl
end

return Interp
