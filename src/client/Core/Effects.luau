--!strict
-- Combat effects from network events (guide 15.3, net.md sections 7–8).
-- Pure Luau (C-7); Render/Effects draws the result.
--
-- Everything plays on the render clock (Interp), so a shell bursts where the
-- interpolated tanks are: an event or a death waits in the queue until the
-- render tick reaches its tick.
--   * SPAWN_PROJ starts a projectile the client steps itself with the
--     server's math (Shared/Combat/Guidance for homing, S-27; Ballistics.step); IMPACT
--     ends it and bursts; DECOYED / LOST_LOCK snap it and clear its target;
--     homing corrections snap the prediction and blend the drawn offset away
--     over 5 ticks (errors above 60 studs snap).
--   * Strategic missiles (nukes, S-48) fly ballistic; INTERCEPTOR starts a
--     missile that chases one (steered at its state, C-57), INTERCEPTED
--     destroys one in the air, LAUNCH_WARNING is kept in `warnings`.
--   * FIRE draws a tracer from the shooter's muzzle to the end point; SHOT
--     (a shooter the client doesn't have, S-43) from the start point it gives.
--   * DEATH bursts at the unit, bigger with severity.
-- Caps (guide 15.3): every projectile is followed, but at most
-- MAX_PROJECTILES are drawn; at most MAX_EXPLOSIONS bursts and MAX_TRACERS
-- tracers live at once. Over a cap the least important goes: importance =
-- size / (1 + distance to the camera focus / 100).

local Ballistics = require("@shared/Combat/Ballistics")
local Guidance = require("@shared/Combat/Guidance")
local ShieldField = require("@shared/Combat/ShieldField")
local Lofted = require("@shared/Combat/Lofted")
local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local Deaths = require("./Deaths")
local Interp = require("./Interp")
local World = require("./World")

local Effects = {}

Effects.MAX_PROJECTILES = 150
Effects.MAX_EXPLOSIONS = 60
Effects.MAX_TRACERS = 100
Effects.BLEND_TICKS = 5
Effects.REBLEND_KEEP = 0.3 -- a correction during a blend with more than this share left keeps its progress (C-38)
Effects.LAUNCH_BLEND = 3 -- ticks for a shell to go from the drawn barrel tip onto the server's path (C-27)
Effects.SHOOTER_RADIUS = 12 -- studs: a unit this close to a launch point with that weapon fired it
Effects.SNAP_STUDS = 60
Effects.TRACER_SECONDS = 0.09
Effects.LASER_SECONDS = 0.12 -- a laser bolt's line, drawn whole at once (C-198)
-- Where a hitscan shot from (x0, y0, z0) at the server's hit point (x1,
-- y1, z1) meets the hit unit's drawn body (its surface toward the shooter,
-- on the line to the model's middle), or nil (Main sets it from the models)
Effects.bodyAt = nil :: ((x0: number, y0: number, z0: number, x1: number, y1: number, z1: number) -> (number?, number?, number?))?
Effects.BEAM_SECONDS = 0.45 -- a BEAM shot without a duration of its own (S-96, C-112)
-- Beam durations until the sim's `beamDuration` (S-113) is in the defs: the
-- user's look (C-128): Radiance's ray lingers 3 s, Inferno's 1.5 s.
Effects.BEAM_FALLBACK = table.freeze({ ord_radiance_beam = 3, chs_inferno_beam = 1.5 }) :: { [string]: number }
Effects.BEAM_FADE = 1 -- seconds: the last part of a beam's life, when it narrows to nothing

Effects.DEFLECT_SURFACE = 2 -- studs: a beam ending this close to a dome's surface was stopped by it (sim request 50)
Effects.DEFLECT_DOWN = 0.45 -- the glancing ray points at least this steeply into the ground
Effects.DEFLECT_MIN, Effects.DEFLECT_MAX = 8, 90 -- studs: the glancing ray's length
Effects.SHIELD_PULSE = 0.2 -- seconds: a beam held on a dome lights it again this often (the user, C-139)

-- A beam from (x0, y0, z0) that ended at (x1, y1, z1) on the surface of one
-- of `domes` ({ x, y, z, radius }, centers on the ground) from outside: where
-- it glances to, mirrored about the dome's surface and tilted down into the
-- ground (`groundY`), or nil (the user's sketch, C-129; sim request 50).
function Effects.deflection(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, domes: { { number } }, groundY: (number, number) -> number): (number?, number?, number?)
	for _, d in domes do
		local cx, cy, cz, r = d[1], d[2], d[3], d[4]
		local ex, ey, ez = x1 - cx, y1 - cy, z1 - cz
		local de = math.sqrt(ex * ex + ey * ey + ez * ez)
		local sx, sy, sz = x0 - cx, y0 - cy, z0 - cz
		if math.abs(de - r) <= Effects.DEFLECT_SURFACE and sx * sx + sy * sy + sz * sz > r * r and de > 1e-6 then
			local nx, ny, nz = ex / de, ey / de, ez / de
			local vx, vy, vz = x1 - x0, y1 - y0, z1 - z0
			local len = math.sqrt(vx * vx + vy * vy + vz * vz)
			if len < 1e-6 then
				return nil, nil, nil
			end
			vx, vy, vz = vx / len, vy / len, vz / len
			local dot = vx * nx + vy * ny + vz * nz
			local rx, ry, rz = vx - 2 * dot * nx, vy - 2 * dot * ny, vz - 2 * dot * nz
			ry = math.min(ry, -Effects.DEFLECT_DOWN)
			local rl = math.sqrt(rx * rx + ry * ry + rz * rz)
			rx, ry, rz = rx / rl, ry / rl, rz / rl
			local reach = math.clamp((y1 - groundY(x1, z1)) / -ry, Effects.DEFLECT_MIN, Effects.DEFLECT_MAX)
			local gx, gz = x1 + rx * reach, z1 + rz * reach
			return gx, math.max(y1 + ry * reach, groundY(gx, gz)), gz
		end
	end
	return nil, nil, nil
end

Effects.CONTINUE_RADIUS = 3 -- studs: a beam fired this close to a burning one of the same weapon continues it

-- A FIRE / SHOT from a beam weapon whose beam still burns (a dome dropped
-- under it: the rest goes through, sim request 54): moves that beam's end and
-- drops its glance and dome pulses; true if one was found (C-144).
function Effects.continueBeam(fx: Fx, weapon: any, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, hit: boolean, now: number, world: World.World?): boolean
	if weapon == nil or weapon.type ~= "BEAM" then
		return false
	end
	local r2 = Effects.CONTINUE_RADIUS ^ 2
	for _, t in fx.tracers do
		if t.weaponId == weapon.id and now < t.born + t.life and (t.x0 - x0) ^ 2 + (t.y0 - y0) ^ 2 + (t.z0 - z0) ^ 2 <= r2 then
			t.x1, t.y1, t.z1, t.hit = x1, y1, z1, hit
			t.deflect, t.pulseAt = nil, nil
			if world and not hit then
				Effects.glance(world, weapon, t, now) -- now short on another dome
			end
			return true
		end
	end
	return false
end

-- How long a BEAM weapon's ray is drawn.
function Effects.beamSeconds(weapon: any): number
	return weapon.beamDuration or Effects.BEAM_FALLBACK[weapon.id] or Effects.BEAM_SECONDS
end

-- A beam's look `age` seconds into a `life`-second ray: its width (1 = full)
-- and transparency. Full and bright until the last BEAM_FADE seconds (at
-- most half the life), then it narrows to nothing as it fades (C-128).
function Effects.beamLook(age: number, life: number): (number, number)
	local fade = math.min(Effects.BEAM_FADE, life / 2)
	local k = math.clamp((age - (life - fade)) / fade, 0, 1)
	return 1 - k, 0.1 + 0.9 * k * k
end
Effects.EXPLOSION_SECONDS = 0.55
Effects.LAUNCH_SECONDS = 0.5 -- a missile's launch flash (its smoke cloud lasts longer, Render/Vfx)
Effects.FLARE_SECONDS = 1.6 -- flares or chaff falling where a decoyed missile went (C-47)
Effects.DIRCM_SECONDS = 0.45 -- a jammer laser on a decoyed IR missile (C-48)
Effects.NUKE_SECONDS = 4 -- a nuke's detonation flash and fireball (its cloud lasts longer, Render/Vfx; C-57)
Effects.WARNING_LINGER = 4 -- seconds a launch warning stays after its missile is gone
Effects.DEATH_SECONDS = 0.9
Effects.INTERCEPT_PUFF = 3 -- studs: a rocket or missile shot down by point defence (S-149, C-182)
Effects.LOST_FIRST = 1 -- Guidance.lost's tick count on the first step after a LOST_LOCK (C-181)
Effects.MARK_SECONDS = 2.5 -- how long the sensor view shows a correction, decoy or lost lock (C-39)
Effects.MAX_MARKS = 40
-- an impact this close above water at least this deep is a splash (C-82)
Effects.SPLASH_ABOVE = 4
Effects.SPLASH_DEPTH = 0.5

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
	nextState: { number }?, -- the prediction one tick on { x, y, z, vx, vy, vz, dvx, dvy, dvz } (dv: this tick's steering): frames draw the curve between (C-38)
	decoy: { number }?, -- decoyed: { x, y, z, ticks left } of the flare or chaff it follows (S-28)
	lost: number?, -- a radar missile that lost its target: ticks of Guidance.lost it has flown (S-146, C-181)
	turned: boolean?, -- a vertical launch has pitched over onto its target (Guidance.vertical, S-42, C-53)
	chase: Proj?, -- an interceptor's strategic missile (S-48, C-57)
	own: boolean?, -- a strategic missile launched by the local player's team (C-58)
	goal: { number }?, -- a strategic missile's ordered spot x, y, z (SPAWN_STRATEGIC, S-51): it flies Shared/Combat/Lofted
	gone: boolean?, -- ended (impact, interception, time out): interceptors chasing it fly on
	field: { number }?, -- in a shield dome's field (SHIELD_FIELD, S-79, C-91): { cx, cy, cz, radius, force 0..1, phase }; stepped with Shared/Combat/ShieldField
}

-- A shell turned back by a shield dome or breaking through it (SHIELD_HIT,
-- protocol 24, S-79): Render/ShieldDomes lights the dome there.
-- `kind`: "enter" (the shell crossed the dome's surface: SHIELD_FIELD, drawn
-- at once, C-95), "turn" or "breach" (SHIELD_HIT, at the turn deep inside),
-- "absorb" (SHIELD_HIT: a shell destroyed at the surface, S-85; it bursts
-- there with its own explosion, C-185).
export type ShieldHit = { unitId: number, kind: string, x: number, y: number, z: number, mass: number, breach: boolean, projId: number, tick: number }

-- A strategic missile's launch (LAUNCH_WARNING, S-48): every player gets one.
export type Warning = { projId: number, x: number, y: number, z: number, born: number, proj: Proj?, endedAt: number? }

-- A flash, explosion or puff. `kind`: impact, death, muzzle, launch (a
-- missile leaving its launcher), decoy, flare (dropped by the aircraft,
-- falling toward the decoy point), chaff (a cloud at the decoy point), dircm
-- (the aircraft's jammer laser on the missile), lost. `ground`: the ground
-- height under it (air bursts sit well above it); `dx, dy, dz`: the
-- direction it faces (a muzzle's shot, a launch's flight), when known
-- (C-47); `tx, ty, tz`: where flares head, or the missile a laser hits (C-48).
export type Burst = { x: number, y: number, z: number, radius: number, born: number, life: number, kind: string, size: number, ground: number?, water: number?, dx: number?, dy: number?, dz: number?, tx: number?, ty: number?, tz: number?, noCrater: boolean? }
-- A correction, decoy or lost lock (C-39): where the missile was drawn
-- (x0, y0, z0) and the server's state it was moved onto (x1, y1, z1).
export type Mark = { kind: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, born: number }
export type Tracer = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, born: number, life: number, hit: boolean, size: number, beam: string?, deflect: { number }?, pulseAt: number?, pulseMass: number?, weaponId: string?, laser: { number }?, ramp: number?, flame: { number }?, beamColor: { number }? } -- beamColor: a BEAM weapon's fx.color (H38); beam: the shooter's faction for a BEAM weapon (C-112): a held line, not a streak; deflect: where a beam stopped by a shield glances to (C-129)

export type Fx = {
	projectiles: { [number]: Proj },
	bursts: { Burst },
	tracers: { Tracer },
	pendingDeaths: { World.Death },
	crashes: { { at: number, x: number, y: number, z: number, radius: number } }, -- falling aircraft: where and at which render tick they hit (C-48)
	tick: number, -- projectiles are stepped up to this sim tick
	focusX: number,
	focusZ: number,
	skipped: { bursts: number, tracers: number, stale: number }, -- stale: FIREs drawn without their streak (H37)
	applied: { [string]: number }, -- events applied per kind name (diagnostics)
	late: { n: number, sum: number, max: number }, -- render ticks between an event's tick and when it played (diagnostics)
	launches: { n: number, fromBarrel: number, sumOffset: number }, -- shells started at a drawn barrel tip, and its distance from the server's launch point (diagnostics)
	shots: { { number } }, -- { unitId, slot } of shots played since the caller last cleared it (piece scripts' FireWeapon)
	ramps: { [number]: { number } }, -- a ramping beam's run on one target (C-198)
	marks: { Mark }, -- the sensor view's corrections, decoys and lost locks, oldest first (C-39)
	warnings: { Warning }, -- strategic launches, kept while the missile flies and WARNING_LINGER after (C-57)
	shieldHits: { ShieldHit }, -- since the caller last cleared it (C-91)
}

function Effects.new(): Fx
	return {
		projectiles = {},
		bursts = {},
		tracers = {},
		pendingDeaths = {},
		crashes = {},
		tick = -1,
		focusX = 0,
		focusZ = 0,
		skipped = { bursts = 0, tracers = 0, stale = 0 },
		applied = {},
		late = { n = 0, sum = 0, max = 0 },
		launches = { n = 0, fromBarrel = 0, sumOffset = 0 },
		shots = {},
		ramps = {}, -- a ramping beam's run on one target: unit*16+slot → { started, last } (C-198)
		marks = {},
		warnings = {},
		shieldHits = {},
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

-- Weapons whose impact effect is a large one (fx.impact "..._large", the
-- radar SAMs' heavy warheads) explode this much bigger than their blast
-- radius alone gives (C-52).
Effects.LARGE_IMPACT = 1.8
Effects.FLAME_SECONDS = 0.35 -- a flame stream's life (S-181)
Effects.HUGE_BLAST = 90 -- studs: a death blast this wide plays the nuke's look scaled to it (F15)
Effects.BLAST_SHOWN = 0.6 -- an ordinary death blast's burst, as a share of its damage radius
Effects.BOLT_HEIGHT = 5 -- studs a D-Gun bolt rides over the ground (the server's Combat.BOLT_HEIGHT, S-194)
Effects.BOLT_BEHIND = 1.5 -- seconds of a D-Gun bolt's path behind it where a death counts as its burn

-- The D-Gun bolt that a unit of `def` dying at (x, z) was burned by, or nil:
-- one whose last BOLT_BEHIND seconds of path pass within its reach and the
-- unit's radius (C-266: the server sends no IMPACT for a pass-through, S-194).
function Effects.boltThrough(fx: Fx, x: number, z: number, def: any): Proj?
	local radius = (if def then def.footprint else 1) * 3.6
	for _, p in fx.projectiles do
		local reach = p.weapon.bolt
		if reach == nil then
			continue
		end
		local x1, z1 = p.x + p.vx * 0.2, p.z + p.vz * 0.2 -- (a tick or so ahead: deaths lag the burn)
		local x0, z0 = p.x - p.vx * Effects.BOLT_BEHIND, p.z - p.vz * Effects.BOLT_BEHIND
		local dx, dz = x1 - x0, z1 - z0
		local len2 = dx * dx + dz * dz
		local t = if len2 > 0 then math.clamp(((x - x0) * dx + (z - z0) * dz) / len2, 0, 1) else 0
		local ex, ez = x0 + dx * t - x, z0 + dz * t - z
		if ex * ex + ez * ez <= (reach + radius + 2) ^ 2 then
			return p
		end
	end
	return nil
end
-- A shot with no blast whose impact is "explosion_small" (the Thug's and
-- Mace's plasma, S-190) bursts like a tank shell's small hit: the Lancer's
-- (aoe 3), not the smallest burst its missing blast radius would give.
Effects.SMALL_HIT = 3
function Effects.impactSize(weapon: any): number
	local impact = weapon and weapon.fx and weapon.fx.impact
	if impact == "explosion_small" and ((weapon :: any).aoe or 0) <= 0 then
		return Effects.SMALL_HIT
	end
	local large = type(impact) == "string" and string.find(impact, "_large", 1, true) ~= nil
	return weaponSize(weapon) * (if large then Effects.LARGE_IMPACT else 1)
end

-- A shot's tracer: a BEAM weapon's held ray (its duration, its faction's
-- colour; stopped by a known dome it glances off and pulses the dome, C-129,
-- C-139), else a quick streak.
Effects.STALE_STUDS = 24 -- a drawn shooter this far from its last record draws no streak (H37)

-- Whether a FIRE's start (the shooter as drawn, `x0, z0`) is stale: no live
-- muzzle (`muzzled`) and the shooter not in the tactical tier, or drawn
-- more than STALE_STUDS from its record; or the shot reaches farther
-- than `weapon` could fire from there. Pure (C-7).
function Effects.staleStart(shooter: World.Unit?, weapon: any, x0: number, z0: number, x1: number, z1: number, muzzled: boolean): boolean
	if shooter == nil then
		return true
	end
	if not muzzled then
		if shooter.tier ~= "tactical" then
			return true -- a strategic record: an 8-stud square, or its spot when it left the camera area
		end
		local rx, rz = shooter.rx, shooter.rz
		if rx and rz and (rx - shooter.x) ^ 2 + (rz - shooter.z) ^ 2 > Effects.STALE_STUDS ^ 2 then
			return true
		end
	end
	local range = weapon and weapon.range
	if range and range > 0 and not weapon.fullLength then
		local reach = range * 1.5 + 40
		if (x1 - x0) ^ 2 + (z1 - z0) ^ 2 > reach * reach then
			return true
		end
	end
	return false
end

local function shotTracer(world: World.World, weapon: any, faction: string?, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, hit: boolean, now: number): Tracer
	local isBeam = weapon ~= nil and weapon.type == "BEAM"
	local t: Tracer = { x0 = x0, y0 = y0, z0 = z0, x1 = x1, y1 = y1, z1 = z1, born = now, life = if isBeam then Effects.beamSeconds(weapon) else Effects.TRACER_SECONDS, hit = hit, size = if weapon then weaponSize(weapon) else 1, beam = if isBeam then (faction or "order") else nil, weaponId = if weapon then weapon.id else nil }
	-- a laser (S-157): the whole line at once in the weapon's colour (C-198)
	local fxDef = weapon and weapon.fx
	if fxDef and fxDef.tracer == "laser" then
		local c = fxDef.color -- { r, g, b } (0..255, S-157)
		t.laser = if c then { c.r or c[1] or 255, c.g or c[2] or 255, c.b or c[3] or 255 } else { 255, 255, 255 }
		t.life = Effects.LASER_SECONDS
	end
	-- a beam in its weapon's colour (H38: Radiance's electric blue), else its faction's
	if isBeam and fxDef and fxDef.color then
		local c = fxDef.color
		t.beamColor = { c.r or c[1] or 255, c.g or c[2] or 255, c.b or c[3] or 255 }
	end
	-- a flame (S-181, the Dragon): a short thick stream in the weapon's colour
	if fxDef and fxDef.trail == "flame" then
		local c = fxDef.color
		t.flame = if c then { c.r or 255, c.g or 120, c.b or 20 } else { 255, 120, 20 }
		t.life = Effects.FLAME_SECONDS
	end
	-- a beam that runs on through its whole line (S-181, the Centurion's
	-- `fullLength`): drawn out to the weapon's range past the target
	if weapon and weapon.fullLength and weapon.range then
		local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		if len > 1e-3 and len < weapon.range then
			local k = weapon.range / len
			t.x1, t.y1, t.z1 = x0 + dx * k, y0 + dy * k, z0 + dz * k
		end
	end
	if isBeam and not hit then
		Effects.glance(world, weapon, t, now)
	end
	return t
end

-- A ramping beam's intensity now (0..1, C-198): time on one target over the
-- weapon's ramp.seconds, as the server ramps its damage (S-157); firing
-- that paused longer than 1.6 shot gaps starts over.
function Effects.ramp(fx: Fx, key: number, weapon: any, now: number): number
	local r = fx.ramps[key]
	local gap = (weapon.reload or 0.2) * 1.6
	if r == nil or now - r[2] > gap then
		r = { now, now }
		fx.ramps[key] = r
	end
	r[2] = now
	return math.clamp((now - r[1]) / (weapon.ramp.seconds or 4), 0, 1)
end

-- A beam that ended short of its target: on a known dome's surface, it
-- glances off into the ground and pulses the dome (C-129, C-139); else
-- nothing to add. Also re-run when a burning beam's end moves (C-144).
function Effects.glance(world: World.World, weapon: any, t: Tracer, now: number)
	t.deflect, t.pulseAt = nil, nil
	local x0, y0, z0, x1, y1, z1 = t.x0, t.y0, t.z0, t.x1, t.y1, t.z1
	do
		local domes = {}
		for id in world.shields do
			local g = world.units[id]
			local gdef = g and World.def(world, g)
			local r = gdef and gdef.shield and gdef.shield.radius
			if r then
				table.insert(domes, { g.x, World.groundY(world, g.x, g.z), g.z, r })
			end
		end
		for _, rd in world.remoteDomes do
			table.insert(domes, { rd.x, rd.y, rd.z, rd.radius }) -- unseen generators' domes (S-122)
		end
		local gx, gy, gz = Effects.deflection(x0, y0, z0, x1, y1, z1, domes, function(x: number, z: number): number
			return World.groundY(world, x, z)
		end)
		if gx then
			t.deflect = { gx, gy :: number, gz :: number }
			t.pulseAt = now + Effects.SHIELD_PULSE
			t.pulseMass = math.min(ShieldField.mass(weapon), 3)
		end
	end
end

local function pos(world: World.World, e: Schema.Event): (number, number, number)
	local x, z = world.grid:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
	return x, (e.y :: number) / Schema.Y_SCALE, z
end

-- SPAWN_STRATEGIC's goal (S-51).
local function goalPos(world: World.World, e: any): { number }
	local x, z = world.grid:decode(e.goalCell :: number, e.goalOffX :: number, e.goalOffZ :: number)
	return { x, (e.goalY :: number) / Schema.Y_SCALE, z }
end

-- One tick of a strategic missile toward `goal` (Shared/Combat/Lofted, S-51):
-- the server's Projectiles step, climb measured on Layers.heightAt.
local function loftedStep(world: World.World, weapon: any, goal: { number }, x: number, y: number, z: number, vx: number, vy: number, vz: number): (number, number, number, number, number, number)
	local layers = world.layers
	local climbLeft = if layers then Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z)) or 0 else 0
	return Lofted.step(x, y, z, vx, vy, vz, goal[1], goal[2], goal[3], goal[2] + weapon.apex, weapon.gravity, math.rad(weapon.turnRate or 0) * DT, climbLeft, DT)
end
Effects.loftedStep = loftedStep

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
local function burst(fx: Fx, now: number, x: number, y: number, z: number, radius: number, kind: string, life: number): Burst
	if #fx.bursts >= Effects.MAX_EXPLOSIONS then
		fx.skipped.bursts += 1
	end
	local b: Burst = { x = x, y = y, z = z, radius = radius, born = now, life = life, kind = kind, size = radius }
	capped(fx, fx.bursts, b, Effects.MAX_EXPLOSIONS)
	return b
end

-- Which countermeasure seduced a missile of `guidance` aimed at `unit`
-- (C-48). DECOYED says (`wire`: Schema.Countermeasure, protocol 13, S-38);
-- without it (an older record) it follows the server's order (EW): radar
-- missiles meet chaff; IR missiles meet DIRCM first, then flares.
local CM_NAME = { [Schema.Countermeasure.FLARES] = "flare", [Schema.Countermeasure.CHAFF] = "chaff", [Schema.Countermeasure.DIRCM] = "dircm" }
function Effects.countermeasure(world: World.World, unit: World.Unit?, guidance: string?, wire: number?): string
	if wire and CM_NAME[wire] then
		return CM_NAME[wire]
	end
	if guidance == "RADAR" then
		return "chaff"
	end
	local def = if unit then World.def(world, unit) else nil
	local cm = def and (def :: any).countermeasures
	if cm and cm.dircm and not cm.flares then
		return "dircm"
	end
	return "flare"
end

local function facing(b: Burst, dx: number, dy: number, dz: number)
	local l = math.sqrt(dx * dx + dy * dy + dz * dz)
	if l > 1e-6 then
		b.dx, b.dy, b.dz = dx / l, dy / l, dz / l
	end
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
Effects.HULL_RADIUS = PlacementRules.RADIUS_PER_FOOTPRINT -- collision radius per footprint cell (the fuse measures from the hull)

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

-- Is a known unit's hull under (x, z)? Within half its footprint (cells of
-- 8 studs) plus a margin.
function Effects.unitAt(world: World.World, x: number, z: number): boolean
	for _, u in world.units do
		local def = World.def(world, u)
		local reach = ((def and def.footprint or 1) * 4 + 3)
		local ux, uz = u.rx or u.x, u.rz or u.z
		if (ux - x) ^ 2 + (uz - z) ^ 2 <= reach * reach then
			return true
		end
	end
	return false
end

-- The server's aim from a target's state: (x, z), altitude, heading and
-- speed `tv` (studs/s). Returns the led point x, y, z and the unled centre
-- cx, cz (y is the same).
function Effects.aimFrom(world: World.World, target: World.Unit, x: number, z: number, alt: number, heading: number, tv: number, px: number, py: number, pz: number, speed: number): (number, number, number, number, number)
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
	return x + math.sin(heading) * tv * tgo, y, z + math.cos(heading) * tv * tgo, x, z
end

-- A target's state at render tick `t`: x, z, altitude, heading, and its
-- speed over the tick before.
local function targetAt(target: World.Unit, t: number): (number, number, number, number, number)
	local x, z, alt, heading = Interp.sample(target, t)
	local x0, z0 = Interp.sample(target, t - 1)
	return x, z, alt, heading, math.sqrt((x - x0) ^ 2 + (z - z0) ^ 2) / DT
end

-- One tick of the server's homing guidance into tick `t` (Projectiles,
-- S-27; Shared/Combat/Guidance): missiles fly proportional navigation
-- against the target's centre where it was when the tick's step starts,
-- torpedoes lead pursuit against where it is at the tick's end. `at(t)`
-- gives the target's x, z and altitude at the end of sim tick t; its
-- velocity is taken over the tick.
-- Vertical launches (`launch = "vertical"`, S-42) climb `climbHeight` straight
-- up (S-44), then pitch over (Guidance.vertical); `turned` is their state,
-- returned updated.
local function steer(world: World.World, target: World.Unit, weapon: any, at: (number) -> (number, number, number), t: number, x: number, y: number, z: number, vx: number, vy: number, vz: number, turned: boolean?): (number, number, number, boolean?)
	local ex, ez, alt = at(t)
	local sx, sz = at(t - 1)
	local _, ty = Effects.aimFrom(world, target, ex, ez, alt, 0, 0, x, y, z, 1)
	local tvx, tvz = (ex - sx) / DT, (ez - sz) / DT
	local maxTurn = math.rad(weapon.turnRate) * DT
	if weapon.type == "HOMING" and weapon.launch == "vertical" then
		-- the straight climb first (S-44, C-55): judged on the server's cell
		-- ground (Layers.heightAt), not the smoothed drawn terrain
		local layers = world.layers
		local climbLeft = if layers then Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z)) else nil
		return Guidance.vertical(x, y, z, vx, vy, vz, sx, ty, sz, tvx, 0, tvz, maxTurn, DT, turned == true, climbLeft)
	elseif weapon.type == "HOMING" then
		local nx, ny, nz = Guidance.pn(x, y, z, vx, vy, vz, sx, ty, sz, tvx, 0, tvz, maxTurn, DT)
		return nx, ny, nz, turned
	end
	local nx, ny, nz = Guidance.lead(x, y, z, vx, vy, vz, ex, ty, ez, tvx, tvz, maxTurn)
	return nx, ny, nz, turned
end

-- A decoyed missile's tick toward its decoy point (S-28): the new velocity
-- and whether its seeker still follows the point.
local function followDecoy(weapon: any, d: { number }, x: number, y: number, z: number, vx: number, vy: number, vz: number): (number, number, number, boolean)
	return Guidance.decoy(x, y, z, vx, vy, vz, d[1], d[2], d[3], math.rad(weapon.turnRate) * DT, Guidance.seekerAngle(weapon) or 60)
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

-- The gap to the ghost `frac` ticks into the current tick, scaled by what
-- is left of the blend. Through the tick the prediction moves with its
-- velocity after this tick's steering (nextState's dv), the ghost without
-- steering: the gap grows by their difference (as advanceBlend does at the
-- tick's end, so there's no step at the boundary).
local function gapAt(p: Proj, frac: number): (number, number, number)
	local left = offsetLeft(p, frac)
	if left <= 0 then
		return 0, 0, 0
	end
	local f = frac * DT
	local n = p.nextState
	local dvx, dvy, dvz = if n then n[7] else 0, if n then n[8] else 0, if n then n[9] else 0
	return (p.ox + ((p.ovx or 0) - dvx) * f) * left, (p.oy + ((p.ovy or 0) - dvy) * f) * left, (p.oz + ((p.ovz or 0) - dvz) * f) * left
end

-- Restarts the blend from where the projectile is drawn now (frac 0) to its
-- new state: the ghost keeps the drawn position and course.
local function reblend(p: Proj, x: number, y: number, z: number, vx: number, vy: number, vz: number)
	local left = offsetLeft(p, 0)
	local gx, gy, gz = gapAt(p, 0)
	local dx, dy, dz = p.x + gx, p.y + gy, p.z + gz
	-- the drawn velocity now: the prediction's, plus the ghost's share, plus
	-- how fast the closing gap itself moves the drawn point (d left / dt)
	local rate = 0
	if p.blend > 0 then
		local s = math.clamp(p.age / p.blend, 0, 1)
		rate = -6 * s * (1 - s) / (p.blend * DT)
	end
	local dvx = p.vx + (p.ovx or 0) * left + p.ox * rate
	local dvy = p.vy + (p.ovy or 0) * left + p.oy * rate
	local dvz = p.vz + (p.ovz or 0) * left + p.oz * rate
	p.x, p.y, p.z, p.vx, p.vy, p.vz = x, y, z, vx, vy, vz
	if (dx - x) ^ 2 + (dy - y) ^ 2 + (dz - z) ^ 2 > Effects.SNAP_STUDS ^ 2 then
		p.ox, p.oy, p.oz, p.blend, p.age = 0, 0, 0, 0, 0
		p.ovx, p.ovy, p.ovz = 0, 0, 0
		return dx, dy, dz
	end
	-- a blend under way keeps its progress (only the ghost is re-aimed), so
	-- frequent corrections still converge on schedule; restarting it each
	-- time left the drawn missile trailing an ever older course
	local l, r = 1, 0
	if p.blend > 0 and left > Effects.REBLEND_KEEP then
		l, r = left, rate
	else
		p.blend, p.age = Effects.BLEND_TICKS, 0
	end
	p.ox, p.oy, p.oz = (dx - x) / l, (dy - y) / l, (dz - z) / l
	p.ovx, p.ovy, p.ovz = (dvx - vx - p.ox * r) / l, (dvy - vy - p.oy * r) / l, (dvz - vz - p.oz * r) / l
	return dx, dy, dz
end

-- A projectile's state one sim tick on, into tick `t` (the server's
-- order: steer, then step), without changing it; how steering changed its
-- velocity; and, for a decoyed missile, whether it still follows the decoy.
-- On its spawn tick (launched early, C-27) it is the server's own state (a
-- homing missile already steered during it). Last: a vertical launch's
-- `turned` after this tick (C-53).
local function advance(world: World.World, p: Proj, t: number): (number, number, number, number, number, number, number, number, number, boolean, boolean?, number?)
	local launch = p.launch
	if launch and launch[1] == t then
		return launch[2], launch[3], launch[4], launch[5], launch[6], launch[7], 0, 0, 0, true, p.turned
	end
	local field = p.field
	if field then
		-- in a shield dome's field: the server's field step (S-79), unsteered
		local w = p.weapon
		local x, y, z, vx, vy, vz, phase = ShieldField.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, w.gravity or 0, field[1], field[2], field[3], field[4], field[5], ShieldField.mass(w), field[6], DT)
		return x, y, z, vx, vy, vz, 0, 0, 0, true, p.turned, phase
	end
	local weapon = p.weapon
	local vx, vy, vz = p.vx, p.vy, p.vz
	local target = World.unitOrDying(world, p.target)
	local follow = true
	local turned = p.turned
	local chase = p.chase
	if weapon.turnRate and chase and not chase.gone then
		-- an interceptor (S-48): navigate against its missile's own state at
		-- the step's start, vertical velocity included, as the server does
		local maxTurn = math.rad(weapon.turnRate) * DT
		if weapon.launch == "vertical" then
			local layers = world.layers
			local climbLeft = if layers then Guidance.climbLeft(weapon, p.y, Layers.heightAt(layers, p.x, p.z)) else nil
			vx, vy, vz, turned = Guidance.vertical(p.x, p.y, p.z, vx, vy, vz, chase.x, chase.y, chase.z, chase.vx, chase.vy, chase.vz, maxTurn, DT, turned == true, climbLeft)
		else
			vx, vy, vz = Guidance.pn(p.x, p.y, p.z, vx, vy, vz, chase.x, chase.y, chase.z, chase.vx, chase.vy, chase.vz, maxTurn, DT)
		end
	elseif weapon.turnRate and target then
		vx, vy, vz, turned = steer(world, target, weapon, function(tt: number): (number, number, number)
			local x, z, alt = Interp.sample(target, tt)
			return x, z, alt
		end, t, p.x, p.y, p.z, vx, vy, vz, p.turned)
	elseif weapon.turnRate and p.decoy then
		vx, vy, vz, follow = followDecoy(weapon, p.decoy, p.x, p.y, p.z, vx, vy, vz)
	elseif p.lost then
		-- lost its target: corkscrews and sinks, as the server steps it (S-146)
		vx, vy, vz = Guidance.lost(vx, vy, vz, p.lost, p.id, DT)
	end
	local goal = p.goal
	if goal and weapon.apex then
		-- a strategic missile: boost, pitch-over, lofted arc (S-51)
		local x, y, z, nvx, nvy, nvz = loftedStep(world, weapon, goal, p.x, p.y, p.z, p.vx, p.vy, p.vz)
		return x, y, z, nvx, nvy, nvz, 0, 0, 0, true, turned
	end
	local dvx, dvy, dvz = vx - p.vx, vy - p.vy, vz - p.vz
	local x, y, z, nvx, nvy, nvz = Ballistics.step(p.x, p.y, p.z, vx, vy, vz, weapon.gravity or 0, DT)
	if weapon.bolt then
		-- a D-Gun bolt rides the ground (S-194): the cell's height + BOLT_HEIGHT, as the server steps it
		y, nvy = World.simGroundY(world, x, z) + Effects.BOLT_HEIGHT, 0
	end
	return x, y, z, nvx, nvy, nvz, dvx, dvy, dvz, follow, turned
end

-- One sim tick of every projectile, into tick `t`. Every step is worked
-- out from the tick's start states first, then applied, so an interceptor
-- steers at its missile where it was at the tick's start (C-57).
local stepped: { [Proj]: { any } } = {}
local function stepProjectiles(fx: Fx, world: World.World, t: number)
	table.clear(stepped)
	for id, p in fx.projectiles do
		p.ttl -= 1
		if p.ttl <= 0 then
			fx.projectiles[id] = nil
			p.gone = true
			continue
		end
		stepped[p] = { advance(world, p, t) }
	end
	for _, p in fx.projectiles do
		local r = stepped[p]
		if r == nil then
			continue
		end
		local x, y, z, vx, vy, vz, dvx, dvy, dvz, follow, turned = r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11]
		p.x, p.y, p.z, p.vx, p.vy, p.vz = x, y, z, vx, vy, vz
		local field, phase = p.field, r[12]
		if field and phase then
			field[6] = phase
			if phase == ShieldField.DONE or phase == ShieldField.FREE then
				p.field = nil -- out of the field: it flies on plainly
			end
		end
		p.turned = turned
		p.launch = nil
		if p.lost then
			p.lost += 1
		end
		local d = p.decoy
		if d then
			d[4] -= 1
			if not follow or d[4] <= 0 then
				p.decoy = nil
			end
		end
		advanceBlend(p, dvx, dvy, dvz)
	end
end

local function mark(fx: Fx, kind: string, now: number, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number)
	if #fx.marks >= Effects.MAX_MARKS then
		table.remove(fx.marks, 1)
	end
	table.insert(fx.marks, { kind = kind, x0 = x0, y0 = y0, z0 = z0, x1 = x1, y1 = y1, z1 = z1, born = now })
end

local KIND_NAME = { [EK.SHIELD_FIELD] = "SHIELD_FIELD", [EK.SHIELD_HIT] = "SHIELD_HIT", [0] = "correction", [EK.FIRE] = "FIRE", [EK.SHOT] = "SHOT", [EK.SPAWN_PROJ] = "SPAWN_PROJ", [EK.IMPACT] = "IMPACT", [EK.DECOYED] = "DECOYED", [EK.LOST_LOCK] = "LOST_LOCK", [EK.INTERCEPTOR] = "INTERCEPTOR", [EK.LAUNCH_WARNING] = "LAUNCH_WARNING", [EK.INTERCEPTED] = "INTERCEPTED", [EK.SPAWN_STRATEGIC] = "SPAWN_STRATEGIC" }

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

-- Is one of the local team's launchers at (x, z)? The wire doesn't say
-- whose a projectile is, but a strategic missile leaves from its silo's
-- position (Weapons.fire) and own units are always known (C-58).
Effects.LAUNCHER_REACH = 24 -- studs
function Effects.ownLauncherAt(world: World.World, x: number, z: number): boolean
	local me = world.me
	if me == nil then
		return false
	end
	for _, u in world.units do
		if u.team == me.team and (u.x - x) ^ 2 + (u.z - z) ^ 2 <= Effects.LAUNCHER_REACH ^ 2 then
			local def = World.def(world, u)
			for _, ws in if def then def.weapons else {} do
				local w = world.defs.weaponByIndex[(ws :: any).weaponIndex]
				if w and (w :: any).strategic then
					return true
				end
			end
		end
	end
	return false
end

-- One warning per strategic launch (LAUNCH_WARNING and the missile's own
-- SPAWN_PROJ both raise it; ids are reused once a missile has ended).
local function warn(fx: Fx, p: Proj?, projId: number, x: number, y: number, z: number, now: number)
	for _, w in fx.warnings do
		if w.projId == projId and w.endedAt == nil then
			w.proj = w.proj or p
			return
		end
	end
	table.insert(fx.warnings, { projId = projId, x = x, y = y, z = z, born = now, proj = p })
end

-- `early`: applied one tick before its tick (C-27). SPAWN_PROJ carries the
-- state after the server's first step, so the shell is stepped back one
-- tick to where the server launched it.
local function apply(fx: Fx, world: World.World, e: any, now: number, muzzleOf: ((number, number) -> (number?, number?, number?))?, early: boolean?)
	local kind = e.kind
	local name = KIND_NAME[kind] or tostring(kind)
	fx.applied[name] = (fx.applied[name] or 0) + 1
	if kind == EK.SPAWN_PROJ or kind == EK.INTERCEPTOR or kind == EK.SPAWN_STRATEGIC then
		local weapon = world.defs.weaponByIndex[e.weaponIndex]
		if weapon == nil then
			return
		end
		local x, y, z = pos(world, e)
		local vx, vy, vz = vel(e)
		local launch = if early then { e.tick, x, y, z, vx, vy, vz } else nil
		local goal = if kind == EK.SPAWN_STRATEGIC then goalPos(world, e) else nil
		if early and goal then
			-- a strategic missile's first tick is its boost: straight up, no gravity (Lofted)
			x, y, z = x - vx * DT, y - vy * DT, z - vz * DT
		elseif early then
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
			World.noteShot(world, shooter, slot :: number, e.tick or fx.tick)
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
			-- an interceptor's target is a projectile, not a unit (S-48)
			target = if kind == EK.INTERCEPTOR then 0 else e.targetId or 0,
			chase = if kind == EK.INTERCEPTOR then fx.projectiles[e.targetId] else nil,
			ttl = if goal then 15 * 60 else ttlTicks(weapon), -- a strategic missile ends with its IMPACT
			size = weaponSize(weapon),
			launch = launch,
			goal = goal,
		}
		-- a missile leaves its launcher in a cloud (C-47); a gun just flashes;
		-- a D-Gun has its own (models-C's DgunMuzzle, C-266)
		local b = if weapon.type == "HOMING" or weapon.strategic
			then burst(fx, now, x + ox, y + oy, z + oz, weaponSize(weapon), "launch", Effects.LAUNCH_SECONDS)
			else burst(fx, now, x + ox, y + oy, z + oz, 0.8, if weapon.bolt then "dgunMuzzle" else "muzzle", 0.12)
		b.ground = World.groundY(world, x + ox, z + oz)
		facing(b, vx, vy, vz)
		-- a strategic missile warns even without its LAUNCH_WARNING, which
		-- comes only on its launch tick: a player who joins while it flies
		if weapon.strategic then
			local p = fx.projectiles[e.projId]
			p.own = Effects.ownLauncherAt(world, p.x, p.z)
			warn(fx, p, e.projId, x, y, z, now)
		end
	elseif kind == EK.IMPACT then
		-- (a D-Gun bolt's only IMPACT is its range's end: the units it burns
		-- through show as their DEATHs, S-194)
		local p = fx.projectiles[e.projId]
		fx.projectiles[e.projId] = nil
		if p then
			p.gone = true
		end
		local x, y, z = pos(world, e)
		local r = if p then Effects.impactSize(p.weapon) else 2
		-- a strategic missile's IMPACT is its detonation (S-48, C-57)
		local nuke = p ~= nil and p.weapon.strategic == true
		local bolt = p ~= nil and p.weapon.bolt ~= nil -- a D-Gun's end of range (C-266)
		local b = if nuke
			then burst(fx, now, x, y, z, (p :: Proj).weapon.aoe or 150, "nuke", Effects.NUKE_SECONDS)
			else burst(fx, now, x, y, z, r, if bolt then "dgunEnd" else "impact", Effects.EXPLOSION_SECONDS)
		if bolt then
			facing(b, (p :: Proj).vx, 0, (p :: Proj).vz) -- level: its ring lies flat
		end
		b.ground = World.groundY(world, x, z)
		-- a shell, bomb or torpedo ending at the water surface splashes (C-82),
		-- unless it hit a ship there (IMPACT doesn't say: a unit under the point)
		local floor, water = cellHeights(world, x, z)
		if not nuke and water > Effects.SPLASH_DEPTH and y <= floor + water + Effects.SPLASH_ABOVE and not Effects.unitAt(world, x, z) then
			b.water = floor + water
		end
		if p then
			facing(b, p.vx, p.vy, p.vz)
		end
	elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
		local p = fx.projectiles[e.projId]
		if p then
			-- like a correction: the server's new state, drawn from where the
			-- missile is and eased onto its new course (no jump, C-36)
			local x, y, z = pos(world, e)
			local vx, vy, vz = vel(e)
			local dx, dy, dz = reblend(p, x, y, z, vx, vy, vz)
			local target = World.unitOrDying(world, p.target)
			p.target = 0
			p.decoy = nil
			-- a radar missile spirals down from here (S-146); the event's state
			-- is after the server's first lost tick, so the next step is k = 1
			p.lost = if kind == EK.LOST_LOCK and p.weapon.type == "HOMING" and p.weapon.guidance == "RADAR" then Effects.LOST_FIRST else nil
			if kind == EK.DECOYED and (e.decoyTicks or 0) > 0 then
				-- it follows the flare or chaff like the server (S-28)
				local cx, cz = world.grid:decode(e.decoyCell, e.decoyOffX, e.decoyOffZ)
				p.decoy = { cx, e.decoyY / Schema.Y_SCALE, cz, e.decoyTicks }
				-- what seduced it (C-48): flares the aircraft drops toward the decoy
				-- point, a chaff cloud there, or the aircraft's jammer laser
				local cy = e.decoyY / Schema.Y_SCALE
				local ax, ay, az = cx, cy, cz
				if target and target.rx then
					ax, ay, az = target.rx, target.ry :: number, target.rz :: number
				end
				local cm = Effects.countermeasure(world, target, p.weapon.guidance, e.countermeasure)
				local b
				if cm == "dircm" then
					b = burst(fx, now, ax, ay, az, 1, "dircm", Effects.DIRCM_SECONDS)
					b.tx, b.ty, b.tz = dx, dy, dz
				elseif cm == "chaff" then
					b = burst(fx, now, cx, cy, cz, 1, "chaff", Effects.FLARE_SECONDS)
				else
					b = burst(fx, now, ax, ay, az, 1, "flare", Effects.FLARE_SECONDS)
					b.tx, b.ty, b.tz = cx, cy, cz
				end
				b.ground = World.groundY(world, b.x, b.z)
				facing(b, vx, vy, vz)
			end
			mark(fx, if kind == EK.DECOYED then "decoy" else "lost", now, dx, dy, dz, x, y, z)
			burst(fx, now, dx, dy, dz, 1.2, if kind == EK.DECOYED then "decoy" else "lost", 0.35)
		end
	elseif kind == EK.INTERCEPTED then
		-- destroyed in flight: a burst in the air, no detonation (S-48, C-57)
		local p = fx.projectiles[e.projId]
		fx.projectiles[e.projId] = nil
		if p then
			p.gone = true
		end
		local x, y, z = pos(world, e)
		-- a nuke's is big; a rocket or missile shot down by point defence
		-- (S-149) a small puff
		local size = if p == nil or p.weapon.strategic then 12 else Effects.INTERCEPT_PUFF
		local b = burst(fx, now, x, y, z, size, "impact", Effects.EXPLOSION_SECONDS)
		b.ground = World.groundY(world, x, z)
	elseif kind == EK.LAUNCH_WARNING then
		local x, y, z = pos(world, e)
		warn(fx, fx.projectiles[e.projId], e.projId, x, y, z, now)
	elseif kind == EK.FIRE then
		table.insert(fx.shots, { e.unitId, e.slot })
		World.noteShot(world, e.unitId, e.slot, e.tick or fx.tick) -- the reload bar (C-170)
		local x1, y1, z1 = pos(world, e)
		local shooter = world.units[e.unitId]
		local x0, y0, z0
		if muzzleOf then
			x0, y0, z0 = muzzleOf(e.unitId, e.slot)
		end
		local muzzled = x0 ~= nil -- (its model is drawn: the muzzle is live)
		if x0 == nil and shooter then
			x0, y0, z0 = shooter.rx or shooter.x, (shooter.ry or World.groundY(world, shooter.x, shooter.z)) + 2.5, shooter.rz or shooter.z
		end
		-- a FIRE carries only the end (sim-A): the start is where we draw the
		-- shooter. One not drawn (it just left the camera area, a strategic
		-- record's square), or drawn far from its last record, would stretch
		-- the streak from a stale spot (H37: near the edge of vision a beam
		-- ran to somewhere random). Then only the hit shows. A shot longer
		-- than its weapon could fire is stale too. Ends past the map edge are
		-- fine (aircraft, S-189).
		local sdef = shooter and World.def(world, shooter)
		local sslot = sdef and sdef.weapons[e.slot]
		local sweapon = sslot and world.defs.weaponByIndex[sslot.weaponIndex or 0]
		if x0 and Effects.staleStart(shooter, sweapon, x0, z0 :: number, x1, z1, muzzled) then
			fx.skipped.stale += 1
			if sweapon and sweapon.type == "BEAM" and e.hit then
				burst(fx, now, x1, y1, z1, 2.4, "impact", Effects.EXPLOSION_SECONDS)
			end
			x0 = nil
		end
		-- a hit ends on the hit unit's drawn body, where the line toward its
		-- middle meets the model's surface: the server aims at its sim
		-- height's middle, near the top of most models (the user: a tower's
		-- laser went to the tank's head; then: its burst sat inside the tank)
		local body = Effects.bodyAt
		if e.hit and body and x0 then
			local bx, by, bz = body(x0, y0 :: number, z0 :: number, x1, y1, z1)
			if bx then
				x1, y1, z1 = bx, by :: number, bz :: number
			end
		end
		if x0 then
			local def = shooter and World.def(world, shooter)
			local slot = def and def.weapons[e.slot]
			local weapon = slot and world.defs.weaponByIndex[slot.weaponIndex or 0]
			local isBeam = weapon ~= nil and weapon.type == "BEAM"
			if Effects.continueBeam(fx, weapon, x0, y0 :: number, z0 :: number, x1, y1, z1, e.hit == true, now, world) then
				return -- the burning beam goes on to the new end (a dome dropped, C-144)
			end
			local t = shotTracer(world, weapon, def and def.faction, x0, y0 :: number, z0 :: number, x1, y1, z1, e.hit == true, now)
			if weapon and weapon.ramp then
				-- the Beamer (S-157): its intensity grows over ramp.seconds of
				-- firing at one target, as the server's damage does; a pause
				-- longer than a shot's gap (a target change, a loss) starts over
				t.ramp = Effects.ramp(fx, e.unitId * 16 + e.slot, weapon, now)
				t.life = (weapon.reload or 0.2) + 0.08 -- the bolts join into one beam
			end
			if #fx.tracers >= Effects.MAX_TRACERS then
				fx.skipped.tracers += 1
			end
			capped(fx, fx.tracers, t, Effects.MAX_TRACERS)
			-- a beam: a big charge flash at the barrel and a heavy hit at the end (C-112)
			local b = burst(fx, now, x0, y0 :: number, z0 :: number, if isBeam then 2.2 else 0.7 * t.size, if isBeam then "launch" else "muzzle", if isBeam then 0.3 else 0.1)
			facing(b, x1 - x0, y1 - (y0 :: number), z1 - (z0 :: number))
			if isBeam and t.hit then
				burst(fx, now, x1, y1, z1, 2.4, "impact", Effects.EXPLOSION_SECONDS)
			end
		end
	elseif kind == EK.SHIELD_FIELD then
		-- the shell came into an enemy dome's field (protocol 24, S-79): step it
		-- through the field from now on, as the server does
		local p = fx.projectiles[e.projId]
		if p then
			local x, y, z = pos(world, e)
			p.field = { x, y, z, e.radius, e.force / 255, e.phase }
			-- it just crossed the surface (the field is inside the dome, S-83): the hit
			-- shows here and now, not at the turn deep inside (the user, C-95)
			local dx, dy, dz = p.x - x, p.y - y, p.z - z
			local d = math.sqrt(dx * dx + dy * dy + dz * dz)
			if e.phase == ShieldField.BRAKING and not e.lit and d > 1e-6 and #fx.shieldHits < 64 then
				local k = e.radius / d
				table.insert(fx.shieldHits, { unitId = 0, kind = "enter", x = x + dx * k, y = y + dy * k, z = z + dz * k, mass = ShieldField.mass(p.weapon), breach = false, projId = e.projId, tick = e.tick })
			end
		end
	elseif kind == EK.SHIELD_HIT then
		-- turned back (a missile loses its lock), broke through, or destroyed
		-- at the surface (protocol 25): no IMPACT follows, so an absorbed
		-- projectile bursts on the honeycomb with its own explosion (the
		-- user, C-185)
		local p = fx.projectiles[e.projId]
		local x, y, z = pos(world, e)
		if p and e.absorbed then
			fx.projectiles[e.projId] = nil
			p.gone = true
			local b = burst(fx, now, x, y, z, Effects.impactSize(p.weapon), "impact", Effects.EXPLOSION_SECONDS)
			b.ground = World.groundY(world, x, z)
			facing(b, p.vx, p.vy, p.vz)
		elseif p and not e.breach then
			p.target = 0
		end
		if #fx.shieldHits < 64 then
			table.insert(fx.shieldHits, { unitId = e.unitId or 0, kind = if e.breach then "breach" elseif e.absorbed then "absorb" else "turn", x = x, y = y, z = z, mass = e.mass / Schema.SHIELD_MASS_SCALE, breach = e.breach == true, projId = e.projId, tick = e.tick })
		end
	elseif kind == EK.SHOT then
		-- a hidden shooter's hitscan shot (protocol 14, S-43, C-54): a tracer
		-- between the two ends the server sends, with no shooter and no muzzle
		-- flash, so it shows the shot without lighting up where it came from
		local x1, y1, z1 = pos(world, e)
		local x0, z0 = world.grid:decode(e.fromCell, e.fromOffX, e.fromOffZ)
		local y0 = e.fromY / Schema.Y_SCALE
		-- the weapon (protocol 28, S-118): a hidden beam tower's shot draws as its
		-- full beam, as BAR shows a Pulsar's (the user, C-143); the faction from
		-- the weapon's id
		local weapon = if e.weaponIndex and e.weaponIndex > 0 then world.defs.weaponByIndex[e.weaponIndex] else nil
		local faction = if weapon and string.sub(weapon.id, 1, 4) == "chs_" then "chaos" else "order"
		if Effects.continueBeam(fx, weapon, x0, y0, z0, x1, y1, z1, e.hit == true, now, world) then
			return
		end
		local t = shotTracer(world, weapon, faction, x0, y0, z0, x1, y1, z1, e.hit == true, now)
		if t.beam and t.hit then
			burst(fx, now, x1, y1, z1, 2.4, "impact", Effects.EXPLOSION_SECONDS)
		end
		if #fx.tracers >= Effects.MAX_TRACERS then
			fx.skipped.tracers += 1
		end
		capped(fx, fx.tracers, t, Effects.MAX_TRACERS)
	elseif kind == 0 then
		-- homing correction (Projectiles channel): snap the prediction, keep
		-- drawing where it was, blend the gap away
		local p = fx.projectiles[e.projId]
		if p then
			local x, z = world.grid:decode(e.cell, e.offX, e.offZ)
			local y = e.y / Schema.Y_SCALE
			local vx, vy, vz = vel(e)
			local dx, dy, dz = reblend(p, x, y, z, vx, vy, vz)
			-- a correction doesn't carry a vertical launch's `turned`: with the
			-- target already near the nose, the server has handed over (C-53)
			local target = World.unitOrDying(world, p.target)
			if p.weapon.launch == "vertical" and not p.turned and target then
				local tx, tz, alt = Interp.sample(target, fx.tick)
				local _, ty = Effects.aimFrom(world, target, tx, tz, alt, 0, 0, x, y, z, 1)
				p.turned = Guidance.inCone(x, y, z, vx, vy, vz, tx, ty, tz, math.rad(Guidance.HANDOVER))
			end
			mark(fx, "correction", now, dx, dy, dz, x, y, z)
		end
	end
end

-- The fraction (0..1) of the move from s to e, both relative to a sphere's
-- centre, where it first comes inside `radius`: 0 when it starts inside, 1
-- when it doesn't get in.
local function crossing(sx: number, sy: number, sz: number, ex: number, ey: number, ez: number, radius: number): number
	local r2 = radius * radius
	local c = sx * sx + sy * sy + sz * sz - r2
	if c <= 0 then
		return 0
	end
	local dx, dy, dz = ex - sx, ey - sy, ez - sz
	local a = dx * dx + dy * dy + dz * dz
	local b = 2 * (sx * dx + sy * dy + sz * dz)
	local disc = b * b - 4 * a * c
	if a < 1e-12 or disc < 0 then
		return 1
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	return if t >= 0 and t <= 1 then t else 1
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
		if (e.kind == EK.SPAWN_PROJ or e.kind == EK.INTERCEPTOR or e.kind == EK.SPAWN_STRATEGIC) and e.tick == fx.tick + 1 and not e.launched then
			e.launched = true
			apply(fx, world, e, now, muzzleOf, true)
		end
	end
	-- a shell that hits during the coming tick bursts when its drawn path
	-- reaches the impact point, not at the tick's end: drawn on, it would fly
	-- up to a tick's travel past the target first (C-26). Events arrive
	-- ahead of the render clock (Interp's delay), so the IMPACT is known. A
	-- light shell a dome destroys (SHIELD_HIT absorbed, S-85) goes the same way:
	-- gone where its drawn path reaches the surface (C-99)
	local frac = renderTick - fx.tick
	for i = #events, 1, -1 do
		local e = events[i] :: any
		local ends = e.kind == EK.IMPACT or (e.kind == EK.SHIELD_HIT and e.absorbed == true)
		if not ends or e.tick ~= fx.tick + 1 then
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
		local nx, ny, nz = advance(world, p, fx.tick + 1)
		local dx, dy, dz = nx + g1x - sx, ny + g1y - sy, nz + g1z - sz
		local len2 = dx * dx + dy * dy + dz * dz
		local along = if len2 > 1e-9 then ((x - sx) * dx + (y - sy) * dy + (z - sz) * dz) / len2 else 1
		if frac >= math.clamp(along, 0, 1) then
			table.remove(events, i)
			apply(fx, world, e, now, muzzleOf)
		end
	end
	-- a shell that comes into a dome's field during the coming tick is
	-- stepped through the field from the tick's start, as the server does
	-- (the field takes hold where it crosses the surface), and its hit shows
	-- when its drawn path crosses, not a tick later when the event is due
	-- (C-99: drawn on plainly, it flew a tick into the dome unbraked first)
	for i = 1, #events do
		local e = events[i] :: any
		if e.kind == EK.SHIELD_FIELD and e.tick == fx.tick + 1 and e.phase == ShieldField.BRAKING and not e.lit then
			local p = fx.projectiles[e.projId]
			if p then
				local cx, cy, cz = pos(world, e)
				if p.field == nil then
					p.field = { cx, cy, cz, e.radius, e.force / 255, ShieldField.FREE }
				end
				local g0x, g0y, g0z = gapAt(p, 0)
				local g1x, g1y, g1z = gapAt(p, 1)
				local sx, sy, sz = p.x + g0x - cx, p.y + g0y - cy, p.z + g0z - cz
				local nx, ny, nz = advance(world, p, fx.tick + 1)
				local ex, ey, ez = nx + g1x - cx, ny + g1y - cy, nz + g1z - cz
				local along = crossing(sx, sy, sz, ex, ey, ez, e.radius)
				if frac >= along then
					e.lit = true
					local hx, hy, hz = sx + (ex - sx) * along, sy + (ey - sy) * along, sz + (ez - sz) * along
					local d = math.sqrt(hx * hx + hy * hy + hz * hz)
					if d > 1e-6 and #fx.shieldHits < 64 then
						local k = e.radius / d
						table.insert(fx.shieldHits, { unitId = 0, kind = "enter", x = cx + hx * k, y = cy + hy * k, z = cz + hz * k, mass = ShieldField.mass(p.weapon), breach = false, projId = e.projId, tick = e.tick })
					end
				end
			end
		end
	end
	-- each projectile's state one tick on: frames draw the curve between (C-38)
	for _, p in fx.projectiles do
		local x, y, z, vx, vy, vz, dvx, dvy, dvz = advance(world, p, fx.tick + 1)
		local n = p.nextState
		if n == nil then
			n = table.create(9, 0)
			p.nextState = n
		end
		n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8], n[9] = x, y, z, vx, vy, vz, dvx, dvy, dvz
	end
	for i = #fx.pendingDeaths, 1, -1 do
		local d = fx.pendingDeaths[i]
		if d.tick <= renderTick then
			table.remove(fx.pendingDeaths, i)
			local def = if d.defIndex then world.defs.unitByIndex[d.defIndex] else nil
			local r = (if def then def.footprint else 1) * 3 * (1 + d.severity / 255)
			-- an aircraft falls first and explodes where it hits (C-48)
			local crash = Deaths.crash(d, def, function(x: number, z: number): number
				return World.groundY(world, x, z)
			end)
			if crash then
				-- on the render clock, as Render/Deaths plays the fall
				table.insert(fx.crashes, { at = renderTick + crash.duration * 15, x = crash.ex, y = crash.ey, z = crash.ez, radius = r * 1.3 })
			else
				local ground = World.groundY(world, d.x, d.z)
				local b = burst(fx, now, d.x, ground + 1.5, d.z, r, "death", Effects.DEATH_SECONDS)
				b.ground = ground
				local bolt = Effects.boltThrough(fx, d.x, d.z, def)
				if bolt then
					-- burned by a D-Gun bolt passing: its hit there too (the server
					-- sends no IMPACT for a pass-through, S-194; C-266)
					local h = burst(fx, now, d.x, ground + Effects.BOLT_HEIGHT, d.z, 1, "dgunHit", Effects.EXPLOSION_SECONDS)
					h.ground = ground
					facing(h, bolt.vx, 0, bolt.vz)
				end
				local blast = def and (def :: any).deathBlast
				if blast then
					-- every unit explodes when killed (S-70, S-178, F15), its blast's
					-- size from its def: a huge one (a Commander, a fusion reactor) as
					-- the nuke's look scaled to its radius, smaller than a nuke's;
					-- others a burst of part of the blast's reach
					local huge = blast.aoe >= Effects.HUGE_BLAST
					local radius = if huge then blast.aoe else blast.aoe * Effects.BLAST_SHOWN
					local big = burst(fx, now, d.x, ground + 2, d.z, radius, if huge then "nuke" else "impact", if huge then Effects.DEATH_SECONDS * 2 else Effects.EXPLOSION_SECONDS)
					big.ground = ground
					big.noCrater = huge or nil -- a nuke's look without its crater
				end
			end
		end
	end
	for i = #fx.crashes, 1, -1 do
		local c = fx.crashes[i]
		if renderTick >= c.at then
			table.remove(fx.crashes, i)
			local b = burst(fx, now, c.x, c.y + 1.5, c.z, c.radius, "death", Effects.DEATH_SECONDS)
			b.ground = c.y
		end
	end
	-- beams held on a shield dome: a fresh hit at the contact every
	-- SHIELD_PULSE while they burn (the server's SHIELD_HIT lit the first)
	for _, t in fx.tracers do
		local at = t.pulseAt
		if at and now < t.born + t.life and now >= at and #fx.shieldHits < 64 then
			t.pulseAt = at + Effects.SHIELD_PULSE
			table.insert(fx.shieldHits, { unitId = 0, kind = "absorb", x = t.x1, y = t.y1, z = t.z1, mass = t.pulseMass or 1, breach = false, projId = 0, tick = fx.tick })
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
	for i = #fx.warnings, 1, -1 do
		local wv = fx.warnings[i]
		wv.proj = wv.proj or fx.projectiles[wv.projId]
		local p = wv.proj
		if wv.endedAt == nil and ((p == nil and now - wv.born > 1) or (p ~= nil and p.gone)) then
			wv.endedAt = now
		end
		if wv.endedAt and now - (wv.endedAt :: number) > Effects.WARNING_LINGER then
			table.remove(fx.warnings, i)
		end
	end
	for i = #fx.marks, 1, -1 do
		if now - fx.marks[i].born >= Effects.MARK_SECONDS then
			table.remove(fx.marks, i)
		end
	end
end

-- Projectiles to draw at render tick `renderTick`: at most MAX_PROJECTILES,
-- the most important first. Each entry: { proj, x, y, z }.
function Effects.visible(fx: Fx, renderTick: number): { { any } }
	local s = math.clamp(renderTick - fx.tick, 0, 1)
	local frac = s * DT
	-- cubic Hermite weights: a curve through this tick's and the next tick's
	-- states with their velocities, so a turning missile bends through the
	-- tick instead of flying straight and turning at its end (C-38)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, (s3 - 2 * s2 + s) * DT, -2 * s3 + 3 * s2, (s3 - s2) * DT
	local list = {}
	for _, p in fx.projectiles do
		local x, y, z
		local n = p.nextState
		if n then
			x = h00 * p.x + h10 * p.vx + h01 * n[1] + h11 * n[4]
			y = h00 * p.y + h10 * p.vy + h01 * n[2] + h11 * n[5]
			z = h00 * p.z + h10 * p.vz + h01 * n[3] + h11 * n[6]
		else
			x, y, z = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, p.weapon.gravity or 0, frac)
		end
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

-- Where homing projectile `p` aims at render tick `t` from (px, py, pz)
-- (default: its prediction): the led point lx, ly, lz and the target's
-- centre cx, cy, cz; nil without a target (C-39).
function Effects.aim(world: World.World, p: Proj, t: number, px: number?, py: number?, pz: number?): (number?, number?, number?, number?, number?, number?)
	local target = World.unitOrDying(world, p.target)
	if target == nil then
		return nil, nil, nil, nil, nil, nil
	end
	local tx, tz, alt, heading, tv = targetAt(target, t)
	local speed = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz)
	local lx, ly, lz, cx, cz = Effects.aimFrom(world, target, tx, tz, alt, heading, tv, px or p.x, py or p.y, pz or p.z, speed)
	return lx, ly, lz, cx, ly, cz
end

export type Prediction = {
	path: { number }, -- x, y, z after each predicted tick
	miss: number?, -- closest approach to the target's hull (studs); nil without a target
	centre: number?, -- the same to its centre
	at: number?, -- sim ticks from fx.tick to that closest approach
	cx: number?, -- the missile there
	cy: number?,
	cz: number?,
	hit: boolean, -- the proximity fuse would fire (miss <= aoe)
	ground: boolean, -- it flies into the ground first
}

-- Where projectile `p` flies over the next `ticks` sim ticks from its
-- prediction at fx.tick: the server's steering and step on a copy, the
-- target known up to its last snapshot and extrapolated from it holding its
-- speed and its turn rate over its last two snapshots (a circling jet keeps
-- circling: proportional navigation reacts to the target's turn). Stops at the fuse (as the server's) or the
-- ground. The closest approach is taken along each tick's chord relative to
-- the moving target, as the server's fuse does (C-39).
function Effects.predict(fx: Fx, world: World.World, p: Proj, ticks: number): Prediction
	local weapon = p.weapon
	local target = World.unitOrDying(world, p.target)
	local out: Prediction = { path = table.create(ticks * 3), hit = false, ground = false }
	local x, y, z, vx, vy, vz = p.x, p.y, p.z, p.vx, p.vy, p.vz
	local lastTick, lx, lz, lalt, lheading, ltv, lturn = math.huge, 0, 0, 0, 0, 0, 0
	local radius, height = 0, 0
	if target then
		local snaps = target.snaps
		if #snaps > 0 then
			lastTick = snaps[#snaps].tick
			lx, lz, lalt, lheading, ltv = targetAt(target, lastTick)
			if #snaps >= 2 then
				local a, b = snaps[#snaps - 1], snaps[#snaps]
				lturn = ((b.heading - a.heading + math.pi) % (2 * math.pi) - math.pi) / math.max(b.tick - a.tick, 1)
			end
		end
		local def = World.def(world, target)
		local fp = if def then def.footprint else 1
		radius, height = fp * Effects.HULL_RADIUS, Effects.UNIT_HEIGHT * fp
	end
	-- the target at tick t: as drawn up to its last snapshot, then on along
	-- its turn (whole ticks stepped like the sim's movement, then the rest)
	local ext = { lx, lz, lheading } -- x, z, heading after k whole ticks past lastTick, flattened
	local function targetState(t: number): (number, number, number, number, number)
		if t <= lastTick then
			return targetAt(target :: World.Unit, t)
		end
		local k = math.floor(t - lastTick)
		while #ext < (k + 1) * 3 do
			local i = #ext
			local h = ext[i] + lturn
			ext[i + 1], ext[i + 2], ext[i + 3] = ext[i - 2] + math.sin(h) * ltv * DT, ext[i - 1] + math.cos(h) * ltv * DT, h
		end
		local x, z, h = ext[k * 3 + 1], ext[k * 3 + 2], ext[k * 3 + 3]
		local f = (t - lastTick - k) * ltv * DT
		return x + math.sin(h + lturn) * f, z + math.cos(h + lturn) * f, lalt, h, ltv
	end
	-- the target's centre at the start of the current tick
	local pcx, pcy, pcz = 0, 0, 0
	if target then
		local tx, tz, alt, heading, tv = targetState(fx.tick)
		local _, ty, _, cx, cz = Effects.aimFrom(world, target, tx, tz, alt, heading, tv, x, y, z, 1)
		pcx, pcy, pcz = cx, ty, cz
	end
	local function at(t: number): (number, number, number)
		local tx, tz, alt = targetState(t)
		return tx, tz, alt
	end
	local decoy = if p.decoy then table.clone(p.decoy) else nil
	local turned = p.turned
	local best = math.huge
	local path = out.path
	for k = 1, ticks do
		local t = fx.tick + k
		local launch = p.launch
		local nx, ny, nz, nvx, nvy, nvz
		local ccx, ccy, ccz = 0, 0, 0
		local svx, svy, svz = vx, vy, vz
		if target then
			local tx, tz, alt, heading, tv = targetState(t)
			local _, ay, _, cx, cz = Effects.aimFrom(world, target, tx, tz, alt, heading, tv, x, y, z, 1)
			ccx, ccy, ccz = cx, ay, cz
			if weapon.turnRate then
				svx, svy, svz, turned = steer(world, target, weapon, at, t, x, y, z, vx, vy, vz, turned)
			end
		elseif decoy and weapon.turnRate then
			local follow
			svx, svy, svz, follow = followDecoy(weapon, decoy, x, y, z, vx, vy, vz)
			decoy[4] -= 1
			if not follow or decoy[4] <= 0 then
				decoy = nil
			end
		end
		if launch and launch[1] == t then
			nx, ny, nz, nvx, nvy, nvz = launch[2], launch[3], launch[4], launch[5], launch[6], launch[7]
		else
			nx, ny, nz, nvx, nvy, nvz = Ballistics.step(x, y, z, svx, svy, svz, weapon.gravity or 0, DT)
		end
		if target then
			-- closest approach along the chord, relative to the moving centre
			local ax, ay, az = x - pcx, y - pcy, z - pcz
			local dx, dy, dz = (nx - ccx) - ax, (ny - ccy) - ay, (nz - ccz) - az
			local len2 = dx * dx + dy * dy + dz * dz
			local s = if len2 > 1e-9 then math.clamp(-(ax * dx + ay * dy + az * dz) / len2, 0, 1) else 0
			local rx, ry, rz = ax + dx * s, ay + dy * s, az + dz * s
			local hull = Ballistics.distanceToCylinder(rx, ry, rz, 0, 0, radius, -height / 2, height / 2)
			if hull < best then
				best = hull
				out.miss, out.centre, out.at = hull, math.sqrt(rx * rx + ry * ry + rz * rz), k - 1 + s
				out.cx, out.cy, out.cz = x + (nx - x) * s, y + (ny - y) * s, z + (nz - z) * s
			end
			pcx, pcy, pcz = ccx, ccy, ccz
		end
		path[#path + 1], path[#path + 2], path[#path + 3] = nx, ny, nz
		x, y, z, vx, vy, vz = nx, ny, nz, nvx, nvy, nvz
		if target and weapon.type == "HOMING" and best <= (weapon.aoe or 0) then
			out.hit = true
			break
		end
		if y < cellHeights(world, x, z) then
			out.ground = true
			break
		end
	end
	return out
end

-- Where a ballistic projectile comes down (C-57): its state stepped with
-- gravity (a strategic missile: Lofted toward its goal, S-51) until it
-- reaches the ground (the server's Layers.heightAt), at most `maxSeconds`.
-- Returns x, z and the sim seconds to get there, or nil.
function Effects.landing(world: World.World, p: Proj, maxSeconds: number?): (number?, number?, number?)
	local layers = world.layers
	local g = p.weapon.gravity or 0
	local x, y, z, vx, vy, vz = p.x, p.y, p.z, p.vx, p.vy, p.vz
	for k = 1, math.floor((maxSeconds or 60) * 15) do
		local px, py, pz = x, y, z
		local goal = p.goal
		if goal and p.weapon.apex then
			x, y, z, vx, vy, vz = loftedStep(world, p.weapon, goal, x, y, z, vx, vy, vz)
		else
			x, y, z, vx, vy, vz = Ballistics.step(x, y, z, vx, vy, vz, g, DT)
		end
		local ground = if layers then Layers.heightAt(layers, x, z) else 0
		if vy < 0 and y <= ground then
			-- where the tick's chord meets the ground
			local f = if py > y then math.clamp((py - ground) / (py - y), 0, 1) else 1
			return px + (x - px) * f, pz + (z - pz) * f, (k - 1 + f) * DT
		end
	end
	return nil, nil, nil
end

-- Forgets everything (a new WELCOME).
function Effects.clear(fx: Fx)
	table.clear(fx.projectiles)
	table.clear(fx.bursts)
	table.clear(fx.tracers)
	table.clear(fx.pendingDeaths)
	table.clear(fx.crashes)
	table.clear(fx.warnings)
	table.clear(fx.shots)
	table.clear(fx.marks)
	fx.tick = -1
end

return Effects
