--!strict
-- A transport's pick-up and set-down as drawn (C-273, the user: "The
-- transport must descend from the air, grab the unit model under its belly
-- and rise up again, same for dropping them"). The server takes 1 s
-- (Transport.LOAD_TICKS) hovering; the client lowers the drawn transport
-- over it, holds it low until the grab or release lands (the CARGO change,
-- with the unit's LEAVE or ENTER), then lifts it back over RISE_TICKS.
-- Render/Transports turns the share into a height and a slide over the
-- unit, and hangs the cargo under the belly.
--
-- Until the server says when a lift starts (client request 40), the start
-- is inferred from own transports' orders: in reach of their Load target
-- (the server starts its timer there, still gliding in; a helicopter always
-- reports MOVING), or of their Unload point with cargo. Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local TransportLift = {}

local CT = Schema.CmdType

TransportLift.DOWN_TICKS = 15 -- the server's Transport.LOAD_TICKS: 1 s down
TransportLift.RISE_TICKS = 12 -- back up after the grab or release
TransportLift.HOLD_TICKS = 30 -- low this long past DOWN_TICKS with no grab: give up and rise
TransportLift.LOAD_REACH = 10 -- the server's: hovers within this plus the unit's radius
TransportLift.UNLOAD_REACH = 12 -- the server's Transport.UNLOAD_REACH
TransportLift.SLACK = 4 -- studs past the server's reach still counted

export type Lift = {
	kind: "pickup" | "drop",
	unitId: number, -- the unit picked up or set down
	start: number, -- render tick the descent started
	cargo: number, -- the transport's cargo count at the start
	up: number?, -- render tick the rise started (grab, release or give-up)
	from: number?, -- the descent share the rise started from
	grabbed: boolean, -- the grab or release happened (not a give-up)
	overX: number?, -- picking up: where the unit stood as last drawn (the belly slides over it)
	overZ: number?,
}

export type State = { lifts: { [number]: Lift } }

function TransportLift.new(): State
	return { lifts = {} }
end

local function ease(f: number): number
	f = math.clamp(f, 0, 1)
	return f * f * (3 - 2 * f)
end

-- The descent share of lift `l` at render tick `t`: 0 up high, 1 down low.
function TransportLift.share(l: Lift, t: number): number
	if l.up then
		return (l.from or 1) * (1 - ease((t - l.up) / TransportLift.RISE_TICKS))
	end
	return ease((t - l.start) / TransportLift.DOWN_TICKS)
end

-- Starts a lift (the server's word, or the inference below).
function TransportLift.start(s: State, transportId: number, kind: "pickup" | "drop", unitId: number, t: number, cargo: number)
	s.lifts[transportId] = { kind = kind, unitId = unitId, start = t, cargo = cargo, up = nil, from = nil, grabbed = false, overX = nil, overZ = nil }
end

local function rise(l: Lift, t: number, grabbed: boolean)
	if l.up == nil then
		l.from = TransportLift.share(l, t)
		l.up = t
		l.grabbed = grabbed
	end
end

local function radiusOf(world: World.World, u: World.Unit): number
	local def = World.def(world, u)
	return (if def then def.footprint else 1) * 4
end

-- One frame at render tick `t`: starts lifts from own transports' orders
-- (`byUnit`: Waypoints' lists), ends the descent on the grab or release
-- (the cargo count changed) or after HOLD_TICKS, drops finished lifts.
function TransportLift.step(s: State, world: World.World, byUnit: { [number]: { any } }, t: number)
	for id, l in s.lifts do
		local u = world.units[id]
		if u == nil then
			s.lifts[id] = nil
			continue
		end
		if l.up == nil then
			local over = if l.kind == "pickup" then world.units[l.unitId] else nil
			if over then
				l.overX, l.overZ = over.rx or over.x, over.rz or over.z
			end
			local n = #(u.cargo or {})
			local p = byUnit[id] and byUnit[id][1]
			local other = p ~= nil and p.kind ~= (if l.kind == "pickup" then CT.LOAD else CT.UNLOAD)
			if n ~= l.cargo then
				rise(l, t, true) -- picked up or set down
			elseif other or t - l.start > TransportLift.DOWN_TICKS + TransportLift.HOLD_TICKS then
				rise(l, t, false) -- another order, or it never got there
			end
		elseif t - l.up >= TransportLift.RISE_TICKS then
			s.lifts[id] = nil
		end
	end
	for id, u in world.units do
		if s.lifts[id] or u.team ~= world.me.team or u.tier ~= "tactical" then
			continue
		end
		local def = World.def(world, u)
		if def == nil or def.transport == nil then
			continue
		end
		local p = byUnit[id] and byUnit[id][1]
		if p == nil then
			continue
		end
		local n = #(u.cargo or {})
		if p.kind == CT.LOAD and p.targetId and n < def.transport.maxUnits then
			local target = world.units[p.targetId]
			if target and target.tier == "tactical" then
				local reach = TransportLift.LOAD_REACH + radiusOf(world, target) + TransportLift.SLACK
				if (target.x - u.x) ^ 2 + (target.z - u.z) ^ 2 <= reach * reach then
					TransportLift.start(s, id, "pickup", p.targetId, t, n)
				end
			end
		elseif p.kind == CT.UNLOAD and n > 0 then
			local reach = TransportLift.UNLOAD_REACH + TransportLift.SLACK
			if (p.x - u.x) ^ 2 + (p.z - u.z) ^ 2 <= reach * reach then
				TransportLift.start(s, id, "drop", (u.cargo :: { number })[1], t, n)
			end
		end
	end
end

-- The drawn lift of transport `id` at render tick `t`: the descent share
-- (0..1) and, picking up, where the unit stood (the belly slides over it by
-- the same share, and back on the way up); nil when it isn't lifting.
function TransportLift.of(s: State, id: number, t: number): (number?, number?, number?)
	local l = s.lifts[id]
	if l == nil then
		return nil, nil, nil
	end
	return TransportLift.share(l, t), l.overX, l.overZ
end

return TransportLift
