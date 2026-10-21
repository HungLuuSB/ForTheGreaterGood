--!strict
-- Combat effects from network events (guide 15.3, net.md sections 7–8).
-- Pure Luau (C-7); Render/Effects draws the result.
--
-- Everything plays on the render clock (Interp), so a shell bursts where the
-- interpolated tanks are: an event or a death waits in the queue until the
-- render tick reaches its tick.
--   * SPAWN_PROJ starts a projectile the client steps itself with the
--     server's math (Ballistics.steer for homing, Ballistics.step); IMPACT
--     ends it and bursts; DECOYED / LOST_LOCK snap it and clear its target;
--     homing corrections snap the prediction and blend the drawn offset away
--     over 5 ticks (errors above 60 studs snap).
--   * FIRE draws a tracer from the shooter's muzzle to the end point.
--   * DEATH bursts at the unit, bigger with severity.
-- Caps (guide 15.3): every projectile is followed, but at most
-- MAX_PROJECTILES are drawn; at most MAX_EXPLOSIONS bursts and MAX_TRACERS
-- tracers live at once. Over a cap the least important goes: importance =
-- size / (1 + distance to the camera focus / 100).

local Ballistics = require("@shared/Combat/Ballistics")
local Layers = require("@shared/Grid/Layers")
local Schema = require("@shared/Net/Schema")
local Interp = require("./Interp")
local World = require("./World")

local Effects = {}

Effects.MAX_PROJECTILES = 150
Effects.MAX_EXPLOSIONS = 60
Effects.MAX_TRACERS = 100
Effects.BLEND_TICKS = 5
Effects.LAUNCH_BLEND = 3 -- ticks for a shell to go from the drawn barrel tip onto the server's path (C-27)
Effects.SHOOTER_RADIUS = 12 -- studs: a unit this close to a launch point with that weapon fired it
Effects.SNAP_STUDS = 60
Effects.TRACER_SECONDS = 0.09
Effects.EXPLOSION_SECONDS = 0.55
Effects.DEATH_SECONDS = 0.9

local DT = 1 / 15
local EK = Schema.EventKind

export type Proj = {
	id: number,
	x: number, -- prediction at `tick`
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	ox: number, -- drawn = prediction + gap × offsetLeft: the gap to a ghost of the old course
	oy: number,
	oz: number,
	ovx: number?, -- the ghost's velocity minus the prediction's (the ghost flies on, C-36)
	ovy: number?,
	ovz: number?,
	blend: number, -- ticks the gap takes to close (0 = none)
	age: number, -- ticks of it gone
	weapon: any,
	target: number,
	ttl: number, -- ticks left (fallback; IMPACT normally ends it)
	size: number,
	launch: { number }?, -- launched early (C-27): the server's state at its spawn tick { tick, x, y, z, vx, vy, vz }, taken as is on that step
}

export type Burst = { x: number, y: number, z: number, radius: number, born: number, life: number, kind: string, size: number }
export type Tracer = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, born: number, life: number, hit: boolean, size: number }

export type Fx = {
	projectiles: { [number]: Proj },
	bursts: { Burst },
	tracers: { Tracer },
	pendingDeaths: { World.Death },
	tick: number, -- projectiles are stepped up to this sim tick
	focusX: number,
	focusZ: number,
	skipped: { bursts: number, tracers: number },
	applied: { [string]: number }, -- events applied per kind name (diagnostics)
	late: { n: number, sum: number, max: number }, -- render ticks between an event's tick and when it played (diagnostics)
	launches: { n: number, fromBarrel: number, sumOffset: number }, -- shells started at a drawn barrel tip, and its distance from the server's launch point (diagnostics)
	shots: { { number } }, -- { unitId, slot } of shots played since the caller last cleared it (piece scripts' FireWeapon)
}

function Effects.new(): Fx
	return {
		projectiles = {},
		bursts = {},
		tracers = {},
		pendingDeaths = {},
		tick = -1,
		focusX = 0,
		focusZ = 0,
		skipped = { bursts = 0, tracers = 0 },
		applied = {},
		late = { n = 0, sum = 0, max = 0 },
		launches = { n = 0, fromBarrel = 0, sumOffset = 0 },
		shots = {},
	}
end

function Effects.importance(fx: Fx, size: number, x: number, z: number): number
	local d = math.sqrt((x - fx.focusX) ^ 2 + (z - fx.focusZ) ^ 2)
	return size / (1 + d / 100)
end

-- Adds `item` to `list` under `cap`: over it, the least important (this one
-- included) is dropped. Returns false when `item` itself was dropped.
local function capped(fx: Fx, list: { any }, item: any, cap: number): boolean
	if #list < cap then
		table.insert(list, item)
		return true
	end
	local worst, worstK = Effects.importance(fx, item.size, item.x or item.x1, item.z or item.z1), 0
	for k, other in list do
		local v = Effects.importance(fx, other.size, other.x or other.x1, other.z or other.z1)
		if v < worst then
			worst, worstK = v, k
		end
	end
	if worstK == 0 then
		return false
	end
	list[worstK] = item
	return true
end

local function weaponSize(weapon: any): number
	return math.max(1, (weapon and weapon.aoe) or 1)
end

local function pos(world: World.World, e: Schema.Event): (number, number, number)
	local x, z = world.grid:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
	return x, (e.y :: number) / Schema.Y_SCALE, z
end

local function vel(e: any): (number, number, number)
	return e.vx / Schema.Y_SCALE, e.vy / Schema.Y_SCALE, e.vz / Schema.Y_SCALE
end

local function ttlTicks(weapon: any): number
	if weapon.type == "BOMB" then
		return math.ceil(8 * 15) + 1
	end
	return math.ceil((2 * weapon.range / math.max(weapon.projectileSpeed or 1, 1) + 1) * 15) + 1
end

-- Over a cap one effect is always dropped (this one or a less important one).
local function burst(fx: Fx, now: number, x: number, y: number, z: number, radius: number, kind: string, life: number)
	if #fx.bursts >= Effects.MAX_EXPLOSIONS then
		fx.skipped.bursts += 1
	end
	capped(fx, fx.bursts, { x = x, y = y, z = z, radius = radius, born = now, life = life, kind = kind, size = radius }, Effects.MAX_EXPLOSIONS)
end

-- The server's homing aim (Sim/Systems/Projectiles, C-36): the centre of the
-- target's collision cylinder (Combat.aimPoint) at tick `t`, led by the
-- target's heading and speed over the straight-line time to go. The
-- cylinder is UNIT_HEIGHT studs per footprint cell, standing on the cell's
-- height plus altitude, ships DRAFT into the water, submerged submarines
-- SUB_DEPTH under it (mirrors of Combat's constants: request 11).
Effects.UNIT_HEIGHT = 6
Effects.DRAFT = 3
Effects.SUB_DEPTH = 10

local function cellHeights(world: World.World, x: number, z: number): (number, number)
	local layers = world.layers
	if layers == nil then
		return 0, 0
	end
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	local i = math.clamp(cz, 0, g.cellsZ - 1) * g.cellsX + math.clamp(cx, 0, g.cellsX - 1)
	return Layers.getHeight(layers, i), Layers.getWater(layers, i)
end

local function homingAim(world: World.World, target: World.Unit, t: number, px: number, py: number, pz: number, speed: number): (number, number, number)
	local x, z, alt, heading = Interp.sample(target, t)
	local x0, z0 = Interp.sample(target, t - 1)
	local def = World.def(world, target)
	local height = Effects.UNIT_HEIGHT * (if def then def.footprint else 1)
	local ground, water = cellHeights(world, x, z)
	local base
	if def and def.domain == "naval" then
		base = ground + water - (if bit32.band(target.state or 0, Schema.UnitState.SUBMERGED) ~= 0 then Effects.SUB_DEPTH + height else Effects.DRAFT)
	else
		base = ground + alt
	end
	local y = base + height / 2
	-- lead: where the target will be when the missile gets there
	local tgo = math.sqrt((x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2) / math.max(speed, 1)
	local tv = math.sqrt((x - x0) ^ 2 + (z - z0) ^ 2) / DT -- its speed over the last tick
	return x + math.sin(heading) * tv * tgo, y, z + math.cos(heading) * tv * tgo
end

-- The share of the drawn offset left `frac` ticks into the current tick:
-- eased in and out (smoothstep), so the drawn path keeps its direction
-- when a correction or a launch offset starts closing (C-36: a linear
-- blend turned at once, a corner at every correction).
local function offsetLeft(p: Proj, frac: number): number
	if p.blend <= 0 then
		return 0
	end
	local s = math.clamp((p.age + frac) / p.blend, 0, 1)
	return 1 - s * s * (3 - 2 * s)
end

-- One tick of the blend. `dvx, dvy, dvz`: how the prediction's velocity
-- changed by steering this tick (the ghost doesn't steer).
local function advanceBlend(p: Proj, dvx: number, dvy: number, dvz: number)
	if p.blend > 0 then
		local vx, vy, vz = (p.ovx or 0) - dvx, (p.ovy or 0) - dvy, (p.ovz or 0) - dvz
		p.ovx, p.ovy, p.ovz = vx, vy, vz
		p.ox, p.oy, p.oz = p.ox + vx * DT, p.oy + vy * DT, p.oz + vz * DT
		p.age += 1
		if p.age >= p.blend then
			p.ox, p.oy, p.oz, p.blend, p.age = 0, 0, 0, 0, 0
			p.ovx, p.ovy, p.ovz = 0, 0, 0
		end
	end
end

-- The gap to the ghost `frac` ticks into the current tick, scaled by what is left of the blend.
local function gapAt(p: Proj, frac: number): (number, number, number)
	local left = offsetLeft(p, frac)
	if left <= 0 then
		return 0, 0, 0
	end
	local f = frac * DT
	return (p.ox + (p.ovx or 0) * f) * left, (p.oy + (p.ovy or 0) * f) * left, (p.oz + (p.ovz or 0) * f) * left
end

-- Restarts the blend from where the projectile is drawn now (frac 0) to its
-- new state: the ghost keeps the drawn position and course.
local function reblend(p: Proj, x: number, y: number, z: number, vx: number, vy: number, vz: number)
	local left = offsetLeft(p, 0)
	local gx, gy, gz = gapAt(p, 0)
	local dx, dy, dz = p.x + gx, p.y + gy, p.z + gz
	local dvx, dvy, dvz = p.vx + (p.ovx or 0) * left, p.vy + (p.ovy or 0) * left, p.vz + (p.ovz or 0) * left
	p.x, p.y, p.z, p.vx, p.vy, p.vz = x, y, z, vx, vy, vz
	p.ox, p.oy, p.oz = dx - x, dy - y, dz - z
	p.ovx, p.ovy, p.ovz = dvx - vx, dvy - vy, dvz - vz
	p.blend, p.age = Effects.BLEND_TICKS, 0
	if p.ox * p.ox + p.oy * p.oy + p.oz * p.oz > Effects.SNAP_STUDS ^ 2 then
		p.ox, p.oy, p.oz, p.blend = 0, 0, 0, 0
		p.ovx, p.ovy, p.ovz = 0, 0, 0
	end
	return dx, dy, dz
end

-- One sim tick of every projectile, into tick `t` (the server's order:
-- steer, then step).
local function stepProjectiles(fx: Fx, world: World.World, t: number)
	for id, p in fx.projectiles do
		p.ttl -= 1
		if p.ttl <= 0 then
			fx.projectiles[id] = nil
			continue
		end
		local weapon = p.weapon
		local launch = p.launch
		if launch and launch[1] == t then
			-- the step into the spawn tick: the server's own state (a homing
			-- missile already steered during it)
			p.x, p.y, p.z, p.vx, p.vy, p.vz = launch[2], launch[3], launch[4], launch[5], launch[6], launch[7]
			p.launch = nil
			advanceBlend(p, 0, 0, 0)
			continue
		end
		p.launch = nil
		local target = if p.target ~= 0 then world.units[p.target] else nil
		local svx, svy, svz = p.vx, p.vy, p.vz
		if weapon.turnRate and target then
			local speed = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz)
			local tx, ty, tz = homingAim(world, target, t, p.x, p.y, p.z, speed)
			p.vx, p.vy, p.vz = Ballistics.steer(p.vx, p.vy, p.vz, tx - p.x, ty - p.y, tz - p.z, math.rad(weapon.turnRate) * DT)
		end
		local dvx, dvy, dvz = p.vx - svx, p.vy - svy, p.vz - svz
		p.x, p.y, p.z, p.vx, p.vy, p.vz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, weapon.gravity or 0, DT)
		advanceBlend(p, dvx, dvy, dvz)
	end
end

local KIND_NAME = { [0] = "correction", [EK.FIRE] = "FIRE", [EK.SPAWN_PROJ] = "SPAWN_PROJ", [EK.IMPACT] = "IMPACT", [EK.DECOYED] = "DECOYED", [EK.LOST_LOCK] = "LOST_LOCK" }

-- The unit (and weapon slot) that launched a `weaponIndex` shell from
-- (x, z): the nearest unit with that weapon within SHOOTER_RADIUS. The
-- server launches from the unit's center at muzzle height (Weapons.luau).
local function launcher(world: World.World, weaponIndex: number, x: number, z: number): (number?, number?)
	local bestId, bestSlot, bestD = nil, nil, Effects.SHOOTER_RADIUS ^ 2
	for id, u in world.units do
		if u.tier ~= "tactical" then
			continue
		end
		local def = World.def(world, u)
		if def == nil then
			continue
		end
		for slot, wslot in def.weapons do
			if wslot.weaponIndex == weaponIndex then
				local d = ((u.rx or u.x) - x) ^ 2 + ((u.rz or u.z) - z) ^ 2
				if d < bestD then
					bestId, bestSlot, bestD = id, slot, d
				end
			end
		end
	end
	return bestId, bestSlot
end

-- `early`: applied one tick before its tick (C-27). SPAWN_PROJ carries the
-- state after the server's first step, so the shell is stepped back one
-- tick to where the server launched it.
local function apply(fx: Fx, world: World.World, e: any, now: number, muzzleOf: ((number, number) -> (number?, number?, number?))?, early: boolean?)
	local kind = e.kind
	local name = KIND_NAME[kind] or tostring(kind)
	fx.applied[name] = (fx.applied[name] or 0) + 1
	if kind == EK.SPAWN_PROJ then
		local weapon = world.defs.weaponByIndex[e.weaponIndex]
		if weapon == nil then
			return
		end
		local x, y, z = pos(world, e)
		local vx, vy, vz = vel(e)
		local launch = if early then { e.tick, x, y, z, vx, vy, vz } else nil
		if early then
			-- invert Ballistics.step over one tick (unsteered: the step into the
			-- spawn tick then takes the server's state as is, see stepProjectiles)
			local g = weapon.gravity or 0
			vy += g * DT
			x, y, z = x - vx * DT, y - vy * DT + 0.5 * g * DT * DT, z - vz * DT
		end
		-- drawn from the shooter's barrel tip, blended onto the server's path
		local shooter, slot = launcher(world, e.weaponIndex, x, z)
		if shooter and early then
			table.insert(fx.shots, { shooter, slot :: number })
		end
		local mx, my, mz
		if shooter and muzzleOf then
			mx, my, mz = muzzleOf(shooter, slot :: number)
		end
		local ox, oy, oz, blend = 0, 0, 0, 0
		if mx and (mx - x) ^ 2 + ((my :: number) - y) ^ 2 + ((mz :: number) - z) ^ 2 < Effects.SNAP_STUDS ^ 2 then
			ox, oy, oz, blend = mx - x, (my :: number) - y, (mz :: number) - z, Effects.LAUNCH_BLEND
			fx.launches.fromBarrel += 1
			fx.launches.sumOffset += math.sqrt(ox * ox + oy * oy + oz * oz)
		end
		if early then
			fx.launches.n += 1
		end
		fx.projectiles[e.projId] = {
			id = e.projId,
			x = x,
			y = y,
			z = z,
			vx = vx,
			vy = vy,
			vz = vz,
			ox = ox,
			oy = oy,
			oz = oz,
			blend = blend,
			age = 0,
			ovx = 0,
			ovy = 0,
			ovz = 0,
			weapon = weapon,
			target = e.targetId or 0,
			ttl = ttlTicks(weapon),
			size = weaponSize(weapon),
			launch = launch,
		}
		burst(fx, now, x + ox, y + oy, z + oz, 0.8, "muzzle", 0.12)
	elseif kind == EK.IMPACT then
		local p = fx.projectiles[e.projId]
		fx.projectiles[e.projId] = nil
		local x, y, z = pos(world, e)
		local r = if p then weaponSize(p.weapon) else 2
		burst(fx, now, x, y, z, r, "impact", Effects.EXPLOSION_SECONDS)
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		local p = fx.projectiles[e.projId]
		if p then
			-- like a correction: the server's new state, drawn from where the
			-- missile is and eased onto its new course (no jump, C-36)
			local x, y, z = pos(world, e)
			local vx, vy, vz = vel(e)
			local dx, dy, dz = reblend(p, x, y, z, vx, vy, vz)
			p.target = 0
			burst(fx, now, dx, dy, dz, 1.2, if kind == EK.DECOYED then "decoy" else "lost", 0.35)
		end
	elseif kind == EK.FIRE then
		table.insert(fx.shots, { e.unitId, e.slot })
		local x1, y1, z1 = pos(world, e)
		local shooter = world.units[e.unitId]
		local x0, y0, z0
		if muzzleOf then
			x0, y0, z0 = muzzleOf(e.unitId, e.slot)
		end
		if x0 == nil and shooter then
			x0, y0, z0 = shooter.rx or shooter.x, (shooter.ry or World.groundY(world, shooter.x, shooter.z)) + 2.5, shooter.rz or shooter.z
		end
		if x0 then
			local def = shooter and World.def(world, shooter)
			local slot = def and def.weapons[e.slot]
			local weapon = slot and world.defs.weaponByIndex[slot.weaponIndex or 0]
			local t: Tracer = { x0 = x0, y0 = y0 :: number, z0 = z0 :: number, x1 = x1, y1 = y1, z1 = z1, born = now, life = Effects.TRACER_SECONDS, hit = e.hit == true, size = weaponSize(weapon) }
			if #fx.tracers >= Effects.MAX_TRACERS then
				fx.skipped.tracers += 1
			end
			capped(fx, fx.tracers, t, Effects.MAX_TRACERS)
			burst(fx, now, x0, y0 :: number, z0 :: number, 0.7, "muzzle", 0.1)
		end
	elseif kind == 0 then
		-- homing correction (Projectiles channel): snap the prediction, keep
		-- drawing where it was, blend the gap away
		local p = fx.projectiles[e.projId]
		if p then
			local x, z = world.grid:decode(e.cell, e.offX, e.offZ)
			local vx, vy, vz = vel(e)
			reblend(p, x, e.y / Schema.Y_SCALE, z, vx, vy, vz)
		end
	end
end

-- Plays everything due by render tick `renderTick` (fractional sim tick).
-- Consumes world.events up to it and copies world.died (the caller clears
-- that). `muzzleOf(unitId, slot)` gives a drawn muzzle position, if known.
function Effects.update(fx: Fx, world: World.World, renderTick: number, now: number, focusX: number, focusZ: number, muzzleOf: ((number, number) -> (number?, number?, number?))?)
	fx.focusX, fx.focusZ = focusX, focusZ
	for _, d in world.died do
		table.insert(fx.pendingDeaths, d)
	end
	if renderTick < 0 then
		return
	end
	local due = math.floor(renderTick)
	if fx.tick < 0 then
		fx.tick = due - 1
	end
	-- events and projectile steps interleave tick by tick: a projectile
	-- spawned at tick T is stepped from T + 1 on, as on the server
	local events = world.events
	local k = 1
	while fx.tick < due do
		local t = fx.tick + 1
		stepProjectiles(fx, world, t)
		while k <= #events and ((events[k] :: any).tick or 0) <= t do
			local late = renderTick - ((events[k] :: any).tick or renderTick)
			fx.late.n += 1
			fx.late.sum += late
			fx.late.max = math.max(fx.late.max, late)
			if not (events[k] :: any).launched then
				apply(fx, world, events[k], now, muzzleOf)
			end
			k += 1
		end
		fx.tick = t
	end
	if k > 1 then
		-- keep only the events not due yet
		local rest = table.move(events, k, #events, 1, {})
		table.clear(events)
		table.move(rest, 1, #rest, 1, events)
	end
	-- a shell launched during the coming tick starts now, from its launch
	-- point: SPAWN_PROJ arrives ahead of the render clock (Interp's delay)
	-- and carries the position after a tick of flight, so played at its
	-- tick it would appear a tick's travel out of the barrel (C-27)
	for i = 1, #events do
		local e = events[i] :: any
		if e.kind == EK.SPAWN_PROJ and e.tick == fx.tick + 1 and not e.launched then
			e.launched = true
			apply(fx, world, e, now, muzzleOf, true)
		end
	end
	-- a shell that hits during the coming tick bursts when its drawn path
	-- reaches the impact point, not at the tick's end: drawn on, it would fly
	-- up to a tick's travel past the target first (C-26). Events arrive
	-- ahead of the render clock (Interp's delay), so the IMPACT is known.
	local frac = renderTick - fx.tick
	for i = #events, 1, -1 do
		local e = events[i] :: any
		if e.kind ~= EK.IMPACT or e.tick ~= fx.tick + 1 then
			continue
		end
		local p = fx.projectiles[e.projId]
		if p == nil then
			continue
		end
		local x, y, z = pos(world, e)
		-- where it is drawn now and at the tick's end (the server's step plus
		-- the offset still closing after a launch, C-27); it bursts once it is
		-- as far along that move as the point nearest the impact
		local g0x, g0y, g0z = gapAt(p, 0)
		local g1x, g1y, g1z = gapAt(p, 1)
		local sx, sy, sz = p.x + g0x, p.y + g0y, p.z + g0z
		local nx, ny, nz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, p.weapon.gravity or 0, DT)
		local dx, dy, dz = nx + g1x - sx, ny + g1y - sy, nz + g1z - sz
		local len2 = dx * dx + dy * dy + dz * dz
		local along = if len2 > 1e-9 then ((x - sx) * dx + (y - sy) * dy + (z - sz) * dz) / len2 else 1
		if frac >= math.clamp(along, 0, 1) then
			table.remove(events, i)
			apply(fx, world, e, now, muzzleOf)
		end
	end
	for i = #fx.pendingDeaths, 1, -1 do
		local d = fx.pendingDeaths[i]
		if d.tick <= renderTick then
			table.remove(fx.pendingDeaths, i)
			local def = if d.defIndex then world.defs.unitByIndex[d.defIndex] else nil
			local r = (if def then def.footprint else 1) * 3 * (1 + d.severity / 255)
			burst(fx, now, d.x, World.groundY(world, d.x, d.z) + 1.5, d.z, r, "death", Effects.DEATH_SECONDS)
		end
	end
	for i = #fx.bursts, 1, -1 do
		if now - fx.bursts[i].born >= fx.bursts[i].life then
			table.remove(fx.bursts, i)
		end
	end
	for i = #fx.tracers, 1, -1 do
		if now - fx.tracers[i].born >= fx.tracers[i].life then
			table.remove(fx.tracers, i)
		end
	end
end

-- Projectiles to draw at render tick `renderTick`: at most MAX_PROJECTILES,
-- the most important first. Each entry: { proj, x, y, z }.
function Effects.visible(fx: Fx, renderTick: number): { { any } }
	local frac = math.clamp(renderTick - fx.tick, 0, 1) * DT
	local list = {}
	for _, p in fx.projectiles do
		local x, y, z = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, p.weapon.gravity or 0, frac)
		-- the offset shrinks smoothly through the tick (stepProjectiles cuts it a step at a time)
		local gx, gy, gz = gapAt(p, math.clamp(renderTick - fx.tick, 0, 1))
		table.insert(list, { p, x + gx, y + gy, z + gz, Effects.importance(fx, p.size, x, z) })
	end
	if #list > Effects.MAX_PROJECTILES then
		table.sort(list, function(a, b)
			return a[5] > b[5]
		end)
		for i = #list, Effects.MAX_PROJECTILES + 1, -1 do
			list[i] = nil
		end
	end
	return list
end

-- Forgets everything (a new WELCOME).
function Effects.clear(fx: Fx)
	table.clear(fx.projectiles)
	table.clear(fx.bursts)
	table.clear(fx.tracers)
	table.clear(fx.pendingDeaths)
	table.clear(fx.shots)
	fx.tick = -1
end

return Effects
