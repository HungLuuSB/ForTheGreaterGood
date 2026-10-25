--!strict
-- The client's table of known units (guide 15.1): every unit the server told
-- this player about, in both tiers. Pure data, no Instances (C-7): NetIn
-- fills it from packets, Interp samples it, the renderer drains its queues.
--
-- Wire conventions: docs/contracts/net.md (protocol 5).

local Defs = require("@shared/Defs/Defs")
local MoveClasses = require("@shared/Defs/MoveClasses")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Schema = require("@shared/Net/Schema")
local Terrain = require("./Terrain")

local World = {}

World.MAX_SNAPS = 4 -- per unit (guide 7.4: 3–4)
-- A unit counts as moving this many ticks after its position or heading
-- last changed (C-45): tactical records come every tick it moves, strategic
-- ones every 5th tick at cell precision, so a slow unit may keep its cell
-- for a few snapshots.
World.MOVING_TICKS = table.freeze({ tactical = 2, strategic = 16 })
World.MAX_QUEUED_EVENTS = 1024 -- combat events kept until the renderer drains them

-- Unit state bits (net.md section 3), shared with the sim (S-6).
World.State = Schema.UnitState

export type Snap = { tick: number, x: number, z: number, alt: number, heading: number }

export type Aim = { yaw: number, pitch: number } -- radians; yaw relative to the hull

export type Unit = {
	id: number,
	tier: "tactical" | "strategic",
	team: number,
	defIndex: number?, -- tactical units (and strategic ones once the icon maps to a def later)
	icon: number?, -- strategic records: 0 = unknown blip
	flags: number?, -- strategic records: Schema.StrategicFlag
	-- latest known values
	x: number,
	z: number,
	sx: number?, -- strategic records: where they're drawn, gliding toward x, z (radar blips don't jump, C-151)
	sz: number?,
	gx: number?, -- the glide toward x, z; sx, sz add the blip's orbit to it (C-154)
	gz: number?,
	alt: number,
	heading: number, -- radians, (sin h, cos h) forward
	snaps: { Snap }, -- tactical: ascending sim ticks
	lastTick: number, -- sim tick of the last position applied (drops reordered unreliable records)
	movedTick: number?, -- sim tick its position or heading last changed (C-45)
	health: number?, -- 0..1, the latest the server sent
	shownHealth: number?, -- what the bars show: health as of the render tick (C-49, World.settle)
	healthLog: { { number } }?, -- health changes not shown yet: { tick, health }, oldest first
	build: number?, -- 0..1
	state: number,
	weapon: number, -- Schema weapon state field
	aim: { [number]: Aim }, -- by weapon slot
	targets: { [number]: number }?, -- own units (S-16): target unit id by weapon slot, 0 = none; nil until the server sends them
	stock: { [number]: number }?, -- own units (S-47): missiles in stock by weapon slot (slots with a stockpile only)
	stockProgress: { [number]: { number } }?, -- own units (S-49): the next missile's build progress (0..1) by slot, and the record's tick
	-- own units only (S-61, protocol 20); nil until the server sends them
	queue: { number }?, -- a factory's queue: unit def indices, the head in production
	queueProgress: number?, -- the head item's progress, 0..1 (to a 255th)
	producing: number?, -- allied factories (protocol 27, S-103): the def index in production, 0 = idle
	producingProgress: number?, -- its progress, 0..1
	productionShown: number?, -- the item's progress as drawn (eased between the server's steps, Render/FactoryFrames, C-168)
	fireState: number?, -- Schema.FireState
	moveState: number?, -- Schema.MoveState
	ammo: number?, -- aircraft with an ammo count: rounds left
	maxAmmo: number?,
	flares: number?, -- countermeasure charges left (protocol 21, S-63); nil until sent
	chaff: number?,
	-- where the renderer drew it this frame (ground + altitude for ry); nil when not drawn
	rx: number?,
	ry: number?,
	rz: number?,
}

-- A tactical unit that died: the renderer plays its death and drops the model.
-- `alt`, `vx`, `vz`: its altitude and velocity (studs/s, from its last two
-- snapshots) for an aircraft's fall (C-48).
export type Death = { id: number, defIndex: number?, team: number, x: number, z: number, heading: number, severity: number, wreckId: number, tick: number, alt: number, vx: number, vz: number }

export type Me = { player: number, team: number, allyTeam: number }

-- The ally team's sight on the sensor grid (SIGHT_ROWS / SIGHT_CELLS,
-- protocol 10, C-65): one byte (0 / 1) per sensor cell. `changed` lists
-- cells set since the last reader cleared it; `full` says a SIGHT_ROWS
-- replaced rows wholesale (the reader diffs everything).
export type Sight = { width: number, depth: number, cells: buffer, version: number, changed: { number }, full: boolean }

-- A wreck the team knows of (WRECK, protocol 10, C-65).
-- A known wreck (C-65). Supply and resurrect progress (protocol 35, S-168;
-- C-216): `supply` left in it and `fullSupply` it held at the death (whole
-- units), `rez` 0..1; out of sight they keep their last values.
export type Wreck = { id: number, defIndex: number, x: number, z: number, heading: number, supply: number, fullSupply: number, rez: number }

-- An own unit's status off camera (OWN_STATUS, S-158): health and build
-- 0..1, the factory queue's head (unit def index, 0 = none), its progress
-- 0..1 and the queue's length.
export type OwnStatus = { health: number, build: number, queueHead: number, queueProgress: number, queueCount: number }

-- The queue an OWN_STATUS describes, from the one the client last had: the
-- old queue from its head on, cut or padded (with its last item) to the
-- count; the head alone repeated when the old one doesn't hold it.
function World.statusQueue(old: { number }?, head: number, count: number): { number }
	local out = {}
	if head == 0 or count == 0 then
		return out
	end
	local from = if old then table.find(old, head) else nil
	for i = 1, count do
		local item = if from and old then old[from + i - 1] else nil
		out[i] = item or out[i - 1] or head
	end
	out[1] = head
	return out
end

-- Applies `status` to own unit `u` while it's outside the tactical tier.
function World.applyStatus(u: Unit, status: OwnStatus)
	u.health = status.health
	u.shownHealth = status.health
	u.build = status.build
	if status.queueHead ~= 0 or status.queueCount ~= 0 or u.queue ~= nil then
		u.queue = World.statusQueue(u.queue, status.queueHead, status.queueCount)
		u.queueProgress = status.queueProgress
	end
end

-- The pre-game (net.md 9b, protocols 36-37, S-169, S-174; C-218): every
-- player's pick, ready, faction and host flags (PREGAME), the pick clock
-- (PICK_CLOCK), the spawn boxes (START_BOXES), the countdown (COUNTDOWN)
-- and the Commanders' queued builds (PREBUILD). `active` from the first PREGAME until the
-- COUNTDOWN 0 that starts the match; a match with fixed starts never has one.
export type PregamePick = { flags: number, x: number?, z: number? } -- flags: Schema.PregameFlag
export type PregameBuild = { defIndex: number, x: number, z: number, facing: number }
export type Pregame = {
	active: boolean,
	started: boolean, -- COUNTDOWN 0 arrived: the Commanders are on the picks
	picks: { [number]: PregamePick }, -- by sim player
	countdown: number?, -- 3..1 while counting down (5..1 before protocol 37), nil otherwise
	builds: { [number]: { PregameBuild } }, -- by sim player: the player's and its allies' (spectators: all)
	clock: { seconds: number, flags: number }?, -- the last PICK_CLOCK (protocol 37): Schema.PickClockFlag bits
	boxes: { [number]: { number } }?, -- ally team → its spawn box { x0, z0, x1, z1 } (START_BOXES, protocol 37)
	startedTick: number?, -- the tick of COUNTDOWN 0: the Commanders land for Schema.LANDING_TICKS from it
	version: number, -- bumps on every change (the views redraw)
}

function World.newPregame(): Pregame
	return { active = false, started = false, picks = {}, countdown = nil, builds = {}, clock = nil, boxes = nil, startedTick = nil, version = 0 }
end

export type World = {
	shownTick: number?, -- the render tick World.settle last ran for (C-49)
	grid: Grid.Grid,
	layers: Layers.Layers?,
	mapId: string?,
	mapVersion: number, -- bumps when WELCOME brings another map (the renderer rebuilds the ground)
	defs: Defs.DefSet,
	me: Me,
	teamAllies: { [number]: number }, -- every team's ally team (WELCOME, protocol 30, S-129); empty before
	joined: boolean, -- a WELCOME arrived; everything else is dropped before it
	joins: number, -- WELCOMEs received (the renderer starts over on a change)
	rejected: Schema.SnapshotRecord?, -- the server's REJECT: stale client
	economy: Schema.Eco?, -- own team's account (Eco channel)
	units: { [number]: Unit },
	latestTick: number, -- newest sim tick seen on any channel, -1 before the first
	latestAt: number, -- local time (seconds) when latestTick arrived
	strategicTick: number, -- wire tick of the current strategic snapshot, -1 none
	-- queues the renderer drains each frame
	entered: { number }, -- became tactical (ENTER)
	left: { number }, -- stopped being tactical without dying (LEAVE)
	died: { Death },
	dying: { [number]: { unit: Unit, tick: number } }, -- units whose DEATH arrived but isn't drawn yet (C-50)
	events: { Schema.Event }, -- combat events (FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK) with `tick`
	dropped: number, -- records dropped as out of sync or malformed (diagnostics)
	eventCounts: { [number]: number }, -- combat events received per Schema.EventKind (0 = homing correction)
	sight: Sight?, -- the server's ally-team sight (C-65); nil before the first record
	wrecks: { [number]: Wreck }, -- known wrecks by wreck ID (C-65)
	wreckAdded: { number }, -- queues the wreck renderer drains: WRECK
	wreckGone: { number }, -- WRECK_GONE (reclaimed or gone)
	alertQueue: { { kind: number, x: number, z: number, defIndex: number, tick: number } }, -- ALERT events (protocol 23, S-68) Core/Alerts drains
	cheatResults: { any }, -- CHEAT_RESULT events (protocol 27, S-102) the cheat command line drains (C-119)
	lastShot: { [number]: { [number]: number } }, -- unit → weapon slot → sim tick of its last shot seen (FIRE, a launch; the reload bar, C-170)
	idle: { [number]: boolean }, -- the player's idle builders and factories, on camera or not (IDLE, protocol 31, S-136; C-158)
	ownStatus: { [number]: OwnStatus }, -- own units off camera: the latest OWN_STATUS by unit (protocol 34, S-158; C-205), kept until the unit ENTERs or dies
	remoteDomes: { [number]: { x: number, y: number, z: number, radius: number, charge: number, flags: number } }, -- domes of generators not in the tactical tier (DOME, protocol 29, S-122): drawn without vision, as in BAR (C-145)
	shields: { [number]: { charge: number, flags: number } }, -- shield generators' domes by unit id (SHIELD, protocol 24, S-79): charge 0..1 of capacity, Schema.ShieldFlag bits
	deathWrecks: { [number]: number }, -- wreck ID → the tick of the DEATH that left it (its death animation places it)
	pregame: Pregame, -- the pre-game's picks and countdown (C-218)
}

-- An empty world waiting for the server's WELCOME (net.md section 10).
function World.new(defs: Defs.DefSet): World
	return {
		grid = Grid.new(1, 1), -- replaced by the WELCOME's map
		layers = nil,
		mapId = nil,
		mapVersion = 0,
		defs = defs,
		me = { player = 0, team = 0, allyTeam = 0 },
		teamAllies = {},
		joined = false,
		joins = 0,
		rejected = nil,
		economy = nil,
		units = {},
		latestTick = -1,
		latestAt = 0,
		strategicTick = -1,
		entered = {},
		left = {},
		died = {},
		dying = {},
		events = {},
		dropped = 0,
		eventCounts = {},
		sight = nil,
		wrecks = {},
		wreckAdded = {},
		wreckGone = {},
		alertQueue = {},
		cheatResults = {},
		shields = {},
		remoteDomes = {},
		idle = {},
		ownStatus = {},
		lastShot = {},
		deathWrecks = {},
		pregame = World.newPregame(),
	}
end

-- Applies a WELCOME: who we are, the map, the full sim tick. Drops
-- everything known before (a join or reconnect rebuilds the whole view).
function World.welcome(world: World, rec: Schema.SnapshotRecord, now: number)
	local mapId = rec.mapId :: string
	if mapId ~= world.mapId then
		local layers = MapRegistry.load(mapId)
		world.layers = layers
		world.grid = if layers then layers.grid else Grid.new(1, 1)
		world.mapId = mapId
		world.mapVersion += 1
	end
	world.me = { player = rec.player :: number, team = rec.team :: number, allyTeam = rec.allyTeam :: number }
	-- every team's ally team (protocol 30, S-129), indexed by team; 0 = not in the match
	world.teamAllies = (rec :: any).teamAllies or {}
	table.clear(world.units)
	table.clear(world.entered)
	table.clear(world.left)
	table.clear(world.died)
	table.clear(world.dying)
	table.clear(world.events)
	world.sight = nil -- the server sends it whole again after a WELCOME
	table.clear(world.wrecks)
	table.clear(world.wreckAdded)
	table.clear(world.wreckGone)
	table.clear(world.alertQueue)
	table.clear(world.shields)
	table.clear(world.remoteDomes)
	table.clear(world.idle) -- the join sends every idle one again
	table.clear(world.lastShot)
	table.clear(world.deathWrecks)
	world.pregame = World.newPregame() -- a join during the pre-game sends it all again
	world.strategicTick = -1
	world.economy = nil
	world.latestTick = rec.tick :: number -- unwraps wire ticks from here on
	world.latestAt = now
	world.joined = true
	world.joins += 1
end

-- Wire heading u8 → radians.
function World.heading(v: number): number
	return v / 256 * 2 * math.pi
end

-- Wire aim angle u8 → radians in [-π, π].
function World.angle(v: number): number
	return v / 255 * 2 * math.pi - math.pi
end

World.BLIP_SMOOTH = 0.45 -- seconds: a strategic record's drawn spot closes most of the way to a new reading in this time
World.BLIP_SNAP = 160 -- studs: a jump this big snaps (a contact reappearing elsewhere)
World.BLIP_ORBIT = 1.5 -- studs: radar / sonar blips circle their reported spot, as in BAR (C-154)
World.BLIP_ORBIT_SECONDS = 6 -- one turn

-- A contact's orbit start angle and direction, from its id (the same every
-- frame, different per contact).
local function orbitOf(id: number): (number, number)
	local h = (id * 2654435761) % 4294967296
	return (h % 65536) / 65536 * 2 * math.pi, if (h // 65536) % 2 == 0 then 1 else -1
end

-- Once a frame: strategic records (radar blips, sonar contacts, out-of-view
-- units) glide toward their latest reported spot instead of jumping to each
-- new one (the user, C-151). Radar and sonar blips also circle it,
-- BLIP_ORBIT studs once every BLIP_ORBIT_SECONDS (with `now`; C-154): the
-- server sends strategic spots by cell, so its own small orbit (S-131)
-- doesn't show. Draw them at sx, sz.
function World.smoothStrategic(world: World, dt: number, now: number?)
	local k = 1 - math.exp(-dt / World.BLIP_SMOOTH)
	local blip = Schema.StrategicFlag.RADAR_ONLY + Schema.StrategicFlag.SONAR_ONLY
	for id, u in world.units do
		if u.tier ~= "tactical" then
			local gx, gz = u.gx, u.gz
			if gx == nil or gz == nil or (gx - u.x) ^ 2 + (gz - u.z) ^ 2 > World.BLIP_SNAP ^ 2 then
				gx, gz = u.x, u.z
			else
				gx, gz = gx + (u.x - gx) * k, gz + (u.z - gz) * k
			end
			u.gx, u.gz = gx, gz
			if now and bit32.band(u.flags or 0, blip) ~= 0 then
				local phase, dir = orbitOf(id)
				local a = phase + dir * 2 * math.pi * now / World.BLIP_ORBIT_SECONDS
				u.sx, u.sz = gx + math.cos(a) * World.BLIP_ORBIT, gz + math.sin(a) * World.BLIP_ORBIT
			else
				u.sx, u.sz = gx, gz
			end
		end
	end
end

function World.relation(world: World, unit: Unit): "own" | "ally" | "enemy"
	if unit.team == world.me.team then
		return "own"
	end
	-- every team's ally team arrives with WELCOME since protocol 30 (S-129, C-150)
	local ally = world.teamAllies[unit.team]
	if ally ~= nil and ally ~= 0 and ally == world.me.allyTeam then
		return "ally"
	end
	return "enemy"
end

-- Drawn ground height (studs) under a world position: the smooth surface
-- the 3D terrain shows (Core/Terrain, C-28), or the water surface for units
-- that float.
-- Whether a unit is drawn on the water surface rather than the bed (C-192,
-- the user: each on its terrain): ships, structures built on water (their
-- models float), and amphibious or hover units, which ride the surface.
function World.floats(def: any): boolean
	if def.domain == "naval" or def.placement == "water" then
		return true
	end
	local mc = def.moveClass and (MoveClasses :: any)[def.moveClass]
	return mc ~= nil and (mc.surface == "amphib" or mc.surface == "hover")
end

function World.groundY(world: World, x: number, z: number, floats: boolean?): number
	local layers = world.layers
	if layers == nil then
		return 0
	end
	return if floats then Terrain.surfaceY(layers, x, z) else Terrain.groundY(layers, x, z)
end

-- Moves what the bars show up to render tick `renderTick` (C-49): a health
-- change shows when the render clock reaches the tick it happened on, with
-- the hit that caused it, not when its record arrives (~2 ticks earlier).
function World.settle(world: World, renderTick: number)
	world.shownTick = renderTick
	-- a unit that died stays a missile's target until its death is drawn (C-50)
	for id, d in world.dying do
		if renderTick >= d.tick + 1 then
			world.dying[id] = nil
		end
	end
	for _, u in world.units do
		local log = u.healthLog
		if log == nil then
			continue
		end
		while log[1] and log[1][1] <= renderTick do
			u.shownHealth = log[1][2]
			table.remove(log, 1)
		end
		if #log == 0 then
			u.healthLog = nil
		end
	end
end

-- A unit by ID, or one whose DEATH arrived but isn't drawn yet (C-50): the
-- server's death record comes ~2 ticks ahead of the render clock, and a
-- missile drawn chasing it must keep steering at it until its hit plays,
-- not lose it and fly past.
function World.unitOrDying(world: World, id: number): Unit?
	if id == 0 then
		return nil
	end
	local u = world.units[id]
	if u then
		return u
	end
	local d = world.dying[id]
	return if d then d.unit else nil
end

-- The health the bars show: as of the render tick once World.settle runs,
-- else (Lune specs that never settle) the latest.
function World.shownHealth(world: World, u: Unit): number?
	if world.shownTick == nil then
		return u.health
	end
	return u.shownHealth or u.health
end

-- Missiles in stock across a unit's stockpile slots (S-47, C-56), and their
-- total capacity (Defs' derived `stockCapacity`); nil when it has no
-- stockpile or the server hasn't said (other players' units never carry it).
World.RELOAD_BAR = 4 -- seconds: weapons reloading at least this long show a recharge bar (C-170)

-- A shot by `id`'s weapon `slot` at sim tick `tick` (Core/Effects).
function World.noteShot(world: World, id: number, slot: number, tick: number)
	local t = world.lastShot[id]
	if t == nil then
		t = {}
		world.lastShot[id] = t
	end
	t[slot] = tick
end

-- How charged `u`'s slowest long-reload weapon is at render tick `tick`,
-- 0..1, while it recharges after a shot seen; nil when it has none, or it's
-- charged (the server's reload runs from the shot: Sim/Weapons).
function World.reloadOf(world: World, u: Unit, tick: number): number?
	local shots = world.lastShot[u.id]
	local def = shots and World.def(world, u)
	if def == nil or shots == nil then
		return nil
	end
	local worst: number? = nil
	for slot, ws in def.weapons do
		local weapon = world.defs.weaponByIndex[(ws :: any).weaponIndex] :: any
		local shot = shots[slot]
		if shot and weapon and (weapon.reload or 0) >= World.RELOAD_BAR then
			local f = (tick - shot) / (weapon.reload * 15)
			if f < 1 then
				worst = math.min(worst or 1, math.max(f, 0))
			end
		end
	end
	return worst
end

function World.stockOf(world: World, u: Unit): (number?, number?)
	local def = World.def(world, u)
	if def == nil or u.stock == nil then
		return nil, nil
	end
	local count, capacity = 0, 0
	for slot, w in def.weapons do
		local cap = (w :: any).stockCapacity
		if cap then
			capacity += cap
			count += (u.stock :: { [number]: number })[slot] or 0
		end
	end
	if capacity == 0 then
		return nil, nil
	end
	return count, capacity
end

-- The build progress (0..1) of the next missile of a unit's first
-- stockpile slot that isn't full (S-49, C-59), at render tick `renderTick`:
-- the server's last value grown at 1 / buildTime per second, capped at the
-- next sixteenth (the server sends one every Stockpile.WIRE_STEPS), so a
-- stalled economy stops it within a step. Nil when full or unknown.
World.STOCK_WIRE_STEPS = 16
function World.stockProgressOf(world: World, u: Unit, renderTick: number): number?
	local def = World.def(world, u)
	local stock, progress = u.stock, u.stockProgress
	if def == nil or stock == nil or progress == nil then
		return nil
	end
	for slot, ws in def.weapons do
		local cap = (ws :: any).stockCapacity
		local p = progress[slot]
		if cap and p and (stock[slot] or 0) < cap then
			local weapon = world.defs.weaponByIndex[(ws :: any).weaponIndex] :: any
			local buildTime = weapon and weapon.stockpile and weapon.stockpile.buildTime or math.huge
			local grown = p[1] + math.max(0, renderTick - p[2]) / 15 / buildTime
			-- the wire floors progress to 1/255: a record sent on crossing a
			-- sixteenth can read just under it
			local cap16 = (math.floor((p[1] + 1 / 255) * World.STOCK_WIRE_STEPS) + 1) / World.STOCK_WIRE_STEPS
			return math.min(grown, cap16, 1)
		end
	end
	return nil
end

-- Whether a unit is moving: the server's MOVING state bit, or (the server
-- doesn't set that bit yet, C-45) a position or heading change within the
-- last MOVING_TICKS ticks.
function World.moving(world: World, unit: Unit): boolean
	if bit32.band(unit.state or 0, World.State.MOVING) ~= 0 then
		return true
	end
	local moved = unit.movedTick
	return moved ~= nil and world.latestTick - moved <= World.MOVING_TICKS[unit.tier]
end

function World.def(world: World, unit: Unit): Defs.UnitDef?
	return if unit.defIndex then world.defs.unitByIndex[unit.defIndex] else nil
end

-- Units the local player owns, sorted by ID.
function World.ownIds(world: World): { number }
	local out = {}
	for id, u in world.units do
		if u.team == world.me.team and u.tier == "tactical" then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

return World
