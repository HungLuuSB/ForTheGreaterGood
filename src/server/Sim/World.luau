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
})
local D = World.Dirty
local ALL_DIRTY = 63

-- State bit flags (replicated in the state record's `state` u16).
World.State = table.freeze({
	MOVING = 1,
	TOGGLED_ON = 2,
})

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
	owner: { [number]: number }, -- player ID
	posX: { [number]: number },
	posZ: { [number]: number },
	alt: { [number]: number },
	heading: { [number]: number }, -- radians, 0 = +Z, counter-clockwise
	health: { [number]: number },
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
	wYaw: { [number]: number }, -- turret yaw relative to the hull, radians
	wPitch: { [number]: number }, -- radians, up positive
	wReload: { [number]: number }, -- seconds until ready (<= 0 = ready)
	wTarget: { [number]: number }, -- target unit ID, 0 = none

	-- ID allocator
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
		owner = {},
		posX = {},
		posZ = {},
		alt = {},
		heading = {},
		health = {},
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
		wYaw = {},
		wPitch = {},
		wReload = {},
		wTarget = {},
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
	local head = w.freeHead
	local id = w.freeIds[head]
	if id ~= nil and tick - w.freeTicks[head] >= World.REUSE_DELAY_TICKS then
		w.freeIds[head] = nil
		w.freeTicks[head] = nil
		w.freeHead = head + 1
		return id
	end
	return nil
end

export type SpawnInfo = {
	defIndex: number,
	team: number,
	owner: number,
	x: number,
	z: number,
	heading: number?,
	alt: number?,
	health: number,
	weaponCount: number?,
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
	w.defIndex[id] = info.defIndex
	w.team[id] = info.team
	w.owner[id] = info.owner
	w.posX[id] = info.x
	w.posZ[id] = info.z
	w.alt[id] = info.alt or 0
	w.heading[id] = info.heading or 0
	w.health[id] = info.health
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
	for slot = 1, weapons do
		local key = id * 8 + slot - 1
		w.wYaw[key] = 0
		w.wPitch[key] = 0
		w.wReload[key] = 0
		w.wTarget[key] = 0
	end
	return id
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
	w.owner[id] = nil
	w.posX[id] = nil
	w.posZ[id] = nil
	w.alt[id] = nil
	w.heading[id] = nil
	w.health[id] = nil
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
	end
	w.weaponCount[id] = nil
	w.lastAttacker[id] = nil

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
		hv = Hash.u32(hv, w.owner[id])
		hv = Hash.number(hv, w.posX[id])
		hv = Hash.number(hv, w.posZ[id])
		hv = Hash.number(hv, w.alt[id])
		hv = Hash.number(hv, w.heading[id])
		hv = Hash.number(hv, w.health[id])
		hv = Hash.u32(hv, w.state[id])
		hv = Hash.u32(hv, w.fireState[id])
		hv = Hash.u32(hv, w.moveState[id])
		hv = Hash.number(hv, w.speed[id])
		hv = Hash.u32(hv, w.orderId[id])
		hv = Hash.number(hv, w.goalX[id])
		hv = Hash.number(hv, w.goalZ[id])
		hv = Hash.u32(hv, if w.direct[id] then 1 else 0)
		hv = Hash.u32(hv, w.lastAttacker[id])
		for slot = 1, w.weaponCount[id] do
			local key = id * 8 + slot - 1
			hv = Hash.number(hv, w.wYaw[key])
			hv = Hash.number(hv, w.wPitch[key])
			hv = Hash.number(hv, w.wReload[key])
			hv = Hash.u32(hv, w.wTarget[key])
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
