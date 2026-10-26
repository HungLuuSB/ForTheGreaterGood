--!strict
-- Piece scripts (guide 14.3–14.5, C-30): BAR-style unit scripts that turn
-- and move model pieces over time. One scheduler advances every turn and
-- move and resumes sleeping script threads once per frame; scripts run as
-- coroutines with BAR's signal masks. Visual only: the server's aim model
-- decides when weapons fire (guide 14.1). Pure Luau (C-7); Render applies
-- the pieces' rotations and offsets to Motor6D.Transform.
--
-- Script hooks (all optional), each run in a new thread:
--   Create(u)                        the unit got a model
--   StartMoving(u) / StopMoving(u)   the unit started / stopped moving (World.moving, C-45)
--   Land(u) / TakeOff(u)             the LANDED state bit changed (aircraft)
--   Deploy(u, phase, instant)        a deployable unit's phase changed (S-64: the
--                                    DEPLOYED / DEPLOYING bits, C-84): "unpacking",
--                                    "deployed", "packing" or "packed"; `instant` the
--                                    first time (a unit seen already deployed)
--   Retract(u, retracted, instant)   a retractable tower (def.retract, S-96) was
--                                    switched off (TOGGLED_ON clear: retracted)
--                                    or on (C-112); `instant` the first time
--   Work(u, yaw)                     a builder's work target (G4): the
--                                    target's bearing from the hull in
--                                    degrees, or nil when it stops working
--                                    (called on a change; not while a
--                                    weapon is engaged, AimWeapon has it)
--   AimWeapon(u, slot, yaw, pitch, active)
--                                    the replicated aim changed, or every
--                                    REAIM seconds while the weapon is
--                                    AIMING / READY (active); degrees,
--                                    yaw relative to the hull
--   FireWeapon(u, slot)              a shot left that weapon
-- Helpers on `u` (angles in degrees, speeds in degrees or studs per
-- second; a speed of 0 or nil is instant):
--   u:Turn(piece, axis, angle, speed)   u:Move(piece, axis, offset, speed)
--   u:WaitForTurn(piece, axis)          u:WaitForMove(piece, axis)
--   u:Spin(piece, axis, speed, accel?)  u:StopSpin(piece, axis, decel?)
--                                       (continuous rotation; accel in degrees/s²,
--                                       none = at once)
--   u:Sleep(seconds)                    u:StartThread(fn, ...)
--   u:Signal(mask)                      u:SetSignalMask(mask)
-- LOD by camera distance (guide 14.5): "near" runs everything; "mid" only
-- aim (no fire, no moving hooks); "far" no hooks at all and every turn and
-- move snaps; strategic zoom doesn't step the hidden units.

local Schema = require("@shared/Net/Schema")
local Ambient = require("./PieceScripts/Ambient")
local Nanoframe = require("./Nanoframe")
local PieceMotion = require("./PieceMotion")
local World = require("./World")

local PieceAnim = {}

PieceAnim.NEAR = 300 -- studs from the camera
PieceAnim.MID = 600
PieceAnim.REAIM = 0.5 -- seconds between AimWeapon calls while a weapon is engaged

local WS = Schema.WeaponState
local LANDED = Schema.UnitState.LANDED
local TOGGLED_ON = Schema.UnitState.TOGGLED_ON
local DEPLOYED = Schema.UnitState.DEPLOYED
local DEPLOYING = Schema.UnitState.DEPLOYING
local AXES = { x = 1, y = 2, z = 3 }

export type Axis = "x" | "y" | "z"
export type Lod = "near" | "mid" | "far"

type Track = { piece: Piece, kind: number, axis: number, cur: number, goal: number, speed: number } -- kind 1 turn (radians), 2 move (studs)
type SpinState = { piece: Piece, axis: number, speed: number, target: number, accel: number } -- radians per second (per second²)

export type Piece = {
	unit: number, -- unit ID
	name: string,
	rot: { number }, -- x, y, z radians
	pos: { number }, -- x, y, z studs
	tracks: { [number]: Track }, -- (kind - 1) * 3 + axis → its track
	dirty: boolean,
}

type Thread = {
	co: thread,
	unit: Unit,
	mask: number,
	wake: number?, -- Sleep: resume at this scheduler time
	wait: Track?, -- WaitForTurn / WaitForMove: resume when it arrives
	dead: boolean,
	spins: number, -- waits in a row that didn't yield (the spin guard, C-180)
}

export type Unit = {
	id: number,
	def: any,
	script: any,
	sched: Sched,
	pieces: { [string]: Piece },
	lod: Lod,
	-- what the driver last saw
	seenAim: { [number]: { number } }, -- slot → { yaw, pitch } (radians)
	aimLag: { [number]: number }, -- slot → the hull lag a locked turret was last shifted by (G9)
	workKey: string?, -- the work target Work was last called with ("" none)
	lastAimCall: { [number]: number }, -- slot → scheduler time
	moving: boolean,
	landed: boolean,
	retracted: boolean?, -- def.retract towers: TOGGLED_ON clear (C-112)
	motions: { PieceMotion.Motion }, -- the def's animated pieces (C-156)
	ambientKey: number?, -- the state Ambient last planned for
	spins: { [string]: SpinState }, -- "piece:axis" → spin
	-- methods (see the header)
	Turn: (Unit, string, Axis, number, number?) -> (),
	Move: (Unit, string, Axis, number, number?) -> (),
	WaitForTurn: (Unit, string, Axis) -> (),
	WaitForMove: (Unit, string, Axis) -> (),
	Sleep: (Unit, number) -> (),
	Spin: (Unit, string, Axis, number, number?) -> (),
	StopSpin: (Unit, string, Axis, number?) -> (),
	StartThread: (Unit, (...any) -> (), ...any) -> (),
	Signal: (Unit, number) -> (),
	SetSignalMask: (Unit, number) -> (),
	weapon: (Unit, number) -> any, -- weapon def of a slot
}

export type Sched = {
	now: number,
	units: { [number]: Unit },
	active: { [Track]: boolean }, -- tracks still moving
	spinning: { [SpinState]: boolean },
	threads: { Thread }, -- waiting threads
	current: Thread?, -- the thread running now
	dirty: { Piece }, -- pieces changed since the last take
	stats: { threads: number, tracks: number, hooks: number },
	weaponDefs: { any }, -- by weapon index (u:weapon)
}

function PieceAnim.new(weaponDefs: { any }): Sched
	return { now = 0, units = {}, active = {}, spinning = {}, threads = {}, current = nil, dirty = {}, stats = { threads = 0, tracks = 0, hooks = 0 }, weaponDefs = weaponDefs }
end

local function pieceOf(u: Unit, name: string): Piece
	local p = u.pieces[name]
	if p == nil then
		p = { unit = u.id, name = name, rot = { 0, 0, 0 }, pos = { 0, 0, 0 }, tracks = {}, dirty = false }
		u.pieces[name] = p
	end
	return p
end

local function markDirty(s: Sched, p: Piece)
	if not p.dirty then
		p.dirty = true
		table.insert(s.dirty, p)
	end
end

local function write(p: Piece, kind: number, axis: number, v: number)
	if kind == 1 then
		p.rot[axis] = v
	else
		p.pos[axis] = v
	end
end

local function setGoal(u: Unit, name: string, kind: number, axisName: Axis, goal: number, speed: number?)
	local axis = AXES[axisName]
	if axis == nil then
		return
	end
	local s = u.sched
	local p = pieceOf(u, name)
	local key = (kind - 1) * 3 + axis
	local tr = p.tracks[key]
	if tr == nil then
		tr = { piece = p, kind = kind, axis = axis, cur = 0, goal = 0, speed = 0 }
		p.tracks[key] = tr
	end
	if kind == 1 then
		-- a turn takes the short way round: aims arrive in -180..180°, and
		-- from 170° to -170° a straight step swung 340° (the user, C-107)
		goal = tr.cur + (goal - tr.cur + math.pi) % (2 * math.pi) - math.pi
	end
	tr.goal = goal
	tr.speed = speed or 0
	if tr.speed <= 0 or u.lod == "far" then
		tr.cur = goal
		s.active[tr] = nil
		write(p, kind, axis, goal)
		markDirty(s, p)
	elseif tr.cur ~= goal then
		s.active[tr] = true
	end
end

local function trackOf(u: Unit, name: string, kind: number, axisName: Axis): Track?
	local p = u.pieces[name]
	local axis = AXES[axisName]
	return if p and axis then p.tracks[(kind - 1) * 3 + axis] else nil
end

-- A locked turret holds its aim in the world while the hull turns under it
-- (G9, the user: "the turret need to hold its lock on the target, and don't
-- drift away with the body"). The wire's yaw is relative to the newest
-- tick's hull; the hull is drawn Interp.DELAY_TICKS behind, still turning
-- toward that heading, so the turret is drawn at yaw + (newest heading -
-- drawn heading) (the sim's world aim = heading + yaw). Each frame the
-- turret's track moves by the change in that lag (with the hull, at once),
-- and its goal is the wire's yaw plus the lag, turned toward at the
-- turret's own rate as before.
local function holdWorldAim(u: Unit, slot: number, piece: string, yaw: number, lag: number)
	local tr = trackOf(u, piece, 1, "y")
	if tr == nil then
		return
	end
	local d = (lag - (u.aimLag[slot] or 0) + math.pi) % (2 * math.pi) - math.pi
	u.aimLag[slot] = lag
	tr.cur += d
	tr.goal = tr.cur + (yaw + lag - tr.cur + math.pi) % (2 * math.pi) - math.pi
	local s = u.sched
	if tr.speed <= 0 then
		tr.cur = tr.goal
	elseif tr.cur ~= tr.goal then
		s.active[tr] = true
	end
	write(tr.piece, tr.kind, tr.axis, tr.cur)
	markDirty(s, tr.piece)
end

local function spawn(u: Unit, mask: number, fn: (...any) -> (), ...: any)
	local s = u.sched
	local th: Thread = { co = coroutine.create(fn), unit = u, mask = mask, wake = nil, wait = nil, dead = false, spins = 0 }
	local outer = s.current
	s.current = th
	local ok, err = coroutine.resume(th.co, u, ...)
	s.current = outer
	if not ok then
		warn(`[PieceAnim] {u.def.id}: {err}`)
		th.dead = true
	end
	if not th.dead and coroutine.status(th.co) == "suspended" then
		table.insert(s.threads, th)
	end
end

-- The running thread of `u` (helpers that yield must run in a script thread).
local function running(u: Unit): Thread
	local th = u.sched.current
	assert(th and th.unit == u, "PieceAnim: call this from the unit's script thread")
	return th
end

local Methods = {}

function Methods.Turn(u: Unit, piece: string, axis: Axis, angle: number, speed: number?)
	setGoal(u, piece, 1, axis, math.rad(angle), if speed then math.rad(speed) else nil)
end

function Methods.Move(u: Unit, piece: string, axis: Axis, offset: number, speed: number?)
	setGoal(u, piece, 2, axis, offset, speed)
end

-- A loop of turns and waits that never yields would hang the client: far
-- away (LOD "far") a turn lands at once, so its wait returns at once (the
-- C-177 freeze). After this many waits in a row that didn't yield, the
-- thread is held to the next frame instead (C-180).
PieceAnim.SPIN_LIMIT = 64

local function waitFor(u: Unit, piece: string, kind: number, axis: Axis)
	local tr = trackOf(u, piece, kind, axis)
	local th = running(u)
	if tr and u.sched.active[tr] then
		th.spins = 0
		th.wait = tr
		coroutine.yield()
	elseif th.spins >= PieceAnim.SPIN_LIMIT then
		if th.spins == PieceAnim.SPIN_LIMIT then
			warn(`[PieceAnim] {u.def.id}: a loop waits on pieces that have already arrived; holding it a frame each time`)
		end
		th.spins += 1
		th.wake = u.sched.now
		coroutine.yield()
	else
		th.spins += 1
	end
end

function Methods.WaitForTurn(u: Unit, piece: string, axis: Axis)
	waitFor(u, piece, 1, axis)
end

function Methods.WaitForMove(u: Unit, piece: string, axis: Axis)
	waitFor(u, piece, 2, axis)
end

function Methods.Sleep(u: Unit, seconds: number)
	local th = running(u)
	th.spins = 0
	th.wake = u.sched.now + seconds
	coroutine.yield()
end

function Methods.StartThread(u: Unit, fn: (...any) -> (), ...: any)
	local th = u.sched.current
	spawn(u, if th and th.unit == u then th.mask else 0, fn, ...)
end

-- Kills this unit's other threads whose mask shares a bit with `mask`.
function Methods.Signal(u: Unit, mask: number)
	local s = u.sched
	for _, th in s.threads do
		if th.unit == u and th ~= s.current and bit32.band(th.mask, mask) ~= 0 then
			th.dead = true
		end
	end
end

local function spinOf(u: Unit, piece: string, axisName: Axis): SpinState?
	local axis = AXES[axisName]
	if axis == nil then
		return nil
	end
	local key = `{piece}:{axisName}`
	local sp = u.spins[key]
	if sp == nil then
		sp = { piece = pieceOf(u, piece), axis = axis, speed = 0, target = 0, accel = 0 }
		u.spins[key] = sp
	end
	return sp
end

function Methods.Spin(u: Unit, piece: string, axis: Axis, speed: number, accel: number?)
	local sp = spinOf(u, piece, axis)
	if sp == nil then
		return
	end
	sp.target = math.rad(speed)
	sp.accel = if accel then math.rad(accel) else 0
	if sp.accel <= 0 then
		sp.speed = sp.target
	end
	u.sched.spinning[sp] = true
end

function Methods.StopSpin(u: Unit, piece: string, axis: Axis, decel: number?)
	local sp = spinOf(u, piece, axis)
	if sp == nil then
		return
	end
	sp.target = 0
	sp.accel = if decel then math.rad(decel) else 0
	if sp.accel <= 0 then
		sp.speed = 0
	end
end

function Methods.SetSignalMask(u: Unit, mask: number)
	running(u).mask = mask
end

function Methods.weapon(u: Unit, slot: number): any
	local w = u.def.weapons[slot]
	return if w then u.sched.weaponDefs[w.weaponIndex] else nil
end

-- Starts animating unit `id` with `script` (a table of hooks).
function PieceAnim.add(s: Sched, id: number, def: any, script: any): Unit
	local u = {
		id = id,
		def = def,
		script = script,
		sched = s,
		pieces = {},
		lod = "near",
		seenAim = {},
		aimLag = {},
		lastAimCall = {},
		moving = false,
		landed = false,
		spins = {},
		motions = PieceMotion.forDef(def),
	} :: any
	for name, fn in Methods do
		u[name] = fn
	end
	s.units[id] = u
	PieceAnim.call(u, "Create")
	return u :: Unit
end

-- Stops animating unit `id` (its model went back to the pool): its threads
-- end, its pieces are forgotten.
function PieceAnim.remove(s: Sched, id: number)
	local u = s.units[id]
	if u == nil then
		return
	end
	s.units[id] = nil
	for _, th in s.threads do
		if th.unit == u then
			th.dead = true
		end
	end
	for _, p in u.pieces do
		for _, tr in p.tracks do
			s.active[tr] = nil
		end
	end
	for _, sp in u.spins do
		s.spinning[sp] = nil
	end
end

-- Runs a script hook in a new thread, if the script has it.
function PieceAnim.call(u: Unit, hook: string, ...: any)
	local fn = u.script[hook]
	if fn then
		u.sched.stats.hooks += 1
		spawn(u, 0, fn, ...)
	end
end

-- Calls the hooks the replicated state asks for (guide 14.3). `shots` are
-- this frame's { unitId, slot } shots (Core/Effects).
-- `work`: builder → where the thing it works on now stands, { x, z }
-- (a unit or a wreck: Core/BuildTargets; G4).
function PieceAnim.drive(s: Sched, world: World.World, shots: { { number } }, work: { [number]: { number } }?)
	local eco = world.economy
	local ownRatio = if eco then eco.power.ratio / 255 else 1
	local myTeam = world.me and world.me.team
	for id, u in s.units do
		local wu = world.units[id]
		if wu == nil then
			continue
		end
		if u.lod == "far" then
			-- no hooks: just snap aim pieces (the default turret / pitch pieces)
			for slot, a in wu.aim do
				local slotDef = u.def.weapons[slot]
				if slotDef then
					if slotDef.turretPiece then
						setGoal(u, slotDef.turretPiece, 1, "y", a.yaw, 0)
					end
					if slotDef.pitchPiece then
						setGoal(u, slotDef.pitchPiece, 1, "x", a.pitch, 0)
					end
				end
			end
			continue
		end
		if u.lod == "near" then
			local moving = World.moving(world, wu)
			if moving ~= u.moving then
				u.moving = moving
				PieceAnim.call(u, if moving then "StartMoving" else "StopMoving")
			end
		end
		local landed = bit32.band(wu.state or 0, LANDED) ~= 0
		if landed ~= u.landed then
			u.landed = landed
			PieceAnim.call(u, if landed then "Land" else "TakeOff")
		end
		-- the animated pieces every unit has (C-156): re-planned on a state change
		if #u.motions > 0 then
			local moving = if u.lod == "near" then u.moving else World.moving(world, wu)
			local power = PieceMotion.power(u.def, wu.state or 0, wu.build, if wu.team == myTeam then ownRatio else 1)
			local producing = Nanoframe.producing(wu) ~= nil
			local key = PieceMotion.key(moving, power, producing, landed)
			if key ~= u.ambientKey then
				u.ambientKey = key
				s.stats.hooks += 1
				spawn(u, 0, Ambient.apply, u.motions, { moving = moving, power = power, producing = producing, landed = landed })
			end
		end
		if u.def.retract then
			local retracted = bit32.band(wu.state or 0, TOGGLED_ON) == 0
			if retracted ~= u.retracted then
				local first = u.retracted == nil
				u.retracted = retracted
				PieceAnim.call(u, "Retract", retracted, first)
			end
		end
		if u.def.deploy then
			-- the deploy phase from the two bits; packing is DEPLOYING after deployed
			local st = wu.state or 0
			local phase = if bit32.band(st, DEPLOYING) ~= 0
				then (if u.deploy == "deployed" or u.deploy == "packing" then "packing" else "unpacking")
				elseif bit32.band(st, DEPLOYED) ~= 0 then "deployed"
				else "packed"
			if phase ~= u.deploy then
				local first = u.deploy == nil
				u.deploy = phase
				PieceAnim.call(u, "Deploy", phase, first)
			end
		end
		-- the upper body toward the work (G4, the user: "Commander should rotate
		-- its upper part of the body toward the current task"); a weapon in
		-- action turns it instead
		if u.lod == "near" and u.script and u.script.Work then
			local engaged = false
			for slot in wu.aim do
				local st = Schema.weaponStateAt(wu.weapon or 0, slot)
				engaged = engaged or st == WS.AIMING or st == WS.READY
			end
			local at = if work and not engaged then work[id] else nil
			local yaw: number? = nil
			if at then
				local rel = math.atan2(at[1] - wu.x, at[2] - wu.z) - (wu.rheading or wu.heading)
				yaw = math.deg((rel + math.pi) % (2 * math.pi) - math.pi)
			end
			local key = if yaw then tostring(math.floor((yaw :: number) / 3)) else ""
			if key ~= (u.workKey or "") then
				u.workKey = key
				PieceAnim.call(u, "Work", yaw)
			end
		end
		for slot, a in wu.aim do
			local seen = u.seenAim[slot]
			local state = Schema.weaponStateAt(wu.weapon or 0, slot)
			local active = state == WS.AIMING or state == WS.READY
			local changed = seen == nil or seen[1] ~= a.yaw or seen[2] ~= a.pitch
			local due = active and s.now - (u.lastAimCall[slot] or -math.huge) >= PieceAnim.REAIM
			if changed or due then
				u.seenAim[slot] = { a.yaw, a.pitch }
				u.lastAimCall[slot] = s.now
				PieceAnim.call(u, "AimWeapon", slot, math.deg(a.yaw), math.deg(a.pitch), active)
			end
			local slotDef = u.def.weapons[slot]
			local drawn = wu.rheading
			if active and drawn and slotDef and slotDef.turretPiece then
				holdWorldAim(u, slot, slotDef.turretPiece, a.yaw, (wu.heading - drawn + math.pi) % (2 * math.pi) - math.pi)
			else
				u.aimLag[slot] = nil
			end
		end
	end
	for _, shot in shots do
		local u = s.units[shot[1]]
		if u and u.lod == "near" then
			PieceAnim.call(u, "FireWeapon", shot[2])
		end
	end
end

-- Advances time by `dt`: turns and moves, then waiting threads.
function PieceAnim.step(s: Sched, dt: number)
	s.now += dt
	local tracks = 0
	for tr in s.active do
		tracks += 1
		local d = tr.goal - tr.cur
		local stepLen = tr.speed * dt
		if math.abs(d) <= stepLen then
			tr.cur = tr.goal
			s.active[tr] = nil
		else
			tr.cur += if d > 0 then stepLen else -stepLen
		end
		write(tr.piece, tr.kind, tr.axis, tr.cur)
		markDirty(s, tr.piece)
	end
	for sp in s.spinning do
		if sp.speed ~= sp.target then
			local d = sp.target - sp.speed
			local stepLen = sp.accel * dt
			sp.speed = if math.abs(d) <= stepLen then sp.target else sp.speed + (if d > 0 then stepLen else -stepLen)
		end
		if sp.speed == 0 and sp.target == 0 then
			s.spinning[sp] = nil
			continue
		end
		local p = sp.piece
		p.rot[sp.axis] = (p.rot[sp.axis] + sp.speed * dt) % (2 * math.pi)
		markDirty(s, p)
	end
	-- resume what is due; resumed threads may add new waiting threads
	local waiting = s.threads
	s.threads = {}
	for _, th in waiting do
		if th.dead then
			continue
		end
		local ready = (th.wake ~= nil and s.now >= th.wake) or (th.wait ~= nil and not s.active[th.wait])
		if ready then
			th.wake, th.wait = nil, nil
			local outer = s.current
			s.current = th
			local ok, err = coroutine.resume(th.co)
			s.current = outer
			if not ok then
				warn(`[PieceAnim] {th.unit.def.id}: {err}`)
				th.dead = true
			end
		end
		if not th.dead and coroutine.status(th.co) == "suspended" then
			table.insert(s.threads, th)
		end
	end
	s.stats.threads = #s.threads
	s.stats.tracks = tracks
end

-- The pieces changed since the last call (the caller writes their joints).
function PieceAnim.take(s: Sched): { Piece }
	local out = s.dirty
	s.dirty = {}
	for _, p in out do
		p.dirty = false
	end
	return out
end

-- LOD of a unit at distance `d` from the camera.
function PieceAnim.lodAt(d: number): Lod
	return if d <= PieceAnim.NEAR then "near" elseif d <= PieceAnim.MID then "mid" else "far"
end

return PieceAnim
