--!strict
-- The client's table of known units (guide 15.1): every unit the server told
-- this player about, in both tiers. Pure data, no Instances (C-7): NetIn
-- fills it from packets, Interp samples it, the renderer drains its queues.
--
-- Wire conventions: docs/contracts/net.md (protocol 5).

local Defs = require("@shared/Defs/Defs")
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

export type World = {
	shownTick: number?, -- the render tick World.settle last ran for (C-49)
	grid: Grid.Grid,
	layers: Layers.Layers?,
	mapId: string?,
	mapVersion: number, -- bumps when WELCOME brings another map (the renderer rebuilds the ground)
	defs: Defs.DefSet,
	me: Me,
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
	events: { Schema.Event }, -- combat events (FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK) with `tick`
	dropped: number, -- records dropped as out of sync or malformed (diagnostics)
	eventCounts: { [number]: number }, -- combat events received per Schema.EventKind (0 = homing correction)
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
		events = {},
		dropped = 0,
		eventCounts = {},
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
	table.clear(world.units)
	table.clear(world.entered)
	table.clear(world.left)
	table.clear(world.died)
	table.clear(world.events)
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

function World.relation(world: World, unit: Unit): "own" | "ally" | "enemy"
	if unit.team == world.me.team then
		return "own"
	end
	-- ally teams aren't on the wire yet (protocol 6 WELCOME); only own team counts as allied
	return "enemy"
end

-- Drawn ground height (studs) under a world position: the smooth surface
-- the 3D terrain shows (Core/Terrain, C-28), or the water surface for units
-- that float.
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

-- The health the bars show: as of the render tick once World.settle runs,
-- else (Lune specs that never settle) the latest.
function World.shownHealth(world: World, u: Unit): number?
	if world.shownTick == nil then
		return u.health
	end
	return u.shownHealth or u.health
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
