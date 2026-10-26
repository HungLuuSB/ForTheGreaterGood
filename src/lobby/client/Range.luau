--!strict
-- The Units showroom's moving parts (L-22, the user): each shown unit plays
-- its own piece animations, and a firing range shows how its weapons work.
--
-- Animation: the match's piece scheduler (client-B's Core/PieceAnim) with
-- the unit's own piece script (Core/PieceScripts) and the animated pieces
-- every unit has (Ambient: radars sweep, rotors and drills turn, gantries
-- run) as if powered and producing; aircraft are flying, deployable units
-- deployed. The joints move through their Motor6D.Transform, as in a match.
--
-- Firing range: a dummy target for each kind of target the unit's weapons
-- take (a target board on the ground or a barge on water, a drone circling
-- for anti-air, a hulk under the water for anti-submarine weapons), closer
-- than the weapon's real range so the shot fits on screen. Each weapon aims
-- (the piece script turns its turret and barrel) and fires at its reload
-- (at most RELOAD_MAX seconds), salvos included, and its shots fly like the
-- match's: the effect records of Core/Effects (shells, missiles, tracers,
-- beams, lasers, bursts) drawn by the match's own Render/Effects. Shells
-- follow the weapon's speed and gravity (Shared/Combat/Ballistics), missiles
-- steer at the weapon's turn rate, bombs fall, torpedoes run under the
-- surface. Anti-missile and strategic weapons aren't shown.

local Ballistics = require("@shared/Combat/Ballistics")
local Codex = require("../shared/Codex")
local Effects = require("@client/Core/Effects")
local PieceAnim = require("@client/Core/PieceAnim")
local PieceScripts = require("@client/Core/PieceScripts/Registry")
local Ambient = require("@client/Core/PieceScripts/Ambient")
local RenderEffects = require("@client/Render/Effects")

local Range = {}

local DT = 1 / 15 -- the sim's tick: shells step as on the server
Range.RELOAD_MAX = 4 -- seconds between shots at most (a long reload waits less)
Range.RELOAD_MIN = 0.12
Range.FIRST_SHOT = 1.2 -- seconds before the first shot (the turret turns first)
Range.AIM_EVERY = 0.2 -- seconds between aim updates
Range.TARGET_SIZE = Vector3.new(7, 5, 7)

export type Target = {
	kind: string, -- "ground" | "air" | "sub"
	model: Model,
	center: Vector3, -- ground and sub targets stand here; the drone circles round it
	radius: number, -- the drone's circle
	height: number, -- the drone's height above `center`
	phase: number,
	pos: Vector3, -- now
	flashUntil: number,
}

type Slot = {
	slot: number,
	weapon: any,
	target: Target,
	nextAt: number,
	queue: { number }, -- salvo shots still to fire (their times)
	lastAim: number,
	shots: number,
}

type Unit = {
	id: number,
	model: Model,
	def: any,
	faction: string,
	motors: { [string]: Motor6D },
	anim: any,
	slots: { Slot },
}

local defs: any = nil
local sched: any = nil
local fx: any = nil
local renderer: any = nil
local folder: Instance? = nil
local targetsFolder: Folder? = nil
local units: { [number]: Unit } = {}
local targets: { Target } = {}
local firing = false
local clock = 0 -- seconds since the range started
local tickAcc = 0
local nextProj = 0
local groundAt: (Vector3) -> number = function(_p)
	return 0
end

-- Shells on the move: our own state; Effects' projectile records are drawn.
type Shot = { proj: any, target: Target, steer: number?, aimY: number?, groundY: number, floor: number? }
local shots: { [number]: Shot } = {}

function Range.init(allDefs: any, parent: Instance)
	defs = allDefs
	folder = parent
	sched = PieceAnim.new(allDefs.weaponByIndex)
	fx = Effects.new()
	local f = Instance.new("Folder")
	f.Name = "Targets"
	f.Parent = parent
	targetsFolder = f
end

-- The level of the floor under a point, for bursts and shells that fall
-- short (the showroom's place).
function Range.setGround(fn: (Vector3) -> number)
	groundAt = fn
end

-- animation ------------------------------------------------------------------

-- A shown unit starts animating: its piece script and its ambient pieces.
function Range.attach(id: number, model: Model, def: any)
	if sched == nil then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local u = PieceAnim.add(sched, id, def, PieceScripts.forDef(def)) :: any
	units[id] = { id = id, model = model, def = def, faction = def.faction or "order", motors = motors, anim = u, slots = {} }
	if def.domain == "air" then
		PieceAnim.call(u, "TakeOff")
	end
	if def.deploy then
		PieceAnim.call(u, "Deploy", "deployed", true)
	end
	if def.retract then
		PieceAnim.call(u, "Retract", false, true)
	end
	if #u.motions > 0 then
		-- as in a match: powered, producing, not moving, flying
		u:StartThread(Ambient.apply, u.motions, { moving = false, power = 1, producing = true, landed = false })
	end
end

function Range.detach(id: number)
	local u = units[id]
	if u then
		for _, m in u.motors do
			m.Transform = CFrame.identity
		end
		units[id] = nil
	end
	if sched then
		PieceAnim.remove(sched, id)
	end
end

-- targets ---------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- A target board on legs (ground), a barge (on water), a drone (air) or a
-- hulk (under water). Built at the origin, moved by its pivot.
local function targetModel(kind: string, onWater: boolean): Model
	local m = Instance.new("Model")
	m.Name = `Target_{kind}`
	local steel = Color3.fromRGB(70, 74, 80)
	if kind == "air" then
		local body = part(m, { Name = "Body", Size = Vector3.new(1.6, 1.2, 5), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Wing", Size = Vector3.new(8, 0.2, 1.6), CFrame = CFrame.new(0, 0.2, 0.2), Material = Enum.Material.Metal, Color = Color3.fromRGB(196, 60, 52) })
		part(m, { Name = "Tail", Size = Vector3.new(3, 0.2, 0.9), CFrame = CFrame.new(0, 0.3, 2.2), Material = Enum.Material.Metal, Color = Color3.fromRGB(196, 60, 52) })
		m.PrimaryPart = body
	elseif kind == "sub" then
		local hull = part(m, { Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 3.4, 3.4), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 3.6, 3.6), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(214, 172, 54) })
		m.PrimaryPart = hull
	elseif onWater then
		local barge = part(m, { Name = "Barge", Size = Vector3.new(8, 1.6, 12), CFrame = CFrame.new(0, 0.3, 0), Material = Enum.Material.Metal, Color = steel })
		part(m, { Name = "Board", Size = Vector3.new(6, 4, 0.4), CFrame = CFrame.new(0, 3.1, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 230, 224) })
		part(m, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 3, 3), CFrame = CFrame.new(0, 3.1, 0) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(196, 60, 52) })
		m.PrimaryPart = barge
	else
		local base = part(m, { Name = "Base", Size = Vector3.new(7, 0.6, 3), CFrame = CFrame.new(0, 0.3, 0), Material = Enum.Material.Metal, Color = steel })
		for _, x in { -2.6, 2.6 } do
			part(m, { Name = "Leg", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(x, 2.4, 0), Material = Enum.Material.Metal, Color = steel })
		end
		part(m, { Name = "Board", Size = Vector3.new(6.4, 4.4, 0.4), CFrame = CFrame.new(0, 4, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 230, 224) })
		for i, r in { 4, 2.6, 1.2 } do
			part(m, {
				Name = "Ring",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.42 + i * 0.02, r, r),
				CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0),
				Material = Enum.Material.SmoothPlastic,
				Color = if i % 2 == 1 then Color3.fromRGB(196, 60, 52) else Color3.fromRGB(230, 230, 224),
			})
		end
		m.PrimaryPart = base
	end
	return m
end

Range.targetKind = Codex.rangeTarget

local function clearTargets()
	for _, t in targets do
		t.model:Destroy()
	end
	table.clear(targets)
	for _, u in units do
		table.clear(u.slots)
	end
end

local function clearShots()
	table.clear(shots)
	if fx then
		Effects.clear(fx)
	end
end

export type Place = {
	floor: number, -- the ground level units stand on (world Y)
	water: number?, -- the water surface, when the place has water (world Y)
	seabed: number?, -- under the water
	sky: boolean, -- aircraft hover; the ground is far below
	underwater: boolean, -- the camera's under the surface; targets stand on the seabed
}

-- How far the targets stand (closer than real ranges, so the shot shows).
local function distanceFor(range: number, lo: number, hi: number): number
	return math.clamp(range * 0.15, lo, hi)
end

-- Sets the range up for the shown units: one target of each kind their
-- weapons take, in front of the first unit (`base`: its pivot), and each
-- weapon slot aimed at its kind. Returns the targets' points (for the
-- camera). `on` false clears it.
function Range.setFiring(on: boolean, base: CFrame?, place: Place?): { Vector3 }
	firing = on
	clearTargets()
	clearShots()
	local points = {}
	if not on or base == nil or place == nil or targetsFolder == nil then
		return points
	end
	local water = place.water ~= nil
	-- the ranges of the weapons per kind
	local need: { [string]: number } = {}
	for _, u in units do
		for slot, w in u.def.weapons or {} do
			local weapon = defs.weaponByIndex[w.weaponIndex]
			local kind = Range.targetKind(weapon, water)
			if kind then
				need[kind] = math.max(need[kind] or 0, weapon.range or 100)
			end
		end
	end
	local forward = -base.LookVector -- a unit model faces its +Z (its barrels point that way at rest)
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(0, 0, -1)
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local origin = Vector3.new(base.X, 0, base.Z)
	local byKind: { [string]: Target } = {}
	for kind, range in need do
		local t: Target
		if kind == "air" then
			local d = distanceFor(range, 24, 40)
			local center = origin + Vector3.new(0, if place.sky then base.Y else place.floor, 0)
			t = { kind = kind, model = targetModel("air", false), center = center, radius = d, height = if place.sky then 10 else 20, phase = 0, pos = center, flashUntil = 0 }
		elseif kind == "sub" then
			local d = distanceFor(range, 24, 40)
			local y = ((place.water or 0) + (place.seabed or ((place.water or 0) - 30))) / 2
			local p = origin + forward * d + right * d * 0.35
			t = { kind = kind, model = targetModel("sub", true), center = Vector3.new(p.X, y, p.Z), radius = 0, height = 0, phase = 0, pos = Vector3.new(p.X, y, p.Z), flashUntil = 0 }
		else
			local d = distanceFor(range, 22, 40)
			local p = origin + forward * d + right * d * 0.35
			local onWater = water and not place.underwater
			local y = if place.sky then groundAt(p) elseif onWater then (place.water :: number) else place.floor
			t = { kind = kind, model = targetModel("ground", onWater), center = Vector3.new(p.X, y, p.Z), radius = 0, height = 0, phase = 0, pos = Vector3.new(p.X, y, p.Z), flashUntil = 0 }
		end
		-- the board faces the unit
		local look = CFrame.lookAt(t.center, Vector3.new(origin.X, t.center.Y, origin.Z))
		t.model:PivotTo(look)
		t.model.Parent = targetsFolder
		table.insert(targets, t)
		byKind[kind] = t
		if not (place.sky and kind == "ground") then
			table.insert(points, if kind == "air" then t.center + Vector3.new(t.radius, t.height, 0) else t.center)
			if kind == "air" then
				table.insert(points, t.center + Vector3.new(-t.radius, t.height, 0))
			end
		end
	end
	for _, u in units do
		for slot, w in u.def.weapons or {} do
			local weapon = defs.weaponByIndex[w.weaponIndex]
			local kind = Range.targetKind(weapon, water)
			local t = kind and byKind[kind]
			if t then
				table.insert(u.slots, { slot = slot, weapon = weapon, target = t, nextAt = clock + Range.FIRST_SHOT + slot * 0.3, queue = {}, lastAim = -math.huge, shots = 0 })
			end
		end
	end
	return points
end

function Range.isFiring(): boolean
	return firing
end

-- Which weapons the range can show for `def` (anti-missile and strategic
-- ones can't): a count, for the toolbar.
function Range.shownWeapons(def: any, water: boolean): number
	local n = 0
	for _, w in def.weapons or {} do
		if Range.targetKind(defs and defs.weaponByIndex[w.weaponIndex], water) then
			n += 1
		end
	end
	return n
end

-- firing ----------------------------------------------------------------------

local function muzzleOf(u: Unit, s: Slot): Vector3
	local slotDef = u.def.weapons[s.slot]
	local name = slotDef and slotDef.muzzle
	local list = slotDef and slotDef.muzzles
	if list and #list > 0 then
		name = list[s.shots % #list + 1]
	end
	local att = name and u.model:FindFirstChild(name, true)
	if att and att:IsA("Attachment") then
		return att.WorldPosition
	end
	local cf, size = u.model:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y * 0.3, 0)
end

-- Where a weapon aims at its target now (a moving drone: led a little).
local function aimPoint(t: Target): Vector3
	if t.kind == "ground" then
		return t.pos + Vector3.new(0, 3.5, 0)
	end
	return t.pos
end

-- A shell's launch pitch: the one the weapon uses at a typical real range
-- (RANGE_SHARE of its range), so its arc has the real shape (a howitzer
-- lobs, a tank fires flat) though the target stands closer; the shell is
-- then launched slower to land there (`arcSpeed`).
Range.RANGE_SHARE = 0.7
local function arcPitch(w: any): number
	local g = w.gravity or 0
	if g <= 0 then
		return 0
	end
	return Ballistics.launchPitch(w.projectileSpeed or 200, g, (w.range or 200) * Range.RANGE_SHARE, 0, w.highArc == true) or math.rad(45)
end
local function arcSpeed(w: any, pitch: number, dist: number): number
	local s2 = math.sin(2 * pitch)
	if s2 < 1e-3 then
		return w.projectileSpeed or 200
	end
	return math.sqrt((w.gravity or 0) * dist / s2)
end

-- Turret yaw and barrel pitch (degrees, hull-relative) toward `p`.
local function aimAngles(u: Unit, s: Slot, p: Vector3): (number, number)
	local pivot = u.model:GetPivot()
	local from = muzzleOf(u, s)
	local localP = pivot:PointToObjectSpace(p)
	local yaw = math.deg(math.atan2(localP.X, localP.Z)) -- from the model's +Z, its forward
	local d = p - from
	local dist = Vector3.new(d.X, 0, d.Z).Magnitude
	local w = s.weapon
	local pitch
	if w.type == "BALLISTIC" and (w.gravity or 0) > 0 then
		pitch = arcPitch(w)
	else
		pitch = math.atan2(d.Y, dist)
	end
	local turret = w.turret
	local deg = math.deg(pitch)
	if turret then
		deg = math.clamp(deg, turret.minPitch or -90, turret.maxPitch or 90)
	end
	return yaw, deg
end

local function burst(x: number, y: number, z: number, radius: number, kind: string, life: number, now: number, dir: Vector3?): any
	local b = { x = x, y = y, z = z, radius = radius, born = now, life = life, kind = kind, size = radius, ground = groundAt(Vector3.new(x, y, z)) } :: any
	if dir and dir.Magnitude > 1e-6 then
		local n = dir.Unit
		b.dx, b.dy, b.dz = n.X, n.Y, n.Z
	end
	table.insert(fx.bursts, b)
	return b
end

local function flash(t: Target)
	t.flashUntil = clock + 0.18
end

local function fire(u: Unit, s: Slot, now: number)
	local w = s.weapon
	local from = muzzleOf(u, s)
	s.shots += 1
	table.insert(fx.shots, { u.id, s.slot })
	local t = s.target
	local to = aimPoint(t)
	local size = math.max(1, w.aoe or 1)
	if w.type == "HITSCAN" or w.type == "BEAM" then
		local isBeam = w.type == "BEAM"
		local tracer = {
			x0 = from.X, y0 = from.Y, z0 = from.Z, x1 = to.X, y1 = to.Y, z1 = to.Z,
			born = now, life = if isBeam then Effects.beamSeconds(w) else Effects.TRACER_SECONDS,
			hit = true, size = size, beam = if isBeam then u.faction else nil, weaponId = w.id,
		} :: any
		local fxDef = w.fx
		if fxDef and fxDef.tracer == "laser" then
			local c = fxDef.color
			tracer.laser = if c then { c.r or c[1] or 255, c.g or c[2] or 255, c.b or c[3] or 255 } else { 255, 255, 255 }
			tracer.life = Effects.LASER_SECONDS
		end
		if w.ramp then
			tracer.ramp = Effects.ramp(fx, u.id * 16 + s.slot, w, now)
			tracer.life = (w.reload or 0.2) + 0.08
		end
		table.insert(fx.tracers, tracer)
		burst(from.X, from.Y, from.Z, if isBeam then 2.2 else 0.7 * size, if isBeam then "launch" else "muzzle", if isBeam then 0.3 else 0.1, now, to - from)
		if isBeam then
			burst(to.X, to.Y, to.Z, 2.4, "impact", Effects.EXPLOSION_SECONDS, now)
		end
		flash(t)
		return
	end
	-- a projectile
	local speed = w.projectileSpeed or 200
	local gravity = w.gravity or 0
	local v: Vector3
	local d = to - from
	local flat = Vector3.new(d.X, 0, d.Z)
	local dist = flat.Magnitude
	local dirFlat = if dist > 1e-6 then flat / dist else Vector3.new(0, 0, -1)
	if w.type == "BOMB" then
		gravity = if gravity > 0 then gravity else 60
		local fall = math.sqrt(math.max(2 * math.max(from.Y - to.Y, 1) / gravity, 0.05))
		v = dirFlat * (dist / fall)
	elseif w.type == "HOMING" then
		-- up and out of the launcher, then it turns onto the target
		v = (dirFlat + Vector3.new(0, 0.9, 0)).Unit * speed
		gravity = 0
	elseif w.type == "TORPEDO" then
		v = if d.Magnitude > 1e-6 then d.Unit * speed else dirFlat * speed
		gravity = 0
	elseif gravity > 0 then
		local pitch = arcPitch(w)
		local s0 = arcSpeed(w, pitch, dist)
		v = dirFlat * (s0 * math.cos(pitch)) + Vector3.new(0, s0 * math.sin(pitch), 0)
	else
		v = if d.Magnitude > 1e-6 then d.Unit * speed else dirFlat * speed
	end
	nextProj += 1
	local proj = {
		id = nextProj, x = from.X, y = from.Y, z = from.Z, vx = v.X, vy = v.Y, vz = v.Z,
		ox = 0, oy = 0, oz = 0, ovx = 0, ovy = 0, ovz = 0, blend = 0, age = 0,
		weapon = if gravity ~= (w.gravity or 0) then setmetatable({ gravity = gravity }, { __index = w }) else w,
		target = 0, ttl = 15 * 12, size = size,
	}
	fx.projectiles[nextProj] = proj
	shots[nextProj] = {
		proj = proj,
		target = t,
		steer = if w.type == "HOMING" then math.rad(w.turnRate or 120) * DT else nil,
		groundY = groundAt(from),
		-- what counts as falling short: the target's own level, deep under
		-- a submarine target, else the place's ground
		floor = if t.kind == "ground" then t.center.Y elseif t.kind == "sub" then t.center.Y - 30 else nil,
	}
	if w.type == "HOMING" then
		burst(from.X, from.Y, from.Z, size, "launch", Effects.LAUNCH_SECONDS, now, v)
	elseif w.type ~= "BOMB" then
		burst(from.X, from.Y, from.Z, 0.8, "muzzle", 0.12, now, v)
	end
end

-- One sim tick of every shell: moves, steers, bursts on its target or the
-- ground.
local function stepShots(now: number)
	for id, s in shots do
		local p = s.proj
		local g = p.weapon.gravity or 0
		local to = aimPoint(s.target)
		if s.steer then
			p.vx, p.vy, p.vz = Ballistics.steer(p.vx, p.vy, p.vz, to.X - p.x, to.Y - p.y, to.Z - p.z, s.steer)
		end
		local nx, ny, nz, nvx, nvy, nvz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, g, DT)
		p.ttl -= 1
		local hitTarget = (Vector3.new(nx, ny, nz) - to).Magnitude <= math.max(3, Vector3.new(p.vx, p.vy, p.vz).Magnitude * DT)
		local floor = s.floor or groundAt(Vector3.new(nx, 0, nz))
		local down = ny <= floor and nvy < 0
		if hitTarget or down or p.ttl <= 0 then
			fx.projectiles[id] = nil
			shots[id] = nil
			local at = if hitTarget then to else Vector3.new(nx, math.max(ny, floor), nz)
			burst(at.X, at.Y, at.Z, Effects.impactSize(p.weapon), "impact", Effects.EXPLOSION_SECONDS, now, Vector3.new(p.vx, p.vy, p.vz))
			if hitTarget then
				flash(s.target)
			end
		else
			p.x, p.y, p.z, p.vx, p.vy, p.vz = nx, ny, nz, nvx, nvy, nvz
			p.age += 1
			p.nextState = nil
		end
	end
end

local function stepTargets(dt: number)
	for _, t in targets do
		if t.kind == "air" then
			t.phase += dt * 0.35
			local p = t.center + Vector3.new(math.cos(t.phase) * t.radius, t.height + math.sin(t.phase * 2.3) * 2, math.sin(t.phase) * t.radius)
			local ahead = t.center + Vector3.new(math.cos(t.phase + 0.1) * t.radius, t.height, math.sin(t.phase + 0.1) * t.radius)
			t.pos = p
			t.model:PivotTo(CFrame.lookAt(p, ahead) * CFrame.Angles(0, 0, -0.35))
		end
		local lit = clock < t.flashUntil
		for _, d in t.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Material = if lit then Enum.Material.Neon else (if d.Name == "Board" or d.Name == "Ring" or d.Name == "Band" then Enum.Material.SmoothPlastic else Enum.Material.Metal)
			end
		end
	end
end

local function stepFiring(dt: number, now: number)
	for _, u in units do
		for _, s in u.slots do
			-- aim (the piece script turns the turret and barrel)
			if clock - s.lastAim >= Range.AIM_EVERY then
				s.lastAim = clock
				local yaw, pitch = aimAngles(u, s, aimPoint(s.target))
				PieceAnim.call(u.anim, "AimWeapon", s.slot, yaw, pitch, true)
			end
			-- fire: a salvo's shots, then the reload
			if #s.queue > 0 and clock >= s.queue[1] then
				table.remove(s.queue, 1)
				fire(u, s, now)
			elseif #s.queue == 0 and clock >= s.nextAt then
				local w = s.weapon
				local salvo = w.salvo
				local count = if salvo then salvo.count or 1 else 1
				for k = 2, count do
					table.insert(s.queue, clock + (k - 1) * (salvo.delay or 0.2))
				end
				fire(u, s, now)
				s.nextAt = clock + math.clamp(w.reload or 1, Range.RELOAD_MIN, Range.RELOAD_MAX) + (if salvo then (count - 1) * (salvo.delay or 0.2) else 0)
			end
		end
	end
	tickAcc += dt
	while tickAcc >= DT do
		tickAcc -= DT
		fx.tick += 1
		stepShots(now)
	end
end

-- Every frame while the showroom is open: animation, targets, shots, and
-- the effects drawn.
function Range.step(dt: number)
	if sched == nil then
		return
	end
	clock += dt
	local now = os.clock()
	if firing then
		stepTargets(dt)
		stepFiring(dt, now)
	end
	if renderer == nil and (firing or next(fx.bursts) ~= nil) then
		renderer = RenderEffects.new()
		renderer.folder.Parent = folder
	end
	if renderer then
		local any = next(fx.projectiles) ~= nil or #fx.bursts > 0 or #fx.tracers > 0
		if any or firing then
			RenderEffects.step(renderer, fx, fx.tick + tickAcc / DT, now, 1)
		end
	end
	-- the piece scripts: recoil on each shot, then every joint they moved
	for _, shot in fx.shots do
		local u = units[shot[1]]
		if u then
			PieceAnim.call(u.anim, "FireWeapon", shot[2])
		end
	end
	table.clear(fx.shots)
	PieceAnim.step(sched, dt)
	for _, p in PieceAnim.take(sched) do
		local u = units[p.unit]
		local motor = u and u.motors[p.name]
		if motor then
			local rot, pos = p.rot, p.pos
			motor.Transform = CFrame.Angles(rot[1], rot[2], rot[3]) * CFrame.new(pos[1], pos[2], pos[3])
		end
	end
end

-- The showroom closed: shots and targets go; units detach on their own.
function Range.stop()
	firing = false
	clearTargets()
	clearShots()
	if renderer then
		RenderEffects.step(renderer, fx, fx.tick, os.clock(), 1)
	end
end

return Range
