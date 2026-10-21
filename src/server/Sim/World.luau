--!strict
-- Server unit storage (guide 3.4): struct-of-arrays keyed by u16 unit ID.
--
-- * IDs run 1..65535. Fresh IDs are handed out first; freed IDs are reused
--   only after REUSE_DELAY_TICKS (oldest first), so late packets never apply
--   to a different unit.
-- * `ids` is the dense list of live units. Systems iterate it (never pairs()),
--   so iteration order is a pure function of spawn/despawn history.
-- * Every write to a replicated field goes through a setter that sets the
--   matching dirty bit. NetOut reads and clears them.

local Hash = require("@shared/Util/Hash")
local Schema = require("@shared/Net/Schema")

local bor = bit32.bor

local World = {}

World.MAX_ID = 65535
World.REUSE_DELAY_TICKS = 150 -- 10 s at 15 Hz

-- Dirty bits: which replicated fields changed since NetOut last looked.
World.Dirty = table.freeze({
	SPAWNED = 1,
	POSITION = 2,
	HEADING = 4,
	HEALTH = 8,
	STATE = 16,
	ALTITUDE = 32,
	BUILD = 64,
})
local D = World.Dirty
local ALL_DIRTY = 127

-- State bit flags (replicated in the state record's `state` u16): defined
-- in Shared so clients decode them with the same table (S-6).
World.State = Schema.UnitState

-- Fire / move states (guide 10.1); values match Schema.FireState / MoveState.
World.FireState = table.freeze({ HOLD_FIRE = 0, RETURN_FIRE = 1, FIRE_AT_WILL = 2 })
World.MoveState = table.freeze({ HOLD_POSITION = 0, MANEUVER = 1, ROAM = 2 })

export type World = {
	-- live units
	ids: { number }, -- dense list of live IDs
	slot: { [number]: number }, -- id → position in ids

	-- per-unit fields, indexed by ID
	defIndex: { [number]: number },
	team: { [number]: number },
	ally: { [number]: number }, -- ally team: shares sight, never a target (guide 16.1)
	owner: { [number]: number }, -- player ID
	posX: { [number]: number },
	posZ: { [number]: number },
	alt: { [number]: number },
	heading: { [number]: number }, -- radians, 0 = +Z, counter-clockwise
	health: { [number]: number },
	buildProgress: { [number]: number }, -- 0..1; 1 = complete
	state: { [number]: number }, -- World.State bits
	fireState: { [number]: number },
	moveState: { [number]: number },
	dirty: { [number]: number }, -- World.Dirty bits

	-- movement (server-only, not replicated directly)
	speed: { [number]: number }, -- studs/s along heading
	orderId: { [number]: number }, -- active move order (Nav), 0 = idle
	goalX: { [number]: number }, -- this unit's own goal (formation slot)
	goalZ: { [number]: number },
	direct: { [number]: boolean }, -- straight line to the goal is clear
	bestDist: { [number]: number }, -- closest distance to the goal so far
	progressTick: { [number]: number }, -- tick bestDist last improved

	-- combat. Per-weapon fields are keyed by World.slotKey(id, slot).
	weaponCount: { [number]: number },
	lastAttacker: { [number]: number }, -- unit that last damaged this one, 0 = none
	lastAttackerGen: { [number]: number }, -- its generation (D109)
	wYaw: { [number]: number }, -- turret yaw relative to the hull, radians
	wPitch: { [number]: number }, -- radians, up positive
	wReload: { [number]: number }, -- seconds until ready (<= 0 = ready)
	wTarget: { [number]: number }, -- target unit ID, 0 = none
	wTargetGen: { [number]: number }, -- the target's generation (D109): a ghost's for dead structures
	wHold: { [number]: number }, -- ticks the weapon still keeps its aim after losing its target (Shared/Combat/Aim, S-20)
	wOverkill: { [number]: number }, -- World.Overkill: left a doomed target, search now / may shoot a doomed one (S-29)
	wBlocked: { [number]: number }, -- 1 while terrain blocks the shot at the current target (line of fire, S-32)
	wStock: { [number]: number }, -- missiles in stock; nil = the slot has no stockpile (Stockpile, S-47)
	wTargetProj: { [number]: number }, -- interceptors: the enemy strategic missile targeted (projectile ID, 0 = none; S-48)
	wTargetProjSerial: { [number]: number }, -- its Combat.pSerial
	wStockProgress: { [number]: number }, -- 0..1 of the next missile

	-- ID allocator
	gen: { [number]: number }, -- per ID slot: how many units have had it (D109); kept after despawn
	pins: { [number]: number }, -- IDs still remembered as ghosts: never reused while pinned (D109)
	nextFresh: number, -- next never-used ID
	freeIds: { number }, -- FIFO of freed IDs ...
	freeTicks: { number }, -- ... and the tick each was freed
	freeHead: number, -- index of the oldest queued entry
	freeTail: number, -- index the next freed ID goes to
}

function World.new(): World
	return {
		ids = {},
		slot = {},
		defIndex = {},
		team = {},
		ally = {},
		owner = {},
		posX = {},
		posZ = {},
		alt = {},
		heading = {},
		health = {},
		buildProgress = {},
		state = {},
		fireState = {},
		moveState = {},
		dirty = {},
		speed = {},
		orderId = {},
		goalX = {},
		goalZ = {},
		direct = {},
		bestDist = {},
		progressTick = {},
		weaponCount = {},
		lastAttacker = {},
		lastAttackerGen = {},
		wYaw = {},
		wPitch = {},
		wReload = {},
		wTarget = {},
		wTargetGen = {},
		wHold = {},
		wOverkill = {},
		wBlocked = {},
		wStock = {},
		wTargetProj = {},
		wTargetProjSerial = {},
		wStockProgress = {},
		gen = {},
		pins = {},
		nextFresh = 1,
		freeIds = {},
		freeTicks = {},
		freeHead = 1,
		freeTail = 1,
	}
end

function World.count(w: World): number
	return #w.ids
end

function World.isAlive(w: World, id: number): boolean
	return w.slot[id] ~= nil
end

-- Returns a free ID or nil if none is available at this tick.
local function allocate(w: World, tick: number): number?
	if w.nextFresh <= World.MAX_ID then
		local id = w.nextFresh
		w.nextFresh += 1
		return id
	end
	-- oldest freed ID past its delay; pinned IDs (remembered ghosts) go to
	-- the back of the queue with their free tick (D109)
	for _ = 1, w.freeTail - w.freeHead do
		local head = w.freeHead
		local id = w.freeIds[head]
		local freedAt = w.freeTicks[head]
		if id == nil or tick - freedAt < World.REUSE_DELAY_TICKS then
			return nil
		end
		w.freeIds[head] = nil
		w.freeTicks[head] = nil
		w.freeHead = head + 1
		if (w.pins[id] or 0) == 0 then
			return id
		end
		local tail = w.freeTail
		w.freeIds[tail] = id
		w.freeTicks[tail] = freedAt
		w.freeTail = tail + 1
	end
	return nil
end

export type SpawnInfo = {
	defIndex: number,
	team: number,
	ally: number?, -- default: team
	owner: number,
	x: number,
	z: number,
	heading: number?,
	alt: number?,
	health: number,
	weaponCount: number?,
	weaponStock: { [number]: number }?, -- slot → missiles in stock, for slots with a stockpile (S-47)
	weaponRest: { { number } }?, -- per slot {yaw, pitch} (radians): the aim it starts at; default 0, 0 (S-20)
	buildProgress: number?, -- default 1 (complete)
}

World.MAX_WEAPONS = 8

-- Key for per-weapon fields: slots 1..8 of unit `id`.
function World.slotKey(id: number, slot: number): number
	return id * 8 + slot - 1
end

-- Adds a unit and returns its ID. Errors when all 65,535 IDs are in use or
-- still waiting out their reuse delay.
function World.spawn(w: World, tick: number, info: SpawnInfo): number
	local id = allocate(w, tick)
	if id == nil then
		error("World.spawn: no unit ID available (all in use or in their reuse delay)", 2)
	end
	table.insert(w.ids, id)
	w.slot[id] = #w.ids
	w.gen[id] = (w.gen[id] or 0) + 1
	w.defIndex[id] = info.defIndex
	w.team[id] = info.team
	w.ally[id] = info.ally or info.team
	w.owner[id] = info.owner
	w.posX[id] = info.x
	w.posZ[id] = info.z
	w.alt[id] = info.alt or 0
	w.heading[id] = info.heading or 0
	w.health[id] = info.health
	w.buildProgress[id] = info.buildProgress or 1
	w.state[id] = 0
	w.fireState[id] = World.FireState.FIRE_AT_WILL
	w.moveState[id] = World.MoveState.MANEUVER
	w.dirty[id] = ALL_DIRTY
	w.speed[id] = 0
	w.orderId[id] = 0
	w.goalX[id] = info.x
	w.goalZ[id] = info.z
	w.direct[id] = false
	w.bestDist[id] = 0
	w.progressTick[id] = tick
	local weapons = info.weaponCount or 0
	w.weaponCount[id] = weapons
	w.lastAttacker[id] = 0
	w.lastAttackerGen[id] = 0
	for slot = 1, weapons do
		local key = id * 8 + slot - 1
		local rest = info.weaponRest and info.weaponRest[slot]
		w.wYaw[key] = if rest then rest[1] else 0
		w.wPitch[key] = if rest then rest[2] else 0
		w.wHold[key] = 0
		w.wOverkill[key] = 0
		w.wBlocked[key] = 0
		w.wReload[key] = 0
		w.wTarget[key] = 0
		w.wTargetGen[key] = 0
		w.wTargetProj[key] = 0
		w.wTargetProjSerial[key] = 0
		local stock = info.weaponStock and info.weaponStock[slot]
		if stock then
			w.wStock[key] = stock
			w.wStockProgress[key] = 0
		end
	end
	return id
end

-- Is (id, gen) still the same live unit (D109)? A remembered reference
-- whose generation no longer matches points at a unit that is gone, even if
-- its ID was handed to a new one.
function World.isRef(w: World, id: number, gen: number?): boolean
	return id ~= 0 and w.slot[id] ~= nil and w.gen[id] == gen
end

-- Sets weapon slot `key`'s target to (id, gen); gen defaults to the live
-- unit's.
function World.setTarget(w: World, key: number, id: number, gen: number?)
	if w.wTarget[key] ~= id then
		w.wOverkill[key] = 0
		w.wBlocked[key] = 0
	end
	w.wTarget[key] = id
	w.wTargetGen[key] = if id == 0 then 0 else (gen or w.gen[id] or 0)
end

-- Overkill avoidance per weapon (S-29): RETARGET = it just left a target that
-- hits already on the way will kill, so it searches on the next tick instead
-- of waiting for its stagger tick; ALLOWED = its target is doomed but nothing
-- else is in reach, so it fires anyway.
World.Overkill = table.freeze({ NONE = 0, RETARGET = 1, ALLOWED = 2 })

-- Ghost pins (D109): an ID remembered as a ghost by any team is never
-- reused, so a ghost and a new unit can't share an ID (on the wire too).
function World.pin(w: World, id: number)
	w.pins[id] = (w.pins[id] or 0) + 1
end

function World.unpin(w: World, id: number)
	local n = (w.pins[id] or 0) - 1
	w.pins[id] = if n > 0 then n else nil
end

-- Removes a unit; its ID becomes reusable after REUSE_DELAY_TICKS.
-- Swap-remove keeps `ids` dense; the order change is deterministic.
function World.despawn(w: World, tick: number, id: number)
	local s = w.slot[id]
	if s == nil then
		error(`World.despawn: unit {id} is not alive`, 2)
	end
	local ids = w.ids
	local last = ids[#ids]
	ids[s] = last
	w.slot[last] = s
	ids[#ids] = nil
	w.slot[id] = nil

	w.defIndex[id] = nil
	w.team[id] = nil
	w.ally[id] = nil
	w.owner[id] = nil
	w.posX[id] = nil
	w.posZ[id] = nil
	w.alt[id] = nil
	w.heading[id] = nil
	w.health[id] = nil
	w.buildProgress[id] = nil
	w.state[id] = nil
	w.fireState[id] = nil
	w.moveState[id] = nil
	w.dirty[id] = nil
	w.speed[id] = nil
	w.orderId[id] = nil
	w.goalX[id] = nil
	w.goalZ[id] = nil
	w.direct[id] = nil
	w.bestDist[id] = nil
	w.progressTick[id] = nil
	for slot = 1, w.weaponCount[id] do
		local key = id * 8 + slot - 1
		w.wYaw[key] = nil
		w.wPitch[key] = nil
		w.wReload[key] = nil
		w.wTarget[key] = nil
		w.wTargetGen[key] = nil
		w.wHold[key] = nil
		w.wOverkill[key] = nil
		w.wBlocked[key] = nil
		w.wStock[key] = nil
		w.wStockProgress[key] = nil
		w.wTargetProj[key] = nil
		w.wTargetProjSerial[key] = nil
	end
	w.weaponCount[id] = nil
	w.lastAttacker[id] = nil
	w.lastAttackerGen[id] = nil

	local tail = w.freeTail
	w.freeIds[tail] = id
	w.freeTicks[tail] = tick
	w.freeTail = tail + 1
end

--------------------------------------------------------------------------------
-- Setters for replicated fields (each marks its dirty bit)
--------------------------------------------------------------------------------

function World.setPosition(w: World, id: number, x: number, z: number)
	w.posX[id] = x
	w.posZ[id] = z
	w.dirty[id] = bor(w.dirty[id], D.POSITION)
end

function World.setHeading(w: World, id: number, heading: number)
	w.heading[id] = heading
	w.dirty[id] = bor(w.dirty[id], D.HEADING)
end

function World.setAltitude(w: World, id: number, alt: number)
	w.alt[id] = alt
	w.dirty[id] = bor(w.dirty[id], D.ALTITUDE)
end

function World.setHealth(w: World, id: number, health: number)
	w.health[id] = health
	w.dirty[id] = bor(w.dirty[id], D.HEALTH)
end

function World.setBuildProgress(w: World, id: number, progress: number)
	w.buildProgress[id] = progress
	w.dirty[id] = bor(w.dirty[id], D.BUILD)
end

function World.setState(w: World, id: number, state: number)
	w.state[id] = state
	w.dirty[id] = bor(w.dirty[id], D.STATE)
end

-- Fire/move states are server-side behavior, replicated via the state record.
function World.setFireState(w: World, id: number, value: number)
	w.fireState[id] = value
	w.dirty[id] = bor(w.dirty[id], D.STATE)
end

function World.setMoveState(w: World, id: number, value: number)
	w.moveState[id] = value
	w.dirty[id] = bor(w.dirty[id], D.STATE)
end

function World.clearDirty(w: World, id: number)
	w.dirty[id] = 0
end

--------------------------------------------------------------------------------
-- Hash (guide 17.1 desync check)
--------------------------------------------------------------------------------

-- Hash of all gameplay state, visiting units in ascending ID order so the
-- result doesn't depend on `ids` order. Includes the allocator, which decides
-- future IDs. Allocates a sorted copy of the IDs: call it rarely (every 300
-- ticks), not per tick.
function World.hash(w: World, h: number?): number
	local hv = h or Hash.OFFSET_BASIS
	local sorted = table.clone(w.ids)
	table.sort(sorted)
	hv = Hash.u32(hv, #sorted)
	for _, id in sorted do
		hv = Hash.u32(hv, id)
		hv = Hash.u32(hv, w.defIndex[id])
		hv = Hash.u32(hv, w.team[id])
		hv = Hash.u32(hv, w.ally[id])
		hv = Hash.u32(hv, w.owner[id])
		hv = Hash.number(hv, w.posX[id])
		hv = Hash.number(hv, w.posZ[id])
		hv = Hash.number(hv, w.alt[id])
		hv = Hash.number(hv, w.heading[id])
		hv = Hash.number(hv, w.health[id])
		hv = Hash.number(hv, w.buildProgress[id])
		hv = Hash.u32(hv, w.state[id])
		hv = Hash.u32(hv, w.fireState[id])
		hv = Hash.u32(hv, w.moveState[id])
		hv = Hash.number(hv, w.speed[id])
		hv = Hash.u32(hv, w.orderId[id])
		hv = Hash.number(hv, w.goalX[id])
		hv = Hash.number(hv, w.goalZ[id])
		hv = Hash.u32(hv, if w.direct[id] then 1 else 0)
		hv = Hash.u32(hv, w.gen[id])
		hv = Hash.u32(hv, w.lastAttacker[id])
		hv = Hash.u32(hv, w.lastAttackerGen[id])
		for slot = 1, w.weaponCount[id] do
			local key = id * 8 + slot - 1
			hv = Hash.number(hv, w.wYaw[key])
			hv = Hash.number(hv, w.wPitch[key])
			hv = Hash.number(hv, w.wReload[key])
			hv = Hash.u32(hv, w.wTarget[key])
			hv = Hash.u32(hv, w.wTargetGen[key])
			hv = Hash.u32(hv, w.wHold[key])
			hv = Hash.u32(hv, w.wOverkill[key])
			hv = Hash.u32(hv, w.wBlocked[key])
			hv = Hash.u32(Hash.u32(hv, w.wTargetProj[key]), w.wTargetProjSerial[key])
			local stock = w.wStock[key]
			if stock ~= nil then
				hv = Hash.u32(hv, stock)
				hv = Hash.number(hv, w.wStockProgress[key])
			end
		end
	end
	hv = Hash.u32(hv, w.nextFresh)
	for i = w.freeHead, w.freeTail - 1 do
		hv = Hash.u32(hv, w.freeIds[i])
		hv = Hash.u32(hv, w.freeTicks[i])
	end
	return hv
end

return World
