--!strict
-- A transport's pick-up and set-down as drawn (C-273, the user: "The
-- transport must descend from the air, grab the unit model under its belly
-- and rise up again, same for dropping them"). The server says when each
-- starts and where (TRANSPORT, protocol 44, S-220; C-274): the drawn
-- transport comes down over its ticks, sliding over the unit it picks up or
-- the spot it sets one down on, holds low until what it carries changes
-- (CARRY: the grab or the release), then rises over RISE_TICKS; CANCEL
-- sends it back up. All on the sim's tick clock, so it plays in step with
-- the render. Render/Transports turns the share into a height and hangs
-- the cargo. Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local TransportLift = {}

local TA = Schema.TransportAction

TransportLift.RISE_TICKS = 12 -- back up after the grab or release
TransportLift.HOLD_TICKS = 30 -- low this long past the server's ticks with no grab: rise anyway

export type Lift = {
	kind: "pickup" | "drop",
	unitId: number, -- the unit picked up or set down
	defIndex: number, -- its def
	start: number, -- sim tick the descent started
	ticks: number, -- how long the server takes
	x: number, -- where: the unit picked up, or the spot it is set down on
	z: number,
	up: number?, -- sim tick the rise started (grab, release, cancel or give-up)
	from: number?, -- the descent share the rise started from
	grabbed: boolean, -- it ended in the grab or release (not a cancel)
}

export type State = { lifts: { [number]: Lift } }

function TransportLift.new(): State
	return { lifts = {} }
end

local function ease(f: number): number
	f = math.clamp(f, 0, 1)
	return f * f * (3 - 2 * f)
end

local function down(l: Lift, t: number): number
	return ease((t - l.start) / math.max(l.ticks, 1))
end

-- The descent share of lift `l` at tick `t`: 0 up high, 1 down low.
function TransportLift.share(l: Lift, t: number): number
	local up = l.up
	if up and t >= up then
		return (l.from or 1) * (1 - ease((t - up) / TransportLift.RISE_TICKS))
	end
	return down(l, t)
end

local function rise(l: Lift, tick: number, grabbed: boolean)
	if l.up == nil then
		l.from = down(l, tick)
		l.up = tick
		l.grabbed = grabbed
	end
end

-- Takes the world's TRANSPORT and CARRY events, then drops finished lifts
-- (`t`: the render tick).
function TransportLift.step(s: State, world: World.World, t: number)
	for _, fx in world.transportFx do
		local l = s.lifts[fx.transport]
		if fx.action == TA.PICKUP or fx.action == TA.DROP then
			s.lifts[fx.transport] = {
				kind = if fx.action == TA.PICKUP then "pickup" else "drop",
				unitId = fx.unit,
				defIndex = fx.defIndex,
				start = fx.tick,
				ticks = fx.ticks,
				x = fx.x,
				z = fx.z,
				up = nil,
				from = nil,
				grabbed = false,
			}
		elseif fx.action == TA.CANCEL then
			if l then
				rise(l, fx.tick, false)
			end
		elseif l then
			rise(l, fx.tick, true) -- CARRY: picked up or set down
		end
	end
	table.clear(world.transportFx)
	for id, l in s.lifts do
		if world.units[id] == nil then
			s.lifts[id] = nil
		elseif l.up == nil and t - l.start > l.ticks + TransportLift.HOLD_TICKS then
			rise(l, t, false) -- (a lost event)
		elseif l.up and t - l.up >= TransportLift.RISE_TICKS then
			s.lifts[id] = nil
		end
	end
end

-- The drawn lift of transport `id` at render tick `t`: the descent share
-- (0..1) and the point the belly slides over by the same share (the unit
-- picked up, or the set-down spot); nil when it isn't lifting.
function TransportLift.of(s: State, id: number, t: number): (number?, number?, number?)
	local l = s.lifts[id]
	if l == nil or t < l.start then
		return nil, nil, nil
	end
	return TransportLift.share(l, t), l.x, l.z
end

return TransportLift
