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
--   StartMoving(u) / StopMoving(u)   the MOVING state bit changed
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
--   u:Sleep(seconds)                    u:StartThread(fn, ...)
--   u:Signal(mask)                      u:SetSignalMask(mask)
-- LOD by camera distance (guide 14.5): "near" runs everything; "mid" only
-- aim (no fire, no moving hooks); "far" no hooks at all and every turn and
-- move snaps; strategic zoom doesn't step the hidden units.

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local PieceAnim = {}

PieceAnim.NEAR = 300 -- studs from the camera
PieceAnim.MID = 600
PieceAnim.REAIM = 0.5 -- seconds between AimWeapon calls while a weapon is engaged

local WS = Schema.WeaponState
local MOVING = Schema.UnitState.MOVING
local AXES = { x = 1, y = 2, z = 3 }

export type Axis = "x" | "y" | "z"
export type Lod = "near" | "mid" | "far"

type Track = { piece: Piece, kind: number, axis: number, cur: number, goal: number, speed: number } -- kind 1 turn (radians), 2 move (studs)

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
	lastAimCall: { [number]: number }, -- slot → scheduler time
	moving: boolean,
	-- methods (see the header)
	Turn: (Unit, string, Axis, number, number?) -> (),
	Move: (Unit, string, Axis, number, number?) -> (),
	WaitForTurn: (Unit, string, Axis) -> (),
	WaitForMove: (Unit, string, Axis) -> (),
	Sleep: (Unit, number) -> (),
	StartThread: (Unit, (...any) -> (), ...any) -> (),
	Signal: (Unit, number) -> (),
	SetSignalMask: (Unit, number) -> (),
	weapon: (Unit, number) -> any, -- weapon def of a slot
}

export type Sched = {
	now: number,
	units: { [number]: Unit },
	active: { [Track]: boolean }, -- tracks still moving
	threads: { Thread }, -- waiting threads
	current: Thread?, -- the thread running now
	dirty: { Piece }, -- pieces changed since the last take
	stats: { threads: number, tracks: number, hooks: number },
	weaponDefs: { any }, -- by weapon index (u:weapon)
}

function PieceAnim.new(weaponDefs: { any }): Sched
	return { now = 0, units = {}, active = {}, threads = {}, current = nil, dirty = {}, stats = { threads = 0, tracks = 0, hooks = 0 }, weaponDefs = weaponDefs }
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

local function spawn(u: Unit, mask: number, fn: (...any) -> (), ...: any)
	local s = u.sched
	local th: Thread = { co = coroutine.create(fn), unit = u, mask = mask, wake = nil, wait = nil, dead = false }
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

local function waitFor(u: Unit, piece: string, kind: number, axis: Axis)
	local tr = trackOf(u, piece, kind, axis)
	if tr and u.sched.active[tr] then
		running(u).wait = tr
		coroutine.yield()
	end
end

function Methods.WaitForTurn(u: Unit, piece: string, axis: Axis)
	waitFor(u, piece, 1, axis)
end

function Methods.WaitForMove(u: Unit, piece: string, axis: Axis)
	waitFor(u, piece, 2, axis)
end

function Methods.Sleep(u: Unit, seconds: number)
	running(u).wake = u.sched.now + seconds
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
		lastAimCall = {},
		moving = false,
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
function PieceAnim.drive(s: Sched, world: World.World, shots: { { number } })
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
			local moving = bit32.band(wu.state or 0, MOVING) ~= 0
			if moving ~= u.moving then
				u.moving = moving
				PieceAnim.call(u, if moving then "StartMoving" else "StopMoving")
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
