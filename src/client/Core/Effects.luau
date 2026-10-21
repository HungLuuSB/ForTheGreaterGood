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
local Schema = require("@shared/Net/Schema")
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
	ox: number, -- drawn = prediction + offset (blends to 0 after a correction)
	oy: number,
	oz: number,
	blend: number,
	weapon: any,
	target: number,
	ttl: number, -- ticks left (fallback; IMPACT normally ends it)
	size: number,
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

-- One sim tick of every projectile (the server's order: steer, then step).
local function stepProjectiles(fx: Fx, world: World.World)
	for id, p in fx.projectiles do
		p.ttl -= 1
		if p.ttl <= 0 then
			fx.projectiles[id] = nil
			continue
		end
		local weapon = p.weapon
		local target = if p.target ~= 0 then world.units[p.target] else nil
		if weapon.turnRate and target then
			local ty = if target.alt and target.alt > 0 then World.groundY(world, target.x, target.z) + target.alt else p.y
			p.vx, p.vy, p.vz = Ballistics.steer(p.vx, p.vy, p.vz, target.x - p.x, ty - p.y, target.z - p.z, math.rad(weapon.turnRate) * DT)
		end
		p.x, p.y, p.z, p.vx, p.vy, p.vz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, weapon.gravity or 0, DT)
		if p.blend > 0 then
			local k = 1 / p.blend
			p.ox, p.oy, p.oz = p.ox * (1 - k), p.oy * (1 - k), p.oz * (1 - k)
			p.blend -= 1
		end
	end
end

local KIND_NAME = { [0] = "correction", [EK.FIRE] = "FIRE", [EK.SPAWN_PROJ] = "SPAWN_PROJ", [EK.IMPACT] = "IMPACT", [EK.DECOYED] = "DECOYED", [EK.LOST_LOCK] = "LOST_LOCK" }

-- The drawn muzzle of the unit that launched a `weaponIndex` shell from
-- (x, z): the nearest unit with that weapon within SHOOTER_RADIUS. The
-- server launches from the unit's center at muzzle height (Weapons.luau).
local function launcherMuzzle(world: World.World, weaponIndex: number, x: number, z: number, muzzleOf: ((number, number) -> (number?, number?, number?))?): (number?, number?, number?)
	if muzzleOf == nil then
		return nil, nil, nil
	end
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
	if bestId == nil then
		return nil, nil, nil
	end
	return muzzleOf(bestId, bestSlot :: number)
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
		if early then
			-- invert Ballistics.step over one tick
			local g = weapon.gravity or 0
			vy += g * DT
			x, y, z = x - vx * DT, y - vy * DT + 0.5 * g * DT * DT, z - vz * DT
		end
		-- drawn from the shooter's barrel tip, blended onto the server's path
		local mx, my, mz = launcherMuzzle(world, e.weaponIndex, x, z, muzzleOf)
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
			weapon = weapon,
			target = e.targetId or 0,
			ttl = ttlTicks(weapon),
			size = weaponSize(weapon),
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
			p.x, p.y, p.z = pos(world, e)
			p.vx, p.vy, p.vz = vel(e)
			p.ox, p.oy, p.oz, p.blend = 0, 0, 0, 0
			p.target = 0
			burst(fx, now, p.x, p.y, p.z, 1.2, if kind == EK.DECOYED then "decoy" else "lost", 0.35)
		end
	elseif kind == EK.FIRE then
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
			local dx, dy, dz = p.x + p.ox, p.y + p.oy, p.z + p.oz
			local x, z = world.grid:decode(e.cell, e.offX, e.offZ)
			p.x, p.y, p.z = x, e.y / Schema.Y_SCALE, z
			p.vx, p.vy, p.vz = vel(e)
			p.ox, p.oy, p.oz = dx - p.x, dy - p.y, dz - p.z
			p.blend = Effects.BLEND_TICKS
			if p.ox * p.ox + p.oy * p.oy + p.oz * p.oz > Effects.SNAP_STUDS ^ 2 then
				p.ox, p.oy, p.oz, p.blend = 0, 0, 0, 0
			end
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
		stepProjectiles(fx, world)
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
		local need = math.sqrt((x - p.x - p.ox) ^ 2 + (y - p.y - p.oy) ^ 2 + (z - p.z - p.oz) ^ 2) -- from where it is drawn
		local step = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz) * DT
		if frac >= math.clamp(need / math.max(step, 1e-6), 0, 1) then
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
		local k = if p.blend > 0 then 1 - math.clamp(renderTick - fx.tick, 0, 1) / p.blend else 1
		table.insert(list, { p, x + p.ox * k, y + p.oy * k, z + p.oz * k, Effects.importance(fx, p.size, x, z) })
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
	fx.tick = -1
end

return Effects
