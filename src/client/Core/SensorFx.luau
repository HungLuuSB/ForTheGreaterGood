--!strict
-- Sensor effects (C-211, the user's queue item 7), pure Luau (C-7):
--   sonar ping   own sonar emitters on camera send a ring out across the
--                water to their sonar radius every PING_PERIOD seconds,
--                staggered per unit, fading as it grows;
--   jammer       every finished jammer on camera (own or a seen enemy's;
--   shimmer      jammers have no off switch in the sim) wears a dome at its
--                jam radius that breathes slowly (Render/SensorFx draws it
--                in the shimmering ForceField material).
-- Which units, where and how far along each effect is; Render/SensorFx
-- draws them.

local World = require("./World")

local SensorFx = {}

SensorFx.PING_PERIOD = 3 -- seconds between one emitter's pings
SensorFx.PING_TIME = 1.6 -- seconds a ring takes to reach the sonar radius
SensorFx.BREATH = 4 -- seconds per jammer dome breath

export type Emitter = { id: number, kind: "sonar" | "jam", x: number, y: number, z: number, r: number }

-- Sonar emitters (own team) and jammers (any team) drawn in the tactical
-- tier, finished, in id order.
function SensorFx.emitters(world: World.World): { Emitter }
	local out: { Emitter } = {}
	local ids = {}
	for id, u in world.units do
		if u.tier == "tactical" and u.rx ~= nil then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ids do
		local u = world.units[id]
		local def = World.def(world, u) :: any
		local sensors = def and def.sensors
		local finished = u.build == nil or u.build >= 0.999
		if sensors and finished then
			if (sensors.sonar or 0) > 0 and u.team == world.me.team then
				table.insert(out, { id = id, kind = "sonar", x = u.rx :: number, y = u.ry or 0, z = u.rz or u.z, r = sensors.sonar })
			end
			if (sensors.jam or 0) > 0 then
				table.insert(out, { id = id, kind = "jam", x = u.rx :: number, y = u.ry or 0, z = u.rz or u.z, r = sensors.jam })
			end
		end
	end
	return out
end

-- An emitter's ping phase offset in [0, PING_PERIOD): spread by its id (the
-- golden ratio), so nearby emitters don't ping together.
function SensorFx.offset(id: number): number
	return (id * 0.6180339887) % 1 * SensorFx.PING_PERIOD
end

-- Emitter `id`'s ping at time `now`: its progress 0..1 (radius share; also
-- how far it has faded), or nil between pings.
function SensorFx.ping(id: number, now: number): number?
	local t = (now + SensorFx.offset(id)) % SensorFx.PING_PERIOD
	if t >= SensorFx.PING_TIME then
		return nil
	end
	return t / SensorFx.PING_TIME
end

-- A ring's transparency at `progress`: clear at the start and the end, most
-- visible a quarter of the way out.
function SensorFx.pingTransparency(progress: number): number
	local a = if progress < 0.25 then progress / 0.25 else 1 - (progress - 0.25) / 0.75
	return 1 - 0.75 * math.clamp(a, 0, 1)
end

-- Jammer `id`'s dome breath at `now`: 0..1, out of phase between jammers.
function SensorFx.breath(id: number, now: number): number
	return 0.5 + 0.5 * math.sin((now / SensorFx.BREATH + (id * 0.37) % 1) * 2 * math.pi)
end

return SensorFx
